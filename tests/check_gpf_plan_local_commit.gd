extends SceneTree
# Headless check that the in-match Game Plan's net commit reaches the real
# local runtime: a position swap changes the live formation and a substitution
# is queued with the expected out/in. The UI tests use a fake runtime; this one
# covers CommitPlanLocal in gdextension/src/gpf_runtime_node.cpp.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_plan_local_commit.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

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


func _find(entries: Array, player_id: int) -> int:
	for index in entries.size():
		if int((entries[index] as Dictionary).get("id", -2)) == player_id:
			return index
	return -1


func _position(squad: Dictionary, player_id: int) -> Vector2:
	for player in squad.get("players", []):
		if int(player.get("id", -2)) == player_id:
			return player.get("position", Vector2.ZERO)
	return Vector2(-99.0, -99.0)


func _run() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8, {"duration": 0.0})
	if package.is_empty():
		print("CHECK FAIL: package")
		quit(1)
		return
	ShellState.clear()
	ShellState.set_teams(package["home"], package["away"])
	ShellState.set_match_package(package)
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	runtime.set_match_package(package)
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime: ", runtime.get_last_error())
		quit(1)
		return
	for attempt in 6000:
		runtime.step_fixed(1)
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_play", false)) and not bool(snap.get("in_set_piece", false)):
			break

	var plan := GpfGamePlan.new()
	get_root().add_child(plan)
	plan.size = Vector2(1920, 1080)
	plan.setup_match(runtime, [0])
	plan.open_plan()
	await process_frame
	await process_frame

	var panel: Dictionary = (plan.get("_panels") as Array)[0]
	var entries: Array = panel["entries"]
	var starters: Array = []
	var bench: Array = []
	for entry in entries:
		if bool(entry.get("left_pitch", false)):
			continue
		if bool(entry.get("active", false)):
			starters.append(entry)
		elif not bool(entry.get("base_active", false)):
			bench.append(entry)
	_check(starters.size() == 11, "the real squad lists eleven starters")
	_check(not bench.is_empty(), "the real squad lists a bench")
	if starters.size() < 3 or bench.is_empty():
		_quit_plan(plan)
		return

	var first: Dictionary = starters[0]
	var second: Dictionary = starters[1]
	var outgoing: Dictionary = starters[2]
	var incoming: Dictionary = bench[0]
	var first_before := _position(runtime.get_squad(0), int(first["id"]))
	var second_before := _position(runtime.get_squad(0), int(second["id"]))

	plan.call("_match_pair", panel, first, second)
	var panel_entries: Array = panel["entries"]
	plan.call("_match_pair", panel, panel_entries[_find(panel_entries, int(outgoing["id"]))],
		panel_entries[_find(panel_entries, int(incoming["id"]))])
	plan.call("_ready_panel", panel)
	await process_frame

	var squad: Dictionary = runtime.get_squad(0)
	_check(_position(squad, int(first["id"])) == second_before
		and _position(squad, int(second["id"])) == first_before,
		"the local commit swaps the live formation")
	var pending: Array = runtime.get_pending_substitutions()
	var found := false
	for pair in pending:
		if int(pair.get("team", -1)) != 0:
			continue
		if int(pair.get("out_id", -2)) == int(outgoing["id"]) \
				and int(pair.get("in_id", -2)) == int(incoming["id"]):
			found = true
			break
	_check(found, "the local commit queues the substitution")

	_quit_plan(plan)


func _quit_plan(plan: GpfGamePlan) -> void:
	if plan != null:
		plan.queue_free()
	if runtime != null:
		runtime.stop_match()
	print("== check_gpf_plan_local_commit: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)
