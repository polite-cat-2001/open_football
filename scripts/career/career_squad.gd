class_name CareerSquad
extends RefCounted
# Career squad read model and lineup actions, ported from
# server/career/{snapshot,squad,formations}.py. The snapshot feeds the Squad
# screen (lineup, bench, reserve, formations, roles); the action helpers mirror
# the prototype's swap/formation/role endpoints and write through to the career.

const MATCHDAY_BENCH := 7
const ROLE_ORDER := {
	"GK": 0, "CB": 1, "LB": 2, "RB": 3, "DM": 4, "CM": 5,
	"LM": 6, "RM": 7, "AM": 8, "CF": 9,
}
const LINE_BY_ROLE := {
	"GK": "GK", "CB": "DEF", "LB": "DEF", "RB": "DEF", "DM": "MID",
	"CM": "MID", "LM": "MID", "RM": "MID", "AM": "MID", "CF": "ATT",
}
const LINE_BY_POSITION := {
	"GK": "GK", "LB": "DEF", "CB": "DEF", "RB": "DEF", "DM": "MID",
	"CM": "MID", "LM": "MID", "RM": "MID", "AM": "MID", "LW": "ATT",
	"RW": "ATT", "ST": "ATT", "CF": "ATT",
}
const SQUAD_ROLE_IDS := ["key", "first", "rotation", "squad", "prospect"]
const SQUAD_ROLE_LABELS := {
	"key": ["KEY PLAYER", "KEY"],
	"first": ["FIRST TEAM", "FIRST"],
	"rotation": ["ROTATION", "ROTATION"],
	"squad": ["SQUAD PLAYER", "SQUAD"],
	"prospect": ["PROSPECT", "PROSPECT"],
}
const SQUAD_ROLE_SHARE := {
	"key": 0.85, "first": 0.65, "rotation": 0.45, "squad": 0.25,
	"prospect": 0.10,
}
const ROLE_THRESHOLDS := [
	[0.11, "key"], [0.32, "first"], [0.57, "rotation"],
	[0.82, "squad"], [1.01, "prospect"],
]
const DEFAULT_ROLE := "rotation"
const MIN_MARKET_VALUE := 50000
const VALUE_AGE_FACTORS := [
	[21, 1.15], [24, 1.08], [27, 1.02], [30, 0.94], [33, 0.84], [99, 0.68],
]
const MAX_SHIRT_NUMBER := 99
const WAGE_COVER_WEEKS := 4
const MIN_WEEKLY_WAGE := 1000
const STARTING_BALANCE_MIN := 1000000
const STARTING_BALANCE_RATIO := 0.25

const STAT_LABELS := {
	"mental_calmness": "Calmness",
	"mental_defensivepositioning": "Def. positioning",
	"mental_offensivepositioning": "Off. positioning",
	"mental_resilience": "Resilience",
	"mental_vision": "Vision",
	"mental_workrate": "Work rate",
	"physical_acceleration": "Acceleration",
	"physical_agility": "Agility",
	"physical_balance": "Balance",
	"physical_reaction": "Reaction",
	"physical_shotpower": "Shot power",
	"physical_stamina": "Stamina",
	"physical_velocity": "Velocity",
	"technical_ballcontrol": "Ball control",
	"technical_dribble": "Dribbling",
	"technical_header": "Heading",
	"technical_highpass": "Long passing",
	"technical_shortpass": "Short passing",
	"technical_shot": "Shooting",
	"technical_slidingtackle": "Sliding tackle",
	"technical_standingtackle": "Standing tackle",
	"technical_volley": "Volley",
}

const ATTRIBUTE_GROUPS := [
	{
		"id": "mental", "label": "MENTAL",
		"keys": ["mental_calmness", "mental_defensivepositioning",
			"mental_offensivepositioning", "mental_resilience", "mental_vision",
			"mental_workrate"],
	},
	{
		"id": "physical", "label": "PHYSICAL",
		"keys": ["physical_acceleration", "physical_agility", "physical_balance",
			"physical_reaction", "physical_shotpower", "physical_stamina",
			"physical_velocity"],
	},
	{
		"id": "technical", "label": "TECHNICAL",
		"keys": ["technical_ballcontrol", "technical_dribble", "technical_header",
			"technical_highpass", "technical_shortpass", "technical_shot",
			"technical_slidingtackle", "technical_standingtackle",
			"technical_volley"],
	},
]

