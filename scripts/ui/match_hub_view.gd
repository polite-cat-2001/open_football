class_name MatchHubView
extends UiScreen
# Shared pre-match hub (prototype MatchHub.svelte): two lineup columns, a
# scoreboard and four command cells. Layout, focus and overlays live here;
# adapters only supply the state snapshot and handle the requested actions.

signal start_requested(input: Dictionary)
signal back_requested(input: Dictionary)
signal game_plan_requested
signal options_requested
signal lineup_changed
signal option_changed(field: String, value: float)
signal exit_requested

const SIDE_SELECT_SCENE := preload("res://scenes/ui/settings_side_select.tscn")
const COMMAND_START := 0
const COMMAND_MANAGE := 1
const COMMAND_OPTIONS := 2
const COMMAND_EXIT := 3
const COMMAND_COUNT := 4

# Same feel as the shell screen transition (UiTransition): 150 ms out,
# 240 ms in, 0.96 scale. Headless applies the end state immediately so the
# existing synchronous tests keep working.
const TRANSITION_OUT := 0.15
const TRANSITION_IN := 0.24
const TRANSITION_SCALE_FROM := 0.96

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var hub_top: Control = $Design/PanelWrap/HubTop
@onready var home_lineup: HubLineupColumn = $Design/PanelWrap/HubTop/HomeLineup
@onready var scoreboard: HubScoreboard = $Design/PanelWrap/HubTop/Scoreboard
@onready var away_lineup: HubLineupColumn = $Design/PanelWrap/HubTop/AwayLineup
@onready var command: Control = $Design/PanelWrap/Command
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
var status_label: Label
var legend: UiLegend
@onready var overlay: Control = $Design/Overlay
@onready var settings_screen: SettingsScreen = $Design/Overlay/SettingsScreen
@onready var game_plan_host: Control = $Design/Overlay/GamePlanHost

var game_plan: GpfGamePlan
var side_select: SettingsSideSelect
var _side_select_layer: CanvasLayer
var _side_select_opening := false

var _ui_nav: Node
var _state: Dictionary = {}
var _flags: Dictionary = {}
var _mode := "hub"
var _command_index := COMMAND_START
var _commands: Array = []
var _back_label := "back"
var _transitioning := false


func _ready() -> void:
	theme = UiTheme.load_or_build()
	add_to_group(&"ui_shell")
	_ui_nav = get_node_or_null("/root/UiNav")
	if _ui_nav != null:
		_ui_nav.moved.connect(_on_nav_moved)
		if _ui_nav.has_signal("moved_gamepad"):
			_ui_nav.moved_gamepad.connect(_on_nav_gamepad_moved)
		_ui_nav.confirmed.connect(_on_nav_confirmed)
		_ui_nav.cancelled.connect(_on_nav_cancelled)
		_ui_nav.tab_previous.connect(_on_nav_tab.bind(-1))
		_ui_nav.tab_next.connect(_on_nav_tab.bind(1))
		_ui_nav.device_changed.connect(_on_device_changed)
	status_label = hints.status_label
	legend = hints.legend
	if settings_screen != null:
		settings_screen.set_scrim(false)
	_build_commands()
	_build_game_plan()
	settings_screen.match_options_changed.connect(_on_option_changed)
	settings_screen.closed.connect(_close_overlay)
	settings_screen.side_select_requested.connect(_open_side_select)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	refresh_legend()
	_layout()


func setup(state: Dictionary, options: Dictionary = {}) -> void:
	_back_label = str(options.get("back_label", _back_label))
	apply_state(state)
	_layout()


func apply_state(state: Dictionary) -> void:
	_state = state
	_flags = state.get("flags", {})
	var sides: Array = state.get("sides", [])
	home_lineup.setup(sides[0] if sides.size() > 0 else {})
	away_lineup.setup(sides[1] if sides.size() > 1 else {})
	scoreboard.setup(state)
	if settings_screen.is_open():
		settings_screen.update_context(_settings_context())
	_apply_command_states()
	set_status(str(state.get("status", "")), bool(state.get("status_error", false)))
	refresh_legend()
	_layout()


func set_status(text: String, error := false) -> void:
	if hints == null:
		return
	hints.set_status(text, error)


func status_text() -> String:
	return status_label.text


