extends SceneTree
# Headless check: changing camera settings while a local match is paused republishes
# the presentation camera immediately, so the settings screen shows a live preview
# behind the pause overlay (the paused match otherwise stops updating the camera).
#
# Run:  godot --headless --path . -s res://tests/check_gpf_camera_pause.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

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

	runtime.step_fixed(60)
	var before: Dictionary = runtime.get_snapshot()
	runtime.pause_match()
	_check(bool(runtime.get_snapshot().get("paused", false)), "match is paused")

	runtime.set_camera_settings({"zoom": 0.95, "height": 0.95, "fov": 0.95, "angle": 0.95})
	var after: Dictionary = runtime.get_snapshot()

	_check(Vector3(after.get("camera_pos", Vector3.ZERO)) != Vector3(before.get("camera_pos", Vector3.ZERO))
		or not is_equal_approx(float(after.get("camera_fov", 0.0)), float(before.get("camera_fov", 0.0))),
		"camera republishes while paused")
	_check(bool(runtime.get_snapshot().get("paused", false)), "match stays paused")

	for failure in failures:
		print("CHECK FAIL: ", failure)
	print("CHECK PASS: paused camera preview" if failures.is_empty() else "CHECK FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("  FAIL: ", message)
	else:
		print("  ok: ", message)
