extends Control
# Godot port of the original SideSelectPage (GameplayFootball
# src/menu/sideselect.cpp): one icon per local device, Home/Away columns, a
# ready mark on the chosen side, keyboard/gamepad driven. The C++ match keeps
# owning HumanGamers; this screen only produces ShellState.controllers.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"
const PREMATCH_SCENE := "res://scenes/prematch.tscn"

const KEYBOARD_ICON := preload("res://assets/ui/controller/keyboard_small.png")
const GAMEPAD_ICON := preload("res://assets/ui/controller/controller_small.png")
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const READY_MARK := preload("res://scripts/ui/ready_mark.gd")

const ROW_REPEAT_MS := 250

var participants: Array = []
var home_caption: Label
var away_caption: Label
var phase_caption: Label
var help_label: Label
var status_label: Label
var panel: ColorRect

var _gamepad_repeat: Dictionary = {}
var _committed := false


func _ready() -> void:
	_build_ui()
	_build_participants()
	_layout()
	get_viewport().size_changed.connect(_layout)
	set_process_input(true)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.02)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	panel = ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.62)
	add_child(panel)

	home_caption = _caption("Team 1", Color(0.95, 0.92, 0.82))
	away_caption = _caption("Team 2", Color(0.95, 0.92, 0.82))
	phase_caption = _caption("choose your side", Color(0.78, 0.78, 0.70))
	help_label = _caption("Left/Right: side    Enter: ready    Esc: leave",
		Color(0.72, 0.72, 0.66))
	status_label = _caption("", Color(1.0, 0.68, 0.30))


