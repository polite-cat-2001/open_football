extends Node3D
# Scene orchestrator for the GDExtension gameplay slice. It wires the presentation
# components together and routes input to them; it owns no match or presentation state.

# The original C++ runtime can only be initialized once per process, so its node
# outlives every match scene: it is created on the first match and parked under the
# tree root while the main menu is up. A scene change therefore gives a fresh match
# without re-initializing the runtime.
const RUNTIME_SCENE := preload("res://scenes/gpf_runtime.tscn")
const RUNTIME_GROUP := "gpf_runtime"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"
const NETWORK_SIDES_SCENE := preload("res://scenes/network_sides.tscn")
const SUBSTITUTION_NOTICES := preload("res://scripts/match/substitution_notices.gd")
# Hold the READY view long enough to finish its entry animation before the
# last vote fades it out.
const RESUME_READY_DWELL_MS := 650

var runtime: Node
@onready var camera := $Camera3D
@onready var actors: GpfActors = $Actors
@onready var environment_view: GpfEnvironment = $Environment
@onready var goal_nets: GpfGoalNets = $GoalNets
@onready var camera_rig: GpfCameraRig = $CameraRig
@onready var hud: GpfHud = $Hud
@onready var replay: GpfReplay = $ReplayView
@onready var shootout: GpfShootoutView = $ShootoutView
@onready var pause_menu: GpfPauseMenu = $PauseMenu
@onready var match_over: GpfMatchOver = $MatchOver
var game_plan: GpfGamePlan
var _game_plan_layer: CanvasLayer
var _roster_ids: Array = []
var _roster_names: Dictionary = {}
var _net_notice_ready_ms := 0
var side_select_overlay: Control
var _side_select_layer: CanvasLayer
var _net_status_layer: CanvasLayer
var _net_status_label: Label
var _net_last_player_ids: Array = []
var _host_lost := false
var _side_select_closing := false

const SET_PIECE_KEYS := {
	KEY_P: 6,
	KEY_F: 3,
	KEY_Y: 4,
	KEY_G: 2,
	KEY_O: 5,
}

var started := false
var frames := 0
var shot_path := OS.get_environment("GPF_SHOT")
var shot_frame := int(OS.get_environment("GPF_SHOT_FRAME")) if OS.get_environment("GPF_SHOT_FRAME") != "" else 120
var shot_taken := false
var demo := OS.get_environment("GPF_DEMO") != ""
# Godot joypad id -> extension-owned virtual joystick id, for the shell setup.
var input_slots: Dictionary = {}
var _pause_stick_ms := 0
var _net_break_seen := false
var _resume_fade_at_ms := 0
var _resume_sequence := false
var _leaving := false


func _ready() -> void:
	# The match only exists from a real shell selection: the prematch builds the
	# package. There is no built-in team pair to fall back to.
	if not ShellState.has_package():
		push_error("GpfSlice: no match package; choose teams in the shell first")
		_drop_loader_after_draw()
		_return_to_team_select.call_deferred()
		return
	runtime = _acquire_runtime(ShellState.match_package)
	# The runtime scene starts manually; gamepad registration needs the original
	# input singletons, so bring the runtime up before applying the setup.
	if not bool(runtime.is_runtime_ready()):
		runtime.start_runtime_now()
	_configure_input()
	SettingsStore.apply_to_runtime(runtime)
	actors.setup(runtime)
	actors.set_match_kits(ShellState.match_package)
	environment_view.setup(runtime, $Sun, $FillLight)
	goal_nets.setup(runtime, environment_view)
	camera_rig.setup(camera, actors)
	hud.setup(runtime)
	if not ShellState.controllers.is_empty() \
			and str(ShellState.controllers[0].get("kind", "keyboard")) == "gamepad":
		hud.set_taker_hint_key("Select")
	replay.setup(runtime, camera, actors, goal_nets, hud)
	shootout.setup()
	pause_menu.setup()
	pause_menu.set_match(runtime, ShellState.match_package)
	pause_menu.set_team(_pause_team(-1))
	match_over.setup()
	match_over.set_match(runtime, ShellState.match_package)
	_build_game_plan()

	match_over.advance_requested.connect(_return_to_main_menu)
	match_over.restart_requested.connect(_start_fresh_match)
	match_over.choice_made.connect(_on_end_choice)
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.forfeit_requested.connect(_return_to_main_menu)
	pause_menu.replay_requested.connect(_on_pause_replay)
	pause_menu.game_plan_requested.connect(_open_game_plan)
	pause_menu.side_select_requested.connect(_open_side_select)
	pause_menu.ready_cancelled.connect(_on_ready_cancelled)

	# Every local scene load is a new match: stop and restart so the previous
	# match's clock, score and objects cannot leak into this one. A LAN host has
	# already started its authoritative match in net_start(); attach the
	# presentation to that live match instead of restarting it under the client.
	var live_snapshot: Dictionary = runtime.get_snapshot()
	var live_net_match: bool = bool(runtime.is_net_active()) and not live_snapshot.is_empty()
	if not live_net_match:
		if not runtime.restart_match():
			push_error("GpfRuntime failed: " + str(runtime.get_last_error()))
			_drop_loader_after_draw()
			return
	goal_nets.build_dynamic()
	_build_presentation()
	# The loader curtain (join / match start) is dropped over a built match.
	await _drop_loader_after_draw()


