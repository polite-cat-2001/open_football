class_name TeamRatings
extends RefCounted
# Port of the prototype's club-rating formula (gf-ui-prototype server/canon.py),
# applied to OpenFootball's base_stat (the equivalent of the prototype's
# `overall`). Ratings are computed from the selected team's squad on demand;
# nothing is precomputed for every team.

const STAR_FLOOR := 59.0
const STAR_STEP := 7.0
const STAR_MIN := 0.5
const STAR_MAX := 5.0
const BEST_COUNT := 11

const ATTACK_ROLES := ["CF", "ST", "LW", "RW", "LM", "RM"]
const MIDFIELD_ROLES := ["DM", "CM", "AM"]
const DEFENCE_ROLES := ["CB", "LB", "RB"]
const ATTACK_SIZE := 3
const MIDFIELD_SIZE := 3
const DEFENCE_SIZE := 4


static func from_players(players: Array) -> Dictionary:
	if players.is_empty():
		return {}
	var overalls: Array[float] = []
	var by_role := {}
	for raw_player in players:
		if not (raw_player is Dictionary):
			continue
		var player: Dictionary = raw_player
		# The prototype's `overall` is the player's base quality, not the mean
		# of GameplayFootball's 22 normalized skills (those saturate near 1.0 and
		# made almost every club a five-star side). base_stat is the direct
		# equivalent and matches the prototype's rating distribution.
		var overall := float(player.get("base_stat", 0.0)) * 100.0
		if overall <= 0.0:
			overall = PlayerStats.average(player.get("stats", {})) * 100.0
		overalls.append(overall)
		var role := str(player.get("role", ""))
		if not by_role.has(role):
			by_role[role] = []
		(by_role[role] as Array).append(overall)
	if overalls.is_empty():
		return {}
	overalls.sort()
	overalls.reverse()
	var best := overalls.slice(0, mini(BEST_COUNT, overalls.size()))
	var average_top := _mean(best)
	return {
		"stars": stars_for(average_top),
		"attack": _line(by_role, ATTACK_ROLES, ATTACK_SIZE, average_top),
		"midfield": _line(by_role, MIDFIELD_ROLES, MIDFIELD_SIZE, average_top),
		"defence": _line(by_role, DEFENCE_ROLES, DEFENCE_SIZE, average_top),
		"average": average_top,
	}


static func stars_for(average: float) -> float:
	var raw := 1.0 + (average - STAR_FLOOR) / STAR_STEP
	var stepped := roundf(raw * 2.0) / 2.0
	return clampf(stepped, STAR_MIN, STAR_MAX)


static func _line(by_role: Dictionary, roles: Array, size: int, fallback: float) -> int:
	var values: Array[float] = []
	for role in roles:
		for value in by_role.get(role, []):
			values.append(float(value))
	if values.is_empty():
		return int(roundf(fallback))
	values.sort()
	values.reverse()
	var best := values.slice(0, mini(size, values.size()))
	return int(roundf(_mean(best)))


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())
