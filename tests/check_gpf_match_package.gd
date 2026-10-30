extends SceneTree
# Headless proof that the C++ runtime builds the match entirely from the shell
# package: names, active squad, score, clock and formation come from the package
# and no database query is needed on the C++ side.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_match_package.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

const HOME_ID := 4
const AWAY_ID := 5
const HOME_NAME := "Club León FC"
const AWAY_NAME := "CF Pachuca"

var failures: Array[String] = []
var runtime: Node
var package: Dictionary


func _init() -> void:
	package = MatchPackageFixture.build(DATA_ROOT, HOME_ID, AWAY_ID, {"duration": 0.0})
	if package.is_empty():
		print("CHECK FAIL: match package could not be built")
		quit(1)
		return

	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	_check(not bool(runtime.has_match_package()), "the runtime starts without a package")
	_check(bool(runtime.set_match_package(package)), "set_match_package accepts the shell package")
	_check(bool(runtime.has_match_package()), "the runtime keeps the package")
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime did not start: ", runtime.get_last_error())
		quit(1)
		return

	_run()
	if failures.is_empty():
		print("CHECK PASS: match package")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _lineup(team: Dictionary) -> Array:
	return (team.get("players", []) as Array).slice(0, 11)


func _last_name(player: Dictionary) -> String:
	var last := str(player.get("last_name", ""))
	return last if not last.is_empty() else str(player.get("first_name", ""))


func _run() -> void:
	var snap: Dictionary = runtime.get_snapshot()
	_check(not snap.is_empty(), "a match exists")
	if snap.is_empty():
		return

	_check(str(snap.get("team0_name", "")) == HOME_NAME,
		"home team name comes from the package (%s)" % snap.get("team0_name"))
	_check(str(snap.get("team1_name", "")) == AWAY_NAME,
		"away team name comes from the package (%s)" % snap.get("team1_name"))
	_check(int(snap.get("score0", -1)) == 0 and int(snap.get("score1", -1)) == 0,
		"the match starts 0:0")
	_check(int(snap.get("match_time_ms", -1)) == 0, "the match clock starts at 0")
	_check(not bool(snap.get("paused", true)) and not bool(snap.get("game_over", true)),
		"the match starts live")

	var ids: Array = runtime.get_player_ids()
	var active := {0: [], 1: []}
	for entry in ids:
		var team := int(entry.get("team", -2))
		if team == 0 or team == 1:
			active[team].append(str(entry.get("name", "")))
	_check(active[0].size() == 11, "team 0 fields exactly 11 players (%d)" % active[0].size())
	_check(active[1].size() == 11, "team 1 fields exactly 11 players (%d)" % active[1].size())

	var home_lineup := _lineup(package["home"])
	var away_lineup := _lineup(package["away"])
	var home_names := {}
	var away_names := {}
	for player in home_lineup:
		home_names[_last_name(player)] = true
	for player in away_lineup:
		away_names[_last_name(player)] = true
	var home_ok := true
	var away_ok := true
	for name in active[0]:
		home_ok = home_ok and home_names.has(name)
	for name in active[1]:
		away_ok = away_ok and away_names.has(name)
	_check(home_ok, "team 0 names match the package lineup")
	_check(away_ok, "team 1 names match the package lineup")

	var home_formation: Array = runtime.debug_get_formation(0)
	var away_formation: Array = runtime.debug_get_formation(1)
	_check(home_formation.size() == 11 and away_formation.size() == 11,
		"both formations have 11 slots")
	var formation_ok := home_formation.size() == 11 and away_formation.size() == 11
	if formation_ok:
		for index in 11:
			formation_ok = formation_ok and _formation_matches(
				home_formation[index], package["home"]["formation"][index])
			formation_ok = formation_ok and _formation_matches(
				away_formation[index], package["away"]["formation"][index])
	_check(formation_ok, "formation roles and positions match the package")

	var tick_before := int(runtime.get_tick())
	runtime.step_fixed(1500)
	_check(int(runtime.get_tick()) == tick_before + 1500, "the match clock ticks")
	var after: Dictionary = runtime.get_snapshot()
	_check(int(after.get("score0", -1)) >= 0 and int(after.get("score1", -1)) >= 0,
		"the score stays a valid score")
	_check(int(after.get("match_time_ms", -1)) >= 0, "match time is valid")

	# Reach open play to prove the clock actually advances from kickoff.
	var guard := 0
	while guard < 3000 and not bool(after.get("in_play", false)):
		runtime.step_fixed(10)
		guard += 10
		after = runtime.get_snapshot()
	if bool(after.get("in_play", false)):
		var in_play_time := int(after.get("match_time_ms", 0))
		runtime.step_fixed(100)
		after = runtime.get_snapshot()
		_check(int(after.get("match_time_ms", 0)) > in_play_time,
			"the clock advances in open play")
	else:
		_check(false, "open play was reached for the clock check")


func _formation_matches(runtime_entry: Dictionary, package_entry: Dictionary) -> bool:
	if str(runtime_entry.get("role", "")) != str(package_entry.get("role", "")):
		return false
	var runtime_pos: Vector3 = runtime_entry.get("position", Vector3.ZERO)
	var package_pos: Vector2 = package_entry.get("position", Vector2.ZERO)
	var runtime_db: Vector3 = runtime_entry.get("database_position", Vector3.ZERO)
	var package_db: Vector2 = package_entry.get("database_position", Vector2.ZERO)
	return absf(runtime_pos.x - package_pos.x) < 0.00001 \
		and absf(runtime_pos.y - package_pos.y) < 0.00001 \
		and absf(runtime_db.x - package_db.x) < 0.00001 \
		and absf(runtime_db.y - package_db.y) < 0.00001
