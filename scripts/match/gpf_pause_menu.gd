class_name GpfPauseMenu
extends Node
# In-match pause menu, structurally ported from the original IngamePage
# (src/menu/ingame/ingame.cpp): Continue, game plan, controller select, side
# selection, camera settings, visual options, system settings, replay, forfeit.
# The C++ match is frozen by the orchestrator; this node only draws and emits.

signal resume_requested
signal forfeit_requested
signal game_plan_requested
signal controller_select_requested
signal side_select_requested
signal camera_requested
signal visual_requested
signal system_requested
signal replay_requested

const ITEMS := [
	{"id": "continue", "caption": "Continue"},
	{"id": "game_plan", "caption": "game plan"},
	{"id": "controller", "caption": "controller select"},
	{"id": "side", "caption": "side selection"},
	{"id": "camera", "caption": "camera settings"},
	{"id": "visual", "caption": "visual options"},
	{"id": "system", "caption": "system settings"},
	{"id": "replay", "caption": "replay"},
	{"id": "forfeit", "caption": "forfeit match"},
]

const DEFAULT_HINT := "Enter: select    Esc / Start: resume"

var layer: CanvasLayer
var panel: PanelContainer
var buttons: Array[Button] = []
var hint_label: Label
var index := 0

var confirm_layer: CanvasLayer
var confirm_buttons: Array[Button] = []
var confirm_index := 0
var confirm_open := false


func setup() -> void:
	_build()


func _build() -> void:
	layer = CanvasLayer.new()
	layer.name = "PauseMenu"
	layer.layer = 6
	layer.visible = false
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(title)

	for item in ITEMS:
		var button := Button.new()
		button.text = String(item["caption"])
		button.custom_minimum_size = Vector2(440, 38)
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_ALL
		var item_index := buttons.size()
		button.pressed.connect(_activate.bind(item_index))
		box.add_child(button)
		buttons.append(button)

	hint_label = Label.new()
	hint_label.text = DEFAULT_HINT
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.66))
	box.add_child(hint_label)

	_build_confirm()


func _build_confirm() -> void:
	confirm_layer = CanvasLayer.new()
	confirm_layer.name = "PauseConfirm"
	confirm_layer.layer = 7
	confirm_layer.visible = false
	add_child(confirm_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.98)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.55, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "forfeit match?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(title)

	var caption := Label.new()
	caption.text = "are you sure you want to forfeit?"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 17)
	box.add_child(caption)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	confirm_buttons.clear()
	for caption_text in ["OK, forfeit", "Continue match"]:
		var button := Button.new()
		button.text = caption_text
		button.custom_minimum_size = Vector2(190, 38)
		button.add_theme_font_size_override("font_size", 18)
		button.focus_mode = Control.FOCUS_ALL
		var button_index := confirm_buttons.size()
		button.pressed.connect(_activate_confirm.bind(button_index))
		row.add_child(button)
		confirm_buttons.append(button)


func is_open() -> bool:
	return layer != null and layer.visible


func open() -> void:
	if layer == null:
		return
	confirm_open = false
	confirm_layer.visible = false
	layer.visible = true
	index = 0
	hint_label.text = DEFAULT_HINT
	_refresh_focus()


func close() -> void:
	if not is_open():
		return
	if layer != null:
		layer.visible = false
	if confirm_layer != null:
		confirm_layer.visible = false
	confirm_open = false
	resume_requested.emit()


# Hide the menu without resuming the match: a submenu (game plan) takes over
# the same frozen match and returns to the pause menu when it closes.
func hide_for_submenu() -> void:
	if layer != null:
		layer.visible = false
	if confirm_layer != null:
		confirm_layer.visible = false
	confirm_open = false


func set_hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


func handle_key(event: InputEventKey) -> bool:
	if not is_open() or not event.pressed:
		return false
	if confirm_open:
		return _handle_confirm_key(event)
	return _handle_menu_key(event)


func handle_joy(event: InputEventJoypadButton) -> bool:
	if not is_open() or not event.pressed:
		return false
	match int(event.button_index):
		JOY_BUTTON_A:
			if confirm_open:
				_activate_confirm(confirm_index)
			else:
				_activate(index)
			return true
		JOY_BUTTON_B:
			if confirm_open:
				_close_confirm()
			else:
				close()
			return true
		JOY_BUTTON_DPAD_UP:
			_move(-1)
			return true
		JOY_BUTTON_DPAD_DOWN:
			_move(1)
			return true
		JOY_BUTTON_DPAD_LEFT:
			if confirm_open:
				_move(-1)
				return true
		JOY_BUTTON_DPAD_RIGHT:
			if confirm_open:
				_move(1)
				return true
	return false


func _handle_menu_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate(index)
		KEY_ESCAPE:
			close()
		_:
			return false
	return true


func _handle_confirm_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_LEFT, KEY_UP:
			confirm_index = (confirm_index - 1 + confirm_buttons.size()) % confirm_buttons.size()
			_refresh_focus()
		KEY_RIGHT, KEY_DOWN:
			confirm_index = (confirm_index + 1) % confirm_buttons.size()
			_refresh_focus()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate_confirm(confirm_index)
		KEY_ESCAPE:
			_close_confirm()
		_:
			return false
	return true


func _move(delta: int) -> void:
	if confirm_open:
		confirm_index = (confirm_index + delta + confirm_buttons.size()) % confirm_buttons.size()
	else:
		index = (index + delta + buttons.size()) % buttons.size()
	_refresh_focus()


func _refresh_focus() -> void:
	if confirm_open and not confirm_buttons.is_empty():
		confirm_buttons[confirm_index].grab_focus()
	elif not buttons.is_empty():
		buttons[index].grab_focus()


func _activate(i: int) -> void:
	if i < 0 or i >= ITEMS.size():
		return
	var id := String(ITEMS[i]["id"])
	match id:
		"continue":
			close()
		"forfeit":
			_open_confirm()
		"game_plan":
			game_plan_requested.emit()
		"controller":
			controller_select_requested.emit()
			set_hint("controller select: не портировано")
		"side":
			side_select_requested.emit()
			set_hint("side selection: не портировано")
		"camera":
			camera_requested.emit()
		"visual":
			visual_requested.emit()
		"system":
			system_requested.emit()
		"replay":
			replay_requested.emit()
			set_hint("replay: не портировано")


func _open_confirm() -> void:
	confirm_open = true
	confirm_index = 0
	confirm_layer.visible = true
	_refresh_focus()


func _close_confirm() -> void:
	confirm_open = false
	confirm_layer.visible = false
	_refresh_focus()


func _activate_confirm(i: int) -> void:
	if i == 0:
		forfeit_requested.emit()
	else:
		_close_confirm()
