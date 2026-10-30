extends SceneTree
# Headless check for the editable prematch lineup: starters/bench swaps, dragged
# formation positions, invalid-state guards, and the edited eleven arriving in
# the C++ match through the package.
#
# Run:  godot --headless --path . -s res://tests/check_prematch_lineup.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const HOME_ID := 4
const AWAY_ID := 5
const EDITED_SLOT := 5

var failures: Array[String] = []


func _init() -> void:
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		_fail("catalog did not load: " + catalog.error)
		_finish()
		return
	var home_squad := catalog.load_squad(HOME_ID)
	var away_squad := catalog.load_squad(AWAY_ID)
	if home_squad.is_empty() or away_squad.is_empty():
		_fail("squads did not load")
		_finish()
		return

	var home := MatchLineup.from_squad(home_squad)
	var away := MatchLineup.from_squad(away_squad)
	_check(home.lineup.size() == Formation.SLOT_COUNT, "the default lineup has eleven slots")
	_check(home.bench.size() == home.players.size() - Formation.SLOT_COUNT,
		"the rest of the squad sits on the bench")
	_check(home.is_valid(), "the default lineup is valid: " + home.error)

	var displaced := home.lineup[EDITED_SLOT]
	var promoted := _bench_outfielder(home)
	_check(promoted != 0, "the bench has an outfield player to promote")
	if promoted != 0:
		_check(home.set_starter(EDITED_SLOT, promoted), "a bench player can be promoted")
		_check(home.lineup[EDITED_SLOT] == promoted, "the promoted player owns the slot")
		_check(home.slot_for_player(displaced) < 0 and home.bench.has(displaced),
			"the displaced starter moves to the bench")
		_check(home.lineup.size() == Formation.SLOT_COUNT and home.bench.size()
			== home.players.size() - Formation.SLOT_COUNT, "the squad stays eleven plus bench")
		_check(home.is_valid(), "swapping a starter keeps the lineup valid: " + home.error)

	var starter_a := home.lineup[EDITED_SLOT]
	var starter_b := home.lineup[7]
	_check(home.swap_players(starter_a, starter_b), "two starters can be swapped")
	_check(home.lineup[EDITED_SLOT] == starter_b and home.lineup[7] == starter_a,
		"two starters exchange slots")
	var bench_a := home.bench[0]
	var bench_b := home.bench[1]
	_check(home.swap_players(bench_a, bench_b), "two bench players can be swapped")
	_check(home.bench[0] == bench_b and home.bench[1] == bench_a,
		"two bench players exchange places")
	_check(home.is_valid(), "starter/bench swaps keep the lineup valid: " + home.error)

	var target := Vector2(0.25, -0.75)
	_check(home.move_position(EDITED_SLOT, target), "a formation position can be moved")
	var moved: Vector2 = home.formation[EDITED_SLOT]["position"]
	_check(moved.distance_to(target) < 0.00001, "the dragged position is stored")

	var saved := home.lineup[4]
	home.clear_slot(4)
	var short := home.validate()
	_check(not bool(short.get("ok", true))
		and str(short.get("error", "")).contains("11"),
		"fewer than eleven starters is rejected and explained")
	home.set_starter(4, saved)

	var goalkeeper_slot := -1
	for index in home.formation.size():
		if str(home.formation[index].get("role", "")) == "GK":
			goalkeeper_slot = index
			break
	_check(goalkeeper_slot >= 0, "the formation has a goalkeeper slot")
	var goalkeeper_id := home.lineup[goalkeeper_slot] if goalkeeper_slot >= 0 else 0
	var outfielder := _bench_outfielder(home)
	if goalkeeper_slot >= 0 and outfielder != 0:
		home.set_starter(goalkeeper_slot, outfielder)
		_check(home.is_valid(), "an outfield player can be placed in goal")
		_check(home.warning().to_lower().contains("outfield"),
			"an outfield keeper is warned about, not blocked")
		home.set_starter(goalkeeper_slot, goalkeeper_id)
	_check(home.is_valid(), "the restored lineup is valid again: " + home.error)

	var builder := MatchPackage.new()
	var package := builder.build(catalog, catalog.team_by_id(HOME_ID),
		catalog.team_by_id(AWAY_ID), {"duration": 0.0}, {"home": home, "away": away})
	_check(not package.is_empty(), "the edited lineup builds a package: " + builder.error)
	if package.is_empty():
		_finish()
		return

	var home_package: Dictionary = package["home"]
	var package_players: Array = home_package["players"]
	_check(package_players.size() == home.players.size(),
		"the package still carries the whole squad")
	var order_ok := package_players.size() == home.players.size()
	if order_ok:
		for index in Formation.SLOT_COUNT:
			order_ok = order_ok and int(package_players[index]["database_id"]) == home.lineup[index]
		for index in home.bench.size():
			order_ok = order_ok and int(package_players[Formation.SLOT_COUNT + index]["database_id"]) \
				== home.bench[index]
	_check(order_ok, "starters come first in package order, then the bench")
	var package_position: Vector2 = home_package["formation"][EDITED_SLOT]["position"]
	_check(package_position.distance_to(target) < 0.00001,
		"the moved position lands in the package")

	var broken := MatchLineup.from_squad(home_squad)
	broken.clear_slot(0)
	var rejected := builder.build(catalog, catalog.team_by_id(HOME_ID),
		catalog.team_by_id(AWAY_ID), {}, {"home": broken, "away": away})
	_check(rejected.is_empty() and builder.error.to_lower().contains("lineup"),
		"the package builder rejects an invalid lineup")

	var outfield_goal := MatchLineup.from_squad(home_squad)
	outfield_goal.set_starter(goalkeeper_slot, _bench_outfielder(outfield_goal))
	var accepted_keeper := builder.build(catalog, catalog.team_by_id(HOME_ID),
		catalog.team_by_id(AWAY_ID), {}, {"home": outfield_goal, "away": away})
	_check(not accepted_keeper.is_empty()
		and outfield_goal.warning().to_lower().contains("outfield"),
		"the package accepts an outfield keeper with a warning")

	_check_runtime(package, home)
	_finish()


