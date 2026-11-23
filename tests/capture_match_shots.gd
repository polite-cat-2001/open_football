extends SceneTree
# Windowed match screenshot bench: kickoff, mid-play, the stadium view and the
# four time-of-day presets, plus a frame-rate sample for each.
# GPF_SHOT_TAG separates a before/after pair (default: the root folder).
#
# Run:  godot --path . -s res://tests/capture_match_shots.gd
# Out:  .scratch/match_shots/<tag>/<shot>.png
#
# Known: the process exits with an access violation (-1073741819) after the last
# save. That is the pre-existing GpfSlice teardown crash, not a failed capture;
# every shot already written to disk is valid.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const OUT_ROOT := "C:/Users/Egor/Desktop/projects/open_football/.scratch/match_shots"
# e_ButtonFunction_ShortPass in the C++ gamepad enum (gpf_runtime_node.cpp set_button).
const SHORT_PASS_BUTTON := 6
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var out_dir := OUT_ROOT
var saved := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tag := OS.get_environment("GPF_SHOT_TAG").strip_edges()
	out_dir = OUT_ROOT + ("/" + tag if tag != "" else "")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	root.position = Vector2i(40, 40)
	# Uncapped: the shadow cost has to show up in the numbers, not be hidden by vsync.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(2)

	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8)
	if package.is_empty():
		push_error("capture_match_shots: match package could not be built")
		quit(1)
		return
	ShellState.set_match_package(package)
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	var runtime := get_first_node_in_group("gpf_runtime")
	if runtime == null or not await _wait_match_ms(runtime, 1, 60000):
		push_error("capture_match_shots: match never started")
		quit(1)
		return
	await _save("kickoff")
	# The kickoff set piece only goes live once the whistle has set it up and the
	# human taker is expected; a fixed delay can fire before that and the press is lost.
	if not await _wait_set_piece(runtime, 60000):
		push_error("capture_match_shots: kickoff set piece never went live")
		quit(1)
		return
	await _press_button(runtime, SHORT_PASS_BUTTON)
	if not await _wait_match_ms(runtime, 8000, 60000):
		push_error("capture_match_shots: match clock did not reach 8 s")
		quit(1)
		return
	# A dead press leaves the kickoff pose on screen, so only accept a mid-play
	# shot once the ball has actually left the centre spot.
	var snap: Dictionary = runtime.get_snapshot()
	var ball_pos: Vector3 = snap.get("ball_pos", Vector3.ZERO)
	if ball_pos.length() <= 1.0:
		push_error("capture_match_shots: ball only moved %.2f m from centre, kickoff pass never happened" % ball_pos.length())
		quit(1)
		return
	print("  ball moved ", snappedf(ball_pos.length(), 0.01), " m from centre")
	await _measure("mid_play")
	await _save("mid_play")

	scene.call("_input", _key(KEY_F6))
	await create_timer(0.5).timeout
	await _measure("stadium_view")
	await _save("stadium_view")
	# From Afternoon: F8 -> Sunset -> Night -> Noon -> Afternoon. Each preset
	# gets a frame-rate sample, so a night regression shows up in the log.
	var environment: Node = scene.get_node("Environment")
	for i in 4:
		scene.call("_input", _key(KEY_F8))
		await create_timer(0.5).timeout
		var preset_name := String(environment.call("lighting_name")).to_lower()
		await _measure("lighting_" + preset_name)
		await _save("lighting_" + preset_name)

	# Sunset / Night in play: the stadium view shows the pitch a few pixels wide,
	# so judge the dark presets from the broadcast camera too.
	scene.call("_input", _key(KEY_F8))  # Afternoon -> Sunset
	await create_timer(0.3).timeout
	scene.call("_input", _key(KEY_F6))
	await create_timer(0.5).timeout
	await _save("sunset_play")
	scene.call("_input", _key(KEY_F8))  # Sunset -> Night
	await create_timer(0.3).timeout
	await _save("night_play")
	for i in 2:  # Night -> Noon -> Afternoon
		scene.call("_input", _key(KEY_F8))
		await create_timer(0.2).timeout

	# Penalty close-up (set piece type 6): the broadcast camera is already live.
	# The players walk into the box during the setup phase, and the close penalty
	# camera engages only once the local human owns the kicker role.
	runtime.call("debug_force_set_piece", 6, 0)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 40000:
		var state: Dictionary = runtime.get_snapshot()
		if int(state.get("set_piece_role", 0)) != 0:
			break
		await process_frame
	var penalty: Dictionary = runtime.get_snapshot()
	if int(penalty.get("set_piece_role", 0)) == 0:
		push_error("capture_match_shots: penalty close-up never went live")
		quit(1)
		return
	print("  penalty taker role=", int(penalty.get("set_piece_role", 0)),
		" at clock=", penalty.get("actual_time_ms"), " ms")
	await create_timer(0.5).timeout
	await _save("player_closeup")

	# F7 re-rolls the pitch; one shot proves the debug key regenerates cleanly.
	scene.call("_input", _key(KEY_F7))
	await create_timer(1.2).timeout
	await _save("pitch_reroll")

	print("captured ", saved, " match screenshots into ", out_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_match_ms(runtime: Node, target_ms: int, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		var snap: Dictionary = runtime.get_snapshot()
		if int(snap.get("actual_time_ms", 0)) >= target_ms:
			print("  match clock=", snap.get("actual_time_ms"), " ms")
			return true
		await process_frame
	return false


func _wait_set_piece(runtime: Node, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)):
			print("  set piece live at clock=", snap.get("actual_time_ms"), " ms")
			return true
		await process_frame
	return false


func _press_button(runtime: Node, index: int) -> void:
	runtime.set_button(index, true)
	await create_timer(0.06).timeout
	runtime.set_button(index, false)


func _measure(label: String) -> void:
	var started := Time.get_ticks_usec()
	var frames := Engine.get_process_frames()
	await create_timer(2.0).timeout
	var seconds := (Time.get_ticks_usec() - started) / 1000000.0
	var drawn := maxi(Engine.get_process_frames() - frames, 1)
	print("fps ", label, "=", snappedf(drawn / seconds, 0.1),
		" (", snappedf(seconds * 1000.0 / drawn, 0.01), " ms/frame)")


func _save(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		push_error("capture_match_shots: no image for " + shot)
		return
	var path := "%s/%s.png" % [out_dir, shot]
	var error := image.save_png(path)
	if error != OK:
		push_error("capture_match_shots: save failed %s (%d)" % [path, error])
		return
	saved += 1
	print("  ", path, "  ", image.get_size())


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
