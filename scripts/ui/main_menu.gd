extends Control

var title_label: Label
var menu_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.1, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "OpenFootball"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(title_label)

	var btn := Button.new()
	btn.name = "StartBtn"
	btn.text = "Start Match"
	add_child(btn)
	menu_buttons.append(btn)

	if not btn.pressed.is_connected(_on_start):
		btn.pressed.connect(_on_start)

	var select_btn := Button.new()
	select_btn.name = "SelectTeamsBtn"
	select_btn.text = "Select Teams"
	add_child(select_btn)
	menu_buttons.append(select_btn)
	if not select_btn.pressed.is_connected(_on_select_teams):
		select_btn.pressed.connect(_on_select_teams)

	var classic_btn := Button.new()
	classic_btn.name = "ClassicMatchBtn"
	classic_btn.text = "Classic Match (legacy)"
	add_child(classic_btn)
	menu_buttons.append(classic_btn)
	if not classic_btn.pressed.is_connected(_on_classic_match):
		classic_btn.pressed.connect(_on_classic_match)

	# Keyboard/gamepad entry point: arrows and ui_accept work on the focused
	# button once one of them owns focus.
	btn.grab_focus()

	print("Main menu ready")


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0 or view.y <= 0:
		return
	title_label.add_theme_font_size_override("font_size",
		clampi(int(view.y * 0.085), 36, 96))
	title_label.position = Vector2(view.x * 0.10, view.y * 0.12)
	title_label.size = Vector2(view.x * 0.80, view.y * 0.15)

	var button_width := minf(360.0, view.x * 0.34)
	var button_height := clampf(view.y * 0.085, 48.0, 92.0)
	var gap := button_height * 0.25
	var total_height := menu_buttons.size() * button_height \
		+ maxf(0.0, menu_buttons.size() - 1) * gap
	var top := view.y * 0.52 - total_height * 0.5
	var font_size := clampi(int(button_height * 0.34), 16, 30)
	for i in menu_buttons.size():
		var button := menu_buttons[i]
		button.position = Vector2(view.x * 0.5 - button_width * 0.5,
			top + i * (button_height + gap))
		button.size = Vector2(button_width, button_height)
		button.add_theme_font_size_override("font_size", font_size)


func _input(event: InputEvent) -> void:
	# Godot 4.7's default ui_accept has no joypad button, so A must be handled
	# explicitly. D-pad/left stick navigation comes from ui_up/down/left/right.
	if event is InputEventJoypadButton and event.pressed \
			and int((event as InputEventJoypadButton).button_index) == JOY_BUTTON_A:
		var viewport := get_viewport()
		var focus := viewport.gui_get_focus_owner() if viewport != null else null
		if focus is BaseButton and not (focus as BaseButton).disabled:
			(focus as BaseButton).pressed.emit()
			if viewport != null:
				viewport.set_input_as_handled()


func _on_start() -> void:
	# Match flow follows the original: side/controller select first, then team
	# select (when needed) and the prematch. The controller screen itself skips
	# team select when a pair is already picked.
	var target := "res://scenes/controller_select.tscn"
	var packed := load(target)
	if not packed:
		push_error("Failed to load " + target)
		return
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("change_scene_to_packed failed: " + str(err))


func _on_select_teams() -> void:
	print("Select Teams clicked")
	var packed := load("res://scenes/team_select.tscn")
	if not packed:
		push_error("Failed to load team_select.tscn")
		return
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("change_scene_to_packed failed: " + str(err))


func _on_classic_match() -> void:
	print("Classic Match clicked")
	var packed := load("res://scenes/match.tscn")
	if not packed:
		push_error("Failed to load match.tscn")
		return
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("change_scene_to_packed failed: " + str(err))
