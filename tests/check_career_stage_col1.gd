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

	_finish()


func _finish() -> void:
	print("== check_career_stage_col1: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