# Every match build (runtime start + match) blocks the main thread for seconds,
# so the shell raises the loader curtain before it. Drop it one drawn frame late:
# its fade-out then plays over a live picture instead of the shader warm-up.
func _drop_loader_after_draw() -> void:
	var connecting := get_node_or_null("/root/UiConnecting")
	if connecting == null or not bool(connecting.is_open()):
		return
	await get_tree().process_frame
	connecting.call("close")


func _exit_tree() -> void:
	# The runtime node stays under the tree root for the next match; park it stopped.
	if runtime != null and is_instance_valid(runtime):
		runtime.stop_match()


func _acquire_runtime(package: Dictionary) -> Node:
	var existing := get_tree().get_first_node_in_group(RUNTIME_GROUP)
	if existing != null:
		# A live LAN host match keeps the package it was started with.
		if existing.get_snapshot().is_empty():
			existing.set_match_package(package)
		return existing
	var node: Node = RUNTIME_SCENE.instantiate()
	if not node.set_match_package(package):
		push_error("GpfRuntime rejected the match package: " + str(node.get_last_error()))
	node.add_to_group(RUNTIME_GROUP)
	get_tree().root.add_child(node)
	return node


func _configure_input() -> void:
	# Register the shell's gamepads with the runtime and hand over the side/device
	# mapping. This must happen before restart_match(), which constructs the match
	# and its HumanGamers.
	var applied := InputSetup.apply_to_runtime(runtime, ShellState.controllers)
	input_slots = applied.get("slots", {})


func _build_game_plan() -> void:
	_game_plan_layer = CanvasLayer.new()
	_game_plan_layer.name = "GamePlanLayer"
	_game_plan_layer.layer = 6
	add_child(_game_plan_layer)
	game_plan = GpfGamePlan.new()
	game_plan.name = "GamePlan"
	game_plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_plan_layer.add_child(game_plan)
	game_plan.close_requested.connect(_on_game_plan_closed)
	game_plan.setup_match(runtime, _human_teams(), _game_plan_options())


func _net_local_team() -> int:
	if runtime == null or not is_instance_valid(runtime) \
			or not runtime.has_method("is_net_active") or not bool(runtime.is_net_active()) \
			or not runtime.has_method("net_lobby"):
		return -1
	return NetShell.local_team_id(runtime.net_lobby())


func _human_teams() -> Array:
	# Network sides live in the host-authoritative lobby, which is the only source
	# that follows an in-match side swap; the shell controller setup is a snapshot
	# taken when this scene loaded.
	var net_team := _net_local_team()
	if net_team >= 0:
		return [net_team]
	var teams: Array = []
	# The C++ controller setup is authoritative after an in-match side change;
	# ShellState is only the pre-match snapshot.
	if runtime != null and is_instance_valid(runtime) and runtime.has_method("get_controller_setup"):
		var setup: Array = runtime.get_controller_setup()
		for entry in setup:
			if not (entry is Dictionary):
				continue
			var side := int(entry.get("side", 0))
			if side == 0:
				continue
			var team_id := 1 if side > 0 else 0
			if not teams.has(team_id):
				teams.append(team_id)
	for controller in ShellState.controllers:
		if not teams.is_empty():
			break
		if not (controller is Dictionary):
			continue
		var team_id := 1 if str(controller.get("side", "home")) == "away" else 0
		if not teams.has(team_id):
			teams.append(team_id)
	if teams.is_empty():
		teams = [0]
	teams.sort()
	return teams


func _game_plan_options() -> Dictionary:
	return {
		"network": runtime != null and bool(runtime.is_net_active()),
		"local_two_player": _human_teams().size() >= 2,
	}


func _open_game_plan() -> void:
	if game_plan == null or game_plan.is_open():
		return
	# A network plan is a local submenu of the shared pause. Opening it must
	# withdraw the local "continue" vote so the match cannot resume while the
	# player is editing.
	if runtime != null and bool(runtime.is_net_active()):
		runtime.net_action("setresumeready", 0, 0, 0)
	pause_menu.hide_for_submenu()
	hud.set_visible(false)
	game_plan.setup_match(runtime, _human_teams(), _game_plan_options())
	game_plan.open_plan()


func _on_game_plan_closed() -> void:
	if game_plan != null:
		game_plan.close_plan()
	hud.set_visible(true)
	if pause_menu != null:
		var lineups: Dictionary = {}
		if game_plan != null:
			for team_id in [0, 1]:
				var line: Array = game_plan.planned_lineup(team_id)
				if not line.is_empty():
					lineups[team_id] = line
		pause_menu.set_plan_lineups(lineups)
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("phase_break_pending", false)) \
				or bool(snap.get("phase_break", false)):
			_show_break_overlay(snap)
			return
		pause_menu.open()


func _build_presentation() -> void:
	var ids: Array = runtime.get_player_ids()
	var controlled := _pick_controlled(ids)
	if controlled >= 0:
		runtime.select_player(controlled)
		print("display_player_id=", controlled, " human_after_select=", runtime.get_human_player_id())
	actors.spawn(ids)
	actors.set_controlled(controlled)
	_remember_roster(ids)
	# A rejoining thin client receives the host's substitution history in its
	# first snapshots; do not replay those as fresh banners.
	_net_notice_ready_ms = Time.get_ticks_msec() + 3000 if bool(runtime.is_net_client()) else 0
	runtime.set("manual_step", false)
	started = true


