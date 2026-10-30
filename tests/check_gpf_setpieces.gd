extends SceneTree
# Headless smoke test for the of_port set-piece bridge: penalty as taker/keeper,
# set-piece camera and human selection. One scenario per process:
#   GPF_SCENARIO=taker|keeper|free|corner|goal|throw|kickoff
# Run: godot --headless --path . -s res://tests/check_gpf_setpieces.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []
var runtime: Node
var scenario := "taker"

func _init() -> void:
	scenario = OS.get_environment("GPF_SCENARIO")
	if scenario == "":
		scenario = "taker"
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
		print("CHECK PASS: set pieces ", scenario)
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

func _find(ids: Array, role: String, team: int) -> int:
	for entry in ids:
		if int(entry.get("team", -9)) == team and String(entry.get("role", "")) == role:
			return int(entry.get("id", -1))
	return -1

func _step(n: int) -> Dictionary:
	runtime.step_fixed(n)
	return runtime.get_snapshot()

func _run() -> void:
	var ids: Array = runtime.get_player_ids()
	var outfield := _find(ids, "player", 0)
	var keeper := _find(ids, "goalkeeper", 0)
	_check(outfield >= 0, "human outfield exists")
	_check(keeper >= 0, "human goalkeeper exists")
	if outfield < 0 or keeper < 0:
		return
	runtime.start_open_play(outfield)
	var snap := _step(120)
	_check(bool(snap.get("in_play", false)), "open play starts")
	_check(int(snap.get("set_piece_type", -1)) == 0, "no set piece before forcing")

	var before_camera: Vector3 = snap.get("camera_pos", Vector3.ZERO)
	var type := 6
	var team := 0
	if scenario == "keeper":
		team = 1
	elif scenario == "free":
		type = 3
	elif scenario == "corner":
		type = 4
	elif scenario == "goal":
		type = 2
	elif scenario == "throw":
		type = 5
	elif scenario == "kickoff":
		type = 1
	runtime.debug_force_set_piece(type, team)

	var found := false
	for i in 500:
		snap = _step(10)
		if int(snap.get("referee_set_piece", -1)) == type and bool(snap.get("in_set_piece", false)):
			found = true
			break
	print("scenario=", scenario, " snap=", snap)
	_check(found, "set piece reached the live state")
	_check(int(snap.get("referee_set_piece", -1)) == type, "correct set-piece type")
	_check(int(snap.get("referee_team", -1)) == team, "correct set-piece team")
	var human_id := int(runtime.get_human_player_id())
	print("human_id=", human_id, " taker=", snap.get("referee_taker"), " keeper=", keeper)
	if scenario == "keeper":
		_check(int(runtime.get_human_team_id()) == 0, "human defends as team 0")
		_check(human_id != keeper, "keeper stays AI-controlled on penalty defense")
		_check(human_id >= 0, "human keeps an outfield selection")
		_check(int(snap.get("referee_taker", -1)) != keeper, "opponent takes the penalty")
		_check(int(snap.get("set_piece_role", 0)) == 0, "keeper is not selected as a set-piece role")
		_check(not bool(snap.get("set_piece_local_taker", true)), "defender has no taker menu")
		_check(not runtime.is_set_piece_taker_menu_available(), "defender cannot open taker menu")
		runtime.set_button(1, true)
		var dove := false
		for i in 600:
			_step(10)
			var keeper_pose: Dictionary = runtime.get_player_pose(keeper)
			if int(keeper_pose.get("function", -1)) == 9:
				dove = true
				break
		runtime.set_button(1, false)
		_check(dove, "keeper plays a dive/deflect after the taker's touch")
	elif scenario == "kickoff":
		_check(not bool(snap.get("set_piece_local_taker", true)), "kickoff has no taker menu hint")
		_check(not bool(snap.get("set_piece_taker_menu_available", true)), "kickoff has no taker menu")
		_check(not runtime.is_set_piece_taker_menu_available(), "kickoff cannot open the taker menu")
	else:
		_check(human_id == int(snap.get("referee_taker", -2)), "human takes the set piece")
		_check(int(snap.get("set_piece_role", 0)) == 1, "human has the kicker role")
		_check(bool(snap.get("set_piece_local_taker", false)), "local taker is exposed")
		if scenario == "taker":
			_check((snap.get("set_piece_aim_point", Vector3.ZERO) as Vector3).length() > 0.01, "penalty reticle aim is exposed")
		_test_taker_menu()
	if scenario != "throw" and scenario != "kickoff":
		_check((snap.get("camera_pos", Vector3.ZERO) as Vector3).distance_to(before_camera) > 0.01, "set-piece camera moved")

func _test_taker_menu() -> void:
	var menu_snap: Dictionary = runtime.get_snapshot()
	_check(bool(menu_snap.get("set_piece_taker_menu_available", false)), "taker menu is available")
	var candidates: Array = runtime.get_set_piece_taker_candidates()
	_check(candidates.size() > 1, "taker candidates are listed")
	var current := int(menu_snap.get("referee_taker", -1))
	var chosen := -1
	for entry in candidates:
		if int(entry.get("id", -1)) != current and String(entry.get("role", "")) != "goalkeeper":
			chosen = int(entry.get("id", -1))
			break
	_check(chosen >= 0, "another outfield taker exists")
	if chosen < 0:
		return
	_check(runtime.open_set_piece_taker_menu(), "taker menu opens")
	_check(runtime.is_set_piece_taker_menu_open(), "taker menu is open")
	runtime.request_set_piece_taker(chosen)
	runtime.close_set_piece_taker_menu()
	_check(not runtime.is_set_piece_taker_menu_open(), "taker menu closes")
	var after := _step(5)
	_check(int(after.get("referee_taker", -1)) == chosen, "chosen taker is applied")