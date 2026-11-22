extends SceneTree
# Headless check for the Colombian two-phase career: both 19-round regular
# phases are built, and the Finalización cuadrangulares appear from their own
# source table, starting from zero points.
#
# Run:  godot --headless --path . -s res://tests/check_career_stage_col1.gd

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
	var best_id := 0
	for team in catalog.all_teams_for_league("COL1"):
		var team_id := int(team.get("id", 0))
		if best_id == 0 or team_id < best_id:
			best_id = team_id
	var career := CareerFactory.create(catalog, best_id, "Stage Manager", 189, 42)
	_check(career != null, "a COL1 career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var apertura := []
	var finalizacion := []
	for fixture in career.schedule:
		match str(fixture.get("stage", "")):
			"apertura_regular":
				apertura.append(fixture)
			"finalizacion_regular":
				finalizacion.append(fixture)
	var size := career.league_club_ids.size()
	var expected := 19 * int(size / 2)
	_check(apertura.size() == expected,
		"the Apertura regular has %d fixtures: %d" % [expected, apertura.size()])
	_check(finalizacion.size() == expected,
		"the Finalización regular has %d fixtures: %d" % [expected, finalizacion.size()])

	if not (career.data.get("results") is Dictionary):
		career.data["results"] = {}
	for fixture in apertura + finalizacion:
		career.data["results"][str(fixture.get("id", ""))] = _result(fixture)
	CareerFactory.ensure_stages(career)
	var groups := []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "finalizacion_groups":
			groups.append(fixture)
	_check(groups.size() == 24, "the Finalización cuadrangulares add 24 fixtures")
	for fixture in groups:
		career.data["results"][str(fixture.get("id", ""))] = _result(fixture)
	var table := CareerFactory.stage_table(career, {}, "finalizacion_groups")
	_check(table.size() == 8, "the cuadrangulares table has eight rows")
	_check(int(table[0].get("played", 0)) == 6,
		"the cuadrangulares start from zero and play six matches")

	CareerFactory.ensure_stages(career)
	var final_legs := []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "finalizacion_final":
			final_legs.append(fixture)
	_check(final_legs.size() == 2, "the Finalización final is two legs")
	if final_legs.size() == 2:
		_check(str(final_legs[0].get("date", "")) != str(final_legs[1].get("date", "")),
			"the two final legs have different dates")
		_check(str(final_legs[0].get("home", "")) == str(final_legs[1].get("away", "")),
			"the final legs swap home and away")
	var apertura_knockout := 0
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "apertura_final" \
				and int(fixture.get("stage_round", 0)) == 1:
			apertura_knockout += 1
	_check(apertura_knockout == 8,
		"the Apertura top eight start four two-legged quarter-finals: %d" % apertura_knockout)
	for guard in range(12):
		CareerFactory.ensure_stages(career)
		var pending := []
		for fixture in career.schedule:
			if str(fixture.get("stage", "")) in ["apertura_final", "finalizacion_final"] \
					and not career.results.has(str(fixture.get("id", ""))):
				pending.append(fixture)
		if pending.is_empty():
			break
		for fixture in pending:
			career.data["results"][str(fixture.get("id", ""))] = _result(fixture)
	_check(CareerSeason.next_fixture(career).is_empty(),
		"the knockout rounds complete the Colombian season")

	var transition := CareerSeason.transition(catalog, career)
	_check(not transition.is_empty(),
		"the Colombian season transitions: " + CareerSeason.last_error)
	if not transition.is_empty():
		var review: Dictionary = transition.get("review", {})
		_check(review.get("relegated", []).size() == 2,
			"the aggregate bottom two are relegated")
		var next_ids: Array = transition.get("league_club_ids", [])
		_check(next_ids.size() == career.league_club_ids.size(),
			"the Colombian league keeps its size: %d" % next_ids.size())
		_check(review.get("next", {}).get("from_below", []).size() == 2,
			"two promoted clubs replace them")
		_check(CareerSeason.next_season(career, catalog, transition),
			"the next Colombian season starts: " + CareerSeason.last_error)
		var league_next := 0
		for fixture in career.schedule:
			if str(fixture.get("stage", "")) in ["apertura_regular", "finalizacion_regular"]:
				league_next += 1
		_check(league_next == 342,
			"the next season rebuilds both regular phases: %d" % league_next)

	_finish()


func _finish() -> void:
	print("== check_career_stage_col1: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
