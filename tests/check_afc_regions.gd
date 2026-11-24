extends SceneTree
# Headless check for the AFC regional ladder: two independent 16-club brackets
# (West/East) that only meet in the final.
#
# Run:  godot --headless --path . -s res://tests/check_afc_regions.gd

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
	print("== check_afc_regions: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _career(club_id: String) -> Career:
	return Career.new({
		"version": Career.SAVE_VERSION, "id": "a".repeat(32), "seed": 5,
		"date": "2026-12-20", "season_start": "2026-12-20",
		"created_at": "2026-07-01T00:00:00.000000Z",
		"updated_at": "2026-07-01T00:00:00.000000Z",
		"manager": {"name": "AFC", "nationality_id": "189"},
		"club_id": club_id, "player_ids": [], "journal": [], "balance": 0,
		"schedule": [], "results": {}, "continental": {},
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
	_check(field.size() >= 32, "the sample leagues have 32 clubs")
	if field.size() < 32:
		_finish()
		return
	var west: Array = field.slice(0, 16)
	var east: Array = field.slice(16, 32)
	var entries: Dictionary = {}
	for club_id in west + east:
		entries[club_id] = "league_stage"
	var regions := {"west": west, "east": east}
	var focus: String = field[3]
	var career := _career(focus)
	var block := CareerConfederation.build(catalog, "AFC",
		{"ACLE": entries}, "2026-12-20", focus, {"ACLE": regions})
	_check(not block.is_empty(), "the AFC competition builds")
	career.data["continental"] = {"2026-12-20": {"confederations": {"AFC": block}}}
	CareerConfederation.ensure(career, catalog)
	var state: Dictionary = block["competitions"]["ACLE"]
	var group_index := 1
	var groups: Array = state["fixtures"][str(group_index)]
	_check(groups.size() == 2 * 8 * 8, "two 16-club groups play 8 rounds")
	var focus_matches := 0
	for fixture in groups:
		var home := str(fixture.get("home", ""))
		if home == focus or str(fixture.get("away", "")) == focus:
			focus_matches += 1
	_check(focus_matches == 8, "the career club plays eight group matches")

	var guard := 0
	while not bool(state.get("done", false)) and guard < 24:
		guard += 1
		for fixture in career.schedule:
			if career.results.has(str(fixture.get("id", ""))):
				continue
			var home := str(fixture.get("home", ""))
			career.data["results"][str(fixture.get("id", ""))] = \
				{"home": 2, "away": 0} if home == focus else {"home": 0, "away": 2}
		CareerConfederation.ensure(career, catalog)
	_check(bool(state.get("done", false)), "the AFC competition reaches the final")
	var r16_map: Dictionary = state["fixtures"].get("2", {})
	var r16: Array = []
	for region in r16_map:
		r16.append_array(r16_map[region])
	_check(r16.size() == 8, "the round of 16 is played inside two regions")
	var mixed := 0
	for fixture in r16:
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		var home_west := west.has(home)
		if home_west != west.has(away):
			mixed += 1
	_check(mixed == 0, "no round-of-16 tie crosses the regions")
	var final_round: Array = state["fixtures"].get("5", [])
	_check(final_round.size() == 1, "the final is a single match")
	if final_round.size() == 1:
		var home := str(final_round[0].get("home", ""))
		var away := str(final_round[0].get("away", ""))
		_check(west.has(home) != west.has(away),
			"the final is one West club against one East club")
	_finish()
