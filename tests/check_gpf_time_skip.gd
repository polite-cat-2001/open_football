extends SceneTree
# Headless check for the F5 time skip: the bridge pushes the clock to the end of
# the current period and the referee blows its own whistle, so the period break
# latches for the next phase.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_time_skip.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

const FIRST_HALF_END := 2700000
const REGULATION_END := 5400000

var runtime: Node
var failures: Array[String] = []


func _init() -> void:
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", true)
	runtime.set("data_root", DATA_ROOT)
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8)
	if package.is_empty():
		print("CHECK FAIL: match package could not be built")
		quit(1)
		return
	if not runtime.set_match_package(package):
		print("CHECK FAIL: match package rejected: ", runtime.get_last_error())
		quit(1)
		return
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime did not start: ", runtime.get_last_error())
		quit(1)
		return
	_run()
	if failures.is_empty():
		print("CHECK PASS: gpf time skip")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)


func _run() -> void:
	# The opening kickoff is a set piece: the skip must ignore it.
	var snap := _step(5)
	_check(not bool(runtime.debug_skip_to_period_end()),
		"the skip is ignored during the kickoff set piece")

	var ids: Array = runtime.get_player_ids()
	var outfield := _find(ids, "player", 0)
	_check(outfield >= 0, "human outfield exists")
	if outfield < 0:
		return
	runtime.start_open_play(outfield)
	snap = _step(120)
	_check(bool(snap.get("in_play", false)), "open play starts")
	_check(int(snap.get("match_phase", -1)) == 1, "the match is in the first half")
	_check(int(snap.get("match_time_ms", -1)) < FIRST_HALF_END,
		"the clock is inside the first half")

	_check(bool(runtime.debug_skip_to_period_end()), "the skip is accepted in open play")
	snap = _step(2)
	_check(int(snap.get("match_phase", -1)) == 2, "the skip ends the first half")
	_check(int(snap.get("match_time_ms", -1)) == FIRST_HALF_END, "the clock reads 45:00")
	_check(not bool(snap.get("in_play", true)), "the referee stopped play at the whistle")

	snap = _step(400)
	_check(bool(snap.get("phase_break_pending", false)), "the half-time break latches")
	_check(int(snap.get("phase_break_next_phase", -1)) == 2,
		"the break starts the second half")
	_check(bool(runtime.begin_phase_break()), "the break pauses the match")
	_check(not bool(runtime.debug_skip_to_period_end()),
		"a paused break is not skipped")
	runtime.continue_after_phase_break()
	_check(not bool(runtime.get_snapshot().get("paused", true)), "the break resumes")

	snap = _wait_in_play(3000)
	_check(bool(snap.get("in_play", false)), "the second-half kickoff starts")
	_check(int(snap.get("match_phase", -1)) == 2, "the match is in the second half")

	_check(bool(runtime.debug_skip_to_period_end()), "the 90:00 skip is accepted")
	snap = _step(2)
	_check(int(snap.get("match_phase", -1)) == 3, "the skip ends regulation time")
	_check(int(snap.get("match_time_ms", -1)) == REGULATION_END, "the clock reads 90:00")
	_check(not bool(snap.get("in_play", true)), "the referee stopped play at 90:00")

	snap = _step(400)
	# With a decisive score the bridge ends the match right there; with a draw the
	# extra-time break latches (the choice screen's own state).
	var ended := bool(snap.get("game_over", false))
	var breaking := bool(snap.get("phase_break_pending", false)) \
		and int(snap.get("phase_break_next_phase", -1)) == 3
	_check(ended or breaking, "90:00 either ends the match or latches extra time")


func _step(count: int) -> Dictionary:
	runtime.step_fixed(count)
	return runtime.get_snapshot()


func _wait_in_play(max_ticks: int) -> Dictionary:
	var snap: Dictionary = runtime.get_snapshot()
	var waited := 0
	while waited < max_ticks:
		if bool(snap.get("in_play", false)) and not bool(snap.get("in_set_piece", false)):
			return snap
		runtime.step_fixed(5)
		waited += 5
		snap = runtime.get_snapshot()
	return snap


func _find(ids: Array, role: String, team: int) -> int:
	for entry in ids:
		if int(entry.get("team", -9)) == team and String(entry.get("role", "")) == role:
			return int(entry.get("id", -1))
	return -1


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)
