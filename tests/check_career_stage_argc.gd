extends SceneTree
# Headless check for the Argentine regular phases and aggregate: both phases are
# built at creation, each club plays 32 matches over the two tables, and the
# season table is the sum of the two regular stages.
#
# Run:  godot --headless --path . -s res://tests/check_career_stage_argc.gd

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
	var best_id := 0
	for team in catalog.all_teams_for_league("ARGC"):
		var team_id := int(team.get("id", 0))
		if best_id == 0 or team_id < best_id:
			best_id = team_id
	career = CareerFactory.create(catalog, best_id, "Stage Manager", 189, 42)
	_check(career != null, "an ARGC career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var apertura := []
	var clausura := []
	for fixture in career.schedule:
		match str(fixture.get("stage", "")):
			"apertura_regular":
				apertura.append(fixture)
			"clausura_regular":
				clausura.append(fixture)
	_check(apertura.size() == 240, "the Apertura regular has 240 fixtures")
	_check(clausura.size() == 240, "the Clausura regular has 240 fixtures")
	_check(int(career.data.get("stages_generated", {}).get("apertura_regular", "") != ""),
		"the Apertura regular is marked as generated")
	_check(int(career.data.get("stages_generated", {}).get("clausura_regular", "") != ""),
		"the Clausura regular is marked as generated")

	if not (career.data.get("results") is Dictionary):
		career.data["results"] = {}
	for fixture in apertura + clausura:
		career.data["results"][str(fixture.get("id", ""))] = _result(fixture)
	var aggregate := CareerFactory.season_table(career, {})
	_check(aggregate.size() == 30, "the aggregate table has 30 rows")
	_check(int(aggregate[0].get("played", 0)) == 32,
		"the aggregate counts both 16-match phases")
	_check(int(aggregate[0].get("points", 0)) == 96,
		"the top club wins both phases")

	var arg2_ids := {}
	for team in catalog.all_teams_for_league("ARG2"):
		arg2_ids[str(team.get("id", ""))] = true
	var transition := CareerSeason.transition(catalog, career)
	_check(not transition.is_empty(), "the ARGC season transitions: " + CareerSeason.last_error)
	var review: Dictionary = transition.get("review", {})
	var relegated: Array = review.get("relegated", [])
	_check(relegated.size() == 2, "the aggregate bottom two are relegated")
	var next_ids: Array = transition.get("league_club_ids", [])
	_check(next_ids.size() == 30, "the league keeps its 30 clubs")
	var relegated_ids := {}
	for row in relegated:
		relegated_ids[str(row.get("id", ""))] = true
		_check(not next_ids.has(str(row.get("id", ""))), "a relegated club leaves the league")
	var incoming: Array = review.get("next", {}).get("from_below", [])
	_check(incoming.size() == 2, "two ARG2 clubs come up")
	for entry in incoming:
		var club_id := str(entry.get("club", {}).get("id", ""))
		_check(arg2_ids.has(club_id), "the incoming club belongs to ARG2")
		_check(next_ids.has(club_id), "the incoming club joins the league")

	_finish()


func _finish() -> void:
	print("== check_career_stage_argc: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
