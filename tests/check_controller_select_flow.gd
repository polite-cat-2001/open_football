extends SceneTree
# Regression check: an already chosen pair must not skip Team Select after the
# side/controller screen. The flow is always Controller Select -> Team Select.

const CONTROLLER_SELECT := "res://scenes/controller_select.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for count_index in count:
		await process_frame


func _tap(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _run() -> void:
	ShellState.clear()
	ShellState.set_teams({"id": 4, "name": "Home"}, {"id": 5, "name": "Away"})
	change_scene_to_file(CONTROLLER_SELECT)
	await _frames(8)
	_check(current_scene != null and current_scene.name == "ControllerSelect",
		"the controller screen opens")
	await _tap(KEY_ENTER)
	await _frames(10)
	_check(current_scene != null and current_scene.name == "TeamSelect",
		"a committed side selection opens Team Select even with teams picked")
	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: controller select flow")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