func _caption(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _build_participants() -> void:
	var devices := InputSetup.available_devices()
	var count := devices.size()
	var saved: Array = ShellState.controllers if ShellState.controllers_configured else []
	for i in count:
		var device: Dictionary = devices[i]
		var side := 0
		# A lone keyboard starts on home. With several devices every row starts in
		# the centre until it is moved: a pre-assigned home row would otherwise
		# block the other device's ready (all active rows must confirm).
		if count == 1 and i == 0:
			side = -1
		for entry in saved:
			if not (entry is Dictionary):
				continue
			if str(entry.get("kind", "")) == str(device.get("kind", "")) \
					and int(entry.get("device", -1)) == int(device.get("device", -2)):
				side = _side_value(str(entry.get("side", "home")))
				break

		var icon := TextureRect.new()
		icon.texture = GAMEPAD_ICON if str(device.get("kind", "")) == "gamepad" else KEYBOARD_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(icon)

		var mark = READY_MARK.new()
		mark.visible = false
		add_child(mark)

		participants.append({
			"device": int(device.get("device", 0)),
			"kind": str(device.get("kind", "keyboard")),
			"name": str(device.get("name", "Device")),
			"side": side,
			"ready": false,
			"row": i,
			"icon": icon,
			"mark": mark,
		})


func _layout() -> void:
	var view := get_viewport_rect().size
	panel.position = Vector2(view.x * 0.10, view.y * 0.15)
	panel.size = Vector2(view.x * 0.80, view.y * 0.70)

	var caption_size := maxi(16, int(round(view.y * 0.035)))
	for label in [home_caption, away_caption, phase_caption, help_label, status_label]:
		label.add_theme_font_size_override("font_size", caption_size)

	_place(home_caption, view.x * 0.25, view.y * 0.10, view.x * 0.30, view.y * 0.06)
	_place(away_caption, view.x * 0.75, view.y * 0.10, view.x * 0.30, view.y * 0.06)
	_place(phase_caption, view.x * 0.50, view.y * 0.05, view.x * 0.40, view.y * 0.05)
	_place(help_label, view.x * 0.50, view.y * 0.88, view.x * 0.70, view.y * 0.05)
	_place(status_label, view.x * 0.50, view.y * 0.82, view.x * 0.70, view.y * 0.04)

	for participant in participants:
		var icon: TextureRect = participant["icon"]
		var mark = participant["mark"]
		var icon_size := Vector2(view.x * 0.14, view.y * 0.10)
		var side := int(participant["side"])
		var center_x := view.x * (0.25 if side < 0 else (0.75 if side > 0 else 0.50))
		var top := view.y * 0.20 + float(participant["row"]) * view.y * 0.15
		icon.position = Vector2(center_x - icon_size.x * 0.5, top)
		icon.size = icon_size
		mark.position = Vector2(icon.position.x + view.x * 0.05, top + view.y * 0.13)
		mark.size = Vector2(view.x * 0.03, view.y * 0.03)
		mark.queue_redraw()


func _place(label: Label, center_x: float, top: float, width: float, height: float) -> void:
	label.position = Vector2(center_x - width * 0.5, top)
	label.size = Vector2(width, height)


func _input(event: InputEvent) -> void:
	if _committed:
		return
	if event is InputEventKey:
		_handle_key(event as InputEventKey)
	elif event is InputEventJoypadButton:
		_handle_joy_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_handle_joy_motion(event as InputEventJoypadMotion)


func _handle_key(event: InputEventKey) -> void:
	if event.echo or not event.pressed:
		return
	var participant := _participant_kind("keyboard")
	if participant.is_empty():
		return
	match event.keycode:
		KEY_LEFT:
			_change_side(participant, -1)
		KEY_RIGHT:
			_change_side(participant, 1)
		KEY_ENTER, KEY_KP_ENTER:
			_set_ready(participant, true)
		KEY_ESCAPE:
			if bool(participant["ready"]):
				_set_ready(participant, false)
			else:
				_leave()
	_set_help(false)


func _handle_joy_button(event: InputEventJoypadButton) -> void:
	var participant := _participant_device(int(event.device))
	if participant.is_empty() or not event.pressed:
		return
	match int(event.button_index):
		JOY_BUTTON_DPAD_LEFT:
			_change_side(participant, -1)
		JOY_BUTTON_DPAD_RIGHT:
			_change_side(participant, 1)
		JOY_BUTTON_A:
			_set_ready(participant, true)
		JOY_BUTTON_B:
			if bool(participant["ready"]):
				_set_ready(participant, false)
			else:
				_leave()
	_set_help(true)


func _handle_joy_motion(event: InputEventJoypadMotion) -> void:
	if int(event.axis) != JOY_AXIS_LEFT_X or absf(event.axis_value) < 0.5:
		return
	var participant := _participant_device(int(event.device))
	if participant.is_empty():
		return
	var now := Time.get_ticks_msec()
	var device := int(event.device)
	if now - int(_gamepad_repeat.get(device, 0)) < ROW_REPEAT_MS:
		return
	_gamepad_repeat[device] = now
	_change_side(participant, -1 if event.axis_value < 0.0 else 1)
	_set_help(true)


func _participant_kind(kind: String) -> Dictionary:
	for participant in participants:
		if str(participant["kind"]) == kind:
			return participant
	return {}


func _participant_device(device: int) -> Dictionary:
	for participant in participants:
		if str(participant["kind"]) == "gamepad" and int(participant["device"]) == device:
			return participant
	return {}


func _change_side(participant: Dictionary, delta: int) -> void:
	if participant.is_empty():
		return
	var spatial := _spatial_index(int(participant["side"])) + delta
	spatial = clampi(spatial, 0, 2)
	var side := _side_from_spatial(spatial)
	if side == int(participant["side"]):
		return
	participant["side"] = side
	participant["ready"] = false
	var mark = participant["mark"]
	mark.set_checked(false)
	status_label.text = ""
	_layout()


func _set_ready(participant: Dictionary, ready: bool) -> void:
	if participant.is_empty():
		return
	if ready and int(participant["side"]) == 0:
		status_label.text = "Choose a side first."
		return
	if bool(participant["ready"]) == ready:
		if ready and _all_ready():
			_commit()
		return
	participant["ready"] = ready
	var mark = participant["mark"]
	mark.set_checked(ready)
	status_label.text = ""
	if ready and _all_ready():
		_commit()


func _all_ready() -> bool:
	var active := 0
	for participant in participants:
		if int(participant["side"]) == 0:
			continue
		active += 1
		if not bool(participant["ready"]):
			return false
	return active > 0


func _commit() -> void:
	if _committed:
		return
	var active: Array = []
	for participant in participants:
		if int(participant["side"]) == 0:
			continue
		active.append({
			"side": "away" if int(participant["side"]) > 0 else "home",
			"kind": str(participant["kind"]),
			"device": int(participant["device"]),
			"name": str(participant["name"]),
		})
	if active.is_empty():
		status_label.text = "Choose a side first."
		return
	_committed = true
	ShellState.set_controllers(active)
	var target := PREMATCH_SCENE if ShellState.has_selection() else TEAM_SELECT_SCENE
	get_tree().change_scene_to_file(target)


func _leave() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _set_help(gamepad: bool) -> void:
	help_label.text = ("Left/Right: side    A: ready    B: leave" if gamepad
		else "Left/Right: side    Enter: ready    Esc: leave")


func _spatial_index(side: int) -> int:
	if side < 0:
		return 0
	if side > 0:
		return 2
	return 1


func _side_from_spatial(spatial: int) -> int:
	if spatial <= 0:
		return -1
	if spatial >= 2:
		return 1
	return 0


func _side_value(side: String) -> int:
	return 1 if side == "away" else -1
