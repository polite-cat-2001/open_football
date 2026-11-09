extends SceneTree
# Headless check for the in-match pause: the bridge freezes/unfreezes the C++
# match, and the pause menu emits continue / forfeit from keyboard and gamepad.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_pause.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/open_football_career/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 7633, 8590, {"duration": 0.0})
	if package.is_empty():
		print("CHECK FAIL: package")
		quit(1)
		return
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	runtime.set_match_package(package)
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime: ", runtime.get_last_error())
		quit(1)
		return
	_run()
	print("== check_gpf_pause: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _run() -> void:
	var before := int(runtime.get_tick())
	runtime.step_fixed(10)
	_check(int(runtime.get_tick()) > before, "ticks advance before pause")

	runtime.pause_match()
	_check(bool(runtime.get_snapshot().get("paused", false)), "pause_match pauses the match")
	var frozen := int(runtime.get_tick())
	runtime.step_fixed(10)
	_check(int(runtime.get_tick()) == frozen, "ticks stop while paused")

	runtime.resume_match()
	_check(not bool(runtime.get_snapshot().get("paused", true)), "resume_match unpauses")
	runtime.step_fixed(10)
	_check(int(runtime.get_tick()) > frozen, "ticks continue after resume")

	var menu := GpfPauseMenu.new()
	get_root().add_child(menu)
	menu.setup()
	var resumed := [false]
	var forfeited := [false]
	menu.resume_requested.connect(func(): resumed[0] = true)
	menu.forfeit_requested.connect(func(): forfeited[0] = true)

	menu.open()
	_check(menu.is_open(), "the pause menu opens")
	_check(menu.handle_key(_key(KEY_ENTER)), "Enter is handled by the menu")
	_check(resumed[0] and not menu.is_open(), "Continue resumes and closes the menu")

	menu.open()
	for i in 8:
		menu.handle_key(_key(KEY_DOWN))
	menu.handle_key(_key(KEY_ENTER))
	_check(menu.confirm_open, "forfeit asks for confirmation")
	menu.handle_key(_key(KEY_ENTER))
	_check(forfeited[0], "confirming forfeit emits forfeit_requested")

	menu.open()
	menu.handle_joy(_joy(JOY_BUTTON_B))
	_check(not menu.is_open(), "gamepad B closes the menu")


func _joy(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event
