extends SceneTree
# Headless UI check for the local kit path: Team Select -> Kit Select -> PreMatch,
# the default kit per side, carousel movement, ShellState persistence and the
# package handoff.

const KIT_SELECT := "res://scenes/kit_select.tscn"
const HOME_ID := 4
const AWAY_ID := 5

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event


func _tap_key(code: int) -> void:
	Input.parse_input_event(_key(code, true))
	await _frames(2)
	Input.parse_input_event(_key(code, false))
	await _frames(1)


func _run() -> void:
	ShellState.clear()
	var teams := TeamCatalog.new()
	if not teams.load_data_root(""):
		_check(false, "the team catalog loads")
		_finish()
		return
	var home := teams.team_by_id(HOME_ID)
	var away := teams.team_by_id(AWAY_ID)
	ShellState.set_teams(home, away)
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])

	change_scene_to_file(KIT_SELECT)
	await _frames(12)
	var screen := current_scene
	_check(screen != null and screen.name == "KitSelect", "the kit selection screen opens")
	if screen == null or screen.name != "KitSelect":
		_finish()
		return

	var view: KitSelectView = screen.get("view")
	var catalog: KitCatalog = screen.get("catalog")
	_check(view != null, "the shared KitSelectView is mounted")
	_check(catalog != null and catalog.is_loaded(), "the kit catalog opened")
	_check(catalog != null and catalog.available, "the imported kit specs were found")
	var sides := view.sides()
	_check(sides.size() == 2, "the view has two side snapshots")
	_check(bool(sides[0].get("live", false)), "1P starts on the home side")
	_check(not bool(sides[1].get("live", false)), "the away side is idle until home is ready")
	_check(int(sides[0].get("kit_index", -1)) == 0, "home defaults to the main kit")
	var expected_away_index := catalog.default_away_index(sides[1].get("kits", []), sides[0].get("kit", {}))
	var expected_away_id := str((sides[1].get("kits", []) as Array)[expected_away_index].get("id", ""))
	_check(int(sides[1].get("kit_index", -1)) == expected_away_index,
		"away defaults to the most contrasting kit")
	_check(str(sides[0].get("kit", {}).get("label", "")) == "HOME",
		"the main kit is labelled HOME")
	var home_panel: KitPanel = view.get_node("Design/PanelWrap/Kits/HomePanel")
	_check(home_panel.count_text() == "1 / 4", "the panel shows all four kits")

	await _tap_key(KEY_RIGHT)
	await _frames(3)
	sides = view.sides()
	_check(int(sides[0].get("kit_index", -1)) == 1, "Right moves to the next kit")
	_check(str(sides[0].get("kit", {}).get("label", "")) == "AWAY",
		"the carousel follows the selected kit")
	await _tap_key(KEY_LEFT)
	await _frames(3)
	_check(int(view.sides()[0].get("kit_index", -1)) == 0, "Left moves back to the main kit")

	await _tap_key(KEY_ENTER)
	await _frames(3)
	sides = view.sides()
	_check(bool(sides[0].get("ready", false)), "Enter marks the home kit ready")
	_check(bool(sides[1].get("live", false)), "the away kit becomes live after home ready")
	await _tap_key(KEY_ENTER)
	await _frames(12)
	_check(current_scene != null and current_scene.name == "Prematch",
		"both ready opens the pre-match hub")
	_check(str(ShellState.kit_home.get("id", "")) == "main",
		"the chosen home kit lands in the shell state")
	_check(str(ShellState.kit_away.get("id", "")) == expected_away_id,
		"the chosen away kit lands in the shell state")

	var package: Dictionary = current_scene.call("build_package")
	_check(not package.is_empty(), "the pre-match hub builds a package")
	_check(str(package.get("home", {}).get("kit", {}).get("id", "")) == "main",
		"the package carries the home kit")
	_check(str(package.get("away", {}).get("kit", {}).get("id", "")) == expected_away_id,
		"the package carries the away kit")

	# Back from a fresh kit screen returns to Team Select.
	ShellState.set_teams(home, away)
	change_scene_to_file(KIT_SELECT)
	await _frames(12)
	await _tap_key(KEY_ESCAPE)
	await _frames(10)
	_check(current_scene != null and current_scene.name == "TeamSelect",
		"Esc returns to team selection")

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: kit select UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
