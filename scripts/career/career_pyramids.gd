class_name CareerPyramids
extends RefCounted
# How many clubs change level through the boundary above and below a league.
# `league_pyramids.json` stores an audited `up_total`/`down_total` per boundary
# (see tools/audit_pyramid_totals.py); a league without a verified boundary keeps
# the engine's flat default, so a career never stalls on missing research.

const PATH := "res://assets/data/league_pyramids.json"
const DEFAULT := 3

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if not FileAccess.file_exists(PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data


static func record(league_id: String) -> Dictionary:
	var rows = data().get("leagues", {})
	if not (rows is Dictionary):
		return {}
	var row = rows.get(league_id, {})
	return row if row is Dictionary else {}


static func has_record(league_id: String) -> bool:
	return not record(league_id).is_empty()


static func promotion_places(league_id: String) -> int:
	# Clubs that leave this league for the one above.
	var row := record(league_id)
	if row.is_empty():
		return DEFAULT
	var level := int(row.get("level", 1))
	if level <= 1 or bool(row.get("closed_up", false)):
		return 0
	var edge := _boundary(str(row.get("country", "")), level - 1, level)
	return _total(edge, "up_total")


static func relegation_places(league_id: String) -> int:
	# Clubs that leave this league for the one below.
	var row := record(league_id)
	if row.is_empty():
		return DEFAULT
	if bool(row.get("closed_down", false)):
		return 0
	var level := int(row.get("level", 1))
	var edge := _boundary(str(row.get("country", "")), level, level + 1)
	return _total(edge, "down_total")


static func playoff_places(league_id: String, upwards: bool) -> int:
	# Places decided by a play-off rather than by the table alone.
	var row := record(league_id)
	if row.is_empty():
		return 0
	var level := int(row.get("level", 1))
	var edge := {}
	if upwards:
		edge = _boundary(str(row.get("country", "")), level - 1, level)
		return int(edge.get("up_playoff", 0)) if edge is Dictionary else 0
	edge = _boundary(str(row.get("country", "")), level, level + 1)
	return int(edge.get("down_playoff", 0)) if edge is Dictionary else 0


static func _boundary(country: String, upper: int, lower: int) -> Dictionary:
	for row in data().get("boundaries", []):
		var edge: Dictionary = row
		if str(edge.get("country", "")) == country \
				and int(edge.get("upper", -1)) == upper \
				and int(edge.get("lower", -1)) == lower:
			return edge
	return {}


static func _total(edge: Dictionary, key: String) -> int:
	if edge.is_empty():
		return DEFAULT
	var value = edge.get(key)
	if value == null:
		return DEFAULT
	return int(value)
