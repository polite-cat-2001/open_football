extends Node
# Dev/test helper: inject gamepad events into the Godot input system.
# The MCP runtime bridge can only inject keyboard events, so UI checks that
# need a pad call these methods through runtime_call_method.

func inject_joy_button(device: int, button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func inject_joy_axis(device: int, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func inject_click(x: float, y: float) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(x, y)
	press.global_position = Vector2(x, y)
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(x, y)
	release.global_position = Vector2(x, y)
	Input.parse_input_event(release)


# MCP has no array/vector arguments; set `pointer` and call this no-arg helper.
var pointer := Vector2.ZERO


func click_pointer() -> void:
	inject_click(pointer.x, pointer.y)


func debug_joypads() -> Array:
	var pads: Array = []
	for id in Input.get_connected_joypads():
		pads.append({
			"id": int(id),
			"name": Input.get_joy_name(int(id)),
			"guid": Input.get_joy_guid(int(id)),
		})
	return pads


func debug_ui_accept() -> Array:
	var events: Array = []
	for event in InputMap.action_get_events("ui_accept"):
		events.append({
			"text": event.as_text(),
			"type": event.get_class(),
			"device": event.device,
			"keycode": (event as InputEventKey).keycode if event is InputEventKey else -1,
			"button": (event as InputEventJoypadButton).button_index \
				if event is InputEventJoypadButton else -1,
		})
	return events


func debug_focus() -> String:
	var owner := get_viewport().gui_get_focus_owner()
	return owner.name if owner != null else ""


# Dev/test helper: jump straight into a GPF match without walking the shell
# screens. Used by the MCP live run to reach pause/game-plan quickly.
func seed_match(home_id: int = 4, away_id: int = 5) -> bool:
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(""):
		return false
	var home := catalog.team_by_id(home_id)
	var away := catalog.team_by_id(away_id)
	if home.is_empty() or away.is_empty():
		return false
	ShellState.set_teams(home, away)
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var builder := MatchPackage.new()
	var package := builder.build_from_ids(catalog, home_id, away_id, {})
	if package.is_empty():
		return false
	ShellState.set_match_package(package)
	get_tree().change_scene_to_file("res://scenes/gpf_slice.tscn")
	return true
