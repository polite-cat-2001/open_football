extends CanvasLayer
# Full-screen "CONNECTING" curtain for a peer that joins a match already in
# progress: the pre-match side-select screen must never flash, and whoever becomes
# the current scene (the match, the main menu) closes the curtain over itself, so
# the fade-out reveals the real screen underneath.
#
# Cancel is local (ESC / pad B): the peer never reached the match, so leaving the
# session needs no agreement from the host.

const FADE_IN := 0.15
const FADE_OUT := 0.24

var content: Control
var title: Label
var hint: Label
var spinner: Spinner

var _cancel := Callable()
var _open := false
var _tween: Tween


class Spinner:
	extends Control
	# Twelve dots with a fading tail: cheap enough to need no texture.

	const DOTS := 12

	var angle := 0.0

	func _process(delta: float) -> void:
		angle = fmod(angle + delta * TAU / 0.9, TAU)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 5.0
		for i in DOTS:
			var a := angle + TAU * float(i) / float(DOTS)
			var t := float(i) / float(DOTS)
			var color := UiTokens.FOCUS_MARK
			color.a = 1.0 - 0.78 * t
			draw_circle(center + Vector2(cos(a), sin(a)) * radius, 3.6 - 1.8 * t, color)


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	set_process(false)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.03, 0.06)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	spinner = Spinner.new()
	spinner.custom_minimum_size = Vector2(64, 64)
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(spinner)

	title = Label.new()
	title.name = "Title"
	title.text = "CONNECTING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTheme.barlow(700))
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UiTokens.INK)
	box.add_child(title)

	hint = Label.new()
	hint.name = "Hint"
	hint.text = "ESC / B: CANCEL"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", UiTheme.barlow(600))
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UiTokens.INK_2)
	box.add_child(hint)


func is_open() -> bool:
	return _open


# `cancel` runs on ESC / pad B; an invalid callable means "not cancellable".
func open(cancel: Callable = Callable(), text := "CONNECTING") -> void:
	title.text = text
	_cancel = cancel
	hint.visible = cancel.is_valid()
	visible = true
	set_process(true)
	if _open:
		return
	_open = true
	_animate(1.0, FADE_IN)


func close() -> void:
	if not _open:
		return
	_open = false
	_cancel = Callable()
	_animate(0.0, FADE_OUT, true)


# Released without animating (a scene swap that must not wait for the fade).
func hide_now() -> void:
	_open = false
	_cancel = Callable()
	visible = false
	set_process(false)
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _animate(alpha: float, time: float, hide_after := false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if DisplayServer.get_name() == "headless":
		content.modulate.a = alpha
		if hide_after:
			hide_now()
		return
	content.pivot_offset = content.size * 0.5
	_tween = create_tween()
	_tween.tween_property(content, "modulate:a", alpha, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hide_after:
		_tween.tween_callback(hide_now)


func _input(event: InputEvent) -> void:
	if not _open or not _cancel.is_valid():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			_fire_cancel(event)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed and button.button_index == JOY_BUTTON_B:
			_fire_cancel(event)


func _fire_cancel(event: InputEvent) -> void:
	var callback := _cancel
	_cancel = Callable()
	if get_viewport() != null:
		get_viewport().set_input_as_handled()
	if callback.is_valid():
		callback.call()
