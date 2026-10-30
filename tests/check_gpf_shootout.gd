extends SceneTree
# Headless shootout flow: F3 entry, alternating kicks, forced outcomes, early stop and winner.
# Run: godot --headless --path . -s res://tests/check_gpf_shootout.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

const PHASE_SETUP := 1
const PHASE_AIM := 2
const PHASE_OUTCOME := 3
const PHASE_HOLD := 4
const PHASE_CELEBRATION := 5
const PHASE_FINISHED := 6
const PHASE_TRANSITION := 7

var failures: Array[String] = []
var runtime: Node

func _init() -> void:
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", true)
	runtime.set("match_duration", 0.0)
	runtime.set("data_root", DATA_ROOT)
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8, {"duration": 0.0})
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
		print("CHECK PASS: gpf shootout")
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

func _step(n: int) -> Dictionary:
	runtime.step_fixed(n)
	return runtime.get_snapshot()

func _find(ids: Array, role: String, team: int) -> int:
	for entry in ids:
		if int(entry.get("team", -9)) == team and String(entry.get("role", "")) == role:
			return int(entry.get("id", -1))
	return -1

func _wait_phase(target: int, max_ticks: int) -> Dictionary:
	var snap: Dictionary = runtime.get_snapshot()
	var waited := 0
	while waited < max_ticks:
		if int(snap.get("shootout_phase", -1)) == target:
			return snap
		runtime.step_fixed(5)
		waited += 5
		snap = runtime.get_snapshot()
	return snap