func setup_game_plan(home_lineup_model: MatchLineup, away_lineup_model: MatchLineup,
		human_teams: Array = [0], options: Dictionary = {}) -> void:
	if game_plan == null:
		return
	game_plan.setup_prematch(home_lineup_model, away_lineup_model, human_teams, options)


func open_game_plan() -> void:
	if game_plan == null or _mode == "game_plan":
		return
	_mode = "game_plan"
	_transitioning = true
	if settings_screen != null:
		settings_screen.dismiss()
	if _animations_instant():
		_show_game_plan_overlay()
		_transitioning = false
		return
	await _animate_out(panel_wrap)
	_show_game_plan_overlay()
	await _animate_in(game_plan_host)
	_transitioning = false


func is_game_plan_open() -> bool:
	return _mode == "game_plan" and game_plan != null and game_plan.is_open()


func open_settings() -> void:
	if _transitioning or _mode == "game_plan":
		return
	_mode = "settings"
	_transitioning = true
	overlay.visible = true
	game_plan_host.visible = false
	if _animations_instant():
		panel_wrap.visible = false
		settings_screen.open(_settings_context())
		settings_screen.modulate.a = 1.0
		settings_screen.scale = Vector2.ONE
		_transitioning = false
		return
	await _animate_out(panel_wrap)
	panel_wrap.visible = false
	settings_screen.open(_settings_context())
	await _animate_in(settings_screen)
	_transitioning = false


# Kept for callers/tests that still name the old options overlay.
func open_options() -> void:
	open_settings()


func _open_side_select() -> void:
	if side_select != null or _side_select_opening \
			or not bool(_flags.get("settings_sides", false)):
		return
	_side_select_opening = true
	# Same choreography as every other screen: 150 ms out, 240 ms in. The
	# side-select stage is the same stadium, so it swaps in after the fade-out.
	if settings_screen != null and not _animations_instant():
		await _animate_out(settings_screen)
	side_select = SIDE_SELECT_SCENE.instantiate() as SettingsSideSelect
	side_select.name = "SettingsSideSelect"
	side_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side_select.closed.connect(_close_side_select)
	side_select.controllers_changed.connect(func(): lineup_changed.emit())
	_side_select_layer = CanvasLayer.new()
	_side_select_layer.name = "SettingsSideSelectLayer"
	_side_select_layer.layer = 8
	add_child(_side_select_layer)
	_side_select_layer.add_child(side_select)
	_side_select_opening = false


func _close_side_select() -> void:
	if _side_select_layer != null:
		_side_select_layer.queue_free()
		_side_select_layer = null
	if side_select != null:
		side_select = null
	# The side stage vanishes with its node; fade the settings screen back in.
	if settings_screen != null and settings_screen.is_open() \
			and not _animations_instant():
		await _animate_in(settings_screen)


func _settings_context() -> Dictionary:
	var options: Dictionary = _state.get("options", {})
	return {
		"runtime": get_tree().get_first_node_in_group(&"gpf_runtime") if is_inside_tree() else null,
		"animate_close": true,
		"options": {
			"difficulty": float(options.get("difficulty", 0.8)),
			"duration": float(options.get("duration", 1.0)),
			"editable": bool(options.get("editable", true)),
		},
		"side_select_available": bool(_flags.get("settings_sides", false)),
	}


func close_overlay() -> void:
	_close_overlay()


func command_index() -> int:
	return _command_index


func command_cell(index: int) -> HubCommandCell:
	if index < 0 or index >= _commands.size():
		return null
	return _commands[index]


func command_rect(index: int) -> Rect2:
	var cell := command_cell(index)
	return Rect2() if cell == null else cell.get_global_rect()


func lineup_rect(side: int) -> Rect2:
	var column := home_lineup if side == 0 else away_lineup
	return column.get_global_rect()


func scoreboard_rect() -> Rect2:
	return scoreboard.get_global_rect()


func design_scale_value() -> float:
	return design.scale.x


func _build_commands() -> void:
	for index in COMMAND_COUNT:
		var cell := HubCommandCell.new()
		command.add_child(cell)
		var data: Dictionary = [
			{"id": "start", "label": "START MATCH", "glyph": "play"},
			{"id": "manage", "label": "TEAM MANAGEMENT", "glyph": "tactics"},
			{"id": "options", "label": "SYSTEM SETTINGS", "glyph": "gear"},
			{"id": "exit", "label": "EXIT", "glyph": "exit"},
		][index]
		cell.setup(str(data["id"]), str(data["label"]), str(data["glyph"]))
		cell.pressed.connect(_activate_command.bind(index))
		cell.selected.connect(_on_command_selected.bind(index))
		_commands.append(cell)


