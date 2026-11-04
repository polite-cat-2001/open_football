class_name KitArt
extends Control
# Prototype KitArt.svelte port: one shirt silhouette drawn from a kit spec.
# Patterns are clipped with Geometry2D against the shirt polygon, so no image
# assets or per-kit textures are needed in the menu.

const VIEWBOX := Vector2(240.0, 196.0)
var SHIRT := PackedVector2Array([
	Vector2(80, 10), Vector2(58, 18), Vector2(26, 32), Vector2(8, 76),
	Vector2(50, 94), Vector2(66, 74), Vector2(66, 186), Vector2(174, 186),
	Vector2(174, 74), Vector2(190, 94), Vector2(232, 76), Vector2(214, 32),
	Vector2(182, 18), Vector2(160, 10), Vector2(150, 20), Vector2(135, 27),
	Vector2(120, 32), Vector2(105, 27), Vector2(92, 20),
])
var COLLAR := PackedVector2Array([
	Vector2(80, 10), Vector2(92, 20), Vector2(105, 27), Vector2(120, 32),
	Vector2(135, 27), Vector2(150, 20), Vector2(160, 10),
])
const STRIPES := 8
const STRIPE_STEP := 44.0
const STRIPE_WIDTH := 22.0
const HOOPS := 6
const HOOP_STEP := 34.0
const HOOP_HEIGHT := 17.0

var kit: Dictionary = {}

var _shirt_color := Color(0.96, 0.97, 0.98)
var _shorts_color := Color(0.96, 0.97, 0.98)
var _pattern := "plain"
var _pattern_color := Color.BLACK


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_kit(kit)


func set_kit(value: Dictionary) -> void:
	kit = value.duplicate(true) if value is Dictionary else {}
	_shirt_color = _parse_color(kit.get("shirt"), Color(0.96, 0.97, 0.98))
	_shorts_color = _parse_color(kit.get("shorts"), Color(0.96, 0.97, 0.98))
	_pattern = str(kit.get("pattern", "plain"))
	if not ["plain", "stripes", "halves", "hoops", "sash"].has(_pattern):
		_pattern = "plain"
	_pattern_color = _parse_color(kit.get("pattern_color"), _shirt_color)
	queue_redraw()


func current_kit() -> Dictionary:
	return kit


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := minf(size.x / VIEWBOX.x, size.y / VIEWBOX.y)
	var origin := (size - VIEWBOX * scale) * 0.5
	draw_set_transform(origin, 0.0, Vector2(scale, scale))

	draw_colored_polygon(SHIRT, _shirt_color)
	for part in _pattern_parts():
		for polygon in Geometry2D.intersect_polygons(SHIRT, part):
			draw_colored_polygon(polygon, _pattern_color)

	var outline := SHIRT.duplicate()
	outline.append(SHIRT[0])
	draw_polyline(outline, UiTokens.KIT_ART_EDGE, 1.4, true)
	draw_polyline(COLLAR, _shorts_color, 7.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pattern_parts() -> Array:
	var parts: Array = []
	match _pattern:
		"stripes":
			for index in STRIPES:
				var x := -STRIPE_STEP + float(index) * STRIPE_STEP
				parts.append(_rect(x, 0.0, STRIPE_WIDTH, VIEWBOX.y))
		"halves":
			parts.append(_rect(0.0, 0.0, VIEWBOX.x * 0.5, VIEWBOX.y))
		"hoops":
			for index in HOOPS:
				parts.append(_rect(0.0, float(index) * HOOP_STEP, VIEWBOX.x, HOOP_HEIGHT))
		"sash":
			parts.append(PackedVector2Array([
				Vector2(-36, 142), Vector2(82, 72), Vector2(284, 72), Vector2(-36, 210),
			]))
	return parts


func _rect(x: float, y: float, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + width, y),
		Vector2(x + width, y + height), Vector2(x, y + height),
	])


func _parse_color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	if not text.begins_with("#"):
		text = "#" + text
	return Color.from_string(text, fallback)
