class_name MatchLineup
extends RefCounted
# Editable prematch squad: which eleven players start, the seven matchday
# substitutes and the reserve list behind them. The match package flattens this
# into "starters first, bench next, reserve last" so the C++ runtime (which
# activates the first eleven in package order) fields exactly the chosen players.

const SLOT_COUNT := Formation.SLOT_COUNT
const BENCH_SIZE := 7
const TEAM_ROLE_COUNT := 6
const TEAM_ROLE_CAPTAIN := 0
const TEAM_ROLE_PENALTY := 1
const TEAM_ROLE_FREE_KICK_NEAR := 2
const TEAM_ROLE_FREE_KICK_FAR := 3
const TEAM_ROLE_CORNER_LEFT := 4
const TEAM_ROLE_CORNER_RIGHT := 5

var team_id := 0
var team_name := ""
var players: Array[Dictionary] = []
var formation: Array[Dictionary] = []
var lineup: Array[int] = []
var bench: Array[int] = []
var reserve: Array[int] = []
# Designated team roles (C++ e_TeamRole -> starting slot, -1/absent = auto).
var roles: Dictionary = {}
var error := ""

var _players_by_id := {}


static func from_squad(squad: Dictionary) -> MatchLineup:
	var result := MatchLineup.new()
	var team: Dictionary = squad.get("team", {})
	result.team_id = int(team.get("id", 0))
	result.team_name = str(team.get("name", ""))

	var source_players: Array = squad.get("players", [])
	for player in source_players:
		if typeof(player) == TYPE_DICTIONARY:
			result.players.append(player.duplicate(true))
	var source_formation: Array = squad.get("formation", [])
	for entry in source_formation:
		if typeof(entry) == TYPE_DICTIONARY:
			result.formation.append(entry.duplicate(true))

	result._reindex()
	var matched_scheme := result.current_scheme()
	if matched_scheme >= 0:
		result.apply_scheme(matched_scheme)
	for index in result.players.size():
		var player_id := int(result.players[index].get("id", 0))
		if result.lineup.size() < SLOT_COUNT:
			result.lineup.append(player_id)
		elif result.bench.size() < BENCH_SIZE:
			result.bench.append(player_id)
		else:
			result.reserve.append(player_id)
	if result.lineup.size() < SLOT_COUNT:
		result.lineup.resize(SLOT_COUNT)
	return result


func apply_plan(plan: Dictionary) -> void:
	# The shell's pre-match plan ({order, formation, roles}) is the applied
	# state of the shared MatchData; mirror it into this lineup before the
	# network package is built.
	if plan.is_empty():
		return
	var order: PackedInt32Array = plan.get("order", PackedInt32Array())
	var starters: Array[int] = []
	var subs: Array[int] = []
	var reserves: Array[int] = []
	for index in order.size():
		var player_id := int(order[index])
		if player_by_id(player_id).is_empty():
			continue
		if starters.size() < SLOT_COUNT:
			starters.append(player_id)
		elif subs.size() < BENCH_SIZE:
			subs.append(player_id)
		else:
			reserves.append(player_id)
	if starters.size() == SLOT_COUNT:
		lineup = starters
		bench = subs
		reserve = reserves
	var formation_rows: Array = plan.get("formation", [])
	if formation_rows.size() == SLOT_COUNT:
		formation = []
		for row in formation_rows:
			if typeof(row) == TYPE_DICTIONARY:
				formation.append((row as Dictionary).duplicate(true))
	var roles_slots: PackedInt32Array = plan.get("roles", PackedInt32Array())
	roles = {}
	for role in mini(roles_slots.size(), TEAM_ROLE_COUNT):
		var slot := int(roles_slots[role])
		if slot >= 0:
			roles[role] = slot
	error = ""


func player_by_id(player_id: int) -> Dictionary:
	return _players_by_id.get(player_id, {})


func slot_for_player(player_id: int) -> int:
	return lineup.find(player_id)


func lineup_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player_id in lineup:
		var player := player_by_id(player_id)
		if not player.is_empty():
			result.append(player)
	return result