func _build_game_plan() -> void:
	game_plan = GpfGamePlan.new()
	game_plan.name = "GamePlan"
	game_plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_plan.close_requested.connect(_close_game_plan)
	game_plan.lineup_changed.connect(_on_game_plan_changed)
	game_plan_host.add_child(game_plan)
	game_plan_host.visible = false


func _apply_command_states() -> void:
	var start_label := str(_flags.get("start_label", "START MATCH"))
	var can_start := bool(_flags.get("can_start", true))
	var can_manage := bool(_flags.get("can_manage", true))
	var can_options := bool(_flags.get("can_options", true))
	_commands[COMMAND_START].set_label(start_label)
	_commands[COMMAND_START].set_enabled(can_start)
	_commands[COMMAND_MANAGE].set_enabled(can_manage)
	_commands[COMMAND_OPTIONS].set_enabled(can_options)
	_commands[COMMAND_EXIT].set_enabled(true)
	if not _command_enabled(_command_index):
		_command_index = _first_enabled()
	_refresh_command_focus(_mode == "hub")


func _command_enabled(index: int) -> bool:
	var cell := command_cell(index)
	return cell != null and not cell.disabled


func _first_enabled() -> int:
	for index in COMMAND_COUNT:
		if _command_enabled(index):
			return index
	return -1


func _next_enabled(from: int, delta: int) -> int:
	if delta == 0:
		return from
	var index := from
	for _step in COMMAND_COUNT:
		index = posmod(index + delta, COMMAND_COUNT)
		if _command_enabled(index):
			return index
	return from


func _set_command_index(index: int, focus: bool) -> void:
	if not _command_enabled(index):
		return
	_command_index = index
	_refresh_command_focus(focus)


func _refresh_command_focus(focus: bool) -> void:
	for index in _commands.size():
		var cell: HubCommandCell = _commands[index]
		cell.set_selected(index == _command_index)
	if focus and _command_index >= 0:
		_commands[_command_index].grab_focus()


func _activate_command(index: int) -> void:
	if _transitioning or not _command_enabled(index):
		return
	_command_index = index
	_refresh_command_focus(true)
	match index:
		COMMAND_START:
			start_requested.emit(_current_input())
		COMMAND_MANAGE:
			game_plan_requested.emit()
			open_game_plan()
		COMMAND_OPTIONS:
			options_requested.emit()
			open_settings()
		COMMAND_EXIT:
			exit_requested.emit()


func _on_command_selected(index: int) -> void:
	if _mode != "hub":
		return
	if not _command_enabled(index):
		return
	_command_index = index
	_refresh_command_focus(false)


func _close_overlay() -> void:
	if _mode == "game_plan":
		_close_game_plan()
		return
	if _mode == "settings":
		_close_settings()
		return
	_mode = "hub"
	overlay.visible = false
	game_plan_host.visible = false
	panel_wrap.visible = true
	hub_top.visible = true
	command.visible = true
	hints.visible = true
	if game_plan != null:
		game_plan.close_plan()
	refresh_legend()
	_refresh_command_focus(true)


func _close_settings() -> void:
	if _transitioning:
		return
	if side_select != null:
		_close_side_select()
	_transitioning = true
	if _animations_instant():
		_hide_settings_overlay()
		_transitioning = false
		return
	await _animate_out(settings_screen)
	_hide_settings_overlay()
	await _animate_in(panel_wrap)
	_transitioning = false


func _hide_settings_overlay() -> void:
	_mode = "hub"
	settings_screen.dismiss()
	overlay.visible = false
	game_plan_host.visible = false
	panel_wrap.visible = true
	hub_top.visible = true
	command.visible = true
	hints.visible = true
	refresh_legend()
	_refresh_command_focus(true)


func _close_game_plan() -> void:
	if _mode != "game_plan" or _transitioning:
		return
	_mode = "hub"
	_transitioning = true
	if _animations_instant():
		_hide_game_plan_overlay()
		_set_command_index(COMMAND_MANAGE, true)
		_transitioning = false
		return
	await _animate_out(game_plan_host)
	_hide_game_plan_overlay()
	await _animate_in(panel_wrap)
	_set_command_index(COMMAND_MANAGE, true)
	_transitioning = false


