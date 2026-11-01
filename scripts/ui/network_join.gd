extends Control
# Godot port of NetworkJoinPage (src/menu/network/network.cpp): address + port +
# name, "Connecting..." polling the NetClient handshake, readable reject reason.

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const NET_SHELL := preload("res://scripts/net/net_shell.gd")

var title_label: Label
var address_input: LineEdit
var port_input: LineEdit
var name_input: LineEdit
var connect_button: Button
var back_button: Button
var status_label: Label
var _form: GridContainer
var _row_labels: Array[Label] = []
var _connecting := false


func _ready() -> void:
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	address_input.text = NET_SHELL.last_join_address
	port_input.text = str(NET_SHELL.last_join_port)
	name_input.text = NET_SHELL.last_join_name
	address_input.grab_focus()
	set_process(true)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.02)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	title_label = _label("Join game", Color(0.95, 0.92, 0.82))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label = _label("", Color(1.0, 0.68, 0.30))

	_form = GridContainer.new()
	_form.columns = 2
	_form.add_theme_constant_override("h_separation", 18)
	_form.add_theme_constant_override("v_separation", 12)
	add_child(_form)

	_row_labels.append(_form_label("Address"))
	address_input = _line_edit(64)
	_form.add_child(_row_labels[0])
	_form.add_child(address_input)

	_row_labels.append(_form_label("Port"))
	port_input = _line_edit(5)
	port_input.text_changed.connect(_on_port_changed)
	_form.add_child(_row_labels[1])
	_form.add_child(port_input)

	_row_labels.append(_form_label("Name"))
	name_input = _line_edit(16)
	_form.add_child(_row_labels[2])
	_form.add_child(name_input)

	connect_button = Button.new()
	connect_button.text = "Connect"
	connect_button.add_theme_font_override("font", MENU_FONT)
	connect_button.pressed.connect(_connect)
	_form.add_child(connect_button)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.add_theme_font_override("font", MENU_FONT)
	back_button.pressed.connect(_on_back)
	_form.add_child(back_button)

	for field in [address_input, port_input, name_input]:
		field.text_submitted.connect(func(_text): _connect())


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.72))
	label.custom_minimum_size = Vector2(140, 42)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _line_edit(max_length: int) -> LineEdit:
	var input := LineEdit.new()
	input.max_length = max_length
	input.add_theme_font_override("font", MENU_FONT)
	return input


func _on_port_changed(text: String) -> void:
	var digits := ""
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			digits += text[i]
	if digits != text:
		port_input.text = digits
		port_input.caret_column = digits.length()


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0 or view.y <= 0:
		return
	var title_size := clampi(int(view.y * 0.05), 24, 56)
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.position = Vector2(view.x * 0.20, view.y * 0.08)
	title_label.size = Vector2(view.x * 0.60, view.y * 0.06)

	var form_size := clampi(int(view.y * 0.026), 14, 24)
	for label in _row_labels:
		label.add_theme_font_size_override("font_size", form_size)
	for control in [address_input, port_input, name_input]:
		control.add_theme_font_size_override("font_size", form_size)
		control.custom_minimum_size = Vector2(300, 42)
	for button in [connect_button, back_button]:
		button.add_theme_font_size_override("font_size", form_size)
		button.custom_minimum_size = Vector2(300, 46)

	_form.position = Vector2(view.x * 0.28, view.y * 0.20)
	_form.size = Vector2(view.x * 0.44, view.y * 0.46)

	status_label.add_theme_font_size_override("font_size", maxi(12, int(view.y * 0.020)))
	status_label.position = Vector2(view.x * 0.20, view.y * 0.76)
	status_label.size = Vector2(view.x * 0.60, view.y * 0.06)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _connect() -> void:
	if _connecting:
		return
	var address := address_input.text.strip_edges()
	if not _valid_address(address):
		status_label.text = "Invalid address"
		return
	var port := int(port_input.text)
	if port <= 0 or port > 65535:
		status_label.text = "Invalid port"
		return
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		status_label.text = "Enter a name"
		return

	var runtime := NET_SHELL.runtime(get_tree())
	if runtime == null:
		status_label.text = "Runtime is not available"
		return
	if bool(runtime.is_net_active()):
		runtime.net_leave()
	if not bool(runtime.net_join(address, port, player_name)):
		status_label.text = runtime.get_last_error()
		return

	NET_SHELL.last_join_address = address
	NET_SHELL.last_join_port = port
	NET_SHELL.last_join_name = player_name
	_connecting = true
	connect_button.disabled = true
	status_label.text = "Connecting..."


func _process(_delta: float) -> void:
	if not _connecting:
		return
	var runtime := NET_SHELL.active_runtime(get_tree())
	if runtime == null:
		_connecting = false
		connect_button.disabled = false
		status_label.text = "Connection closed"
		return
	var info: Dictionary = runtime.net_lobby()
	var connection := int(info.get("connection", 0))
	if connection == 3 and bool(info.get("accepted", false)):
		_connecting = false
		get_tree().change_scene_to_file(SIDES_SCENE)
		return
	if connection == 0:
		var reason := str(info.get("reject_text", ""))
		_connecting = false
		connect_button.disabled = false
		status_label.text = reason if not reason.is_empty() else "Connection failed"


func _on_back() -> void:
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	get_tree().change_scene_to_file(NETWORK_MENU_SCENE)


func _valid_address(text: String) -> bool:
	if text.is_empty() or text.length() > 253:
		return false
	var only_digits_and_dots := true
	for i in text.length():
		var c := text[i]
		if c < "0" or c > "9":
			if c != ".":
				only_digits_and_dots = false
				break
	if only_digits_and_dots:
		var parts := text.split(".")
		if parts.size() != 4:
			return false
		for part in parts:
			if part.is_empty() or part.length() > 3:
				return false
			if int(part) < 0 or int(part) > 255:
				return false
		return true
	for i in text.length():
		var c := text[i]
		var ok := (c >= "0" and c <= "9") or (c >= "a" and c <= "z") \
			or (c >= "A" and c <= "Z") or c == "-" or c == "."
		if not ok:
			return false
	var labels := text.split(".")
	for label in labels:
		if label.is_empty() or label.length() > 63:
			return false
		if label.begins_with("-") or label.ends_with("-"):
			return false
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.echo and key.pressed:
			NET_SHELL.note_local_device(get_tree(), "keyboard", 0)
		if not key.echo and key.pressed and key.keycode == KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if not joy.pressed:
			return
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(joy.device))
		if int(joy.button_index) == JOY_BUTTON_B:
			_on_back()
			get_viewport().set_input_as_handled()
		elif int(joy.button_index) == JOY_BUTTON_A:
			var focus := get_viewport().gui_get_focus_owner()
			if focus is BaseButton and not (focus as BaseButton).disabled:
				(focus as BaseButton).pressed.emit()
				get_viewport().set_input_as_handled()
