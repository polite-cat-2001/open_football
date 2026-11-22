extends SceneTree
# Headless check for the competition container with the Copa del Rey: the cup
# is installed beside La Liga, its field is every Spanish club in the snapshot,
# its match days keep three days from every league round, the bracket grows
# round by round, the league table ignores cup results, and the next season
# installs a fresh cup. Also checks that the cup survives a save round-trip.
#
# Run:  godot --headless --path . -s res://tests/check_career_competitions.gd

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
	var teams := catalog.all_teams_for_league("ES1")
	_check(teams.size() >= 2, "the database has La Liga: %d" % teams.size())
	if teams.size() < 2:
		_finish()
		return
	var best_id := int(teams[0].get("id", 0))
	for team in teams:
		best_id = mini(best_id, int(team.get("id", 0)))
	var career := CareerFactory.create(catalog, best_id, "Stage Manager", 189, 42)
	_check(career != null, "a La Liga career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var entries = career.data.get("competitions", [])
	_check(entries is Array and entries.size() == 2,
		"the league and one cup are installed: %d" % entries.size())
	var cup: Dictionary = {}
	for entry in entries:
		if str(entry.get("id", "")) == "ESCUP":
			cup = entry
	_check(not cup.is_empty(), "the Copa del Rey is in the save")
	if cup.is_empty():
		_finish()
		return
	_check(cup.get("entrants", []).size() == 154,
		"the cup field is every Spanish club in tiers 1-4: %d" % cup.get("entrants", []).size())
	_check(cup.get("rounds", []).size() == 8,
		"a 256-club bracket has eight rounds: %d" % cup.get("rounds", []).size())
	_check(cup.get("dates", []).size() == 9,
		"the bracket needs nine match days: %d" % cup.get("dates", []).size())

	var cup_fixtures := []
	var league_dates := {}
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) == "ESCUP":
			cup_fixtures.append(fixture)
		elif str(fixture.get("competition", "")) == "ES1":
			league_dates[str(fixture.get("date", ""))] = true
	_check(cup_fixtures.size() == 26,
		"the first cup round has 26 ties and 102 byes: %d" % cup_fixtures.size())
	var overlap: Array = []
	for fixture in cup_fixtures:
		var date := str(fixture.get("date", ""))
		for league_date in league_dates:
			if absi(CareerSeason.days_between(date, str(league_date))) < 3:
				overlap.append("%s/%s" % [date, league_date])
	_check(overlap.is_empty(),
		"cup days keep three days from every league round: " + str(overlap.slice(0, 3)))

	for guard in range(14):
		CareerFactory.ensure_stages(career)
		CareerCompetitions.ensure(career)
		if not (career.data.get("results") is Dictionary):
			career.data["results"] = {}
		var pending := []
		for fixture in career.schedule:
			if not career.results.has(str(fixture.get("id", ""))):
				pending.append(fixture)
		if pending.is_empty():
			break
		for fixture in pending:
			career.data["results"][str(fixture.get("id", ""))] = \
				CareerSeason.simulate(42, fixture, {})
	var rounds_seen := {}
	var cup_total := 0
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) != "ESCUP":
			continue
		cup_total += 1
		rounds_seen[int(fixture.get("stage_round", 0))] = true
	_check(cup_total == 155, "the 154-club knockout includes the two-legged semis: %d" % cup_total)
	_check(rounds_seen.size() == 8, "all eight cup rounds are generated")
	_check(not CareerCompetitions.winner_of(career, "ESCUP").is_empty(),
		"the cup has a winner")
	_check(CareerSeason.next_fixture(career).is_empty(),
		"the cup completes together with the league")

	var clubs := {}
	for club_id in career.league_club_ids:
		var club := catalog.career_club(int(club_id))
		if not club.is_empty():
			clubs[str(club_id)] = club
	var table := CareerFactory.season_table(career, clubs)
	var played: Array = []
	for row in table:
		played.append(int(row.get("played", 0)))
	_check(played.size() == 20 and played.min() == 38 and played.max() == 38,
		"the league table counts 38 league matches, not cup ties")

	var loaded := Career.from_save(career.to_save())
	_check(loaded != null, "the career saves and loads: " + Career.last_error)
	if loaded != null:
		var loaded_cup := 0
		for fixture in loaded.schedule:
			if str(fixture.get("competition", "")) == "ESCUP":
				loaded_cup += 1
		_check(loaded_cup == 155, "the cup fixtures survive the save: %d" % loaded_cup)
		_check(loaded.data.get("competitions", []).size() == 2,
			"the competition list survives the save")

	var transition := CareerSeason.transition(catalog, career)
	_check(not transition.is_empty(),
		"the Spanish season transitions: " + CareerSeason.last_error)
	if not transition.is_empty():
		_check(CareerSeason.next_season(career, catalog, transition),
			"the next Spanish season starts: " + CareerSeason.last_error)
		var next_cup := 0
		for fixture in career.schedule:
			if str(fixture.get("competition", "")) == "ESCUP":
				next_cup += 1
		_check(next_cup == 26, "the next season installs a fresh cup: %d" % next_cup)
		_check(career.data.get("competitions", []).size() == 3,
			"the next season keeps the list and adds the super cup")
		var super_cup: Dictionary = {}
		for item in career.data.get("competitions", []):
			if str(item.get("id", "")) == "ESPSC":
				super_cup = item
		_check(not super_cup.is_empty(), "the Supercopa is installed in the second season")
		if not super_cup.is_empty():
			_check(super_cup.get("entrants", []).size() == 4,
				"the Supercopa has four clubs")
			_check(super_cup.get("rounds", []).size() == 2,
				"the Supercopa has a semi-final and a final")
			_check(super_cup.get("entrants", []).has(str(table[0].get("club_id", ""))),
				"the league champion enters the Supercopa")
			_check(super_cup.get("entrants", []).has(str(cup.get("winner", ""))),
				"the cup winner enters the Supercopa")
		for guard in range(4):
			CareerCompetitions.ensure(career)
			var pending := []
			for fixture in career.schedule:
				if str(fixture.get("competition", "")) == "ESPSC" \
						and not career.results.has(str(fixture.get("id", ""))):
					pending.append(fixture)
			if pending.is_empty():
				break
			for fixture in pending:
				career.data["results"][str(fixture.get("id", ""))] = \
					CareerSeason.simulate(42, fixture, {})
		_check(not CareerCompetitions.winner_of(career, "ESPSC").is_empty(),
			"the Supercopa has a winner")
		var reloaded := Career.from_save(career.to_save())
		_check(reloaded != null, "the season with a super cup saves and loads")
		if reloaded != null:
			_check(CareerCompetitions.winner_of(reloaded, "ESPSC")
				== CareerCompetitions.winner_of(career, "ESPSC"),
				"the super cup winner survives the save")
			_check(reloaded.to_save() == career.to_save(),
				"the season with tables and berths round-trips exactly")
			_check(reloaded.data.get("competition_history", []).size() >= 1,
				"the competition history survives the save")
		var season_berths: Dictionary = career.data.get("berths", {}).get(
			career.season_start, {})
		_check(season_berths.size() >= 50,
			"the next season has the UEFA field: %d associations" % season_berths.size())
		var berth_block: Dictionary = season_berths.get("Spain", {})
		_check(str(berth_block.get("association", "")) == "Spain",
			"the next season has Spanish berths")
		_check(berth_block.get("berths", []).size() == 8,
			"Spain has eight UEFA berths: %d" % berth_block.get("berths", []).size())
		_check(career.data.get("world_seasons", {}).size() >= 1,
			"the background world table is stored")
		_check(career.data.get("world_cups", {}).size() >= 1,
			"the background cup winners are stored")

	_finish()


func _finish() -> void:
	print("== check_career_competitions: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
