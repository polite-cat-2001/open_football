class_name MatchHubView
extends UiScreen
# Shared pre-match hub (prototype MatchHub.svelte): two lineup columns, a
# scoreboard and four command cells. Layout, focus and overlays live here;
# adapters only supply the state snapshot and handle the requested actions.

signal start_requested(input: Dictionary)
signal back_requested(input: Dictionary)
signal game_plan_requested
signal lineup_changed
signal option_changed(field: String, value: float)
signal exit_requested

const COMMAND_START := 0
const COMMAND_MANAGE := 1
const COMMAND_OPTIONS := 2
const COMMAND_EXIT := 3
const COMMAND_COUNT := 4

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var hub_top: Control = $Design/PanelWrap/HubTop
@onready var home_lineup: HubLineupColumn = $Design/PanelWrap/HubTop/HomeLineup
@onready var scoreboard: HubScoreboard = $Design/PanelWrap/HubTop/Scoreboard
@onready var away_lineup: HubLineupColumn = $Design/PanelWrap/HubTop/AwayLineup
@onready var command: Control = $Design/PanelWrap/Command
@onready var status_label: Label = $Design/PanelWrap/Status
@onready var legend: UiLegend = $Design/PanelWrap/Legend
@onready var overlay: Control = $Design/Overlay
@onready var options_overlay: MatchOptionsOverlay = $Design/Overlay/OptionsOverlay
@onready var game_plan_host: Control = $Design/Overlay/GamePlanHost

var game_plan: GpfGamePlan

var _ui_nav: Node
var _state: Dictionary = {}
var _flags: Dictionary = {}
var _mode := "hub"
var _command_index := COMMAND_START
var _commands: Array = []
var _back_label := "back"


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
		_ui_nav.tab_previous.connect(_on_nav_tab)
		_ui_nav.tab_next.connect(_on_nav_tab)
		_ui_nav.device_changed.connect(_on_device_changed)
	_build_commands()
	_build_game_plan()
	options_overlay.option_changed.connect(_on_option_changed)
	options_overlay.closed.connect(_close_overlay)
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
	options_overlay.setup(state)
	_apply_command_states()
	set_status(str(state.get("status", "")), bool(state.get("status_error", false)))
	refresh_legend()
	_layout()


func set_status(text: String, error := false) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()
	status_label.theme_type_variation = &"SideStatusError" if error else &"SideStatus"


func status_text() -> String:
	return status_label.text


func setup_game_plan(home_lineup_model: MatchLineup, away_lineup_model: MatchLineup,
		human_teams: Array = [0]) -> void:
	if game_plan == null:
		return
	game_plan.setup_prematch(home_lineup_model, away_lineup_model, human_teams)


func open_game_plan() -> void:
	if game_plan == null:
		return
	_mode = "game_plan"
	overlay.visible = true
	options_overlay.visible = false
	game_plan_host.visible = true
	game_plan.open_plan()
	refresh_legend()


func is_game_plan_open() -> bool:
	return _mode == "game_plan" and game_plan != null and game_plan.is_open()


func open_options() -> void:
	_mode = "options"
	overlay.visible = true
	options_overlay.visible = true
	game_plan_host.visible = false
	refresh_legend()


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
			{"id": "options", "label": "MATCH OPTIONS", "glyph": "sliders"},
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
	if not _command_enabled(index):
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
			open_options()
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
	_mode = "hub"
	overlay.visible = false
	options_overlay.visible = false
	game_plan_host.visible = false
	if game_plan != null:
		game_plan.close_plan()
	refresh_legend()
	_refresh_command_focus(true)


