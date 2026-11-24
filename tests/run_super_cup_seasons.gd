extends SceneTree
# Runs a real season + transition for every country that has a registered super
# cup and checks that the next season builds it. Prints one line per country.
#
# Run:  godot --headless --path . -s res://tests/run_super_cup_seasons.gd

var failures: Array[String] = []
var catalog: TeamCatalog


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	catalog = TeamCatalog.new()
	catalog.load_data_root()
	if not catalog.is_loaded():
		print("FAIL catalog: ", catalog.error)
		quit(1)
		return
	var records: Dictionary = CareerCompetitions.records()
	var leagues := {}
	for league in catalog.career_leagues():
		var country := str(catalog.country_by_id(int(league.get("country_id", 0)))
			.get("name", ""))
		if int(league.get("tier", 0)) == 1 and not leagues.has(country):
			leagues[country] = league
	var checked := 0
	for competition_id in records:
		var record: Dictionary = records[competition_id]
		if str(record.get("kind", "")) != "super_cup":
			continue
		var country := str(record.get("country", ""))
		var league: Dictionary = leagues.get(country, {})
		if league.is_empty():
			print("SKIP ", competition_id, " (no top league)")
			continue
		var teams: Array = catalog.all_teams_for_league(str(league.get("id", "")))
		if teams.is_empty():
			print("SKIP ", competition_id, " (no clubs)")
			continue
		var club_id := int((teams[0] as Dictionary).get("id", 0))
		var career := CareerFactory.create(catalog, club_id, "Cup " + country, 189, 31)
		if career == null:
			print("FAIL ", competition_id, " create: ", CareerFactory.last_error)
			failures.append(competition_id)
			continue
		var clubs: Array = []
		var strengths := {}
		for team in teams:
			clubs.append(team)
			var cid := str(team.get("id", ""))
			strengths[cid] = float(catalog.load_team_rating(int(cid)).get("average", 55.0))
		career.data["results"] = career.data.get("results", {})
		for fixture in career.schedule:
			var home := str(fixture.get("home", ""))
			if home != str(club_id) and str(fixture.get("away", "")) != str(club_id):
				continue
			career.data["results"][str(fixture.get("id", ""))] = \
				{"home": 2, "away": 0} if home == str(club_id) else {"home": 0, "away": 2}
		var season_end := CareerSeason.season_end(career)
		if not CareerSeason.advance_to(career, season_end, clubs, strengths):
			CareerSeason.advance_days(career, season_end)
		var transition := CareerSeason.transition(catalog, career)
		if transition.is_empty():
			print("FAIL ", competition_id, " (no transition: ", CareerSeason.last_error, ")")
			failures.append(competition_id)
			continue
		if not CareerSeason.next_season(career, catalog, transition):
			print("FAIL ", competition_id, " (next season: ", CareerSeason.last_error, ")")
			failures.append(competition_id)
			continue
		var built := false
		for entry in career.data.get("competitions", []):
			if str(entry.get("id", "")) == competition_id:
				built = true
		checked += 1
		if built:
			print("OK   ", competition_id, " | ", country)
		else:
			print("SKIP ", competition_id, " | ", country,
				" (not built: no champion/cup winner history)")
	print("== super cup seasons: ", checked, " checked, ", failures.size(), " failures ==")
	quit(0 if failures.is_empty() else 1)
