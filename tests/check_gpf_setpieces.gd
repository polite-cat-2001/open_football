extends SceneTree
# Headless smoke test for the of_port set-piece bridge: penalty as taker/keeper,
# set-piece camera and human selection. One scenario per process:
#   GPF_SCENARIO=taker|keeper|free|corner|goal
# Run: godot --headless --path . -s res://tests/check_gpf_setpieces.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"

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
	runtime.debug_force_set_piece(type, team)
	if scenario == "keeper":
		runtime.select_goalkeeper(0)

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
		_check(human_id == keeper, "human controls the defending goalkeeper")
		_check(int(snap.get("referee_taker", -1)) != keeper, "opponent takes the penalty")
		_check(int(snap.get("set_piece_role", 0)) == 2, "human has the keeper role")
	else:
		_check(human_id == int(snap.get("referee_taker", -2)), "human takes the set piece")
		_check(int(snap.get("set_piece_role", 0)) == 1, "human has the kicker role")
		if scenario == "taker":
			_check((snap.get("set_piece_aim_point", Vector3.ZERO) as Vector3).length() > 0.01, "penalty reticle aim is exposed")
	_check((snap.get("camera_pos", Vector3.ZERO) as Vector3).distance_to(before_camera) > 0.01, "set-piece camera moved")