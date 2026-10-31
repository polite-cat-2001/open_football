class_name TacticalSchemes
extends RefCounted
# Godot port of GameplayFootball's tactic scheme list
# (src/menu/tacticschemes.cpp): six hardcoded formations, the Hungarian
# assignment of scheme entries to the current players, and scheme matching.
# Positions are database space: x = -1 own goal .. 1 opponent goal, y = -1..1.

const ROLE_LINES := {
	"GK": 0,
	"CB": 1, "LB": 1, "RB": 1,
	"DM": 2, "CM": 2, "LM": 2, "RM": 2, "AM": 2,
	"CF": 3, "LW": 3, "RW": 3, "ST": 3,
}

const SCHEMES := [
	{"name": "4-4-2", "entries": [
		{"role": "GK", "position": Vector2(-1.0, 0.0)},
		{"role": "LB", "position": Vector2(-0.7, 0.6)},
		{"role": "CB", "position": Vector2(-0.8, 0.2)},
		{"role": "CB", "position": Vector2(-0.8, -0.2)},
		{"role": "RB", "position": Vector2(-0.7, -0.6)},
		{"role": "LM", "position": Vector2(0.0, 0.75)},
		{"role": "DM", "position": Vector2(-0.15, 0.0)},
		{"role": "RM", "position": Vector2(0.0, -0.75)},
		{"role": "AM", "position": Vector2(0.3, 0.0)},
		{"role": "CF", "position": Vector2(0.8, 0.3)},
		{"role": "CF", "position": Vector2(0.8, -0.3)},
	]},
	{"name": "4-3-3", "entries": [
		{"role": "GK", "position": Vector2(-1.0, 0.0)},
		{"role": "LB", "position": Vector2(-0.7, 0.75)},
		{"role": "CB", "position": Vector2(-1.0, 0.25)},
		{"role": "CB", "position": Vector2(-1.0, -0.25)},
		{"role": "RB", "position": Vector2(-0.7, -0.75)},
		{"role": "CM", "position": Vector2(0.15, 0.5)},
		{"role": "CM", "position": Vector2(-0.05, 0.0)},
		{"role": "CM", "position": Vector2(0.15, -0.5)},
		{"role": "LM", "position": Vector2(0.6, 0.75)},
		{"role": "CF", "position": Vector2(1.0, 0.0)},
		{"role": "RM", "position": Vector2(0.6, -0.75)},
	]},
	{"name": "4-2-3-1", "entries": [
		{"role": "GK", "position": Vector2(-1.0, 0.0)},
		{"role": "LB", "position": Vector2(-0.7, 0.75)},
		{"role": "CB", "position": Vector2(-1.0, 0.25)},
		{"role": "CB", "position": Vector2(-1.0, -0.25)},
		{"role": "RB", "position": Vector2(-0.7, -0.75)},
		{"role": "CM", "position": Vector2(-0.05, 0.3)},
		{"role": "CM", "position": Vector2(-0.05, -0.3)},
		{"role": "LM", "position": Vector2(0.7, 0.75)},
		{"role": "AM", "position": Vector2(0.2, 0.0)},
		{"role": "RM", "position": Vector2(0.7, -0.75)},
		{"role": "CF", "position": Vector2(1.0, 0.0)},
	]},
	{"name": "3-5-2", "entries": [
		{"role": "GK", "position": Vector2(-1.0, 0.0)},
		{"role": "CB", "position": Vector2(-1.0, 0.35)},
		{"role": "CB", "position": Vector2(-1.0, 0.0)},
		{"role": "CB", "position": Vector2(-1.0, -0.35)},
		{"role": "LM", "position": Vector2(0.0, 0.75)},
		{"role": "CM", "position": Vector2(0.05, 0.3)},
		{"role": "DM", "position": Vector2(-0.15, 0.0)},
		{"role": "CM", "position": Vector2(0.05, -0.3)},
		{"role": "RM", "position": Vector2(0.0, -0.75)},
		{"role": "CF", "position": Vector2(0.8, 0.3)},
		{"role": "CF", "position": Vector2(0.8, -0.3)},
	]},
	{"name": "5-3-2", "entries": [
		{"role": "GK", "position": Vector2(-1.0, 0.0)},
		{"role": "LB", "position": Vector2(-0.6, 0.75)},
		{"role": "CB", "position": Vector2(-1.0, 0.35)},
		{"role": "CB", "position": Vector2(-1.0, 0.0)},
		{"role": "CB", "position": Vector2(-1.0, -0.35)},
		{"role": "RB", "position": Vector2(-0.6, -0.75)},
		{"role": "CM", "position": Vector2(0.15, 0.5)},
		{"role": "CM", "position": Vector2(-0.05, 0.0)},
		{"role": "CM", "position": Vector2(0.15, -0.5)},
		{"role": "CF", "position": Vector2(0.8, 0.3)},
		{"role": "CF", "position": Vector2(0.8, -0.3)},
	]},
	{"name": "4-5-1", "entries": [
		{"role": "GK", "position": Vector2(-1.0, 0.0)},
		{"role": "LB", "position": Vector2(-0.7, 0.75)},
		{"role": "CB", "position": Vector2(-1.0, 0.25)},
		{"role": "CB", "position": Vector2(-1.0, -0.25)},
		{"role": "RB", "position": Vector2(-0.7, -0.75)},
		{"role": "LM", "position": Vector2(0.1, 0.75)},
		{"role": "CM", "position": Vector2(-0.05, 0.3)},
		{"role": "DM", "position": Vector2(-0.25, 0.0)},
		{"role": "CM", "position": Vector2(-0.05, -0.3)},
		{"role": "RM", "position": Vector2(0.1, -0.75)},
		{"role": "CF", "position": Vector2(0.9, 0.0)},
	]},
]