func bench_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player_id in bench:
		var player := player_by_id(player_id)
		if not player.is_empty():
			result.append(player)
	return result


func reserve_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player_id in reserve:
		var player := player_by_id(player_id)
		if not player.is_empty():
			result.append(player)
	return result


func ordered_players() -> Array[Dictionary]:
	var result := lineup_players()
	result.append_array(bench_players())
	result.append_array(reserve_players())
	return result


func set_starter(slot: int, player_id: int) -> bool:
	error = ""
	if slot < 0 or slot >= SLOT_COUNT:
		error = "Formation slot %d does not exist." % slot
		return false
	if player_by_id(player_id).is_empty():
		error = "Player %d is not in the squad." % player_id
		return false

	var existing_slot := slot_for_player(player_id)
	if existing_slot >= 0:
		var displaced := lineup[slot]
		lineup[slot] = player_id
		lineup[existing_slot] = displaced
		return true

	var current := lineup[slot]
	var bench_index := bench.find(player_id)
	if bench_index >= 0:
		lineup[slot] = player_id
		if current != 0:
			bench[bench_index] = current
		else:
			bench.remove_at(bench_index)
		return true
	var reserve_index := reserve.find(player_id)
	if reserve_index >= 0:
		lineup[slot] = player_id
		if current != 0:
			reserve[reserve_index] = current
		else:
			reserve.remove_at(reserve_index)
		return true
	error = "Player %d is neither in the lineup, on the bench nor in reserve." % player_id
	return false


func clear_slot(slot: int) -> bool:
	error = ""
	if slot < 0 or slot >= SLOT_COUNT:
		error = "Formation slot %d does not exist." % slot
		return false
	var current := lineup[slot]
	if current == 0:
		return false
	lineup[slot] = 0
	if bench.size() < BENCH_SIZE:
		bench.append(current)
	else:
		reserve.append(current)
	return true


func swap_players(first_id: int, second_id: int) -> bool:
	error = ""
	if first_id == second_id:
		return false
	if player_by_id(first_id).is_empty() or player_by_id(second_id).is_empty():
		error = "Both players must be in the squad."
		return false
	var first_slot := slot_for_player(first_id)
	var second_slot := slot_for_player(second_id)
	var first_bench := bench.find(first_id)
	var second_bench := bench.find(second_id)
	var first_reserve := reserve.find(first_id)
	var second_reserve := reserve.find(second_id)
	if first_slot >= 0 and second_slot >= 0:
		lineup[first_slot] = second_id
		lineup[second_slot] = first_id
		return true
	if first_bench >= 0 and second_bench >= 0:
		bench[first_bench] = second_id
		bench[second_bench] = first_id
		return true
	if first_reserve >= 0 and second_reserve >= 0:
		reserve[first_reserve] = second_id
		reserve[second_reserve] = first_id
		return true
	if first_bench >= 0 and second_reserve >= 0:
		bench[first_bench] = second_id
		reserve[second_reserve] = first_id
		return true
	if first_reserve >= 0 and second_bench >= 0:
		reserve[first_reserve] = second_id
		bench[second_bench] = first_id
		return true
	if first_slot >= 0 and second_bench >= 0:
		return set_starter(first_slot, second_id)
	if first_bench >= 0 and second_slot >= 0:
		return set_starter(second_slot, first_id)
	if first_slot >= 0 and second_reserve >= 0:
		return set_starter(first_slot, second_id)
	if first_reserve >= 0 and second_slot >= 0:
		return set_starter(second_slot, first_id)
	error = "A player is neither in the lineup, on the bench nor in reserve."
	return false


func move_position(slot: int, position: Vector2) -> bool:
	error = ""
	if slot < 0 or slot >= SLOT_COUNT:
		error = "Formation slot %d does not exist." % slot
		return false
	var clamped := Vector2(clampf(position.x, -1.0, 1.0), clampf(position.y, -1.0, 1.0))
	var entry: Dictionary = formation[slot]
	entry["position"] = clamped
	# The edited spot is what both the match and a later re-open should show.
	entry["database_position"] = clamped
	return true


