class_name CareerRoles
extends RefCounted
# Set-piece role assignments ported from server/career/roles.py. A role's
# default wearer is the best starter by the prototype's weighted stats; the
# chosen id lives in the career save under `role_assignments`.

const ROLE_IDS := [
	"captain", "free_kick_left", "free_kick_right", "free_kick_long",
	"penalties", "corner_left", "corner_right",
]

const LABELS := {
	"captain": "CAPTAIN",
	"free_kick_left": "FREE KICK LEFT",
	"free_kick_right": "FREE KICK RIGHT",
	"free_kick_long": "LONG FREE KICK",
	"penalties": "PENALTIES",
	"corner_left": "LEFT CORNER",
	"corner_right": "RIGHT CORNER",
}

const WEIGHTS := {
	"captain": {
		"mental_calmness": 0.30, "mental_resilience": 0.25,
		"mental_workrate": 0.20, "mental_vision": 0.10, "overall": 0.15,
	},
	"free_kick_left": {
		"technical_shot": 0.25, "technical_highpass": 0.25,
		"physical_shotpower": 0.20, "mental_vision": 0.15,
		"technical_ballcontrol": 0.15,
	},
	"free_kick_right": {
		"technical_shot": 0.25, "technical_highpass": 0.25,
		"physical_shotpower": 0.20, "mental_vision": 0.15,
		"technical_ballcontrol": 0.15,
	},
	"free_kick_long": {
		"physical_shotpower": 0.35, "technical_shot": 0.25,
		"technical_highpass": 0.20, "mental_vision": 0.10,
		"technical_ballcontrol": 0.10,
	},
	"penalties": {
		"technical_shot": 0.35, "mental_calmness": 0.30,
		"physical_shotpower": 0.20, "technical_ballcontrol": 0.15,
	},
	"corner_left": {
		"technical_highpass": 0.40, "mental_vision": 0.25,
		"technical_ballcontrol": 0.20, "technical_shortpass": 0.15,
	},
	"corner_right": {
		"technical_highpass": 0.40, "mental_vision": 0.25,
		"technical_ballcontrol": 0.20, "technical_shortpass": 0.15,
	},
}

static var last_error := ""


static func role_score(player: Dictionary, weights: Dictionary) -> float:
	var stats: Dictionary = player.get("stats", {}) if player.get("stats") is Dictionary else {}
	var total := 0.0
	var weight := 0.0
	for key in weights:
		var value
		if str(key) == "overall":
			value = player.get("overall")
		else:
			value = stats.get(key)
		if value == null:
			continue
		total += float(value) * float(weights[key])
		weight += float(weights[key])
	return total / weight if weight > 0.0 else 0.0


static func default_assignments(starters: Array) -> Dictionary:
	last_error = ""
	if starters.is_empty():
		return {}
	var result := {}
	for role in ROLE_IDS:
		var weights: Dictionary = WEIGHTS[role]
		var best: Dictionary = {}
		var best_key: Array = []
		for player in starters:
			var key := [
				role_score(player, weights),
				float(player.get("overall", 0.0)),
				str(player.get("id", "")),
			]
			if best.is_empty() or _key_greater(key, best_key):
				best = player
				best_key = key
		if not best.is_empty():
			result[role] = str(best.get("id", ""))
	return result


static func role_assignments(career: Career, starters: Array) -> Dictionary:
	last_error = ""
	var fallback := default_assignments(starters)
	var starter_ids := {}
	for player in starters:
		starter_ids[str(player.get("id", ""))] = true
	var stored: Dictionary = career.role_assignments
	var result := {}
	for role in ROLE_IDS:
		var assigned := str(stored.get(role, ""))
		result[role] = assigned if starter_ids.has(assigned) \
			else str(fallback.get(role, ""))
	return result


static func set_role_assignment(career: Career, starters: Array, role: String,
		player_id: String) -> bool:
	last_error = ""
	if not ROLE_IDS.has(role):
		last_error = "unknown role"
		return false
	var starter_ids := {}
	for player in starters:
		starter_ids[str(player.get("id", ""))] = true
	var key := str(player_id)
	if not starter_ids.has(key):
		last_error = "player is not in the starting lineup"
		return false
	var assignments: Dictionary = career.role_assignments
	assignments[role] = key
	career.role_assignments = assignments
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": "lineup.role",
		"payload": {"role": role, "player_id": key},
	})
	return true


static func _key_greater(a: Array, b: Array) -> bool:
	if is_equal_approx(float(a[0]), float(b[0])):
		if is_equal_approx(float(a[1]), float(b[1])):
			return str(a[2]) > str(b[2])
		return float(a[1]) > float(b[1])
	return float(a[0]) > float(b[0])
