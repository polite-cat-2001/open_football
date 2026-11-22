extends SceneTree
# Headless check for a career club eliminated in the knockout: the rest of the
# bracket is simulated by date while the season is still running, not deferred to
# the season transition. After the club loses its play-off, later rounds appear and
# the final stores a champion without calling the season-end resolver.
#
# Run:  godot --headless --path . -s res://tests/check_career_knockout_elimination.gd

const CLUB := 583

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
	var career := CareerFactory.create(catalog, CLUB, "Eliminated", 189, 42, "real")
	_check(career != null, "a real-mode career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var ratings := {}
	for club_id in CareerEurope.fields().get("ucl", []):
		ratings[str(club_id)] = float(
			catalog.load_team_rating(int(club_id)).get("average", 55.0))
	var results := {}
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) == "ucl":
			results[str(fixture.get("id", ""))] = CareerSeason.simulate(
				career.seed, fixture, ratings)
	career.data["results"] = results
	CareerSeason.next_fixture(career)
	var playoff := _round(career, 1)
	_check(playoff.size() == 16, "the play-off is created")
	var own: Array = []
	for fixture in playoff:
		if str(fixture.get("home", "")) == str(CLUB) \
				or str(fixture.get("away", "")) == str(CLUB):
			own.append(fixture)
	_check(own.size() == 0 or own.size() == 2,
		"the career club is either in the play-off or already out")
	for fixture in own:
		var home := str(fixture.get("home", "")) == str(CLUB)
		results[str(fixture.get("id", ""))] = {"home": 0, "away": 3} if home \
			else {"home": 3, "away": 0}
	career.data["results"] = results
	for step in range(5):
		CareerEurope.simulate_due(career, catalog, "2027-06-01")
	var rounds := 0
	for index in range(1, 6):
		if not _round(career, index).is_empty():
			rounds += 1
	_check(rounds == 5, "all five rounds exist after the club is out: %d" % rounds)
	var block: Dictionary = career.data.get("continental", {}).get(
		career.season_start, {})
	var competition: Dictionary = block.get("competitions", {}).get("ucl", {})
	_check(not str(competition.get("champion", "")).is_empty(),
		"the champion is decided without the season-end resolver")
	_check(str(competition.get("champion", "")) != str(CLUB),
		"the eliminated club is not the champion")
	_finish()


func _finish() -> void:
	print("== check_career_knockout_elimination: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