func _show_game_plan_overlay() -> void:
	# The half-panel plan replaces the hub chrome; only the stage background
	# stays behind it (matches the reference screen). Start hidden so the
	# first visible frame is already part of the fade-in (no one-frame flash).
	panel_wrap.visible = false
	overlay.visible = true
	if _animations_instant():
		game_plan_host.modulate.a = 1.0
		game_plan_host.scale = Vector2.ONE
	else:
		game_plan_host.pivot_offset = game_plan_host.size * 0.5
		game_plan_host.modulate.a = 0.0
		game_plan_host.scale = Vector2.ONE * TRANSITION_SCALE_FROM
	game_plan_host.visible = true
	game_plan.open_plan()


func _hide_game_plan_overlay() -> void:
	overlay.visible = false
	game_plan_host.visible = false
	game_plan_host.modulate.a = 1.0
	game_plan_host.scale = Vector2.ONE
	if game_plan != null:
		game_plan.close_plan()
	panel_wrap.visible = true
	refresh_legend()
	_refresh_command_focus(true)


func _animations_instant() -> bool:
	return DisplayServer.get_name() == "headless"


func _animate_out(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 0.0, TRANSITION_OUT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(target, "scale", Vector2.ONE * TRANSITION_SCALE_FROM,
		TRANSITION_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


func _animate_in(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	target.modulate.a = 0.0
	target.scale = Vector2.ONE * TRANSITION_SCALE_FROM
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 1.0, TRANSITION_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, TRANSITION_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


func _on_game_plan_changed() -> void:
	lineup_changed.emit()


func _on_option_changed(field: String, value: float) -> void:
	option_changed.emit(field, value)


func _layout() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	layout_canvas()
	var hints_height := hints.height()
	var total := UiTokens.HUB_H + UiTokens.HINTS_GAP + hints_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)
	hub_top.position = Vector2.ZERO
	hub_top.size = Vector2(UiTokens.PANEL_W, UiTokens.HUB_TOP_H)
	home_lineup.position = Vector2.ZERO
	home_lineup.size = Vector2(UiTokens.HUB_SIDE_W, UiTokens.HUB_TOP_H)
	scoreboard.position = Vector2(UiTokens.HUB_SIDE_W + UiTokens.GAP, 0.0)
	scoreboard.size = Vector2(UiTokens.HUB_SCORE_W, UiTokens.HUB_TOP_H)
	away_lineup.position = Vector2(
		UiTokens.HUB_SIDE_W + UiTokens.GAP + UiTokens.HUB_SCORE_W + UiTokens.GAP, 0.0)
	away_lineup.size = Vector2(UiTokens.HUB_SIDE_W, UiTokens.HUB_TOP_H)
	command.position = Vector2(0.0, UiTokens.HUB_TOP_H + UiTokens.HUB_ROW_GAP)
	command.size = Vector2(UiTokens.PANEL_W, UiTokens.HUB_COMMAND_H)
	for index in _commands.size():
		var cell: HubCommandCell = _commands[index]
		cell.position = Vector2(float(index) * (UiTokens.HUB_SIDE_W + UiTokens.GAP), 0.0)
		cell.size = Vector2(UiTokens.HUB_SIDE_W, UiTokens.HUB_COMMAND_H)
	var status_y := UiTokens.HUB_H + UiTokens.HINTS_GAP
	hints.position = Vector2(0.0, status_y)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_plan_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game_plan != null:
		game_plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if _mode == "settings" and settings_screen != null and settings_screen.is_capturing():
		var captured := false
		if event is InputEventKey:
			captured = settings_screen.handle_key(event as InputEventKey)
		elif event is InputEventJoypadButton:
			captured = settings_screen.handle_joy(event as InputEventJoypadButton)
		if captured:
			get_viewport().set_input_as_handled()
		return
	if _transitioning or _mode != "game_plan" or game_plan == null:
		return
	var handled := false
	var device := -1
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_Q:
				handled = game_plan.handle_ui_action("tab_prev", -1)
			elif key.keycode == KEY_E:
				handled = game_plan.handle_ui_action("tab_next", -1)
			elif key.keycode == KEY_Y:
				handled = game_plan.handle_ui_action("details", -1)
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if joy.pressed and int(joy.button_index) == JOY_BUTTON_Y:
			device = int(joy.device)
			handled = game_plan.handle_ui_action("details", device)
	if handled:
		get_viewport().set_input_as_handled()


func _on_nav_moved(direction: Vector2i) -> void:
	if _transitioning:
		return
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return
	_handle_move(direction, {"kind": "keyboard", "device": 0}, -1)


func _on_nav_gamepad_moved(direction: Vector2i, device: int) -> void:
	if _transitioning:
		return
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	_handle_move(direction, {"kind": "gamepad", "device": device}, device)


func _handle_move(direction: Vector2i, _input: Dictionary, device: int) -> void:
	if side_select != null or _side_select_opening:
		return
	match _mode:
		"game_plan":
			if game_plan != null:
				game_plan.handle_ui_action(_direction_action(direction), device)
		"settings":
			settings_screen.handle_nav(direction)
		_:
			if direction == Vector2i.LEFT:
				_set_command_index(_next_enabled(_command_index, -1), true)
			elif direction == Vector2i.RIGHT:
				_set_command_index(_next_enabled(_command_index, 1), true)


func _on_nav_confirmed() -> void:
	if side_select != null or _side_select_opening:
		return
	if _transitioning:
		return
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	match _mode:
		"game_plan":
			if game_plan != null:
				game_plan.handle_ui_action("confirm", _device_for_confirm())
		"settings":
			settings_screen.handle_confirm()
		_: 
			_activate_command(_command_index)


func _on_nav_cancelled() -> void:
	if side_select != null or _side_select_opening:
		return
	if _transitioning:
		return
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	match _mode:
		"game_plan":
			if game_plan == null or not game_plan.handle_ui_action("cancel",
					_device_for_confirm()):
				_close_game_plan()
		"settings":
			settings_screen.handle_cancel()
		_:
			back_requested.emit(_current_input())


func _on_nav_tab(delta: int) -> void:
	if side_select != null or _side_select_opening:
		return
	if _transitioning:
		return
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	match _mode:
		"game_plan":
			if game_plan != null:
				game_plan.handle_ui_action("tab_prev" if delta < 0 else "tab_next",
					_device_for_confirm())
		"hub":
			_set_command_index(_next_enabled(_command_index, 1), true)
		_:
			pass


func _on_device_changed(_gamepad: bool) -> void:
	refresh_legend()


func refresh_legend() -> void:
	if hints == null:
		return
	hints.setup(_gamepad_hints() if _ui_nav != null and _ui_nav.using_gamepad()
		else _keyboard_hints())


func _keyboard_hints() -> Array:
	match _mode:
		"game_plan":
			return [
				{"keys": ["Q", "E"], "label": "tabs"},
				{"keys": ["ENTER"], "label": "select"},
				{"keys": ["Y"], "label": "details"},
				{"keys": ["ESC"], "label": "ready"},
			]
		"options":
			return [
				{"keys": ["в†‘", "в†“"], "label": "option"},
				{"keys": ["в†ђ", "в†’"], "label": "change"},
				{"keys": ["ESC"], "label": "close"},
			]
		_:
			return [
				{"keys": ["в†ђ", "в†’"], "label": "choose"},
				{"keys": ["ENTER"], "label": "select"},
				{"keys": ["ESC"], "label": _back_label},
			]


func _gamepad_hints() -> Array:
	match _mode:
		"game_plan":
			return [
				{"keys": ["LB/RB"], "label": "tabs"},
				{"keys": ["A"], "label": "select"},
				{"keys": ["Y"], "label": "details"},
				{"keys": ["B"], "label": "ready"},
			]
		"options":
			return [
				{"keys": ["D-PAD"], "label": "option / change"},
				{"keys": ["B"], "label": "close"},
			]
		_:
			return [
				{"keys": ["в†ђ", "в†’"], "label": "choose"},
				{"keys": ["A"], "label": "select"},
				{"keys": ["B"], "label": _back_label},
			]


func _direction_action(direction: Vector2i) -> String:
	if direction == Vector2i.LEFT:
		return "left"
	if direction == Vector2i.RIGHT:
		return "right"
	if direction == Vector2i.UP:
		return "up"
	if direction == Vector2i.DOWN:
		return "down"
	return ""


func _device_for_confirm() -> int:
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return int(_ui_nav.last_device_id())
	return -1


func _current_input() -> Dictionary:
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return {"kind": "gamepad", "device": int(_ui_nav.last_device_id())}
	return {"kind": "keyboard", "device": 0}





