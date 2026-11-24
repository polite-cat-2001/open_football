extends SceneTree
# Headless check for the qualifying calendar: the career club's first two-legged
# tie is added to the schedule with July dates, one match per leg, and when both
# legs are played the actual winner is written to the forced map.
#
# Run:  godot --headless --path . -s res://tests/check_qualifying_calendar.gd

const CLUB := "583"
const OPPONENT := "418"

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
	var career := CareerFactory.create(catalog, int(CLUB), "Qualifying", 189, 42, "real")
	_check(career != null, "a career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var block: Dictionary = career.data.get("continental", {}).get(
		career.season_start, {})
	block["qualifying_pending"] = true
	block["qualifying_focus"] = CLUB
	block["qualifying_competition"] = "CL"
	block["focus_fixtures"] = [
		{"id": "q:q1:main:tie:00:0", "home": CLUB, "away": OPPONENT,
			"tie": "tie:00", "leg": 0, "europe": "CL",
			"qualifying_round": "q1", "qualifying_path": "main"},
		{"id": "q:q1:main:tie:00:1", "home": OPPONENT, "away": CLUB,
			"tie": "tie:00", "leg": 1, "europe": "CL",
			"qualifying_round": "q1", "qualifying_path": "main"},
	]
	career.data["continental"][career.season_start] = block
	var added := CareerEurope.qualifying_fixtures(career, catalog)
	_check(added.size() == 2, "the first qualifying round has two legs")
	var scheduled: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "euroq:CL":
			scheduled.append(fixture)
	_check(scheduled.size() == 2, "both legs are in the schedule")
	var dates: Array = []
	for fixture in scheduled:
		dates.append(str(fixture.get("date", "")))
	dates.sort()
	_check(dates.size() == 2 and dates[0] >= "2026-07-01" and dates[1] <= "2026-07-31",
		"the legs are dated in July: " + str(dates))
	var results := {}
	for fixture in scheduled:
		results[str(fixture.get("id", ""))] = {"home": 1, "away": 0}
	career.data["results"] = results
	CareerEurope.ensure_qualifying(career, catalog)
	var forced: Dictionary = career.data.get("europe_forced", {})
	_check(forced.has(CareerEurope._pair_key(CLUB, OPPONENT)),
		"the played tie writes the actual winner")
	var league := CareerFactory.create(catalog, int(CLUB), "League Phase", 189, 42,
		"none")
	_check(league != null, "a no-Europe career is created: "
		+ CareerFactory.last_error)
	if league != null:
		var field: Array = CareerEurope.fields().get("CL", [])
		var league_block := {
			"qualifying_pending": false,
			"competitions": {"CL": {"league_phase": field, "round_count": 8,
				"coefficients": {}}},
		}
		league.data["continental"][league.season_start] = league_block
		CareerEurope.ensure_league_phase(league, catalog)
		var count := 0
		for fixture in league.schedule:
			if str(fixture.get("competition", "")) == "CL":
				count += 1
		_check(count == 144, "the league phase has 144 fixtures: %d" % count)
	_finish()


func _finish() -> void:
	print("== check_qualifying_calendar: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
