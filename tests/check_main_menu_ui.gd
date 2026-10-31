extends SceneTree
# Headless check for the main menu's keyboard/gamepad entry point: a control
# must own focus on entry, otherwise arrows and ui_accept do nothing.
#
# Run:  godot --headless --path . -s res://tests/check_main_menu_ui.gd

const MAIN_MENU := "res://scenes/main_menu.tscn"

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


func _finish() -> void:
	print("== check_main_menu_ui: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	change_scene_to_file(MAIN_MENU)
	await _frames(6)
	var screen := current_scene
	_check(screen != null and screen.name == "MainMenu", "the main menu opens")
	if screen == null or screen.name != "MainMenu":
		_finish()
		return

	var start_button := screen.get_node_or_null("StartBtn") as Button
	_check(start_button != null, "Start Match exists")
	if start_button == null:
		_finish()
		return
	_check(start_button.has_focus(), "Start Match owns focus on entry")
	_check(start_button.focus_mode == Control.FOCUS_ALL, "Start Match is focusable")
	var next := start_button.find_next_valid_focus()
	_check(next != null and next != start_button, "focus traversal has a next control")
	_check((screen.get_node("SelectTeamsBtn") as Button).focus_mode == Control.FOCUS_ALL,
		"Select Teams is focusable")

	# Godot 4.7's default ui_accept has no joypad button: A must be handled by
	# the screen itself or the pad cannot leave the main menu.
	var joy := InputEventJoypadButton.new()
	joy.device = 0
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	Input.parse_input_event(joy)
	await _frames(4)
	_check(current_scene != null and current_scene.name == "ControllerSelect",
		"gamepad A activates the focused Start Match")

	_finish()
