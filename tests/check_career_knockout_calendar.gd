extends SceneTree
# Headless check for the knockout in the career calendar. Once the league phase is
# played, the play-off fixtures appear; each following round appears after the
# previous one is complete, and the final stores the champion. The fixtures are
# dated after the league phase and the final has one match.
#
# Run:  godot --headless --path . -s res://tests/check_career_knockout_calendar.gd

const CLUB := 583
const SIZES := [16, 16, 8, 4, 1]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _round(career: Career, round_index: int) -> Array:
	var rows: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "euro:ucl" \
				and int(fixture.get("stage_round", 0)) == round_index:
			rows.append(fixture)
	return rows


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, CLUB, "Knockout Calendar", 189, 42, "real")
	_check(career != null, "a real-mode career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var ratings := {}
	for club_id in CareerEurope.fields().get("ucl", []):
		ratings[str(club_id)] = float(
			catalog.load_team_rating(int(club_id)).get("average", 55.0))
	var results := {}
	var last_league_date := ""
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) == "ucl":
			results[str(fixture.get("id", ""))] = CareerSeason.simulate(
				career.seed, fixture, ratings)
			last_league_date = maxi_date(last_league_date, str(fixture.get("date", "")))
	career.data["results"] = results
	var block: Dictionary = career.data.get("continental", {}).get(
		career.season_start, {})
	var competition: Dictionary = block.get("competitions", {}).get("ucl", {})
	for round_index in range(SIZES.size()):
		CareerSeason.next_fixture(career)
		var fixtures := _round(career, round_index + 1)
		_check(fixtures.size() == SIZES[round_index],
			"round %d has %d fixtures: %d" % [round_index + 1,
				SIZES[round_index], fixtures.size()])
		var after := true
		for fixture in fixtures:
			if str(fixture.get("date", "")) < last_league_date:
				after = false
			results[str(fixture.get("id", ""))] = CareerSeason.simulate(
				career.seed, fixture, ratings)
		career.data["results"] = results
		_check(after, "round %d is after the league phase" % (round_index + 1))
	CareerSeason.next_fixture(career)
	_check(not str(competition.get("champion", "")).is_empty(),
		"the final stores the champion")
	_check((CareerEurope.fields().get("ucl", []) as Array).has(
		str(competition.get("champion", ""))), "the champion is from the field")
	_finish()


func maxi_date(left: String, right: String) -> String:
	return right if right > left else left


func _finish() -> void:
	print("== check_career_knockout_calendar: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
