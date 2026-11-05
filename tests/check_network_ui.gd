extends SceneTree
# Headless checks for the design-system network screens: menu tiles, host/join
# forms, the shared OSK, inline validation, persistence and the join
# "Connecting..."/failure path.
#
# Run:  godot --headless --path . -s res://tests/check_network_ui.gd

const MAIN_MENU := "res://scenes/main_menu.tscn"
const NETWORK_MENU := "res://scenes/network_menu.tscn"
const NETWORK_HOST := "res://scenes/network_host.tscn"
const NETWORK_JOIN := "res://scenes/network_join.tscn"
const TEST_CONFIG := "user://network_ui_test.cfg"
const PORT_FIRST := 28351
const PORT_TRIES := 20
const NET_SHELL := preload("res://scripts/net/net_shell.gd")

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


func _tap_key(code: int) -> void:
	Input.parse_input_event(_key(code, true))
	await _frames(2)
	Input.parse_input_event(_key(code, false))
	await _frames(1)


func _left_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _aligned_with_panel(screen: Node) -> bool:
	var panel: Control = screen.get("form_panel")
	var breadcrumb: Control = screen.get("breadcrumb")
	var legend: Control = screen.get("legend")
	if panel == null or breadcrumb == null or legend == null:
		return false
	var left := panel.get_global_rect().position.x
	return absf(breadcrumb.get_global_rect().position.x - left) <= 1.0 \
		and absf(legend.get_global_rect().position.x - left) <= 1.0