const RADAR_AXES := [
	{"label": "PACE", "keys": ["physical_velocity", "physical_acceleration"]},
	{"label": "SHOT", "keys": ["technical_shot", "physical_shotpower",
		"technical_volley"]},
	{"label": "PASS", "keys": ["technical_shortpass", "technical_highpass",
		"mental_vision"]},
	{"label": "DRIBBLE", "keys": ["technical_ballcontrol", "technical_dribble",
		"physical_agility"]},
	{"label": "DEFENCE", "keys": ["technical_standingtackle",
		"technical_slidingtackle", "mental_defensivepositioning"]},
	{"label": "PHYS", "keys": ["physical_stamina", "physical_resilience",
		"physical_reaction"]},
]

static var last_error := ""


static func roster(catalog: TeamCatalog, career: Career, club_id, with_stats := false) -> Array:
	# The database squad plus the career's own movements. `players.team_id` is
	# read-only and never changes, so a signing, a sale or an AI transfer only
	# exists in `career.club_deltas`; reading the database alone shows a squad
	# that ignored every transfer.
	if catalog == null or career == null:
		return []
	var base := catalog.career_squad(int(club_id), with_stats)
	if base.is_empty():
		return base
	return CareerWorldMarket.effective_players(career, club_id, base,
		func(ids: Array) -> Array:
			return catalog.career_players_by_ids(ids, with_stats))


static func snapshot(catalog: TeamCatalog, career: Career) -> Dictionary:
	last_error = ""
	if catalog == null or career == null:
		last_error = "career squad data is unavailable"
		return {}
	var players := roster(catalog, career, career.club_id, true)
	if players.is_empty():
		last_error = "the career squad is missing from the database"
		return {}
	var squad := enrich_players(career, players)
	squad = _sort_players(squad)
	var blocked := CareerCondition.blocked_player_ids(career)
	var raw := lineup_for(squad, career.lineup, career.bench_order, blocked,
		career.formation, MATCHDAY_BENCH)
	var starters: Array = []
	for slot in raw.get("slots", []):
		starters.append(slot.get("player", {}))
	var roles := CareerRoles.role_assignments(career, starters)
	return {
		"summary": _summary(squad),
		"finance": finance_view(career, squad),
		"groups": _groups(squad),
		"players": squad,
		"formations": CareerFormations.catalog(),
		"roles": roles,
		"lineup": raw,
		"blocked": blocked,
	}


static func wage_fund_ok(career: Career, replace_id := "", weekly_wage := -1) -> bool:
	# One rule for both doors: a renewal and a transfer contract must fit four
	# weeks of the resulting bill into the balance. `replace_id`/`weekly_wage`
	# swap one contract out for the terms being negotiated, so a renewal does not
	# count the old wage twice; with no replace id the wage is an addition.
	if career == null or career.balance == null:
		return true
	var total := 0
	for player_id in career.player_ids:
		var contract = career.player_contracts.get(str(player_id))
		if contract is Dictionary:
			total += int(contract.get("weekly_wage", 0))
	if not str(replace_id).is_empty() and career.player_ids.has(str(replace_id)):
		var current = career.player_contracts.get(str(replace_id))
		if current is Dictionary:
			total -= int(current.get("weekly_wage", 0))
	if weekly_wage >= 0:
		total += int(weekly_wage)
	return total * WAGE_COVER_WEEKS <= int(career.balance)


static func ensure_finances(career: Career, players: Array) -> void:
	last_error = ""
	if players.is_empty():
		return
	var values: Dictionary = career.player_values
	var ages: Dictionary = career.player_ages
	for player in players:
		var player_id := str(player.get("id", ""))
		var value := maxi(MIN_MARKET_VALUE, int(player.get("market_value", 0)))
		values[player_id] = value
		if not ages.has(player_id):
			ages[player_id] = _player_age(player)
		player["market_value"] = value
		player["age"] = int(ages[player_id])
	career.player_values = values
	career.player_ages = ages
	if career.balance == null:
		var total := 0
		for player in players:
			total += int(player.get("market_value", 0))
		career.balance = maxi(STARTING_BALANCE_MIN,
			_round_money(float(total) * STARTING_BALANCE_RATIO))
	_ensure_contracts(career, players)
	_ensure_shirt_numbers(career, players)


