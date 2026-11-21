class_name CareerStages
extends RefCounted
# Pure stage math for the career formats: build a table from a fixture list and
# results, cut it into groups, carry points/goals into the next stage, and pick
# the champion. No career, database or dates: callers pass the fixtures.

static func table(fixtures: Array, results: Dictionary, club_ids: Array,
		carried: Dictionary = {}) -> Array:
	var rows := {}
	for club_id in club_ids:
		var key := str(club_id)
		rows[key] = {
			"id": key, "played": 0, "won": 0, "drawn": 0, "lost": 0,
			"goals_for": 0, "goals_against": 0, "goal_difference": 0, "points": 0,
		}
	for club_id in carried:
		if not rows.has(str(club_id)):
			continue
		var source: Dictionary = carried[str(club_id)]
		var row: Dictionary = rows[str(club_id)]
		row["played"] = int(source.get("played", 0))
		row["goals_for"] = int(source.get("goals_for", 0))
		row["goals_against"] = int(source.get("goals_against", 0))
		row["points"] = int(source.get("points", 0))

	for fixture in fixtures:
		var result = results.get(str(fixture.get("id", "")))
		if not (result is Dictionary):
			continue
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		if not rows.has(home) or not rows.has(away):
			continue
		var home_goals := int(result.get("home", 0))
		var away_goals := int(result.get("away", 0))
		_add(rows[home], home_goals, away_goals)
		_add(rows[away], away_goals, home_goals)

	var table: Array = rows.values()
	table.sort_custom(_before)
	return table


static func split(table: Array, sizes: Array) -> Array:
	var groups: Array = []
	var index := 0
	for size in sizes:
		var count := int(size)
		groups.append(table.slice(index, index + count))
		index += count
	return groups


static func carry(table: Array, mode: Dictionary) -> Dictionary:
	var points_mode := str(mode.get("points", "none"))
	var goals_mode := str(mode.get("goals", "reset"))
	var rounding := str(mode.get("rounding", "down"))
	var carried := {}
	for row in table:
		var points := 0
		if points_mode == "full":
			points = int(row.points)
		elif points_mode == "half":
			var half := float(row.points) / 2.0
			points = int(ceil(half)) if rounding == "up" else int(floor(half))
		carried[str(row.id)] = {
			"points": points,
			"played": int(row.played),
			"goals_for": int(row.goals_for) if goals_mode == "carry" else 0,
			"goals_against": int(row.goals_against) if goals_mode == "carry" else 0,
		}
	return carried


static func champion(table: Array) -> Dictionary:
	return table[0] if not table.is_empty() else {}


static func _add(row: Dictionary, goals_for: int, goals_against: int) -> void:
	row["played"] = int(row.played) + 1
	row["goals_for"] = int(row.goals_for) + goals_for
	row["goals_against"] = int(row.goals_against) + goals_against
	row["goal_difference"] = int(row.goals_for) - int(row.goals_against)
	if goals_for > goals_against:
		row["won"] = int(row.won) + 1
		row["points"] = int(row.points) + 3
	elif goals_for == goals_against:
		row["drawn"] = int(row.drawn) + 1
		row["points"] = int(row.points) + 1
	else:
		row["lost"] = int(row.lost) + 1


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.points) != int(b.points):
		return int(a.points) > int(b.points)
	if int(a.goal_difference) != int(b.goal_difference):
		return int(a.goal_difference) > int(b.goal_difference)
	if int(a.goals_for) != int(b.goals_for):
		return int(a.goals_for) > int(b.goals_for)
	return str(a.id) < str(b.id)
