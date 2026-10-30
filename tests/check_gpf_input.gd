extends SceneTree
# Headless proof that the C++ runtime consumes per-device input (keyboard and a
# shell-owned virtual gamepad), not one shared keyboard state, and that the
# shell can put the human on either side.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_input.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

const HOME_ID := 4
const AWAY_ID := 5

# e_ButtonFunction indices of the original input layer.
const BUTTON_UP := 0
const BUTTON_SHORTPASS := 6

# Godot/SDL semantic joypad ids (the HIDGamepad default mapping uses the same).
const JOY_BUTTON_A := 0
const JOY_AXIS_LEFT_Y := 1

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
	if not bool(runtime.set_match_package(package)):
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
		print("CHECK PASS: gpf input")
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


func _setup_keyboard_home() -> void:
	runtime.set_controller_setup([
		{"side": -1, "kind": "keyboard", "slot": -1},
	])
	_check(bool(runtime.restart_match()), "keyboard match restarts")
	_check(int(runtime.get_human_team_id()) == 0, "keyboard setup puts the human on home")
	_check(int(runtime.get_human_player_id()) > 0, "keyboard setup selects a human player")
	_check(str(runtime.debug_human_device()) == "keyboard",
		"the human's bound device is the keyboard")


func _setup_gamepad_away() -> int:
	var slot := int(runtime.register_gamepad(0))
	_check(slot >= 0, "the shell can register a gamepad device")
	if slot < 0:
		return -1
	runtime.set_controller_setup([
		{"side": 1, "kind": "gamepad", "slot": slot},
	])
	_check(bool(runtime.restart_match()), "gamepad match restarts")
	_check(int(runtime.get_human_team_id()) == 1, "gamepad setup puts the human on away")
	_check(int(runtime.get_human_player_id()) > 0, "gamepad setup selects a human player")
	_check(str(runtime.debug_human_device()) == "gamepad",
		"the human's bound device is the registered gamepad")
	var applied: Array = runtime.get_controller_setup()
	_check(applied.size() == 1 and str(applied[0].get("kind", "")) == "gamepad",
		"C++ stores the gamepad controller setup")
	return slot


func _run() -> void:
	# --- keyboard on home ---
	_setup_keyboard_home()
	var moved := _move_and_measure("keyboard", BUTTON_UP, -1, 0)
	_check(moved > 0.5, "keyboard input moves the controlled player (%.2f)" % moved)

	# --- gamepad on away ---
	var slot := _setup_gamepad_away()
	if slot < 0:
		return
	moved = _move_and_measure("gamepad", -1, slot, JOY_AXIS_LEFT_Y)
	_check(moved > 0.5, "gamepad input moves the controlled player (%.2f)" % moved)


# Puts the match into open play, pins the human selection, drives one movement
# axis for a second and returns how far the player advanced along raw +Y.
func _move_and_measure(kind: String, key_function: int, slot: int, axis: int) -> float:
	_take_kickoff(kind, slot)
	var guard := 0
	var snap: Dictionary = runtime.get_snapshot()
	while guard < 3000 and not (bool(snap.get("in_play", false))
			and not bool(snap.get("in_set_piece", false))):
		runtime.step_fixed(10)
		guard += 10
		snap = runtime.get_snapshot()
	if not bool(snap.get("in_play", false)) or bool(snap.get("in_set_piece", false)):
		_check(false, "%s: open play reached" % kind)
		return 0.0
	# Let the kickoff action (when the human took it) finish before steering.
	runtime.step_fixed(100)
	var player_id := int(runtime.get_human_player_id())
	if player_id <= 0:
		_check(false, "%s: a controlled player is selected" % kind)
		return 0.0
	runtime.select_player(player_id)
	var before := _player_pos(player_id)
	if kind == "keyboard":
		runtime.set_button(key_function, true)
	else:
		# HIDGamepad maps negative LEFT_Y to Up (raw +Y).
		runtime.set_gamepad_axis(slot, axis, -1.0)
	runtime.step_fixed(100)
	if kind == "keyboard":
		runtime.set_button(key_function, false)
	else:
		runtime.set_gamepad_axis(slot, axis, 0.0)
	runtime.step_fixed(10)
	var after := _player_pos(player_id)
	return after.y - before.y


func _take_kickoff(kind: String, slot: int) -> void:
	# Wait for the opening kickoff, then select its taker on our side (the press
	# only works on the controlled player) and pass.
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
		if kind == "keyboard":
			runtime.set_button(BUTTON_SHORTPASS, true)
		else:
			runtime.set_gamepad_button(slot, JOY_BUTTON_A, true)
		runtime.step_fixed(5)
		if kind == "keyboard":
			runtime.set_button(BUTTON_SHORTPASS, false)
		else:
			runtime.set_gamepad_button(slot, JOY_BUTTON_A, false)


func _player_pos(player_id: int) -> Vector3:
	var pose: Dictionary = runtime.get_player_pose(player_id)
	return pose.get("pos", Vector3.ZERO)
