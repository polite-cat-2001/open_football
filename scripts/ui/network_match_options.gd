extends Control
# Godot port of NetworkMatchOptionsPage (src/menu/network/networkmatchoptions.cpp):
# the Options phase between team selection and kickoff. Only the host edits the
# AI difficulty / match duration; every peer mirrors LobbyState. The host starts
# immediately and broadcasts MatchSetup (the client waits for it).

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"
const MATCH_SCENE := "res://scenes/gpf_slice.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
const NETWORK_MATCH := preload("res://scripts/net/network_match.gd")

var header_label: Label
var difficulty_slider: HSlider
var duration_slider: HSlider
var difficulty_value: Label
var duration_value: Label
var start_button: Button
var status_label: Label
var help_label: Label
var panel: ColorRect
var _grid: VBoxContainer

var _host := false
var _host_setup_done := false
var _match_started := false
var _syncing := false


func _ready() -> void:
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_poll_lobby()
	set_process(true)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.02)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	panel = ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.66)
	add_child(panel)

	header_label = _label("Match options", Color(0.95, 0.92, 0.82))
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 16)
	add_child(_grid)

	difficulty_slider = _slider_row("difficulty (when HUMAN vs CPU)")
	duration_slider = _slider_row("match duration (5 minutes .. 25 min.)")

	start_button = Button.new()
	start_button.text = "Start match"
	start_button.add_theme_font_override("font", MENU_FONT)
	start_button.pressed.connect(_start_match)
	_grid.add_child(start_button)

	status_label = _label("", Color(0.72, 0.72, 0.66))
	help_label = _label("Esc/B: back to teams", Color(0.62, 0.62, 0.58))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _slider_row(caption: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_grid.add_child(row)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.74))
	label.custom_minimum_size = Vector2(170, 40)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.001
	slider.value = 0.8
	slider.custom_minimum_size = Vector2(120, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_option_changed)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.add_theme_font_override("font", MENU_FONT)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	value_label.custom_minimum_size = Vector2(64, 40)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	if caption.begins_with("difficulty"):
		difficulty_value = value_label
	else:
		duration_value = value_label
	return slider


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0 or view.y <= 0:
		return
	panel.position = Vector2(view.x * 0.30, view.y * 0.20)
	panel.size = Vector2(view.x * 0.40, view.y * 0.70)

	var header_size := clampi(int(view.y * 0.035), 18, 40)
	header_label.add_theme_font_size_override("font_size", header_size)
	header_label.position = Vector2(view.x * 0.30, view.y * 0.15)
	header_label.size = Vector2(view.x * 0.40, view.y * 0.05)

	_grid.position = Vector2(view.x * 0.33, view.y * 0.29)
	_grid.size = Vector2(view.x * 0.34, view.y * 0.50)

	for label in [difficulty_value, duration_value]:
		if label != null:
			label.add_theme_font_size_override("font_size", maxi(12, int(view.y * 0.019)))
	start_button.add_theme_font_size_override("font_size", maxi(14, int(view.y * 0.024)))
	start_button.custom_minimum_size = Vector2(0, 48)
	status_label.add_theme_font_size_override("font_size", maxi(12, int(view.y * 0.020)))
	status_label.position = Vector2(view.x * 0.20, view.y * 0.86)
	status_label.size = Vector2(view.x * 0.60, view.y * 0.04)
	help_label.add_theme_font_size_override("font_size", maxi(11, int(view.y * 0.018)))
	help_label.position = Vector2(view.x * 0.20, view.y * 0.91)
	help_label.size = Vector2(view.x * 0.60, view.y * 0.03)


func _poll_lobby() -> void:
	if _match_started:
		return
	var info := NET_SHELL.lobby(get_tree())
	if info.is_empty() or not bool(info.get("active", false)):
		get_tree().change_scene_to_file(NETWORK_MENU_SCENE)
		return
	if bool(info.get("is_client", false)) and int(info.get("connection", 0)) == 0:
		if NET_SHELL.is_active(get_tree()):
			NET_SHELL.leave(get_tree())
		get_tree().change_scene_to_file(NETWORK_MENU_SCENE)
		return

	var lobby: Dictionary = info.get("lobby", {})
	if int(lobby.get("phase", -1)) != 2:
		get_tree().change_scene_to_file(LOBBY_SCENE)
		return

	_host = bool(info.get("is_host", false))
	if _host:
		if not _host_setup_done:
			_host_setup_done = true
			_setup_host(lobby)
	else:
		_setup_client(lobby)


