extends SceneTree
# Headless smoke test for the original GameplayFootball match loop inside Godot.
# Runs one match and drives it through: kickoff -> goal -> restart kickoff ->
# throw-in -> goal kick -> corner. Uses debug_set_ball() to place the ball in
# the original C++ (raw) space: raw X = length, raw Y = width, raw Z = up.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_match_cycle.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"

const SET_PIECE_KICKOFF := 1
const SET_PIECE_GOAL_KICK := 2
const SET_PIECE_CORNER := 4
const SET_PIECE_THROW_IN := 5

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

	print("human=", runtime.get_human_player_id(), " ids=", (runtime.get_player_ids() as Array).size())
	_run()
	if failures.is_empty():
		print("CHECK PASS: match cycle")
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

func _step(ticks: int) -> Dictionary:
	runtime.step_fixed(ticks)
	return runtime.get_snapshot()

func _wait_for(predicate: Callable, max_ticks: int, label: String) -> Dictionary:
	var snap: Dictionary = runtime.get_snapshot()
	var guard := 0
	while guard < max_ticks and not bool(predicate.call(snap)):
		snap = _step(10)
		guard += 10
	if guard >= max_ticks:
		failures.append("timeout waiting for " + label)
		print("  FAIL: timeout waiting for ", label, " after ", max_ticks, " ticks; snap=", _brief(snap))
	return snap

func _brief(snap: Dictionary) -> String:
	return "tick=%s inplay=%s setpiece=%s desired=%s team=%s score=%s:%s paused=%s time=%s" % [
		snap.get("tick"), snap.get("in_play"), snap.get("in_set_piece"),
		snap.get("referee_set_piece"), snap.get("referee_team"),
		snap.get("score0"), snap.get("score1"), snap.get("paused"),
		snap.get("match_time_ms"),
	]

func _take_set_piece_with_human(snap: Dictionary) -> void:
	var taker := int(snap.get("referee_taker", -1))
	if taker > 0:
		runtime.select_player(taker)
	runtime.set_button(6, true)
	runtime.step_fixed(5)
	runtime.set_button(6, false)

func _run() -> void:
	var snap: Dictionary = runtime.get_snapshot()
	_check(int(snap.get("score0", -1)) == 0 and int(snap.get("score1", -1)) == 0, "new match starts 0:0")
	_check(int(snap.get("match_phase", -1)) == 0, "new match starts in PRE-MATCH")

	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and bool(s.get("in_set_piece", false)), 500, "opening kickoff")
	_check(int(snap.get("referee_set_piece", 0)) == SET_PIECE_KICKOFF, "opening set piece is KICKOFF")
	_check(int(snap.get("referee_team", -1)) == 0, "opening kickoff belongs to the human team")

	_take_set_piece_with_human(snap)
	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and not bool(s.get("in_set_piece", false)), 500, "kickoff taken")
	_check(int(snap.get("match_phase", -1)) == 1, "kickoff starts the 1ST HALF")
	var clock_before := int(snap.get("match_time_ms", 0))
	snap = _step(20)
	_check(int(snap.get("match_time_ms", 0)) > clock_before, "match clock advances during live play")

	# Goal into the team_1 (raw +X) goal; place it just outside the keeper's reach.
	var score_before := int(snap.get("score0", 0))
	runtime.debug_set_ball(Vector3(54.6, 3.4, 1.2), Vector3(8.0, 0.0, 0.0))
	snap = _wait_for(func(s): return int(s.get("score0", 0)) > score_before, 200, "goal for team_0")
	_check(int(snap.get("score0", 0)) == score_before + 1, "goal increments the team_0 score")
	_check(int(snap.get("score1", 0)) == 0, "goal does not change the opponent's score")
	_check(int(snap.get("last_goal_team", -1)) == 0, "last goal is credited to team_0")
	_check(bool(snap.get("goal_scored", false)), "goal flag is raised")
	_check(not bool(snap.get("paused", false)), "match does not freeze on the goal replay pause")

	# The conceding team (AI) takes the restart kickoff. Make sure the original
	# 6-second replay pause does not leave the match paused forever.
	snap = _wait_for(func(s): return bool(s.get("in_set_piece", false)) and int(s.get("referee_set_piece", 0)) == SET_PIECE_KICKOFF, 1600, "restart kickoff after goal")
	_check(not bool(snap.get("paused", false)), "restart kickoff is not stuck paused")
	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and not bool(s.get("in_set_piece", false)), 1600, "restart kickoff taken")
	_check(int(snap.get("score0", 0)) == score_before + 1 and int(snap.get("score1", 0)) == 0, "score survives the restart")
	var restart_tick := int(snap.get("tick", 0))

	# Throw-in: last touch is team_1 after its kickoff, so the ball over the
	# sideline gives a throw-in to the human team.
	runtime.debug_set_ball(Vector3(0.0, 35.9, 0.11), Vector3(0.0, 8.0, 0.0))
	snap = _wait_for(func(s): return int(s.get("referee_set_piece", 0)) == SET_PIECE_THROW_IN, 300, "throw-in decision")
	_check(int(snap.get("referee_team", -1)) == 0, "throw-in is awarded against the last-touch team")
	snap = _wait_for(func(s): return bool(s.get("in_set_piece", false)) and int(s.get("referee_set_piece", 0)) == SET_PIECE_THROW_IN, 700, "throw-in set piece")
	_check(int(snap.get("referee_taker", -1)) > 0, "throw-in has a taker")
	_take_set_piece_with_human(snap)
	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and not bool(s.get("in_set_piece", false)), 600, "throw-in taken")
	_check(int(snap.get("tick", 0)) > restart_tick, "match continues after the throw-in")

	# Goal kick: human team touched last, ball over team_1's backline, so the
	# AI keeper's team gets the goal kick.
	runtime.debug_set_ball(Vector3(54.0, 10.0, 0.11), Vector3(8.0, 0.0, 0.0))
	snap = _wait_for(func(s): return int(s.get("referee_set_piece", 0)) == SET_PIECE_GOAL_KICK, 300, "goal kick decision")
	_check(int(snap.get("referee_team", -1)) == 1, "goal kick goes to the defending team")
	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and not bool(s.get("in_set_piece", false)), 900, "goal kick taken")
	_check(int(snap.get("score0", 0)) == score_before + 1 and int(snap.get("score1", 0)) == 0, "score unchanged by the goal kick")

	# Corner: the AI team touched last at its goal kick, so the same cross of
	# the backline is now a corner for the human team.
	runtime.debug_set_ball(Vector3(54.0, 10.0, 0.11), Vector3(8.0, 0.0, 0.0))
	snap = _wait_for(func(s): return int(s.get("referee_set_piece", 0)) == SET_PIECE_CORNER, 300, "corner decision")
	_check(int(snap.get("referee_team", -1)) == 0, "corner goes to the attacking team")
	snap = _wait_for(func(s): return bool(s.get("in_set_piece", false)) and int(s.get("referee_set_piece", 0)) == SET_PIECE_CORNER, 700, "corner set piece")
	_check(int(snap.get("referee_taker", -1)) > 0, "corner has a taker")
	_take_set_piece_with_human(snap)
	snap = _wait_for(func(s): return bool(s.get("in_play", false)) and not bool(s.get("in_set_piece", false)), 600, "corner taken")
	_check(int(snap.get("score0", 0)) == score_before + 1 and int(snap.get("score1", 0)) == 0, "score unchanged by the corner")
	_check(not bool(snap.get("game_over", false)), "match is still running after the set-piece cycle")

