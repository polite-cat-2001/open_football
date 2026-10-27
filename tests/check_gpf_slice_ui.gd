extends SceneTree
# Smoke test for the Godot-side in-match UI: the Tab taker menu, debug throw-ins and
# the half-time/full-time phase menu. Loads the real slice scene, forces the states
# through the bridge.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"

var scene: Node
var runtime: Node
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/gpf_slice.tscn")
	scene = packed.instantiate()
	get_root().add_child(scene)
	await process_frame
	runtime = scene.get_node("GpfRuntime")
	runtime.set("manual_step", true)
	runtime.set("data_root", DATA_ROOT)
	for i in 4:
		await process_frame
	var net0 := scene.get_node_or_null("Goals/GoalNet0") as MeshInstance3D
	_check(net0 != null and net0.mesh != null and net0.mesh.get_surface_count() > 0,
		"dynamic goal net is built")
	var goal_frames := scene.get_node_or_null("Environment/GoalFrames") as Node3D
	var frame_count := 0
	var hidden_count := 0
	if goal_frames != null:
		for node in goal_frames.find_children("*", "MeshInstance3D", true, false):
			if node.visible:
				frame_count += 1
			else:
				hidden_count += 1
	_check(goal_frames != null and frame_count == 1 and hidden_count == 1,
		"imported goal frame is visible and static net is hidden")

	var stadium := scene.get_node_or_null("Environment/Stadium") as Node3D
	_check(stadium != null and stadium.visible, "imported stadium is present")
	var stadium_meshes := stadium.find_children("*", "MeshInstance3D", true, false) if stadium else []
	var textured := 0
	for node in stadium_meshes:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_surface_override_material(surface)
			if material == null:
				material = mesh.mesh.surface_get_material(surface)
			if material is BaseMaterial3D and material.albedo_texture != null:
				textured += 1
	_check(stadium_meshes.size() >= 31 and textured >= 31,
		"stadium meshes carry baked textures (%d meshes, %d textured surfaces)" % [stadium_meshes.size(), textured])
	var pitch_node := scene.get_node_or_null("Environment/Pitch") as Node3D
	var pitch_materials: Array = scene.get("pitch_materials")
	var pitch_surface: MeshInstance3D = null
	if pitch_node != null:
		pitch_surface = pitch_node.get_node_or_null("PitchSurface") as MeshInstance3D
	_check(pitch_node != null and pitch_node.visible and pitch_materials.size() == 1
		and pitch_surface != null and pitch_surface.mesh.get_surface_count() == 1,
		"imported pitch is merged into one themed surface")
	scene.call("set_pitch_theme", "wet")
	var wet_pitch := pitch_materials[0] as StandardMaterial3D
	_check(wet_pitch != null and wet_pitch.roughness < 0.5, "wet pitch theme changes roughness")
	scene.call("set_pitch_theme", "dry")
	scene.call("_input", _key(KEY_V))
	await process_frame
	_check(bool(scene.get("stadium_camera")), "V switches to the stadium camera")
	scene.call("_input", _key(KEY_V))
	await process_frame
	_check(not bool(scene.get("stadium_camera")), "V returns to the broadcast camera")

	var ids: Array = runtime.get_player_ids()
	var outfield := -1
	var opponent_outfield := -1
	for entry in ids:
		if String(entry.get("role", "")) != "player":
			continue
		if int(entry.get("team", -1)) == 0 and outfield < 0:
			outfield = int(entry.get("id", -1))
		elif int(entry.get("team", -1)) == 1 and opponent_outfield < 0:
			opponent_outfield = int(entry.get("id", -1))
	_check(outfield >= 0, "outfield exists")
	_check(opponent_outfield >= 0, "opponent outfield exists")
	if outfield < 0 or opponent_outfield < 0:
		_finish()
		return

	runtime.start_open_play(outfield)
	runtime.step_fixed(120)

	scene.call("_input", _key(KEY_F2))
	await process_frame
	_check(bool(runtime.get_snapshot().get("debug_park_opponents", false)),
		"F2 parks opponent outfielders")
	var bodies: Dictionary = scene.get("actor_bodies")
	var red_body: Node3D = bodies.get(opponent_outfield)
	_check(red_body != null and not red_body.visible, "parked opponent is hidden")
	scene.call("_input", _key(KEY_F2))
	await process_frame
	_check(not bool(runtime.get_snapshot().get("debug_park_opponents", false)),
		"F2 restores opponent outfielders")
	_check(red_body != null and red_body.visible, "opponent is visible again")

	runtime.debug_force_set_piece(3, 0)
	var snap: Dictionary = {}
	for i in 500:
		runtime.step_fixed(10)
		await process_frame
		snap = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) and int(snap.get("referee_set_piece", 0)) == 3:
			break
	_check(bool(snap.get("set_piece_local_taker", false)), "free kick has a local taker")
	var hint := scene.get("taker_hint") as Label
	_check(hint != null and hint.visible, "Tab hint is visible for the local taker")
	scene.call("_input", _key(KEY_TAB))
	await process_frame
	_check(bool(scene.get("taker_menu_open")), "Tab opens the taker menu")
	_check(bool(runtime.is_set_piece_taker_menu_open()), "bridge menu is open")
	var menu_label := scene.get("taker_menu_label") as Label
	_check(menu_label != null and "SET-PIECE" not in menu_label.text, "menu lists players")
	scene.call("_input", _key(KEY_ESCAPE))
	await process_frame
	_check(not bool(scene.get("taker_menu_open")), "Escape closes the taker menu")
	_check(not bool(runtime.is_set_piece_taker_menu_open()), "bridge menu is closed")
	runtime.step_fixed(2)
	await process_frame
	var before_taker := int(runtime.get_snapshot().get("referee_taker", -1))
	scene.call("_input", _key(KEY_TAB))
	scene.call("_input", _key(KEY_DOWN))
	scene.call("_input", _key(KEY_ENTER))
	await process_frame
	runtime.step_fixed(3)
	var after: Dictionary = runtime.get_snapshot()
	_check(not bool(scene.get("taker_menu_open")), "Enter closes the taker menu")
	_check(int(after.get("referee_taker", -1)) != before_taker, "Enter applies another taker")

	runtime.start_open_play(outfield)
	await process_frame
	runtime.step_fixed(20)
	scene.call("_input", _key(KEY_O))
	var throw_snap: Dictionary = await _wait_for_set_piece(5)
	_check(not throw_snap.is_empty(), "O forces a throw-in")
	_check(int(throw_snap.get("referee_team", -1)) == 0, "O gives the throw-in to the human team")

	runtime.start_open_play(outfield)
	await process_frame
	runtime.step_fixed(20)
	var alt_o := _key(KEY_O)
	alt_o.alt_pressed = true
	scene.call("_input", alt_o)
	throw_snap = await _wait_for_set_piece(5)
	_check(not throw_snap.is_empty(), "Alt+O forces a throw-in")
	_check(int(throw_snap.get("referee_team", -1)) == 1, "Alt+O gives the throw-in to the opponent")

	runtime.debug_force_phase_break(2)
	for i in 10:
		await process_frame
	_check(bool(scene.get("phase_menu_open")), "phase break opens the menu")
	var phase_title := scene.get("phase_menu_title") as Label
	_check(phase_title != null and phase_title.text == "HALF TIME", "half-time title is shown")
	_check(bool(runtime.get_snapshot().get("paused", false)), "phase break pauses the match")
	scene.call("_input", _key(KEY_ENTER))
	await process_frame
	_check(not bool(scene.get("phase_menu_open")), "Enter continues after the phase break")
	_check(not bool(runtime.get_snapshot().get("paused", false)), "continue unpauses the match")

	runtime.debug_force_game_over()
	for i in 10:
		await process_frame
	_check(bool(scene.get("phase_menu_open")), "game over opens the result menu")
	_check(phase_title != null and phase_title.text in ["FULL TIME", "AFTER EXTRA TIME"], "full-time title is shown")
	var continue_button := scene.get("phase_menu_continue") as Button
	_check(continue_button != null and not continue_button.visible, "result menu has no continue button")
	_finish()

func _wait_for_set_piece(type: int) -> Dictionary:
	for i in 500:
		runtime.step_fixed(10)
		await process_frame
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) and int(snap.get("referee_set_piece", 0)) == type:
			return snap
	return {}

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: slice UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
