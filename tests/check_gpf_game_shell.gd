extends SceneTree
# End-to-end check for the GPF game shell: main menu -> match -> final whistle ->
# main menu -> second match, all in one process. The C++ runtime node must survive
# the scene change while every presentation piece is rebuilt from scratch.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_game_shell.gd

const MAIN_MENU := "res://scenes/main_menu.tscn"
const RUNTIME_GROUP := "gpf_runtime"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _runtime() -> Node:
	return get_first_node_in_group(RUNTIME_GROUP)


func _press_start(menu: Node) -> void:
	var start := menu.get_node_or_null("StartBtn") as Button
	if start == null:
		failures.append("main menu has no Start Match button")
		return
	start.pressed.emit()
	await _frames(3)
	# Start Match now opens the original-style controller/side select first.
	if current_scene != null and current_scene.name == "ControllerSelect":
		# A lone keyboard starts on home; Enter confirms it and commits.
		current_scene.call("_input", _key(KEY_ENTER))
		await _frames(3)
	# With teams already picked, the controller screen goes straight to prematch.
	if current_scene != null and current_scene.name == "Prematch":
		var kick_off := current_scene.get("start_button") as Button
		if kick_off == null:
			failures.append("prematch has no Kick Off button")
			return
		kick_off.pressed.emit()
		await _frames(4)


