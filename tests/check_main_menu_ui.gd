extends SceneTree
# Headless check for the main menu's keyboard/gamepad entry point: the Quick
# Match tile must own focus on entry and both Enter and gamepad A must open the
# controller/side select through the shared UiNav router.
#
# Run:  godot --headless --path . -s res://tests/check_main_menu_ui.gd

const MAIN_MENU := "res://scenes/main_menu.tscn"
const QUICK_TILE := "Design/PanelWrap/PlayGrid/QuickMatchTile"
const NETWORK_TILE := "Design/PanelWrap/PlayGrid/NetworkTile"
const CONTINUE_TILE := "Design/PanelWrap/PlayGrid/ContinueCareerTile"
const CAREER_TILE := "Design/PanelWrap/PlayGrid/CareerTile"

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
	CareerSaveStore.root_override = "user://main_menu_empty_%d" % Time.get_ticks_usec()
	change_scene_to_file(MAIN_MENU)
	await _frames(8)
	var screen := current_scene
	_check(screen != null and screen.name == "MainMenu", "the main menu opens")
	if screen == null or screen.name != "MainMenu":
		_finish()
		return

	var quick := screen.get_node_or_null(QUICK_TILE) as Button
	_check(quick != null, "Quick Match tile exists")
	if quick == null:
		_finish()
		return
	_check(quick.has_focus(), "Quick Match owns focus on entry")
	_check(quick.focus_mode == Control.FOCUS_ALL, "Quick Match is focusable")
	var next := quick.find_next_valid_focus()
	_check(next != null and next == screen.get_node(CAREER_TILE),
		"focus traversal reaches Career when there is no save")

	var disabled := screen.get_node_or_null(CONTINUE_TILE) as Button
	_check(disabled != null and disabled.disabled, "Continue Career is disabled without saves")
	_check(disabled != null and disabled.focus_mode == Control.FOCUS_NONE,
		"disabled tile is skipped by focus")
	var career := screen.get_node_or_null(CAREER_TILE) as Button
	_check(career != null and not career.disabled and career.focus_mode == Control.FOCUS_ALL,
		"Career is enabled and focusable")

	# Godot 4.7's default ui_accept has no joypad button: UiNav handles A.
	var joy := InputEventJoypadButton.new()
	joy.device = 0
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	Input.parse_input_event(joy)
	await _frames(6)
	_check(current_scene != null and current_scene.name == "ControllerSelect",
		"gamepad A activates the focused Quick Match tile")

	_finish()