func _pick_controlled(ids: Array) -> int:
	# The C++ side already selected a player for the human's gamer.
	var human := int(runtime.get_human_player_id())
	if human > 0:
		return human
	# Thin LAN client: no local HumanGamer exists. The host snapshot marks the
	# selected player with this peer's owner id, so follow that first.
	if bool(runtime.is_net_client()):
		var info: Dictionary = runtime.net_lobby()
		var local_id := int(info.get("local_id", -1))
		for entry in ids:
			if int(entry.get("owner_id", -1)) == local_id:
				return int(entry.get("id", -1))
		# Before the first snapshot/frame: fall back to the lobby side.
		var players: Array = info.get("lobby", {}).get("players", [])
		for player in players:
			if int(player.get("id", -1)) != local_id:
				continue
			var side := int(player.get("side", -1))
			if side != 0 and side != 1:
				return -1
			for entry in ids:
				if int(entry.get("team", -1)) == side \
						and String(entry.get("role", "player")) != "goalkeeper":
					return int(entry.get("id", -1))
			return -1
	# PRE-MATCH: no selection yet. Use the configured side, not always home.
	var human_team := int(runtime.get_human_team_id())
	if human_team < 0:
		var setup: Array = runtime.get_controller_setup()
		if not setup.is_empty():
			human_team = 0 if int(setup[0].get("side", -1)) < 0 else 1
	if human_team < 0:
		return -1
	for entry in ids:
		if int(entry.get("team", -1)) == human_team and int(entry.get("id", -1)) != 0 \
				and String(entry.get("role", "player")) != "goalkeeper":
			return int(entry.get("id"))
	return -1


func _remember_roster(ids: Array) -> void:
	var roster: Array = []
	var names := {}
	for entry in ids:
		var id := int(entry.get("id", -1))
		roster.append(id)
		names[id] = str(entry.get("name", ""))
	roster.sort()
	_roster_ids = roster
	_roster_names = names


func _sync_roster() -> void:
	var ids: Array = runtime.get_player_ids()
	var roster: Array = []
	for entry in ids:
		roster.append(int(entry.get("id", -1)))
	roster.sort()
	if roster == _roster_ids:
		return
	var previous_names := _roster_names
	_remember_roster(ids)
	if bool(runtime.is_net_client()) and Time.get_ticks_msec() >= _net_notice_ready_ms:
		var lines := SUBSTITUTION_NOTICES.build_lines(previous_names, _roster_names)
		if not lines.is_empty():
			hud.show_substitution_notice(lines)
	actors.sync_roster(ids)


func _process(delta: float) -> void:
	if not started:
		return
	if replay.is_active():
		replay.update(delta)
		return
	if demo:
		_run_demo()
	var current_ids: Array = runtime.get_human_player_ids()
	if not current_ids.is_empty():
		actors.set_controlled_ids(current_ids)
	var snap: Dictionary = runtime.get_snapshot()
	if snap.is_empty():
		return
	if bool(runtime.is_net_active()) and not _net_connection_lost(snap):
		_update_network_pause(snap)
		# The break is over once every peer voted and the host unpaused; drop
		# the bridge latch so the break overlay closes on the host too. Only
		# clear after the break was actually entered, or a freshly forced break
		# would be cancelled before the HUD can pause it.
		var break_paused := bool(snap.get("paused", false)) \
			and (bool(snap.get("phase_break", false)) \
				or bool(snap.get("phase_break_pending", false)))
		if break_paused:
			_net_break_seen = true
		if _net_break_seen and not bool(snap.get("paused", false)) \
				and not bool(snap.get("phase_break", false)):
			runtime.clear_phase_break_pending()
			_net_break_seen = false
	shootout.update(snap, delta)
	_sync_phase_break(snap)
	_sync_match_over(snap)
	# A substitution applied at the C++ restart changes the active roster: add
	# the new bodies and drop the players who left the pitch. The thin client
	# derives its own banner from the delta (the original client applies the
	# substitution but keeps no notice book).
	_sync_roster()
	var poses := actors.apply_runtime()
	actors.sync_ball(snap)
	actors.update_referee_card(snap)
	camera_rig.update(snap)
	goal_nets.update()
	replay.record(poses)
	replay.on_snapshot(snap)
	actors.update_reticle(snap)
	actors.apply_park_visibility(snap)
	actors.set_labels_visible(not camera_rig.stadium)
	hud.apply_snapshot(snap, actors.get_controlled(), actors.count(), camera_rig.stadium,
		environment_view.lighting_name())

	frames += 1
	if shot_path != "" and not shot_taken and frames >= shot_frame:
		shot_taken = true
		_save_screenshot.call_deferred()
	if frames % 60 == 0:
		print("slice frame=", frames, " tick=", snap.get("tick"), " in_play=", snap.get("in_play"),
			" player=", actors.get_controlled(), " ball=", snap.get("ball_pos"))


func _input(event: InputEvent) -> void:
	if not started:
		return
	if _host_lost:
		# The host is gone: the only move left is back to the main menu.
		if event is InputEventKey:
			var lost_key := event as InputEventKey
			if lost_key.pressed and not lost_key.echo \
					and lost_key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
				_return_to_main_menu()
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
		return
	if side_select_overlay != null:
		# The mirrored side-select overlay owns the input; it consumes its own
		# events, the match must not act on the same buttons.
		return
	if pause_menu != null and pause_menu.has_local_side_select():
		# The local side-select overlay is driven by UiNav; do not consume the
		# event (or Enter/Esc starve). Keep the C++ device state in sync so a
		# held direction released over the overlay does not stick afterwards.
		_forward_overlay_input(event)
		return
	var viewport := get_viewport()
	var menu_before := _menu_open()
	if event is InputEventJoypadButton:
		_handle_gamepad_button(event as InputEventJoypadButton)
		if menu_before or _menu_open() or pause_menu.is_open():
			# GUI focus navigation also listens to the D-pad; the menu already
			# consumed this event, otherwise focus skips a row.
			if viewport != null:
				viewport.set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		_handle_gamepad_motion(event as InputEventJoypadMotion)
		if game_plan != null and game_plan.is_open() or pause_menu.is_open() or menu_before:
			if viewport != null:
				viewport.set_input_as_handled()
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.echo:
		return
	_handle_key(key_event)
	if menu_before or _menu_open() or pause_menu.is_open() \
			or key_event.keycode in [KEY_ESCAPE, KEY_TAB]:
		# Same double-step guard as above: a pause/game-plan key must not also
		# drive Godot's GUI focus or press the focused button.
		if viewport != null:
			viewport.set_input_as_handled()


