extends SceneTree
# Headless check for the new side-select screen: the shared SideSelectView
# renders the prototype geometry, the keyboard row starts on home, Left/Right
# moves it through centre to away, a centre row cannot be confirmed, and ready
# commits the setup into ShellState.
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


func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event


func _tap(code: int) -> void:
	Input.parse_input_event(_key(code, true))
	await process_frame
	Input.parse_input_event(_key(code, false))
	await process_frame


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

	var view: Node = screen.get_node_or_null("SideSelectView")
	_check(view != null, "the shared side select view is present")
	if view == null:
		_finish()
		return
	_check(is_equal_approx(view.head_height(), 56.0), "the header is 56 px tall")
	_check(absf(view.body_height() - 691.2) < 0.01, "the body is 691.2 px tall")
	_check(is_equal_approx(view.device_size(), 112.0), "devices are 112 px")
	_check(is_equal_approx(view.edge_inset(), 260.0), "the device track is inset 260 px")

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
	var row_id := str(keyboard.get("id", ""))
	_check(is_equal_approx(view.row_device_x(row_id), 260.0),
		"home sits at the 260 px edge inset")
	_check(view.row_tone(row_id) == UiTokens.SIDE_TONES[0],
		"the first participant gets the first tone")
	_check(view.row_cue_visible(row_id, true) == false
		and view.row_cue_visible(row_id, false), "home shows only the right cue")

	var hotplug_devices: Array = [
		{"kind": "keyboard", "device": 0, "name": "Keyboard"},
		{"kind": "gamepad", "device": 0, "name": "Pad"},
	]
	screen.call("_sync_participants", hotplug_devices)
	await _frames(3)
	var hotplug_participants: Array = screen.get("participants")
	_check(hotplug_participants.size() == 2, "hot-plug adds the gamepad row")
	var pad: Dictionary = {}
	for participant in hotplug_participants:
		if str(participant.get("kind", "")) == "gamepad":
			pad = participant
			break
	_check(not pad.is_empty(), "the hot-plugged gamepad is listed")
	if not pad.is_empty():
		_check(int(pad.get("side", -9)) == 0, "a hot-plugged pad starts in the centre")
		_check(int(pad.get("tone_index", -1)) == 1, "the pad gets the next tone index")
		_check(absf(view.row_device_x("gamepad:0") - 684.0) < 0.5,
			"the hot-plugged pad appears at the centre")
		_check(view.row_tone("gamepad:0") == UiTokens.SIDE_TONES[1],
			"the hot-plugged pad uses the second tone")
		var keyboard_y: float = view.row_device_rect(row_id).position.y
		var pad_y: float = view.row_device_rect("gamepad:0").position.y
		_check(pad_y > keyboard_y, "the hot-plugged pad is below the keyboard")
		_check(pad_y - keyboard_y <= 150.0, "devices stack compactly")

	var second_wave: Array = hotplug_devices.duplicate()
	second_wave.append({"kind": "gamepad", "device": 1, "name": "Pad 2"})
	screen.call("_sync_participants", second_wave)
	await _frames(3)
	_check((screen.get("participants") as Array).size() == 3,
		"a second gamepad adds a third row")
	_check(view.row_device_rect("gamepad:0").position.y
		< view.row_device_rect("gamepad:1").position.y,
		"a later gamepad is placed below the earlier one")
	_check(view.row_tone("gamepad:1") == UiTokens.SIDE_TONES[2],
		"the second gamepad gets the third tone")

	screen.call("_sync_participants", [hotplug_devices[0]])
	await _frames(3)
	_check((screen.get("participants") as Array).size() == 1,
		"unplugging removes the gamepad rows")
	_check(view.row_device_x("gamepad:0") < 0.0, "the removed pad is gone from the view")
	_check(view.row_device_x("gamepad:1") < 0.0, "the second removed pad is gone")

	await _tap(KEY_RIGHT)
	await create_timer(0.4).timeout
	_check(int(keyboard.get("side", -9)) == 0, "Right moves home -> centre")
	_check(absf(view.row_device_x(row_id) - 684.0) < 0.5,
		"centre sits at the track midpoint")
	_check(view.row_cue_visible(row_id, true)
		and view.row_cue_visible(row_id, false), "centre shows both cues")

	await _tap(KEY_ENTER)
	_check(not bool(keyboard.get("ready", true)), "a centre row cannot be confirmed")
	var status := screen.get("status_label") as Label
	_check(status != null and status.text.contains("Choose a side"),
		"confirming the centre explains what is missing")

	await _tap(KEY_RIGHT)
	await create_timer(0.4).timeout
	_check(int(keyboard.get("side", -9)) == 1, "Right moves centre -> away")
	_check(absf(view.row_device_x(row_id) - 1108.0) < 0.5,
		"away sits at the opposite edge inset")
	_check(view.row_cue_visible(row_id, true)
		and not view.row_cue_visible(row_id, false), "away shows only the left cue")

	await _tap(KEY_ENTER)
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
