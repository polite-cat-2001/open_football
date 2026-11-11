extends SceneTree
# Headless check for the career matchday (ticket 04, second half): lineup and
# bench building, the seed-driven score, applying the outcome to results, table,
# player stats and condition, the matchday read model and the save round-trip.
#
# Run:  godot --headless --path . -s res://tests/check_career_matchday.gd

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
	print("== check_career_matchday: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_matchday_test_%d" % Time.get_ticks_usec()
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

	var league_clubs := catalog.all_teams_for_league(career.league_id)
	var strengths := _strengths(catalog, league_clubs)
	_check(CareerSeason.advance_to(career, "2026-07-08", league_clubs, strengths),
		"the calendar advances to the match day: " + CareerSeason.last_error)
	var fixture := CareerSeason.next_fixture(career)
	_check(not fixture.is_empty(), "the career club has a fixture")
	if fixture.is_empty():
		_finish()
		return

	var clubs := {}
	for club_id in [str(fixture.get("home", "")), str(fixture.get("away", ""))]:
		clubs[club_id] = catalog.career_club(int(club_id))
	var setup := _build_setup(catalog, career, fixture, clubs)
	_check(setup.get("home_lineup", {}).get("slots", []).size() == 11,
		"the home lineup has eleven starters")
	_check(setup.get("away_lineup", {}).get("slots", []).size() == 11,
		"the away lineup has eleven starters")
	_check(setup.get("home_lineup", {}).get("bench", []).size() == 7,
		"the home bench has seven players")
	_check(str(setup.get("home_lineup", {}).get("formation_label", "")) == "4-3-3",
		"the default formation is 4-3-3")
	_check(not str(setup.get("home_team", {}).get("abbr", "")).is_empty(),
		"the match setup carries club abbreviations")

	_check(not CareerSeason.play_next_match(career, league_clubs, strengths).is_empty(),
		"the match is played: " + CareerSeason.last_error)
	_check(career.date == "2026-07-09", "the career date moves past the match day")
	var fixture_id := str(fixture.get("id", ""))
	var score = career.results.get(fixture_id)
	_check(score is Dictionary, "the career club's fixture has a result")
	if not (score is Dictionary):
		_finish()
		return
	var played_round := 0
	for item in career.schedule:
		if int(item.get("round", 0)) == int(fixture.get("round", 0)) \
				and career.results.has(str(item.get("id", ""))):
			played_round += 1
	_check(played_round == 10, "all ten fixtures of the round are played")

	var match := CareerMatch.build_match_simulation(
		career.seed, fixture, setup, score)
	var own_home := bool(setup.get("home", false))
	var goals_for := int(score.get("home", 0)) if own_home else int(score.get("away", 0))
	var goals_against := int(score.get("away", 0)) if own_home else int(score.get("home", 0))
	var event_goals := 0
	for event in match.get("events", []):
		if str(event.get("team", "")) != ("home" if own_home else "away"):
			continue
		if str(event.get("type", "")) in ["goal", "penalty"]:
			event_goals += 1
	_check(event_goals == goals_for, "the timeline goals add up to the result")

	CareerCondition.apply_match_outcome(
		career, fixture, setup, match, career.league_id)
	var side := "home" if own_home else "away"
	var lineup: Dictionary = setup["%s_lineup" % side]
	var stats_goals := 0
	var stats_apps := 0
	for slot in lineup.get("slots", []):
		var state = career.player_state.get(str(slot["player"]["id"]))
		if not (state is Dictionary):
			continue
		stats_goals += int(state.get("stats", {}).get("goals", 0))
		stats_apps += int(state.get("stats", {}).get("apps", 0))
	_check(stats_goals == goals_for, "player goals match the team score")
	_check(stats_apps >= 11, "the starting eleven receive appearances")
	var tired := 0
	for slot in lineup.get("slots", []):
		var state = career.player_state.get(str(slot["player"]["id"]))
		if state is Dictionary and int(state.get("fatigue", 100)) < 100:
			tired += 1
	_check(tired == 11, "the starting eleven lose fatigue")
	_check(not career.journal.is_empty()
		and str(career.journal[-1].get("type", "")) == "match.played",
		"the match is written to the journal")

	var clubs_by_id := {}
	for club in league_clubs:
		clubs_by_id[str(club.get("id", ""))] = catalog.career_club(int(club.get("id", "")))
	var matchday := CareerSeason.matchday_state(career, clubs_by_id, "Premier League")
	_check(int(matchday.get("round", 0)) == int(fixture.get("round", 0)),
		"the matchday state names the played round")
	_check((matchday.get("results", []) as Array).size() == 10,
		"the matchday state lists all ten results")
	_check((matchday.get("standings", []) as Array).size() == 20,
		"the matchday state lists the full table")
	var delta_ok := true
	for row in matchday.get("standings", []):
		delta_ok = delta_ok and row.has("delta") and row.has("previous_position")
	_check(delta_ok, "the table rows carry the position delta")

	var fresh := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	CareerSeason.advance_to(fresh, "2026-07-08", league_clubs, strengths)
	var fresh_fixture := CareerSeason.next_fixture(fresh)
	var fresh_clubs := {}
	for club_id in [
			str(fresh_fixture.get("home", "")), str(fresh_fixture.get("away", ""))]:
		fresh_clubs[club_id] = catalog.career_club(int(club_id))
	var fresh_setup := _build_setup(catalog, fresh, fresh_fixture, fresh_clubs)
	CareerSeason.play_next_match(fresh, league_clubs, strengths)
	var fresh_match := CareerMatch.build_match_simulation(
		fresh.seed, fresh_fixture, fresh_setup, fresh.results[fresh_fixture["id"]])
	_check(JSON.stringify(fresh_match.get("events", [])) == JSON.stringify(match.get("events", [])),
		"the match timeline replays identically for the same seed")

	var store := CareerSaveStore.new(_directory)
	_check(store.save(career), "the career saves after the match")
	var reloaded := store.load_career(career.id)
	_check(reloaded != null, "the career loads: " + store.last_error)
	if reloaded != null:
		_check(reloaded.date == "2026-07-09", "the reloaded career keeps the new date")
		_check(reloaded.results.has(fixture_id), "the reloaded career keeps the result")
		var state = reloaded.player_state.get(str(lineup["slots"][0]["player"]["id"]))
		_check(state is Dictionary and int(state.get("stats", {}).get("apps", 0)) > 0,
			"the reloaded career keeps player stats")
		_check(state is Dictionary and int(state.get("fatigue", 100)) < 100,
			"the reloaded career keeps player fatigue")

	var empty := CareerMatch.build_lineup([])
	_check((empty.get("slots", []) as Array).is_empty()
		and (empty.get("bench", []) as Array).is_empty(),
		"an empty squad produces an empty lineup")

	await _check_hub_flow(catalog, league_clubs, strengths)

	_finish()


func _check_hub_flow(catalog: TeamCatalog, league_clubs: Array,
		strengths: Dictionary) -> void:
	var nav := root.get_node("UiNav")
	var ui_career := CareerFactory.create(catalog, 131, "UI Manager", 189, 42)
	_check(ui_career != null, "a career is created for the hub flow")
	if ui_career == null:
		return
	CareerSeason.advance_to(ui_career, "2026-07-08", league_clubs, strengths)
	var store := CareerSaveStore.new(_directory)
	CareerSession.career = ui_career
	CareerSession.catalog = catalog
	CareerSession.store = store
	change_scene_to_file("res://scenes/career_hub.tscn")
	for _index in range(14):
		await process_frame
	var hub := current_scene
	_check(hub != null and hub.name == "CareerHub", "the hub opens on the match day")
	if hub == null or hub.name != "CareerHub":
		return
	var next_tile = hub.get_node("Design/PanelWrap/Body/Grid/NextTile")
	var play_tile = hub.get_node("Design/PanelWrap/Body/Grid/PlayTile")
	var simulation_tile = hub.get_node("Design/PanelWrap/Body/Grid/SimulationTile")
	_check(bool(hub.get("_match_day")), "the hub knows it is match day")
	_check(not next_tile.visible and play_tile.visible and simulation_tile.visible,
		"the calendar is replaced by PLAY and SIMULATION")
	_check(play_tile.has_focus(), "PLAY owns focus on match day")

	nav.confirmed.emit()
	for _index in range(8):
		await process_frame
	_check(str(hub.get("_match_phase")) == "matchday_results",
		"PLAY opens the matchday results")
	var overlay = hub.get("_match_overlay")
	_check(overlay != null and overlay.is_open(), "the match overlay is open")
	_check(ui_career.date == "2026-07-09", "PLAY advances the career past the match")
	nav.confirmed.emit()
	for _index in range(4):
		await process_frame
	_check(str(hub.get("_match_phase")) == "matchday_table",
		"Enter switches to the matchday table")
	nav.cancelled.emit()
	for _index in range(4):
		await process_frame
	_check(str(hub.get("_match_phase")) == "matchday_results",
		"Back returns to the results")
	nav.cancelled.emit()
	for _index in range(8):
		await process_frame
	_check(not overlay.is_open(), "Back from the results closes the overlay")
	_check(not bool(hub.get("_match_day")), "the hub moves to the next fixture")
	_check(not play_tile.visible and next_tile.visible,
		"the calendar returns after the match")

	var sim_career := CareerFactory.create(catalog, 131, "Sim Manager", 189, 42)
	CareerSeason.advance_to(sim_career, "2026-07-08", league_clubs, strengths)
	CareerSession.career = sim_career
	change_scene_to_file("res://scenes/career_hub.tscn")
	for _index in range(14):
		await process_frame
	hub = current_scene
	simulation_tile = hub.get_node("Design/PanelWrap/Body/Grid/SimulationTile")
	simulation_tile.grab_focus()
	nav.confirmed.emit()
	for _index in range(8):
		await process_frame
	_check(str(hub.get("_match_phase")) == "setup",
		"SIMULATION opens the pre-match screen")
	nav.confirmed.emit()
	for _index in range(4):
		await process_frame
	_check(str(hub.get("_match_phase")) == "live",
		"Enter starts the live simulation")
	nav.confirmed.emit()
	for _index in range(4):
		await process_frame
	_check(str(hub.get("_match_phase")) == "done",
		"Enter during live skips to the final whistle")
	nav.confirmed.emit()
	for _index in range(4):
		await process_frame
	_check(str(hub.get("_match_phase")) == "matchday_results",
		"the final whistle opens the matchday results")
	var sim_overlay = hub.get("_match_overlay")
	nav.cancelled.emit()
	for _index in range(8):
		await process_frame
	_check(not sim_overlay.is_open(), "Back from the results closes the match overlay")

	# The match day arriving through the calendar hands focus to PLAY, and the
	# two match tiles navigate to each other.
	var transition_career := CareerFactory.create(
		catalog, 131, "Matchday Manager", 189, 42)
	CareerSession.career = transition_career
	change_scene_to_file("res://scenes/career_hub.tscn")
	for _index in range(14):
		await process_frame
	hub = current_scene
	if hub != null and hub.name == "CareerHub":
		play_tile = hub.get_node("Design/PanelWrap/Body/Grid/PlayTile")
		simulation_tile = hub.get_node("Design/PanelWrap/Body/Grid/SimulationTile")
		_check(not bool(hub.get("_match_day")),
			"a fresh career opens before the match day")
		nav.confirmed.emit()
		for _index in range(14):
			await process_frame
		_check(bool(hub.get("_match_day")), "advancing reaches the match day")
		_check(play_tile.visible and play_tile.has_focus(),
			"the arriving match day hands focus to PLAY")
		simulation_tile.grab_focus()
		nav.moved.emit(Vector2i.LEFT)
		for _index in range(3):
			await process_frame
		_check(play_tile.has_focus(), "Left moves from SIMULATION to PLAY")
		nav.moved.emit(Vector2i.RIGHT)
		for _index in range(3):
			await process_frame
		_check(simulation_tile.has_focus(), "Right moves from PLAY to SIMULATION")
		nav.moved.emit(Vector2i.RIGHT)
		for _index in range(3):
			await process_frame
		var table_tile = hub.get_node("Design/PanelWrap/Body/Grid/TableTile")
		_check(table_tile.has_focus(), "Right moves from SIMULATION to the table")
	CareerSession.clear()


func _build_setup(catalog: TeamCatalog, career: Career, fixture: Dictionary,
		clubs: Dictionary) -> Dictionary:
	var our_players := catalog.career_squad(int(career.club_id))
	var our_ids: Array = []
	for player in our_players:
		our_ids.append(str(player.get("id", "")))
	CareerCondition.ensure_player_states(career, our_ids)
	CareerCondition.recover_condition(career, career.date)
	var blocked := CareerCondition.blocked_player_ids(career)
	var own_home := str(fixture.get("home", "")) == career.club_id
	var home_players := our_players if own_home \
		else catalog.career_squad(int(fixture.get("home", "")))
	var away_players := our_players if not own_home \
		else catalog.career_squad(int(fixture.get("away", "")))
	var home_lineup := CareerMatch.build_lineup(
		home_players,
		career.lineup if own_home else [],
		career.bench_order if own_home else [],
		blocked if own_home else [],
		career.formation if own_home else CareerFormations.DEFAULT)
	var away_lineup := CareerMatch.build_lineup(
		away_players,
		career.lineup if not own_home else [],
		career.bench_order if not own_home else [],
		blocked if not own_home else [],
		career.formation if not own_home else CareerFormations.DEFAULT)
	var own_lineup := home_lineup if own_home else away_lineup
	var starters: Array = []
	for slot in own_lineup.get("slots", []):
		starters.append(str(slot["player"]["id"]))
	var bench: Array = []
	for player in own_lineup.get("bench", []):
		bench.append(str(player.get("id", "")))
	career.lineup = starters
	career.bench_order = bench
	return CareerMatch.build_match_setup(
		career, fixture, "Premier League", clubs, home_lineup, away_lineup)


func _strengths(catalog: TeamCatalog, league_clubs: Array) -> Dictionary:
	var strengths := {}
	for club in league_clubs:
		var club_id := str(club.get("id", ""))
		strengths[club_id] = CareerSeason.squad_strength(catalog.career_squad(int(club_id)))
	return strengths


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