func _run() -> void:
	var ids: Array = runtime.get_player_ids()
	var outfield := _find(ids, "player", 0)
	_check(outfield >= 0, "human outfield exists")
	if outfield < 0:
		return
	runtime.start_open_play(outfield)
	var snap := _step(120)
	_check(bool(snap.get("in_play", false)), "open play starts")

	runtime.debug_force_shootout()
	snap = _step(5)
	_check(bool(snap.get("shootout_active", false)), "F3 starts the shootout")
	_check(int(snap.get("match_phase", -1)) == 5, "match phase reads PENALTIES")
	var first_phase := int(snap.get("shootout_phase", -1))
	_check(first_phase == PHASE_TRANSITION or first_phase == PHASE_SETUP,
		"first kick fades in before it is set up")
	_check(not bool(snap.get("game_over", false)), "match not over during the series")

	var goal_x := float(snap.get("shootout_goal_x", 0.0))
	_check(absf(goal_x) > 50.0, "a goal is chosen for the series")
	var goal_sign := 1.0 if goal_x > 0.0 else -1.0

	# Kick 1: read the coin toss winner, then alternate: that team scores, the other misses.
	snap = _wait_phase(PHASE_AIM, 800)
	_check(int(snap.get("shootout_phase", -1)) == PHASE_AIM, "first kick goes live")
	var first_team := int(snap.get("shootout_taker_team", -1))
	_check(first_team == 0 or first_team == 1, "first taker team is valid")

	var keeper_id := _find(ids, "goalkeeper", 0)
	_check(keeper_id >= 0, "human goalkeeper exists")
	var keeper_dive_checked := false
	var keeper_dive_pending := false
	var sad_checked := false
	var takers: Array[int] = []
	for kick in 6:
		snap = _wait_phase(PHASE_AIM, 800)
		if int(snap.get("shootout_phase", -1)) != PHASE_AIM:
			_check(false, "kick %d reaches the aim phase" % (kick + 1))
			return
		var taker_team := int(snap.get("shootout_taker_team", -1))
		takers.append(taker_team)
		if kick > 0:
			_check(takers[kick] != takers[kick - 1], "kick %d alternates teams" % (kick + 1))

		# Our kick is taken by the human: hold the shot button briefly and release.
		if taker_team == 0:
			runtime.set_button(7, true)
			runtime.step_fixed(25)
			runtime.set_button(7, false)
		elif not keeper_dive_checked:
			# First opponent kick: the human must control an outfielder (never the keeper), and the
			# AI keeper must dive on the strike. Hold a dive side through the shot.
			keeper_dive_checked = true
			keeper_dive_pending = true
			var human_id := int(runtime.get_human_player_id())
			print("  info: opponent kick %d, human_id=%d keeper_id=%d taker_team=%d" % [
				kick + 1, human_id, keeper_id, taker_team])
			_check(human_id != keeper_id, "human never controls the keeper on an opponent kick")
			_check(human_id >= 0, "human holds an outfield selection on an opponent kick")
			runtime.set_button(1, true)

		snap = _wait_phase(PHASE_OUTCOME, 800)
		if int(snap.get("shootout_phase", -1)) != PHASE_OUTCOME:
			_check(false, "kick %d is struck" % (kick + 1))
			return

		# Resolve before the keeper can: the scoring team's kicks go in, the other's go out.
		var score_it: bool = (taker_team == first_team)
		if score_it:
			runtime.debug_set_ball(Vector3(goal_x + goal_sign, 0.0, 0.5), Vector3.ZERO)
		else:
			runtime.debug_set_ball(Vector3(0.0, 40.0, 0.5), Vector3.ZERO)
		snap = _step(15)

		if keeper_dive_pending:
			keeper_dive_pending = false
			# The committed dive plays its deflect clip for ~0.9 s, so it is still visible during
			# the outcome hold.
			var dove := false
			for i in 30:
				var keeper_pose: Dictionary = runtime.get_player_pose(keeper_id)
				if int(keeper_pose.get("function", -1)) == 9:
					dove = true
					break
				runtime.step_fixed(5)
			runtime.set_button(1, false)
			_check(dove, "defending keeper dives on the shot")

		if not score_it and not sad_checked:
			sad_checked = true
			var kicker_id := int(snap.get("referee_taker", -1))
			var sad := false
			for i in 20:
				var kicker_pose: Dictionary = runtime.get_player_pose(kicker_id)
				if String(kicker_pose.get("anim", "")).contains("sad_normal"):
					sad = true
					break
				runtime.step_fixed(5)
			_check(sad, "missed kicker plays sad_normal")

		# The first team scores on every one of its kicks (1, 1, 2, 2, 3, 3 after each kick),
		# the other team never scores: 3:0 after three pairs.
		var expected_first := (kick + 2) / 2
		var score_first := int(snap.get("shootout_score0", 0)) if first_team == 0 else int(snap.get("shootout_score1", 0))
		var score_other := int(snap.get("shootout_score0", 0)) if first_team != 0 else int(snap.get("shootout_score1", 0))
		_check(score_first == expected_first, "kick %d series score updated" % (kick + 1))
		_check(score_other == 0, "kick %d opponent has not scored" % (kick + 1))

	# After 3 scored and 3 missed kicks the series is mathematically decided.
	snap = _wait_phase(PHASE_CELEBRATION, 400)
	_check(int(snap.get("shootout_phase", -1)) == PHASE_CELEBRATION, "decisive outcome celebrates")
	_check(int(snap.get("shootout_winner", -1)) == first_team, "the scoring team wins")
	_check(bool(snap.get("shootout_decisive", false)), "decisive flag is set")
	_check(int(snap.get("shootout_outcome_counter", 0)) == 6, "six outcomes recorded")
	_check(int(snap.get("score0", -1)) == 0 and int(snap.get("score1", -1)) == 0,
		"match score is not touched by shootout goals")
	_check(not bool(snap.get("game_over", false)), "match stays live for the presentation")

	snap = _wait_phase(PHASE_FINISHED, 800)
	_check(int(snap.get("shootout_phase", -1)) == PHASE_FINISHED, "series reaches FINISHED")
	_check(int(snap.get("shootout_winner", -2)) == first_team, "winner survives the celebration")
	_check(bool(snap.get("game_over", false)), "the series ends the match")
	_check(not bool(snap.get("replay_moment", true)), "extended replay never fires in the series")

	var kicks0: Array = snap.get("shootout_kicks0", [])
	var kicks1: Array = snap.get("shootout_kicks1", [])
	_check(kicks1.size() >= 3 and kicks0.size() >= 3, "kick results are exposed for the HUD circles")
