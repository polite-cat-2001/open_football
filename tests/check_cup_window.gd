extends SceneTree
# Headless check for a cup window that opens before the league: the planned dates
# must exist, sit inside the season, and never share a day with a league round.
#
# Run:  godot --headless --path . -s res://tests/check_cup_window.gd

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
	print("== check_cup_window: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var teams: Array = catalog.all_teams_for_league("JO1L")
	_check(not teams.is_empty(), "Jordan has a league")
	if teams.is_empty():
		_finish()
		return
	var club_id := int(str((teams[0] as Dictionary).get("id", "0")))
	var career := CareerFactory.create(catalog, club_id, "Cup Window", 189, 31)
	_check(career != null, "a Jordanian career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var season_end := CareerSeason.season_end(career)
	var cup: Dictionary = {}
	for entry in career.data.get("competitions", []):
		if str(entry.get("kind", "")) == "cup":
			cup = entry
			break
	_check(not cup.is_empty(), "the season carries a cup")
	if cup.is_empty():
		_finish()
		return
	var rounds: Array = cup.get("rounds", [])
	var legs := 0
	for spec in rounds:
		legs += int((spec as Dictionary).get("legs", 1))
	var dates: Array = cup.get("dates", [])
	_check(dates.size() == legs,
		"the cup gets one date per leg: %d of %d" % [dates.size(), legs])
	var inside := true
	for date in dates:
		if str(date) < str(career.season_start) or str(date) > season_end:
			inside = false
	_check(inside, "every cup date sits inside the season %s .. %s" % [
		career.season_start, season_end])

	# A club never plays a cup tie on a day it already has a league round.
	var by_date := {}
	var clashes: Array = []
	for fixture in career.schedule:
		if str(fixture.get("home", "")) != career.club_id \
				and str(fixture.get("away", "")) != career.club_id:
			continue
		var date := str(fixture.get("date", ""))
		if by_date.has(date):
			clashes.append(date + " (%s + %s)" % [by_date[date],
				str(fixture.get("competition", career.league_id))])
		by_date[date] = str(fixture.get("competition", career.league_id))
	_check(clashes.is_empty(), "no two fixtures on one day %s" % [clashes])
	_finish()