func _other_menu_open() -> bool:
	return replay.is_active() or match_over.is_open() \
		or hud.is_taker_menu_open() \
		or side_select_overlay != null \
		or (game_plan != null and game_plan.is_open())


func _menu_open() -> bool:
	return _other_menu_open() or pause_menu.is_open()


func _can_pause() -> bool:
	if _menu_open():
		return false
	var snap: Dictionary = runtime.get_snapshot()
	return not bool(snap.get("game_over", false)) \
		and not bool(snap.get("shootout_active", false))


func _open_pause(device := -1) -> void:
	_resume_fade_at_ms = 0
	_resume_sequence = false
	pause_menu.set_team(_pause_team(device))
	pause_menu.set_waiting("")
	pause_menu.open()
	runtime.pause_match()
	_release_sticks()
	_release_buttons()


# Phase break (original MatchPhasePage): the design-system pause screen with the
# period caption and a "begin <period>" continue tile. The runtime pauses when
# the latched break opens; a network host broadcasts that pause, a thin client
# only mirrors the host snapshot.
func _sync_phase_break(snap: Dictionary) -> void:
	var breaking := bool(snap.get("phase_break_pending", false)) \
		or bool(snap.get("phase_break", false))
	if not breaking or bool(snap.get("game_over", false)) \
			or bool(snap.get("shootout_active", false)):
		if pause_menu.is_break():
			pause_menu.dismiss()
		return
	if choice_needed(snap):
		# A level score at 90:00 is the choice screen's latch, not the period
		# break: the choice overlay pauses the match itself (see _sync_match_over).
		if pause_menu.is_break():
			pause_menu.dismiss()
		return
	if pause_menu.is_break():
		return
	# A local submenu owns the frozen match: open the break screen when it closes.
	if game_plan != null and game_plan.is_open():
		return
	if not bool(runtime.is_net_client()):
		runtime.begin_phase_break()
	_show_break_overlay(snap)


func _show_break_overlay(snap: Dictionary) -> void:
	var next_phase := int(snap.get("phase_break_next_phase", 0))
	if next_phase <= 0:
		# Thin client: the host's latch never runs here, so its match phase is
		# the period being started.
		next_phase = int(snap.get("match_phase", 0))
	pause_menu.open_break(next_phase, _pause_team(-1))
	_release_sticks()
	_release_buttons()


# End of match and the 90:00 draw: one overlay, two screens. The result screen
# also owns the finished shootout (the C++ GameOver follows its celebration).
func _sync_match_over(snap: Dictionary) -> void:
	if bool(snap.get("game_over", false)):
		var caption := ""
		if bool(snap.get("shootout_active", false)):
			caption = "PENALTIES %d – %d" % [
				int(snap.get("shootout_score0", 0)),
				int(snap.get("shootout_score1", 0)),
			]
		if not match_over.is_open() or match_over.is_choice():
			match_over.open_result(caption)
		return
	if choice_needed(snap):
		if not match_over.is_choice():
			if not bool(runtime.is_net_client()):
				runtime.begin_phase_break()
			match_over.open_choice()
			_release_sticks()
			_release_buttons()
		return
	if match_over.is_open():
		match_over.dismiss()


# A level score at the end of regulation: the C++ referee latched the extra-time
# phase break and the choice screen takes over from the period break. Static so
# the routing is testable without a live match.
static func choice_needed(snap: Dictionary) -> bool:
	var breaking := bool(snap.get("phase_break_pending", false)) \
		or bool(snap.get("phase_break", false))
	# The host's latch names the period being started; a thin client never runs
	# that latch, but its match phase already names the same period.
	var next_phase := int(snap.get("phase_break_next_phase", 0))
	if next_phase <= 0:
		next_phase = int(snap.get("match_phase", 0))
	return breaking \
		and next_phase == 3 \
		and int(snap.get("score0", 0)) == int(snap.get("score1", 0)) \
		and not bool(snap.get("game_over", false)) \
		and not bool(snap.get("shootout_active", false))


func _on_end_choice(id: String) -> void:
	match id:
		"classic":
			runtime.continue_after_phase_break()
		"penalties":
			runtime.start_shootout()
		"draw":
			runtime.debug_force_game_over()


# Function states are edge-tracked too: a direction held when the pause opens
# would otherwise stay down after the side-select trip and make that arrow feel
# dead (or keep the player running).
func _release_buttons() -> void:
	for function in 18:
		runtime.set_button(function, false)
	# D-pad buttons are edge-tracked in SDL; release them too so a held
	# direction does not survive the pause/side-select trip.
	for device in input_slots:
		var slot := int(input_slots[device])
		for button in 21:
			runtime.set_gamepad_button(slot, button, false)


