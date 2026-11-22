extends SceneTree
# Headless check for the continental league phase fixtures: eight rounds of
# eighteen matches, every club plays eight different opponents with four home
# and four away games, and the European dates keep three days from the league.
# Also checks the league table built from those fixtures.
#
# Run:  godot --headless --path . -s res://tests/check_continental_fixtures.gd

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
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var league_ids: Array = []
	for team in catalog.all_teams_for_league("ES1"):
		league_ids.append(str(team.get("id", "")))
	if league_ids.size() < 20:
		_check(false, "La Liga is in the database")
		_finish()
		return
	var clubs: Array = league_ids.duplicate()
	for league in ["ES2", "E3G1", "E3G2", "E4G2"]:
		for team in catalog.all_teams_for_league(league):
			if clubs.size() >= 36:
				break
			var club_id := str(team.get("id", ""))
			if not clubs.has(club_id):
				clubs.append(club_id)
		if clubs.size() >= 36:
			break
	_check(clubs.size() == 36, "the synthetic field has 36 clubs: %d" % clubs.size())
	var continental := {"competitions": {"ucl": {"league_phase": clubs}}}
	var built := CareerCompetitions.build_season(catalog, "ES1", league_ids,
		"2026-08-15", {}, continental, clubs[0])
	var schedule: Array = built.get("schedule", [])
	var euro := []
	var league_dates := {}
	for fixture in schedule:
		if str(fixture.get("competition", "")) == "ucl":
			euro.append(fixture)
		elif str(fixture.get("competition", "")) == "ES1":
			league_dates[str(fixture.get("date", ""))] = true
	_check(euro.size() == 144, "the league phase has 144 fixtures: %d" % euro.size())
	var rounds := {}
	var opponents := {}
	var home := {}
	var away := {}
	for fixture in euro:
		rounds[int(fixture.get("stage_round", 0))] = true
		var home_id := str(fixture.get("home", ""))
		var away_id := str(fixture.get("away", ""))
		home[home_id] = int(home.get(home_id, 0)) + 1
		away[away_id] = int(away.get(away_id, 0)) + 1
		var played: Dictionary = opponents.get(home_id, {})
		played[away_id] = true
		opponents[home_id] = played
		var reverse: Dictionary = opponents.get(away_id, {})
		reverse[home_id] = true
		opponents[away_id] = reverse
	_check(rounds.size() == 8, "the league phase has eight rounds")
	var bad: Array = []
	for club_id in clubs:
		if int(opponents.get(club_id, {}).size()) != 8:
			bad.append("opponents:" + str(club_id))
		if int(home.get(club_id, 0)) != 4 or int(away.get(club_id, 0)) != 4:
			bad.append("home/away:" + str(club_id))
	_check(bad.is_empty(), "every club has 8 opponents and 4+4 home/away: " + str(bad.slice(0, 3)))
	var overlap: Array = []
	for fixture in euro:
		var date := str(fixture.get("date", ""))
		for league_date in league_dates:
			if absi(CareerSeason.days_between(date, str(league_date))) < 3:
				overlap.append("%s/%s" % [date, league_date])
	_check(overlap.is_empty(), "European days keep three days from the league: "
		+ str(overlap.slice(0, 2)))

	var world := Career.new({
		"seed": 7, "club_id": clubs[0], "league_id": "ES1",
		"season_start": "2026-08-15", "league_club_ids": league_ids,
		"schedule": schedule, "results": {},
	})
	for fixture in euro:
		world.data["results"][str(fixture.get("id", ""))] = \
			CareerSeason.simulate(7, fixture, {})
	var table := CareerContinental.table(world, "ucl")
	_check(table.size() == 36, "the continental table has 36 rows")
	_check(int(table[0].get("played", 0)) == 8,
		"the continental table counts eight matches")

	_finish()


func _finish() -> void:
	print("== check_continental_fixtures: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