static func rollover_values(career: Career, players: Array) -> void:
	# The prototype's season rollover: +1 year and a fresh value from age,
	# overall and the minutes played last season (squad.py rollover_player_values).
	ensure_finances(career, players)
	var values: Dictionary = career.player_values
	var ages: Dictionary = career.player_ages
	var states: Dictionary = career.data.get("player_state", {})
	for player in players:
		var player_id := str(player.get("id", ""))
		var age := int(ages.get(player_id, _player_age(player))) + 1
		var value := maxi(MIN_MARKET_VALUE, int(values.get(player_id,
			player.get("market_value", 0))))
		var state: Dictionary = states.get(player_id) if states.get(player_id) is Dictionary else {}
		var stats: Dictionary = state.get("stats", {}) if state.get("stats") is Dictionary else {}
		var ratio := 0.0
		var expected := int(state.get("expected_minutes", 0))
		var minutes_factor := 1.0
		if expected > 0:
			ratio = clampf(float(stats.get("minutes", 0)) / float(expected), 0.0, 2.0)
			minutes_factor = 0.85 + 0.15 * ratio
		var rolled := float(value) * _age_value_factor(age) \
			* _ovr_value_factor(player.get("overall")) * minutes_factor
		values[player_id] = maxi(MIN_MARKET_VALUE, _round_money(rolled))
		ages[player_id] = age
		player["market_value"] = values[player_id]
		player["age"] = age
	career.player_values = values
	career.player_ages = ages


static func _age_value_factor(age: int) -> float:
	for pair in VALUE_AGE_FACTORS:
		if age <= int(pair[0]):
			return float(pair[1])
	return float(VALUE_AGE_FACTORS[-1][1])


static func _ovr_value_factor(overall) -> float:
	return maxf(0.8, minf(1.25, 1.0 + (float(overall if overall != null else 0.0) - 70.0) * 0.01))


static func _ensure_contracts(career: Career, players: Array) -> void:
	var ranked: Array = players.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.get("overall", 0.0)),
				float(b.get("overall", 0.0))):
			return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
		if str(a.get("name", "")) != str(b.get("name", "")):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return str(a.get("id", "")) < str(b.get("id", "")))
	var ranks := {}
	for index in range(ranked.size()):
		ranks[str(ranked[index].get("id", ""))] = index
	var total := ranked.size()
	var contracts: Dictionary = career.player_contracts
	for player in players:
		var player_id := str(player.get("id", ""))
		var contract: Dictionary = contracts.get(player_id) \
			if contracts.get(player_id) is Dictionary else {}
		if not SQUAD_ROLE_SHARE.has(str(contract.get("squad_role", ""))):
			contract["squad_role"] = _role_for_rank(int(ranks.get(player_id, 0)), total)
		if int(contract.get("years", 0)) <= 0:
			contract["years"] = _contract_years(career, player, player_id)
		if int(contract.get("weekly_wage", 0)) <= 0:
			contract["weekly_wage"] = _weekly_wage(career, player, player_id)
		if int(contract.get("release_clause", 0)) <= 0:
			contract["release_clause"] = _release_clause(career, player, player_id)
		contracts[player_id] = contract
	career.player_contracts = contracts


static func ensure_shirt_numbers(career: Career, players: Array) -> void:
	# Used after a signing: the new player has to get a free number immediately.
	_ensure_shirt_numbers(career, players)


static func _ensure_shirt_numbers(career: Career, players: Array) -> void:
	var ordered: Array = players.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", "")))
	var assigned := {}
	var used := {}
	var current: Dictionary = career.shirt_numbers
	for player in ordered:
		var player_id := str(player.get("id", ""))
		var number = current.get(player_id)
		if number != null and int(number) >= 1 and int(number) <= MAX_SHIRT_NUMBER \
				and not used.has(int(number)):
			assigned[player_id] = int(number)
			used[int(number)] = true
	for player in ordered:
		var player_id := str(player.get("id", ""))
		if assigned.has(player_id):
			continue
		var canon = player.get("shirt_number")
		if canon == null:
			continue
		var number := int(canon)
		if number >= 1 and number <= MAX_SHIRT_NUMBER and not used.has(number):
			assigned[player_id] = number
			used[number] = true
	var free: Array = []
	for number in range(1, MAX_SHIRT_NUMBER + 1):
		if not used.has(number):
			free.append(number)
	var cursor := 0
	for player in ordered:
		var player_id := str(player.get("id", ""))
		if assigned.has(player_id):
			continue
		if cursor >= free.size():
			break
		assigned[player_id] = int(free[cursor])
		cursor += 1
	career.shirt_numbers = assigned


static func _player_age(player: Dictionary) -> int:
	var age = player.get("age")
	return int(age) if age != null else 25


static func _rng(career: Career, player_id: String, salt: String) -> CareerRng:
	return CareerRng.seeded("%d:contract:%s:%s" % [career.seed, player_id, salt])


static func _contract_years(career: Career, player: Dictionary, player_id: String) -> int:
	var age := _player_age(player)
	var options: Array
	if age <= 21:
		options = [4, 5]
	elif age <= 24:
		options = [3, 4, 5]
	elif age <= 27:
		options = [2, 3, 4]
	elif age <= 30:
		options = [2, 3]
	else:
		options = [1, 2]
	var rng := _rng(career, player_id, "years")
	return int(rng.choice(options))