# Stick axes are event-driven: the runtime keeps the last value, so a stick
# pushed when the pause opens would keep running after resume. Zero them.
func _release_sticks() -> void:
	for device in input_slots:
		var slot := int(input_slots[device])
		runtime.set_gamepad_axis(slot, JOY_AXIS_LEFT_X, 0.0)
		runtime.set_gamepad_axis(slot, JOY_AXIS_LEFT_Y, 0.0)


# The lineup card shows the team of the human who opened the pause: the pad
# that pressed Start in local 2P, otherwise the first configured human (the
# keyboard in 1P).
func _pause_team(device: int) -> int:
	# A network side swap is applied by the host after this scene read the shell
	# setup, so the lobby is the live source for the local team.
	var net_team := _net_local_team()
	if net_team >= 0:
		return net_team
	# Runtime setup reflects a live network side change; ShellState would still
	# hold the side chosen in the lobby.
	if runtime != null and is_instance_valid(runtime) and runtime.has_method("get_controller_setup"):
		var setup: Array = runtime.get_controller_setup()
		var slot := int(input_slots.get(device, -1)) if device >= 0 else -1
		for entry in setup:
			if not (entry is Dictionary):
				continue
			var kind := str(entry.get("kind", "keyboard"))
			var matches := device < 0
			if not matches and kind == "gamepad" and slot >= 0 \
					and int(entry.get("slot", -1)) == slot:
				matches = true
			elif not matches and kind == "keyboard" and device == 0:
				matches = true
			if not matches:
				continue
			var side := int(entry.get("side", 0))
			if side != 0:
				return 1 if side > 0 else 0
	for controller in ShellState.controllers:
		if not (controller is Dictionary):
			continue
		if device < 0 or int(controller.get("device", -1)) == device:
			return 1 if str(controller.get("side", "home")) == "away" else 0
	return int(_human_teams()[0])


# The 90:00 choice belongs to the host / P1. A network client waits for the
# host; locally the first configured controller owns it (keyboard events arrive
# with device -1 because Godot reports 0 for both a keyboard and the first pad).
func _over_owner_ok(device: int) -> bool:
	if runtime != null and is_instance_valid(runtime) \
			and runtime.has_method("is_net_client") and bool(runtime.is_net_client()):
		return false
	for controller in ShellState.controllers:
		if not (controller is Dictionary):
			continue
		if str(controller.get("kind", "keyboard")) == "keyboard":
			return device < 0
		return device == int(controller.get("device", -1))
	return device < 0


func _on_pause_resume() -> void:
	# LAN pause is peer-equal: the host only unpauses once every peer has voted
	# (NetMatchSession::ProcessHost consumes the all-resume-ready event).
	if bool(runtime.is_net_active()):
		runtime.net_action("set_resume_ready", 0, 1, 0)
		pause_menu.set_waiting("WAITING FOR RIVAL")
		pause_menu.set_hint("resume vote sent")
		return
	if pause_menu.is_break():
		runtime.continue_after_phase_break()
		return
	runtime.resume_match()


# Back out of the READY view: withdraw the pause vote so the match cannot
# resume behind the pause menu.
func _on_ready_cancelled() -> void:
	_resume_fade_at_ms = 0
	if bool(runtime.is_net_active()):
		runtime.net_action("set_resume_ready", 0, 0, 0)
	pause_menu.set_waiting("")
	pause_menu.set_hint("")


func _update_network_pause(snap: Dictionary) -> void:
	var paused := bool(snap.get("paused", false))
	var blocked := bool(snap.get("game_over", false)) \
		or bool(snap.get("shootout_active", false)) \
		or bool(snap.get("phase_break", false)) \
		or bool(snap.get("phase_break_pending", false))
	var info: Dictionary = runtime.net_lobby()
	var lobby: Dictionary = info.get("lobby", {})
	var side_select := bool(lobby.get("side_select", false))
	# The phase break is a resume vote on every peer too: keep its overlay and
	# only refresh the vote counts.
	if pause_menu.is_break():
		if not paused:
			_resume_sequence = false
			_resume_fade_at_ms = 0
			pause_menu.dismiss()
			return
		if _resume_sequence:
			return
		_show_resume_votes(lobby)
		return
	# The roster change that opens side selection is only visible as a delta:
	# remember the live list until the flag flips.
	var roster_status := ""
	if side_select:
		roster_status = _roster_change_status(lobby)
	else:
		_net_last_player_ids = _lobby_player_ids(lobby)

	if not paused:
		_resume_sequence = false
		_resume_fade_at_ms = 0
		if game_plan != null and game_plan.is_open():
			game_plan.close_plan()
			hud.set_visible(true)
		if pause_menu.is_open():
			pause_menu.dismiss()
		return
	if _resume_sequence:
		# Both votes are in: the READY view already faded out and the host
		# unpauses shortly. Keep the pause menu from reopening in between.
		return
	if blocked:
		if game_plan != null and game_plan.is_open():
			game_plan.close_plan()
			hud.set_visible(true)
		if pause_menu.is_open():
			pause_menu.dismiss()
		return
	if side_select:
		# Mirrored in-match side selection (pause menu item or a C++ roster
		# change): the overlay replaces the pause menu on every peer.
		if pause_menu.is_open() and (game_plan == null or not game_plan.is_open()):
			pause_menu.dismiss()
		_ensure_side_select_overlay(roster_status)
		return
	if not _menu_open():
		pause_menu.set_team(_pause_team(-1))
		pause_menu.open()
		_release_sticks()
	if not pause_menu.is_open():
		return
	_show_resume_votes(lobby)


