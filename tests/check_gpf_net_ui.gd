extends SceneTree
# Headless check for the LAN shell screens: main menu -> Network -> Host ->
# mirrored Sides -> Teams lobby -> Match options -> GPF match, plus the Join
# form's readable errors. Drives the same bridge the two-process harness uses,
# but with one host peer.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_net_ui.gd

const MAIN_MENU := "res://scenes/main_menu.tscn"
const NETWORK_MENU := "res://scenes/network_menu.tscn"
const NETWORK_HOST := "res://scenes/network_host.tscn"
const NETWORK_JOIN := "res://scenes/network_join.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"
const PORT_FIRST := 28151
const PORT_TRIES := 20
const NET_SHELL := preload("res://scripts/net/net_shell.gd")

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
	change_scene_to_file(MAIN_MENU)
	await _frames(6)
	var menu := current_scene
	_check(menu != null and menu.name == "MainMenu", "the main menu opens")
	_check(menu != null and menu.get_node_or_null("Design/PanelWrap/PlayGrid/NetworkTile") is Button,
		"the main menu has a Network Match tile")
	if menu != null:
		(menu.get_node("Design/PanelWrap/PlayGrid/NetworkTile") as Button).pressed.emit()
		await _frames(6)
	_check(current_scene != null and current_scene.name == "NetworkMenu",
		"Network opens the network menu")
	var network_menu := current_scene
	if network_menu != null:
		var menu_buttons: Array = network_menu.get("buttons")
		_check(menu_buttons.size() == 3, "the network menu has Host/Join/Back")

	# Join form validation (no connection yet).
	change_scene_to_file(NETWORK_JOIN)
	await _frames(5)
	var join := current_scene
	_check(join != null and join.name == "NetworkJoin", "the join screen opens")
	if join != null:
		var address: LineEdit = join.get("address_input")
		var port: LineEdit = join.get("port_input")
		var player_name: LineEdit = join.get("name_input")
		var join_status: Label = join.get("status_label")
		address.text = "bad address!"
		join.call("_connect")
		_check(join_status.text.contains("Invalid address"),
			"an invalid address is reported")
		address.text = "127.0.0.1"
		port.text = "0"
		join.call("_connect")
		_check(join_status.text.contains("Invalid port"), "an invalid port is reported")
		port.text = "27015"
		player_name.text = ""
		join.call("_connect")
		_check(join_status.text.contains("Enter a name"), "an empty name is reported")

	# Host screen: bind a free port through the real UI entry point.
	change_scene_to_file(NETWORK_HOST)
	await _frames(5)
	var host := current_scene
	_check(host != null and host.name == "NetworkHost", "the host screen opens")
	var runtime: Node = null
	if host != null:
		var host_port: LineEdit = host.get("port_input")
		var host_name: LineEdit = host.get("name_input")
		for offset in PORT_TRIES:
			host_port.text = str(PORT_FIRST + offset)
			host_name.text = "UI Host"
			host.call("_open_lobby")
			await _frames(3)
			if current_scene != null and current_scene.name == "NetworkSides":
				break
		_check(current_scene != null and current_scene.name == "NetworkSides",
			"Open lobby enters the side screen")
		runtime = NET_SHELL.active_runtime(self)
		_check(runtime != null and bool(runtime.is_net_host()),
			"the UI host owns a NetServer")
		_check(runtime != null and runtime.get_snapshot().is_empty(),
			"the lobby runtime has no match yet")
		_check(runtime != null and bool(runtime.is_runtime_ready()),
			"the lobby runtime started without a match")

	var sides := current_scene
	if sides != null and sides.name == "NetworkSides":
		var participants: Array = sides.get("participants")
		_check(participants.size() == 1, "the side screen lists the connected host")
		var participant: Dictionary = participants[0]
		_check(String(participant.get("name", "")) == "UI Host", "the host name is mirrored")
		_check(int(participant.get("side", -9)) == -1, "the host starts on home")
		await _tap_key(KEY_RIGHT)
		await _frames(3)
		await _tap_key(KEY_RIGHT)
		await _frames(3)
		var info := NET_SHELL.lobby(self)
		var players: Array = info.get("lobby", {}).get("players", [])
		_check(players.size() == 1 and int(players[0].get("side", -9)) == 1,
			"Right twice moves the host through centre to away in the lobby")
		await _tap_key(KEY_ENTER)
		await _frames(4)
		info = NET_SHELL.lobby(self)
		players = info.get("lobby", {}).get("players", [])
		_check(players.size() == 1 and bool(players[0].get("ready", false)),
			"Enter readies the host")
		_check(int(info.get("lobby", {}).get("phase", -1)) == 1,
			"the side screen advances the lobby to Teams")
		await _frames(8)

	_check(current_scene != null and current_scene.name == "NetworkLobby",
		"Teams opens the mirrored team lobby")
	var lobby_screen := current_scene
	if lobby_screen != null and lobby_screen.name == "NetworkLobby":
		var lobby_view: TeamSelectView = lobby_screen.get("view")
		_check(lobby_view != null and lobby_view.sides().size() == 2,
			"the team lobby has HOME and AWAY panels")
		var catalog: TeamCatalog = lobby_screen.get("catalog")
		_check(catalog != null and catalog.national_league_id() > 0
			and not catalog.teams_for_league(catalog.national_league_id()).is_empty(),
			"the team lobby loads the catalog on demand")
		_check(NET_SHELL.action(self, "set_selection", 0, 0, 0), "home country selection")
		_check(NET_SHELL.action(self, "set_selection", 0, 2, 3), "home team selection")
		_check(NET_SHELL.action(self, "set_selection", 1, 0, 0), "away country selection")
		_check(NET_SHELL.action(self, "set_selection", 1, 2, 8), "away team selection")
		await _frames(4)

		# The shared view sends the same lobby actions through UiNav.
		var before_team := int(NET_SHELL.lobby(self).get("lobby", {}).get("team_ids", [0])[0])
		await _tap_key(KEY_RIGHT)
		await _frames(4)
		var after_team := int(NET_SHELL.lobby(self).get("lobby", {}).get("team_ids", [0])[0])
		_check(after_team != before_team,
			"the team view sends set_selection through the lobby")
		NET_SHELL.action(self, "set_selection", 0, 2, 3)
		await _frames(4)
		await _tap_key(KEY_ENTER)
		await _frames(4)
		var ready_now: Array = NET_SHELL.lobby(self).get("lobby", {}).get("team_ready", [])
		_check(ready_now.size() > 0 and bool(ready_now[0]),
			"Enter sends set_team_ready through the lobby")
		_check(NET_SHELL.action(self, "set_team_ready", 0, 1, 0), "home team ready")
		_check(NET_SHELL.action(self, "set_team_ready", 1, 1, 0), "away team ready")
		await _frames(8)

	await _frames(8)
	_check(current_scene != null and current_scene.name == "NetworkKitSelect",
		"both team confirmations open the network kit selection")
	if current_scene != null and current_scene.name == "NetworkKitSelect":
		var kit_view: KitSelectView = current_scene.get("view")
		_check(kit_view != null and kit_view.sides().size() == 2,
			"the network kit screen mounts the shared view")
		await _tap_key(KEY_ENTER)
		await _frames(4)
		await _tap_key(KEY_ENTER)
		await _frames(10)

	_check(current_scene != null and current_scene.name == "NetworkMatchHub",
		"the local kit step opens the network match hub")
	var options := current_scene
	if options != null and options.name == "NetworkMatchHub":
		await _tap_key(KEY_ESCAPE)
		await _frames(8)
		_check(current_scene != null and current_scene.name == "NetworkKitSelect",
			"Back from the network hub returns to the kit step")
		if current_scene != null and current_scene.name == "NetworkKitSelect":
			await _tap_key(KEY_ENTER)
			await _frames(4)
			await _tap_key(KEY_ENTER)
			await _frames(10)
		options = current_scene
		_check(options != null and options.name == "NetworkMatchHub",
			"the kit step returns to the network hub")
		var hub_view: MatchHubView = options.get("view") if options != null else null
		_check(hub_view != null, "the network hub mounts the shared MatchHubView")
		_check(NET_SHELL.action(self, "set_team_ready", 0, 1, 0), "host team ready")
		_check(NET_SHELL.action(self, "set_team_ready", 1, 1, 0), "away team ready")
		await _frames(4)
		if hub_view != null:
			_check(not hub_view.command_cell(0).disabled, "host Start is enabled")
			_check(hub_view.options_overlay.is_editable(), "host options are editable")
			hub_view.options_overlay._sliders["difficulty"].set_value(0.9)
			await _frames(8)
			var lobby_now: Dictionary = NET_SHELL.lobby(self).get("lobby", {})
			_check(absf(float(lobby_now.get("match_difficulty", 0.0)) - 0.9) < 0.001,
				"the host difficulty reaches the lobby")
		options.call("_start_host")
		await _frames(12)

	_check(current_scene != null and current_scene.name == "GpfSlice",
		"Start match opens the GPF match scene")
	var snap: Dictionary = runtime.get_snapshot() if runtime != null else {}
	_check(not snap.is_empty(), "the host net match has a snapshot")
	_check(bool(snap.get("net_active", false)) and bool(snap.get("net_is_host", false)),
		"the match runs with the host network session")
	_check(String(snap.get("team0_name", "")) != "" and String(snap.get("team1_name", "")) != "",
		"the match is built from the lobby teams")

	# LAN pause: the menu opens on the paused snapshot and Continue is a resume
	# vote (with one peer it resolves immediately).
	var slice := current_scene
	if runtime != null:
		runtime.pause_match()
		await _frames(8)
		var pause_menu = slice.get("pause_menu") if slice != null else null
		snap = runtime.get_snapshot()
		_check(bool(snap.get("paused", false)), "pause_match freezes the net match")
		_check(pause_menu != null and pause_menu.is_open(), "the pause menu opens on the paused peer")
		if pause_menu != null:
			_check(pause_menu.hint_label.text.contains("resume ready"),
				"the pause menu shows the resume vote tally")
			slice.call("_on_pause_resume")
			# Headless frames can be far shorter than a 10 ms sim tick; drive the
			# network session explicitly so the resume vote is consumed.
			runtime.step_fixed(5)
			await _frames(12)
			snap = runtime.get_snapshot()
			_check(not bool(snap.get("paused", true)), "the resume vote unpauses the match")
			_check(not pause_menu.is_open(), "the pause menu closes after the resume")

	# In-match side selection: the pause menu opens the mirrored overlay, the
	# host commits once every row is ready and the match resumes.
	if runtime != null and slice != null:
		runtime.pause_match()
		await _frames(8)
		var pause_menu = slice.get("pause_menu")
		_check(pause_menu != null and pause_menu.is_open(),
			"the pause menu reopens for side selection")
		if pause_menu != null:
			for i in 3:
				slice.call("_input", _key(KEY_DOWN))
			slice.call("_input", _key(KEY_ENTER))
			await _frames(6)
			var overlay = slice.get("side_select_overlay")
			_check(overlay != null and overlay.is_visible_in_tree(),
				"side selection opens the mirrored overlay")
			_check(bool(NET_SHELL.lobby(self).get("lobby", {}).get("side_select", false)),
				"the lobby enters mirrored side-select mode")
			_check(not pause_menu.is_open(), "the pause menu hands over to the overlay")
			if overlay != null:
				await _tap_key(KEY_LEFT)
				await _frames(4)
				var players_after: Array = NET_SHELL.lobby(self).get("lobby", {}).get("players", [])
				_check(players_after.size() == 1 and int(players_after[0].get("side", -9)) == 2,
					"the overlay moves the host side through the lobby")
				await _tap_key(KEY_RIGHT)
				await _frames(4)
				await _tap_key(KEY_ENTER)
				await _frames(10)
				_check(slice.get("side_select_overlay") == null,
					"the host commit closes the overlay")
				snap = runtime.get_snapshot()
				_check(not bool(snap.get("paused", true)), "the side-select commit unpauses")
				_check(not bool(NET_SHELL.lobby(self).get("lobby", {}).get("side_select", true)),
					"the commit clears the side-select flag")

	# Cancel (Esc in the overlay): the host applies the chosen sides but keeps
	# the match paused, and the pause menu comes back.
	if runtime != null and slice != null:
		runtime.pause_match()
		await _frames(8)
		var pause_menu = slice.get("pause_menu")
		if pause_menu != null and pause_menu.is_open():
			pause_menu.index = 3
			slice.call("_input", _key(KEY_ENTER))
			await _frames(6)
			var overlay = slice.get("side_select_overlay")
			_check(overlay != null, "side selection reopens for the cancel path")
			if overlay != null:
				await _tap_key(KEY_ESCAPE)
				await _frames(10)
				_check(slice.get("side_select_overlay") == null, "cancel closes the overlay")
				_check(not bool(NET_SHELL.lobby(self).get("lobby", {}).get("side_select", true)),
					"cancel clears the side-select flag")
				snap = runtime.get_snapshot()
				_check(bool(snap.get("paused", false)), "cancel keeps the match paused")
				_check(pause_menu.is_open(), "cancel returns to the pause menu")
				slice.call("_on_pause_resume")
				runtime.step_fixed(5)
				await _frames(10)
				_check(not bool(runtime.get_snapshot().get("paused", true)),
					"the match resumes after the cancel path")

	# LAN half-time: the host break overlay is a resume vote for every peer.
	if runtime != null and slice != null:
		runtime.debug_force_phase_break(2)
		runtime.step_fixed(5)
		await _frames(10)
		var hud = slice.get("hud")
		snap = runtime.get_snapshot()
		_check(bool(snap.get("paused", false)), "the forced break pauses the net match")
		_check(hud != null and bool(hud.phase_menu_open), "the break overlay opens")
		if hud != null:
			hud.call("continue_phase_break")
			runtime.step_fixed(5)
			await _frames(12)
			snap = runtime.get_snapshot()
			_check(not bool(snap.get("paused", true)), "the break resume vote unpauses")
			_check(not bool(hud.phase_menu_open), "the break overlay closes after the resume")

	if current_scene != null and current_scene.has_method("_return_to_main_menu"):
		current_scene.call("_return_to_main_menu")
		await _frames(8)
	_check(not NET_SHELL.is_active(self), "returning to the menu leaves the LAN session")

	ShellState.clear()
	if failures.is_empty():
		print("== check_gpf_net_ui: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_gpf_net_ui: FAIL ==")
	quit(0 if failures.is_empty() else 1)
