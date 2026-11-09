extends SceneTree
# Headless check for the ported SetPieceTakerPage overlay (ticket 21):
# home/away candidate lists, the owner-device gate in 2P, navigation/apply and
# the auto-close rules. The last section drives a real C++ runtime where the
# human plays away, to prove the list follows the taker's team.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_set_piece_taker.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/open_football_career/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []


class FakeRuntime:
	extends Node
	var snapshot: Dictionary = {}
	var player_ids: Array = []
	var candidates: Array = []
	var available := true
	var menu_open := false
	var closed_count := 0
	var requested: Array = []
	var match_duration := 1.0
	var human_team := 0

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func get_player_ids() -> Array:
		return player_ids.duplicate(true)

	func get_human_team_id() -> int:
		return human_team

	func is_set_piece_taker_menu_available() -> bool:
		return available

	func is_set_piece_taker_menu_open() -> bool:
		return menu_open

	func open_set_piece_taker_menu() -> bool:
		if not available:
			return false
		menu_open = true
		snapshot["set_piece_taker_menu_open"] = true
		return true

	func close_set_piece_taker_menu() -> void:
		menu_open = false
		closed_count += 1
		snapshot["set_piece_taker_menu_open"] = false

	func get_set_piece_taker_candidates() -> Array:
		return candidates.duplicate(true)

	func request_set_piece_taker(player_id: int) -> void:
		requested.append(player_id)


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _joy(device: int, button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event


func _candidate(id: int, team: int, name: String, role: String = "player",
		current: bool = false) -> Dictionary:
	return {"id": id, "team": team, "name": name, "role": role, "current": current}


func _snapshot(hud_player: int, taker: int, team: int, menu_open: bool = false,
		in_set_piece: bool = true, local: bool = true) -> Dictionary:
	return {
		"score0": 1, "score1": 0, "match_time_ms": 600000, "match_phase": 1,
		"team0_name": "HOME", "team1_name": "AWAY", "human_team": team,
		"in_play": false, "in_set_piece": in_set_piece,
		"set_piece_type": 3, "referee_set_piece": 3, "referee_team": team,
		"referee_taker": taker, "set_piece_taker": taker,
		"set_piece_hud_player": hud_player, "set_piece_human_taker": local,
		"set_piece_local_taker": local,
		"set_piece_taker_menu_available": true,
		"set_piece_taker_menu_open": menu_open,
		"phase_break_pending": false, "phase_break": false,
		"game_over": false, "paused": false, "shootout_active": false,
	}


func _wait() -> void:
	await process_frame


func _make_hud(fake: Node) -> GpfHud:
	var hud := GpfHud.new()
	get_root().add_child(hud)
	hud.setup(fake)
	return hud


func _drop(node: Node) -> void:
	node.queue_free()


func _run() -> void:
	await _check_home_and_away()
	await _check_two_players()
	await _check_auto_close()
	await _check_real_away_runtime()
	print("== check_gpf_set_piece_taker: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _check_home_and_away() -> void:
	print("-- home and away candidate lists")
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var fake := FakeRuntime.new()
	fake.player_ids = [
		{"id": 10, "team": 0, "role": "goalkeeper", "name": "HOME GK"},
		{"id": 11, "team": 0, "role": "player", "name": "HOME A"},
		{"id": 12, "team": 0, "role": "player", "name": "HOME B"},
	]
	fake.candidates = [
		_candidate(12, 0, "HOME B", "player", true),
		_candidate(10, 0, "HOME GK", "goalkeeper"),
	]
	fake.snapshot = _snapshot(12, 12, 0)
	var hud := _make_hud(fake)
	hud.update(fake.snapshot, 12, 0, false, "Afternoon")
	var hint := hud.get("taker_hint") as Label
	_check(hint != null and hint.visible, "home taker hint is visible")
	_check(bool(hud.toggle_taker_menu("keyboard", 0)), "home keyboard opens the menu")
	var menu: GpfSetPieceTakerMenu = hud.get("taker_menu")
	var texts := menu.button_texts()
	_check(texts.size() == 2, "every active player is listed")
	_check(texts[0] == "HOME B *", "current taker is marked *")
	_check(texts[1] == "HOME GK (GK)", "keeper caption gets (GK)")
	_check(menu.selected_index() == 0, "focus starts on the current taker")
	_check(hud.handle_taker_menu_key(_key(KEY_DOWN)), "Down moves the selection")
	_check(menu.selected_index() == 1, "selection moved")
	_check(hud.handle_taker_menu_key(_key(KEY_ENTER)), "Enter applies")
	_check(fake.requested == [10], "the chosen player is requested")
	_check(not hud.is_taker_menu_open(), "applying closes the menu")
	_check(not fake.menu_open and fake.closed_count == 1, "bridge menu is closed")
	_drop(hud)
	await _wait()

	ShellState.set_controllers([
		{"side": "away", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	fake = FakeRuntime.new()
	fake.human_team = 1
	fake.player_ids = [
		{"id": 20, "team": 1, "role": "player", "name": "AWAY A"},
		{"id": 21, "team": 1, "role": "player", "name": "AWAY B"},
	]
	fake.candidates = [
		_candidate(20, 1, "AWAY A", "player", true),
		_candidate(21, 1, "AWAY B"),
	]
	fake.snapshot = _snapshot(20, 20, 1)
	hud = _make_hud(fake)
	hud.update(fake.snapshot, 20, 0, false, "Afternoon")
	_check(bool(hud.toggle_taker_menu("keyboard", 0)),
		"away human opens the menu with his keyboard")
	menu = hud.get("taker_menu")
	_check(menu.button_texts()[0] == "AWAY A *", "away list is the away team's")
	_check(hud.handle_taker_menu_key(_key(KEY_DOWN)), "away navigation works")
	_check(hud.handle_taker_menu_key(_key(KEY_ENTER)), "away apply works")
	_check(fake.requested == [21], "away choice is requested")
	_check(fake.human_team == 1, "control stays with the away human")
	_drop(hud)
	await _wait()


func _check_two_players() -> void:
	print("-- two local players: only the taker's device drives the menu")
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
		{"side": "away", "kind": "gamepad", "device": 3, "name": "Pad"},
	])
	var fake := FakeRuntime.new()
	fake.human_team = 1
	fake.player_ids = [
		{"id": 10, "team": 0, "role": "player", "name": "HOME A"},
		{"id": 20, "team": 1, "role": "player", "name": "AWAY A"},
		{"id": 21, "team": 1, "role": "player", "name": "AWAY B"},
	]
	fake.candidates = [
		_candidate(20, 1, "AWAY A", "player", true),
		_candidate(21, 1, "AWAY B"),
	]
	fake.snapshot = _snapshot(20, 20, 1)
	var hud := _make_hud(fake)
	hud.update(fake.snapshot, 20, 0, false, "Afternoon")
	_check(not hud.toggle_taker_menu("keyboard", 0),
		"the away taker's menu cannot be opened by the home keyboard")
	_check(not hud.toggle_taker_menu("gamepad", 4),
		"an unassigned pad cannot open it")
	_check(hud.toggle_taker_menu("gamepad", 3),
		"the away taker's own pad opens it")
	var menu: GpfSetPieceTakerMenu = hud.get("taker_menu")
	_check(not hud.toggle_taker_menu("keyboard", 0),
		"the home keyboard cannot close the away menu")
	_check(not hud.toggle_taker_menu("gamepad", 4),
		"an unassigned pad cannot close it either")
	_check(hud.is_taker_menu_open(), "the away menu stays open")
	var selected_before := menu.selected_index()
	_check(not hud.handle_taker_menu_key(_key(KEY_DOWN)),
		"the home keyboard cannot drive the away menu")
	_check(menu.selected_index() == selected_before, "selection did not move")
	_check(not hud.handle_taker_menu_joy(_joy(4, JOY_BUTTON_A)),
		"another pad cannot apply")
	_check(hud.handle_taker_menu_joy(_joy(3, JOY_BUTTON_DPAD_DOWN)),
		"the owner pad navigates")
	_check(menu.selected_index() == 1, "owner pad moved the selection")
	_check(hud.handle_taker_menu_joy(_joy(3, JOY_BUTTON_A)),
		"the owner pad applies")
	_check(fake.requested == [21], "the owner pad's choice is requested")
	_check(not hud.is_taker_menu_open(), "pad apply closes the menu")
	_drop(hud)
	await _wait()

	# A home taker in the same 2P session is owned by the keyboard, not the pad.
	fake = FakeRuntime.new()
	fake.player_ids = [
		{"id": 10, "team": 0, "role": "player", "name": "HOME A"},
		{"id": 11, "team": 0, "role": "player", "name": "HOME B"},
		{"id": 20, "team": 1, "role": "player", "name": "AWAY A"},
	]
	fake.candidates = [
		_candidate(10, 0, "HOME A", "player", true),
		_candidate(11, 0, "HOME B"),
	]
	fake.snapshot = _snapshot(10, 10, 0)
	hud = _make_hud(fake)
	hud.update(fake.snapshot, 10, 0, false, "Afternoon")
	var hint := hud.get("taker_hint") as Label
	_check(hint != null and hint.text == "Tab: change taker",
		"the home keyboard taker sees the Tab hint")
	_check(not hud.toggle_taker_menu("gamepad", 3),
		"the away pad cannot open the home taker's menu")
	_check(hud.toggle_taker_menu("keyboard", 0),
		"the home keyboard opens its own menu")
	hud.close_taker_menu(false)
	_drop(hud)
	await _wait()


func _check_auto_close() -> void:
	print("-- auto-close")
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var fake := FakeRuntime.new()
	fake.player_ids = [
		{"id": 10, "team": 0, "role": "player", "name": "HOME A"},
		{"id": 11, "team": 0, "role": "player", "name": "HOME B"},
	]
	fake.candidates = [
		_candidate(10, 0, "HOME A", "player", true),
		_candidate(11, 0, "HOME B"),
	]
	fake.snapshot = _snapshot(10, 10, 0)
	var hud := _make_hud(fake)
	hud.update(fake.snapshot, 10, 0, false, "Afternoon")
	_check(hud.toggle_taker_menu("keyboard", 0), "menu opens before the auto-close checks")
	var hint := hud.get("taker_hint") as Label
	_check(hint != null and hint.visible, "the hint is visible while the menu is closed")
	hud.close_taker_menu(false)
	hud.update(fake.snapshot, 10, 0, false, "Afternoon")
	_check(hud.toggle_taker_menu("keyboard", 0), "menu opens again for the kick-key check")
	hud.handle_taker_menu_key(_key(KEY_W))
	_check(not hud.is_taker_menu_open(), "a kick key closes the menu without applying")
	_check(fake.requested.is_empty(), "the kick key did not change the taker")

	fake.snapshot = _snapshot(10, 10, 0)
	hud.update(fake.snapshot, 10, 0, false, "Afternoon")
	_check(hud.toggle_taker_menu("keyboard", 0), "menu reopens")
	hud.update(_snapshot(10, 10, 0, true, false), 10, 0, false, "Afternoon")
	_check(not hud.is_taker_menu_open(), "the end of the set piece closes the menu")

	fake.snapshot = _snapshot(10, 10, 0)
	hud.update(fake.snapshot, 10, 0, false, "Afternoon")
	_check(hud.toggle_taker_menu("keyboard", 0), "menu reopens again")
	hud.update(_snapshot(10, 11, 0, true, true, false), 10, 0, false, "Afternoon")
	_check(not hud.is_taker_menu_open(), "losing the human taker closes the menu")
	_check(not fake.menu_open, "the bridge menu is closed on auto-close")
	_drop(hud)
	await _wait()


func _check_real_away_runtime() -> void:
	print("-- real runtime: human away takes the set piece")
	var package := MatchPackageFixture.build(DATA_ROOT, 7633, 8590, {"duration": 0.0})
	if package.is_empty():
		_check(false, "match package builds")
		return
	ShellState.set_match_package(package)
	ShellState.set_controllers([
		{"side": "away", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var runtime: Node = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		_check(false, "GpfRuntimeNode is registered")
		return
	runtime.set("manual_step", true)
	runtime.set("data_root", DATA_ROOT)
	runtime.set_match_package(package)
	runtime.set_controller_setup([{"side": 1, "kind": "keyboard", "slot": 0}])
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready() or not runtime.restart_match():
		_check(false, "runtime starts: " + str(runtime.get_last_error()))
		return
	runtime.step_fixed(5)
	await process_frame
	var ids: Array = runtime.get_player_ids()
	var away_outfield := -1
	for entry in ids:
		if int(entry.get("team", -1)) == 1 and String(entry.get("role", "")) == "player":
			away_outfield = int(entry.get("id", -1))
			break
	_check(away_outfield > 0, "an away outfield player exists")
	if away_outfield <= 0:
		return
	runtime.start_open_play(away_outfield)
	runtime.select_player(away_outfield)
	for i in 12:
		runtime.step_fixed(10)
		await process_frame
	_check(int(runtime.get_human_team_id()) == 1, "the human plays away")
	_check(int(runtime.get_human_player_id()) == away_outfield,
		"the away human is the controlled player")

	runtime.debug_force_set_piece(3, 1)
	var snap: Dictionary = {}
	var found := false
	for i in 500:
		runtime.step_fixed(10)
		await process_frame
		snap = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) \
				and int(snap.get("referee_team", -1)) == 1 \
				and int(snap.get("referee_taker", -1)) > 0 \
				and bool(snap.get("set_piece_local_taker", false)):
			found = true
			break
	_check(found, "the away human's free kick reaches the live state")
	if not found:
		return
	var hud_player := int(snap.get("set_piece_hud_player", -1))
	_check(hud_player > 0, "the snapshot names the away human")
	var taker := int(snap.get("referee_taker", -1))
	_check(hud_player != int(runtime.get_human_player_id()) or hud_player == taker,
		"the HUD player follows the away taker")

	var hud := _make_hud(runtime)
	hud.update(snap, taker, 0, false, "Afternoon")
	var hint := hud.get("taker_hint") as Label
	_check(hint != null and hint.visible and hint.text == "Tab: change taker",
		"the away keyboard taker sees the Tab hint")
	_check(hud.toggle_taker_menu("keyboard", 0),
		"the away human opens the taker menu")
	_check(runtime.is_set_piece_taker_menu_open(), "the bridge flip is on")
	var menu: GpfSetPieceTakerMenu = hud.get("taker_menu")
	var candidates: Array = menu.get("candidates")
	var all_away := true
	var current_marked := 0
	for entry in candidates:
		all_away = all_away and int(entry.get("team", -1)) == 1
		if bool(entry.get("current", false)):
			current_marked += 1
	_check(all_away, "the list holds the away team's players")
	_check(current_marked == 1, "the current away taker is marked")
	var before_taker := taker
	var before_human_team := int(runtime.get_human_team_id())
	hud.handle_taker_menu_key(_key(KEY_DOWN))
	hud.handle_taker_menu_key(_key(KEY_ENTER))
	for i in 4:
		runtime.step_fixed(5)
		await process_frame
	var after: Dictionary = runtime.get_snapshot()
	_check(not hud.is_taker_menu_open(), "away apply closes the menu")
	_check(not runtime.is_set_piece_taker_menu_open(), "the bridge flip is off")
	_check(int(after.get("referee_taker", -1)) != before_taker,
		"the away taker changes")
	_check(int(runtime.get_human_team_id()) == before_human_team,
		"control stays with the away player")
	_drop(hud)
	await _wait()
	runtime.stop_match()
