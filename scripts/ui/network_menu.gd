extends Control
# Godot port of NetworkMenuPage (GameplayFootball src/menu/network/network.cpp):
# Host game / Join game / Back.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const HOST_SCENE := "res://scenes/network_host.tscn"
const JOIN_SCENE := "res://scenes/network_join.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const NET_SHELL := preload("res://scripts/net/net_shell.gd")

var title_label: Label
var buttons: Array[Button] = []


func _ready() -> void:
	# A stale session must not leak into a new network menu.
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	buttons[0].grab_focus()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.02)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	title_label = Label.new()
	title_label.text = "Network"
	title_label.add_theme_font_override("font", MENU_FONT)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title_label)

	_add_button("HostBtn", "Host game", _on_host)
	_add_button("JoinBtn", "Join game", _on_join)
	_add_button("BackBtn", "Back", _on_back)


func _add_button(node_name: String, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.add_theme_font_override("font", MENU_FONT)
	button.custom_minimum_size = Vector2(320, 52)
	button.pressed.connect(callback)
	add_child(button)
	buttons.append(button)


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0 or view.y <= 0:
		return
	title_label.add_theme_font_size_override("font_size",
		clampi(int(view.y * 0.06), 28, 72))
	title_label.position = Vector2(view.x * 0.2, view.y * 0.14)
	title_label.size = Vector2(view.x * 0.6, view.y * 0.10)

	var width := minf(360.0, view.x * 0.34)
	var height := clampf(view.y * 0.085, 48.0, 88.0)
	var gap := height * 0.30
	var total := buttons.size() * height + maxf(0.0, buttons.size() - 1) * gap
	var top := view.y * 0.52 - total * 0.5
	var font_size := clampi(int(height * 0.34), 16, 30)
	for i in buttons.size():
		var button := buttons[i]
		button.position = Vector2(view.x * 0.5 - width * 0.5, top + i * (height + gap))
		button.size = Vector2(width, height)
		button.add_theme_font_size_override("font_size", font_size)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.echo and key.pressed and key.keycode == KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if not joy.pressed:
			return
		if int(joy.button_index) == JOY_BUTTON_B:
			_on_back()
			get_viewport().set_input_as_handled()
		elif int(joy.button_index) == JOY_BUTTON_A:
			var focus := get_viewport().gui_get_focus_owner()
			if focus is BaseButton and not (focus as BaseButton).disabled:
				(focus as BaseButton).pressed.emit()
				get_viewport().set_input_as_handled()


func _on_host() -> void:
	get_tree().change_scene_to_file(HOST_SCENE)


func _on_join() -> void:
	get_tree().change_scene_to_file(JOIN_SCENE)


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
