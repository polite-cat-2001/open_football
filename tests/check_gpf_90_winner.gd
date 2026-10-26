extends SceneTree
# Headless regression: a regular-time winner must end at 90:00, not play extra time.
# Forces a 2:1 lead at ~80:00 via debug_set_ball, then runs to the final whistle.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_90_winner.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"

const PHASE_PRE_MATCH := 0
const PHASE_1ST_HALF := 1
const PHASE_2ND_HALF := 2
const PHASE_1ST_EXTRA := 3
const PHASE_2ND_EXTRA := 4
const PHASE_PENALTIES := 5

const SECOND_HALF_MS := 5400000
const MAX_TICKS := 50000

var failures: Array[String] = []
var runtime: Node

func _init() -> void:
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("match_duration", 0.0)
	runtime.set("data_root", DATA_ROOT)
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime did not start: ", runtime.get_last_error())
		quit(1)
		return

	_run()
	if failures.is_empty():
		print("CHECK PASS: 90-minute winner")
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

func _clock(ms: int) -> String:
	var total := int(maxf(0.0, float(ms)) / 1000.0)
	return "%02d:%02d" % [total / 60, total % 60]

func _run() -> void:
	var snap: Dictionary = runtime.get_snapshot()
	var guard := 0
	var forced := false
	var score_before := 0
	var goal_time := 0

	while guard < MAX_TICKS:
		snap = runtime.get_snapshot()
		var phase := int(snap.get("match_phase", PHASE_PRE_MATCH))
		var time_ms := int(snap.get("match_time_ms", 0))
		var score0 := int(snap.get("score0", 0))
		var score1 := int(snap.get("score1", 0))

		if not forced and phase == PHASE_2ND_HALF and time_ms >= 4800000:
			score_before = score0 + score1
			print("forcing goal at ", _clock(time_ms), " score=", score0, ":", score1)
			runtime.debug_set_ball(Vector3(-54.6, 3.4, 1.2), Vector3(-40, 0, 0))
			runtime.debug_set_last_touch_team(0)
			forced = true

		if forced and score0 + score1 > score_before and goal_time == 0:
			goal_time = time_ms
			print("goal awarded at ", _clock(time_ms), " score=", score0, ":", score1)

		if bool(snap.get("game_over", false)):
			print("game over at ", _clock(time_ms), " phase=", phase, " score=", score0, ":", score1)
			_check(score0 > score1, "team_0 leads at full time")
			_check(phase == PHASE_2ND_HALF, "full time stays in the 2nd-half phase")
			_check(bool(snap.get("ended_in_regular_time", false)), "ended in regular time")
			_check(time_ms >= SECOND_HALF_MS, "full time is at/after 90:00")
			_check(time_ms < SECOND_HALF_MS + 60000, "full time is within 60s of 90:00, not 105:00")
			_check(phase != PHASE_2ND_EXTRA, "no 2nd extra time")
			_check(phase != PHASE_PENALTIES, "no penalty phase")
			_check(bool(snap.get("paused", false)), "match is paused at the final whistle")
			return

		runtime.step_fixed(100)
		guard += 100

	_check(false, "match did not reach game over within %d ticks" % MAX_TICKS)