func _show_resume_votes(lobby: Dictionary) -> void:
	var players: Array = lobby.get("players", [])
	var ready := 0
	for player in players:
		if bool(player.get("resume_ready", false)):
			ready += 1
	if pause_menu.is_ready() and not players.is_empty() and ready >= players.size():
		# Everyone voted: let the READY view finish its entry animation, then
		# fade it out on both peers ahead of the host's delayed unpause.
		var now := Time.get_ticks_msec()
		if _resume_fade_at_ms == 0:
			_resume_fade_at_ms = now + RESUME_READY_DWELL_MS
		elif now >= _resume_fade_at_ms:
			_resume_fade_at_ms = 0
			_resume_sequence = true
			pause_menu.dismiss_ready()
			return
	else:
		_resume_fade_at_ms = 0
	pause_menu.set_waiting("WAITING FOR RIVAL %d/%d" % [ready, players.size()])
	pause_menu.set_hint("resume ready %d/%d    Enter/Esc: vote" % [ready, players.size()])


func _on_pause_replay() -> void:
	pause_menu.set_hint("replay: not ported")


func _open_side_select() -> void:
	if side_select_overlay != null or _host_lost:
		return
	if not bool(runtime.is_net_active()):
		pause_menu.set_hint("side selection: network match only")
		return
	# IngamePage::GoSideSelect -> CancelResumeVote: withdraw this peer's
	# Continue vote so the match cannot resume behind the overlay.
	runtime.net_action("set_resume_ready", 0, 0, 0)
	pause_menu.hide_for_submenu()
	if not bool(runtime.net_side_select_open()):
		pause_menu.open()
		pause_menu.set_hint("side selection unavailable")
		return
	_ensure_side_select_overlay()


func _ensure_side_select_overlay(status: String = "") -> void:
	if side_select_overlay != null or _host_lost:
		return
	_side_select_layer = CanvasLayer.new()
	_side_select_layer.name = "SideSelectLayer"
	_side_select_layer.layer = 8
	add_child(_side_select_layer)
	var overlay: Control = NETWORK_SIDES_SCENE.instantiate()
	overlay.name = "NetworkSidesResume"
	overlay.set("resume_mode", true)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.connect("closed", _on_side_select_closed)
	_side_select_layer.add_child(overlay)
	side_select_overlay = overlay
	if not status.is_empty():
		overlay.call("set_status", status)
	# Fade only the side-select content: the stage/scrim must cover the pitch from
	# the first frame, otherwise the bright 3D field flashes while it fades in.
	_fade_screen(_side_select_content(overlay), true)


func _side_select_content(overlay: Control) -> Control:
	var view := overlay.get_node_or_null("SideSelectView") if overlay != null else null
	var content := view.get_node_or_null("Design/PanelWrap") if view != null else null
	return content if content != null else overlay


func _on_side_select_closed() -> void:
	_close_side_select_overlay(true)


func _close_side_select_overlay(reopen_pause: bool) -> void:
	if _side_select_closing:
		return
	_side_select_closing = true
	var overlay := side_select_overlay
	var layer := _side_select_layer
	side_select_overlay = null
	_side_select_layer = null
	if overlay != null and is_instance_valid(overlay):
		await _fade_screen(_side_select_content(overlay), false)
		overlay.queue_free()
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	_side_select_closing = false
	if not reopen_pause or _host_lost:
		return
	# A commit resumed the match (nothing to show); a cancel stayed paused, so
	# the settings screen that opened side select comes back.
	var snap: Dictionary = runtime.get_snapshot()
	if bool(snap.get("paused", false)):
		pause_menu.open_settings_page()


func _fade_screen(target: Control, show: bool) -> void:
	if target == null or DisplayServer.get_name() == "headless":
		return
	target.pivot_offset = target.size * 0.5
	if show:
		target.modulate.a = 0.0
		target.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 1.0 if show else 0.0,
		0.24 if show else 0.15) \
		.set_trans(Tween.TRANS_CUBIC if show else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT if show else Tween.EASE_IN)
	tween.tween_property(target, "scale",
		Vector2.ONE if show else Vector2(0.96, 0.96), 0.24 if show else 0.15) \
		.set_trans(Tween.TRANS_CUBIC if show else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT if show else Tween.EASE_IN)
	await tween.finished


func _lobby_player_ids(lobby: Dictionary) -> Array:
	var ids: Array = []
	for player in lobby.get("players", []):
		ids.append(int(player.get("id", -1)))
	ids.sort()
	return ids


func _roster_change_status(lobby: Dictionary) -> String:
	if _net_last_player_ids.is_empty():
		return ""
	var ids := _lobby_player_ids(lobby)
	if ids == _net_last_player_ids:
		return ""
	for id in _net_last_player_ids:
		if not ids.has(id):
			return "Player disconnected"
	for id in ids:
		if not _net_last_player_ids.has(id):
			return "Player joined"
	return ""


func _net_connection_lost(snap: Dictionary) -> bool:
	if _host_lost:
		return true
	if not bool(runtime.is_net_client()):
		return false
	if int(snap.get("net_connection", -1)) != 0:
		return false
	_host_lost = true
	_show_host_disconnected()
	return true


