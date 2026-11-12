extends SceneTree
# Headless flow for the end-of-match screens: a level 90:00 opens the draw choice,
# penalties start the series from the break, classic resumes extra time, draw ends
# the match on the result screen.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_result_flow.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var scene: Node
var runtime: Node
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 4, 5)
	if package.is_empty():
		_check(false, "match package could not be built")
		_finish()
		return
	ShellState.set_match_package(package)

	var packed: PackedScene = load("res://scenes/gpf_slice.tscn")
	scene = packed.instantiate()
	get_root().add_child(scene)
	await process_frame
	runtime = get_first_node_in_group("gpf_runtime")
	runtime.set("manual_step", true)
	runtime.set("data_root", DATA_ROOT)
	for i in 4:
		await process_frame

	var over = scene.get("match_over")
	_check(over != null, "the match-over carrier is wired into the slice")

	# The choice screen: the break latch at 90:00 with a level score.
	var snap: Dictionary = runtime.get_snapshot()
	_check(int(snap.get("score0", -1)) == int(snap.get("score1", 0)),
		"the level-score assumption holds at kickoff")
	runtime.debug_force_phase_break(3)
	await _frames(10)
	_check(over.is_choice(), "a level 90:00 opens the draw choice")
	_check(bool(runtime.get_snapshot().get("paused", false)),
		"the draw choice pauses the match")

	# PENALTIES (Down from CLASSIC) starts the series from the stopped break.
	scene.call("_input", _key(KEY_DOWN))
	scene.call("_input", _key(KEY_ENTER))
	await _frames(10)
	snap = runtime.get_snapshot()
	_check(bool(snap.get("shootout_active", false)),
		"penalties start the shootout from the break")
	_check(not over.is_open(), "the choice screen closes when the series starts")

	# Restart, then CLASSIC resumes the match after the break.
	scene.call("_start_fresh_match")
	await _frames(10)
	runtime.debug_force_phase_break(3)
	await _frames(10)
	_check(over.is_choice(), "the choice reopens on a fresh level 90:00")
	scene.call("_input", _key(KEY_ENTER))
	await _frames(10)
	snap = runtime.get_snapshot()
	_check(not bool(snap.get("paused", true)), "classic unpauses the match")
	_check(not bool(snap.get("phase_break", true)), "classic clears the period break")
	_check(not bool(snap.get("shootout_active", false)),
		"classic does not start the series")
	_check(not over.is_open(), "the choice screen closes after classic")

	# DRAW accepts the draw and lands on the result screen.
	runtime.debug_force_phase_break(3)
	await _frames(10)
	scene.call("_input", _key(KEY_DOWN))
	scene.call("_input", _key(KEY_RIGHT))
	scene.call("_input", _key(KEY_ENTER))
	await _frames(10)
	_check(bool(runtime.get_snapshot().get("game_over", false)),
		"draw ends the match")
	_check(over.is_open() and not over.is_choice(), "draw shows the result screen")
	_check(over.result.tiles().size() == 4
		and over.result.tiles()[1].title == "RESTART MATCH",
		"the result screen carries the live tiles")

	# RESTART MATCH starts a fresh match with the same package and drops the
	# previous match's committed plan from the pause preview.
	var pause = scene.get("pause_menu")
	var stale: Array = []
	for index in 11:
		stale.append({"name": "STALE%d" % index, "role": "CM",
			"position": Vector2.ZERO, "rating": 50})
	pause.set_plan_lineups({0: stale})
	over.result.call("_on_tile_pressed", "restart")
	await _frames(10)
	_check(not bool(runtime.get_snapshot().get("game_over", true)),
		"restart match starts a fresh match")
	_check(not over.is_open(), "restart closes the result screen")
	_check((pause.get("_plan_lineups") as Dictionary).is_empty(),
		"restart clears the previous plan XI")

	_finish()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: gpf result flow")
		quit(0)
	else:
		print("CHECK FAIL: ", failures[0])
		quit(1)
