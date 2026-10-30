class_name InputSetup
extends RefCounted
# Shell-side device list and translation into the C++ controller setup.
#
# Godot owns device enumeration and raw input; C++ owns the human controllers.
# The bridge API is:
#   register_gamepad(godot_device_id) -> virtual slot (-1 when unavailable)
#   set_controller_setup([{side: -1|1, kind: "keyboard"|"gamepad", slot}])
#   set_gamepad_button(slot, button, pressed) / set_gamepad_axis(slot, axis, value)

const KEYBOARD_DEVICE := 0
const KEYBOARD_NAME := "Keyboard"


static func default_entry() -> Dictionary:
	return {"side": "home", "kind": "keyboard", "device": KEYBOARD_DEVICE, "name": KEYBOARD_NAME}


static func available_devices() -> Array:
	var devices: Array = [
		{"kind": "keyboard", "device": KEYBOARD_DEVICE, "name": KEYBOARD_NAME},
	]
	for id in Input.get_connected_joypads():
		var device := int(id)
		var name := Input.get_joy_name(device)
		if name.is_empty():
			name = "Gamepad %d" % device
		devices.append({"kind": "gamepad", "device": device, "name": name})
	return devices


static func normalize(entry: Dictionary, devices: Array = []) -> Dictionary:
	if devices.is_empty():
		devices = available_devices()
	var kind := str(entry.get("kind", "keyboard"))
	var device := int(entry.get("device", KEYBOARD_DEVICE))
	var chosen: Dictionary = {}
	for candidate in devices:
		if str(candidate.get("kind", "")) == kind and int(candidate.get("device", -1)) == device:
			chosen = candidate
			break
	if chosen.is_empty():
		chosen = devices[0]
	var side := str(entry.get("side", "home"))
	if side != "away":
		side = "home"
	return {
		"side": side,
		"kind": str(chosen.get("kind", "keyboard")),
		"device": int(chosen.get("device", KEYBOARD_DEVICE)),
		"name": str(chosen.get("name", chosen.get("kind", "Device"))),
	}


static func side_value(side: String) -> int:
	return 1 if side == "away" else -1


static func describe(entry: Dictionary) -> String:
	var side := "Away" if str(entry.get("side", "home")) == "away" else "Home"
	return "%s - %s" % [side, str(entry.get("name", entry.get("kind", "Device")))]


# Applies the shell selection to the runtime. Returns
# {setup: [...], slots: {godot_device_id: cpp_slot}}; slots is what the match
# scene uses to route joypad events.
static func apply_to_runtime(runtime: Node, entries: Array) -> Dictionary:
	var runtime_setup: Array = []
	var slots: Dictionary = {}
	if runtime == null:
		return {"setup": runtime_setup, "slots": slots}
	var devices := available_devices()
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry := normalize(raw_entry, devices)
		var slot := -1
		if str(entry["kind"]) == "gamepad":
			slot = int(runtime.register_gamepad(int(entry["device"])))
			if slot >= 0:
				slots[int(entry["device"])] = slot
			else:
				# The runtime refused the device: fall back to the keyboard so the
				# match is still playable (and never silently AI-vs-AI).
				entry = normalize({"side": entry["side"], "kind": "keyboard"}, devices)
		runtime_setup.append({
			"side": side_value(str(entry["side"])),
			"kind": str(entry["kind"]),
			"slot": slot,
		})
	runtime.set_controller_setup(runtime_setup)
	return {"setup": runtime_setup, "slots": slots}
