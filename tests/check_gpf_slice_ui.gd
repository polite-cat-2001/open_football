extends SceneTree
# Smoke test for the Godot-side set-piece UI: the aim line for free kicks/corners/goal kicks
# and the Tab taker menu. Loads the real slice scene, forces a free kick through the bridge.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"

var scene: Node
var runtime: Node
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/gpf_slice.tscn")
	scene = packed.instantiate()
	get_root().add_child(scene)
	await process_frame
	runtime = scene.get_node("GpfRuntime")
	runtime.set("manual_step", true)
	runtime.set("data_root", DATA_ROOT)
	for i in 4:
		await process_frame

	var ids: Array = runtime.get_player_ids()
	var outfield := -1
	for entry in ids:
		if int(entry.get("team", -1)) == 0 and String(entry.get("role", "")) == "player":
			outfield = int(entry.get("id", -1))
			break
	_check(outfield >= 0, "outfield exists")
	if outfield < 0:
		_finish()
		return
	runtime.start_open_play(outfield)
	runtime.step_fixed(120)
	runtime.debug_force_set_piece(3, 0)
	var snap: Dictionary = {}
	for i in 500:
		runtime.step_fixed(10)
		await process_frame
		snap = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) and int(snap.get("referee_set_piece", 0)) == 3:
			break
	_check(bool(snap.get("set_piece_local_taker", false)), "free kick has a local taker")
	var hint := scene.get("taker_hint") as Label
	_check(hint != null and hint.visible, "Tab hint is visible for the local taker")
	scene.call("_input", _key(KEY_TAB))
	await process_frame
	_check(bool(scene.get("taker_menu_open")), "Tab opens the taker menu")
	_check(bool(runtime.is_set_piece_taker_menu_open()), "bridge menu is open")
	var menu_label := scene.get("taker_menu_label") as Label
	_check(menu_label != null and "SET-PIECE" not in menu_label.text, "menu lists players")
	scene.call("_input", _key(KEY_ESCAPE))
	await process_frame
	_check(not bool(scene.get("taker_menu_open")), "Escape closes the taker menu")
	_check(not bool(runtime.is_set_piece_taker_menu_open()), "bridge menu is closed")
	runtime.step_fixed(2)
	await process_frame
	var before_taker := int(runtime.get_snapshot().get("referee_taker", -1))
	scene.call("_input", _key(KEY_TAB))
	scene.call("_input", _key(KEY_DOWN))
	scene.call("_input", _key(KEY_ENTER))
	await process_frame
	runtime.step_fixed(3)
	var after: Dictionary = runtime.get_snapshot()
	_check(not bool(scene.get("taker_menu_open")), "Enter closes the taker menu")
	_check(int(after.get("referee_taker", -1)) != before_taker, "Enter applies another taker")

	runtime.start_open_play(outfield)
	await process_frame
	runtime.step_fixed(20)
	scene.call("_input", _key(KEY_O))
	var throw_snap: Dictionary = await _wait_for_set_piece(5)
	_check(not throw_snap.is_empty(), "O forces a throw-in")
	_check(int(throw_snap.get("referee_team", -1)) == 0, "O gives the throw-in to the human team")

	runtime.start_open_play(outfield)
	await process_frame
	runtime.step_fixed(20)
	var alt_o := _key(KEY_O)
	alt_o.alt_pressed = true
	scene.call("_input", alt_o)
	throw_snap = await _wait_for_set_piece(5)
	_check(not throw_snap.is_empty(), "Alt+O forces a throw-in")
	_check(int(throw_snap.get("referee_team", -1)) == 1, "Alt+O gives the throw-in to the opponent")
	_finish()

func _wait_for_set_piece(type: int) -> Dictionary:
	for i in 500:
		runtime.step_fixed(10)
		await process_frame
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) and int(snap.get("referee_set_piece", 0)) == type:
			return snap
	return {}

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: slice set-piece UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
