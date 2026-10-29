extends SceneTree
# Headless full-match test: AI vs AI, accelerated match clock, no presentation.
# Verifies phase transitions, side changes, score persistence and the final
# whistle pause from the original Referee/Match.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_full_match.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"

const PHASE_PRE_MATCH := 0
const PHASE_1ST_HALF := 1
const PHASE_2ND_HALF := 2
const PHASE_1ST_EXTRA := 3
const PHASE_2ND_EXTRA := 4
const PHASE_PENALTIES := 5

const FIRST_HALF_MS := 2700000
const SECOND_HALF_MS := 5400000
const FIRST_EXTRA_MS := 6300000
const SECOND_EXTRA_MS := 7200000

# A draw after 120:00 now plays the penalty shootout before the match ends, so leave headroom for
# the series (each kick is a short set piece + a short hold).
const MAX_TICKS := 200000

var failures: Array[String] = []
var runtime: Node
var max_ticks := MAX_TICKS
var log_every := 5000

func _init() -> void:
	var env_limit := OS.get_environment("GPF_FULL_MATCH_MAX_TICKS")
	if env_limit != "":
		max_ticks = int(env_limit)
	var env_log := OS.get_environment("GPF_FULL_MATCH_LOG_EVERY")
	if env_log != "":
		log_every = int(env_log)
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
		print("CHECK PASS: full match")
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

func _sides(snap: Dictionary) -> String:
	return "%s/%s" % [snap.get("team0_side", "?"), snap.get("team1_side", "?")]

func _brief(snap: Dictionary) -> String:
	var taker_id := int(snap.get("referee_taker", -1))
	var taker: Dictionary = runtime.get_player_pose(taker_id) if taker_id > 0 else {}
	return "tick=%s inplay=%s setpiece=%s sptype=%s desired=%s team=%s taker=%s taker_team=%s taker_pos=%s taker_fn=%s anim=%s retainer=%s paused=%s goal=%s score=%s:%s ball=%s sim=%s restart=%s" % [
		snap.get("tick"), snap.get("in_play"), snap.get("in_set_piece"),
		snap.get("set_piece_type"), snap.get("referee_set_piece"), snap.get("referee_team"), snap.get("referee_taker"),
		taker.get("team"), taker.get("pos"), taker.get("function"), taker.get("anim"),
		snap.get("ball_retainer"),
		snap.get("paused"), snap.get("goal_scored"), snap.get("score0"), snap.get("score1"),
		snap.get("ball_pos"), snap.get("ball_sim_pos"), snap.get("restart_pos"),
	]

