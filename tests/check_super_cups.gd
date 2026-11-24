extends SceneTree
# Headless check for every registered super cup: it must build a valid entry
# from a six-club league history and a cup winner, with the right rounds/legs,
# and a parsable date. Catches malformed imported records without simulating a
# season.
#
# Run:  godot --headless --path . -s res://tests/check_super_cups.gd

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
	print("== check_super_cups: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var catalog := TeamCatalog.new()
	catalog.load_data_root()
	_check(catalog.is_loaded(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
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
			_check(false, "%s: no top league for %s" % [competition_id, country])
			continue
		var rows: Array = []
		for team in catalog.all_teams_for_league(str(league.get("id", ""))):
			rows.append({"club_id": str(team.get("id", ""))})
			if rows.size() >= 6:
				break
		var cup := {"id": str(record.get("cup", "")), "season_start": "2025-07-01",
			"winner": str((rows[-1] as Dictionary).club_id), "runner_up": ""}
		var history := {"league_id": str(league.get("id", "")),
			"season_start": "2025-07-01", "league_rows": rows, "cups": [cup]}
		var entry := CareerCompetitions._super_entry(record, competition_id, history,
			league)
		checked += 1
		if entry.is_empty():
			_check(false, "%s: the entry builds" % competition_id)
			continue
		var teams := int(record.get("teams", 2))
		var rounds: Array = entry.get("rounds", [])
		var expected_rounds := 2 if teams >= 4 else 1
		_check(rounds.size() == expected_rounds,
			"%s: %d round(s)" % [competition_id, expected_rounds])
		if not rounds.is_empty():
			var last: Dictionary = rounds[-1]
			var legs := int(last.get("legs", 1))
			var expected_legs := int(record.get("final_legs", 1)) if teams < 4 else 1
			_check(legs == expected_legs,
				"%s: final legs %d" % [competition_id, expected_legs])
		var start := str(record.get("start_md", ""))
		var parts := start.split("-")
		var valid_date := parts.size() == 2 and parts[0].is_valid_int() \
			and parts[1].is_valid_int() and int(parts[0]) >= 1 and int(parts[0]) <= 12 \
			and int(parts[1]) >= 1 and int(parts[1]) <= 31
		_check(valid_date, "%s: the date is parsable" % competition_id)
		_check((entry.get("entrants", []) as Array).size() == teams,
			"%s: %d entrants" % [competition_id, teams])
	_check(checked >= 45, "at least 45 super cups are checked (%d)" % checked)
	_finish()