func _run() -> void:
	# The shell has no built-in teams: preselect a real pair, as the team screen
	# would. Each prematch Kick Off rebuilds the package.
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(""):
		failures.append("team catalog could not be loaded: " + catalog.error)
		_finish()
		return
	ShellState.set_teams(catalog.team_by_id(4), catalog.team_by_id(5))

	change_scene_to_file(MAIN_MENU)
	await _frames(3)
	var menu := current_scene
	_check(menu != null and menu.name == "MainMenu", "boots into the main menu")
	if menu == null or menu.get_node_or_null("StartBtn") == null:
		_finish()
		return

	# First match: Start Match must lead through the prematch to the GPF match.
	await _press_start(menu)
	var first := current_scene
	_check(first != null and first.name == "GpfSlice", "Start Match opens the GPF match")
	if first == null or first.name != "GpfSlice":
		_finish()
		return
	var runtime := _runtime()
	_check(runtime != null and runtime.is_runtime_ready(), "the runtime started")
	if runtime == null or not runtime.is_runtime_ready():
		_finish()
		return
	var baseline_players := (runtime.get_player_ids() as Array).size()
	var baseline_objects := int(runtime.debug_get_scene_object_count())
	_check(baseline_players > 0, "first match spawns players (%d)" % baseline_players)
	var first_actors := first.get_node("Actors")
	_check(int(first_actors.call("count")) == baseline_players,
		"first match presents every player")
	var baseline_labels := (first_actors.get("player_labels") as Dictionary).size()
	_check(baseline_labels > 0, "first match builds nameplates")

	# Final whistle: the result menu replaces the old "quit the app" button with
	# a return to the main menu.
	runtime.debug_force_game_over()
	await _frames(10)
	var first_hud := first.get_node("Hud")
	_check(bool(first_hud.get("phase_menu_open")), "final whistle opens the result menu")
	var menu_button := first_hud.get("phase_menu_quit") as Button
	_check(menu_button != null and menu_button.text == "Main menu",
		"result menu offers a return to the main menu")
	first.call("_input", _key(KEY_ENTER))
	await _frames(4)

	menu = current_scene
	_check(menu != null and menu.name == "MainMenu", "the result menu returns to the main menu")
	_check(runtime.get_snapshot().is_empty(), "the finished match is stopped")
	_check(not runtime.get_snapshot().get("game_over", false), "no finished match is left behind")
	_check(get_nodes_in_group(RUNTIME_GROUP).size() == 1,
		"exactly one runtime node survives the scene change")
	_check(current_scene.get_node_or_null("Actors") == null, "match actors are gone with the scene")

	# Second match in the same process.
	await _press_start(menu)
	var second := current_scene
	_check(second != null and second.name == "GpfSlice", "the second match opens from the menu")
	if second == null or second.name != "GpfSlice":
		_finish()
		return
	_check(second != first, "a fresh match scene is built")
	_check(_runtime() == runtime, "the same C++ runtime serves both matches")
	var snap: Dictionary = runtime.get_snapshot()
	_check(not snap.is_empty(), "the second match has a snapshot")
	_check(int(snap.get("match_time_ms", -1)) == 0, "the second match starts with a clean clock")
	_check(int(snap.get("score0", -1)) == 0 and int(snap.get("score1", -1)) == 0,
		"the second match starts 0:0")
	_check(not bool(snap.get("paused", true)), "the second match is not paused")
	_check(not bool(snap.get("game_over", true)), "the second match is not game over")
	_check((runtime.get_player_ids() as Array).size() == baseline_players,
		"the second match spawns the same players (no duplication)")
	_check(int(runtime.debug_get_scene_object_count()) == baseline_objects,
		"the C++ scene has no leftovers from the first match")

	var second_actors := second.get_node("Actors")
	_check(int(second_actors.call("count")) == baseline_players,
		"the second match presents exactly one set of actors")
	_check((second_actors.get("player_labels") as Dictionary).size() == baseline_labels,
		"nameplates are rebuilt, not duplicated")
	var second_hud := second.get_node("Hud")
	_check(not bool(second_hud.get("phase_menu_open")), "the result menu is not left over")
	var second_replay := second.get_node("ReplayView")
	_check(not bool(second_replay.call("is_active")), "the replay is not left over")
	var nets: Array = second.get_node("GoalNets").get("goal_net_meshes")
	_check(nets.size() == 2, "the goal nets are rebuilt exactly once")
	var net_drawn := true
	for net in nets:
		var mesh_instance := net as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null \
				or mesh_instance.mesh.get_surface_count() == 0:
			net_drawn = false
	_check(net_drawn, "every goal net has geometry")

	# The second match must run its own pre-match, not jump into the first match's play.
	runtime.set("manual_step", true)
	var kickoff: Dictionary = {}
	for i in 100:
		runtime.step_fixed(5)
		var step_snap: Dictionary = runtime.get_snapshot()
		if bool(step_snap.get("in_set_piece", false)) \
				and int(step_snap.get("referee_set_piece", 0)) == 1:
			kickoff = step_snap
			break
	_check(not kickoff.is_empty(), "the second match reaches its own opening kickoff")
	_check(int(kickoff.get("match_time_ms", -1)) == 0,
		"the second match's clock is still clean at its kickoff")
	_check(int(kickoff.get("score0", -1)) == 0 and int(kickoff.get("score1", -1)) == 0,
		"the second match has no goals before its kickoff")
	_check(int(runtime.get_tick()) > 0, "the second match advances its own clock")

	# F4 stays the in-place restart path (same scene, fresh match).
	var tick_before := int(runtime.get_tick())
	second.call("_input", _key(KEY_F4))
	await process_frame
	_check(int(runtime.get_tick()) < tick_before, "F4 restarts the match in place")
	_check(int(runtime.debug_get_scene_object_count()) == baseline_objects,
		"F4 leaves no leftovers")
	_check(int(second_actors.call("count")) == baseline_players,
		"F4 rebuilds exactly one set of actors")

	# The shootout end menu has its own return-to-menu path.
	var shootout := second.get_node("ShootoutView")
	shootout.set("shootout_end_open", true)
	second.call("_input", _key(KEY_ESCAPE))
	await _frames(4)
	_check(current_scene != null and current_scene.name == "MainMenu",
		"the shootout end menu returns to the main menu")
	_check(runtime.get_snapshot().is_empty(), "the second match is stopped on the way out")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: gpf game shell")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
