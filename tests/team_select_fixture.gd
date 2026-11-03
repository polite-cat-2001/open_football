extends RefCounted
class_name TeamSelectFixture

const RATING := {"stars": 3.5, "attack": 81, "midfield": 78, "defence": 75, "average": 78.0}


static func entry(entry_name: String, texture: Texture2D = null) -> Dictionary:
	return {"id": entry_name.to_lower().replace(" ", "-"), "name": entry_name, "texture": texture}


static func side(side_index: int, live: bool, ready := false, editable := true,
		kind := "keyboard", device := 0, owner := "") -> Dictionary:
	return {
		"side": side_index,
		"label": "HOME" if side_index == 0 else "AWAY",
		"owner": owner,
		"ready": ready,
		"live": live,
		"editable": editable,
		"device": {"kind": kind, "device": device},
		"country": entry("Spain"),
		"competition": entry("La Liga"),
		"team": entry("FC Barcelona" if side_index == 0 else "Real Madrid"),
		"rating": RATING.duplicate(true),
		"choices": {"country": 2, "competition": 2, "team": 2},
	}


static func state_1p() -> Dictionary:
	return {
		"sides": [
			side(0, true),
			side(1, false, false, false),
		],
		"status": "",
		"status_error": false,
		"error": false,
	}


static func state_away() -> Dictionary:
	return {
		"sides": [
			side(0, false, true, false),
			side(1, true),
		],
		"status": "",
		"status_error": false,
		"error": false,
	}


static func state_2p() -> Dictionary:
	return {
		"sides": [
			side(0, true, false, true, "keyboard", 0),
			side(1, true, false, true, "gamepad", 1),
		],
		"status": "",
		"status_error": false,
		"error": false,
	}


static func state_network() -> Dictionary:
	return {
		"sides": [
			side(0, true, false, true, "keyboard", 0, "YOU  ALEX"),
			side(1, true, false, true, "keyboard", 0, "MARIA"),
		],
		"status": "",
		"status_error": false,
		"error": false,
	}


static func state_network_ready() -> Dictionary:
	var state := state_network()
	state["sides"][0]["ready"] = true
	state["sides"][0]["live"] = false
	state["sides"][1]["ready"] = true
	state["sides"][1]["live"] = false
	return state


static func state_error() -> Dictionary:
	var state := state_1p()
	for side in state["sides"]:
		side["country"] = {}
		side["competition"] = {}
		side["team"] = {}
		side["rating"] = {}
		side["live"] = false
		side["editable"] = false
	state["error"] = true
	state["status"] = "Team database not found at Z:/missing."
	state["status_error"] = true
	return state
