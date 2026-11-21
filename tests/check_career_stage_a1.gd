extends SceneTree
# Headless check for the Austrian format in a real career: creation builds the
# 22-round regular stage, the 6+6 groups appear after the regular results, the
# group table carries the regular points, and the next fixture moves into the
# split.
#
# Run:  godot --headless --path . -s res://tests/check_career_stage_a1.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _result(fixture: Dictionary) -> Dictionary:
	var home := str(fixture.get("home", ""))
	var away := str(fixture.get("away", ""))
	return {"home": 2, "away": 0} if home < away else {"home": 0, "away": 2}


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return

	var career: Career = null
	for team in catalog.all_teams_for_league("A1"):
		career = CareerFactory.create(catalog, int(team.get("id", 0)),
			"Stage Manager", 189, 42)
		if career != null:
			break
	_check(career != null, "an A1 career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var regular := []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "regular":
			regular.append(fixture)
	_check(regular.size() == 132, "the regular stage has 132 fixtures")
	_check(career.data.get("stages_generated", {}).get("regular", "") == "fixtures",
		"the regular stage is marked as generated")

	for fixture in regular:
		if not (career.data.get("results") is Dictionary):
			career.data["results"] = {}
		career.data["results"][str(fixture.get("id", ""))] = _result(fixture)
	var before: int = career.schedule.size()
	CareerFactory.ensure_stages(career)
	_check(career.schedule.size() == before + 60,
		"the 6+6 split adds 60 fixtures")

	var next := CareerSeason.next_fixture(career)
	_check(str(next.get("stage", "")) in ["championship", "relegation"],
		"after the regular season the next fixture is in the split")

	var championship := []
	var relegation := []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "championship":
			championship.append(fixture)
		elif str(fixture.get("stage", "")) == "relegation":
			relegation.append(fixture)
	_check(championship.size() == 30, "the championship group has 30 fixtures")
	_check(relegation.size() == 30, "the relegation group has 30 fixtures")

	for fixture in championship:
		career.data["results"][str(fixture.get("id", ""))] = _result(fixture)
	var table := CareerFactory.stage_table(career, {}, "championship")
	_check(table.size() == 6, "the championship table has six rows")
	_check(int(table[0].get("played", 0)) == 32,
		"the group table carries the 22 regular matches")
	_check(int(table[0].get("points", 0)) == 96,
		"the full points and the group wins are carried")

	_finish()


func _finish() -> void:
	print("== check_career_stage_a1: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