static func _weekly_wage(career: Career, player: Dictionary, player_id: String) -> int:
	var value := maxi(MIN_MARKET_VALUE, int(player.get("market_value", 0)))
	var age := _player_age(player)
	var age_factor := 1.1
	if age > 31:
		age_factor = 0.8
	elif age > 28:
		age_factor = 0.9
	elif age > 23:
		age_factor = 1.0
	var rng := _rng(career, player_id, "wage")
	var jitter := rng.uniform(0.9, 1.1)
	var weekly := float(value) * 0.12 * age_factor * jitter / 52.0
	return maxi(MIN_WEEKLY_WAGE, CareerRng.python_round(weekly / 100.0) * 100)


static func _release_clause(career: Career, player: Dictionary, player_id: String) -> int:
	var value := maxi(MIN_MARKET_VALUE, int(player.get("market_value", 0)))
	var rng := _rng(career, player_id, "clause")
	var multiplier := rng.uniform(1.2, 2.0)
	var rounded := _round_money(float(value) * multiplier)
	return maxi(int(float(value) * 1.2), mini(int(float(value) * 2.0), rounded))


static func _round_money(value: float) -> int:
	var step := 100
	if value >= 1000000.0:
		step = 100000
	elif value >= 100000.0:
		step = 10000
	elif value >= 10000.0:
		step = 1000
	return maxi(step, CareerRng.python_round(value / float(step)) * step)


static func enrich_players(career: Career, players: Array) -> Array:
	var states: Dictionary = career.data.get("player_state", {})
	var contracts: Dictionary = career.data.get("player_contracts", {})
	var numbers: Dictionary = career.data.get("shirt_numbers", {})
	var ranks := _squad_role_ranks(players)
	var total := players.size()
	var enriched: Array = []
	for player in players:
		var copy: Dictionary = player.duplicate(true)
		var player_id := str(copy.get("id", ""))
		var state: Dictionary = states.get(player_id) if states.get(player_id) is Dictionary else {}
		var stats: Dictionary = state.get("stats", {}) if state.get("stats") is Dictionary else {}
		var contract: Dictionary = contracts.get(player_id) if contracts.get(player_id) is Dictionary else {}
		var fatigue := int(state.get("fatigue", 100))
		var overall := float(copy.get("overall", 0.0))
		var effective := roundf(overall * _fatigue_factor(fatigue) * 10.0) / 10.0
		var role_id := _role_for_rank(int(ranks.get(player_id, 0)), total)
		if SQUAD_ROLE_SHARE.has(str(contract.get("squad_role", ""))):
			role_id = str(contract.get("squad_role"))
		var role_labels: Array = SQUAD_ROLE_LABELS.get(role_id, SQUAD_ROLE_LABELS[DEFAULT_ROLE])
		var expected_minutes := int(state.get("expected_minutes", 0))
		var actual_minutes := int(stats.get("minutes", 0))
		copy["fatigue"] = fatigue
		copy["injury"] = state.get("injury")
		copy["suspension"] = state.get("suspension")
		copy["available"] = not (state.get("injury") != null) \
			and int(_dict(state.get("suspension")).get("matches", 0)) <= 0
		copy["season_stats"] = _season_stats(stats)
		copy["stats"] = copy.get("stats", {}) if copy.get("stats") is Dictionary else {}
		copy["effective_overall"] = effective
		copy["squad_role"] = role_id
		copy["squad_role_label"] = role_labels[0]
		copy["squad_role_short"] = role_labels[1]
		copy["expected_share"] = float(SQUAD_ROLE_SHARE.get(role_id, 0.45))
		copy["expected_minutes"] = expected_minutes
		copy["actual_minutes"] = actual_minutes
		copy["morale"] = _morale_percent(actual_minutes, expected_minutes)
		var shirt = numbers.get(player_id)
		if shirt != null:
			copy["shirt_number"] = int(shirt)
		copy["contract"] = {
			"years": int(contract.get("years", 1)),
			"weekly_wage": int(contract.get("weekly_wage", 0)),
			"release_clause": int(contract.get("release_clause", 0)),
		}
		enriched.append(copy)
	return enriched


