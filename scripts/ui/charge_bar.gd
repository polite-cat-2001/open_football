class_name ChargeBar
extends Control
# Action charge under the striker's feet: a thin screen-space bar that fills
# green -> red with the shot/pass power. GpfHud positions it from the projected
# feet and only shows it while a charge is running.

const BAR_W := 56.0
const BAR_H := 4.0

var ratio := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(BAR_W, BAR_H)
	visible = false
	resized.connect(queue_redraw)


func set_ratio(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, ratio):
		return
	ratio = clamped
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, BAR_W, BAR_H), Color(0.02, 0.03, 0.08, 0.72), true)
	var fill := BAR_W * ratio
	var steps := 24
	var step_w := BAR_W / float(steps)
	for i in steps:
		var x := float(i) * step_w
		if x >= fill:
			break
		var color := UiTokens.FOCUS_MARK.lerp(UiTokens.RAIL, x / BAR_W)
		draw_rect(Rect2(x, 0.5, minf(step_w, fill - x), BAR_H - 1.0), color)
	draw_rect(Rect2(0.0, 0.0, BAR_W, BAR_H), Color(0, 0, 0, 0.55), false, 1.0)