func _run() -> void:
	var snap: Dictionary = runtime.get_snapshot()
	_check(int(snap.get("match_phase", -1)) == PHASE_PRE_MATCH, "new match starts in PRE-MATCH")
	_check(int(snap.get("team0_side", 0)) == -1 and int(snap.get("team1_side", 0)) == 1, "team_0 starts on the -X side")

	var phase_first: Dictionary = {}
	var phase_sides: Dictionary = {}
	var phase_kickoff: Dictionary = {}
	var last_phase := int(snap.get("match_phase", PHASE_PRE_MATCH))
	var last_score0 := int(snap.get("score0", 0))
	var last_score1 := int(snap.get("score1", 0))
	var guard := 0
	var game_over := false
	var next_log := log_every

	while guard < max_ticks and not game_over:
		runtime.step_fixed(100)
		guard += 100
		snap = runtime.get_snapshot()
		game_over = bool(snap.get("game_over", false))

		if guard >= next_log:
			print("progress ", _brief(snap))
			next_log += log_every


		var score0 := int(snap.get("score0", 0))
		var score1 := int(snap.get("score1", 0))
		if score0 < last_score0 or score1 < last_score1:
			_check(false, "score went backwards at tick %d: %d:%d" % [guard, score0, score1])
			break
		last_score0 = score0
		last_score1 = score1

		var phase := int(snap.get("match_phase", PHASE_PRE_MATCH))
		if phase != last_phase:
			print("phase ", last_phase, " -> ", phase,
				"  time=", _clock(int(snap.get("match_time_ms", 0))),
				"  score=", score0, ":", score1,
				"  sides=", _sides(snap),
				"  kickoff_team=", snap.get("referee_team", "?")
			)
			if not phase_first.has(phase):
				phase_first[phase] = int(snap.get("match_time_ms", 0))
				phase_sides[phase] = [int(snap.get("team0_side", 0)), int(snap.get("team1_side", 0))]
				phase_kickoff[phase] = [
					int(snap.get("referee_set_piece", 0)),
					int(snap.get("referee_team", -1)),
				]
			last_phase = phase

	if guard >= max_ticks:
		_check(false, "full match did not finish within %d ticks (phase=%d time=%s) %s" % [
			max_ticks, int(snap.get("match_phase", -1)), _clock(int(snap.get("match_time_ms", 0))), _brief(snap)
		])
	else:
		_check(true, "full match finished in %d ticks" % guard)

	_check(phase_first.has(PHASE_1ST_HALF), "first half started")
	_check(phase_first.has(PHASE_2ND_HALF), "second half started")
	_check(phase_first.has(PHASE_1ST_EXTRA), "extra time 1 started after 90:00")

	if phase_first.has(PHASE_1ST_HALF):
		_check(int(phase_first[PHASE_1ST_HALF]) < 1000, "first half clock starts near 00:00")
	if phase_first.has(PHASE_2ND_HALF):
		_check(int(phase_first[PHASE_2ND_HALF]) >= FIRST_HALF_MS, "second half starts at 45:00")
		_check(int(phase_first[PHASE_2ND_HALF]) < FIRST_HALF_MS + 500000, "second half starts soon after 45:00")
		_check(phase_sides[PHASE_2ND_HALF] == [1, -1], "sides swap for the second half")
		_check(phase_kickoff[PHASE_2ND_HALF] == [1, 1], "team_1 kicks off the second half")
	if phase_first.has(PHASE_1ST_EXTRA):
		_check(int(phase_first[PHASE_1ST_EXTRA]) >= SECOND_HALF_MS, "extra time 1 starts at 90:00")
		_check(int(phase_first[PHASE_1ST_EXTRA]) < SECOND_HALF_MS + 500000, "extra time 1 starts soon after 90:00")
		_check(phase_sides[PHASE_1ST_EXTRA] == [-1, 1], "sides swap back for extra time 1")
		_check(phase_kickoff[PHASE_1ST_EXTRA] == [1, 0], "team_0 kicks off extra time 1")

	if phase_first.has(PHASE_2ND_EXTRA):
		_check(int(phase_first[PHASE_2ND_EXTRA]) >= FIRST_EXTRA_MS, "extra time 2 starts at 105:00")
		_check(int(phase_first[PHASE_2ND_EXTRA]) < FIRST_EXTRA_MS + 500000, "extra time 2 starts soon after 105:00")
		_check(phase_sides[PHASE_2ND_EXTRA] == [1, -1], "sides swap for extra time 2")
		_check(phase_kickoff[PHASE_2ND_EXTRA] == [1, 1], "team_1 kicks off extra time 2")
	if phase_first.has(PHASE_PENALTIES):
		_check(int(phase_first[PHASE_PENALTIES]) >= SECOND_EXTRA_MS, "penalties phase starts at 120:00")
		_check(int(phase_first[PHASE_PENALTIES]) < SECOND_EXTRA_MS + 500000, "penalties phase starts soon after 120:00")

	_check(game_over, "match reaches game over")
	_check(bool(snap.get("paused", false)), "match is paused at the final whistle")
	var final_score0 := int(snap.get("score0", 0))
	var final_score1 := int(snap.get("score1", 0))
	print("final: phase=", snap.get("match_phase"), " clock=", _clock(int(snap.get("match_time_ms", 0))),
		" score=", final_score0, ":", final_score1, " sides=", _sides(snap))

	runtime.step_fixed(500)
	var after: Dictionary = runtime.get_snapshot()
	_check(bool(after.get("paused", false)), "match stays paused after the final whistle")
	_check(int(after.get("score0", 0)) == final_score0 and int(after.get("score1", 0)) == final_score1, "final score does not change after the whistle")