func _run() -> void:
	ShellState.clear()
	NetworkSettings.config_path = TEST_CONFIG
	NetworkSettings.reset()
	change_scene_to_file(MAIN_MENU)
	await _frames(6)
	var menu := current_scene
	_check(menu != null and menu.name == "MainMenu", "the main menu opens")
	if menu != null:
		(menu.get_node("Design/PanelWrap/PlayGrid/NetworkTile") as Button).pressed.emit()
		await _frames(8)

	_check(current_scene != null and current_scene.name == "NetworkMenu",
		"the network menu opens")
	var network_menu := current_scene
	if network_menu != null:
		_check(network_menu.get_node_or_null("Design/PanelWrap/Grid/HostTile") is Button
			and network_menu.get_node_or_null("Design/PanelWrap/Grid/JoinTile") is Button,
			"the network menu has two tiles")
		_check(network_menu.get_node_or_null("Design/PanelWrap/BackRow") == null,
			"the network menu has no Back button")
		await _tap_key(KEY_ESCAPE)
		await _frames(6)
		_check(current_scene != null and current_scene.name == "MainMenu",
			"Esc returns from the network menu to the main menu")

	change_scene_to_file(NETWORK_HOST)
	await _frames(5)
	var host := current_scene
	_check(host != null and host.name == "NetworkHost", "the host screen opens")
	if host != null:
		var port_row: UiFormRow = host.get("port_row")
		var name_row: UiFormRow = host.get("name_row")
		var open_row: UiMenuRow = host.get("open_row")
		var label: Label = host.get("status_label")
		_check(host.get_node_or_null("Design/PanelWrap/FormPanel/Content/BackRow") == null,
			"the host form has no Back button")
		_check(_aligned_with_panel(host), "the host breadcrumb and legend are left-aligned")
		port_row.set_value("0")
		name_row.set_value("")
		host.call("_open_lobby")
		_check(port_row.error_text().contains("port"), "the host reports an invalid port")
		_check(name_row.error_text().contains("name"), "the host reports an empty name")
		_check(label.text.contains("highlighted"), "the host asks for the fields")

		port_row.set_value("27015")
		host.call("_open_port")
		await _frames(3)
		var osk: UiOnScreenKeyboard = host.get("osk")
		_check(osk != null and osk.is_open(), "the port OSK opens from the field")
		osk.press_clear()
		osk.press_character("2")
		osk.press_character("a")
		osk.press_character("8")
		osk.press_apply()
		await _frames(3)
		_check(port_row.value_text() == "28", "the OSK applies a filtered port")
		_check(port_row.has_focus(), "the focus returns to the port field after Apply")
		_check(open_row != null, "the host has a primary action row")
		host.call("_open_port")
		await _frames(2)
		osk.call("_on_scrim_input", _left_click())
		await _frames(2)
		_check(not osk.is_open() and port_row.has_focus(),
			"the focus returns to the field after a backdrop close")
		host.call("_open_port")
		await _frames(2)
		await _tap_key(KEY_ESCAPE)
		await _frames(4)
		_check(not osk.is_open() and current_scene != null
			and current_scene.name == "NetworkHost",
			"Esc closes the OSK without leaving the host screen")
		host.call("_open_port")
		await _frames(2)
		osk.focus_action(UiOnScreenKeyboard.ACTION_APPLY)
		await _tap_key(KEY_ENTER)
		await _frames(4)
		_check(not osk.is_open() and current_scene != null
			and current_scene.name == "NetworkHost",
			"Enter on Apply closes the OSK without reopening it")

	change_scene_to_file(NETWORK_JOIN)
	await _frames(5)
	var join := current_scene
	_check(join != null and join.name == "NetworkJoin", "the join screen opens")
	if join != null:
		var address_row: UiFormRow = join.get("address_row")
		var join_port: UiFormRow = join.get("port_row")
		var join_name: UiFormRow = join.get("name_row")
		var join_status: Label = join.get("status_label")
		_check(join.get_node_or_null("Design/PanelWrap/FormPanel/Content/BackRow") == null,
			"the join form has no Back button")
		_check(_aligned_with_panel(join), "the join breadcrumb and legend are left-aligned")
		_check(address_row.value_text() == NetworkSettings.DEFAULT_JOIN_ADDRESS,
			"the join form starts from defaults")
		address_row.set_value("bad address!")
		join.call("_connect")
		_check(address_row.error_text().contains("IPv4"), "the join reports an invalid address")
		address_row.set_value("127.0.0.1")
		join_port.set_value("0")
		join.call("_connect")
		_check(join_port.error_text().contains("port"), "the join reports an invalid port")
		join_port.set_value("27015")
		join_name.set_value("")
		join.call("_connect")
		_check(join_name.error_text().contains("name"), "the join reports an empty name")

		join.call("_open_address")
		await _frames(3)
		var join_osk: UiOnScreenKeyboard = join.get("osk")
		_check(join_osk != null and join_osk.is_open(), "the address OSK opens")
		join_osk.press_clear()
		join_osk.press_character("1")
		join_osk.press_character("2")
		join_osk.press_character("7")
		join_osk.press_character(".")
		join_osk.press_character("0")
		join_osk.press_character(".")
		join_osk.press_character("0")
		join_osk.press_character(".")
		join_osk.press_character("1")
		join_osk.press_apply()
		await _frames(3)
		_check(address_row.value_text() == "127.0.0.1", "the address OSK applies")

		# A closed localhost port must fail cleanly, not hang the form.
		address_row.set_value("127.0.0.1")
		join_port.set_value(str(PORT_FIRST + PORT_TRIES + 1))
		join_name.set_value("Guest")
		join.call("_connect")
		await _frames(2)
		_check(join_status.text.contains("CONNECTING"), "the join shows Connecting...")
		var deadline := Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < deadline and bool(join.get("_connecting")):
			await _frames(4)
		_check(not bool(join.get("_connecting")), "a failed connection stops polling")
		_check(not join_status.text.is_empty() and not join_status.text.contains("CONNECTING"),
			"a failed connection shows a reason")
		var join_saved := NetworkSettings.load_join()
		_check(str(join_saved["address"]) == "127.0.0.1"
			and str(join_saved["name"]) == "Guest", "the join values are persisted")
		join.call("_back")
		await _frames(6)
		_check(current_scene != null and current_scene.name == "NetworkMenu",
			"Back returns from the join form to the network menu")

	NetworkSettings.reset()
	NetworkSettings.config_path = NetworkSettings.CONFIG_PATH
	ShellState.clear()
	if failures.is_empty():
		print("== check_network_ui: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_network_ui: FAIL ==")
	quit(0 if failures.is_empty() else 1)

