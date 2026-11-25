extends SceneTree
# Windowed capture for ticket 10: the substitution stack, the right-side
# set-piece hints and the shootout dots under the scoreboard, in a live match.
#
# Run:  godot --path . -s res://tests/capture_hud_shots.gd
# Out:  .scratch/hud_shots/*.png (full frame + a HUD crop each)
#
# Known: the process exits with the pre-existing GpfSlice teardown access
# violation after the last save; every PNG already on disk is valid.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football/.scratch/hud_shots"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var saved := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	root.position = Vector2i(40, 40)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(2)
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8)
	if package.is_empty():
		push_error("capture_hud_shots: match package could not be built")
		quit(1)
		return
	ShellState.set_match_package(package)
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	var runtime := get_first_node_in_group("gpf_runtime")
	if runtime == null or not await _wait_match(runtime, 60000):
		push_error("capture_hud_shots: match never started")
		quit(1)
		return
	await _take_kickoff(runtime)
	if not await _wait_open_play(runtime, 30000):
		push_error("capture_hud_shots: kickoff never reached open play")
		quit(1)
		return
	var hud: GpfHud = scene.get_node("Hud")
	await _frames(10)

	# The stack is normally filled from the snapshot counter; pushing the three
	# test lines directly shows the real component over the real pitch.
	hud.show_substitution_notice([
		"Rivera off, Koval on",
		"Velasco off, Brandt on",
		"Duarte off, Okafor on",
	], [0, 0, 1])
	await create_timer(0.45).timeout
	await _save("hud_substitutions", Rect2i(500, 0, 920, 240))

	runtime.call("debug_force_set_piece", 3, 0)
	var piece := await _wait_set_piece(runtime, 40000)
	if piece.is_empty():
		push_error("capture_hud_shots: free kick never went live")
		quit(1)
		return
	await create_timer(0.4).timeout
	await _save("hud_set_piece", Rect2i(1400, 40, 520, 260))

	# F4 rebuilds the match; the shootout needs clean open play (the free kick
	# screenshot is taken with the ball still waiting on the whistle).
	scene.call("_start_fresh_match")
	if not await _wait_match(runtime, 60000):
		push_error("capture_hud_shots: fresh match never started")
		quit(1)
		return
	await _take_kickoff(runtime)
	if not await _wait_open_play(runtime, 30000):
		push_error("capture_hud_shots: fresh kickoff never reached open play")
		quit(1)
		return
	await _frames(10)
	# Step the series deterministically: the real-time C++ loop only leaves the
	# outcome hold on its own in a live match, but the capture needs exact kicks.
	runtime.set("manual_step", true)
	runtime.call("debug_force_shootout")
	if not await _wait_shootout(runtime, 30000):
		push_error("capture_hud_shots: shootout never started")
		quit(1)
		return
	var first_team := -1
	var goal_x := 0.0
	var shots := 0
	while shots < 12:
		var snap := await _step_to_phase(runtime, 2, 800)
		print("  kick ", shots + 1, ": phase=", snap.get("shootout_phase", -1),
			" taker=", snap.get("shootout_taker_team", -1),
			" kicks=", (snap.get("shootout_kicks0", []) as Array).size(), "+",
			(snap.get("shootout_kicks1", []) as Array).size())
		if int(snap.get("shootout_phase", -1)) != 2:
			break
		var taker := int(snap.get("shootout_taker_team", -1))
		if first_team < 0:
			first_team = taker
			goal_x = float(snap.get("shootout_goal_x", 0.0))
		var kicks0: Array = snap.get("shootout_kicks0", [])
		var kicks1: Array = snap.get("shootout_kicks1", [])
		var taken := kicks0.size() + kicks1.size()
		if taken == 10:
			await create_timer(0.3).timeout
			await _save("hud_shootout", Rect2i(0, 0, 420, 220))
		if taker == 0:
			runtime.call("set_button", 7, true)
			runtime.call("step_fixed", 25)
			runtime.call("set_button", 7, false)
		snap = await _step_to_phase(runtime, 3, 800)
		if int(snap.get("shootout_phase", -1)) != 3:
			break
		# Keep the series level through five pairs, then the coin-toss winner
		# takes the sudden-death round (its sixth kick clears the row).
		var score_it := taken < 10 or taker == first_team
		var sign := 1.0 if goal_x > 0.0 else -1.0
		if score_it:
			runtime.call("debug_set_ball", Vector3(goal_x + sign, 0.0, 0.5), Vector3.ZERO)
		else:
			runtime.call("debug_set_ball", Vector3(0.0, 40.0, 0.5), Vector3.ZERO)
		# Manual stepping: wait until the outcome is actually recorded (the
		# circle row must show the new kick), not a fixed 15 ticks.
		var waited := 0
		while waited < 400:
			runtime.call("step_fixed", 5)
			waited += 5
			await process_frame
			snap = runtime.get_snapshot()
			if (snap.get("shootout_kicks0", []) as Array).size() \
					+ (snap.get("shootout_kicks1", []) as Array).size() > taken \
					or int(snap.get("shootout_phase", -1)) == 6:
				break
		shots += 1
		if taken == 10:
			await create_timer(0.5).timeout
			await _save("hud_shootout_sd", Rect2i(0, 0, 420, 220))
			break
		await _frames(5)
	if saved < 8:
		push_error("capture_hud_shots: only %d shots saved" % saved)
		quit(1)
		return
	print("captured ", saved, " HUD screenshots into ", OUT_DIR)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_match(runtime: Node, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_play", false)) and int(snap.get("actual_time_ms", 0)) > 500:
			return true
		await process_frame
	return false


func _wait_open_play(runtime: Node, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_play", false)) and not bool(snap.get("in_set_piece", false)) \
				and not bool(snap.get("goal_scored", false)) \
				and int(snap.get("actual_time_ms", 0)) > 500:
			return true
		await process_frame
	return false


func _take_kickoff(runtime: Node) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 60000:
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) \
				and int(snap.get("set_piece_type", 0)) == 1:
			break
		await process_frame
	await _press(runtime, 6, 0.06)


func _wait_set_piece(runtime: Node, timeout_ms: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) \
				and int(snap.get("set_piece_role", 0)) != 0:
			return snap
		await process_frame
	return {}


func _wait_shootout(runtime: Node, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		if bool(runtime.get_snapshot().get("shootout_active", false)):
			return true
		await process_frame
	return false


func _step_to_phase(runtime: Node, target: int, max_steps: int) -> Dictionary:
	var snap: Dictionary = runtime.get_snapshot()
	var waited := 0
	while waited < max_steps:
		if int(snap.get("shootout_phase", -1)) == target:
			await process_frame
			return snap
		runtime.call("step_fixed", 5)
		waited += 5
		await process_frame
		snap = runtime.get_snapshot()
	return snap


func _press(runtime: Node, button: int, seconds: float) -> void:
	runtime.call("set_button", button, true)
	await create_timer(seconds).timeout
	runtime.call("set_button", button, false)


func _save(shot: String, region: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		push_error("capture_hud_shots: no image for " + shot)
		return
	var path := "%s/%s.png" % [OUT_DIR, shot]
	if image.save_png(path) == OK:
		saved += 1
		print("  ", path, "  ", image.get_size())
	else:
		push_error("capture_hud_shots: save failed " + path)
	var crop := image.get_region(region)
	if crop.save_png("%s/%s_crop.png" % [OUT_DIR, shot]) == OK:
		saved += 1
		print("  ", OUT_DIR, "/", shot, "_crop.png  ", crop.get_size())
