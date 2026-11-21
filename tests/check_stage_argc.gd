extends SceneTree
# Headless check for the Argentine two-zone schedule: 15 clubs per zone, 15
# zone rounds plus 2 interzonal rounds = 17 rounds, 16 matches per club.
#
# Run:  godot --headless --path . -s res://tests/check_stage_argc.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	var clubs: Array = []
	for index in range(30):
		clubs.append("C%02d" % index)
	var format: Dictionary = LeagueRegulations.record("ARGC").get("format", {})
	var stages := CareerStages.stages(format)
	_check(stages.size() == 4, "the ARGC format has four stages")
	var fixtures := CareerStages.build_stage(stages[0], clubs,
		"2026-01-22", "2026-05-24")
	_check(fixtures.size() == 240, "the regular stage has 240 fixtures")

	var per_club := {}
	var cross := 0
	var max_round := 0
	for fixture in fixtures:
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		per_club[home] = int(per_club.get(home, 0)) + 1
		per_club[away] = int(per_club.get(away, 0)) + 1
		max_round = maxi(max_round, int(fixture.get("round", 0)))
		if int(fixture.get("group", -1)) < 0:
			cross += 1
	_check(per_club.size() == 30, "every club appears")
	var wrong: Array = []
	for club_id in per_club:
		if int(per_club[club_id]) != 16:
			wrong.append("%s:%d" % [club_id, int(per_club[club_id])])
	_check(wrong.is_empty(), "every club plays 16 matches: " + str(wrong))
	_check(max_round == 17, "the phase runs 17 rounds")
	_check(cross == 30, "two interzonal rounds add 30 fixtures")

	print("== check_stage_argc: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
