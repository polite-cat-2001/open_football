extends RefCounted
class_name KitSelectFixture

const KITS := [
	{"id": "main", "label": "HOME", "shirt": "#1D4ED8", "shorts": "#111827",
		"pattern": "plain", "pattern_color": null},
	{"id": "white", "label": "AWAY", "shirt": "#F5F7FA", "shorts": "#1D4ED8",
		"pattern": "plain", "pattern_color": null},
	{"id": "black", "label": "THIRD", "shirt": "#171B3F", "shorts": "#F5F7FA",
		"pattern": "plain", "pattern_color": null},
	{"id": "reserve", "label": "FOURTH", "shirt": "#C9F227", "shorts": "#171B3F",
		"pattern": "stripes", "pattern_color": "#E6236E"},
]


static func kit(index: int) -> Dictionary:
	return KITS[posmod(index, KITS.size())].duplicate(true)


static func side(side_index: int, live: bool, ready := false, editable := true,
		kind := "keyboard", device := 0, kit_index := 0, kits := KITS) -> Dictionary:
	return {
		"side": side_index,
		"label": "HOME" if side_index == 0 else "AWAY",
		"team": {"name": "FC Barcelona" if side_index == 0 else "Real Madrid",
			"texture": null},
		"kits": (kits as Array).duplicate(true),
		"kit_index": kit_index,
		"ready": ready,
		"live": live,
		"editable": editable,
		"device": {"kind": kind, "device": device},
		"choices": {"kits": (kits as Array).size()},
		"kit": (kits as Array)[clampi(kit_index, 0, (kits as Array).size() - 1)],
	}


static func state_1p() -> Dictionary:
	var home := side(0, true)
	var away := side(1, false, false, false, "keyboard", 0, 1)
	return _state([home, away])


static func state_away() -> Dictionary:
	var home := side(0, false, true, false)
	var away := side(1, true, false, true, "keyboard", 0, 1)
	return _state([home, away])


static func state_2p() -> Dictionary:
	var home := side(0, true, false, true, "keyboard", 0)
	var away := side(1, true, false, true, "gamepad", 1, 1)
	return _state([home, away])


static func state_network() -> Dictionary:
	var home := side(0, true, false, true, "keyboard", 0)
	var away := side(1, true, false, true, "keyboard", 0, 1)
	return _state([home, away])


static func state_network_ready() -> Dictionary:
	var home := side(0, false, true, false, "keyboard", 0)
	var away := side(1, false, true, false, "keyboard", 0, 1)
	return _state([home, away])


static func state_single_kit() -> Dictionary:
	var one := [kit(0)]
	var home := side(0, true, false, true, "keyboard", 0, 0, one)
	var away := side(1, false, false, false, "keyboard", 0, 0, one)
	return _state([home, away])


static func state_error() -> Dictionary:
	var state := state_1p()
	for side_state in state["sides"]:
		side_state["live"] = false
		side_state["editable"] = false
	state["error"] = true
	state["status"] = "Kit database not found at Z:/missing."
	state["status_error"] = true
	return state


static func _state(sides: Array) -> Dictionary:
	return {
		"sides": sides,
		"preview": {
			"home": {"name": sides[0]["team"]["name"], "kit": sides[0]["kit"]},
			"away": {"name": sides[1]["team"]["name"], "kit": sides[1]["kit"]},
		},
		"status": "",
		"status_error": false,
		"error": false,
	}
