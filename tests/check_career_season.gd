extends SceneTree
# Headless check for the season end: the review transition (promotion /
# relegation between adjacent tiers), next-season rollover (calendar, results,
# ages, values, condition) and the save round-trip.
#
# Run:  godot --headless --path . -s res://tests/check_career_season.gd

const TEAM_ID := 2  # 1.FC Kaiserslautern, 2. Bundesliga: L1 above, L3 below.
const GOLDEN_KEYS := ["season.completed", "season.started"]

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
	print("== check_career_season: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_season_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, TEAM_ID, "Season Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	_check(career.league_id == "L2", "the career starts in 2. Bundesliga: " + career.league_id)

	_check(CareerSeason.transition(catalog, career).is_empty(),
		"a running season has no transition")
	_check(not CareerSeason.next_season(career, catalog, {}),
		"next season waits for the season to finish")

	var league_clubs := _league_clubs(catalog, career)
	var strengths := _strengths(catalog, career, league_clubs)
	var rounds := 0
	var expected_rounds := 0
	if league_clubs.size() > 1:
		expected_rounds = (league_clubs.size() - 1) * 2
	while not CareerSeason.next_fixture(career).is_empty() and rounds < 60:
		var fixture := CareerSeason.next_fixture(career)
		if not CareerSeason.advance_to(career, str(fixture.get("date", "")),
				league_clubs, strengths):
			_check(false, "advance failed: " + CareerSeason.last_error)
			break
		if CareerSeason.play_next_match(career, league_clubs, strengths).is_empty():
			_check(false, "match day failed: " + CareerSeason.last_error)
			break
		rounds += 1
	_check(rounds == expected_rounds, "the season plays every round (%d)" % expected_rounds)
	_check(CareerSeason.next_fixture(career).is_empty(),
		"the last round leaves no fixture")

	var snapshot := CareerFactory.snapshot(catalog, career)
	_check(bool(snapshot.get("season", {}).get("complete", false)),
		"the hub snapshot marks the season complete")
	var tile := CareerHubModel.next_tile(snapshot)
	_check(str(tile.get("title", "")) == "SIMULATE",
		"the hero keeps rolling through the off-season")
	_check(bool(tile.get("transition", false)),
		"the off-season hero has no fixture")
	_check((tile.get("days", []) as Array).size() == 7,
		"the off-season hero shows the week strip")
	var season_end := CareerSeason.season_end(career)
	_check(career.date < season_end, "the last match does not end the season yet")
	_check(CareerSeason.advance_days(career, season_end),
		"the off-season advances to the season end: " + CareerSeason.last_error)
	_check(career.date == season_end, "the calendar stops on the season end")
	_check(not CareerSeason.advance_days(career, "2027-07-01"),
		"the calendar cannot pass the season end")
	var ended := CareerFactory.snapshot(catalog, career)
	var ended_tile := CareerHubModel.next_tile(ended)
	_check(str(ended_tile.get("title", "")) == "SEASON COMPLETE",
		"the season end offers the next season")
	_check(str(ended_tile.get("season_title", "")) == "START NEW SEASON",
		"the season end keeps the season summary")
	var reel_start := str(snapshot.get("date", ""))
	var reel_a := CareerHubModel.next_tile(snapshot, reel_start, reel_start)
	var reel_b := CareerHubModel.next_tile(snapshot,
		CareerSeason.add_days(reel_start, 1), reel_start)
	_check(_keys(reel_a) == _keys(reel_b),
		"the off-season strip keeps its cells while the reel moves")
	_check(int(reel_b.get("day_offset", 0)) == int(reel_a.get("day_offset", 0)) + 1,
		"the off-season strip slides one cell per day")

	var transition := CareerSeason.transition(catalog, career)
	_check(not transition.is_empty(), "the season end builds a transition: "
		+ CareerSeason.last_error)
	if transition.is_empty():
		_finish()
		return
	var review: Dictionary = transition.get("review", {})
	var standings: Array = review.get("standings", [])
	var review_next: Dictionary = review.get("next", {})
	var review_league: Dictionary = review.get("league", {})
	var review_next_league: Dictionary = review_next.get("league", {})
	var promoted_to: Dictionary = review.get("promoted_to", {}) if review.get("promoted_to") is Dictionary else {}
	var relegated_to: Dictionary = review.get("relegated_to", {}) if review.get("relegated_to") is Dictionary else {}
	_check(standings.size() == league_clubs.size(),
		"the review table lists every club")
	_check(str(review_league.get("id", "")) == "L2",
		"the review names the finished league")
	_check((review.get("promoted", []) as Array).size() == 3,
		"the top three go up")
	_check((review.get("relegated", []) as Array).size() == 3,
		"the bottom three go down")
	_check(str(promoted_to.get("id", "")) == "L1",
		"promotion leads to the Bundesliga")
	_check(str(relegated_to.get("id", "")) == "L3",
		"relegation leads to 3. Liga")
	var own_row := {}
	for row in standings:
		if str(row.get("club_id", "")) == career.club_id:
			own_row = row
			break
	var expected_movement = null
	if not own_row.is_empty():
		if int(own_row.get("position", 99)) <= 3:
			expected_movement = "up"
		elif int(own_row.get("position", 0)) > standings.size() - 3:
			expected_movement = "down"
	_check(review.get("movement") == expected_movement,
		"the movement follows the final position")

	var next_ids: Array = transition.get("league_club_ids", [])
	var unique := {}
	for club_id in next_ids:
		unique[str(club_id)] = true
	_check(unique.size() == next_ids.size(), "the next league has no duplicate clubs")
	_check(next_ids.size() == league_clubs.size(),
		"the next league keeps its size")
	_check(next_ids.has(career.club_id), "the career club stays in its league")
	_check(str(transition.get("league_id", "")) == str(review_next_league.get("id", "")),
		"the next league id matches the review")
	_check(_composition_matches(catalog, career, review, next_ids),
		"the next composition applies the review swaps")

	var before_players := CareerSquad.roster(catalog, career, int(career.club_id), false)
	var ages_before := {}
	for player in before_players:
		ages_before[str(player.get("id", ""))] = int(career.player_ages.get(
			str(player.get("id", "")), 0))
	var journal_before: Array = career.data.get("journal", []).duplicate()
	var ui_career := Career.from_save(career.to_save())
	_check(ui_career != null, "the finished season clones for the review UI")
	if ui_career != null:
		ui_career.data["date"] = str(snapshot.get("date", ""))
	_check(CareerSeason.next_season(career, catalog, transition),
		"the next season starts: " + CareerSeason.last_error)
	_check(career.season_start == "2027-07-01",
		"the calendar shifts a year: " + career.season_start)
	_check(career.date == career.season_start, "the career lands on the new season start")
	_check(career.results.is_empty(), "the new season starts with no results")
	_check(str(career.league_id) == str(transition.get("league_id", "")),
		"the career moves to the reviewed league")
	_check(career.league_club_ids == next_ids, "the league composition is stored")
	_check(not career.schedule.is_empty(), "the new schedule exists")
	_check(str(career.schedule[0].get("date", "")) == "2027-07-08",
		"the new schedule starts a week after the season start")
	_check(career.incoming_market_date == career.date
		and career.world_market_date == career.date,
		"the off-season gap is not replayed by the market")
	_check(bool(CareerFactory.snapshot(catalog, career).get("season", {}).get("next") is Dictionary),
		"the hub has the first fixture of the new season")

	var journal: Array = career.data.get("journal", [])
	_check(journal.size() == journal_before.size() + 2,
		"the rollover journals both season events")
	if journal.size() >= 2:
		_check(str(journal[-2].get("type", "")) == GOLDEN_KEYS[0],
			"the completed season is archived")
		_check(str(journal[-1].get("type", "")) == GOLDEN_KEYS[1],
			"the new season is opened")

	var ages_ok := true
	var values_ok := true
	for player in CareerSquad.roster(catalog, career, int(career.club_id), false):
		var player_id := str(player.get("id", ""))
		if ages_before.has(player_id):
			ages_ok = ages_ok and int(career.player_ages.get(player_id, 0)) == ages_before[player_id] + 1
			values_ok = values_ok and int(player.get("market_value", 0)) > 0
	_check(ages_ok, "every squad player is a year older")
	_check(values_ok, "every squad player keeps a market value")
	var reset_ok := true
	for state in career.data.get("player_state", {}).values():
		reset_ok = reset_ok and int(state.get("fatigue", 0)) == 100
		reset_ok = reset_ok and state.get("injury") == null and state.get("suspension") == null
		reset_ok = reset_ok and int(state.get("stats", {}).get("minutes", -1)) == 0
	_check(reset_ok, "condition and season stats reset for the new season")
	_check(not CareerSeason.next_season(career, catalog, transition),
		"a second rollover is refused mid-season")
	_check(CareerSeason.last_error == "season is not complete",
		"the refusal reads like the prototype")

	var store := CareerSaveStore.new(_directory)
	_check(store.save(career), "the new season saves")
	var reloaded := store.load_career(career.id)
	_check(reloaded != null, "the new season loads: " + store.last_error)
	if reloaded != null:
		_check(reloaded.season_start == career.season_start,
			"the reload keeps the new season start")
		_check(reloaded.league_club_ids == career.league_club_ids,
			"the reload keeps the new league composition")
		_check(reloaded.results.is_empty(), "the reload keeps the empty results")

	_check_two_seasons(catalog)
	await _check_hub_review(catalog, ui_career)
	_finish()


func _check_two_seasons(catalog: TeamCatalog) -> void:
	# A club keeps its database league after promotion; the next review must not
	# treat it (or any other current club) as a newcomer from that old league.
	var career := CareerFactory.create(catalog, 82, "Composition", 189, 42)
	_check(career != null, "the composition career is created")
	if career == null:
		return
	_fill_results(career, true)
	var first := CareerSeason.transition(catalog, career)
	_check(str(first.get("review", {}).get("movement", "")) == "up",
		"the composition career is promoted")
	_check(CareerSeason.next_season(career, catalog, first),
		"the composition career starts the next season")
	var expected_size := career.league_club_ids.size()
	_fill_results(career, false)
	var second := CareerSeason.transition(catalog, career)
	var next_ids: Array = second.get("league_club_ids", [])
	var unique := {}
	for club_id in next_ids:
		unique[str(club_id)] = true
	_check(next_ids.size() == expected_size,
		"the next review keeps the league size")
	_check(unique.size() == next_ids.size(), "the next review has no duplicates")
	_check(not _from_contains_current(second.get("review", {}), career.league_club_ids),
		"the next review does not call current clubs newcomers")


func _fill_results(career: Career, own_wins: bool) -> void:
	if not (career.data.get("results") is Dictionary):
		career.data["results"] = {}
	var results: Dictionary = career.data["results"]
	var own_index := 0
	for fixture in career.schedule:
		var fixture_id := str(fixture.get("id", ""))
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		if career.club_id == home or career.club_id == away:
			var win := own_wins or own_index % 2 == 0
			var score := {"home": 5, "away": 0} if win else {"home": 0, "away": 5}
			if career.club_id == away:
				score = {"home": 0, "away": 5} if win else {"home": 5, "away": 0}
			results[fixture_id] = score
			own_index += 1
		else:
			results[fixture_id] = {"home": 0, "away": 0}


func _from_contains_current(review: Dictionary, current_ids: Array) -> bool:
	var next_block: Dictionary = review.get("next", {})
	for key in ["from_above", "from_below"]:
		for item in next_block.get(key, []):
			if current_ids.has(str(_dict(item.get("club")).get("id", ""))):
				return true
	return false


func _check_hub_review(catalog: TeamCatalog, career: Career) -> void:
	if career == null:
		return
	CareerSession.career = career
	CareerSession.catalog = catalog
	CareerSession.store = CareerSaveStore.new(_directory)
	change_scene_to_file("res://scenes/career_hub.tscn")
	for _index in range(12):
		await process_frame
	var hub := current_scene
	_check(hub != null and hub.name == "CareerHub", "the hub opens at the season end")
	if hub == null or hub.name != "CareerHub":
		CareerSession.clear()
		return
	var next_tile = hub.get_node("Design/PanelWrap/Body/Grid/NextTile")
	var hints = hub.get_node("Design/PanelWrap/Hints")
	var season_end := CareerSeason.season_end(career)
	_check(career.date < season_end, "the hub opens before the season end")
	_check(str(next_tile.get("_headline").text) == "SIMULATE",
		"the hero offers the off-season advance")
	next_tile.pressed.emit()
	for _index in range(8):
		await process_frame
	_check(career.date == season_end,
		"the hero rolls the calendar to the season end: " + career.date)
	_check(str(next_tile.get("_headline").text) == "SEASON COMPLETE",
		"the season end switches the hero to the next season")
	next_tile.pressed.emit()
	for _index in range(12):
		await process_frame
	_check(str(hub.get("_match_phase")) == "season_review",
		"the hero opens the season review")
	var overlay = hub.get("_match_overlay")
	_check(overlay.is_open(), "the review card is open")
	_check(hub.get("_review_step") == 0, "the review starts on the table")
	_check(hints.status_text() == "Season review",
		"the review reports its step")
	hub.call("_match_action")
	await process_frame
	_check(hub.get("_review_step") == 1, "confirm moves to the new-season step")
	_check(hints.status_text() == "New season",
		"the second step reports the new season")
	hub.call("_match_back")
	await process_frame
	_check(hub.get("_review_step") == 0, "back returns to the table")
	hub.call("_match_action")
	await process_frame
	hub.call("_match_action")
	var guard := 0
	while overlay.is_open() and guard < 200:
		await process_frame
		guard += 1
	_check(not overlay.is_open(), "starting the season closes the review")
	_check(career.date == "2027-07-01",
		"the next day is already the new season: " + career.date)
	_check(career.season_start == "2027-07-01",
		"the hub starts the new season: " + career.season_start)
	_check(career.results.is_empty(), "the hub resets the results")
	var saved := CareerSession.store.load_career(career.id)
	_check(saved != null and saved.season_start == "2027-07-01",
		"the hub saves the new season")
	CareerSession.clear()


func _composition_matches(catalog: TeamCatalog, career: Career, review: Dictionary,
		next_ids: Array) -> bool:
	var current: Array = []
	for club_id in career.league_club_ids:
		current.append(str(club_id))
	var promoted: Array = review.get("promoted", [])
	var relegated: Array = review.get("relegated", [])
	var next_block: Dictionary = review.get("next", {})
	var next_league: Dictionary = next_block.get("league", {})
	var from_above: Array = next_block.get("from_above", [])
	var from_below: Array = next_block.get("from_below", [])
	var movement = review.get("movement")
	var expected: Array = []
	if movement == "up":
		for club in catalog.all_teams_for_league(str(next_league.get("id", ""))):
			if not _has_ref(from_above, str(club.get("id", ""))):
				expected.append(str(club.get("id", "")))
		for row in promoted:
			expected.append(str(row.get("id", "")))
	elif movement == "down":
		for club in catalog.all_teams_for_league(str(next_league.get("id", ""))):
			if not _has_ref(from_below, str(club.get("id", ""))):
				expected.append(str(club.get("id", "")))
		for row in relegated:
			expected.append(str(row.get("id", "")))
	else:
		for club_id in current:
			if not _has_ref(promoted, club_id) and not _has_ref(relegated, club_id):
				expected.append(club_id)
		for row in from_above:
			expected.append(str(row.get("club", {}).get("id", "")))
		for row in from_below:
			expected.append(str(row.get("club", {}).get("id", "")))
	var unique := {}
	for club_id in expected:
		unique[club_id] = true
	return unique.size() == next_ids.size() and unique.has(str(career.club_id)) \
		and _same_members(unique, next_ids)


func _dict(value) -> Dictionary:
	return value if value is Dictionary else {}


func _keys(tile: Dictionary) -> Array:
	var keys: Array = []
	for day in tile.get("days", []):
		keys.append(str(day.get("key", "")))
	return keys


func _same_members(unique: Dictionary, ids: Array) -> bool:
	for club_id in ids:
		if not unique.has(str(club_id)):
			return false
	return true


func _has_ref(rows: Array, club_id: String) -> bool:
	for row in rows:
		if str(row.get("id", "")) == club_id:
			return true
	return false


func _league_clubs(catalog: TeamCatalog, career: Career) -> Array:
	var clubs: Array = []
	for club_id in career.league_club_ids:
		var club := catalog.career_club(int(club_id))
		if not club.is_empty():
			clubs.append(club)
	return clubs


func _strengths(catalog: TeamCatalog, career: Career, clubs: Array) -> Dictionary:
	var strengths := {}
	for club in clubs:
		var club_id := str(club.get("id", ""))
		strengths[club_id] = CareerSeason.squad_strength(
			CareerSquad.roster(catalog, career, int(club_id), false))
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