static func lineup_for(players: Array, order: Array = [], bench_order: Array = [],
		blocked_ids: Array = [], formation := CareerFormations.DEFAULT,
		bench_limit := -1) -> Dictionary:
	var normalized := CareerFormations.normalize(str(formation))
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
		var player: Dictionary = {}
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
			"player": starters[index],
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
		bench.append_array(_stable_overall_desc(benched.values()))
	else:
		bench = _stable_overall_desc(bench_players)
	if bench_limit < 0:
		return {
			"formation": normalized,
			"formation_label": CareerFormations.label(normalized),
			"slots": slots,
			"bench": bench,
			"reserve": [],
		}
	var matchday: Array = []
	for player in bench:
		if blocked.has(str(player.get("id", ""))):
			continue
		matchday.append(player)
		if matchday.size() >= bench_limit:
			break
	var picked := {}
	for player in matchday:
		picked[str(player.get("id", ""))] = true
	var reserve: Array = []
	for player in bench:
		if not picked.has(str(player.get("id", ""))):
			reserve.append(player)
	return {
		"formation": normalized,
		"formation_label": CareerFormations.label(normalized),
		"slots": slots,
		"bench": matchday,
		"reserve": reserve,
	}


static func preview_lineup(lineup: Dictionary, formation: String) -> Dictionary:
	var normalized := CareerFormations.normalize(formation)
	if lineup.is_empty() or str(lineup.get("formation", "")) == normalized:
		return lineup
	var slots: Array = lineup.get("slots", [])
	if slots.is_empty():
		return lineup
	var keeper: Dictionary = slots[0]
	for slot in slots:
		if str(slot.get("position", "")) == "GK":
			keeper = slot
			break
	var keeper_id := str(_dict(keeper.get("player")).get("id", ""))
	var outfield: Array = []
	for slot in slots:
		var player: Dictionary = _dict(slot.get("player"))
		if str(player.get("id", "")) != keeper_id:
			outfield.append(player)
		if outfield.size() >= 10:
			break
	var template := CareerFormations.slots(normalized)
	var outfield_slots: Array = []
	for slot in template:
		if str(slot.get("position", "")) != "GK":
			outfield_slots.append(slot)
	var by_id := {}
	for slot in slots:
		var player: Dictionary = _dict(slot.get("player"))
		by_id[str(player.get("id", ""))] = player
	var order := _assign_players(outfield, outfield_slots)
	var next: Array = []
	var outfield_index := 0
	for slot in template:
		var player: Dictionary = {}
		if str(slot.get("position", "")) == "GK":
			player = _dict(keeper.get("player"))
		else:
			var player_id := str(order[outfield_index]) if outfield_index < order.size() else ""
			outfield_index += 1
			player = _dict(by_id.get(player_id))
		next.append({
			"position": str(slot.get("position", "")),
			"role": str(slot.get("role", "")),
			"x": int(slot.get("x", 50)),
			"y": int(slot.get("y", 50)),
			"player": player,
		})
	var copy: Dictionary = lineup.duplicate(true)
	copy["formation"] = normalized
	copy["formation_label"] = CareerFormations.label(normalized)
	copy["slots"] = next
	return copy


static func arrange_lineup(current_slots: Array, formation: String) -> Array:
	if current_slots.is_empty():
		return []
	var keeper: Dictionary = current_slots[0]
	for slot in current_slots:
		if str(slot.get("position", "")) == "GK":
			keeper = slot
			break
	var keeper_id := str(_dict(keeper.get("player")).get("id", ""))
	var outfield: Array = []
	for slot in current_slots:
		var player: Dictionary = _dict(slot.get("player"))
		if str(player.get("id", "")) != keeper_id:
			outfield.append(player)
		if outfield.size() >= 10:
			break
	var outfield_slots: Array = []
	for slot in CareerFormations.slots(formation):
		if str(slot.get("position", "")) != "GK":
			outfield_slots.append(slot)
	var order := _assign_players(outfield, outfield_slots)
	var result: Array = [keeper_id]
	result.append_array(order)
	return result


