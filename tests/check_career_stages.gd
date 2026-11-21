extends SceneTree
# Headless check for the stage engine on the Austrian split: a 12-club regular
# double round-robin, a 6+6 cut, full points carried into each group, and the
# championship-group winner as champion.
#
# Run:  godot --headless --path . -s res://tests/check_career_stages.gd

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
	# The lower-ranked club always wins 2-0, so the table is deterministic.
	var results := {}
	for fixture in fixtures:
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		results[str(fixture.get("id", ""))] = (
			{"home": 2, "away": 0} if home < away else {"home": 0, "away": 2})
	return results


func _run() -> void:
	var regular := CareerFactory.build_schedule(CLUBS, "2026-08-01", "2027-03-01")
	_check(regular.size() == 132, "12 clubs play a 22-round double round-robin")
	var table := CareerStages.table(regular, _results(regular), CLUBS)
	_check(table.size() == 12, "the regular table has 12 rows")
	_check(str(table[0].id) == "C00" and int(table[0].points) == 66,
		"the top club has 22 wins")
	_check(str(table[-1].id) == "C11" and int(table[-1].points) == 0,
		"the bottom club has no points")
	_check(int(table[0].played) == 22, "the regular table counts 22 matches")

	var groups := CareerStages.split(table, [6, 6])
	_check(groups.size() == 2 and groups[0].size() == 6 and groups[1].size() == 6,
		"the table is cut into 6 and 6")
	_check(str(groups[0][0].id) == "C00" and str(groups[1][0].id) == "C06",
		"the cut keeps the top six and the bottom six")

	var carried := CareerStages.carry(table, {"points": "full", "goals": "carry"})
	var championship_ids: Array = []
	for row in groups[0]:
		championship_ids.append(str(row.id))
	var group_fixtures := CareerFactory.build_schedule(championship_ids,
		"2027-03-08", "2027-05-17")
	_check(group_fixtures.size() == 30, "six clubs play a 10-round double round-robin")
	var championship := CareerStages.table(group_fixtures, _results(group_fixtures),
		championship_ids, carried)
	_check(championship.size() == 6, "the championship group has six rows")
	_check(str(championship[0].id) == "C00" and int(championship[0].points) == 96,
		"the regular points are carried and the top club wins the group")
	_check(int(championship[0].played) == 32, "the group table shows 32 matches")
	_check(int(championship[0].goals_for) == 64,
		"the goals are carried with the points")
	_check(str(CareerStages.champion(championship).id) == "C00",
		"the group winner is the champion")

	var bottom_ids: Array = []
	for row in groups[1]:
		bottom_ids.append(str(row.id))
	var bottom_fixtures := CareerFactory.build_schedule(bottom_ids,
		"2027-03-08", "2027-05-17")
	var bottom := CareerStages.table(bottom_fixtures, _results(bottom_fixtures),
		bottom_ids, carried)
	_check(str(bottom[0].id) == "C06" and int(bottom[0].points) == 60,
		"the bottom group carries its own regular points")

	print("== check_career_stages: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
