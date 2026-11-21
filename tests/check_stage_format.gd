extends SceneTree
# Headless check for the format-driven Austrian plan: the stages, the 6+6 cut
# and the carried points come from the shipped A1 format, not from constants in
# the test.
#
# Run:  godot --headless --path . -s res://tests/check_stage_format.gd

const CLUBS := ["C00", "C01", "C02", "C03", "C04", "C05",
	"C06", "C07", "C08", "C09", "C10", "C11"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _results(fixtures: Array) -> Dictionary:
	var results := {}
	for fixture in fixtures:
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		results[str(fixture.get("id", ""))] = (
			{"home": 2, "away": 0} if home < away else {"home": 0, "away": 2})
	return results


func _run() -> void:
	var format: Dictionary = LeagueRegulations.record("A1").get("format", {})
	_check(not format.is_empty(), "the A1 format loads")
	var stages := CareerStages.stages(format)
	_check(stages.size() == 3, "the format has a regular stage and two groups")

	var rows: Array = []
	for club_id in CLUBS:
		rows.append({"id": club_id})
	var regular_ids := CareerStages.resolve_entrants(stages[0], rows)
	_check(regular_ids.size() == 12, "the regular stage takes all 12 clubs")
	var regular := CareerStages.build_stage(stages[0], regular_ids,
		"2026-08-01", "2027-03-01")
	_check(regular.size() == 132, "the format's regular stage is 22 rounds")
	var table := CareerStages.table(regular, _results(regular), regular_ids)
	_check(str(table[0].id) == "C00" and int(table[0].points) == 66,
		"the regular table is built from the format")

	var championship_ids := CareerStages.resolve_entrants(stages[1], table)
	_check(championship_ids.size() == 6 and str(championship_ids[0]) == "C00",
		"the championship group takes the top six")
	var taken := {}
	for club_id in championship_ids:
		taken[str(club_id)] = true
	var relegation_ids := CareerStages.resolve_entrants(stages[2], table, taken)
	_check(relegation_ids.size() == 6 and str(relegation_ids[0]) == "C06",
		"the relegation group takes the rest")

	var carried := CareerStages.carry(table, format.get("carry", {}))
	var group := CareerStages.build_stage(stages[1], championship_ids,
		"2027-03-08", "2027-05-17")
	_check(group.size() == 30, "the championship group is 10 rounds")
	var group_table := CareerStages.table(group, _results(group), championship_ids,
		carried)
	_check(str(group_table[0].id) == "C00" and int(group_table[0].points) == 96,
		"the format's carry feeds the group table")
	_check(str(format.get("champion", "")) == "stage:championship",
		"the format names the championship group as the title stage")

	print("== check_stage_format: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
