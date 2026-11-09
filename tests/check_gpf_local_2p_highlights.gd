extends SceneTree
# Headless check for the selected-player highlight rule:
# - a LAN host/client only sees its own selected player (owner id filter);
# - a local 2P match sees both teams' selected players.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_local_2p_highlights.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/open_football_career/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const HOME_ID := 4941
const AWAY_ID := 4035

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, HOME_ID, AWAY_ID, {"duration": 0.0})
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
	runtime.set("human_control", true)
	runtime.set("data_root", DATA_ROOT)
	if not runtime.set_match_package(package):
		print("CHECK FAIL: set_match_package failed: ", runtime.get_last_error())
		quit(1)
		return
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime did not start: ", runtime.get_last_error())
		quit(1)
		return

	_run()
	if failures.is_empty():
		print("CHECK PASS: local 2P highlights")
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


func _run() -> void:
	var slot := int(runtime.register_gamepad(0))
	_check(slot >= 0, "a shell gamepad can be registered")
	if slot < 0:
		return
	runtime.set_controller_setup([
		{"side": -1, "kind": "keyboard", "slot": -1},
		{"side": 1, "kind": "gamepad", "slot": slot},
	])
	_check(bool(runtime.restart_match()), "the local 2P match starts")

	var human_ids: Array = runtime.get_human_player_ids()
	_check(human_ids.size() == 2, "local 2P highlights both selected players")
	if human_ids.size() != 2:
		return
	_check(int(human_ids[0]) != int(human_ids[1]), "the two highlights are different players")

	var by_team := {}
	var owned := 0
	for entry in runtime.get_player_ids():
		if int(entry.get("owner_id", -1)) == 0:
			owned += 1
			by_team[int(entry.get("team", -1))] = int(entry.get("id", -1))
	_check(owned == 2, "both local gamers are owned by the local peer")
	_check(by_team.has(0) and by_team.has(1), "one selected player per team is marked controlled")
	_check(int(human_ids[0]) == int(by_team.get(0, -1)) or int(human_ids[0]) == int(by_team.get(1, -1)),
		"get_human_player_id returns one of the two controlled players")
	_check(int(runtime.get_human_team_id()) >= 0, "the human team resolves")
	_check(str(runtime.debug_human_device()) != "", "the human device resolves")