func apply_scheme(scheme_index: int) -> bool:
	error = ""
	if scheme_index < 0 or scheme_index >= TacticalSchemes.count():
		error = "Unknown tactical scheme."
		return false
	var candidates: Array = []
	for slot in mini(SLOT_COUNT, formation.size()):
		var entry: Dictionary = formation[slot]
		candidates.append({
			"slot": slot,
			"role": str(entry.get("role", "CM")),
			"position": entry.get("database_position", entry.get("position", Vector2.ZERO)),
		})
	var assignment := TacticalSchemes.assign(candidates, scheme_index)
	for slot in mini(assignment.size(), formation.size()):
		var entry: Dictionary = assignment[slot]
		formation[slot]["role"] = str(entry["role"])
		formation[slot]["database_position"] = entry["database_position"]
		formation[slot]["position"] = entry["position"]
	return true


func current_scheme() -> int:
	var entries: Array = []
	for slot in mini(SLOT_COUNT, formation.size()):
		var entry: Dictionary = formation[slot]
		entries.append({
			"role": str(entry.get("role", "CM")),
			"position": entry.get("database_position", entry.get("position", Vector2.ZERO)),
		})
	return TacticalSchemes.match_scheme(entries)


func designated_role_slot(role: int) -> int:
	if not roles.has(role):
		return -1
	var slot := int(roles[role])
	return slot if slot >= 0 and slot < SLOT_COUNT else -1


func role_slot(role: int) -> int:
	var designated := designated_role_slot(role)
	return designated if designated >= 0 else suggest_role_slot(role)


func set_role(role: int, slot: int) -> bool:
	if role < 0 or role >= TEAM_ROLE_COUNT or slot < 0 or slot >= SLOT_COUNT:
		return false
	roles[role] = slot
	return true


func roles_to_array() -> Array:
	var result: Array = []
	for role in TEAM_ROLE_COUNT:
		# Materialise the suggestion the UI shows, so the match uses the same
		# captain/taker the prematch screen named.
		result.append(role_slot(role))
	return result


func suggest_role_slot(role: int) -> int:
	var best := -1
	var best_score := -1.0
	for slot in mini(SLOT_COUNT, lineup.size()):
		var entry: Dictionary = formation[slot]
		if str(entry.get("role", "")) == "GK":
			continue
		var player := player_by_id(lineup[slot])
		if player.is_empty():
			continue
		var score := _role_score(role, player)
		if score > best_score:
			best_score = score
			best = slot
	return best


func _role_score(role: int, player: Dictionary) -> float:
	var stats: Dictionary = player.get("stats", {})
	var keys: Array = []
	match role:
		TEAM_ROLE_CAPTAIN:
			keys = ["mental_workrate", "mental_resilience", "mental_vision"]
		TEAM_ROLE_PENALTY:
			keys = ["technical_shot", "mental_calmness"]
		TEAM_ROLE_FREE_KICK_NEAR, TEAM_ROLE_FREE_KICK_FAR:
			keys = ["technical_highpass", "technical_shot"]
		TEAM_ROLE_CORNER_LEFT, TEAM_ROLE_CORNER_RIGHT:
			keys = ["technical_highpass", "mental_vision"]
		_:
			keys = ["mental_vision"]
	var total := 0.0
	for key in keys:
		total += float(stats.get(key, player.get("average", 0.0)))
	return total