static func count() -> int:
	return SCHEMES.size()


static func scheme_name(index: int) -> String:
	if index < 0 or index >= SCHEMES.size():
		return ""
	return String(SCHEMES[index]["name"])


# candidates: [{slot, role, position}] in current formation order.
# Returns the same length: [{role, database_position, position}].
static func assign(candidates: Array, scheme_index: int) -> Array:
	var result: Array = []
	for candidate in candidates:
		var role := str(candidate.get("role", "CM"))
		var position: Vector2 = candidate.get("position", Vector2.ZERO)
		result.append({
			"role": role,
			"database_position": position,
			"position": position * Formation.DATABASE_WEIGHT
				+ Formation.default_role_position(role) * Formation.DEFAULT_WEIGHT,
		})
	if candidates.is_empty() or scheme_index < 0 or scheme_index >= SCHEMES.size():
		return result

	var scheme: Dictionary = SCHEMES[scheme_index]
	var entries: Array = scheme["entries"]
	var gk_candidate := -1
	var gk_entry := -1
	for index in candidates.size():
		if str(candidates[index].get("role", "")) == "GK":
			gk_candidate = index
			break
	for index in entries.size():
		if str(entries[index].get("role", "")) == "GK":
			gk_entry = index
			break
	if gk_candidate >= 0 and gk_entry >= 0:
		result[gk_candidate] = _make_entry(entries[gk_entry])

	var candidate_indices: Array = []
	var entry_indices: Array = []
	for index in candidates.size():
		if index != gk_candidate:
			candidate_indices.append(index)
	for index in entries.size():
		if index != gk_entry:
			entry_indices.append(index)
	var size := maxi(candidate_indices.size(), entry_indices.size())
	if size <= 0:
		return result
	var pad_cost := 100000.0
	var cost: Array = []
	for row in size:
		var row_costs: Array = []
		for column in size:
			row_costs.append(pad_cost)
		cost.append(row_costs)
	for row in entry_indices.size():
		var entry: Dictionary = entries[entry_indices[row]]
		for column in candidate_indices.size():
			var candidate: Dictionary = candidates[candidate_indices[column]]
			var candidate_position: Vector2 = candidate.get("position", Vector2.ZERO)
			var scheme_position: Vector2 = entry["position"]
			var distance := candidate_position.distance_to(scheme_position)
			(cost[row] as Array)[column] = roundf(distance * 10.0) + _role_penalty(
				str(candidate.get("role", "CM")), str(entry["role"]))
	var assignment := _min_cost_assignment(cost)
	for row in entry_indices.size():
		var column := int(assignment[row])
		if column < 0 or column >= candidate_indices.size():
			continue
		result[int(candidate_indices[column])] = _make_entry(entries[int(entry_indices[row])])
	return result


