extends SceneTree
# Headless check for the tournament intro: the facts are built from the same data
# the engine plays, and each competition is introduced once per career.
#
# Run:  godot --headless --path . -s res://tests/check_career_intro.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _career(club_id: String) -> Career:
	return Career.new({
		"version": Career.SAVE_VERSION,
		"id": "i".repeat(32),
		"seed": 5,
		"date": "2026-07-01",
		"season_start": "2026-07-01",
		"created_at": "2026-07-01T00:00:00.000000Z",
		"updated_at": "2026-07-01T00:00:00.000000Z",
		"manager": {"name": "Intro", "nationality_id": "189", "nationality": "England"},
		"club_id": club_id,
		"player_ids": [],
		"journal": [],
		"balance": 0,
		"schedule": [],
		"results": {},
	})


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return

	var league := CareerIntro.facts(_career("131"), "ES1", catalog)
	_check(str(league.get("kind", "")) == "league", "a league is a league")
	_check(str(league.get("label", "")) == "LaLiga", "the league label comes from the database")
	var league_text := " | ".join(league.get("lines", []))
	_check(league_text.contains("Relegation: 3"), "the league intro names the relegation slots")
	_check(league_text.contains("Aug") and league_text.contains("May"),
		"the league intro names the season window")

	var cup := CareerIntro.facts(_career("131"), "CGB", catalog)
	_check(str(cup.get("kind", "")) == "cup", "a cup is a cup")
	var cup_text := " | ".join(cup.get("lines", []))
	_check(cup_text.contains("knockout"), "the cup intro names the knockout")
	_check(cup_text.contains("Two legs"), "the cup intro names the two-legged rounds")
	_check(str(cup.get("label", "")) == "EFL Cup", "the cup label comes from the records")

	var super_cup := CareerIntro.facts(_career("131"), "SUC", catalog)
	var super_text := " | ".join(super_cup.get("lines", []))
	_check(super_text.contains("4 clubs") and super_text.contains("mini-tournament"),
		"the Supercopa intro names the mini-tournament: " + super_text)

	var uefa := CareerIntro.facts(_career("131"), "CL", catalog)
	var uefa_text := " | ".join(uefa.get("lines", []))
	_check(str(uefa.get("label", "")) == "UEFA Champions League",
		"the Champions League intro names the competition")
	_check(uefa_text.contains("36 clubs") and uefa_text.contains("league-phase"),
		"the Champions League intro names the league phase: " + uefa_text)

	var afc := CareerIntro.facts(_career("131"), "ACLE", catalog)
	var afc_text := " | ".join(afc.get("lines", []))
	_check(str(afc.get("label", "")) == "AFC Champions League Elite",
		"the AFC label comes from the format")
	_check(afc_text.contains("groups of"), "the AFC intro names the groups: " + afc_text)

	var career := _career("131")
	career.data["league_id"] = "ES1"
	career.data["league_club_ids"] = ["131", "418"]
	career.data["schedule"] = [
		{"id": "r01-01", "round": 1, "date": "2026-08-21", "home": "131", "away": "418"},
		{"id": "r02-01", "round": 2, "date": "2026-08-28", "home": "418", "away": "131"},
		{"id": "CDR:l01-00", "round": 1, "date": "2026-09-10", "home": "131",
			"away": "418", "competition": "CDR"},
	]
	career.data["season_start"] = "2026-07-01"
	var league_facts := CareerIntro.facts(career, "ES1", catalog)
	var league_facts_text := " | ".join(league_facts.get("lines", []))
	_check(league_facts_text.contains("2 clubs") and league_facts_text.contains("2 matchdays"),
		"the league intro counts the clubs and matchdays: " + league_facts_text)
	var league_day := CareerIntro.pending(career, "2026-08-21", catalog)
	_check(league_day.size() == 1
		and str(league_day[0].get("competition", "")) == "ES1",
		"the league is introduced on its first match day")
	CareerIntro.mark_seen(career, "ES1")
	_check(CareerIntro.pending(career, "2026-08-21", catalog).is_empty(),
		"the league is not introduced again")
	var cup_day := CareerIntro.pending(career, "2026-09-10", catalog)
	_check(cup_day.size() == 1, "the cup is introduced on its first match day")
	if cup_day.size() == 1:
		_check(str(cup_day[0].get("competition", "")) == "CDR", "the cup intro names the cup")
		CareerIntro.mark_seen(career, "CDR")
		_check(CareerIntro.pending(career, "2026-09-10", catalog).is_empty(),
			"a seen competition is never introduced twice")
		_check(CareerIntro.seen(career).has("CDR"), "the career remembers what it has seen")
	_finish()


func _finish() -> void:
	print("== check_career_intro: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
