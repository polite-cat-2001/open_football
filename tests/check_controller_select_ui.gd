extends SceneTree
# Headless check for the original-style controller/side select screen: the
# keyboard row starts on home, Left/Right moves it through centre to away, a
# centre row cannot be confirmed, and ready commits the setup into ShellState.
#
# Run:  godot --headless --path . -s res://tests/check_controller_select_ui.gd

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
	for i in count:
		await process_frame


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _run() -> void:
	ShellState.clear()
	change_scene_to_file(CONTROLLER_SELECT)
	await _frames(6)
	var screen := current_scene
	_check(screen != null and screen.name == "ControllerSelect",
		"the controller select screen opens")
	if screen == null or screen.name != "ControllerSelect":
		_finish()
		return

	var participants: Array = screen.get("participants")
	_check(participants.size() >= 1, "the screen lists the connected devices")
	var keyboard: Dictionary = {}
	for participant in participants:
		if str(participant.get("kind", "")) == "keyboard":
			keyboard = participant
			break
	_check(not keyboard.is_empty(), "the keyboard is always listed")
	if keyboard.is_empty():
		_finish()
		return
	_check(int(keyboard.get("side", 0)) == -1, "a lone keyboard starts on home")

	screen.call("_input", _key(KEY_RIGHT))
	await _frames(1)
	_check(int(keyboard.get("side", -9)) == 0, "Right moves home -> centre")

	screen.call("_input", _key(KEY_ENTER))
	await _frames(1)
	_check(not bool(keyboard.get("ready", true)), "a centre row cannot be confirmed")
	var status := screen.get("status_label") as Label
	_check(status != null and status.text.contains("Choose a side"),
		"confirming the centre explains what is missing")

	screen.call("_input", _key(KEY_RIGHT))
	await _frames(1)
	_check(int(keyboard.get("side", -9)) == 1, "Right moves centre -> away")

	screen.call("_input", _key(KEY_ENTER))
	await _frames(8)
	_check(bool(keyboard.get("ready", false)), "Enter marks the row ready")
	_check(ShellState.controllers_configured, "the confirmed setup is marked configured")
	_check(ShellState.controllers.size() == 1
		and str(ShellState.controllers[0].get("side", "")) == "away"
		and str(ShellState.controllers[0].get("kind", "")) == "keyboard",
		"the away-side keyboard setup reaches the shell state")
	_check(current_scene != null and current_scene.name == "TeamSelect",
		"a committed side selection opens team select")

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: controller select UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