func _show_host_disconnected() -> void:
	_close_side_select_overlay(false)
	pause_menu.dismiss()
	# The match is already over and the host left the lobby: there is nothing left
	# to show here, so leave with him instead of a dead-end "host disconnected"
	# note over the result screen (whose buttons the note also blocks).
	if match_over.is_open():
		_return_to_main_menu()
		return
	if _net_status_layer == null:
		_net_status_layer = CanvasLayer.new()
		_net_status_layer.name = "NetStatus"
		_net_status_layer.layer = 9
		add_child(_net_status_layer)
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_net_status_layer.add_child(backdrop)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		_net_status_layer.add_child(center)
		_net_status_label = Label.new()
		_net_status_label.text = "HOST DISCONNECTED\n\nEnter / Esc: main menu"
		_net_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_net_status_label.add_theme_font_size_override("font_size", 28)
		_net_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.30))
		center.add_child(_net_status_label)
	_net_status_layer.visible = true


func _handle_gamepad_button(event: InputEventJoypadButton) -> void:
	var device := int(event.device)
	var button := int(event.button_index)
	var pressed := bool(event.pressed)
	if match_over.is_open():
		if pressed and (not match_over.is_choice() or _over_owner_ok(device)):
			match_over.handle_joy(event)
		return
	# Start is the pause key and works from any pad, even one that is not
	# assigned to a side in this match.
	if pressed and button == JOY_BUTTON_START:
		# The plan's exit is its READY overlay (B / Esc); Start is unused there.
		if game_plan != null and game_plan.is_open():
			return
		if pause_menu.is_open():
			pause_menu.close()
			return
		if not _other_menu_open():
			if _can_pause():
				_open_pause(device)
			return
	if game_plan != null and game_plan.is_open():
		game_plan.handle_joy_button(event)
		return
	if pause_menu.is_open():
		# Menu consumes presses; releases go straight to the runtime so a held pad
		# button does not stay down when the match resumes.
		if pause_menu.handle_joy(event) or pressed:
			return
		if input_slots.has(device):
			runtime.set_gamepad_button(int(input_slots[device]), button, false)
		return
	# The taker's own device owns the overlay; another local player's pad must
	# keep driving its team (the runtime freezes the taker on its side).
	if hud.is_taker_menu_open():
		if hud.accepts_taker_menu_joy(device):
			hud.handle_taker_menu_joy(event)
			return
		if input_slots.has(device):
			runtime.set_gamepad_button(int(input_slots[device]), button, pressed)
		return
	if not input_slots.has(device):
		return
	var slot := int(input_slots[device])
	if _menu_open():
		if not pressed:
			return
		var keycode := -1
		match button:
			JOY_BUTTON_A, JOY_BUTTON_START:
				keycode = KEY_ENTER
			JOY_BUTTON_B:
				keycode = KEY_ESCAPE
			JOY_BUTTON_DPAD_UP:
				keycode = KEY_UP
			JOY_BUTTON_DPAD_DOWN:
				keycode = KEY_DOWN
			JOY_BUTTON_DPAD_LEFT:
				keycode = KEY_LEFT
			JOY_BUTTON_DPAD_RIGHT:
				keycode = KEY_RIGHT
		if keycode != -1:
			_handle_key(_synthetic_key(keycode))
		return
	# Back/Select opens the taker menu, same as Tab, but only from the taker's
	# own pad (the series owns its own participants, so it is left out).
	if pressed and button == JOY_BUTTON_BACK \
			and not bool(runtime.get_snapshot().get("shootout_active", false)):
		hud.toggle_taker_menu("gamepad", device)
		return
	runtime.set_gamepad_button(slot, button, pressed)


func _handle_gamepad_motion(event: InputEventJoypadMotion) -> void:
	var device := int(event.device)
	if match_over.is_open():
		return
	if game_plan != null and game_plan.is_open():
		game_plan.handle_joy_motion(event)
		return
	if pause_menu.is_open():
		if int(event.axis) != JOY_AXIS_LEFT_Y or absf(event.axis_value) <= 0.5:
			return
		var now := Time.get_ticks_msec()
		if now - _pause_stick_ms < 220:
			return
		_pause_stick_ms = now
		_handle_key(_synthetic_key(KEY_DOWN if event.axis_value > 0.0 else KEY_UP))
		return
	if hud.is_taker_menu_open():
		if hud.accepts_taker_menu_joy(device):
			hud.handle_taker_menu_joy_motion(event)
		elif input_slots.has(device):
			runtime.set_gamepad_axis(int(input_slots[device]), int(event.axis), event.axis_value)
		return
	if not input_slots.has(device):
		return
	if _menu_open():
		return
	runtime.set_gamepad_axis(int(input_slots[device]), int(event.axis), event.axis_value)