func validate() -> Dictionary:
	error = ""
	var starter_count := 0
	var seen := {}
	for player_id in lineup:
		if player_id == 0:
			continue
		starter_count += 1
		if seen.has(player_id):
			return _invalid("A player is listed twice in the starting eleven.")
		seen[player_id] = true
		if player_by_id(player_id).is_empty():
			return _invalid("The starting eleven contains a player outside the squad.")

	if starter_count != SLOT_COUNT:
		return _invalid("Starting eleven needs exactly %d players (currently %d)." \
			% [SLOT_COUNT, starter_count])
	if formation.size() != SLOT_COUNT:
		return _invalid("Formation needs exactly %d slots (currently %d)." \
			% [SLOT_COUNT, formation.size()])
	if bench.size() > BENCH_SIZE:
		return _invalid("The matchday bench can hold at most %d players (currently %d)." \
			% [BENCH_SIZE, bench.size()])

	for player_id in bench:
		if player_id == 0:
			return _invalid("The bench contains an empty slot.")
		if seen.has(player_id):
			return _invalid("A player is listed twice in the squad.")
		seen[player_id] = true
		if player_by_id(player_id).is_empty():
			return _invalid("The bench contains a player outside the squad.")
	for player_id in reserve:
		if player_id == 0:
			return _invalid("The reserve list contains an empty slot.")
		if seen.has(player_id):
			return _invalid("A player is listed twice in the squad.")
		seen[player_id] = true
		if player_by_id(player_id).is_empty():
			return _invalid("The reserve list contains a player outside the squad.")
	if starter_count + bench.size() + reserve.size() != players.size():
		return _invalid("Squad and lineup do not match: %d starters, %d on the bench, %d in reserve, %d in the squad." \
			% [starter_count, bench.size(), reserve.size(), players.size()])

	var goalkeeper_slot := -1
	for index in formation.size():
		if str(formation[index].get("role", "")) == "GK":
			goalkeeper_slot = index
			break
	if goalkeeper_slot < 0:
		return _invalid("Formation has no goalkeeper slot.")
	if lineup[goalkeeper_slot] == 0:
		return _invalid("Starting eleven needs a goalkeeper in the GK slot.")

	return {"ok": true, "error": ""}


func warning() -> String:
	# An outfield player is allowed in goal (real football does it too); C++ plays
	# them at the GK slot role with their own stats, so surface it without blocking.
	if formation.size() != SLOT_COUNT or lineup.size() != SLOT_COUNT:
		return ""
	for index in formation.size():
		if str(formation[index].get("role", "")) != "GK":
			continue
		var goalkeeper_id := lineup[index]
		if goalkeeper_id != 0 and not is_goalkeeper(player_by_id(goalkeeper_id)):
			return "Outfield player in goal: he will play out of position."
		break
	return ""


func is_valid() -> bool:
	return bool(validate().get("ok", false))


func snapshot() -> Dictionary:
	# Wire-friendly state for the network pre-match handshake. Only ids and
	# formation/roles travel; both peers already hold the same squad data.
	return {
		"team_id": team_id,
		"lineup": lineup.duplicate(),
		"bench": bench.duplicate(),
		"reserve": reserve.duplicate(),
		"formation": formation.duplicate(true),
		"roles": roles.duplicate(true),
	}


func apply_snapshot(data: Dictionary) -> bool:
	error = ""
	var new_lineup: Array = data.get("lineup", [])
	var new_bench: Array = data.get("bench", [])
	var new_reserve: Array = data.get("reserve", [])
	var new_formation: Array = data.get("formation", [])
	if new_lineup.size() != SLOT_COUNT or new_formation.size() != SLOT_COUNT:
		error = "The network lineup is incomplete."
		return false
	lineup.clear()
	for value in new_lineup:
		lineup.append(int(value))
	bench.clear()
	for value in new_bench:
		bench.append(int(value))
	reserve.clear()
	for value in new_reserve:
		reserve.append(int(value))
	formation.clear()
	for entry in new_formation:
		if typeof(entry) != TYPE_DICTIONARY:
			error = "The network formation is invalid."
			return false
		formation.append((entry as Dictionary).duplicate(true))
	roles = (data.get("roles", {}) as Dictionary).duplicate(true)
	return true


static func is_goalkeeper(player: Dictionary) -> bool:
	var roles := str(player.get("role", "")).to_upper().replace(",", " ")
	for token in roles.split(" ", false):
		if token == "GK":
			return true
	return false


func _invalid(message: String) -> Dictionary:
	error = message
	return {"ok": false, "error": message}


func _reindex() -> void:
	_players_by_id.clear()
	for player in players:
		_players_by_id[int(player.get("id", 0))] = player
