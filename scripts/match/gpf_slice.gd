extends Node3D
# Scene orchestrator for the GDExtension gameplay slice. It wires the presentation
# components together and routes input to them; it owns no match or presentation state.

@onready var runtime := $GpfRuntime
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


func _ready() -> void:
	actors.setup(runtime)
	environment_view.setup(runtime, $Sun, $FillLight)
	goal_nets.setup(runtime, environment_view)
	camera_rig.setup(camera, actors)
	hud.setup(runtime)
	replay.setup(runtime, camera, actors, goal_nets, hud)
	shootout.setup()

	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		push_error("GpfRuntime failed: " + str(runtime.get_last_error()))
		return
	goal_nets.build_dynamic()

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
	for entry in ids:
		if int(entry.get("team", -1)) == 0 and int(entry.get("id", -1)) != 0 \
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
	if not started or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.echo:
		return
	if key_event.keycode == KEY_F4:
		if key_event.pressed:
			_debug_restart_match()
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
	# Tab and F2 keys while it runs. Movement/action buttons MUST keep flowing to the runtime below —
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


func _debug_restart_match() -> void:
	# F4 debug: tear down the presentation, ask C++ for a fresh match and rebuild
	# the actors from the new match's player list.
	if replay.is_active():
		replay.finish()
	replay.reset()
	hud.reset()
	shootout.reset()
	actors.reset()
	if not runtime.restart_match():
		push_error("GpfRuntime restart failed: " + str(runtime.get_last_error()))
		return
	goal_nets.update()
	var ids: Array = runtime.get_player_ids()
	var controlled := _pick_controlled(ids)
	if controlled >= 0:
		runtime.select_player(controlled)
	actors.spawn(ids)
	actors.set_controlled(controlled)
	print("debug restart: ids=", ids.size(), " controlled=", controlled,
		" tick=", runtime.get_tick())


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(shot_path)
	print("screenshot saved=", shot_path, " err=", err)
	get_tree().quit()
