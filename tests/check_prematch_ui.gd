extends SceneTree
# Headless check for the local MatchHub path: the shared view mounts over the
# real catalog, edits options and the Game Plan lineup, builds the package and
# hands it to the C++ runtime.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const HOME_ID := 4
const AWAY_ID := 5
const EDITED_SLOT := 5
const PREMATCH := "res://scenes/prematch.tscn"

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
	for count_index in count:
		await process_frame


func _tap(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _run() -> void:
	ShellState.clear()
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		_check(false, "the catalog loads")
		_finish()
		return
	var home := catalog.team_by_id(HOME_ID)
	var away := catalog.team_by_id(AWAY_ID)
	ShellState.set_teams(home, away)
	ShellState.set_controllers([
		{"side": "away", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])

	change_scene_to_file(PREMATCH)
	await _frames(10)
	var screen := current_scene
	_check(screen != null and screen.name == "Prematch", "the match hub opens")
	if screen == null or screen.name != "Prematch":
		_finish()
		return
	var view: MatchHubView = screen.get("view")
	_check(view != null, "the hub mounts the shared MatchHubView")
	if view == null:
		_finish()
		return
	_check(view.scoreboard.team_name(0) == str(home.get("name", "")).to_upper(),
		"the scoreboard shows the home team")
	_check(view.scoreboard.team_name(1) == str(away.get("name", "")).to_upper(),
		"the scoreboard shows the away team")
	_check(view.home_lineup.row_count() == 11 and view.away_lineup.row_count() == 11,
		"both columns list eleven starters")
	_check(not view.command_cell(0).disabled, "Start match is enabled with valid lineups")
	_check(view.options_overlay.slider_value("duration") == 1.0,
		"the options overlay starts from the shell options")

	# Back leaves the hub for the kit screen (the previous step in the flow).
	await _tap(KEY_ESCAPE)
	await _frames(8)
	_check(current_scene != null and current_scene.name == "KitSelect",
		"Back returns to the kit selection")

	change_scene_to_file(PREMATCH)
	await _frames(10)
	screen = current_scene
	view = screen.get("view") if screen != null else null
	if view == null:
		_check(false, "the hub reopens after Back")
		_finish()
		return

	# Options: the overlay writes the shell state and the package.
	view.open_options()
	await _frames(2)
	_check(view.options_overlay.visible, "the options overlay opens")
	view.options_overlay._sliders["duration"].set_value(1.5)
	view.options_overlay._sliders["difficulty"].set_value(0.6)
	await _frames(3)
	_check(absf(float(ShellState.match_options.get("duration", -1)) - 1.5) < 0.001,
		"the chosen duration lands in the shell state")
	_check(absf(float(ShellState.match_options.get("difficulty", -1)) - 0.6) < 0.001,
		"the chosen difficulty lands in the shell state")
	view.close_overlay()
	await _frames(2)

	# Game plan: edit a starter, return to the hub and see the column follow.
	view.open_game_plan()
	await _frames(3)
	_check(view.is_game_plan_open(), "Team management opens the Game Plan overlay")
	var home_lineup: MatchLineup = screen.get("home_lineup")
	var away_lineup: MatchLineup = screen.get("away_lineup")
	_check(home_lineup != null and away_lineup != null, "both lineup models load")
	if home_lineup == null or away_lineup == null:
		_finish()
		return
	var promoted := int(home_lineup.bench[0])
	var promoted_name := str(home_lineup.player_by_id(promoted).get("lastname", ""))
	home_lineup.set_starter(EDITED_SLOT, promoted)
	view.game_plan.emit_signal("lineup_changed")
	await _frames(3)
	view.game_plan.emit_signal("close_requested")
	await _frames(3)
	_check(not view.is_game_plan_open(), "the Game Plan closes back into the hub")
	_check(view.home_lineup.row_text(EDITED_SLOT) == promoted_name,
		"the hub column follows the edited lineup")

	var package: Dictionary = screen.call("build_package")
	_check(not package.is_empty(), "the hub builds a match package")
	if package.is_empty():
		_finish()
		return
	_check(int(package["home"]["database_id"]) == HOME_ID
		and int(package["away"]["database_id"]) == AWAY_ID,
		"the package carries the chosen teams")
	_check(absf(float(package["options"]["duration"]) - 1.5) < 0.001,
		"the package carries the chosen duration")
	_check(absf(float(package["options"]["difficulty"]) - 0.6) < 0.001,
		"the package carries the chosen difficulty")
	_check(int(package["home"]["players"][EDITED_SLOT]["database_id"]) == promoted,
		"the edited starter reaches the package")

	view.command_cell(0).pressed.emit()
	await _frames(12)
	_check(current_scene != null and current_scene.name == "GpfSlice",
		"Start match opens the GPF match")
	_check(ShellState.has_package(), "the hub stored the match package")
	var runtime := get_first_node_in_group("gpf_runtime")
	_check(runtime != null and bool(runtime.has_match_package()),
		"the runtime received the package")
	if runtime != null:
		var setup: Array = runtime.get_controller_setup()
		_check(setup.size() == 1 and int(setup[0].get("side", 0)) == 1
			and str(setup[0].get("kind", "")) == "keyboard",
			"the runtime received the away-side keyboard setup")
		var snap: Dictionary = runtime.get_snapshot()
		_check(str(snap.get("team0_name", "")) == str(home.get("name", "")),
			"the match uses the chosen home team")
		_check(str(snap.get("team1_name", "")) == str(away.get("name", "")),
			"the match uses the chosen away team")
		var active_names: Array[String] = []
		for entry in runtime.get_player_ids():
			if int(entry.get("team", -2)) == 0:
				active_names.append(str(entry.get("name", "")))
		_check(active_names.has(promoted_name), "the edited starter is on the pitch")

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: prematch UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