static func swap_players(career: Career, players: Array, player_a: String,
		player_b: String) -> bool:
	last_error = ""
	if str(player_a) == str(player_b):
		last_error = "choose two different players"
		return false
	var ids: Array = []
	for player in players:
		ids.append(str(player.get("id", "")))
	if not ids.has(str(player_a)) or not ids.has(str(player_b)):
		last_error = "player is not in this squad"
		return false
	CareerCondition.ensure_player_states(career, ids)
	CareerCondition.recover_condition(career, career.date)
	var blocked := CareerCondition.blocked_player_ids(career)
	if blocked.has(str(player_a)) or blocked.has(str(player_b)):
		last_error = "player is unavailable"
		return false
	var lineup := lineup_for(players, career.lineup, career.bench_order, blocked,
		career.formation, -1)
	var starters: Array = []
	for slot in lineup.get("slots", []):
		starters.append(str(_dict(slot.get("player")).get("id", "")))
	var bench: Array = []
	for player in lineup.get("bench", []):
		bench.append(str(player.get("id", "")))
	var slot_a := starters.find(str(player_a))
	var slot_b := starters.find(str(player_b))
	var bench_a := bench.find(str(player_a))
	var bench_b := bench.find(str(player_b))
	if slot_a >= 0 and slot_b >= 0:
		var swap = starters[slot_a]
		starters[slot_a] = starters[slot_b]
		starters[slot_b] = swap
		career.lineup = starters
	elif slot_a >= 0 or slot_b >= 0:
		var starter_id := str(player_a) if slot_a >= 0 else str(player_b)
		var bench_id := str(player_b) if slot_a >= 0 else str(player_a)
		var slot := slot_a if slot_a >= 0 else slot_b
		var bench_index := bench.find(bench_id)
		if bench_index < 0:
			last_error = "player is not in this squad"
			return false
		starters[slot] = bench_id
		bench[bench_index] = starter_id
		career.lineup = starters
		career.bench_order = bench
	else:
		if bench_a < 0 or bench_b < 0:
			last_error = "player is not in this squad"
			return false
		var swap = bench[bench_a]
		bench[bench_a] = bench[bench_b]
		bench[bench_b] = swap
		career.bench_order = bench
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": "lineup.swap",
		"payload": {"player_a": str(player_a), "player_b": str(player_b)},
	})
	return true


static func set_formation(career: Career, players: Array, formation: String) -> bool:
	last_error = ""
	if not CareerFormations.FORMATIONS.has(formation):
		last_error = "unknown formation"
		return false
	if career.formation == formation:
		return true
	var blocked := CareerCondition.blocked_player_ids(career)
	var lineup := lineup_for(players, career.lineup, career.bench_order, blocked,
		career.formation, -1)
	career.lineup = arrange_lineup(lineup.get("slots", []), formation)
	career.formation = formation
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": "lineup.formation",
		"payload": {"formation": formation},
	})
	return true


static func set_role(career: Career, players: Array, role: String,
		player_id: String) -> bool:
	last_error = ""
	var blocked := CareerCondition.blocked_player_ids(career)
	var lineup := lineup_for(players, career.lineup, career.bench_order, blocked,
		career.formation, -1)
	var starters: Array = []
	for slot in lineup.get("slots", []):
		starters.append(_dict(slot.get("player")))
	var ok := CareerRoles.set_role_assignment(career, starters, role, player_id)
	if not ok:
		last_error = CareerRoles.last_error
	return ok


