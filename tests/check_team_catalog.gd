extends SceneTree
# Headless check for the lazy Godot-side SQLite team catalog: opening validates
# the database, countries/leagues/teams are fetched on demand, squads/ratings
# only for the selected team, and errors stay readable.

const KNOWN_TEAM := 3

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
	_check(catalog.load_data_root(root), "catalog opens the database: " + catalog.error)
	if not catalog.error.is_empty():
		_finish()
		return
	_check(catalog.is_loaded(), "the catalog keeps its reader open")

	var countries := catalog.countries()
	_check(not countries.is_empty(), "countries are fetched on demand")
	var sorted := true
	for index in range(1, countries.size()):
		if str(countries[index - 1].get("name", "")) > str(countries[index].get("name", "")):
			sorted = false
	_check(sorted, "countries are sorted by name")

	var first_country := int(countries[0].get("id", 0))
	var leagues := catalog.leagues_for_country(first_country)
	_check(not leagues.is_empty(), "a country lists its leagues on demand")
	_check(not str(leagues[0].get("name", "")).is_empty(), "every league has a name")
	_check(str(leagues[0].get("country", "")) == str(countries[0].get("name", "")),
		"a league resolves its country name")

	var first_league := int(leagues[0].get("id", 0))
	var teams := catalog.teams_for_league(first_league)
	_check(not teams.is_empty(), "a league lists its teams on demand")
	var names_ok := true
	for team in teams:
		if str(team.get("name", "")).is_empty():
			names_ok = false
	_check(names_ok, "every team has a name")

	var known := catalog.team_by_id(KNOWN_TEAM)
	_check(not known.is_empty() and not str(known.get("name", "")).is_empty(),
		"a known team id resolves to a real team (%s)" % str(known.get("name", "")))
	var known_league := catalog.league_by_id(int(known.get("league_id", 0)))
	_check(not known_league.is_empty(), "its league resolves by id")
	_check(catalog.teams_for_league(int(known_league.get("id", 0))).any(
		func(team: Dictionary) -> bool: return int(team.get("id", 0)) == KNOWN_TEAM),
		"the known team is in its league's list")

	var national := catalog.national_league_id()
	_check(national > 0, "the National Teams league is found")
	_check(not catalog.teams_for_league(national).is_empty(),
		"national teams are listed on demand")

	var squad := catalog.load_squad(KNOWN_TEAM)
	_check(not squad.is_empty() and (squad.get("players", []) as Array).size() >= 11,
		"a squad is loaded only for the selected team")
	_check(catalog.can_field_eleven(KNOWN_TEAM), "the known team can field eleven")
	_check(not catalog.can_field_eleven(387),
		"a team with fewer than eleven players is rejected on ready")
	_check(not catalog.teams_for_league(21).any(
		func(team: Dictionary) -> bool: return int(team.get("id", 0)) == 387),
		"listing filters teams that cannot field eleven")
	var listed_fieldable := true
	for team in catalog.teams_for_league(21):
		if not catalog.can_field_eleven(int(team.get("id", 0))):
			listed_fieldable = false
			break
	_check(listed_fieldable, "every listed team can field eleven")
	var rating := catalog.load_team_rating(KNOWN_TEAM)
	_check(not rating.is_empty(), "the selected team's rating is computed")
	_check(float(rating.get("stars", 0.0)) >= 0.5 and float(rating.get("stars", 0.0)) <= 5.0,
		"stars are in 0.5..5")
	for line in ["attack", "midfield", "defence"]:
		_check(int(rating.get(line, -1)) >= 1 and int(rating.get(line, -1)) <= 100,
			"%s is a 1..100 rating" % line)
	_check(catalog.load_team_rating(KNOWN_TEAM) == rating,
		"ratings are cached by team id")

	var coverage := catalog.read_manifest_coverage(root)
	_check(not coverage.is_empty(), "manifest coverage is readable")
	_check(int(coverage.get("leagues", 0)) > 0 and int(coverage.get("teams", 0)) > 0,
		"the manifest describes a populated database")

	_check_rating_math()

	ShellState.clear()
	_check(not ShellState.has_selection(), "shell state starts without a selection")
	ShellState.set_teams(known, catalog.team_by_id(4))
	_check(ShellState.has_selection(), "shell state keeps a two-team selection")
	_check(int(ShellState.home_team["id"]) == KNOWN_TEAM,
		"shell state keeps the home team")
	ShellState.clear()

	_check_missing_database()
	_check_corrupt_database()
	_finish()


func _check_rating_math() -> void:
	_check(is_equal_approx(TeamRatings.stars_for(59.0), 1.0), "59 average is one star")
	_check(is_equal_approx(TeamRatings.stars_for(80.0), 4.0), "80 average is four stars")
	_check(is_equal_approx(TeamRatings.stars_for(100.0), 5.0), "100 average is five stars")
	var players := [
		{"role": "CF", "base_stat": 0.90},
		{"role": "ST", "base_stat": 0.80},
		{"role": "LW", "base_stat": 0.70},
		{"role": "CM", "base_stat": 0.75},
		{"role": "DM", "base_stat": 0.65},
		{"role": "CB", "base_stat": 0.85},
		{"role": "LB", "base_stat": 0.60},
		{"role": "RB", "base_stat": 0.55},
	]
	var rating := TeamRatings.from_players(players)
	_check(rating.get("attack", 0) == 80, "attack is the best three attacking roles")
	_check(rating.get("midfield", 0) == 70, "midfield is the best three midfield roles")
	_check(rating.get("defence", 0) == 67, "defence is the best four defensive roles")
	_check(not TeamRatings.from_players([]).size(), "an empty squad has no rating")


func _check_missing_database() -> void:
	var catalog := TeamCatalog.new()
	var missing_root := "user://__team_catalog_missing"
	_check(not catalog.load_data_root(missing_root), "a missing database is rejected")
	_check(catalog.error.contains("not found") and catalog.error.contains("GPF_DATA_ROOT"),
		"the missing database message explains where to point GPF_DATA_ROOT")
	_check(catalog.countries().is_empty(), "a rejected database returns no countries")


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
	_check(catalog.countries().is_empty(), "a corrupt database leaves no half-loaded catalog")

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