func _synthetic_key(keycode: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func _forward_overlay_input(event: InputEvent) -> void:
	# No set_input_as_handled(): UiNav must still see the event. This only
	# mirrors the hardware state into the paused C++ match so releases land.
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return
		for function in SettingsStore.functions_for_key(key.keycode):
			runtime.set_button(int(function), key.pressed)
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		var device := int(joy.device)
		if input_slots.has(device):
			runtime.set_gamepad_button(int(input_slots[device]),
				int(joy.button_index), joy.pressed)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var device := int(motion.device)
		if input_slots.has(device):
			runtime.set_gamepad_axis(int(input_slots[device]),
				int(motion.axis), motion.axis_value)


func _handle_key(key_event: InputEventKey) -> void:
	if key_event.keycode == KEY_F4:
		if key_event.pressed:
			_start_fresh_match()
		return
	if key_event.keycode == KEY_F5:
		# Skip to the next break: the host (or a local match) pushes the clock to
		# the period end; the referee's own whistle opens the break.
		if key_event.pressed and not _menu_open() \
				and not (bool(runtime.is_net_active()) and bool(runtime.is_net_client())):
			runtime.debug_skip_to_period_end()
		return
	if match_over.is_open():
		# The end-of-match overlay is modal: the 90:00 choice is owned by P1
		# locally, the result screen takes any local device.
		if not match_over.is_choice() or _over_owner_ok(-1):
			match_over.handle_key(key_event)
		return
	if game_plan != null and game_plan.is_open():
		game_plan.handle_key(key_event)
		return
	if pause_menu.is_open():
		# Presses belong to the menu, but releases must still reach the runtime:
		# otherwise a direction held when the pause opened stays stuck down and
		# the player keeps running the wrong way after resume.
		if pause_menu.handle_key(key_event):
			return
	if replay.is_active():
		if key_event.pressed and key_event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			replay.finish()
		return
	if key_event.keycode == KEY_V:
		if key_event.pressed:
			camera_rig.toggle()
		return
	if key_event.keycode == KEY_F1:
		if key_event.pressed:
			environment_view.cycle_lighting()
		return
	var shootout_running := bool(runtime.get_snapshot().get("shootout_active", false))
	if key_event.keycode == KEY_F3:
		if key_event.pressed and not shootout_running:
			if hud.is_taker_menu_open():
				hud.close_taker_menu(false)
			runtime.debug_force_shootout()
		return
	# The series owns the set pieces, the taker order and the parking: ignore the debug set-piece,
	# Tab and F2 keys while it runs. Movement/action buttons MUST keep flowing to the runtime below:
	# the series needs the aim stick, the shot button and the keeper's dive stick.
	if not shootout_running:
		if key_event.keycode == KEY_F2:
			if key_event.pressed:
				runtime.toggle_debug_park_opponents()
			return
		if key_event.keycode == KEY_TAB:
			if key_event.pressed:
				hud.toggle_taker_menu("keyboard", 0)
			return
		if hud.is_taker_menu_open():
			if hud.accepts_taker_menu_keyboard() \
					and hud.handle_taker_menu_key(key_event):
				return
			# A keyboard that does not own the overlay is another local player's
			# input and keeps flowing to the runtime below.
		if key_event.pressed and key_event.keycode == KEY_ESCAPE and _can_pause():
			_open_pause()
			return
		if SET_PIECE_KEYS.has(key_event.keycode):
			if key_event.pressed:
				var human_team: int = runtime.get_human_team_id()
				if human_team < 0:
					human_team = 0
				var team := human_team
				if key_event.alt_pressed:
					team = 1 - human_team
				runtime.debug_force_set_piece(SET_PIECE_KEYS[key_event.keycode], team)
			return
	var functions: Array = SettingsStore.functions_for_key(key_event.keycode)
	for function in functions:
		runtime.set_button(int(function), key_event.pressed)


func _run_demo() -> void:
	if frames < 90:
		runtime.set_button(1, true)
		runtime.set_button(14, true)
	elif frames == 90:
		runtime.set_button(1, false)
		runtime.set_button(14, false)
		runtime.set_button(7, true)
	elif frames == 125:
		runtime.set_button(7, false)


func _start_fresh_match() -> void:
	# Restarting a LAN match locally would desync the peers; a rematch must go
	# back through the network lobby (ticket 18, follow-up).
	if bool(runtime.is_net_active()):
		push_warning("GpfSlice: a LAN rematch must be started from the network lobby")
		return
	# Tear down the presentation, ask C++ for a fresh match and rebuild the actors
	# from the new match's player list (F4 debug key and the end-of-match menu).
	# The rebuild blocks the thread for ~2 s: cover it, and raise the curtain
	# without a fade-in (there is no frame to animate it in).
	var connecting := get_node_or_null("/root/UiConnecting")
	if connecting != null:
		connecting.call("open", Callable(), "LOADING MATCH", true)
	if replay.is_active():
		replay.finish()
	replay.reset()
	hud.reset()
	shootout.reset()
	match_over.hide_now()
	# The previous match's committed plan must not leak into the new one.
	if pause_menu != null:
		pause_menu.set_plan_lineups({})
	actors.reset()
	_roster_ids = []
	_roster_names = {}
	_net_notice_ready_ms = 0
	if game_plan != null:
		game_plan.clear_local_orders()
	_configure_input()
	SettingsStore.apply_to_runtime(runtime)
	if not runtime.restart_match():
		push_error("GpfRuntime restart failed: " + str(runtime.get_last_error()))
		_drop_loader_after_draw()
		return
	goal_nets.update()
	_build_presentation()
	_drop_loader_after_draw()
	print("new match: ids=", runtime.get_player_ids().size(),
		" tick=", runtime.get_tick())


func _return_to_main_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if replay.is_active():
		replay.finish()
	# Fade the end-of-match overlay out before the scene swap; an instant cut made
	# ADVANCE look like the screen just vanished.
	if match_over.is_open():
		match_over.dismiss()
		if match_over.is_open():
			await match_over.closed
	# UiTransition ignores a scene change that arrives while its own hide is still
	# running (its busy flag clears after the close callback), so yield a frame.
	await get_tree().process_frame
	# Leaving a LAN match tears the session down before the menu appears.
	if runtime != null and is_instance_valid(runtime) and bool(runtime.is_net_active()):
		runtime.net_leave()
	var transition := get_node_or_null("/root/UiTransition")
	if transition != null:
		transition.change_scene(MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _return_to_team_select() -> void:
	get_tree().change_scene_to_file(TEAM_SELECT_SCENE)


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(shot_path)
	print("screenshot saved=", shot_path, " err=", err)
	get_tree().quit()