func _close_game_plan() -> void:
	_mode = "hub"
	overlay.visible = false
	game_plan_host.visible = false
	if game_plan != null:
		game_plan.close_plan()
	refresh_legend()
	_set_command_index(COMMAND_MANAGE, true)


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
	var legend_height := maxf(24.0, legend.get_combined_minimum_size().y)
	var total := UiTokens.HUB_H + UiTokens.HUB_STATUS_GAP + UiTokens.HUB_STATUS_H \
		+ UiTokens.HUB_LEGEND_GAP + legend_height
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
	var status_y := UiTokens.HUB_H + UiTokens.HUB_STATUS_GAP
	status_label.position = Vector2(0.0, status_y)
	status_label.size = Vector2(UiTokens.PANEL_W, UiTokens.HUB_STATUS_H)
	legend.position = Vector2(0.0, status_y + UiTokens.HUB_STATUS_H + UiTokens.HUB_LEGEND_GAP)
	legend.size = Vector2(UiTokens.PANEL_W, legend_height)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_plan_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game_plan != null:
		game_plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if _mode != "game_plan" or game_plan == null:
		return
	var handled := false
	var device := -1
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_X:
			handled = game_plan.handle_ui_action("cancel_sub", -1)
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if joy.pressed and int(joy.button_index) == JOY_BUTTON_X:
			device = int(joy.device)
			handled = game_plan.handle_ui_action("cancel_sub", device)
	if handled:
		get_viewport().set_input_as_handled()


func _on_nav_moved(direction: Vector2i) -> void:
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return
	_handle_move(direction, {"kind": "keyboard", "device": 0}, -1)


func _on_nav_gamepad_moved(direction: Vector2i, device: int) -> void:
	_handle_move(direction, {"kind": "gamepad", "device": device}, device)


func _handle_move(direction: Vector2i, _input: Dictionary, device: int) -> void:
	match _mode:
		"game_plan":
			if game_plan != null:
				game_plan.handle_ui_action(_direction_action(direction), device)
		"options":
			if direction == Vector2i.UP:
				options_overlay.move_focus(-1)
			elif direction == Vector2i.DOWN:
				options_overlay.move_focus(1)
			elif direction == Vector2i.LEFT:
				options_overlay.adjust(-1)
			elif direction == Vector2i.RIGHT:
				options_overlay.adjust(1)
		_:
			if direction == Vector2i.LEFT:
				_set_command_index(_next_enabled(_command_index, -1), true)
			elif direction == Vector2i.RIGHT:
				_set_command_index(_next_enabled(_command_index, 1), true)


func _on_nav_confirmed() -> void:
	match _mode:
		"game_plan":
			if game_plan != null:
				game_plan.handle_ui_action("confirm", _device_for_confirm())
		"options":
			options_overlay.confirm()
		_:
			_activate_command(_command_index)


func _on_nav_cancelled() -> void:
	match _mode:
		"game_plan":
			if game_plan == null or not game_plan.handle_ui_action("cancel",
					_device_for_confirm()):
				_close_game_plan()
		"options":
			_close_overlay()
		_:
			back_requested.emit(_current_input())


func _on_nav_tab() -> void:
	match _mode:
		"game_plan":
			if game_plan != null:
				game_plan.handle_ui_action("bench", _device_for_confirm())
		"hub":
			_set_command_index(_next_enabled(_command_index, 1), true)
		_:
			pass


func _on_device_changed(_gamepad: bool) -> void:
	refresh_legend()


func refresh_legend() -> void:
	if legend == null:
		return
	legend.setup(_gamepad_hints() if _ui_nav != null and _ui_nav.using_gamepad()
		else _keyboard_hints())


func _keyboard_hints() -> Array:
	match _mode:
		"game_plan":
			return [
				{"keys": ["←↑↓→"], "label": "move"},
				{"keys": ["ENTER"], "label": "select"},
				{"keys": ["TAB"], "label": "bench"},
				{"keys": ["ESC"], "label": "close"},
			]
		"options":
			return [
				{"keys": ["↑", "↓"], "label": "option"},
				{"keys": ["←", "→"], "label": "change"},
				{"keys": ["ESC"], "label": "close"},
			]
		_:
			return [
				{"keys": ["←", "→"], "label": "choose"},
				{"keys": ["ENTER"], "label": "select"},
				{"keys": ["ESC"], "label": _back_label},
			]


func _gamepad_hints() -> Array:
	match _mode:
		"game_plan":
			return [
				{"keys": ["D-PAD"], "label": "move"},
				{"keys": ["A"], "label": "select"},
				{"keys": ["B"], "label": "close"},
				{"keys": ["LB/RB"], "label": "bench"},
			]
		"options":
			return [
				{"keys": ["D-PAD"], "label": "option / change"},
				{"keys": ["B"], "label": "close"},
			]
		_:
			return [
				{"keys": ["←", "→"], "label": "choose"},
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
