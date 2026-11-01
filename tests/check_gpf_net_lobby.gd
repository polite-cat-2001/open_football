extends SceneTree
# Headless check for the LAN foundation (ticket 18): the bridge can host a
# NetServer, expose the host-authoritative lobby, apply side/ready/selection
# actions, start a host-owned net match and tear the session down again.
# No second process yet.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_net_lobby.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const PORT_FIRST := 27851
const PORT_TRIES := 20

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8)
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
	if not runtime.set_match_package(package):
		print("CHECK FAIL: match package rejected: ", runtime.get_last_error())
		quit(1)
		return
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime: ", runtime.get_last_error())
		quit(1)
		return
	# The lobby exists before the match: park the fixture match the runtime
	# started while bringing the original runtime up.
	runtime.stop_match()
	_run()
	print("== check_gpf_net_lobby: ", "PASS" if failures.is_empty() else "FAIL", " ===")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _host_any_port() -> int:
	for offset in PORT_TRIES:
		var port := PORT_FIRST + offset
		if runtime.net_host(port, "Tester"):
			return port
		print("  (port ", port, " busy: ", runtime.get_last_error(), ")")
	return -1


func _players(info: Dictionary) -> Array:
	return Array(info.get("lobby", {}).get("players", []))


func _run() -> void:
	_check(not runtime.is_net_active(), "no network session before net_host")

	var port := _host_any_port()
	_check(port > 0, "net_host binds a port")
	if port <= 0:
		return
	_check(runtime.is_net_active() and runtime.is_net_host(), "host session is active")
	_check(not runtime.is_net_client(), "host is not a client")

	var info: Dictionary = runtime.net_lobby()
	_check(bool(info.get("active", false)), "net_lobby reports an active session")
	_check(bool(info.get("is_host", false)), "net_lobby reports the host role")
	_check(int(info.get("local_id", -1)) == 0, "the host is player 0")
	_check(int(info.get("connection", -1)) == 3, "the host connection is connected")
	_check(bool(info.get("accepted", false)), "the host session is accepted")
	_check(String(info.get("reject_text", "x")) == "", "no reject text on the host")

	var players := _players(info)
	_check(players.size() == 1, "the host lobby starts with exactly one player")
	if players.size() == 1:
		var host: Dictionary = players[0]
		_check(int(host.get("id", -1)) == 0, "the lobby player is the host id")
		_check(String(host.get("name", "")) == "Tester", "the host name is mirrored")
		_check(bool(host.get("is_host", false)), "the lobby player is marked as host")
		_check(int(host.get("side", -1)) == 0, "the host starts on the home side")
		_check(not bool(host.get("ready", true)), "the host starts not ready")

	var lobby: Dictionary = info.get("lobby", {})
	_check(int(lobby.get("phase", -1)) == 0, "the lobby starts in the Sides phase")
	_check(not bool(lobby.get("side_select", true)), "side select is off in the lobby")
	_check(Array(lobby.get("team_ids", [])) == [-1, -1], "no teams are selected yet")

	_check(runtime.net_action("set_side", 1, 1, 0), "SetSide action is accepted")
	info = runtime.net_lobby()
	_check(int(_players(info)[0].get("side", -1)) == 1, "the host moved to the away side")

	# Raw enum form works too (SetDevice = 6).
	_check(runtime.net_action(6, 0, 1, 0), "raw action enum is accepted")
	info = runtime.net_lobby()
	_check(int(_players(info)[0].get("device", -1)) == 1, "the lobby device was updated")

	_check(runtime.net_action("set_ready", 0, 1, 0), "SetReady action is accepted")
	info = runtime.net_lobby()
	lobby = info.get("lobby", {})
	_check(bool(_players(info)[0].get("ready", false)), "the host is ready")
	_check(int(lobby.get("phase", -1)) == 1, "all ready advances the lobby to Teams")
	var chooser := Array(lobby.get("chooser", []))
	_check(chooser.size() == 2 and int(chooser[0]) == 0 and int(chooser[1]) == 0,
		"the host chooses both sides when alone")

	# Home picks team 3, away picks team 8 (the fixture package).
	_check(runtime.net_action("set_selection", 0, 0, 0), "home country selection is accepted")
	_check(runtime.net_action("set_selection", 0, 2, 3), "home team selection is accepted")
	_check(runtime.net_action("set_selection", 1, 0, 0), "away country selection is accepted")
	_check(runtime.net_action("set_selection", 1, 2, 8), "away team selection is accepted")
	info = runtime.net_lobby()
	lobby = info.get("lobby", {})
	var team_ids := Array(lobby.get("team_ids", []))
	_check(team_ids == [3, 8], "the lobby holds the chosen team ids")
	_check(Array(lobby.get("team_ready", [])) == [false, false], "teams are not confirmed yet")

	check_not_started_yet(info)
	_check(runtime.net_action("set_team_ready", 0, 1, 0), "home team confirmation is accepted")
	_check(runtime.net_action("set_team_ready", 1, 1, 0), "away team confirmation is accepted")
	info = runtime.net_lobby()
	_check(int(info.get("lobby", {}).get("phase", -1)) == 2,
		"both teams confirmed advance the lobby to Options")

	_check(not runtime.net_action("nonsense", 0, 0, 0), "unknown lobby actions are rejected")

	_check(runtime.net_start(), "net_start starts the host match")
	var snap: Dictionary = runtime.get_snapshot()
	_check(not snap.is_empty(), "the net match produces a snapshot")
	_check(bool(snap.get("net_active", false)), "the snapshot reports the net session")
	_check(bool(snap.get("net_is_host", false)), "the snapshot reports the host role")
	_check(not bool(snap.get("net_is_client", true)), "the snapshot reports no client role")
	_check(int(snap.get("net_local_id", -1)) == 0, "the snapshot reports the local player id")
	_check(int(snap.get("net_connection", -1)) == 3, "the snapshot reports a live connection")
	_check(int(snap.get("net_phase_state", -1)) == 0, "an unpaused net match is playing")
	_check(String(snap.get("team0_name", "")) != "" and String(snap.get("team1_name", "")) != "",
		"the match is built from both chosen teams")

	var before := int(runtime.get_tick())
	runtime.step_fixed(20)
	_check(int(runtime.get_tick()) > before, "the host net match advances its tick")

	var setup: Dictionary = runtime.net_take_match_setup()
	_check(setup.is_empty(), "the host has no pending MatchSetup")

	_check(runtime.net_leave(), "net_leave tears the session down")
	_check(not runtime.is_net_active(), "no network session after net_leave")
	_check(not runtime.is_net_host(), "the host role is cleared after net_leave")
	_check(runtime.get_snapshot().is_empty(), "net_leave stops the net match")

	# The port must be released: hosting again on the same port proves it.
	_check(runtime.net_host(port, "Second"), "the same port can be hosted again")
	if runtime.is_net_active():
		runtime.net_leave()


func check_not_started_yet(_info: Dictionary) -> void:
	_check(runtime.get_snapshot().is_empty(), "no match exists before net_start")
