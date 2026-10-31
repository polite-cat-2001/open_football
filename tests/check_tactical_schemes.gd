extends SceneTree
# Headless check for the tactical scheme data and assignment (port of
# src/menu/tacticschemes.cpp).
#
# Run:  godot --headless --path . -s res://tests/check_tactical_schemes.gd

var failures: Array[String] = []


func _init() -> void:
	_run()
	print("== check_tactical_schemes: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _candidates() -> Array:
	var roles := ["GK", "CB", "CB", "LB", "RB", "DM", "CM", "CM", "LM", "RM", "ST"]
	var positions := [
		Vector2(-1.0, 0.0), Vector2(-0.8, -0.2), Vector2(-0.8, 0.2),
		Vector2(-0.7, 0.75), Vector2(-0.7, -0.75), Vector2(-0.45, 0.0),
		Vector2(-0.1, -0.25), Vector2(-0.1, 0.25), Vector2(0.25, -0.7),
		Vector2(0.25, 0.7), Vector2(0.8, 0.0),
	]
	var result: Array = []
	for index in roles.size():
		result.append({"slot": index, "role": roles[index], "position": positions[index]})
	return result


func _role_counts(assignment: Array) -> Dictionary:
	var counts := {}
	for entry in assignment:
		var role := str(entry["role"])
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


func _run() -> void:
	_check(TacticalSchemes.count() == 6, "six schemes are ported")
	_check(TacticalSchemes.scheme_name(0) == "4-4-2", "4-4-2 is first")

	var assignment := TacticalSchemes.assign(_candidates(), 0)
	_check(assignment.size() == Formation.SLOT_COUNT, "the assignment covers eleven slots")
	var counts := _role_counts(assignment)
	_check(int(counts.get("GK", 0)) == 1, "the goalkeeper is pinned")
	_check(int(counts.get("CB", 0)) == 2 and int(counts.get("LB", 0)) == 1
		and int(counts.get("RB", 0)) == 1, "the back four is a 4-4-2")
	_check(int(counts.get("CF", 0)) == 2, "two centre forwards")
	_check(int(counts.get("LM", 0)) == 1 and int(counts.get("RM", 0)) == 1,
		"both wide midfielders")

	var formation: Array = []
	for entry in assignment:
		formation.append({"role": entry["role"], "position": entry["database_position"]})
	_check(TacticalSchemes.match_scheme(formation) == 0, "the applied scheme is recognised")

	var assignment_433 := TacticalSchemes.assign(_candidates(), 1)
	var counts_433 := _role_counts(assignment_433)
	_check(int(counts_433.get("CM", 0)) == 3, "4-3-3 has three central midfielders")
	_check(int(counts_433.get("CF", 0)) == 1, "4-3-3 has one centre forward")
	formation.clear()
	for entry in assignment_433:
		formation.append({"role": entry["role"], "position": entry["database_position"]})
	_check(TacticalSchemes.match_scheme(formation) == 1, "4-3-3 is recognised")
