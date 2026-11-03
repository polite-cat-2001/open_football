class_name TeamStars
extends Control
# Five prototype stars drawn procedurally: full, half (left half filled) and
# empty. A Control instead of text so the half state does not depend on font
# glyphs or clipping node tricks.

const STAR_COUNT := 5
const INNER_RATIO := 0.45

var stars := 0.0
var on_dark := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_stars(value: float) -> void:
	stars = clampf(value, 0.0, float(STAR_COUNT))
	queue_redraw()


func set_on_dark(value: bool) -> void:
	if on_dark == value:
		return
	on_dark = value
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var empty := UiTokens.TEAM_STAR_EMPTY_FOCUS if on_dark else UiTokens.TEAM_STAR_EMPTY
	var slot := size.x / float(STAR_COUNT)
	var radius := minf(size.y * 0.46, slot * 0.44)
	for index in STAR_COUNT:
		var center := Vector2(slot * (float(index) + 0.5), size.y * 0.5)
		var polygon := _star_polygon(center, radius)
		if stars >= float(index + 1):
			draw_colored_polygon(polygon, UiTokens.TEAM_STAR_FULL)
			continue
		draw_colored_polygon(polygon, empty)
		if stars > float(index):
			var clip := PackedVector2Array([
				Vector2(center.x - radius, center.y - radius),
				Vector2(center.x, center.y - radius),
				Vector2(center.x, center.y + radius),
				Vector2(center.x - radius, center.y + radius),
			])
			for part in Geometry2D.intersect_polygons(polygon, clip):
				draw_colored_polygon(part, UiTokens.TEAM_STAR_FULL)


func _star_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in STAR_COUNT * 2:
		var angle := -PI * 0.5 + float(index) * PI / float(STAR_COUNT)
		var point_radius := radius if index % 2 == 0 else radius * INNER_RATIO
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	return points
