extends Control
# Godot port of NetworkHostPage (src/menu/network/network.cpp): port + name,
# "Open lobby" starts the original NetServer and enters the shared side screen.

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const NET_SHELL := preload("res://scripts/net/net_shell.gd")

var title_label: Label
var port_input: LineEdit
var name_input: LineEdit
var open_button: Button
var back_button: Button
var status_label: Label
var _row_labels: Array[Label] = []
var _form: GridContainer


func _ready() -> void:
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	port_input.text = str(NET_SHELL.last_host_port)
	name_input.text = NET_SHELL.last_host_name
	port_input.grab_focus()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.02)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	title_label = _label("Host game", Color(0.95, 0.92, 0.82))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label = _label("", Color(1.0, 0.68, 0.30))

	_form = GridContainer.new()
	_form.columns = 2
	_form.add_theme_constant_override("h_separation", 18)
	_form.add_theme_constant_override("v_separation", 12)
	add_child(_form)

	_row_labels.append(_form_label("Port"))
	port_input = LineEdit.new()
	port_input.max_length = 5
	port_input.add_theme_font_override("font", MENU_FONT)
	port_input.text_changed.connect(_on_port_changed)
	_form.add_child(_row_labels[0])
	_form.add_child(port_input)

	_row_labels.append(_form_label("Name"))
	name_input = LineEdit.new()
	name_input.max_length = 16
	name_input.add_theme_font_override("font", MENU_FONT)
	_form.add_child(_row_labels[1])
	_form.add_child(name_input)

	open_button = Button.new()
	open_button.text = "Open lobby"
	open_button.add_theme_font_override("font", MENU_FONT)
	open_button.pressed.connect(_open_lobby)
	_form.add_child(open_button)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.add_theme_font_override("font", MENU_FONT)
	back_button.pressed.connect(_on_back)
	_form.add_child(back_button)

	port_input.text_submitted.connect(func(_text): _open_lobby())
	name_input.text_submitted.connect(func(_text): _open_lobby())


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
	title_label.position = Vector2(view.x * 0.20, view.y * 0.10)
	title_label.size = Vector2(view.x * 0.60, view.y * 0.06)

	var form_size := clampi(int(view.y * 0.026), 14, 24)
	for label in _row_labels:
		label.add_theme_font_size_override("font_size", form_size)
	for control in [port_input, name_input]:
		control.add_theme_font_size_override("font_size", form_size)
		control.custom_minimum_size = Vector2(260, 42)
	for button in [open_button, back_button]:
		button.add_theme_font_size_override("font_size", form_size)
		button.custom_minimum_size = Vector2(260, 46)

	_form.position = Vector2(view.x * 0.30, view.y * 0.24)
	_form.size = Vector2(view.x * 0.40, view.y * 0.40)

	status_label.add_theme_font_size_override("font_size", maxi(12, int(view.y * 0.020)))
	status_label.position = Vector2(view.x * 0.20, view.y * 0.78)
	status_label.size = Vector2(view.x * 0.60, view.y * 0.06)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _open_lobby() -> void:
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
	if not bool(runtime.net_host(port, player_name)):
		status_label.text = "Could not bind port %d: %s" % [port, runtime.get_last_error()]
		return

	NET_SHELL.last_host_port = port
	NET_SHELL.last_host_name = player_name
	get_tree().change_scene_to_file(SIDES_SCENE)


func _on_back() -> void:
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	get_tree().change_scene_to_file(NETWORK_MENU_SCENE)


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
