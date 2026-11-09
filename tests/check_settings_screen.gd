extends SceneTree
# Headless check for the shared SettingsScreen + SettingsStore: category grid,
# slider persistence, keyboard rebinding and the C++ gameplay value mapping.

const SCREEN_SCENE := preload("res://scenes/ui/settings_screen.tscn")
const TEST_CONFIG := "user://check_settings_store.cfg"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


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
	SettingsStore.reset_for_tests()
	SettingsStore.config_path = TEST_CONFIG
	if FileAccess.file_exists(TEST_CONFIG):
		DirAccess.remove_absolute(TEST_CONFIG)

	var host := Control.new()
	root.add_child(host)
	host.size = Vector2(1480.0, 900.0)
	var screen: SettingsScreen = SCREEN_SCENE.instantiate()
	host.add_child(screen)
	screen.size = Vector2(1480.0, 900.0)
	await process_frame
	screen.open({})
	_check(screen.mode_name() == "menu", "settings opens on the category grid")

	# Gameplay: the first row is the short-pass direction assist.
	screen.handle_nav(Vector2i.DOWN)
	screen.handle_nav(Vector2i.UP)
	screen.handle_confirm()
	_check(screen.mode_name() == "gameplay", "Gameplay tile opens its sliders")
	var before := float(SettingsStore.gameplay()["shortpass_direction"])
	screen.handle_nav(Vector2i.RIGHT)
	var after := float(SettingsStore.gameplay()["shortpass_direction"])
	_check(after > before, "Right raises the focused slider")
	for i in 11:
		screen.handle_nav(Vector2i.DOWN)
	_check(screen.scroll_offset() > 0.0,
		"the one-column slider list scrolls to reach the last row")
	_check(str(screen.focused_row()["caption"].text).begins_with("8-WAY"),
		"the last gameplay row is reachable")
	screen.handle_cancel()
	_check(screen.mode_name() == "menu", "Esc returns to the grid")

	# Controls -> keyboard: rebind the walk-north key to K.
	screen.handle_nav(Vector2i.RIGHT)
	screen.handle_confirm()
	_check(screen.mode_name() == "controls", "Controls tile opens")
	screen.handle_confirm()
	_check(screen.mode_name() == "keyboard", "Keyboard opens the key list")
	screen.handle_confirm()
	_check(screen.is_capturing(), "Enter starts key capture")
	screen.handle_key(_key(KEY_K))
	_check(SettingsStore.key_for_function(0) == KEY_K, "the key binding is stored")
	_check(SettingsStore.functions_for_key(KEY_K).has(0),
		"the slice lookup maps the new key to walk north")

	# Gamepad defaults still map onto the C++ controller-button encoding.
	var buttons := SettingsStore.gamepad_buttons()
	_check(SettingsStore.controller_label(int(buttons[0])) == "A1-",
		"the left stick up default survives the encoding round trip")

	screen.close()
	_check(not screen.is_open(), "close hides the screen")
	_check(FileAccess.file_exists(TEST_CONFIG), "closing writes the config file")

	# Persistence: reload from disk and see the edited values again.
	SettingsStore.reset_for_tests()
	SettingsStore.config_path = TEST_CONFIG
	_check(SettingsStore.key_for_function(0) == KEY_K, "the key binding survives a reload")
	_check(absf(float(SettingsStore.gameplay()["shortpass_direction"]) - after) < 0.001,
		"the slider value survives a reload")

	var runtime_values := SettingsStore.gameplay_for_runtime()
	_check(is_equal_approx(float(runtime_values["gameplay_shot_curlspin"]),
		0.3 * SettingsStore.CURL_SPIN_MAX), "curl spin reaches C++ scaled 0..300")
	_check(is_equal_approx(float(runtime_values["gameplay_shot_curlaimout"]),
		0.3333 * SettingsStore.CURL_AIM_MAX), "curl aim reaches C++ in radians")

	DirAccess.remove_absolute(TEST_CONFIG)
	SettingsStore.reset_for_tests()

	print("== check_settings_screen: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)
