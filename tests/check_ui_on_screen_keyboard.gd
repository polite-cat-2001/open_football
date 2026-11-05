extends SceneTree
# Headless check for the shared on-screen keyboard: rows/actions, filtering,
# physical typing, UiNav navigation, modal ownership and Apply/close.
#
# Run:  godot --headless --path . -s res://tests/check_ui_on_screen_keyboard.gd

const OSK_SCENE := preload("res://scenes/ui/ui_on_screen_keyboard.tscn")

var failures: Array[String] = []
var host: Control
var osk: UiOnScreenKeyboard
var applied_text := ""
var closed_count := 0
var ui_nav: Node


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


func _tap_key(code: int, unicode := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(1)


func _run() -> void:
	host = Control.new()
	host.name = "OskHost"
	host.add_to_group(&"ui_shell")
	host.size = Vector2(1920, 1080)
	host.theme = UiTheme.load_or_build()
	ui_nav = root.get_node_or_null("UiNav")
	_check(ui_nav != null, "the UiNav autoload is present")
	root.add_child(host)
	osk = OSK_SCENE.instantiate()
	host.add_child(osk)
	osk.applied.connect(func(text: String): applied_text = text)
	osk.closed.connect(func(): closed_count += 1)
	await _frames(4)

	_check(not osk.is_open(), "the keyboard starts closed")
	_check(osk.key_button(0, 0) != null and osk.key_button(0, 0).text == "Q",
		"the first QWERTY key is Q")
	_check(osk.key_button(3, 0) != null and osk.key_button(3, 0).text == "1",
		"the service row starts with digits")
	_check(osk.action_button(0).text == "SPACE" and osk.action_button(3).text == "APPLY",
		"the action column is SPACE/DEL/CLEAR/APPLY")

	osk.open("NAME", "Ab", NetworkValidation.NAME_MAX, NetworkValidation.NAME_CHARS)
	await _frames(3)
	_check(osk.is_open() and osk.visible, "open shows the keyboard")
	_check(ui_nav.is_modal() and ui_nav.modal_owner() == osk, "the keyboard owns the modal")
	_check(osk.key_button(0, 0).has_focus(), "first focus lands on Q")
	_check(osk.display_text() == "Ab", "the display mirrors the field text")

	osk.press_character("c")
	_check(osk.current_text() == "Abc", "pressing a key appends a character")
	osk.press_character("!")
	_check(osk.current_text() == "Abc", "the name filter rejects punctuation")
	osk.press_backspace()
	_check(osk.current_text() == "Ab", "backspace removes the last character")
	osk.press_clear()
	_check(osk.current_text() == "", "clear empties the text")
	_check(osk.display_text() == "\u2014", "the empty display shows a dash")

	osk.close(false)
	await _frames(2)
	_check(closed_count == 1 and not osk.is_open(), "close emits closed")
	_check(not ui_nav.is_modal(), "closing releases the modal")

	osk.open("PORT", "", 5, NetworkValidation.PORT_CHARS)
	await _frames(2)
	osk.press_character("a")
	osk.press_character("1")
	osk.press_character("2")
	osk.press_character("3")
	osk.press_character("4")
	osk.press_character("5")
	osk.press_character("6")
	_check(osk.current_text() == "12345", "port filtering keeps digits and caps at 5")
	osk.press_apply()
	await _frames(2)
	_check(applied_text == "12345" and not osk.is_open(), "Apply returns the text and closes")
	_check(not ui_nav.is_modal(), "Apply releases the modal")

	osk.open("NAME", "Q", NetworkValidation.NAME_MAX, NetworkValidation.NAME_CHARS)
	await _frames(2)
	osk.focus_key(0, 1)
	ui_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(osk.row_index() == 0 and osk.col_index() == 2, "Right moves along the row")
	ui_nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(osk.row_index() == 1, "Down moves to the next row")
	osk.focus_key(0, String(UiTokens.OSK_ROWS[0]).length() - 1)
	ui_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(osk.zone() == UiOnScreenKeyboard.Zone.ACTIONS, "Right at a row end enters actions")
	ui_nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(osk.zone() == UiOnScreenKeyboard.Zone.KEYS
		and osk.row_index() == 0, "Left returns to the key row")
	osk.focus_key(1, 2)
	var before := osk.current_text()
	ui_nav.confirmed.emit()
	await _frames(1)
	_check(osk.current_text() == before + "D", "confirm presses the focused key")
	await _tap_key(KEY_X, 120)
	_check(osk.current_text().ends_with("x"), "physical letters reach the keyboard")
	await _tap_key(KEY_SPACE, 32)
	_check(osk.current_text().ends_with(" "), "physical space inserts a space")
	await _tap_key(KEY_BACKSPACE)
	_check(osk.current_text().ends_with("x"), "physical backspace deletes")
	osk.key_button(0, 0).pressed.emit()
	_check(osk.current_text().ends_with("Q"), "a mouse-style key press inserts")
	osk.call("_on_scrim_input", _left_click())
	await _frames(2)
	_check(not osk.is_open(), "clicking the backdrop closes the keyboard")

	osk.open("NAME", "x", NetworkValidation.NAME_MAX, NetworkValidation.NAME_CHARS)
	await _frames(2)
	ui_nav.cancelled.emit()
	await _frames(2)
	_check(not osk.is_open(), "cancel closes the keyboard")

	host.queue_free()
	await _frames(1)
	if failures.is_empty():
		print("== check_ui_on_screen_keyboard: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_ui_on_screen_keyboard: FAIL ==")
	quit(0 if failures.is_empty() else 1)


func _left_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


