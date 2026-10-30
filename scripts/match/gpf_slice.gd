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

var runtime: Node
@onready var camera := $Camera3D
@onready var actors: GpfActors = $Actors
@onready var environment_view: GpfEnvironment = $Environment
@onready var goal_nets: GpfGoalNets = $GoalNets
@onready var camera_rig: GpfCameraRig = $CameraRig
@onready var hud: GpfHud = $Hud
@onready var replay: GpfReplay = $ReplayView
@onready var shootout: GpfShootoutView = $ShootoutView

const BUTTONS := {
	KEY_UP: [0],
	KEY_RIGHT: [1],
	KEY_DOWN: [2],
	KEY_LEFT: [3],
	KEY_W: [4, 8],
	KEY_A: [5, 9],
	KEY_S: [6, 10],
	KEY_D: [7, 11],
	KEY_Q: [12],
	KEY_Z: [13],
	KEY_E: [14],
	KEY_C: [15],
	KEY_ENTER: [17],
}

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
# Godot joypad id -> C++ virtual gamepad slot, for the devices in the shell setup.
var input_slots: Dictionary = {}


func _ready() -> void:
	# The match only exists from a real shell selection: the prematch builds the
	# package. There is no built-in team pair to fall back to.
	if not ShellState.has_package():
		push_error("GpfSlice: no match package; choose teams in the shell first")
		_return_to_team_select.call_deferred()
		return
	runtime = _acquire_runtime(ShellState.match_package)
	# The runtime scene starts manually; gamepad registration needs the original
	# input singletons, so bring the runtime up before applying the setup.
	if not bool(runtime.is_runtime_ready()):
		runtime.start_runtime_now()
	_configure_input()
	actors.setup(runtime)
	environment_view.setup(runtime, $Sun, $FillLight)
	goal_nets.setup(runtime, environment_view)
	camera_rig.setup(camera, actors)
	hud.setup(runtime)
	if not ShellState.controllers.is_empty() \
			and str(ShellState.controllers[0].get("kind", "keyboard")) == "gamepad":
		hud.set_taker_hint_key("Select")
	replay.setup(runtime, camera, actors, goal_nets, hud)
	shootout.setup()

	hud.main_menu_requested.connect(_return_to_main_menu)
	shootout.main_menu_requested.connect(_return_to_main_menu)
	shootout.restart_requested.connect(_start_fresh_match)

	# Every scene load is a new match: stop and restart so the previous match's
	# clock, score and objects cannot leak into this one.
	if not runtime.restart_match():
		push_error("GpfRuntime failed: " + str(runtime.get_last_error()))
		return
	goal_nets.build_dynamic()
	_build_presentation()


func _exit_tree() -> void:
	# The runtime node stays under the tree root for the next match; park it stopped.
	if runtime != null and is_instance_valid(runtime):
		runtime.stop_match()


func _acquire_runtime(package: Dictionary) -> Node:
	var existing := get_tree().get_first_node_in_group(RUNTIME_GROUP)
	if existing != null:
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


func _build_presentation() -> void:
	var ids: Array = runtime.get_player_ids()
	var controlled := _pick_controlled(ids)
	if controlled >= 0:
		runtime.select_player(controlled)
		print("display_player_id=", controlled, " human_after_select=", runtime.get_human_player_id())
	actors.spawn(ids)
	actors.set_controlled(controlled)
	runtime.set("manual_step", false)
	started = true


func _pick_controlled(ids: Array) -> int:
	# The C++ side already selected a player for the human's gamer.
	var human := int(runtime.get_human_player_id())
	if human > 0:
		return human
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


func _process(delta: float) -> void:
	if not started:
		return
	if replay.is_active():
		replay.update(delta)
		return
	if demo:
		_run_demo()
	var current_id: int = runtime.get_human_player_id()
	if current_id > 0:
		actors.set_controlled(current_id)
	var snap: Dictionary = runtime.get_snapshot()
	if snap.is_empty():
		return
	shootout.update(snap, delta)
	var poses := actors.apply_runtime()
	actors.sync_ball(snap)
	camera_rig.update(snap)
	goal_nets.update()
	replay.record(poses)
	replay.on_snapshot(snap)
	actors.update_reticle(snap)
	actors.apply_park_visibility(snap)
	actors.set_labels_visible(not camera_rig.stadium)
	hud.update(snap, actors.get_controlled(), actors.count(), camera_rig.stadium,
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
	if event is InputEventJoypadButton:
		_handle_gamepad_button(event as InputEventJoypadButton)
		return
	if event is InputEventJoypadMotion:
		_handle_gamepad_motion(event as InputEventJoypadMotion)
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.echo:
		return
	_handle_key(key_event)


func _menu_open() -> bool:
	return replay.is_active() or shootout.is_end_menu_open() \
		or hud.is_phase_menu_open() or hud.is_taker_menu_open()


func _handle_gamepad_button(event: InputEventJoypadButton) -> void:
	var device := int(event.device)
	if not input_slots.has(device):
		return
	var slot := int(input_slots[device])
	var button := int(event.button_index)
	var pressed := bool(event.pressed)
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
	# Back/Select opens the taker menu, same as Tab (the series owns its own
	# participants, so it is left out).
	if pressed and button == JOY_BUTTON_BACK \
			and not bool(runtime.get_snapshot().get("shootout_active", false)):
		_handle_key(_synthetic_key(KEY_TAB))
		return
	runtime.set_gamepad_button(slot, button, pressed)


func _handle_gamepad_motion(event: InputEventJoypadMotion) -> void:
	var device := int(event.device)
	if not input_slots.has(device) or _menu_open():
		return
	runtime.set_gamepad_axis(int(input_slots[device]), int(event.axis), event.axis_value)


func _synthetic_key(keycode: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func _handle_key(key_event: InputEventKey) -> void:
	if key_event.keycode == KEY_F4:
		if key_event.pressed:
			_start_fresh_match()
		return
	if replay.is_active():
		if key_event.pressed and key_event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			replay.finish()
		return
	if shootout.is_end_menu_open():
		shootout.handle_end_menu_key(key_event)
		return
	if hud.is_phase_menu_open():
		hud.handle_phase_menu_key(key_event)
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
				hud.toggle_taker_menu()
			return
		if hud.is_taker_menu_open():
			hud.handle_taker_menu_key(key_event)
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
	var functions: Array = BUTTONS.get(key_event.keycode, [])
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
	# Tear down the presentation, ask C++ for a fresh match and rebuild the actors
	# from the new match's player list (F4 debug key and the end-of-match menu).
	if replay.is_active():
		replay.finish()
	replay.reset()
	hud.reset()
	shootout.reset()
	actors.reset()
	_configure_input()
	if not runtime.restart_match():
		push_error("GpfRuntime restart failed: " + str(runtime.get_last_error()))
		return
	goal_nets.update()
	_build_presentation()
	print("new match: ids=", runtime.get_player_ids().size(),
		" tick=", runtime.get_tick())


func _return_to_main_menu() -> void:
	if replay.is_active():
		replay.finish()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _return_to_team_select() -> void:
	get_tree().change_scene_to_file(TEAM_SELECT_SCENE)


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(shot_path)
	print("screenshot saved=", shot_path, " err=", err)
	get_tree().quit()
