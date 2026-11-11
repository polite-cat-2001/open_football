class_name CareerCondition
extends RefCounted
# Player condition, season stats and match outcomes ported from
# server/career/condition.py. Career stores the prototype's player_state map in
# its JSON, so these helpers read and write career.data directly.

const STAT_KEYS := [
	"apps", "starts", "minutes", "goals", "assists", "yellow", "red", "clean_sheets",
]
const DEFAULT_COMPETITION := "league"
const FATIGUE_PER_MATCH := 35
const FATIGUE_PER_SUB := 15
const FATIGUE_RECOVERY_PER_DAY := 4
const YELLOW_SUSPENSION_THRESHOLD := 5
const INJURY_TYPES := ["Muscle", "Ligaments", "Ankle", "Knee", "Thigh"]
const INJURY_DAYS := [7, 10, 14, 21, 28]


static func empty_stats() -> Dictionary:
	var stats := {}
	for key in STAT_KEYS:
		stats[key] = 0
	return stats


static func default_player_state() -> Dictionary:
	return {
		"fatigue": 100,
		"injury": null,
		"suspension": null,
		"stats": empty_stats(),
		"stats_by_competition": {},
		"available_matches": 0,
		"expected_minutes": 0,
	}


static func competition_key(career: Career) -> String:
	return career.league_id if not career.league_id.is_empty() else DEFAULT_COMPETITION


static func competition_stats(state: Dictionary, competition_id: String) -> Dictionary:
	if not (state.get("stats_by_competition") is Dictionary):
		state["stats_by_competition"] = {}
	var blocks: Dictionary = state["stats_by_competition"]
	var block = blocks.get(competition_id)
	if not (block is Dictionary):
		block = {}
	for key in STAT_KEYS:
		if not block.has(key):
			block[key] = 0
	blocks[competition_id] = block
	return block


static func ensure_player_states(career: Career, player_ids: Array) -> void:
	if not (career.data.get("player_state") is Dictionary):
		career.data["player_state"] = {}
	var states: Dictionary = career.data["player_state"]
	var current := competition_key(career)
	for player_id in player_ids:
		var key := str(player_id)
		var state = states.get(key)
		if not (state is Dictionary):
			state = default_player_state()
		for field in ["fatigue", "injury", "suspension", "available_matches",
				"expected_minutes"]:
			if not state.has(field):
				state[field] = default_player_state()[field]
		if not (state.get("stats") is Dictionary):
			state["stats"] = empty_stats()
		for stat_key in STAT_KEYS:
			if not state["stats"].has(stat_key):
				state["stats"][stat_key] = 0
		competition_stats(state, current)
		states[key] = state
	if career.data.get("condition_date") == null:
		career.data["condition_date"] = career.date


static func recover_condition(career: Career, target_date: String) -> void:
	var states = career.data.get("player_state")
	if not (states is Dictionary) or states.is_empty():
		career.data["condition_date"] = target_date
		return
	var previous = career.data.get("condition_date")
	if previous == null:
		career.data["condition_date"] = target_date
		return
	var elapsed := CareerSeason.days_between(str(previous), target_date)
	if elapsed <= 0:
		return
	for state in states.values():
		var fatigue := int(state.get("fatigue", 0))
		state["fatigue"] = mini(100, fatigue + FATIGUE_RECOVERY_PER_DAY * elapsed)
		var injury = state.get("injury")
		if injury is Dictionary and str(injury.get("until", "")) <= target_date:
			state["injury"] = null
	career.data["condition_date"] = target_date


static func blocked_player_ids(career: Career) -> Array:
	var blocked: Array = []
	var states = career.data.get("player_state")
	if not (states is Dictionary):
		return blocked
	for player_id in states:
		var state = states[player_id]
		if not (state is Dictionary):
			continue
		if state.get("injury"):
			blocked.append(str(player_id))
			continue
		var suspension = state.get("suspension")
		if suspension is Dictionary and int(suspension.get("matches", 0)) > 0:
			blocked.append(str(player_id))
	return blocked


