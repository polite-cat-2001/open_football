extends SceneTree
# Re-runs the season day by day (so split-stage leagues build their phases and
# the world is simulated) for the countries whose one-shot run left an empty
# table, then checks that the next season builds the super cup.
#
# Run:  godot --headless --path . -s res://tests/run_super_cup_seasons_daily.gd

const RETRY := ["Ecuador", "Peru", "Venezuela", "Bulgaria", "Cyprus", "Gibraltar",
	"Greece", "Iceland", "Israel", "Malta", "Moldova", "Northern Ireland", "Romania"]

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
		if not RETRY.has(country):
			continue
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
		var season_end := CareerSeason.season_end(career)
		var day := 0
		var season_over := false
		while day < 420 and career.date < season_end:
			day += 1
			var date := CareerSeason.add_days(career.date, 1)
			career.data["date"] = date
			for fixture in career.schedule:
				if str(fixture.get("date", "")) != date:
					continue
				if career.results.has(str(fixture.get("id", ""))):
					continue
				var home := str(fixture.get("home", ""))
				if home != str(club_id) and str(fixture.get("away", "")) != str(club_id):
					continue
				career.data["results"][str(fixture.get("id", ""))] = \
					{"home": 2, "away": 0} if home == str(club_id) else {"home": 0, "away": 2}
			if not season_over:
				if not CareerSeason.advance_to(career, date, clubs, strengths):
					season_over = true
					CareerAdvance.tick(career, catalog, date)
			else:
				CareerAdvance.tick(career, catalog, date)
		# Fixtures created late (cup replays, added stages) can be dated in the
		# past; play every remaining club fixture before the transition.
		for fixture in career.schedule:
			if career.results.has(str(fixture.get("id", ""))):
				continue
			var home := str(fixture.get("home", ""))
			if home != str(club_id) and str(fixture.get("away", "")) != str(club_id):
				continue
			career.data["results"][str(fixture.get("id", ""))] = \
				{"home": 2, "away": 0} if home == str(club_id) else {"home": 0, "away": 2}
		if career.date < season_end:
			CareerSeason.advance_days(career, season_end)
		var transition := CareerSeason.transition(catalog, career)
		if transition.is_empty():
			print("FAIL ", competition_id, " (no transition: ", CareerSeason.last_error, ") days ", day)
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
		print("OK   " if built else "SKIP ", competition_id, " | ", country,
			"" if built else " (not built)")
	print("== daily super cup seasons: ", checked, " checked, ", failures.size(),
		" failures ==")
	quit(0 if failures.is_empty() else 1)
