extends SceneTree
# Headless golden check for career creation: fixed seed, known club, exact
# player order and schedule. Mirrors the prototype pytest snapshots.
#
# Run:  godot --headless --path . -s res://tests/check_career_creation.gd

const GOLDEN := "res://tests/fixtures/career_creation_golden.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _fixtures(items: Array) -> Array:
	var result: Array = []
	for item in items:
		result.append({
			"id": str(item.get("id", "")),
			"round": int(item.get("round", 0)),
			"date": str(item.get("date", "")),
			"home": str(item.get("home", "")),
			"away": str(item.get("away", "")),
		})
	return result


func _finish() -> void:
	print("== check_career_creation: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the golden fixture loads")
	if not (golden is Dictionary):
		_finish()
		return

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return

	var career := CareerFactory.create(
		catalog,
		int(golden["club_id"]),
		str(golden["manager_name"]),
		int(golden["manager_nationality_id"]),
		int(golden["seed"])
	)
	_check(career != null, "career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	_check(career.seed == int(golden["seed"]), "the seed is stored")
	_check(career.id.length() == 32 and career.id.is_valid_hex_number(),
		"the career id is a 32-char hex string")
	_check(career.club_id == str(golden["club_id"]), "the club id is the transfermarkt id")
	_check(career.league_id == str(golden["league_id"]), "the league id is set")
	_check(career.manager.name == str(golden["manager_name"]), "the manager name is stored")
	_check(career.manager.nationality == str(golden["manager_nationality"]),
		"the manager nationality is stored")
	_check(career.manager.nationality_id == str(golden["manager_nationality_id"]),
		"the manager nationality id is stored")
	_check(career.date == Career.START_DATE and career.season_start == Career.START_DATE,
		"the career starts on the prototype date")

	_check(career.player_ids == golden["player_ids"],
		"the starting squad is the sorted canon squad")
	_check(career.league_club_ids == golden["league_club_ids"],
		"the league clubs match the fixture")
	_check(career.schedule.size() == int(golden["schedule_count"]),
		"the double round-robin schedule is built")
	_check(career.schedule.slice(0, 4) == _fixtures(golden["schedule_first"]),
		"the first fixtures match the golden schedule")
	_check(career.schedule.slice(career.schedule.size() - 3)
		== _fixtures(golden["schedule_last"]),
		"the last fixtures match the golden schedule")
	_check(career.data.get("schedule_version", 0) == CareerFactory.SCHEDULE_VERSION,
		"the schedule version is current")

	var snapshot := CareerFactory.snapshot(catalog, career)
	_check(not snapshot.is_empty(), "the creation snapshot is built")
	var summary: Dictionary = snapshot.get("squad", {}).get("summary", {})
	_check(int(summary.get("squad_size", 0)) == int(golden["squad_size"]),
		"the snapshot squad size matches")
	_check(is_equal_approx(float(summary.get("average_overall", 0.0)),
		float(golden["average_overall"])), "the snapshot average overall matches")
	_check(is_equal_approx(float(summary.get("average_age", 0.0)),
		float(golden["average_age"])), "the snapshot average age matches")
	_check(int(summary.get("total_market_value", 0)) == int(golden["total_market_value"]),
		"the snapshot squad value matches")
	var season: Dictionary = snapshot.get("season", {})
	_check(season.get("next") is Dictionary, "the next match is known")
	_check(int(season.get("rounds_total", 0)) == 38, "the season has 38 rounds")
	_check((season.get("standings", []) as Array).size() == 20,
		"the snapshot has a 20-club table")

	var again := CareerFactory.create(
		catalog,
		int(golden["club_id"]),
		str(golden["manager_name"]),
		int(golden["manager_nationality_id"]),
		int(golden["seed"])
	)
	_check(again != null, "a second creation with the same seed works")
	if again != null:
		var first := career.to_save()
		var second := again.to_save()
		for key in ["id", "created_at", "updated_at"]:
			first.erase(key)
			second.erase(key)
		_check(first == second, "creation is deterministic once the volatile fields are removed")

	_finish()
