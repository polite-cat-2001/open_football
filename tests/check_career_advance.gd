extends SceneTree
# Headless check for the calendar advance (ticket 04, first half): the Poisson
# score line, the match timeline port, advancing to the next match day,
# determinism against a seed golden, the refreshed table and the save round-trip.
#
# Run:  godot --headless --path . -s res://tests/check_career_advance.gd

const GOLDEN := "res://tests/fixtures/career_advance_golden.json"
const MATCH_GOLDEN := "res://tests/fixtures/career_match_golden.json"
const ROLES := ["GK", "CB", "CB", "LB", "RB", "DM", "CM", "CM", "LM", "CF", "RM"]
const BENCH_ROLES := ["GK", "CB", "LB", "DM", "CM", "LM", "CF"]

var failures: Array[String] = []
var _directory := ""


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	_cleanup()
	CareerSaveStore.root_override = ""
	print("== check_career_advance: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_advance_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	_check(career.date == "2026-07-01", "a new career starts on 2026-07-01")

	var before := CareerFactory.snapshot(catalog, career)
	var next = before.get("season", {}).get("next")
	_check(next is Dictionary, "the hub knows the next fixture")
	if not (next is Dictionary):
		_finish()
		return
	_check(str(next.get("date", "")) == "2026-07-08",
		"the first match day is 2026-07-08")
	var round_no := int(next.get("round", 0))

	var league_clubs := catalog.all_teams_for_league(career.league_id)
	_check(league_clubs.size() == 20, "the league has twenty clubs")
	var strengths := _strengths(catalog, league_clubs)

	var round_fixtures: Array = []
	for fixture in career.schedule:
		if int(fixture.get("round", 0)) == round_no:
			round_fixtures.append(fixture)
	var own_fixture := {}
	var others := {}
	for fixture in round_fixtures:
		var fixture_id := str(fixture.get("id", ""))
		if career.club_id in [str(fixture.get("home", "")), str(fixture.get("away", ""))]:
			own_fixture = fixture
		else:
			others[fixture_id] = fixture
	_check(not own_fixture.is_empty(), "the career club plays in round %d" % round_no)
	_check(others.size() == round_fixtures.size() - 1,
		"round %d has nine other fixtures" % round_no)

	_check(CareerSeason.advance_to(career, "2026-07-08", league_clubs, strengths),
		"the calendar advances to the match day: " + CareerSeason.last_error)
	_check(career.date == "2026-07-08", "the career date moves to the match day")
	_check(not career.results.has(str(own_fixture.get("id", ""))),
		"the career club's own fixture waits for the matchday screen")
	var played_others := 0
	for fixture_id in others:
		if career.results.has(fixture_id):
			played_others += 1
	_check(played_others == others.size(), "every other fixture of the round is played")

	var scores_ok := true
	for fixture_id in others:
		var score = career.results.get(fixture_id)
		scores_ok = scores_ok and score is Dictionary \
			and int(score.get("home", -1)) >= 0 and int(score.get("away", -1)) >= 0
	_check(scores_ok, "every result is a non-negative {home, away} score")

	var fresh := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	_check(CareerSeason.advance_to(fresh, "2026-07-08", league_clubs, strengths),
		"a second career with the same seed advances")
	var deterministic := true
	for fixture_id in others:
		deterministic = deterministic and _same_score(
			career.results.get(fixture_id), fresh.results.get(fixture_id))
	_check(deterministic, "the round replays identically for the same seed")

	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the golden fixture loads")
	if golden is Dictionary:
		var golden_results: Dictionary = golden.get("results", {})
		_check(golden_results.size() == others.size(),
			"the golden covers every simulated fixture")
		var matches := true
		for fixture_id in others:
			matches = matches and _same_score(
				career.results.get(fixture_id), golden_results.get(fixture_id))
		_check(matches, "the round matches the seed golden")

	var after := CareerFactory.snapshot(catalog, career)
	var standings: Array = after.get("season", {}).get("standings", [])
	var played_rows := 0
	for row in standings:
		played_rows += int(row.get("played", 0))
	_check(played_rows == 2 * others.size(), "the table counts both sides of every result")
	var own_row := CareerHubModel.own_row(after)
	_check(int(own_row.get("played", -1)) == 0,
		"the career club has not played its match yet")
	_check((after.get("season", {}).get("form", []) as Array).is_empty(),
		"the form waits for the career club's own match")
	var next_tile := CareerHubModel.next_tile(after)
	_check(bool(next_tile.get("match_day", false)), "the hub marks the match day")
	_check(str(next_tile.get("title", "")) == "MATCH DAY", "the tile title becomes MATCH DAY")
	var table_tile := CareerHubModel.table_tile(after)
	_check((table_tile.get("rows", []) as Array).size() > 0, "the overview tile has rows")

	var sim_tile := CareerHubModel.next_tile(before, "2026-07-04", "2026-07-01")
	_check(bool(sim_tile.get("simulating", false)), "the calendar marks a running simulation")
	_check(str(sim_tile.get("eyebrow", "")) == "SIMULATING",
		"the tile eyebrow switches to SIMULATING")
	_check((sim_tile.get("days", []) as Array).size() == 14,
		"the sliding track spans fourteen days")
	_check(int(sim_tile.get("day_offset", -1)) == 3,
		"the track offset follows the display date")
	var sim_days: Array = sim_tile.get("days", [])
	_check(str(sim_days[3].get("key", "")) == "2026-07-04"
		and bool(sim_days[3].get("today", false)),
		"the today marker moves with the display date")
	_check(str(sim_days[7].get("key", "")) == "2026-07-08"
		and bool(sim_days[7].get("match", false)),
		"the match day is marked inside the track")
	_check(str(sim_tile.get("opponent_logo", ""))
		== str(next.get("opponent", {}).get("logo", "")),
		"the match cell uses the opponent crest")

	var store := CareerSaveStore.new(_directory)
	_check(store.save(career), "the advanced career saves")
	var reloaded := store.load_career(career.id)
	_check(reloaded != null, "the advanced career loads: " + store.last_error)
	if reloaded != null:
		_check(reloaded.date == "2026-07-08", "the reloaded career keeps the new date")
		var kept := true
		for fixture_id in others:
			kept = kept and _same_score(
				reloaded.results.get(fixture_id), career.results.get(fixture_id))
		_check(kept, "the reloaded career keeps the round results")

	_check(not CareerSeason.advance_to(career, "2026-07-01", league_clubs, strengths),
		"time cannot move backwards")
	_check(CareerSeason.last_error == "cannot move time backwards",
		"the backwards error matches the prototype")
	_check(not CareerSeason.advance_to(career, "2026-07-09", league_clubs, strengths),
		"time cannot pass the next match day")
	_check(CareerSeason.last_error == "cannot pass the next match day",
		"the match-day error matches the prototype")
	_check(not CareerSeason.advance_to(career, "2026-13-01", league_clubs, strengths),
		"an invalid date is rejected")
	_check(CareerSeason.last_error == "date must be ISO YYYY-MM-DD",
		"the invalid-date error matches the prototype")

	await _check_hub_advance(catalog)

	_check_timeline()

	_finish()


func _check_hub_advance(catalog: TeamCatalog) -> void:
	var ui_career := CareerFactory.create(catalog, 131, "UI Manager", 189, 42)
	_check(ui_career != null, "a career is created for the hub check")
	if ui_career == null:
		return
	var store := CareerSaveStore.new(_directory)
	CareerSession.career = ui_career
	CareerSession.catalog = catalog
	CareerSession.store = store
	change_scene_to_file("res://scenes/career_hub.tscn")
	for _index in range(12):
		await process_frame
	var hub := current_scene
	_check(hub != null and hub.name == "CareerHub", "the hub opens for the advance check")
	if hub == null or hub.name != "CareerHub":
		return
	var next_tile = hub.get_node("Design/PanelWrap/Body/Grid/NextTile")
	next_tile.pressed.emit()
	for _index in range(6):
		await process_frame
	_check(ui_career.date == "2026-07-08", "NEXT advances the career to the match day")
	var hints = hub.get_node("Design/PanelWrap/Hints")
	_check(hints.status_text().begins_with("Advanced to"),
		"the hub reports the advance: " + hints.status_text())
	_check(str(hub.get("_snapshot").get("date", "")) == "2026-07-08",
		"the hub snapshot is rebuilt for the new date")
	next_tile.pressed.emit()
	for _index in range(3):
		await process_frame
	_check(hints.status_text().begins_with("Match day"),
		"on the match day NEXT stays a stub: " + hints.status_text())
	var saved := store.load_career(ui_career.id)
	_check(saved != null and saved.date == "2026-07-08",
		"the hub saves the advanced career")
	CareerSession.clear()


func _check_timeline() -> void:
	var fixture := {"id": "r01-00", "round": 1, "date": "2026-07-08"}
	var setup := {
		"home": true,
		"home_lineup": _lineup("h"),
		"away_lineup": _lineup("a"),
	}
	var result := CareerMatch.build_match_simulation(42, fixture, setup, {"home": 3, "away": 2})
	_check(int(result.get("score", {}).get("home", -1)) == 3
		and int(result.get("score", {}).get("away", -1)) == 2,
		"the timeline keeps the final score")
	_check(str(result.get("outcome", "")) == "W", "the home win is reported from our side")
	var goals := {"home": 0, "away": 0}
	var minutes: Array = []
	var has_sub := false
	for event in result.get("events", []):
		minutes.append(int(event.get("minute", 0)))
		if str(event.get("type", "")) in ["goal", "penalty"]:
			goals[str(event.get("team", ""))] += 1
		if str(event.get("type", "")) == "sub":
			has_sub = true
	_check(goals == {"home": 3, "away": 2}, "the goal events add up to the score")
	var sorted_minutes := minutes.duplicate()
	sorted_minutes.sort()
	_check(minutes == sorted_minutes, "the events are sorted by minute")
	_check(has_sub, "the timeline contains substitutions")
	var again := CareerMatch.build_match_simulation(42, fixture, setup, {"home": 3, "away": 2})
	_check(JSON.stringify(again) == JSON.stringify(result),
		"the timeline replays identically for the same seed")
	var match_golden = JSON.parse_string(FileAccess.get_file_as_string(MATCH_GOLDEN))
	_check(match_golden is Dictionary, "the timeline golden loads")
	if match_golden is Dictionary:
		var round_trip = JSON.parse_string(JSON.stringify(result["events"]))
		_check(JSON.stringify(round_trip) == JSON.stringify(match_golden.get("events", [])),
			"the timeline events match the golden")
		_check(str(match_golden.get("outcome", "")) == str(result.get("outcome", "")),
			"the timeline outcome matches the golden")

	var away_setup := setup.duplicate(true)
	away_setup["home"] = false
	var away := CareerMatch.build_match_simulation(42, fixture, away_setup, {"home": 3, "away": 2})
	_check(str(away.get("outcome", "")) == "L", "an away result is reported from our side")
	_check(int(away.get("goals_for", -1)) == 2 and int(away.get("goals_against", -1)) == 3,
		"the away goals swap around our club")


func _lineup(prefix: String) -> Dictionary:
	var slots: Array = []
	for index in range(ROLES.size()):
		slots.append({"player": {
			"id": "%s%d" % [prefix, index],
			"role": ROLES[index],
			"overall": 70 + index,
		}})
	var bench: Array = []
	for index in range(BENCH_ROLES.size()):
		bench.append({
			"id": "%s%d" % [prefix, index + 11],
			"role": BENCH_ROLES[index],
			"overall": 65 + index,
		})
	return {"slots": slots, "bench": bench}


func _strengths(catalog: TeamCatalog, league_clubs: Array) -> Dictionary:
	var strengths := {}
	for club in league_clubs:
		var club_id := str(club.get("id", ""))
		strengths[club_id] = CareerSeason.squad_strength(catalog.career_squad(int(club_id)))
	return strengths


func _same_score(a, b) -> bool:
	if not (a is Dictionary) or not (b is Dictionary):
		return false
	if not (a.has("home") and a.has("away") and b.has("home") and b.has("away")):
		return false
	return int(a["home"]) == int(b["home"]) and int(a["away"]) == int(b["away"])


func _cleanup() -> void:
	if _directory.is_empty():
		return
	var dir := DirAccess.open(_directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_directory))
