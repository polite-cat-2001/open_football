extends SceneTree
# Headless check that every shipped cup installs beside its league: the field
# is non-empty, the bracket has the right number of rounds, and no cup day sits
# within three days of a league round. England also checks the second cup.
#
# Run:  godot --headless --path . -s res://tests/check_competition_countries.gd

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
	var cases := [
		{"league": "GB1", "cups": ["ENGFA", "ENGLC"]},
		{"league": "L1", "cups": ["GERPOK"]},
		{"league": "IT1", "cups": ["ITACOP"]},
		{"league": "FR1", "cups": ["FRACOP"]},
		{"league": "ES1", "cups": ["ESCUP"]},
	]
	for case in cases:
		var league_id := str(case["league"])
		var teams := catalog.all_teams_for_league(league_id)
		if teams.is_empty():
			_check(false, "%s has clubs" % league_id)
			continue
		var best_id := int(teams[0].get("id", 0))
		for team in teams:
			best_id = mini(best_id, int(team.get("id", 0)))
		var career := CareerFactory.create(catalog, best_id, "Cup Probe", 189, 7)
		_check(career != null, "%s career is created: %s" % [league_id, CareerFactory.last_error])
		if career == null:
			continue
		var entries = career.data.get("competitions", [])
		_check(entries is Array and entries.size() == 1 + case["cups"].size(),
			"%s has %d competitions: %d" % [league_id, 1 + case["cups"].size(), entries.size()])
		var league_dates := {}
		for fixture in career.schedule:
			if str(fixture.get("competition", "")) == league_id:
				league_dates[str(fixture.get("date", ""))] = true
		for cup_id in case["cups"]:
			var cup: Dictionary = {}
			for entry in entries:
				if str(entry.get("id", "")) == str(cup_id):
					cup = entry
			_check(not cup.is_empty(), "%s has %s" % [league_id, cup_id])
			if cup.is_empty():
				continue
			var field: Array = cup.get("entrants", [])
			var rounds: Array = cup.get("rounds", [])
			var dates: Array = cup.get("dates", [])
			_check(field.size() > 10, "%s field is non-empty: %d" % [cup_id, field.size()])
			_check(rounds.size() >= 4, "%s has a real bracket: %d rounds" % [cup_id, rounds.size()])
			_check(dates.size() >= rounds.size(),
				"%s has a date for every match day: %d/%d" % [cup_id, dates.size(), rounds.size()])
			var first := 0
			var overlap: Array = []
			for fixture in career.schedule:
				if str(fixture.get("competition", "")) != str(cup_id):
					continue
				first += 1
				var date := str(fixture.get("date", ""))
				for league_date in league_dates:
					if absi(CareerSeason.days_between(date, str(league_date))) < 3:
						overlap.append("%s/%s" % [date, league_date])
			_check(first > 0, "%s first round is generated: %d" % [cup_id, first])
			_check(overlap.is_empty(),
				"%s keeps three days from the league: %s" % [cup_id, str(overlap.slice(0, 2))])

	_finish()


func _finish() -> void:
	print("== check_competition_countries: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
