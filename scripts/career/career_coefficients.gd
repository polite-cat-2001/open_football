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
