extends SceneTree
# Headless check for the non-UEFA continental cups: the CONCACAF knockout
# ladder from a 27-club field (22 in round one, 5 byes to the round of 16).
# The career club's ties go into the calendar, every other tie is simulated.
#
# Run:  godot --headless --path . -s res://tests/check_confederation_cup.gd

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
	print("== check_confederation_cup: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _career(club_id: String) -> Career:
	return Career.new({
		"version": Career.SAVE_VERSION,
		"id": "c".repeat(32),
		"seed": 11,
		"date": "2026-12-20",
		"season_start": "2026-12-20",
		"created_at": "2026-07-01T00:00:00.000000Z",
		"updated_at": "2026-07-01T00:00:00.000000Z",
		"manager": {"name": "Synthetic", "nationality_id": "189", "nationality": "England"},
		"club_id": club_id,
		"player_ids": [],
		"journal": [],
		"balance": 0,
		"schedule": [],
		"results": {},
		"continental": {},
	})


func _run() -> void:
	var catalog := TeamCatalog.new()
	catalog.load_data_root()
	_check(catalog.is_loaded(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return

	var field: Array = []
	for league in ["GB1", "ES1", "IT1"]:
		for team in catalog.all_teams_for_league(league):
			field.append(str(team.get("id", "")))
	_check(field.size() >= 27, "the sample leagues have at least 27 clubs")
	if field.size() < 27:
		_finish()
		return
	var direct: Dictionary = {}
	for index in range(27):
		direct[field[index]] = "round_of_16" if index < 5 else "round_one"
	var focus: String = field[5]

	var career := _career(focus)
	var block := CareerConfederation.build(catalog, "CONCACAF",
		{"CCL": direct}, "2026-12-20", focus)
	_check(not block.is_empty(), "the CONCACAF competition builds")
	_check(str(block.get("focus", "")) == "CCL",
		"the career club's competition is the focus")
	career.data["continental"] = {"2026-12-20": {"confederations": {"CONCACAF": block}}}

	CareerConfederation.ensure(career, catalog)
	var state: Dictionary = block["competitions"]["CCL"]
	_check(career.schedule.size() == 2, "the focus club gets its two round-one legs")
	_check(int(state.get("round_index", -1)) == 0,
		"the round waits for the focus club's results")
	var round_one: Array = state["fixtures"]["0"]
	_check(round_one.size() == 22, "the round of 32 plays 11 ties over two legs")
	var simulated := 0
	for fixture in round_one:
		if career.results.has(str(fixture.get("id", ""))):
			simulated += 1
	_check(simulated == 20, "the other ten ties are simulated")
	_check(career.results.size() == 20, "only the focus tie is left to play")

	# Play the focus tie: a home win and a draw win the round.
	_play_next(career, 1, 0)
	_play_next(career, 0, 1)
	CareerConfederation.ensure(career, catalog)
	_check(int(state.get("round_index", -1)) == 1, "the focus club reaches the round of 16")
	var round_two: Array = state["fixtures"]["1"]
	var focus_legs := 0
	for fixture in round_two:
		if str(fixture.get("home", "")) == focus or str(fixture.get("away", "")) == focus:
			focus_legs += 1
	_check(focus_legs == 2, "the round of 16 schedules two focus legs")
	_check((state["entrants"]["1"] as Array).size() == 16,
		"the round of 16 has the eleven winners and the five byes")

	# Play every focus tie until the competition ends.
	var guard := 0
	while not bool(state.get("done", false)) and guard < 16:
		guard += 1
		for fixture in career.schedule:
			if career.results.has(str(fixture.get("id", ""))):
				continue
			# Score for the focus club whichever leg it hosts, so the test does
			# not depend on the seeded tie order.
			var focus_home := str(fixture.get("home", "")) == focus
			_play_fixture(career, fixture, 2 if focus_home else 0,
				0 if focus_home else 2)
		CareerConfederation.ensure(career, catalog)
	_check(bool(state.get("done", false)), "the competition resolves to the final")
	_check(_all_results(state, career), "every tie has a result")
	var champion := str(state.get("champion", ""))
	var runner_up := str(state.get("runner_up", ""))
	_check(direct.has(champion), "the champion is one of the field")
	_check(not runner_up.is_empty() and runner_up != champion,
		"the runner-up is the other finalist")
	_check(career.schedule.size() == 2 + 2 + 2 + 2 + 1,
		"a finalist plays nine legs")

	# A club outside the field: the whole cup is simulated at once.
	var outside_id := ""
	for team in catalog.all_teams_for_league("GB2"):
		var candidate := str(team.get("id", ""))
		if not direct.has(candidate):
			outside_id = candidate
			break
	_check(not outside_id.is_empty(), "a club outside the field exists")
	var outside := _career(outside_id)
	var other := CareerConfederation.build(catalog, "CONCACAF",
		{"CCL": direct}, "2026-12-20", "")
	_check(str(other.get("focus", "")).is_empty(), "no club means no focus")
	outside.data["continental"] = {"2026-12-20": {"confederations": {"CONCACAF": other}}}
	CareerConfederation.ensure(outside, catalog)
	var other_state: Dictionary = other["competitions"]["CCL"]
	_check(bool(other_state.get("done", false))
		and not str(other_state.get("champion", "")).is_empty(),
		"an unplayed cup resolves in one pass")
	_check(_all_results(other_state, outside), "every simulated tie has a result")

	# Libertadores: eight groups of four, then the round of 16 and up.
	var group_entries: Dictionary = {}
	for index in range(32):
		group_entries[field[index]] = "group_stage"
	var group_focus: String = field[3]
	var group_career := _career(group_focus)
	var group_block := CareerConfederation.build(catalog, "CONMEBOL",
		{"CLI": group_entries}, "2026-12-20", group_focus)
	_check(not group_block.is_empty(), "the Libertadores builds")
	group_career.data["continental"] = {"2026-12-20": {
		"confederations": {"CONMEBOL": group_block}}}
	CareerConfederation.ensure(group_career, catalog)
	var group_state: Dictionary = group_block["competitions"]["CLI"]
	var group_index := 3
	var group_fixtures: Array = group_state["fixtures"][str(group_index)]
	_check(group_fixtures.size() == 96, "eight groups of four play 96 matches")
	var focus_group_matches := 0
	for fixture in group_fixtures:
		if str(fixture.get("home", "")) == group_focus \
				or str(fixture.get("away", "")) == group_focus:
			focus_group_matches += 1
	_check(focus_group_matches == 6, "the career club plays six group matches")
	_check(group_fixtures.size() - focus_group_matches
		== _simulated(group_career, group_fixtures),
		"the other group matches are simulated")
	_check(int(group_state.get("round_index", -1)) == group_index,
		"the group table waits for the career club")

	var group_guard := 0
	while not bool(group_state.get("done", false)) and group_guard < 16:
		group_guard += 1
		for fixture in group_career.schedule:
			if group_career.results.has(str(fixture.get("id", ""))):
				continue
			var home := str(fixture.get("home", ""))
			group_career.data["results"][str(fixture.get("id", ""))] = \
				{"home": 3, "away": 0} if home == group_focus \
				else {"home": 0, "away": 3}
		CareerConfederation.ensure(group_career, catalog)
	_check(bool(group_state.get("done", false)), "the Libertadores reaches its final")
	_check(str(group_state.get("champion", "")) == group_focus,
		"the group winner goes on to win the cup")
	_check((group_state["entrants"]["7"] as Array).size() == 2,
		"the final is played by the two semi-final winners")
	_finish()


func _simulated(career: Career, fixtures: Array) -> int:
	var count := 0
	for fixture in fixtures:
		if career.results.has(str(fixture.get("id", ""))):
			count += 1
	return count


func _play_next(career: Career, home: int, away: int) -> void:
	for fixture in career.schedule:
		if career.results.has(str(fixture.get("id", ""))):
			continue
		_play_fixture(career, fixture, home, away)
		return


func _play_fixture(career: Career, fixture: Dictionary, home: int, away: int) -> void:
	career.data["results"][str(fixture.get("id", ""))] = {"home": home, "away": away}


func _all_results(state: Dictionary, career: Career) -> bool:
	var total := 0
	for round_index in state.get("fixtures", {}):
		for fixture in state["fixtures"][round_index]:
			total += 1
			if not career.results.has(str(fixture.get("id", ""))):
				return false
	return total > 0