func _setup_host(lobby: Dictionary) -> void:
	_syncing = true
	difficulty_slider.value = float(lobby.get("match_difficulty", 0.8))
	duration_slider.value = float(lobby.get("match_duration", 1.0))
	difficulty_slider.editable = true
	duration_slider.editable = true
	start_button.disabled = false
	status_label.text = "Host: set options - Start match; Esc: back to teams"
	difficulty_slider.grab_focus()
	_update_values()
	_syncing = false
	# Seed the lobby so clients see the starting values immediately.
	_send_option(0, difficulty_slider.value)
	_send_option(1, duration_slider.value)


func _setup_client(lobby: Dictionary) -> void:
	_syncing = true
	difficulty_slider.value = float(lobby.get("match_difficulty", 0.8))
	duration_slider.value = float(lobby.get("match_duration", 1.0))
	difficulty_slider.editable = false
	duration_slider.editable = false
	start_button.disabled = true
	status_label.text = "Waiting for the host - Esc: back to teams"
	_update_values()
	_syncing = false

	var runtime := NET_SHELL.active_runtime(get_tree())
	if runtime == null:
		return
	var setup: Dictionary = runtime.net_take_match_setup()
	if not setup.is_empty():
		_start_client(setup, lobby)


func _on_option_changed(_value: float) -> void:
	# The network protocol's matchDuration is the 0..1 slider value itself; the
	# label follows the original "5 minutes .. 25 min." caption.
	_update_values()
	if _syncing or not _host:
		return
	_send_option(0, difficulty_slider.value)
	_send_option(1, _duration_value())


func _duration_value() -> float:
	return duration_slider.value


func _update_values() -> void:
	if difficulty_value != null:
		difficulty_value.text = "%.2f" % difficulty_slider.value
	if duration_value != null:
		duration_value.text = "~%d min" % (5 + int(round(20.0 * duration_slider.value)))


func _send_option(field: int, value: float) -> void:
	NET_SHELL.action(get_tree(), "set_match_options", 0, field, int(round(value * 1000.0)))


func _start_match() -> void:
	if not _host or _match_started:
		return
	var info := NET_SHELL.lobby(get_tree())
	var lobby: Dictionary = info.get("lobby", {})
	var ids: Array = lobby.get("team_ids", [])
	var options := {
		"difficulty": difficulty_slider.value,
		"duration": _duration_value(),
	}
	var runtime := NET_SHELL.active_runtime(get_tree())
	if runtime == null:
		status_label.text = "Network session is gone."
		return
	var package := NETWORK_MATCH.build_package(ids, options)
	if package.is_empty():
		status_label.text = NETWORK_MATCH.error
		return
	if not bool(runtime.set_match_package(package)):
		status_label.text = runtime.get_last_error()
		return
	if not bool(runtime.net_start()):
		status_label.text = runtime.get_last_error()
		return
	_match_started = true
	get_tree().change_scene_to_file(MATCH_SCENE)


func _start_client(setup: Dictionary, lobby: Dictionary) -> void:
	if _match_started:
		return
	var options := {
		"difficulty": float(lobby.get("match_difficulty", 0.8)),
		"duration": float(lobby.get("match_duration", 1.0)),
	}
	var runtime := NET_SHELL.active_runtime(get_tree())
	var package := NETWORK_MATCH.apply_setup(get_tree(), runtime, setup, options)
	if package.is_empty():
		status_label.text = NETWORK_MATCH.error
		return
	_match_started = true
	get_tree().change_scene_to_file(MATCH_SCENE)


func _process(_delta: float) -> void:
	_poll_lobby()


func _back() -> void:
	if _match_started:
		return
	# The server flips the shared phase; _poll_lobby reopens the team screen on
	# every peer (NetworkLobbyPage then routes to Sides/Teams as needed).
	NET_SHELL.action(get_tree(), "backtoteams", 0, 0, 0)
	status_label.text = "Back to teams..."


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.echo and key.pressed:
			NET_SHELL.note_local_device(get_tree(), "keyboard", 0)
		if not key.echo and key.pressed and key.keycode == KEY_ESCAPE:
			_back()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if not joy.pressed:
			return
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(joy.device))
		if int(joy.button_index) == JOY_BUTTON_B:
			_back()
			get_viewport().set_input_as_handled()
		elif int(joy.button_index) == JOY_BUTTON_A:
			var focus := get_viewport().gui_get_focus_owner()
			if focus is BaseButton and not (focus as BaseButton).disabled:
				(focus as BaseButton).pressed.emit()
				get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) > 0.5:
			NET_SHELL.note_local_device(get_tree(), "gamepad", int(motion.device))
