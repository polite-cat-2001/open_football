extends RefCounted
class_name MatchHubFixture

const HOME_RATING := {"stars": 4.5, "attack": 88, "midfield": 86, "defence": 84}
const AWAY_RATING := {"stars": 4.0, "attack": 85, "midfield": 83, "defence": 81}

const HOME_NAMES := [
	"Ter Stegen", "Balde", "Christensen", "Araujo", "Kounde", "De Jong",
	"Pedri", "Gavi", "Raphinha", "Lewandowski", "Yamal",
]
const AWAY_NAMES := [
	"Courtois", "Mendy", "Militao", "Rudiger", "Carvajal", "Tchouameni",
	"Valverde", "Bellingham", "Vinicius", "Mbappe", "Rodrygo",
]
const HOME_ROLES := ["GK", "LB", "CB", "CB", "RB", "DM", "CM", "CM", "LW", "ST", "RW"]
const AWAY_ROLES := ["GK", "LB", "CB", "CB", "RB", "DM", "CM", "CM", "LW", "ST", "RW"]


static func kit(kit_name: String, shirt: String, shorts: String) -> Dictionary:
	return {
		"id": kit_name.to_lower(),
		"name": kit_name,
		"shirt": shirt,
		"shorts": shorts,
		"pattern": "plain",
		"pattern_color": shirt,
	}


static func side(side_index: int, team_name: String, names: Array, roles: Array,
		rating: Dictionary, uniform: Dictionary, kind := "keyboard", device := 0,
		owner := "") -> Dictionary:
	var lineup: Array = []
	for index in names.size():
		lineup.append({
			"slot": index,
			"number": index + 1,
			"name": names[index],
			"role": roles[index],
			"captain": index == 5,
		})
	return {
		"side": side_index,
		"label": "HOME" if side_index == 0 else "AWAY",
		"team": {"name": team_name, "texture": null, "rating": rating.duplicate(true)},
		"lineup": lineup,
		"kit": uniform.duplicate(true),
		"device": {"kind": kind, "device": device, "name": "Keyboard" if kind == "keyboard" else "Gamepad"},
		"owner": owner,
	}


static func squad_for(side_index: int) -> Dictionary:
	var names: Array = HOME_NAMES if side_index == 0 else AWAY_NAMES
	var roles: Array = HOME_ROLES if side_index == 0 else AWAY_ROLES
	var players: Array = []
	for index in names.size() + 7:
		var role := str(roles[index]) if index < roles.size() else "CM"
		var last := str(names[index]) if index < names.size() else "Reserve %d" % (index + 1)
		players.append({
			"id": side_index * 100 + index + 1,
			"firstname": "First",
			"lastname": last,
			"name": "First " + last,
			"role": role,
			"base_stat": 0.82,
			"average": 0.82,
			"stats": {"mental_workrate": 0.8, "mental_resilience": 0.8,
				"mental_vision": 0.8, "technical_shot": 0.8, "mental_calmness": 0.8,
				"technical_highpass": 0.8},
		})
	var formation: Array = []
	for slot in 11:
		formation.append({
			"slot": slot,
			"role": str(roles[slot]),
			"position": Vector2(-0.6 + float(slot % 4) * 0.4,
				-0.7 + (float(slot) / 4.0) * 0.6),
			"database_position": Vector2(-0.6 + float(slot % 4) * 0.4,
				-0.7 + (float(slot) / 4.0) * 0.6),
		})
	return {
		"team": {"id": side_index + 1,
			"name": "FC Barcelona" if side_index == 0 else "Real Madrid"},
		"players": players,
		"formation": formation,
	}


static func lineup_model(side_index: int) -> MatchLineup:
	return MatchLineup.from_squad(squad_for(side_index))


static func state_1p() -> Dictionary:
	return _state({
		"local_two_player": false,
		"start_label": "START MATCH",
	})


static func state_2p() -> Dictionary:
	return _state({
		"local_two_player": true,
		"start_label": "START MATCH (1/2)",
		"start_votes": 1,
		"start_votes_needed": 2,
		"status": "START 1/2",
	})


static func state_network_host() -> Dictionary:
	return _state({
		"network": true,
		"host": true,
		"client": false,
		"start_label": "START MATCH",
		"status": "HOST: SET OPTIONS AND START",
	})


static func state_network_client() -> Dictionary:
	return _state({
		"network": true,
		"host": false,
		"client": true,
		"can_start": false,
		"can_options": true,
		"options_editable": false,
		"start_label": "WAITING FOR HOST",
		"status": "WAITING FOR HOST",
	})


static func state_options() -> Dictionary:
	var state := state_1p()
	state["status"] = ""
	return state


static func state_settings_sides() -> Dictionary:
	return _state({"settings_sides": true})


static func _state(flags: Dictionary) -> Dictionary:
	var home := side(0, "FC Barcelona", HOME_NAMES, HOME_ROLES, HOME_RATING,
		kit("HOME", "#a50044", "#004d98"))
	var away := side(1, "Real Madrid", AWAY_NAMES, AWAY_ROLES, AWAY_RATING,
		kit("AWAY", "#ffffff", "#111111"), "gamepad", 1, "MARIA")
	return {
		"meta": {"competition": "LA LIGA", "difficulty": 0.8, "duration": 1.0},
		"sides": [home, away],
		"options": {
			"difficulty": 0.8,
			"duration": 1.0,
			"editable": bool(flags.get("options_editable", true)),
		},
		"flags": {
			"can_start": bool(flags.get("can_start", true)),
			"can_manage": bool(flags.get("can_manage", true)),
			"can_options": bool(flags.get("can_options", true)),
			"network": bool(flags.get("network", false)),
			"host": bool(flags.get("host", true)),
			"client": bool(flags.get("client", false)),
			"local_two_player": bool(flags.get("local_two_player", false)),
			"settings_sides": bool(flags.get("settings_sides", false)),
			"start_label": str(flags.get("start_label", "START MATCH")),
			"start_votes": int(flags.get("start_votes", 0)),
			"start_votes_needed": int(flags.get("start_votes_needed", 1)),
		},
		"status": str(flags.get("status", "")),
		"status_error": false,
		"error": false,
	}
