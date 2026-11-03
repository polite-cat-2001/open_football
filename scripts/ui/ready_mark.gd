class_name ReadyMark
extends Control
# Original side-select ready mark: a green disc with a white tick, drawn in the
# same place/size as SideSelectPage's generated icon.

var checked := false


func set_checked(value: bool) -> void:
	if checked == value:
		return
	checked = value
	visible = value
	queue_redraw()


func _draw() -> void:
	if not checked:
		return
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	draw_circle(center, radius, UiTokens.SIDE_READY_FILL)
	var width := maxf(1.0, radius * 0.18)
	var p0 := center + Vector2(-radius * 0.45, 0.0)
	var p1 := center + Vector2(-radius * 0.10, radius * 0.38)
	var p2 := center + Vector2(radius * 0.55, -radius * 0.40)
	draw_line(p0, p1, UiTokens.SIDE_READY_INK, width)
	draw_line(p1, p2, UiTokens.SIDE_READY_INK, width)