# Index of the scheme matching the current formation exactly, or -1.
static func match_scheme(formation: Array) -> int:
	for scheme_index in SCHEMES.size():
		var entries: Array = SCHEMES[scheme_index]["entries"]
		if formation.size() != entries.size():
			continue
		var used: Array = []
		used.resize(entries.size())
		used.fill(false)
		var matches := true
		for entry in formation:
			var found := -1
			for index in entries.size():
				if used[index]:
					continue
				if str(entries[index]["role"]) != str(entry.get("role", "")):
					continue
				var position: Vector2 = entry.get("position", entry.get("database_position", Vector2.ZERO))
				if (entries[index]["position"] as Vector2).distance_to(position) >= 0.02:
					continue
				found = index
				break
			if found < 0:
				matches = false
				break
			used[found] = true
		if matches:
			return scheme_index
	return -1


static func _make_entry(entry: Dictionary) -> Dictionary:
	var role := str(entry["role"])
	var position: Vector2 = entry["position"]
	return {
		"role": role,
		"database_position": position,
		"position": position * Formation.DATABASE_WEIGHT
			+ Formation.default_role_position(role) * Formation.DEFAULT_WEIGHT,
	}


static func _role_line(role: String) -> int:
	return int(ROLE_LINES.get(role, 2))


static func _role_penalty(first: String, second: String) -> int:
	if first == second:
		return 0
	var line_a := _role_line(first)
	var line_b := _role_line(second)
	if line_a == 0 or line_b == 0:
		return 8
	if line_a == line_b:
		return 2
	return 6


# Hungarian algorithm (min-cost, square matrix). Returns row -> column.
static func _min_cost_assignment(cost: Array) -> Array:
	var n := cost.size()
	var u: Array = []
	var v: Array = []
	var p: Array = []
	var way: Array = []
	u.resize(n + 1)
	v.resize(n + 1)
	p.resize(n + 1)
	way.resize(n + 1)
	for index in n + 1:
		u[index] = 0.0
		v[index] = 0.0
		p[index] = 0
		way[index] = 0
	for row in range(1, n + 1):
		p[0] = row
		var column := 0
		var minv: Array = []
		var used: Array = []
		minv.resize(n + 1)
		used.resize(n + 1)
		for index in n + 1:
			minv[index] = INF
			used[index] = false
		while true:
			used[column] = true
			var current_row := int(p[column])
			var delta := INF
			var next_column := -1
			for candidate_column in range(1, n + 1):
				if used[candidate_column]:
					continue
				var current := float((cost[current_row - 1] as Array)[candidate_column - 1]) \
					- float(u[current_row]) - float(v[candidate_column])
				if current < float(minv[candidate_column]):
					minv[candidate_column] = current
					way[candidate_column] = column
				if float(minv[candidate_column]) < delta:
					delta = float(minv[candidate_column])
					next_column = candidate_column
			for candidate_column in range(0, n + 1):
				if used[candidate_column]:
					u[p[candidate_column]] = float(u[p[candidate_column]]) + delta
					v[candidate_column] = float(v[candidate_column]) - delta
				else:
					minv[candidate_column] = float(minv[candidate_column]) - delta
			column = next_column
			if int(p[column]) == 0:
				break
		while true:
			var previous := int(way[column])
			p[column] = p[previous]
			column = previous
			if column == 0:
				break
	var assignment: Array = []
	assignment.resize(n)
	assignment.fill(-1)
	for column in range(1, n + 1):
		if int(p[column]) != 0:
			assignment[int(p[column]) - 1] = column - 1
	return assignment
