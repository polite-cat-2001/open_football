extends SceneTree
# Headless check for a split league with format-driven movement: Denmark's
# second tier plays a regular season, then a promotion and a relegation group;
# the top two of the promotion group go up, the bottom two of the relegation
# group go down, and the league keeps its size. Also checks the promotion up
# path: a promoted career club moves to the league above.
#
# Run:  godot --headless --path . -s res://tests/check_career_stage_dk2.gd

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
	var teams := catalog.all_teams_for_league("DK2")
	_check(teams.size() >= 8, "the database has a Danish second tier: %d" % teams.size())
	if teams.size() < 8:
		_finish()
		return
	var best_id := int(teams[0].get("id", 0))
	for team in teams:
		best_id = mini(best_id, int(team.get("id", 0)))
	var career := CareerFactory.create(catalog, best_id, "Stage Manager", 189, 42)
	_check(career != null, "a DK2 career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	for guard in range(12):
		CareerFactory.ensure_stages(career)
		if not (career.data.get("results") is Dictionary):
			career.data["results"] = {}
		var pending := []
		for fixture in career.schedule:
			if not career.results.has(str(fixture.get("id", ""))):
				pending.append(fixture)
		if pending.is_empty():
			break
		for fixture in pending:
			career.data["results"][str(fixture.get("id", ""))] = _result(fixture)
	var groups := 0
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) in ["promotion", "relegation"]:
			groups += 1
	_check(groups == 60, "the two six-club groups add 60 fixtures: %d" % groups)
	_check(CareerSeason.next_fixture(career).is_empty(),
		"the split season is complete")

	var transition := CareerSeason.transition(catalog, career)
	_check(not transition.is_empty(),
		"the Danish season transitions: " + CareerSeason.last_error)
	if transition.is_empty():
		_finish()
		return
	var review: Dictionary = transition.get("review", {})
	var promoted: Array = review.get("promoted", [])
	var relegated: Array = review.get("relegated", [])
	_check(promoted.size() == 2, "the promotion group sends two clubs up")
	_check(relegated.size() == 2, "the relegation group sends two clubs down")
	var promoted_ids := {}
	for row in promoted:
		promoted_ids[str(row.get("club_id", ""))] = true
	var relegated_ids := {}
	for row in relegated:
		relegated_ids[str(row.get("club_id", ""))] = true
	var next_ids: Array = transition.get("league_club_ids", [])
	_check(next_ids.size() == career.league_club_ids.size(),
		"the league keeps its size: %d" % next_ids.size())
	_check(review.get("next", {}).get("from_below", []).size() == 2
		or str(review.get("movement", "")) == "down",
		"the league is refilled from below")
	if promoted_ids.has(career.club_id):
		_check(str(review.get("movement", "")) == "up",
			"a promoted career club moves up")
		_check(str(transition.get("league_id", "")) != "DK2",
			"the career club changes league")
	elif relegated_ids.has(career.club_id):
		_check(str(review.get("movement", "")) == "down",
			"a relegated career club moves down")
	else:
		_check(review.get("movement") == null,
			"a staying career club keeps its league")

	_finish()


func _finish() -> void:
	print("== check_career_stage_dk2: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
