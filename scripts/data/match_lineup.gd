class_name MatchLineup
extends RefCounted
# Editable prematch squad: which eleven players start, who sits on the bench
# and where each formation slot stands. The match package flattens this into
# "starters first, bench after" so the C++ runtime (which activates the first
# eleven in package order) fields exactly the chosen players.

const SLOT_COUNT := Formation.SLOT_COUNT

var team_id := 0
var team_name := ""
var players: Array[Dictionary] = []
var formation: Array[Dictionary] = []
var lineup: Array[int] = []
var bench: Array[int] = []
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
	for index in result.players.size():
		var player_id := int(result.players[index].get("id", 0))
		if result.lineup.size() < SLOT_COUNT:
			result.lineup.append(player_id)
		else:
			result.bench.append(player_id)
	if result.lineup.size() < SLOT_COUNT:
		result.lineup.resize(SLOT_COUNT)
	return result


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


func ordered_players() -> Array[Dictionary]:
	var result := lineup_players()
	result.append_array(bench_players())
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

	var bench_index := bench.find(player_id)
	if bench_index < 0:
		error = "Player %d is neither in the lineup nor on the bench." % player_id
		return false
	var current := lineup[slot]
	lineup[slot] = player_id
	if current != 0:
		bench[bench_index] = current
	else:
		bench.remove_at(bench_index)
	return true


func clear_slot(slot: int) -> bool:
	error = ""
	if slot < 0 or slot >= SLOT_COUNT:
		error = "Formation slot %d does not exist." % slot
		return false
	var current := lineup[slot]
	if current == 0:
		return false
	lineup[slot] = 0
	bench.append(current)
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
	if first_slot >= 0 and second_slot >= 0:
		lineup[first_slot] = second_id
		lineup[second_slot] = first_id
		return true
	if first_bench >= 0 and second_bench >= 0:
		bench[first_bench] = second_id
		bench[second_bench] = first_id
		return true
	if first_slot >= 0 and second_bench >= 0:
		return set_starter(first_slot, second_id)
	if first_bench >= 0 and second_slot >= 0:
		return set_starter(second_slot, first_id)
	error = "A player is neither in the lineup nor on the bench."
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

	for player_id in bench:
		if player_id == 0:
			return _invalid("The bench contains an empty slot.")
		if seen.has(player_id):
			return _invalid("A player is listed twice in the squad.")
		seen[player_id] = true
		if player_by_id(player_id).is_empty():
			return _invalid("The bench contains a player outside the squad.")
	if starter_count + bench.size() != players.size():
		return _invalid("Squad and lineup do not match: %d starters, %d on the bench, %d in the squad." \
			% [starter_count, bench.size(), players.size()])

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
