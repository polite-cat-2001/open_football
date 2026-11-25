extends SceneTree
# Headless check for the pyramid movement: how many clubs leave a league through
# the boundary above and below, taken from the audited `up_total`/`down_total`.
#
# Run:  godot --headless --path . -s res://tests/check_pyramids.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	print("== check_pyramids: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_check(CareerPyramids.has_record("GB2"), "the Championship has a pyramid record")
	_check(CareerPyramids.promotion_places("GB2") == 3,
		"three clubs leave the Championship upwards")
	_check(CareerPyramids.relegation_places("GB2") == 3,
		"three clubs leave the Championship downwards")
	_check(CareerPyramids.playoff_places("GB2", true) == 1,
		"one of the promotion places is a play-off")

	_check(CareerPyramids.promotion_places("GB1") == 0,
		"the top flight has no promotion above it")
	_check(CareerPyramids.relegation_places("GB1") == 3,
		"the Premier League sends three clubs down")

	# A league whose boundary is not symmetrical: the audited pair is 3 up / 2
	# down, clamped to two so the top flight keeps its size.
	_check(CareerPyramids.relegation_places("ALB2") == 0,
		"the Albanian second tier is the pyramid floor")

	_check(CareerPyramids.relegation_places("CLPD") == 2,
		"the Chilean top flight really sends two clubs down")

	_check(CareerPyramids.promotion_places("ES2") == 3,
		"LaLiga 2 promotes three clubs")
	_check(CareerPyramids.relegation_places("ES2") == 4,
		"LaLiga 2 sends four clubs down")
	_check(CareerPyramids.relegation_places("ES1") == 3,
		"LaLiga sends three clubs down")
	_check(CareerPyramids.promotion_places("ES1") == 0,
		"there is nothing above LaLiga")

	# The two sides of a boundary move the same number of clubs, so no league
	# changes size season after season. Albania is the one audited imbalance
	# (3 up / 2 down mid-reform) and is clamped to the smaller side.
	_check(CareerPyramids.promotion_places("ALB2") == 2,
		"Albania promotes the number the top flight can take")
	_check(CareerPyramids.relegation_places("ALB1") == 2,
		"Albania relegates the same number")

	# A league the pyramid does not know keeps the engine default, so a career
	# never stalls on missing research.
	_check(CareerPyramids.promotion_places("CLI") == CareerPyramids.DEFAULT
		and CareerPyramids.relegation_places("CLI") == CareerPyramids.DEFAULT,
		"an unknown league keeps the engine default")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var teams: Array = catalog.all_teams_for_league("CLPD")
	if teams.is_empty():
		_finish()
		return
	var career := CareerFactory.create(catalog,
		int(str((teams[0] as Dictionary).get("id", "0"))), "Pyramid", 189, 21)
	_check(career != null, "a Chilean career is created: " + CareerFactory.last_error)
	if career != null:
		var snapshot := CareerFactory.snapshot(catalog, career)
		var season: Dictionary = snapshot.get("season", {})
		_check(int(season.get("relegation_places", -1)) == 2,
			"the hub snapshot reports the league's real relegation count")
	_finish()