static func apply_match_outcome(career: Career, fixture: Dictionary, setup: Dictionary,
		match: Dictionary, competition_id: String = "") -> void:
	var side := "home" if bool(setup.get("home", false)) else "away"
	var competition := competition_id if not competition_id.is_empty() \
		else competition_key(career)
	var lineup: Dictionary = setup["%s_lineup" % side]
	var starters: Array = []
	for slot in lineup["slots"]:
		starters.append(slot["player"])
	var bench: Array = lineup.get("bench", [])
	var events: Array = []
	for event in match.get("events", []):
		if str(event.get("team", "")) == side:
			events.append(event)

	var states: Dictionary = career.data.get("player_state", {})
	var suspended_before := {}
	for player_id in states:
		var state = states[player_id]
		if state is Dictionary and int(_dict(state.get("suspension")).get("matches", 0)) > 0:
			suspended_before[str(player_id)] = true

	var minutes := {}
	for player in starters:
		minutes[str(player["id"])] = 90
	var blocks := {}
	for player in starters + bench:
		var state := _player_state(career, player["id"])
		blocks[str(player["id"])] = [
			state["stats"], competition_stats(state, competition),
		]

	for event in events:
		var minute := int(event.get("minute", 0))
		var player := _dict(event.get("player"))
		var player_id := str(player.get("id", ""))
		if player_id.is_empty() or not blocks.has(player_id):
			continue
		var total: Dictionary = blocks[player_id][0]
		var by_competition: Dictionary = blocks[player_id][1]
		match str(event.get("type", "")):
			"sub":
				var outgoing := _dict(event.get("player_out"))
				var outgoing_id := str(outgoing.get("id", ""))
				if not outgoing_id.is_empty():
					minutes[outgoing_id] = mini(int(minutes.get(outgoing_id, 90)), minute)
				minutes[player_id] = maxi(0, 90 - minute)
				_bump(total, "apps")
				_bump(by_competition, "apps")
			"goal", "penalty":
				_bump(total, "goals")
				_bump(by_competition, "goals")
				var assist := _dict(event.get("assist"))
				var assist_id := str(assist.get("id", ""))
				if blocks.has(assist_id):
					_bump(blocks[assist_id][0], "assists")
					_bump(blocks[assist_id][1], "assists")
			"yellow":
				_bump(total, "yellow")
				_bump(by_competition, "yellow")
				if int(total.get("yellow", 0)) % YELLOW_SUSPENSION_THRESHOLD == 0:
					_add_suspension(_player_state(career, player_id), "yellow")
			"red":
				_bump(total, "red")
				_bump(by_competition, "red")
				minutes[player_id] = mini(int(minutes.get(player_id, 90)), minute)
				_add_suspension(_player_state(career, player_id), "red")
			"injury":
				var state := _player_state(career, player_id)
				var fallback := _injury_for(career, fixture, player_id)
				state["injury"] = {
					"type": str(event.get("injury_type", fallback["type"])),
					"until": str(event.get("injury_until", fallback["until"])),
				}

	for player in starters:
		var total: Dictionary = blocks[str(player["id"])][0]
		var by_competition: Dictionary = blocks[str(player["id"])][1]
		_bump(total, "apps")
		_bump(total, "starts")
		_bump(by_competition, "apps")
		_bump(by_competition, "starts")
	for player_id in minutes:
		if not blocks.has(player_id):
			continue
		_bump(blocks[player_id][0], "minutes", maxi(0, int(minutes[player_id])))
		_bump(blocks[player_id][1], "minutes", maxi(0, int(minutes[player_id])))

	var score = match.get("score")
	if not (score is Dictionary):
		score = {}
	var goals_against := int(score.get("away" if side == "home" else "home", 0))
	var keeper_id := ""
	for slot in lineup["slots"]:
		if str(slot.get("position", "")) == "GK":
			keeper_id = str(slot["player"].get("id", ""))
			break
	if not keeper_id.is_empty() and blocks.has(keeper_id) and goals_against == 0:
		_bump(blocks[keeper_id][0], "clean_sheets")
		_bump(blocks[keeper_id][1], "clean_sheets")

	for player in starters:
		var state := _player_state(career, player["id"])
		state["fatigue"] = maxi(0, int(state.get("fatigue", 0)) - FATIGUE_PER_MATCH)
	for event in events:
		if str(event.get("type", "")) != "sub":
			continue
		var player_id := str(_dict(event.get("player")).get("id", ""))
		if not player_id.is_empty():
			var state := _player_state(career, player_id)
			state["fatigue"] = maxi(0, int(state.get("fatigue", 0)) - FATIGUE_PER_SUB)

	for player_id in suspended_before:
		var state := _player_state(career, player_id)
		var suspension: Dictionary = state.get("suspension") \
			if state.get("suspension") is Dictionary else {}
		var matches := int(suspension.get("matches", 0)) - 1
		if matches > 0:
			var next: Dictionary = suspension.duplicate()
			next["matches"] = matches
			state["suspension"] = next
		else:
			state["suspension"] = null


static func _player_state(career: Career, player_id) -> Dictionary:
	if not (career.data.get("player_state") is Dictionary):
		career.data["player_state"] = {}
	var states: Dictionary = career.data["player_state"]
	var key := str(player_id)
	if not (states.get(key) is Dictionary):
		states[key] = default_player_state()
	return states[key]


static func _dict(value) -> Dictionary:
	return value if value is Dictionary else {}


static func _injury_for(career: Career, fixture: Dictionary, player_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s:injury:%s" % [
		career.seed, str(fixture.get("id", "")), player_id,
	]).hash()
	var days: int = INJURY_DAYS[rng.randi_range(0, INJURY_DAYS.size() - 1)]
	return {
		"type": INJURY_TYPES[rng.randi_range(0, INJURY_TYPES.size() - 1)],
		"until": CareerSeason.add_days(str(fixture.get("date", "")), days),
	}


static func _add_suspension(state: Dictionary, reason: String) -> void:
	var current := _dict(state.get("suspension"))
	var matches := maxi(1, int(current.get("matches", 0)))
	state["suspension"] = {"matches": matches, "reason": reason}


static func _bump(stats: Dictionary, key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount
