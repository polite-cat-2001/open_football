extends SceneTree
# Headless check for the Godot-side SQLite team catalog: it must read leagues and
# teams straight from the database (no C++ catalog), match the manifest coverage,
# keep the selection in the shell state, and fail with a readable message when the
# database is missing or corrupt.
#
# Run:  godot --headless --path . -s res://tests/check_team_catalog.gd

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
	var catalog := TeamCatalog.new()
	var root := catalog.resolve_data_root()
	print("data root: ", root)
	_check(catalog.load_data_root(root), "catalog loads from the database: " + catalog.error)
	if not catalog.error.is_empty():
		_finish()
		return

	var coverage := catalog.read_manifest_coverage(root)
	_check(not coverage.is_empty(), "manifest coverage is readable")
	_check(int(coverage.get("leagues", -1)) == catalog.leagues.size(),
		"league count matches the manifest (%d)" % catalog.leagues.size())
	_check(int(coverage.get("teams", -1)) == catalog.teams.size(),
		"team count matches the manifest (%d)" % catalog.teams.size())

	var grouped := 0
	var names_ok := true
	var leagues_ok := true
	var countries_ok := true
	for league in catalog.leagues:
		grouped += catalog.teams_for_league(int(league["id"])).size()
		if str(league["name"]).is_empty():
			leagues_ok = false
		if int(league["country_id"]) != 0 and str(league["country"]).is_empty():
			countries_ok = false
	_check(leagues_ok, "every league has a name")
	_check(countries_ok, "every country-linked league resolves its country name")
	for team in catalog.teams:
		if str(team["name"]).is_empty():
			names_ok = false
	_check(names_ok, "every team has a name")
	_check(grouped == catalog.teams.size(), "every team belongs to exactly one league")

	var known := catalog.team_by_id(3)
	_check(not known.is_empty() and not str(known["name"]).is_empty(),
		"a known team id resolves to a real team (%s)" % str(known.get("name", "")))
	var known_league := catalog.league_by_id(int(known.get("league_id", 0)))
	_check(not known_league.is_empty() and not catalog.teams_for_league(int(known_league["id"])).is_empty(),
		"that team's league is present in the league list")

	ShellState.clear()
	_check(not ShellState.has_selection(), "shell state starts without a selection")
	ShellState.set_teams(catalog.teams[0], catalog.teams[1])
	_check(ShellState.has_selection(), "shell state keeps a two-team selection")
	_check(int(ShellState.home_team["id"]) == int(catalog.teams[0]["id"]),
		"shell state keeps the home team")
	_check(int(ShellState.away_team["id"]) == int(catalog.teams[1]["id"]),
		"shell state keeps the away team")
	ShellState.clear()

	_check_missing_database()
	_check_corrupt_database()
	_finish()


func _check_missing_database() -> void:
	var catalog := TeamCatalog.new()
	var missing_root := "user://__team_catalog_missing"
	_check(not catalog.load_data_root(missing_root), "a missing database is rejected")
	_check(catalog.error.contains("not found") and catalog.error.contains("GPF_DATA_ROOT"),
		"the missing database message explains where to point GPF_DATA_ROOT")


func _check_corrupt_database() -> void:
	var corrupt_root := "user://__team_catalog_corrupt"
	var database_dir := corrupt_root.path_join("databases/default")
	DirAccess.make_dir_recursive_absolute(database_dir)
	var file := FileAccess.open(database_dir.path_join("database.sqlite"), FileAccess.WRITE)
	if file != null:
		file.store_string("this is definitely not a sqlite database")
		file.close()

	var catalog := TeamCatalog.new()
	_check(not catalog.load_data_root(corrupt_root), "a corrupt database is rejected")
	_check(catalog.error.contains("could not be read"),
		"the corrupt database message says it could not be read: " + catalog.error)
	_check(catalog.leagues.is_empty() and catalog.teams.is_empty(),
		"a corrupt database leaves no half-loaded catalog")

	DirAccess.remove_absolute(database_dir.path_join("database.sqlite"))
	DirAccess.remove_absolute(database_dir)
	DirAccess.remove_absolute(corrupt_root.path_join("databases"))
	DirAccess.remove_absolute(corrupt_root)


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: team catalog")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
