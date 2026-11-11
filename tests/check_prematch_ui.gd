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


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _open_options_page(view) -> void:
	view.open_settings()
	view.settings_screen.handle_nav(Vector2i.DOWN)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	view.settings_screen.handle_confirm()


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
	_open_options_page(view)
	var duration_row: Dictionary = view.settings_screen.focused_row()
	view.settings_screen.handle_nav(Vector2i.DOWN)
	duration_row = view.settings_screen.focused_row()
	_check(str(duration_row.get("kind", "")) == "choice",
		"match length is a minute preset list")
	_check((duration_row["value"] as Label).text == "10 MIN",
		"the options page starts from the shell options")
	view.settings_screen.close()

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

	# Options: the settings page writes the shell state and the package.
	view.open_options()
	await _frames(2)
	_check(view.settings_screen.is_open(), "the settings screen opens")
	view.settings_screen.handle_nav(Vector2i.DOWN)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	view.settings_screen.handle_confirm()
	var difficulty_slider: HubValueSlider = view.settings_screen.focused_row()["slider"]
	view.settings_screen.handle_nav(Vector2i.DOWN)
	var chosen_duration := MatchPackage.duration_from_minutes(15.0)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	difficulty_slider.set_value(0.6)
	await _frames(3)
	_check(absf(float(ShellState.match_options.get("duration", -1)) - chosen_duration) < 0.001,
		"the chosen match length lands in the shell state")
	_check(absf(float(ShellState.match_options.get("difficulty", -1)) - 0.6) < 0.001,
		"the chosen difficulty lands in the shell state")
	view.close_overlay()
	await _frames(2)

	# Side selection from settings opens over the grid and returns to settings.
	view.open_settings()
	view.settings_screen.handle_nav(Vector2i.DOWN)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	view.settings_screen.handle_confirm()
	_check(view.side_select != null, "Side Selection opens over the settings")
	_check(view.settings_screen.is_open(), "the settings screen stays behind it")
	if view.side_select != null:
		await _tap(KEY_ENTER)
		_check(view.side_select == null, "Enter readies the device and closes side select")
		_check(view.settings_screen.is_open(), "closing side select returns to settings")
	view.settings_screen.close()
	await _frames(2)

	# Game plan: edit a starter, return to the hub and see the column follow.
	view.call("_activate_command", 1)
	await _frames(3)
	_check(view.is_game_plan_open(), "Team management opens the Game Plan overlay")
	_check(view.game_plan.human_teams().has(1) and not view.game_plan.human_teams().has(0),
		"the side chosen in settings carries into the game plan")
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
	_check(absf(float(package["options"]["duration"]) - chosen_duration) < 0.001,
		"the package carries the chosen match length")
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

	# In-match local side select uses UiNav; GpfSlice must not swallow Esc first.
	var slice := current_scene
	if slice != null and slice.name == "GpfSlice":
		slice.call("_open_pause")
		await _frames(4)
		var pause = slice.get("pause_menu")
		if pause != null and pause.is_open():
			var pause_screen = pause.screen
			pause.handle_key(_key(KEY_DOWN))
			pause.handle_key(_key(KEY_ENTER))
			await _frames(3)
			pause.handle_key(_key(KEY_DOWN))
			pause.handle_key(_key(KEY_RIGHT))
			pause.handle_key(_key(KEY_RIGHT))
			pause.handle_key(_key(KEY_ENTER))
			await _frames(4)
			_check(pause_screen.has_local_side_select(),
				"Side Selection opens in the live match")
			Input.parse_input_event(_key(KEY_ESCAPE))
			await _frames(3)
			var release := InputEventKey.new()
			release.keycode = KEY_ESCAPE
			release.pressed = false
			Input.parse_input_event(release)
			await _frames(3)
			_check(not pause_screen.has_local_side_select(),
				"Esc closes the live in-match side select")
			_check(pause_screen.is_settings_page(),
				"Esc returns to settings in the live match")
			pause.handle_key(_key(KEY_ENTER))
			await _frames(3)
			_check(pause_screen.has_local_side_select(),
				"Side Selection reopens from the live settings")
			Input.parse_input_event(_key(KEY_ENTER))
			await _frames(3)
			var enter_release := InputEventKey.new()
			enter_release.keycode = KEY_ENTER
			enter_release.pressed = false
			Input.parse_input_event(enter_release)
			await _frames(3)
			_check(not pause_screen.has_local_side_select(),
				"Enter readies and closes the live side select")
			var human_state: Array = runtime.debug_human_state()
			var away_state: Dictionary = {}
			for entry in human_state:
				if int(entry.get("team", -1)) == 1:
					away_state = entry
			_check(int(away_state.get("gamers", 0)) >= 1
				and int(away_state.get("controlled", 0)) >= 1,
				"the switched side owns a human-controlled player")
			_check(int(runtime.get_human_team_id()) == 1,
				"the human team follows the in-match side change")
			var controlled := int(runtime.get_human_player_id())
			_check(controlled > 0, "the switched side selects an outfield player")
			if controlled > 0:
				runtime.set("manual_step", true)
				runtime.resume_match()
				# Kickoff freezes players until the ball leaves the spot.
				for _step in 20:
					if Vector3(runtime.get_snapshot().get("ball_pos",
							Vector3.ZERO)).length() > 1.5:
						break
					runtime.step_fixed(50)
				var before: Dictionary = runtime.get_player_pose(controlled)
				runtime.set_button(1, true)
				runtime.step_fixed(20)
				runtime.set_button(1, false)
				var after: Dictionary = runtime.get_player_pose(controlled)
				var moved := (Vector3(after.get("pos", Vector3.ZERO))
					- Vector3(before.get("pos", Vector3.ZERO))).length()
				_check(moved > 0.02,
					"the human still moves after the side change")
				var up_before: Dictionary = runtime.get_player_pose(controlled)
				runtime.set_button(0, true)
				runtime.step_fixed(20)
				runtime.set_button(0, false)
				var up_after: Dictionary = runtime.get_player_pose(controlled)
				var up_moved := (Vector3(up_after.get("pos", Vector3.ZERO))
					- Vector3(up_before.get("pos", Vector3.ZERO))).length()
				_check(up_moved > 0.02, "Up still moves after the side change")
				runtime.set("manual_step", false)

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