func _check_runtime(package: Dictionary, home: MatchLineup) -> void:
	var runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		_fail("GpfRuntimeNode is not registered")
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	_check(bool(runtime.set_match_package(package)), "the runtime accepts the edited package")
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		_fail("runtime did not start: " + str(runtime.get_last_error()))
		return

	var active := {}
	var active_names: Array[String] = []
	for entry in runtime.get_player_ids():
		if int(entry.get("team", -2)) == 0:
			active[int(entry.get("id", 0))] = true
			active_names.append(str(entry.get("name", "")))
	_check(active.size() == Formation.SLOT_COUNT, "team 0 fields eleven players")
	var expected_names: Array[String] = []
	for player in home.lineup_players():
		expected_names.append(_last_name(player))
	_check(active_names == expected_names, "the edited starters are on the pitch")

	var live: Array = runtime.debug_get_formation(0)
	_check(live.size() == Formation.SLOT_COUNT, "the live formation has eleven slots")
	if live.size() == Formation.SLOT_COUNT:
		var live_position: Vector3 = live[EDITED_SLOT].get("position", Vector3.ZERO)
		var expected: Vector2 = home.formation[EDITED_SLOT]["position"]
		_check(absf(live_position.x - expected.x) < 0.00001
			and absf(live_position.y - expected.y) < 0.00001,
			"the live formation uses the dragged position")


func _bench_outfielder(lineup: MatchLineup) -> int:
	for player_id in lineup.bench:
		if not MatchLineup.is_goalkeeper(lineup.player_by_id(player_id)):
			return player_id
	return 0


func _last_name(player: Dictionary) -> String:
	var last := str(player.get("lastname", ""))
	return last if not last.is_empty() else str(player.get("firstname", ""))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("  FAIL: ", message)


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: prematch lineup")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
