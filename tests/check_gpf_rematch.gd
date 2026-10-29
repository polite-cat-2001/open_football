extends SceneTree
# Headless check for starting a second match in the same process.
# Plays the first match for a while (and scores a goal so its score/clock are
# dirty), stops it, then starts a fresh match and verifies time, score, tick and
# the scene contents all start from scratch.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_rematch.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"

var failures: Array[String] = []
var runtime: Node

func _init() -> void:
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("data_root", DATA_ROOT)
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime did not start: ", runtime.get_last_error())
		quit(1)
		return

	_run()
	if failures.is_empty():
		print("CHECK PASS: second match in one process")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("  FAIL: ", message)
	else:
		print("  ok: ", message)

func _brief(snap: Dictionary) -> String:
	return "tick=%s inplay=%s setpiece=%s score=%s:%s paused=%s time=%s phase=%s" % [
		snap.get("tick"), snap.get("in_play"), snap.get("in_set_piece"),
		snap.get("score0"), snap.get("score1"), snap.get("paused"),
		snap.get("match_time_ms"), snap.get("match_phase"),
	]

func _wait_for(predicate: Callable, max_ticks: int, label: String) -> Dictionary:
	var snap: Dictionary = runtime.get_snapshot()
	var guard := 0
	while guard < max_ticks and not bool(predicate.call(snap)):
		runtime.step_fixed(10)
		snap = runtime.get_snapshot()
		guard += 10
	if guard >= max_ticks:
		failures.append("timeout waiting for " + label)
		print("  FAIL: timeout waiting for ", label, " after ", max_ticks, " ticks; snap=", _brief(snap))
	return snap

func _player_ids_unique() -> bool:
	var seen := {}
	for entry in runtime.get_player_ids():
		var id := int(entry.get("id", -1))
		if seen.has(id):
			return false
		seen[id] = true
	return true

func _run() -> void:
	var baseline_objects := int(runtime.debug_get_scene_object_count())
	var baseline_players := (runtime.get_player_ids() as Array).size()
	var baseline_net := (runtime.get_goal_net_positions(0) as PackedVector3Array).size()
	_check(baseline_objects > 0, "first match populates the scene")
	_check(baseline_players > 0, "first match spawns players")
	_check(baseline_net > 0, "first match builds the goal net")
	_check(_player_ids_unique(), "first match player ids are unique")

	# Play the first match until the opening kickoff is actually taken, then
	# score so the scoreboard and clock are no longer pristine.
	var snap := _wait_for(func(s): return bool(s.get("in_play", false)) and bool(s.get("in_set_piece", false)), 500, "opening kickoff")
	var taker := int(snap.get("referee_taker", -1))
	if taker > 0:
		runtime.select_player(taker)
	runtime.set_button(6, true)
	runtime.step_fixed(5)
	runtime.set_button(6, false)
	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and not bool(s.get("in_set_piece", false)), 500, "kickoff taken")
	runtime.step_fixed(30)

	runtime.debug_set_ball(Vector3(54.6, 3.4, 1.2), Vector3(8.0, 0.0, 0.0))
	snap = _wait_for(func(s): return int(s.get("score0", 0)) > 0, 300, "first match goal")

	_check(int(snap.get("tick", 0)) > 0, "first match advanced its tick")
	_check(int(snap.get("match_time_ms", 0)) > 0, "first match advanced its clock")
	_check(int(snap.get("score0", 0)) > 0, "first match score is dirty")
	var dirty_objects := int(runtime.debug_get_scene_object_count())
	var dirty_players := (runtime.get_player_ids() as Array).size()

	# The real second-match path starts after the final whistle.
	runtime.debug_force_game_over()
	snap = runtime.get_snapshot()
	_check(bool(snap.get("game_over", false)), "first match reaches game over")
	_check(bool(snap.get("paused", false)), "first match is paused at game over")

	# Stop and start a second match.
	_check(runtime.restart_match(), "restart_match succeeds")
	_check(runtime.is_runtime_ready(), "runtime stays ready after the restart")
	snap = runtime.get_snapshot()
	_check(not snap.is_empty(), "second match has a snapshot")
	_check(int(snap.get("tick", -1)) == 0, "second match starts at tick 0")
	_check(int(snap.get("match_time_ms", -1)) == 0, "second match starts with a clean clock")
	_check(int(snap.get("score0", -1)) == 0 and int(snap.get("score1", -1)) == 0, "second match starts 0:0")
	_check(int(snap.get("match_phase", -1)) == 0, "second match starts in PRE-MATCH")
	_check(not bool(snap.get("game_over", true)), "second match is not game over")
	_check(not bool(snap.get("paused", true)), "second match is not paused")
	_check(_player_ids_unique(), "second match player ids are unique")
	_check((runtime.get_player_ids() as Array).size() == baseline_players,
		"second match spawns the same number of players (no duplication)")
	_check(int(runtime.debug_get_scene_object_count()) == baseline_objects,
		"second match scene object count matches the first match (no leftovers)")
	_check((runtime.get_goal_net_positions(0) as PackedVector3Array).size() == baseline_net,
		"second match rebuilds the goal net exactly once")

	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and bool(s.get("in_set_piece", false)), 500, "second opening kickoff")
	_check(int(snap.get("referee_set_piece", 0)) == 1, "second match opening set piece is KICKOFF")
	runtime.step_fixed(30)
	snap = runtime.get_snapshot()
	_check(int(snap.get("tick", 0)) > 0, "second match runs its own clock")

	# Repeated stop must be safe, and a stopped runtime must be restartable.
	runtime.stop_match()
	runtime.stop_match()
	_check(runtime.is_runtime_ready(), "runtime survives a repeated stop")
	_check(runtime.get_snapshot().is_empty(), "no match snapshot while stopped")
	_check(runtime.get_tick() == 0, "stopped runtime reports tick 0")
	_check(runtime.start_match(), "start_match works after a stop")
	snap = runtime.get_snapshot()
	_check(int(snap.get("tick", -1)) == 0 and int(snap.get("score0", -1)) == 0,
		"match after stop is clean")
	_check(int(runtime.debug_get_scene_object_count()) == baseline_objects,
		"scene has no leftovers after stop + start")
	runtime.step_fixed(20)
	_check(runtime.get_tick() > 0, "match after stop advances again")

	# And the convenience path can restart a third time.
	_check(runtime.restart_match(), "third restart succeeds")
	snap = runtime.get_snapshot()
	_check(int(snap.get("tick", -1)) == 0, "third match starts at tick 0")
	_check(int(runtime.debug_get_scene_object_count()) == baseline_objects,
		"third match scene object count still matches")
	_check(dirty_players == baseline_players and dirty_objects == baseline_objects,
		"first match did not leave permanent scene growth")
