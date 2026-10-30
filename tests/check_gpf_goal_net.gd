extends SceneTree
# Headless check for the C++ NetSim bridge: both goal nets are built with the
# original topology, are mirrored into scene space, and deform when the ball
# presses a side panel.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const NODE_COUNT := 1274
const EDGE_POINTS := 4796
const GOAL_HALF_WIDTH := 3.7
const GOAL_DEPTH := 2.55

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

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)

func _max_shift(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var shifted := 0.0
	for i in mini(a.size(), b.size()):
		shifted = maxf(shifted, a[i].distance_to(b[i]))
	return shifted

func _bounds(points: PackedVector3Array) -> Vector3:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in points:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	return hi - lo

func _run() -> void:
	var edges: PackedInt32Array = runtime.get_goal_net_edges()
	_check(edges.size() == EDGE_POINTS, "edge point count is %d" % EDGE_POINTS)
	var net0: PackedVector3Array = runtime.get_goal_net_positions(0)
	var net1: PackedVector3Array = runtime.get_goal_net_positions(1)
	_check(net0.size() == NODE_COUNT and net1.size() == NODE_COUNT, "both nets have %d nodes" % NODE_COUNT)
	var b0 := _bounds(net0)
	var b1 := _bounds(net1)
	_check(absf(b0.x - GOAL_DEPTH) < 0.01 and absf(b0.z - GOAL_HALF_WIDTH * 2.0) < 0.01, "goal 0 spans the box depth and width")
	_check(absf(b1.x - GOAL_DEPTH) < 0.01 and absf(b1.z - GOAL_HALF_WIDTH * 2.0) < 0.01, "goal 1 spans the box depth and width")
	_check(net0[0].x > 54.0 and net1[0].x < -54.0, "nets are mirrored onto the two goal lines")

	# Start live play, then hit the outer side panel of the +X goal so the ball
	# cannot score (and therefore cannot reset the net mid-test).
	runtime.start_open_play(1)
	runtime.step_fixed(60)
	var before: PackedVector3Array = runtime.get_goal_net_positions(1)
	runtime.debug_set_ball(Vector3(56.0, 3.9, 1.2), Vector3(0.0, -30.0, 0.0))
	runtime.step_fixed(20)
	var after: PackedVector3Array = runtime.get_goal_net_positions(1)
	_check(after.size() == before.size(), "net state survives the ball impact")
	_check(_max_shift(after, before) > 0.01, "ball impact deforms the side net")

	if failures.is_empty():
		print("CHECK PASS: goal net")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
