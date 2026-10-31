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
