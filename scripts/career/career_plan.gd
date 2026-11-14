class_name CareerPlan
extends RefCounted
# Adapter between the career squad and the shared Game Plan screen
# (`GpfGamePlan`, same screen as the prematch hub and the match pause): builds
# the MatchLineup models the plan edits and reads them back into the career.

const ROLE_TO_INDEX := {
	"captain": 0,
	"penalties": 1,
	"free_kick_left": 2,
	"free_kick_right": 3,
	"corner_left": 4,
	"corner_right": 5,
}
const INDEX_TO_ROLE := {
	0: "captain",
	1: "penalties",
	2: "free_kick_left",
	3: "free_kick_right",
	4: "corner_left",
	5: "corner_right",
}


static func build(catalog: TeamCatalog, career: Career, club_id: int,
		opponent_id: int) -> Dictionary:
	return {
		"home": _own_lineup(catalog, career),
		"away": _opponent_lineup(catalog, opponent_id),
	}


# The FORMATIONS drawer lists the career's own twenty formations.
static func formation_source() -> Array:
	var items: Array = []
	for formation in CareerFormations.ORDER:
		var entries: Array = []
		for slot in CareerFormations.slots(formation):
			entries.append({
				"role": str(slot.get("role", "CM")),
				"position": _position(slot),
			})
		items.append({
			"id": str(formation),
			"label": CareerFormations.label(str(formation)),
			"entries": entries,
		})
	return items


static func apply(career: Career, lineup: MatchLineup, formation_id: String) -> void:
	var starters: Array = []
	for player_id in lineup.lineup:
		if int(player_id) > 0:
			starters.append(str(player_id))
	career.lineup = starters
	var bench: Array = []
	for player_id in lineup.bench:
		if int(player_id) > 0:
			bench.append(str(player_id))
	career.bench_order = bench
	if not formation_id.is_empty() and CareerFormations.FORMATIONS.has(formation_id):
		career.formation = formation_id
	var assignments: Dictionary = career.role_assignments \
		if career.role_assignments is Dictionary else {}
	for role in ROLE_TO_INDEX:
		var slot := int(lineup.roles.get(int(ROLE_TO_INDEX[role]), -1))
		if slot >= 0 and slot < lineup.lineup.size():
			assignments[role] = str(lineup.lineup[slot])
	career.role_assignments = assignments


static func _own_lineup(catalog: TeamCatalog, career: Career) -> MatchLineup:
	var snapshot := CareerSquad.snapshot(catalog, career)
	var club := catalog.career_club(int(career.club_id))
	var lineup: Dictionary = snapshot.get("lineup", {})
	var result := _make_lineup(club, snapshot.get("players", []),
		lineup.get("slots", []), lineup.get("bench", []), lineup.get("reserve", []))
	result.team_id = int(career.club_id)
	for role in ROLE_TO_INDEX:
		var player_id := str((career.role_assignments as Dictionary).get(role, ""))
		var slot := result.lineup.find(int(player_id)) if not player_id.is_empty() else -1
		if slot >= 0:
			result.roles[int(ROLE_TO_INDEX[role])] = slot
	return result


static func _opponent_lineup(catalog: TeamCatalog, club_id: int) -> MatchLineup:
	var club := catalog.career_club(club_id)
	var players := catalog.career_squad(club_id)
	var lineup := CareerSquad.lineup_for(players, [], [], [],
		CareerFormations.DEFAULT, CareerSquad.MATCHDAY_BENCH)
	var result := _make_lineup(club, players, lineup.get("slots", []),
		lineup.get("bench", []), lineup.get("reserve", []))
	result.team_id = club_id
	return result


static func _make_lineup(club: Dictionary, players: Array, slots: Array,
		bench: Array, reserve: Array) -> MatchLineup:
	var result := MatchLineup.new()
	result.team_id = int(str(club.get("id", "0")))
	result.team_name = str(club.get("name", ""))
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (player as Dictionary).duplicate(true)
		copy["tm_id"] = int(str(copy.get("id", "0")))
		result.players.append(copy)
	result._reindex()
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var position := _position(slot)
		result.formation.append({
			"slot": index,
			"role": str(slot.get("role", "CM")),
			"position": position,
			"database_position": position,
		})
		result.lineup.append(int(str(slot.get("player", {}).get("id", "0"))))
	for player in bench:
		result.bench.append(int(str((player as Dictionary).get("id", "0"))))
	for player in reserve:
		result.reserve.append(int(str((player as Dictionary).get("id", "0"))))
	return result


# Career slots: x is across (0 left), y is depth (0 attack, 100 own goal).
# The plan wants Vector2(depth, across) in [-1, 1].
static func _position(slot: Dictionary) -> Vector2:
	var x := float(slot.get("x", 50))
	var y := float(slot.get("y", 50))
	return Vector2(1.0 - y / 50.0, 1.0 - x / 50.0)
