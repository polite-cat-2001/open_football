extends SceneTree
# Regression: a direction held when the pause opens, then released while paused,
# must be released in the runtime too (otherwise the player keeps running).
#
# Run:  godot --headless --path . -s res://tests/check_gpf_pause_release.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const BUTTON_SHORTPASS := 6
const BUTTON_RIGHT := 1

var scene: Node
var runtime: Node
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _key(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.physical_keycode = KEY_RIGHT
	event.pressed = pressed
	return event


func _pos(player_id: int) -> Vector3:
	return (runtime.get_player_pose(player_id) as Dictionary).get("pos", Vector3.ZERO)


func _run() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 1795, 1794)
	ShellState.set_match_package(package)
	ShellState.controllers = [{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"}]
	scene = load("res://scenes/gpf_slice.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	runtime = get_first_node_in_group("gpf_runtime")
	runtime.set("manual_step", true)
	runtime.set("data_root", DATA_ROOT)
	for i in 8:
		await process_frame
	var player := _open_play()
	if player <= 0:
		_check(false, "a human player is selected")
		_finish()
		return
	scene.call("_input", _key(true))
	runtime.step_fixed(30)
	scene.call("_open_pause")
	runtime.step_fixed(2)
	scene.call("_input", _key(false))
	runtime.step_fixed(2)
	scene.get("pause_menu").close()
	runtime.step_fixed(120)
	var before := _pos(player)
	runtime.step_fixed(40)
	var moved := absf(_pos(player).x - before.x)
	_check(moved < 0.3, "a release during the pause stops the player (%.2f m)" % moved)
	runtime.set_button(BUTTON_RIGHT, false)
	_finish()


func _open_play() -> int:
	var guard := 0
	var snap: Dictionary = runtime.get_snapshot()
	while guard < 2000 and not (bool(snap.get("in_play", false))
			and bool(snap.get("in_set_piece", false))):
		runtime.step_fixed(10)
		guard += 10
		snap = runtime.get_snapshot()
	var taker := int(snap.get("referee_taker", -1))
	if taker > 0 and int(snap.get("referee_team", -1)) == int(runtime.get_human_team_id()):
		runtime.select_player(taker)
		runtime.set_button(BUTTON_SHORTPASS, true)
		runtime.step_fixed(5)
		runtime.set_button(BUTTON_SHORTPASS, false)
	guard = 0
	snap = runtime.get_snapshot()
	while guard < 3000 and not (bool(snap.get("in_play", false))
			and not bool(snap.get("in_set_piece", false))):
		runtime.step_fixed(10)
		guard += 10
		snap = runtime.get_snapshot()
	runtime.step_fixed(100)
	var player := int(runtime.get_human_player_id())
	runtime.select_player(player)
	return player


func _finish() -> void:
	print("== check_gpf_pause_release: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)
