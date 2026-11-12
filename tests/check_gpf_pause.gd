extends SceneTree
# Headless check for the in-match pause: the bridge freezes/unfreezes the C++
# match, and the pause menu emits continue / forfeit from keyboard and gamepad.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_pause.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8, {"duration": 0.0})
	if package.is_empty():
		print("CHECK FAIL: package")
		quit(1)
		return
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
	_check(runtime.has_method("set_gameplay_settings"), "the settings bridge is present")
	_check(runtime.has_method("set_gamepad_settings"), "the gamepad bridge is present")
	_run.call_deferred(package)


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


func _tap_key(code: int) -> void:
	var event := _key(code)
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _run(package: Dictionary) -> void:
	var before := int(runtime.get_tick())
	runtime.step_fixed(10)
	_check(int(runtime.get_tick()) > before, "ticks advance before pause")

	runtime.pause_match()
	_check(bool(runtime.get_snapshot().get("paused", false)), "pause_match pauses the match")
	var frozen := int(runtime.get_tick())
	runtime.step_fixed(10)
	_check(int(runtime.get_tick()) == frozen, "ticks stop while paused")

	runtime.resume_match()
	_check(not bool(runtime.get_snapshot().get("paused", true)), "resume_match unpauses")
	runtime.step_fixed(10)
	_check(int(runtime.get_tick()) > frozen, "ticks continue after resume")

	var menu := GpfPauseMenu.new()
	get_root().add_child(menu)
	await process_frame
	menu.setup()
	menu.set_match(runtime, package)
	menu.set_team(0)
	var resumed := [false]
	var forfeited := [false]
	menu.resume_requested.connect(func(): resumed[0] = true)
	menu.forfeit_requested.connect(func(): forfeited[0] = true)

	menu.open()
	_check(menu.is_open(), "the pause menu opens")
	_check(menu.buttons.size() == 6, "the pause menu has the six prototype tiles")
	_check(menu.buttons[0].has_focus(), "Continue owns focus on entry")
	_check(is_equal_approx(menu.screen.scoreboard.size.x, PauseScreen.PAUSE_W),
		"the pause block uses the wide pause layout")
	_check(menu.screen.lineup.card_count() == 11, "the lineup card shows all eleven starters")
	_check(not menu.screen.lineup_tile.title.is_empty()
		and menu.screen.lineup_tile.subtitle.contains("-"),
		"the lineup card carries the team name and formation")

	# A just-committed plan is shown immediately, even before the live match
	# catches up (the client's relay can lag while paused).
	var plan_entries: Array = []
	for index in 11:
		plan_entries.append({
			"name": "PLAN%d" % index,
			"role": "CM",
			"position": Vector2(-0.8 + 0.16 * index, 0.0),
			"rating": 70,
		})
	menu.set_plan_lineups({0: plan_entries})
	menu.open()
	var planned_entries: Array = menu.screen.get("_pending_entries")
	_check(planned_entries.size() == 11
		and str((planned_entries[0] as Dictionary).get("name", "")) == "PLAN0",
		"the pause lineup uses the just-committed plan XI")
	menu.set_plan_lineups({})

	# The package is the pre-match XI; the pause card must follow the live
	# squad and show a queued substitute in the outgoing player's spot.
	var squad: Dictionary = runtime.get_squad(0)
	var out_player: Dictionary = {}
	var in_player: Dictionary = {}
	for player in squad.get("players", []):
		if bool(player.get("active", false)) and out_player.is_empty() \
				and str(player.get("role", "")) != "GK":
			out_player = player
		elif not bool(player.get("active", false)) and in_player.is_empty():
			in_player = player
	if not out_player.is_empty() and not in_player.is_empty():
		_check(runtime.queue_substitution(0, int(out_player.get("id", -1)),
			int(in_player.get("id", -1))), "the pause test queues a substitution")
		menu.open()
		var entries: Array = menu.screen.get("_pending_entries")
		var shown := false
		for entry in entries:
			if str(entry.get("name", "")) == str(in_player.get("name", "")):
				shown = entry.get("position", Vector2.ZERO) \
					== out_player.get("position", Vector2.ZERO)
		_check(shown, "the pause lineup shows the queued substitute in the outgoing's spot")

	menu.set_waiting("WAITING FOR RIVAL 1/2")
	_check(menu.screen.continue_tile.meta.contains("WAITING FOR RIVAL"),
		"the continue tile carries the waiting-for-rival note")
	_check(menu.handle_key(_key(KEY_ENTER)), "Enter is handled by the menu")
	_check(resumed[0] and not menu.is_open(), "Continue resumes and closes the menu")

	menu.open()
	menu.handle_key(_key(KEY_DOWN))
	_check(menu.buttons[4].has_focus(), "Down reaches the Settings tile")
	menu.handle_key(_key(KEY_ENTER))
	_check(menu.screen.is_settings_page(), "Settings opens the settings page")
	_check(menu.screen.settings_screen.is_open(), "the shared settings screen is open")
	_check(menu.screen.settings_screen.mode_name() == "menu",
		"settings opens on the category grid")
	menu.handle_key(_key(KEY_ENTER))
	_check(menu.screen.settings_screen.mode_name() == "gameplay",
		"Enter opens the gameplay sliders")
	menu.handle_key(_key(KEY_DOWN))
	menu.handle_key(_key(KEY_RIGHT))
	_check(not menu.screen.settings_screen.is_capturing(),
		"gameplay rows adjust instead of binding keys")
	menu.handle_key(_key(KEY_ESCAPE))
	_check(menu.screen.settings_screen.mode_name() == "menu",
		"Esc returns to the category grid")
	# Local in-match side selection: opens over the settings, commits back.
	menu.handle_key(_key(KEY_DOWN))
	menu.handle_key(_key(KEY_RIGHT))
	menu.handle_key(_key(KEY_RIGHT))
	menu.handle_key(_key(KEY_ENTER))
	_check(menu.screen.has_local_side_select(), "Side Selection opens in a local match")
	_check(menu.screen.is_settings_page(), "settings stay behind the local side select")
	_check(not menu.screen.settings_screen.visible,
		"the settings screen is replaced by the overlay")
	await _tap_key(KEY_RIGHT)
	await _tap_key(KEY_RIGHT)
	await _tap_key(KEY_ENTER)
	_check(not menu.screen.has_local_side_select(),
		"Enter readies and closes the local side select")
	_check(menu.screen.is_settings_page(), "local side select returns to settings")
	_check(menu.screen.settings_screen.visible, "the settings screen comes back")
	# Esc closes the overlay too.
	menu.handle_key(_key(KEY_DOWN))
	menu.handle_key(_key(KEY_RIGHT))
	menu.handle_key(_key(KEY_RIGHT))
	menu.handle_key(_key(KEY_ENTER))
	_check(menu.screen.has_local_side_select(), "Side Selection reopens")
	await _tap_key(KEY_ESCAPE)
	_check(not menu.screen.has_local_side_select(), "Esc closes the local side select")
	_check(menu.screen.is_settings_page(), "Esc returns to settings")
	menu.handle_key(_key(KEY_ESCAPE))
	_check(not menu.screen.is_settings_page(), "Esc closes settings to the pause page")
	menu.handle_key(_key(KEY_ESCAPE))
	_check(not menu.is_open(), "Esc resumes from the pause page")

	menu.open()
	menu.handle_key(_key(KEY_RIGHT))
	_check(menu.buttons[1].has_focus(), "Right moves to Replay")
	menu.handle_key(_key(KEY_LEFT))
	_check(menu.buttons[0].has_focus(), "Left returns to Continue")
	menu.handle_key(_key(KEY_RIGHT))
	menu.handle_key(_key(KEY_DOWN))
	_check(menu.buttons[5].has_focus(), "Down skips the SOON tiles to Quit Match")
	_check(menu.screen.quit_tile.page_count == 3, "Quit Match is a three-page slot")
	menu.handle_key(_key(KEY_E))
	_check(menu.screen.quit_tile.title == "RESTART MATCH"
		and menu.screen.quit_tile.page_index == 1, "E pages the slot to Restart")
	menu.handle_key(_key(KEY_Q))
	_check(menu.screen.quit_tile.title == "QUIT MATCH"
		and menu.screen.quit_tile.page_index == 0, "Q pages back to Quit")
	menu.handle_key(_key(KEY_RIGHT))
	_check(menu.buttons[5].has_focus() and menu.screen.quit_tile.page_index == 0,
		"sideways arrows no longer page the slot")
	menu.handle_key(_key(KEY_ENTER))
	_check(menu.screen.is_confirm_open(), "forfeit asks for confirmation")
	menu.handle_key(_key(KEY_ENTER))
	_check(forfeited[0], "confirming forfeit emits forfeit_requested")

	menu.open()
	menu.handle_joy(_joy(JOY_BUTTON_B))
	_check(not menu.is_open(), "gamepad B closes the menu")

	# A network pause is a vote: the menu must stay up (no close/reopen blink),
	# only the Continue note changes.
	_check(bool(runtime.net_host(28637, "Pause Test")), "the pause test binds a LAN session")
	menu.open()
	resumed[0] = false
	_check(menu.handle_key(_key(KEY_ENTER)), "the network menu handles Continue")
	_check(resumed[0] and menu.is_open(), "a network vote keeps the pause menu open")
	_check(menu.screen.continue_tile.meta.contains("WAITING FOR RIVAL"),
		"the continue note shows the waiting state")
	resumed[0] = false
	menu.handle_joy(_joy(JOY_BUTTON_B))
	_check(resumed[0] and menu.is_open(), "gamepad B votes without closing the menu")
	runtime.net_leave()

	print("== check_gpf_pause: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _joy(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event
