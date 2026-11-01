extends SceneTree
# LAN two-process check: this process hosts, a child Godot process joins over
# localhost, completes the lobby and starts the same match from MatchSetup.
# The child reports its remote-presentation snapshot as JSON.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_net_two_process.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const CLIENT_SCRIPT := "res://tests/gpf_net_client_probe.gd"
const PORT_FIRST := 27951
const PORT_TRIES := 20

var failures: Array[String] = []
var runtime: Node
var client_result: Dictionary = {}
var last_snapshot: Dictionary = {}


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
	runtime.stop_match()

	var port := _host_any_port()
	if port <= 0:
		print("CHECK FAIL: no free port: ", runtime.get_last_error())
		quit(1)
		return

	var result_path := ProjectSettings.globalize_path("user://gpf_net_client_probe.json")
	var running_path := ProjectSettings.globalize_path("user://gpf_net_client_running.json")
	var pause_path := ProjectSettings.globalize_path("user://gpf_net_client_paused.json")
	var host_vote_path := ProjectSettings.globalize_path("user://gpf_net_host_voted.json")
	var side_done_path := ProjectSettings.globalize_path("user://gpf_net_client_side_done.json")
	var resume_done_path := ProjectSettings.globalize_path("user://gpf_net_client_resumed.json")
	var rejoin_path := ProjectSettings.globalize_path("user://gpf_net_client_rejoin.json")
	for path in [result_path, running_path, pause_path, host_vote_path, side_done_path,
			resume_done_path, rejoin_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	var args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", CLIENT_SCRIPT,
		"--",
		"127.0.0.1", str(port), result_path, running_path, pause_path, host_vote_path,
		side_done_path, resume_done_path,
	])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		print("CHECK FAIL: could not start the client process")
		runtime.net_leave()
		quit(1)
		return

	_run(port, pid, result_path, running_path, pause_path, host_vote_path, side_done_path,
		resume_done_path, rejoin_path)

	if runtime.is_net_active():
		runtime.net_leave()
	if OS.is_process_running(pid):
		OS.kill(pid)
	for path in [result_path, running_path, pause_path, host_vote_path, side_done_path,
			resume_done_path, rejoin_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	print("== check_gpf_net_two_process: ", "PASS" if failures.is_empty() else "FAIL", " ===")
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
		if runtime.net_host(port, "Host"):
			return port
		print("  (port ", port, " busy: ", runtime.get_last_error(), ")")
	return -1


func _lobby() -> Dictionary:
	return Dictionary(runtime.net_lobby().get("lobby", {}))


func _has_players(count: int) -> bool:
	var players: Array = _lobby().get("players", [])
	return players.size() >= count


func _client_on_side(side: int) -> bool:
	var players: Array = _lobby().get("players", [])
	return players.size() >= 2 and int(players[1].get("side", -1)) == side


func _phase_is(phase: int) -> bool:
	return int(_lobby().get("phase", -1)) == phase


func _options_ready() -> bool:
	var state := _lobby()
	var ids: Array = state.get("team_ids", [])
	var ready: Array = state.get("team_ready", [])
	return int(state.get("phase", -1)) == 2 and ids == [3, 8] and ready == [true, true]


func _wait_until(predicate: Callable, timeout_ms: int, poll_ms: int = 50) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		OS.delay_msec(poll_ms)
	return false


func _poll_kickoff_ready() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return (bool(last_snapshot.get("in_play", false)) and
		bool(last_snapshot.get("in_set_piece", false)) and
		int(last_snapshot.get("referee_taker", -1)) > 0)


func _poll_kickoff_taken() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return (bool(last_snapshot.get("in_play", false)) and
		not bool(last_snapshot.get("in_set_piece", true)))


func _poll_client_result(result_path: String) -> bool:
	runtime.step_fixed(10)
	if not FileAccess.file_exists(result_path):
		return false
	var file := FileAccess.open(result_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	client_result = parsed
	return true


func _poll_file_exists(path: String) -> bool:
	runtime.step_fixed(10)
	return FileAccess.file_exists(path)


func _poll_unpaused() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return not bool(last_snapshot.get("paused", true))


func _write_marker(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _all_players_ready() -> bool:
	var players: Array = _lobby().get("players", [])
	if players.is_empty():
		return false
	for player in players:
		if not bool(player.get("ready", false)):
			return false
	return true


func _side_select_open() -> bool:
	runtime.step_fixed(10)
	return bool(_lobby().get("side_select", false))


func _poll_disconnected_side_select() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return bool(last_snapshot.get("paused", false)) and bool(_lobby().get("side_select", false))


func _run(port: int, pid: int, result_path: String, running_path: String,
		pause_path: String, host_vote_path: String, side_done_path: String,
		resume_done_path: String, rejoin_path: String) -> void:
	print("  hosting on 127.0.0.1:", port, ", client pid ", pid)

	if not _wait_until(_has_players.bind(2), 20000):
		_check(false, "the client never joined the lobby")
		return
	_check(true, "the client joined the lobby")

	# The client picks the away side on connect; don't confirm before it does.
	if not _wait_until(_client_on_side.bind(1), 10000):
		_check(false, "the client did not pick the away side")
		return
	_check(true, "the client picked the away side")

	var lobby := _lobby()
	var players: Array = lobby.get("players", [])
	_check(String(players[1].get("name", "")) == "Client", "the client name is mirrored")

	_check(runtime.net_action("set_ready", 0, 1, 0), "host SetReady is accepted")
	if not _wait_until(_phase_is.bind(1), 10000):
		_check(false, "the lobby did not advance to Teams")
		return
	_check(true, "both peers ready advanced the lobby to Teams")

	_check(runtime.net_action("set_selection", 0, 0, 0), "host country selection is accepted")
	_check(runtime.net_action("set_selection", 0, 2, 3), "host team selection is accepted")
	_check(runtime.net_action("set_team_ready", 0, 1, 0), "host team confirmation is accepted")

	if not _wait_until(_options_ready, 15000):
		_check(false, "the lobby did not reach Options with both teams: " + str(_lobby()))
		return
	_check(true, "both peers chose teams 3 and 8 and confirmed")

	_check(runtime.net_start(), "host net_start succeeds: " + String(runtime.get_last_error()))
	var snap: Dictionary = runtime.get_snapshot()
	_check(not snap.is_empty(), "the host net match has a snapshot")
	_check(bool(snap.get("net_is_host", false)), "the host snapshot is marked as host")
	_check(int(snap.get("net_connection", -1)) == 3, "the host snapshot is connected")

	# Each peer highlights only its own selected player; the host must not mark
	# the client's NetHIDDevice-owned player as controlled.
	var host_local := int(runtime.net_lobby().get("local_id", -1))
	var host_human := int(runtime.get_human_player_id())
	var host_owner := -1
	var host_human_ids: Array = runtime.get_human_player_ids()
	for entry in runtime.get_player_ids():
		if int(entry.get("owner_id", -1)) == host_local:
			host_owner = int(entry.get("id", -1))
			break
	_check(host_human > 0, "the host has a local human player")
	_check(host_human == host_owner, "the host human matches its own owner")
	_check(host_human_ids.size() == 1 and int(host_human_ids[0]) == host_human,
		"the host highlights only its own selected player")

	# The match clock only runs after the kickoff is taken. The host is the home
	# human; drive its taker so the client sees live remote time.
	if not _wait_until(_poll_kickoff_ready, 15000):
		_check(false, "the host net match never reached its kickoff")
		return
	var taker := int(last_snapshot.get("referee_taker", -1))
	runtime.select_player(taker)
	runtime.set_button(6, true)
	runtime.step_fixed(5)
	runtime.set_button(6, false)
	if not _wait_until(_poll_kickoff_taken, 15000):
		_check(false, "the host could not take the net kickoff")
		return
	_check(true, "the host took the net kickoff")

	# Wait until the client is actually rendering live snapshots before pausing.
	if not _wait_until(_poll_file_exists.bind(running_path), 15000):
		_check(false, "the client never reported a running match")
		return
	_check(true, "the client is rendering the live match")

	runtime.pause_match()
	if not _wait_until(_poll_file_exists.bind(pause_path), 15000):
		_check(false, "the client never saw the pause")
		return
	var paused_snap: Dictionary = runtime.get_snapshot()
	_check(bool(paused_snap.get("paused", false)), "the host net match is paused")
	_check(runtime.net_action("set_resume_ready", 0, 1, 0), "host resume vote is accepted")
	runtime.step_fixed(5)
	paused_snap = runtime.get_snapshot()
	_check(bool(paused_snap.get("paused", false)),
		"one resume vote alone does not unpause the match")
	_write_marker(host_vote_path, "voted")
	if not _wait_until(_poll_unpaused, 15000):
		_check(false, "the match did not resume after both votes")
		return
	_check(true, "both resume votes unpause the match")
	# Do not re-pause before the client has observed the resume, or the two
	# PauseState broadcasts collapse into one latched 'paused' on the thin peer.
	if not _wait_until(_poll_file_exists.bind(resume_done_path), 15000):
		_check(false, "the client did not observe the resume")
		return

	# In-match side selection (pause menu flow): the host opens it, both peers
	# ready, the host commits and both matches go live again. The client reports
	# completion through a marker so the next phase cannot race it.
	runtime.pause_match()
	_check(runtime.net_side_select_open(), "the host opens mirrored side selection")
	_check(runtime.net_action("set_ready", 0, 1, 0), "host side-select ready is accepted")
	if not _wait_until(_all_players_ready, 15000):
		_check(false, "the client did not ready for side selection")
		return
	_check(runtime.net_side_select_commit(), "the host commits the side selection")
	if not _wait_until(_poll_unpaused, 15000):
		_check(false, "the host did not resume after the side-select commit")
		return
	_check(true, "the side-select commit resumes the host")
	if not _wait_until(_poll_file_exists.bind(side_done_path), 20000):
		_check(false, "the client did not finish its side-selection phase")
		return
	_check(true, "the client saw the resumed match after the side-select commit")

	# Queue an away substitution for the restart the penalty forces: the thin
	# client must apply the notice and the new active roster from the snapshot
	# (it used to miss both, leaving an invisible player on the pitch).
	var client_peer := -1
	for player in _lobby().get("players", []):
		if not bool(player.get("is_host", false)):
			client_peer = int(player.get("id", -1))
	var client_owned: Array = []
	var goalkeeper_ids: Array = []
	for entry in runtime.get_player_ids():
		var entry_id := int(entry.get("id", -1))
		if int(entry.get("owner_id", -1)) == client_peer:
			client_owned.append(entry_id)
		if int(entry.get("team", -1)) == 1 and String(entry.get("role", "")) == "goalkeeper":
			goalkeeper_ids.append(entry_id)
	var away_squad: Dictionary = runtime.get_squad(1)
	var sub_out := -1
	var sub_in := -1
	for player in away_squad.get("players", []):
		var player_id := int(player.get("id", -1))
		if bool(player.get("active", false)):
			if sub_out < 0 and not client_owned.has(player_id) \
					and not goalkeeper_ids.has(player_id):
				sub_out = player_id
		elif sub_in < 0 and not bool(player.get("left_pitch", false)):
			sub_in = player_id
	_check(sub_out > 0 and sub_in > 0,
		"the away squad has an active player and a bench replacement")
	if sub_out > 0 and sub_in > 0:
		_check(runtime.queue_substitution(1, sub_out, sub_in),
			"the host queues an away substitution")

	# Force a penalty for the client's team to verify the thin client gets the
	# kicker role and the aim reticle (ownerId-based human id).
	var pre_penalty: Dictionary = runtime.get_snapshot()
	_check(bool(pre_penalty.get("in_play", false)) and
		not bool(pre_penalty.get("in_set_piece", true)),
		"the host is in open play before the forced penalty")
	runtime.debug_force_set_piece(6, 1)

	var got_result := _wait_until(_poll_client_result.bind(result_path), 30000, 50)

	if not got_result:
		snap = runtime.get_snapshot()
		_check(false, "the client never reported a result (host tick=%s, players=%s)" % [
			snap.get("tick"), int(_lobby().get("players", []).size())])
		return
	_check(true, "the client reported a result")

	_check(String(client_result.get("status", "")) == "ok",
		"client status is ok: " + str(client_result.get("failures", [])))
	_check(bool(client_result.get("accepted", false)), "the client was accepted")
	var client_ids: Array = client_result.get("team_ids", [])
	_check(client_ids.size() == 2 and int(client_ids[0]) == 3 and int(client_ids[1]) == 8,
		"the client received the same team ids: " + str(client_ids))
	_check(bool(client_result.get("net_active", false)), "the client has a net session")
	_check(bool(client_result.get("net_is_client", false)), "the client snapshot is a client")
	_check(not bool(client_result.get("net_is_host", true)), "the client is not the host")
	_check(int(client_result.get("match_time_ms", 0)) > 0,
		"the client received remote match time")
	_check(int(client_result.get("tick", 0)) > 0, "the client advanced its match")
	_check(String(client_result.get("team0_name", "")) != "" and
		String(client_result.get("team1_name", "")) != "",
		"the client built the match with both team names")
	_check(bool(client_result.get("pause_seen", false)), "the client saw the pause")
	_check(bool(client_result.get("resumed", false)), "the client saw the resumed match")
	var human_id := int(client_result.get("human_player_id", -1))
	var owner_id := int(client_result.get("owner_player_id", -2))
	_check(human_id > 0, "the client has a local human player")
	_check(human_id == owner_id, "the client human follows the snapshot owner")
	_check(bool(client_result.get("penalty_seen", false)), "the client saw the forced penalty")
	_check(int(client_result.get("penalty_role", 0)) == 1,
		"the client is the penalty kicker")
	_check(float(client_result.get("penalty_aim_length", 0.0)) > 0.01,
		"the client has a penalty aim point")
	_check(bool(client_result.get("penalty_local_taker", false)),
		"the client penalty taker is local")
	_check(bool(client_result.get("substitution_roster_changed", false)),
		"the client applied the substitution roster")
	_check(bool(client_result.get("substitution_roster_synced", false)),
		"the client roster synced the substituted-in player")
	_check(int(runtime.get_substitution_notice_counter()) > 0,
		"the host recorded the applied substitution")
	_check(int(runtime.get_snapshot().get("substitutions1", 0)) > 0,
		"the away team has one applied substitution")

	snap = runtime.get_snapshot()
	_check(int(client_result.get("score0", -1)) == int(snap.get("score0", -2)) and
		int(client_result.get("score1", -1)) == int(snap.get("score1", -2)),
		"host and client report the same score (%s:%s)" % [
			snap.get("score0"), snap.get("score1")])
	print("  host: tick=", snap.get("tick"), " time=", snap.get("match_time_ms"),
		" score=", snap.get("score0"), ":", snap.get("score1"))
	print("  client: tick=", client_result.get("tick"), " time=", client_result.get("match_time_ms"),
		" score=", client_result.get("score0"), ":", client_result.get("score1"))

	# Disconnect: the client process is gone. The host must stay alive, pause
	# and open the mirrored side selection; the freed side goes to the AI.
	if not _wait_until(_poll_disconnected_side_select, 25000):
		_check(false, "the host did not pause into side selection after the disconnect")
		return
	_check(true, "the host pauses and opens side selection after the client left")
	_check(_lobby().get("players", []).size() >= 1, "the host survives the disconnect")
	_check(runtime.net_action("set_ready", 0, 1, 0), "host ready after the disconnect")
	if not _wait_until(_all_players_ready, 10000):
		_check(false, "the host could not ready alone after the disconnect")
		return
	_check(runtime.net_side_select_commit(), "the host commits after the disconnect")
	if not _wait_until(_poll_unpaused, 15000):
		_check(false, "the host did not resume after the disconnect commit")
		return
	_check(true, "the host resumes with the freed side on AI")

	# Rejoin: a fresh client builds the running match from MatchSetup, joins the
	# mirrored side selection and continues after the host commit.
	var rejoin_args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", CLIENT_SCRIPT,
		"--",
		"127.0.0.1", str(port), rejoin_path, "-", "-", "-", "-", "-", "rejoin",
	])
	var rejoin_pid := OS.create_process(OS.get_executable_path(), rejoin_args)
	_check(rejoin_pid > 0, "the rejoin client process starts")
	if rejoin_pid <= 0:
		return
	if not _wait_until(_has_players.bind(2), 20000):
		_check(false, "the rejoin client never joined")
		OS.kill(rejoin_pid)
		return
	_check(true, "the rejoin client joined the running match")
	if not _wait_until(_side_select_open, 15000):
		_check(false, "the rejoin never opened side selection")
		OS.kill(rejoin_pid)
		return
	_check(runtime.net_action("set_ready", 0, 1, 0), "host ready after the rejoin")
	if not _wait_until(_all_players_ready, 20000):
		_check(false, "the rejoin client never readied")
		OS.kill(rejoin_pid)
		return
	_check(runtime.net_side_select_commit(), "the host commits the rejoin side selection")
	if not _wait_until(_poll_unpaused, 15000):
		_check(false, "the host did not resume after the rejoin commit")
		OS.kill(rejoin_pid)
		return
	if not _wait_until(_poll_client_result.bind(rejoin_path), 30000, 50):
		_check(false, "the rejoin client never reported a result")
		OS.kill(rejoin_pid)
		return
	if OS.is_process_running(rejoin_pid):
		OS.kill(rejoin_pid)
	_check(String(client_result.get("status", "")) == "ok",
		"rejoin client status is ok: " + str(client_result.get("failures", [])))
	_check(bool(client_result.get("rejoin", false)), "the rejoin client reports rejoin mode")
	_check(bool(client_result.get("resumed", false)), "the rejoin client resumed")
	_check(bool(client_result.get("side_select_seen", false)),
		"the rejoin client saw the side selection")
	snap = runtime.get_snapshot()
	_check(int(client_result.get("score0", -1)) == int(snap.get("score0", -2)) and
		int(client_result.get("score1", -1)) == int(snap.get("score1", -2)),
		"the rejoined client sees the same score")
	_check(absi(int(client_result.get("match_time_ms", -100000)) -
		int(snap.get("match_time_ms", 0))) <= 2000,
		"the rejoined client sees the same match time (%s vs %s)" % [
			client_result.get("match_time_ms"), snap.get("match_time_ms")])
	print("  rejoin: tick=", client_result.get("tick"),
		" time=", client_result.get("match_time_ms"),
		" score=", client_result.get("score0"), ":", client_result.get("score1"))