static func team_average(lineup: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for slot in lineup.get("slots", []):
		var player: Dictionary = _dict(slot.get("player"))
		total += float(player.get("effective_overall", player.get("overall", 0.0)))
		count += 1
	return total / count if count > 0 else 0.0


static func projected_average(lineup: Dictionary, anchor_id: String,
		focused_id: String) -> float:
	if anchor_id.is_empty() or focused_id.is_empty() or anchor_id == focused_id:
		return team_average(lineup)
	var slots: Array = lineup.get("slots", [])
	var anchor_slot := -1
	var focused_slot := -1
	var anchor_player: Dictionary = {}
	var focused_player: Dictionary = {}
	var overalls: Array = []
	for index in range(slots.size()):
		var player: Dictionary = _dict(slots[index].get("player"))
		var player_id := str(player.get("id", ""))
		if player_id == anchor_id:
			anchor_slot = index
			anchor_player = player
		elif player_id == focused_id:
			focused_slot = index
			focused_player = player
		overalls.append(float(player.get("effective_overall", player.get("overall", 0.0))))
	if anchor_slot < 0 or focused_slot < 0:
		return team_average(lineup)
	overalls[anchor_slot] = float(focused_player.get("effective_overall",
		focused_player.get("overall", 0.0)))
	overalls[focused_slot] = float(anchor_player.get("effective_overall",
		anchor_player.get("overall", 0.0)))
	var total := 0.0
	for value in overalls:
		total += float(value)
	return total / overalls.size()


static func rating_at(player: Dictionary, slot_role: String) -> int:
	var role := str(player.get("role", ""))
	var overall := float(player.get("overall", 0.0))
	if role == slot_role:
		return int(round(overall))
	var families := {
		"GK": "goalkeeper", "CB": "defence", "LB": "defence", "RB": "defence",
		"DM": "middle", "CM": "middle", "AM": "middle", "LM": "wing",
		"RM": "wing", "CF": "attack",
	}
	var order := ["goalkeeper", "defence", "middle", "wing", "attack"]
	var from := order.find(str(families.get(role, "")))
	var to := order.find(str(families.get(slot_role, "")))
	var distance := 3 if from < 0 or to < 0 else absi(from - to)
	var penalty := 2 if distance == 1 else (4 if distance == 2 else 6)
	return maxi(1, int(round(overall - penalty)))


static func slot_for(lineup: Dictionary, player_id: String) -> Dictionary:
	for slot in lineup.get("slots", []):
		if str(_dict(slot.get("player")).get("id", "")) == player_id:
			return slot
	return {}


static func current_role(lineup: Dictionary, player: Dictionary) -> String:
	var slot := slot_for(lineup, str(player.get("id", "")))
	return str(slot.get("role", player.get("role", "")))


static func info_values(player: Dictionary) -> Dictionary:
	return {
		"position": str(player.get("position", "")),
		"age": player.get("age", "—"),
		"height": "%d CM" % int(player.get("height", 0)) if int(player.get("height", 0)) > 0 else "—",
		"weight": "%d KG" % int(player.get("weight", 0)) if int(player.get("weight", 0)) > 0 else "—",
		"foot": str(player.get("foot", "")) if not str(player.get("foot", "")).is_empty() else "—",
		"weakFoot": player.get("weak_foot", "—"),
		"skillMoves": player.get("skill_moves", "—"),
		"shirtNumber": player.get("shirt_number", "—"),
		"potential": int(round(float(player.get("pot", 0.0)))),
		"marketValue": int(player.get("market_value", 0)),
		"citizenship": ", ".join(PackedStringArray(_string_array(player.get("citizenship", [])))),
	}


static func attribute_groups(stats: Dictionary) -> Array:
	var groups: Array = []
	for group in ATTRIBUTE_GROUPS:
		var rows: Array = []
		for key in group["keys"]:
			if not stats.has(key):
				continue
			rows.append({
				"key": key,
				"label": str(STAT_LABELS.get(key, key)),
				"value": int(round(float(stats.get(key, 0.0)))),
			})
		if not rows.is_empty():
			groups.append({"id": group["id"], "label": group["label"], "rows": rows})
	return groups


static func radar_values(stats: Dictionary) -> Array:
	var values: Array = []
	for axis in RADAR_AXES:
		var total := 0.0
		var count := 0
		for key in axis["keys"]:
			if stats.has(key):
				total += float(stats[key])
				count += 1
		values.append({
			"label": str(axis["label"]),
			"value": int(round(total / count)) if count > 0 else 0,
		})
	return values


static func finance_view(career: Career, players: Array) -> Dictionary:
	var total_value := 0
	var weekly := 0
	var contracts: Dictionary = career.data.get("player_contracts", {})
	for player in players:
		total_value += int(player.get("market_value", 0))
		var contract: Dictionary = _dict(contracts.get(str(player.get("id", ""))))
		weekly += int(contract.get("weekly_wage", 0))
	return {
		"balance": int(career.data.get("balance", 0)),
		"total_market_value": total_value,
		"weekly_wage_bill": weekly,
	}


static func _summary(players: Array) -> Dictionary:
	var total_value := 0
	var overalls: Array = []
	var ages: Array = []
	for player in players:
		total_value += int(player.get("market_value", 0))
		overalls.append(float(player.get("overall", 0.0)))
		var age := int(player.get("age", 0))
		if age > 0:
			ages.append(age)
	var overall_sum := 0.0
	for value in overalls:
		overall_sum += float(value)
	var age_sum := 0.0
	for value in ages:
		age_sum += float(value)
	return {
		"squad_size": players.size(),
		"average_overall": _round1(overall_sum / overalls.size()) if not overalls.is_empty() else 0.0,
		"average_age": _round1(age_sum / ages.size()) if not ages.is_empty() else null,
		"total_market_value": total_value,
	}


static func _groups(players: Array) -> Array:
	var grouped := {}
	for player in players:
		var role := str(player.get("role", ""))
		if not grouped.has(role):
			grouped[role] = []
		grouped[role].append(player)
	var ordered: Array = []
	for role in ROLE_ORDER:
		if grouped.has(role):
			ordered.append({"role": role, "players": grouped[role]})
	for role in grouped:
		if not ROLE_ORDER.has(role):
			ordered.append({"role": role, "players": grouped[role]})
	return ordered


static func _sort_players(players: Array) -> Array:
	var copy := players.duplicate()
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var role_a := int(ROLE_ORDER.get(str(a.get("role", "")), 99))
		var role_b := int(ROLE_ORDER.get(str(b.get("role", "")), 99))
		if role_a != role_b:
			return role_a < role_b
		if not is_equal_approx(float(a.get("overall", 0.0)),
				float(b.get("overall", 0.0))):
			return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
		if str(a.get("name", "")) != str(b.get("name", "")):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return str(a.get("id", "")) < str(b.get("id", "")))
	return copy


