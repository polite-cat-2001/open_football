class_name HubValueSlider
extends Control
# Small design-system slider used by the match-options overlay. Keyboard/gamepad
# adjust it through the hub view; the mouse can click/drag the track directly.

signal value_changed(value: float)

const TRACK_H := 6.0
const KNOB_RADIUS := 9.0

var min_value := 0.0
var max_value := 1.0
var step := 0.01
var value := 0.0
var editable := true

var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(120.0, 32.0)


func setup(minimum: float, maximum: float, step_value: float, initial: float,
		can_edit := true) -> void:
	min_value = minimum
	max_value = maximum
	step = maxf(step_value, 0.0001)
	editable = can_edit
	set_value(initial, false)
	queue_redraw()


func set_value(new_value: float, emit := true) -> void:
	var snapped := roundf(new_value / step) * step
	var next := clampf(snapped, min_value, max_value)
	var changed := not is_equal_approx(next, value)
	value = next
	queue_redraw()
	if emit and changed:
		value_changed.emit(value)


func adjust(delta: int) -> void:
	if not editable or delta == 0:
		return
	set_value(value + step * float(delta))


func ratio() -> float:
	if is_equal_approx(max_value, min_value):
		return 0.0
	return (value - min_value) / (max_value - min_value)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var track_y := size.y * 0.5
	var track := Rect2(KNOB_RADIUS, track_y - TRACK_H * 0.5, size.x - KNOB_RADIUS * 2.0,
		TRACK_H)
	draw_rect(track, Color(1.0, 1.0, 1.0, 0.16), true)
	var fill := Rect2(track.position, Vector2(track.size.x * ratio(), track.size.y))
	draw_rect(fill, UiTokens.FOCUS_MARK if editable else UiTokens.FOCUS_INK_2, true)
	var knob := Vector2(track.position.x + track.size.x * ratio(), track_y)
	draw_circle(knob, KNOB_RADIUS, UiTokens.FOCUS_MARK if editable else UiTokens.FOCUS_INK_2)


func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		_dragging = mouse.pressed
		if mouse.pressed:
			_set_from_mouse(mouse.position.x)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_mouse((event as InputEventMouseMotion).position.x)
		accept_event()


func _set_from_mouse(x: float) -> void:
	var usable := maxf(size.x - KNOB_RADIUS * 2.0, 1.0)
	var next_ratio := clampf((x - KNOB_RADIUS) / usable, 0.0, 1.0)
	set_value(min_value + (max_value - min_value) * next_ratio)
