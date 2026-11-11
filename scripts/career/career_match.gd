class_name CareerMatch
extends RefCounted
# Match timeline ported from server/career/match.py (build_match_simulation).
# Pure static math: the caller passes the lineup setup and the final score, so
# this file never reads the database or FootballConstants. RNG streams are keyed
# by `seed + fixture_id`, like the prototype, so a career replays identically.
#
# Setup shape: {home: bool, home_lineup: {slots: [{player}], bench: [player]},
# away_lineup: same}. A player is {id, role, overall?} — the only fields the
# timeline reads.

const EVENT_ORDER := {
	"goal": 0,
	"penalty": 0,
	"yellow": 1,
	"red": 2,
	"injury": 3,
	"sub": 4,
}
const MATCHDAY_BENCH := 7
const CLUB_PREFIXES := ["FC", "AFC", "CF", "AC", "AS", "SV", "SC"]
const ROLE_FAMILY := {
	"GK": 0, "CB": 1, "LB": 1, "RB": 1, "DM": 2,
	"CM": 2, "AM": 2, "LM": 3, "RM": 3, "CF": 4,
}
const INJURY_TYPES := ["Muscle", "Ligaments", "Ankle", "Knee", "Thigh"]
const INJURY_DAYS := [7, 10, 14, 21, 28]


static func build_match_simulation(seed: int, fixture: Dictionary, setup: Dictionary,
		score: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s:timeline" % [seed, str(fixture.get("id", ""))]).hash()
	var final_home := int(score.get("home", 0))
	var final_away := int(score.get("away", 0))
	var events: Array = []

	var subs := {}
	subs["home"] = _substitutions(rng, "home", setup["home_lineup"])
	subs["away"] = _substitutions(rng, "away", setup["away_lineup"])

	var injury_count := _weighted_choice(rng, [0, 1, 2], [64, 29, 7])
	var injured_ids := {}
	var injury_events: Array = []
	for _index in range(injury_count):
		var side: String = ["home", "away"][rng.randi_range(0, 1)]
		var minute := rng.randi_range(12, 86)
		var active := _active_players(setup["%s_lineup" % side], subs[side], minute)
		var candidates: Array = []
		for player in active:
			if not injured_ids.has(str(player["id"])):
				candidates.append(player)
		if candidates.is_empty():
			continue
		var player: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		injured_ids[str(player["id"])] = true
		var days: int = INJURY_DAYS[rng.randi_range(0, INJURY_DAYS.size() - 1)]
		injury_events.append({
			"minute": minute,
			"type": "injury",
			"team": side,
			"player": player,
			"injury_type": INJURY_TYPES[rng.randi_range(0, INJURY_TYPES.size() - 1)],
			"injury_until": add_days(str(fixture.get("date", "")), days),
		})

	var accepted_injuries: Array = []
	for injury in injury_events:
		var side: String = injury["team"]
		var player: Dictionary = injury["player"]
		var minute := int(injury["minute"])
		var side_subs: Array = subs[side]
		var active_ids := {}
		for active in _active_players(setup["%s_lineup" % side], side_subs, minute):
			active_ids[str(active["id"])] = true
		if not active_ids.has(str(player["id"])):
			continue
		accepted_injuries.append(injury)
		if side_subs.size() >= 5:
			continue
		var kept: Array = []
		for event in side_subs:
			var out_player = event.get("player_out")
			if out_player is Dictionary \
					and str(out_player.get("id", "")) == str(player["id"]) \
					and int(event["minute"]) > minute:
				continue
			kept.append(event)
		side_subs = kept
		subs[side] = side_subs
		var incoming := {}
		for event in side_subs:
			var in_player = event.get("player")
			if in_player is Dictionary:
				incoming[str(in_player.get("id", ""))] = true
		var replacement := _replacement_for(
			setup["%s_lineup" % side]["bench"], player.get("role"), incoming)
		if replacement.is_empty():
			continue
		side_subs.append({
			"minute": minute,
			"type": "sub",
			"team": side,
			"player": replacement,
			"player_out": player,
		})

	for side in ["home", "away"]:
		subs[side].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["minute"]) < int(b["minute"]))
		events.append_array(subs[side])
	events.append_array(accepted_injuries)

	var goal_sides: Array = []
	for _index in range(final_home):
		goal_sides.append("home")
	for _index in range(final_away):
		goal_sides.append("away")
	_shuffle(rng, goal_sides)
	for side in goal_sides:
		var minute := rng.randi_range(1, 90)
		var active := _active_players(setup["%s_lineup" % side], subs[side], minute)
		var scorer := _pick_weighted(rng, active, _scorer_weight)
		if scorer.is_empty():
			continue
		var event_type := "penalty" if rng.randf() < 0.14 else "goal"
		var assist = null
		if event_type == "goal":
			var candidates: Array = []
			for player in active:
				if str(player["id"]) != str(scorer["id"]):
					candidates.append(player)
			assist = _pick_weighted(rng, candidates, _assist_weight)
			if assist.is_empty():
				assist = null
		events.append({
			"minute": minute,
			"type": event_type,
			"team": side,
			"player": scorer,
			"assist": assist,
		})

	for side in ["home", "away"]:
		var active := _active_players(setup["%s_lineup" % side], subs[side], 0)
		var carded := {}
		var yellows := _weighted_choice(rng, [0, 1, 2, 3, 4], [40, 30, 17, 9, 4])
		for _index in range(yellows):
			var minute := rng.randi_range(18, 89)
			var candidates: Array = []
			for player in _active_players(setup["%s_lineup" % side], subs[side], minute):
				if not carded.has(str(player["id"])):
					candidates.append(player)
			if candidates.is_empty():
				continue
			var player: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
			carded[str(player["id"])] = true
			events.append({"minute": minute, "type": "yellow", "team": side, "player": player})
		if not active.is_empty() and rng.randf() < 0.08:
			var minute := rng.randi_range(25, 89)
			var candidates: Array = []
			for player in _active_players(setup["%s_lineup" % side], subs[side], minute):
				if not carded.has(str(player["id"])):
					candidates.append(player)
			if not candidates.is_empty():
				var player: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
				events.append({"minute": minute, "type": "red", "team": side, "player": player})

	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var minute_a := int(a["minute"])
		var minute_b := int(b["minute"])
		if minute_a != minute_b:
			return minute_a < minute_b
		var order_a := int(EVENT_ORDER.get(str(a["type"]), 9))
		var order_b := int(EVENT_ORDER.get(str(b["type"]), 9))
		if order_a != order_b:
			return order_a < order_b
		return _player_id(a) < _player_id(b))
	var fixture_id := str(fixture.get("id", ""))
	for index in range(events.size()):
		events[index]["id"] = "%s-e%02d" % [fixture_id, index + 1]

	var home := bool(setup.get("home", false))
	var goals_for := final_home if home else final_away
	var goals_against := final_away if home else final_home
	var outcome := "W" if goals_for > goals_against else ("D" if goals_for == goals_against else "L")
	var result := setup.duplicate(true)
	result["events"] = events
	result["score"] = {"home": final_home, "away": final_away}
	result["outcome"] = outcome
	result["goals_for"] = goals_for
	result["goals_against"] = goals_against
	return result


