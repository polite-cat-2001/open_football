class_name CareerCoefficients
extends RefCounted
# UEFA club coefficients. The first career season uses a published snapshot of
# the end-of-2025-26 five-year ranking; clubs outside it start at zero. The
# career's own European results can be rolled into the same table later.

const PATH := "res://assets/data/club_coefficients.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if not FileAccess.file_exists(PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data


static func season() -> String:
	return str(data().get("season", ""))


static func seasons() -> Array:
	var value = data().get("seasons", [])
	return value if value is Array else []


static func points(club_id: String) -> Array:
	var clubs = data().get("clubs", {})
	if not (clubs is Dictionary):
		return []
	var entry = clubs.get(str(club_id), {})
	if entry is Dictionary and entry.get("points") is Array:
		return entry["points"]
	return []


static func table() -> Dictionary:
	var result := {}
	var clubs = data().get("clubs", {})
	if not (clubs is Dictionary):
		return result
	for club_id in clubs:
		var entry = clubs[club_id]
		if entry is Dictionary and entry.get("points") is Array:
			result[str(club_id)] = (entry["points"] as Array).duplicate()
	return result


static func roll(table_data: Dictionary, season_points: Dictionary) -> Dictionary:
	# Add one season and drop the oldest, so the ranking always covers five.
	var result := {}
	for club_id in table_data:
		var row = table_data[club_id]
		var next: Array = []
		if row is Array:
			for index in range(1, 5):
				next.append(float(row[index]) if index < (row as Array).size() else 0.0)
		else:
			next = [0.0, 0.0, 0.0, 0.0]
		next.append(float(season_points.get(str(club_id), 0.0)))
		result[str(club_id)] = next
	for club_id in season_points:
		if not result.has(str(club_id)):
			result[str(club_id)] = [0.0, 0.0, 0.0, 0.0,
				float(season_points[club_id])]
	return result


static func total(table_data: Dictionary, club_id: String) -> float:
	var row = table_data.get(str(club_id), [])
	var total_points := 0.0
	for value in row:
		total_points += float(value)
	return total_points


static func coefficient(club_id: String) -> float:
	var clubs = data().get("clubs", {})
	if not (clubs is Dictionary):
		return 0.0
	var entry = clubs.get(str(club_id), {})
	if entry is Dictionary:
		return float(entry.get("coefficient", 0.0))
	return 0.0


static func sorted_clubs(club_ids: Array) -> Array:
	var ids: Array = []
	for club_id in club_ids:
		ids.append(str(club_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var left := coefficient(a)
		var right := coefficient(b)
		if not is_equal_approx(left, right):
			return left > right
		return a < b)
	return ids