static func _pick_player(players: Array, preferred_roles: Array,
		used: Dictionary) -> Dictionary:
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
	var best: Dictionary = {}
	var best_overall := -1.0
	for player in players:
		var overall := float(player.get("overall", 0.0))
		if overall > best_overall:
			best = player
			best_overall = overall
	return best


static func _stable_overall_desc(players: Array) -> Array:
	var sorted_players: Array = players.duplicate()
	# Insertion sort keeps equal overalls in their incoming order, like Python's
	# stable sorted(); Godot's sort_custom makes no stability promise.
	for index in range(1, sorted_players.size()):
		var current: Dictionary = sorted_players[index]
		var cursor := index - 1
		while cursor >= 0 and float(sorted_players[cursor].get("overall", 0.0)) \
				< float(current.get("overall", 0.0)):
			sorted_players[cursor + 1] = sorted_players[cursor]
			cursor -= 1
		sorted_players[cursor + 1] = current
	return sorted_players


static func _assign_players(players: Array, slots: Array) -> Array:
	var count := slots.size()
	if players.size() < count:
		var short: Array = []
		for player in players:
			short.append(str(player.get("id", "")))
		return short
	if count == 0:
		return []
	var scores: Array = []
	for index in range(count):
		var row: Array = []
		for slot in slots:
			row.append(_fit_score(players[index], slot))
		scores.append(row)
	var memo := {}
	var best := _solve(scores, count, 0, 0, memo)
	var order: Array = []
	for index in best.get("order", []):
		order.append(str(players[int(index)].get("id", "")))
	return order


static func _solve(scores: Array, count: int, slot_index: int, mask: int,
		memo: Dictionary) -> Dictionary:
	if slot_index == count:
		return {"score": 0.0, "order": []}
	var key := "%d:%d" % [slot_index, mask]
	if memo.has(key):
		return memo[key]
	var best := {"score": -1.0, "order": []}
	for index in range(count):
		var bit := 1 << index
		if (mask & bit) != 0:
			continue
		var rest := _solve(scores, count, slot_index + 1, mask | bit, memo)
		var total := float(scores[index][slot_index]) + float(rest["score"])
		if total > float(best["score"]):
			best = {"score": total, "order": [index] + rest["order"]}
	memo[key] = best
	return best


static func _fit_score(player: Dictionary, slot: Dictionary) -> float:
	var role := str(player.get("role", ""))
	var roles: Array = slot.get("roles", [slot.get("role", "")])
	var index := roles.find(role)
	var score := 0.0
	if index >= 0:
		score = 100.0 - index * 6.0
	else:
		var player_line := str(LINE_BY_ROLE.get(role, ""))
		var slot_line := str(LINE_BY_POSITION.get(str(slot.get("position", "")), ""))
		score = 30.0 if not player_line.is_empty() and player_line == slot_line else 0.0
	return score + float(player.get("overall", 0.0)) * 0.01


static func _squad_role_ranks(players: Array) -> Dictionary:
	var ranked: Array = players.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.get("overall", 0.0)),
				float(b.get("overall", 0.0))):
			return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
		if str(a.get("name", "")) != str(b.get("name", "")):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return str(a.get("id", "")) < str(b.get("id", "")))
	var ranks := {}
	for index in range(ranked.size()):
		ranks[str(ranked[index].get("id", ""))] = index
	return ranks


static func _role_for_rank(index: int, total: int) -> String:
	if total <= 0:
		return DEFAULT_ROLE
	var position := float(index) / float(total)
	for pair in ROLE_THRESHOLDS:
		if position < float(pair[0]):
			return str(pair[1])
	return "prospect"


static func _fatigue_factor(fatigue: int) -> float:
	return 0.75 + 0.25 * (clampf(float(fatigue), 0.0, 100.0) / 100.0)


static func _morale_percent(actual: int, expected: int) -> int:
	if expected <= 0:
		return 100
	return clampi(int(round(float(actual) / float(expected) * 100.0)), 0, 100)


static func _season_stats(stats: Dictionary) -> Dictionary:
	var out := {}
	for key in CareerCondition.STAT_KEYS:
		out[key] = int(stats.get(key, 0))
	return out


static func _string_array(value) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


static func _dict(value) -> Dictionary:
	return value if value is Dictionary else {}


static func _round1(value: float) -> float:
	return roundf(value * 10.0) / 10.0