static func add_days(iso_date: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(iso_date + "T00:00:00")
	return Time.get_datetime_string_from_unix_time(int(unix) + days * 86400, false).substr(0, 10)


static func club_abbr(name: String) -> String:
	var regex := RegEx.new()
	regex.compile("[A-Za-z0-9]+")
	var words: Array = []
	for match in regex.search_all(name):
		words.append(match.get_string())
	if words.is_empty():
		return "???"
	var word := str(words[0])
	if word.to_upper() in CLUB_PREFIXES and words.size() > 1:
		word = str(words[1])
	return word.substr(0, 3).to_upper()


static func player_ref(player: Dictionary) -> Dictionary:
	var last_name = player.get("last_name")
	if last_name == null or str(last_name).is_empty():
		last_name = player.get("lastname")
	return {
		"id": str(player.get("id", "")),
		"name": str(player.get("name", "")),
		"last_name": last_name,
		"shirt_number": player.get("shirt_number"),
		"role": player.get("role"),
		"rating": int(round(float(player.get("overall", 0.0)))),
	}


static func build_lineup(players: Array, order: Array = [], bench_order: Array = [],
		blocked_ids: Array = [], formation := CareerFormations.DEFAULT) -> Dictionary:
	var normalized := CareerFormations.normalize(formation)
	var template := CareerFormations.slots(normalized)
	var blocked := {}
	for player_id in blocked_ids:
		blocked[str(player_id)] = true
	var by_id := {}
	for player in players:
		by_id[str(player.get("id", ""))] = player
	var available: Array = []
	for player in players:
		if not blocked.has(str(player.get("id", ""))):
			available.append(player)
	var order_ids: Array = []
	for player_id in order:
		order_ids.append(str(player_id))
	var starters: Array = []
	var used := {}
	for index in range(template.size()):
		var slot: Dictionary = template[index]
		var player := {}
		if index < order_ids.size():
			var candidate = by_id.get(order_ids[index])
			if candidate is Dictionary \
					and not blocked.has(str(candidate.get("id", ""))) \
					and not used.has(str(candidate.get("id", ""))):
				player = candidate
		if player.is_empty():
			player = _pick_player(available, slot.get("roles", []), used)
		if player.is_empty():
			break
		starters.append(player)
		used[str(player.get("id", ""))] = true
	var slots: Array = []
	for index in range(starters.size()):
		var slot: Dictionary = template[index]
		slots.append({
			"position": str(slot.get("position", "")),
			"role": str(slot.get("role", "")),
			"x": int(slot.get("x", 50)),
			"y": int(slot.get("y", 50)),
			"player": player_ref(starters[index]),
		})
	var bench_players: Array = []
	for player in players:
		if not used.has(str(player.get("id", ""))):
			bench_players.append(player)
	var bench: Array = []
	if not bench_order.is_empty():
		var benched := {}
		for player in bench_players:
			benched[str(player.get("id", ""))] = player
		for player_id in bench_order:
			var key := str(player_id)
			if benched.has(key):
				bench.append(benched[key])
				benched.erase(key)
		var rest: Array = benched.values()
		rest.sort_custom(_overall_desc)
		bench.append_array(rest)
	else:
		bench = bench_players.duplicate()
		bench.sort_custom(_overall_desc)
	var bench_refs: Array = []
	for player in bench:
		if blocked.has(str(player.get("id", ""))):
			continue
		bench_refs.append(player_ref(player))
		if bench_refs.size() >= MATCHDAY_BENCH:
			break
	return {
		"formation": normalized,
		"formation_label": CareerFormations.label(normalized),
		"slots": slots,
		"bench": bench_refs,
	}


static func build_match_setup(career: Career, fixture: Dictionary, competition: String,
		clubs: Dictionary, home_lineup: Dictionary, away_lineup: Dictionary) -> Dictionary:
	var home: Dictionary = clubs.get(str(fixture.get("home", "")), {})
	var away: Dictionary = clubs.get(str(fixture.get("away", "")), {})
	return {
		"fixture_id": str(fixture.get("id", "")),
		"round": int(fixture.get("round", 0)),
		"date": str(fixture.get("date", "")),
		"home": str(fixture.get("home", "")) == career.club_id,
		"competition": competition,
		"home_team": _team_ref(home),
		"away_team": _team_ref(away),
		"home_lineup": home_lineup,
		"away_lineup": away_lineup,
	}


static func _team_ref(club: Dictionary) -> Dictionary:
	var name := str(club.get("name", ""))
	return {
		"id": str(club.get("id", "")),
		"name": name,
		"logo": _club_logo(club),
		"abbr": club_abbr(name),
	}


static func _club_logo(club: Dictionary) -> String:
	var career_logo := str(club.get("career_logo", ""))
	return career_logo if not career_logo.is_empty() else str(club.get("logo", ""))


static func _pick_player(players: Array, preferred_roles: Array, used: Dictionary) -> Dictionary:
	var available: Array = []
	for player in players:
		if not used.has(str(player.get("id", ""))):
			available.append(player)
	for role in preferred_roles:
		var candidates: Array = []
		for player in available:
			if str(player.get("role", "")) == str(role):
				candidates.append(player)
		if not candidates.is_empty():
			return _best_overall(candidates)
	var outfield: Array = []
	for player in available:
		if str(player.get("role", "")) != "GK":
			outfield.append(player)
	if outfield.is_empty():
		outfield = available
	return _best_overall(outfield)


static func _best_overall(players: Array) -> Dictionary:
	var best := {}
	var best_overall := -1.0
	for player in players:
		var overall := float(player.get("overall", 0.0))
		if overall > best_overall:
			best = player
			best_overall = overall
	return best


static func _overall_desc(a: Dictionary, b: Dictionary) -> bool:
	var overall_a := float(a.get("overall", 0.0))
	var overall_b := float(b.get("overall", 0.0))
	if not is_equal_approx(overall_a, overall_b):
		return overall_a > overall_b
	return str(a.get("id", "")) < str(b.get("id", ""))


static func _scorer_weight(player: Dictionary) -> float:
	var role := str(player.get("role", ""))
	if role == "GK":
		return 0.0
	if role == "CF":
		return 6.0
	if role in ["AM", "LM", "RM"]:
		return 3.0
	if role in ["CM", "DM"]:
		return 1.4
	return 0.6


static func _assist_weight(player: Dictionary) -> float:
	var role := str(player.get("role", ""))
	if role == "GK":
		return 0.0
	if role in ["AM", "LM", "RM"]:
		return 5.0
	if role in ["CM", "CF"]:
		return 3.0
	if role == "DM":
		return 1.2
	return 0.5


static func _pick_weighted(rng: RandomNumberGenerator, players: Array,
		weight_for: Callable) -> Dictionary:
	var weighted: Array = []
	for player in players:
		var weight: float = weight_for.call(player)
		if weight > 0.0:
			weighted.append([player, weight])
	if weighted.is_empty():
		return players[0] if not players.is_empty() else {}
	var total := 0.0
	for pair in weighted:
		total += float(pair[1])
	var point := rng.randf() * total
	var upto := 0.0
	for pair in weighted:
		upto += float(pair[1])
		if point <= upto:
			return pair[0]
	return weighted[-1][0]


static func _weighted_choice(rng: RandomNumberGenerator, values: Array, weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += float(weight)
	var point := rng.randf() * total
	var upto := 0.0
	for index in range(values.size()):
		upto += float(weights[index])
		if point < upto:
			return int(values[index])
	return int(values[-1])


static func _replacement_for(bench: Array, role, used_ids: Dictionary) -> Dictionary:
	var best := {}
	var best_key: Array = []
	for player in bench:
		if not (player is Dictionary) or used_ids.has(str(player.get("id", ""))):
			continue
		var candidate_role := str(player.get("role", ""))
		var key: Array
		if candidate_role == str(role):
			key = [0, -float(player.get("overall", 0.0))]
		elif str(role) == "GK" or candidate_role == "GK":
			key = [9, -float(player.get("overall", 0.0))]
		else:
			var distance: int = absi(
				int(ROLE_FAMILY.get(candidate_role, 2)) - int(ROLE_FAMILY.get(str(role), 2)))
			key = [1 + distance, -float(player.get("overall", 0.0))]
		if best.is_empty() or _key_less(key, best_key):
			best = player
			best_key = key
	return best


static func _key_less(a: Array, b: Array) -> bool:
	if int(a[0]) != int(b[0]):
		return int(a[0]) < int(b[0])
	return float(a[1]) < float(b[1])


static func _substitutions(rng: RandomNumberGenerator, team: String, lineup: Dictionary) -> Array:
	var starters: Array = []
	for slot in lineup["slots"]:
		starters.append(slot["player"])
	var bench: Array = []
	for player in lineup["bench"]:
		if str(player.get("role", "")) != "GK":
			bench.append(player)
	if bench.size() < 2:
		return []
	var outfield: Array = []
	for player in starters:
		if str(player.get("role", "")) != "GK":
			outfield.append(player)
	if outfield.size() < 2:
		return []
	var count := rng.randi_range(2, mini(4, mini(outfield.size(), bench.size())))
	var minute_pool: Array = []
	for minute in range(55, 86):
		minute_pool.append(minute)
	var minutes := _sample(rng, minute_pool, count)
	minutes.sort()
	var outgoing := _sample(rng, outfield, count)
	var incoming := _sample(rng, bench, count)
	var events: Array = []
	for index in range(count):
		events.append({
			"minute": minutes[index],
			"type": "sub",
			"team": team,
			"player": incoming[index],
			"player_out": outgoing[index],
		})
	return events


static func _active_players(lineup: Dictionary, subs: Array, minute: int) -> Array:
	var out_at := {}
	var in_at := {}
	for event in subs:
		var out_player = event.get("player_out")
		if out_player is Dictionary:
			out_at[str(out_player.get("id", ""))] = int(event["minute"])
		var in_player = event.get("player")
		if in_player is Dictionary:
			in_at[str(in_player.get("id", ""))] = int(event["minute"])
	var players: Array = []
	for slot in lineup["slots"]:
		var player: Dictionary = slot["player"]
		var player_id := str(player["id"])
		if out_at.has(player_id) and minute >= int(out_at[player_id]):
			continue
		players.append(player)
	for player in lineup["bench"]:
		var player_id := str(player.get("id", ""))
		if in_at.has(player_id) and minute >= int(in_at[player_id]):
			players.append(player)
	return players


static func _sample(rng: RandomNumberGenerator, population: Array, count: int) -> Array:
	var pool := population.duplicate()
	for index in range(mini(count, pool.size())):
		var swap_index := rng.randi_range(index, pool.size() - 1)
		var value = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = value
	return pool.slice(0, mini(count, pool.size()))


static func _shuffle(rng: RandomNumberGenerator, values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value


static func _player_id(event: Dictionary) -> String:
	var player = event.get("player")
	return str(player.get("id", "")) if player is Dictionary else ""
