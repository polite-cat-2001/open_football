class_name GpfPauseMenu
extends Node
# In-match pause carrier: a CanvasLayer over the frozen 3D match holding the
# design-system PauseScreen. The node keeps the stable API the orchestrator and
# the headless checks use (open/close/dismiss/hide_for_submenu/set_hint).

signal resume_requested
signal forfeit_requested
signal game_plan_requested
signal replay_requested
signal side_select_requested
signal ready_cancelled

const SCREEN_SCENE := preload("res://scenes/match/pause_screen.tscn")

var layer: CanvasLayer
var screen: PauseScreen
var hint_label: Label
var buttons: Array = []
var index := 0

var _runtime: Node = null
var _package: Dictionary = {}
var _team_id := 0
var _break := false
var _plan_lineups: Dictionary = {}


func setup() -> void:
	layer = CanvasLayer.new()
	layer.name = "PauseMenu"
	layer.layer = 6
	add_child(layer)

	screen = SCREEN_SCENE.instantiate() as PauseScreen
	screen.name = "PauseScreen"
	layer.add_child(screen)
	screen.visible = false

	screen.resume_requested.connect(func(): resume_requested.emit())
	screen.forfeit_requested.connect(func(): forfeit_requested.emit())
	screen.game_plan_requested.connect(func(): game_plan_requested.emit())
	screen.replay_requested.connect(func(): replay_requested.emit())
	screen.side_select_requested.connect(func(): side_select_requested.emit())
	screen.ready_cancelled.connect(func(): ready_cancelled.emit())

	buttons = screen.tiles()
	hint_label = screen.hints.status_label
	for i in buttons.size():
		(buttons[i] as Control).focus_entered.connect(_on_tile_focused.bind(i))
	screen.set_match(_runtime, _package)
	screen.set_team(_team_id)
	screen.set_plan_lineups(_plan_lineups)


func set_match(runtime_node: Node, package: Dictionary) -> void:
	_runtime = runtime_node
	_package = package
	if screen != null:
		screen.set_match(runtime_node, package)


func set_plan_lineups(lineups: Dictionary) -> void:
	_plan_lineups = lineups
	if screen != null:
		screen.set_plan_lineups(lineups)


func set_team(team_id: int) -> void:
	_team_id = team_id
	if screen != null:
		screen.set_team(team_id)


func is_open() -> bool:
	return screen != null and screen.visible


func is_break() -> bool:
	return _break


func is_ready() -> bool:
	return screen != null and screen.is_ready()


# All peers voted: fade the READY view out and drop the overlay (no menu).
func dismiss_ready() -> void:
	if screen != null:
		screen.dismiss_ready()


func open(team_id := -1) -> void:
	_break = false
	if screen != null:
		screen.set_break_mode("", "")
	_open(team_id)


# Phase break (original MatchPhasePage): the pause screen with the period
# caption and a "begin <period>" continue tile.
func open_break(next_phase: int, team_id := -1) -> void:
	_break = true
	if screen != null:
		screen.set_break_mode(_phase_break_title(next_phase),
			_phase_break_continue(next_phase))
	_open(team_id)


func _open(team_id: int) -> void:
	if team_id >= 0:
		_team_id = team_id
	if screen == null:
		return
	screen.set_team(_team_id)
	screen.open(_team_id)


func _phase_break_title(next_phase: int) -> String:
	match next_phase:
		2:
			return "HALF TIME"
		3:
			return "END OF 90"
		4:
			return "EXTRA TIME"
	return "BREAK"


func _phase_break_continue(next_phase: int) -> String:
	match next_phase:
		2:
			return "BEGIN SECOND HALF"
		3:
			return "BEGIN 1ST EXTRA TIME"
		4:
			return "BEGIN 2ND EXTRA TIME"
	return "BEGIN NEXT PERIOD"


func close() -> void:
	if screen != null:
		screen.close()


# Returning from the mirrored side-select overlay lands back in settings.
func open_settings_page() -> void:
	if screen != null:
		screen.open_settings_page()


# Hide the menu without resuming the match: a submenu (game plan) takes over
# the same frozen match and returns to the pause menu when it closes.
func hide_for_submenu() -> void:
	if screen != null:
		screen.hide_now()


# Close the menu without emitting resume_requested: a network replay/resume
# already moved the authoritative match out of the pause.
func dismiss() -> void:
	_break = false
	if screen != null and not screen.is_closing():
		screen.hide_now()


func set_hint(text: String) -> void:
	if screen != null:
		screen.set_status(text)


func set_waiting(text: String) -> void:
	if screen != null:
		screen.set_waiting(text)


func has_local_side_select() -> bool:
	return screen != null and screen.has_local_side_select()


func handle_key(event: InputEventKey) -> bool:
	return screen != null and screen.handle_key(event)


func handle_joy(event: InputEventJoypadButton) -> bool:
	return screen != null and screen.handle_joy(event)


func _on_tile_focused(tile_index: int) -> void:
	index = tile_index
