class_name KitArrow
extends Control
# Prototype .kit-arrow: a 18x26 triangle that fades in only while its panel is
# live and has more than one kit.

var direction := -1
var active := false
var color := UiTokens.INK


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(is_active: bool, tint: Color) -> void:
	active = is_active
	color = tint
	queue_redraw()


func _draw() -> void:
	if not active or size.x <= 0.0 or size.y <= 0.0:
		return
	var half_w := UiTokens.KIT_ARROW_GLYPH_W * 0.5
	var half_h := UiTokens.KIT_ARROW_GLYPH_H * 0.5
	var center := size * 0.5
	var points: PackedVector2Array
	if direction < 0:
		points = PackedVector2Array([
			center + Vector2(-half_w, 0.0),
			center + Vector2(half_w, -half_h),
			center + Vector2(half_w, half_h),
		])
	else:
		points = PackedVector2Array([
			center + Vector2(half_w, 0.0),
			center + Vector2(-half_w, -half_h),
			center + Vector2(-half_w, half_h),
		])
	draw_colored_polygon(points, color)
