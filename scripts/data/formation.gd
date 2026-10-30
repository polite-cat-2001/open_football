class_name Formation
extends RefCounted
# Formation parsing and normalization, ported from GameplayFootball's
# TeamData::InitFromRaw (src/data/teamdata.cpp).
#
# Database positions are blended with a hardcoded default position per role
# (60/40), then non-goalkeepers are pushed apart until nobody stands closer
# than 0.5 (in the -1..1 normalized pitch space).

const SLOT_COUNT := 11
const DATABASE_WEIGHT := 0.6
const DEFAULT_WEIGHT := 0.4
const MIN_DISTANCE := 0.5
const MAX_ITERATIONS := 10
const NORMALIZE_EPSILON := 0.000001

const DEFAULT_ROLE_POSITIONS := {
	"GK": Vector2(-1.0, 0.0),
	"CB": Vector2(-1.0, 0.0),
	"LB": Vector2(-0.8, 0.8),
	"RB": Vector2(-0.8, -0.8),
	"DM": Vector2(-0.5, 0.0),
	"CM": Vector2(0.0, 0.0),
	"LM": Vector2(0.0, 1.0),
	"RM": Vector2(0.0, -1.0),
	"AM": Vector2(0.5, 0.0),
	"CF": Vector2(1.0, 0.0),
	"ST": Vector2(1.0, 0.0),
	"LW": Vector2(0.7, 0.9),
	"RW": Vector2(0.7, -0.9),
}

const VALID_ROLES := [
	"GK", "CB", "LB", "RB", "DM", "CM", "LM", "RM", "AM", "CF", "LW", "RW", "ST",
]


static func role_from_string(value: String) -> String:
	var role := value.strip_edges()
	if VALID_ROLES.has(role):
		return role
	return "CM"


static func default_role_position(role: String) -> Vector2:
	return DEFAULT_ROLE_POSITIONS.get(role, Vector2.ZERO)


static func parse(formation_xml: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if formation_xml.strip_edges().is_empty():
		return entries

	var parser := XMLParser.new()
	if parser.open_buffer(("<root>" + formation_xml + "</root>").to_utf8_buffer()) != OK:
		return entries

	var current := {}
	var current_tag := ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var name := parser.get_node_name()
				if _is_slot_name(name):
					current = {
						"slot": name.substr(1).to_int() - 1,
						"role": "CM",
						"database_position": Vector2.ZERO,
					}
				elif name == "position" or name == "role":
					current_tag = name
			XMLParser.NODE_TEXT:
				if not current.is_empty():
					var text := parser.get_node_data().strip_edges()
					if current_tag == "position":
						current["database_position"] = _parse_position(text)
					elif current_tag == "role":
						current["role"] = role_from_string(text)
			XMLParser.NODE_ELEMENT_END:
				var end_name := parser.get_node_name()
				if end_name == current_tag:
					current_tag = ""
				elif _is_slot_name(end_name) and not current.is_empty():
					entries.append(current)
					current = {}

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["slot"]) < int(b["slot"]))
	return entries


static func normalize(entries: Array[Dictionary]) -> Array[Dictionary]:
	if entries.is_empty():
		return entries

	var positions: Array[Vector2] = []
	for entry in entries:
		var database_position: Vector2 = entry.get("database_position", Vector2.ZERO)
		var role := str(entry.get("role", "CM"))
		positions.append(database_position * DATABASE_WEIGHT
			+ default_role_position(role) * DEFAULT_WEIGHT)

	for iteration in MAX_ITERATIONS:
		var offsets: Array[Vector2] = []
		offsets.resize(positions.size())
		for i in offsets.size():
			offsets[i] = Vector2.ZERO
		var changed := false
		for first in positions.size() - 1:
			if str(entries[first].get("role", "CM")) == "GK":
				continue
			for second in range(first + 1, positions.size()):
				if str(entries[second].get("role", "CM")) == "GK":
					continue
				var difference := positions[first] - positions[second]
				var distance := difference.length()
				if distance >= MIN_DISTANCE:
					continue
				changed = true
				var distance_factor := 1.0 - distance / MIN_DISTANCE
				var direction := _normalized_or(difference, Vector2(0.0, 1.0))
				var push := direction * MIN_DISTANCE * distance_factor * 0.5
				offsets[first] += push
				offsets[second] -= push
		if not changed:
			break
		for i in positions.size():
			var position := positions[i] + offsets[i]
			positions[i] = Vector2(clampf(position.x, -1.0, 1.0), clampf(position.y, -1.0, 1.0))

	for i in entries.size():
		entries[i]["position"] = positions[i]
	return entries


static func parse_and_normalize(formation_xml: String) -> Array[Dictionary]:
	return normalize(parse(formation_xml))


static func _is_slot_name(name: String) -> bool:
	if name.length() < 2 or name[0] != "p":
		return false
	var number := name.substr(1)
	return number.is_valid_int() and int(number) >= 1 and int(number) <= SLOT_COUNT


static func _parse_position(text: String) -> Vector2:
	var parts := text.split(",", false)
	var x := parts[0].strip_edges().to_float() if parts.size() > 0 else 0.0
	var y := parts[1].strip_edges().to_float() if parts.size() > 1 else 0.0
	return Vector2(x, y)


static func _normalized_or(vector: Vector2, fallback: Vector2) -> Vector2:
	if absf(vector.x) < NORMALIZE_EPSILON and absf(vector.y) < NORMALIZE_EPSILON:
		return fallback
	return vector.normalized()
