extends SceneTree
# Headless check for the action charge bar (ticket 08): the widget shows and
# positions itself from a screen point, hides for menus/replay, and the C++
# snapshot reports the local human's open-play charge and player id.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_charge.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const GpfHudScript := preload("res://scripts/match/gpf_hud.gd")

const HOME_ID := 4
const AWAY_ID := 5
const BUTTON_SHOT := 7

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	await _check_widget()
	await _check_runtime()
	if failures.is_empty():
		print("CHECK PASS: charge bar")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)


func _check_widget() -> void:
	print("-- widget --")
	var hud: GpfHud = GpfHudScript.new()
	get_root().add_child(hud)
	hud.setup(null)
	hud.apply_snapshot({"match_duration": 1.0, "score0": 0, "score1": 0}, 7, 22, false, "Afternoon")
	await process_frame
	var bar := hud.get("charge_bar") as ChargeBar
	_check(bar != null, "the HUD builds a charge bar")
	hud.set_charge(0.5, Vector2(500, 400))
	_check(bar.visible and is_equal_approx(bar.ratio, 0.5), "the bar shows the charge ratio")
	_check(bar.position == Vector2(472, 414), "the bar is centred under the feet point")
	hud.set_charge(0.5, Vector2(500, 400), true)
	_check(bar.position == Vector2(472, 384), "set pieces anchor the bar above the head")
	var view := hud.get_viewport().get_visible_rect().size
	hud.set_charge(0.5, Vector2(500, view.y + 200.0))
	_check(bar.position.y == view.y - ChargeBar.BAR_H - 8.0,
		"the bar clamps to the bottom edge when the feet leave the screen")
	hud.set_charge(0.0, Vector2.ZERO)
	_check(not bar.visible, "the bar hides when the charge ends")

	hud.apply_snapshot({"match_duration": 1.0, "paused": true}, 7, 22, false, "Afternoon")
	hud.set_charge(0.5, Vector2(500, 400))
	_check(not bar.visible, "the bar hides with the pause menu")

	hud.apply_snapshot({"match_duration": 1.0}, 7, 22, false, "Afternoon")
	hud.set_replay_mode(true)
	hud.set_charge(0.5, Vector2(500, 400))
	_check(not bar.visible, "the bar hides in replay")
	hud.set_replay_mode(false)


func _check_runtime() -> void:
	print("-- C++ snapshot --")
	var package := MatchPackageFixture.build(DATA_ROOT, HOME_ID, AWAY_ID, {"duration": 0.0})
	if package.is_empty():
		_check(false, "match package could be built")
		return
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		_check(false, "GpfRuntimeNode is registered")
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", true)
	runtime.set("data_root", DATA_ROOT)
	if not bool(runtime.set_match_package(package)):
		_check(false, "match package accepted")
		return
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	runtime.set_controller_setup([{"side": -1, "kind": "keyboard", "slot": -1}])
	runtime.restart_match()
	runtime.step_fixed(30)

	var idle: Dictionary = runtime.get_snapshot()
	_check(idle.has("charge_ratio") and idle.has("charge_player_id"),
		"the snapshot carries charge fields")
	_check(float(idle.get("charge_ratio", 1.0)) == 0.0
		and int(idle.get("charge_player_id", 0)) == -1,
		"the charge is idle before any action")

	# Kick off, then put the ball at the selected human's feet and hold shot.
	var guard := 0
	var snap := idle
	while guard < 3000 and not (bool(snap.get("in_play", false))
			and bool(snap.get("in_set_piece", false))):
		runtime.step_fixed(10)
		guard += 10
		snap = runtime.get_snapshot()
	var taker := int(snap.get("referee_taker", -1))
	if taker > 0 and int(snap.get("referee_team", -1)) == int(runtime.get_human_team_id()):
		runtime.select_player(taker)
		runtime.set_button(6, true)  # e_ButtonFunction_ShortPass
		runtime.step_fixed(5)
		runtime.set_button(6, false)
	guard = 0
	snap = runtime.get_snapshot()
	while guard < 3000 and not (bool(snap.get("in_play", false))
			and not bool(snap.get("in_set_piece", false))):
		runtime.step_fixed(10)
		guard += 10
		snap = runtime.get_snapshot()
	runtime.step_fixed(40)
	var human_id := int(runtime.get_human_player_id())
	if human_id <= 0:
		_check(false, "a controlled human player is selected")
		return
	runtime.select_player(human_id)
	var pose: Dictionary = runtime.get_player_pose(human_id)
	var pos: Vector3 = pose.get("pos", Vector3.ZERO)
	runtime.debug_set_ball(pos + Vector3(0.2, 0.0, 0.0), Vector3.ZERO)
	runtime.step_fixed(2)
	runtime.set_button(BUTTON_SHOT, true)
	var charged := 0.0
	var charged_id := -1
	for i in 30:
		runtime.step_fixed(2)
		snap = runtime.get_snapshot()
		charged = float(snap.get("charge_ratio", 0.0))
		charged_id = int(snap.get("charge_player_id", -1))
		if charged > 0.05:
			break
	_check(charged > 0.05, "holding shot charges the local human (%.2f)" % charged)
	_check(charged_id == human_id, "the charging player id is the selected human")
	runtime.set_button(BUTTON_SHOT, false)
	# GF keeps the gauge alive until the action's touch lands, so the bar fades
	# when the ball is struck rather than the instant the button is released.
	var cleared := false
	for i in 100:
		runtime.step_fixed(2)
		snap = runtime.get_snapshot()
		if float(snap.get("charge_ratio", 1.0)) == 0.0:
			cleared = true
			break
	_check(cleared, "the charge clears after the action (%.3f, player %d)" % [
		float(snap.get("charge_ratio", -1.0)), int(snap.get("charge_player_id", -2))])

	# Set-piece kicks charge through the same controller. The penalty-only
	# `set_piece_charge` (reticle spread) must not gate the HUD bar.
	runtime.debug_force_set_piece(6, 0)
	guard = 0
	snap = runtime.get_snapshot()
	while guard < 5000 and int(snap.get("set_piece_role", 0)) != 1:
		runtime.step_fixed(10)
		guard += 10
		snap = runtime.get_snapshot()
	_check(int(snap.get("set_piece_role", 0)) == 1, "a human penalty goes live")
	runtime.set_button(BUTTON_SHOT, true)
	var set_piece_charge := 0.0
	var set_piece_id := -1
	for i in 40:
		runtime.step_fixed(2)
		snap = runtime.get_snapshot()
		set_piece_charge = float(snap.get("charge_ratio", 0.0))
		set_piece_id = int(snap.get("charge_player_id", -1))
		if set_piece_charge > 0.05:
			break
	_check(set_piece_charge > 0.05,
		"holding shot charges the set-piece kicker (%.2f)" % set_piece_charge)
	_check(set_piece_id == int(snap.get("set_piece_hud_player", -2)),
		"the set-piece charge belongs to the taker")
	runtime.set_button(BUTTON_SHOT, false)
