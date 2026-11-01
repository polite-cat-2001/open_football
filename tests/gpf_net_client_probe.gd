extends SceneTree
# LAN two-process probe: run as a child process by check_gpf_net_two_process.gd.
# Joins the host, plays through the lobby, receives MatchSetup, builds the same
# match from the ids and reports the remote-presentation snapshot as JSON.
#
# Usage (the host test builds this command):
#   godot --headless --path . -s res://tests/gpf_net_client_probe.gd -- \
#       ADDRESS PORT RESULT_PATH [RUNNING_MARKER PAUSE_MARKER HOST_VOTE_MARKER]

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []
var runtime: Node
var probe_result: Dictionary = {}
var match_setup: Dictionary = {}
var last_snapshot: Dictionary = {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		print("PROBE FAIL: expected ADDRESS PORT RESULT_PATH")
		quit(1)
		return

	probe_result = {
		"status": "fail",
		"stage": "init",
		"address": args[0],
		"port": int(args[1]),
	}
	var running_marker := args[3] if args.size() > 3 else ""
	var pause_marker := args[4] if args.size() > 4 else ""
	var host_vote_marker := args[5] if args.size() > 5 else ""
	var ok := _run(args[0], int(args[1]), running_marker, pause_marker, host_vote_marker)
	probe_result["status"] = "ok" if ok and failures.is_empty() else "fail"
	probe_result["failures"] = failures
	_write_result(args[2], probe_result)
	print("PROBE: ", probe_result["status"], " stage=", probe_result.get("stage", ""))
	for failure in failures:
		print("PROBE FAIL: ", failure)
	quit(0 if probe_result["status"] == "ok" else 1)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("PROBE FAIL: ", message)
	return condition


func _write_result(path: String, result: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("PROBE FAIL: cannot write result to ", path)
		return
	file.store_string(JSON.stringify(result))
	file.close()


func _wait_until(predicate: Callable, timeout_ms: int, poll_ms: int = 50) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		OS.delay_msec(poll_ms)
	return false


func _lobby_state() -> Dictionary:
	return Dictionary(runtime.net_lobby().get("lobby", {}))


func _poll_connected() -> bool:
	var info: Dictionary = runtime.net_lobby()
	probe_result["local_id"] = info.get("local_id", -1)
	probe_result["connection"] = info.get("connection", -1)
	probe_result["reject_text"] = info.get("reject_text", "")
	return int(info.get("connection", 0)) == 3


func _poll_teams_phase() -> bool:
	var lobby := _lobby_state()
	probe_result["phase_after_ready"] = lobby.get("phase", -1)
	return int(lobby.get("phase", -1)) == 1


func _poll_setup() -> bool:
	match_setup = runtime.net_take_match_setup()
	return not match_setup.is_empty()


func _poll_remote() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return int(last_snapshot.get("match_time_ms", 0)) > 0


func _poll_paused() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return bool(last_snapshot.get("paused", false))


func _poll_resumed() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return not bool(last_snapshot.get("paused", true))


func _poll_penalty() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return int(last_snapshot.get("presentation_type", 0)) == 6


func _file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


func _write_marker(path: String, text: String) -> void:
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _run(address: String, port: int, running_marker: String = "",
		pause_marker: String = "", host_vote_marker: String = "") -> bool:
	probe_result["stage"] = "runtime"
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8)
	if package.is_empty():
		return _check(false, "client could not build the bootstrap package")

	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		return _check(false, "GpfRuntimeNode is not registered")
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	if not runtime.set_match_package(package):
		return _check(false, "client bootstrap package rejected")
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		return _check(false, "client runtime did not start: " + String(runtime.get_last_error()))
	runtime.stop_match()

	probe_result["stage"] = "join"
	if not _check(runtime.net_join(address, port, "Client"), "net_join failed: " + String(runtime.get_last_error())):
		return false

	if not _wait_until(_poll_connected, 15000):
		probe_result["stage"] = "connect"
		return _check(false, "client did not connect (connection=%s, reject=%s)" % [
			probe_result.get("connection"), probe_result.get("reject_text")])

	var info: Dictionary = runtime.net_lobby()
	probe_result["accepted"] = info.get("accepted", false)
	if not _check(bool(info.get("accepted", false)), "the host rejected the client: " + String(info.get("reject_text", ""))):
		probe_result["stage"] = "rejected"
		return false

	# Pick the away side and vote ready; the host votes from its own process.
	probe_result["stage"] = "sides"
	_check(runtime.net_action("set_side", 1, 1, 0), "client SetSide failed")
	_check(runtime.net_action("set_ready", 0, 1, 0), "client SetReady failed")

	if not _wait_until(_poll_teams_phase, 10000):
		probe_result["stage"] = "teams-phase"
		return _check(false, "the lobby did not reach the Teams phase")

	probe_result["stage"] = "team-select"
	_check(runtime.net_action("set_selection", 1, 0, 0), "client country selection failed")
	_check(runtime.net_action("set_selection", 1, 2, 8), "client team selection failed")
	_check(runtime.net_action("set_team_ready", 1, 1, 0), "client team confirmation failed")

	probe_result["stage"] = "match-setup"
	if not _wait_until(_poll_setup, 20000):
		return _check(false, "client did not receive NetMatchSetup")
	probe_result["team_ids"] = match_setup.get("team_ids", [])
	var ids: Array = match_setup.get("team_ids", [])
	if not _check(ids.size() == 2 and int(ids[0]) == 3 and int(ids[1]) == 8,
			"unexpected MatchSetup team ids: " + str(ids)):
		return false

	probe_result["stage"] = "build-match"
	var match_package := MatchPackageFixture.build(DATA_ROOT, int(ids[0]), int(ids[1]))
	if not _check(not match_package.is_empty(), "client could not build the match package"):
		return false
	if not _check(runtime.set_match_package(match_package), "client match package rejected"):
		return false
	if not _check(runtime.start_match(), "client could not start the remote match: " + String(runtime.get_last_error())):
		return false

	probe_result["stage"] = "remote-match"
	var saw_remote := _wait_until(_poll_remote, 20000)
	var snap := last_snapshot
	probe_result["net_active"] = snap.get("net_active", false)
	probe_result["net_is_client"] = snap.get("net_is_client", false)
	probe_result["net_is_host"] = snap.get("net_is_host", true)
	probe_result["net_connection"] = snap.get("net_connection", -1)
	probe_result["tick"] = snap.get("tick", -1)
	probe_result["match_time_ms"] = snap.get("match_time_ms", -1)
	probe_result["score0"] = snap.get("score0", -1)
	probe_result["score1"] = snap.get("score1", -1)
	probe_result["team0_name"] = snap.get("team0_name", "")
	probe_result["team1_name"] = snap.get("team1_name", "")

	_check(saw_remote, "client did not receive a remote snapshot")
	_check(bool(snap.get("net_active", false)), "client snapshot has no net session")
	_check(bool(snap.get("net_is_client", false)), "client snapshot is not marked as client")
	_check(not bool(snap.get("net_is_host", true)), "client snapshot is marked as host")
	_check(int(snap.get("tick", 0)) > 0, "client match did not advance")
	_check(String(snap.get("team0_name", "")) != "" and String(snap.get("team1_name", "")) != "",
		"client match has no team names")

	# The client must follow the host's selected player (snapshot ownerId), not
	# the first player on its side.
	var local_id := int(probe_result.get("local_id", -1))
	var human_id := int(runtime.get_human_player_id())
	var owner_id := -1
	var roster_ids: Array = runtime.get_player_ids()
	for entry in roster_ids:
		if int(entry.get("owner_id", -1)) == local_id:
			owner_id = int(entry.get("id", -1))
			break
	probe_result["human_player_id"] = human_id
	probe_result["owner_player_id"] = owner_id
	var human_ids: Array = runtime.get_human_player_ids()
	_check(human_id > 0, "client has a local human player")
	_check(human_id == owner_id, "client human player matches the snapshot owner")
	_check(human_ids.size() == 1 and int(human_ids[0]) == human_id,
		"client highlights only its own selected player")

	if not pause_marker.is_empty():
		probe_result["stage"] = "pause"
		_write_marker(running_marker, "running")
		var saw_pause := _wait_until(_poll_paused, 15000)
		probe_result["pause_seen"] = saw_pause
		if not _check(saw_pause, "client did not see the host pause"):
			return false
		_write_marker(pause_marker, "paused")
		# Wait for the host vote: one vote alone must not resume the match.
		if not _check(_wait_until(_file_exists.bind(host_vote_marker), 15000),
				"client did not see the host resume vote"):
			return false
		if not _check(runtime.net_action("set_resume_ready", 0, 1, 0),
				"client resume vote failed"):
			return false
		var resumed := _wait_until(_poll_resumed, 15000)
		probe_result["resumed"] = resumed
		_check(resumed, "client did not resume after both votes")

		# The host forces a penalty for this client's team; the client must get
		# the kicker role and the yellow aim reticle from the same snapshot data.
		probe_result["stage"] = "penalty"
		var penalty_seen := _wait_until(_poll_penalty, 20000)
		var penalty_snap := last_snapshot
		var aim: Vector3 = penalty_snap.get("set_piece_aim_point", Vector3.ZERO)
		probe_result["penalty_seen"] = penalty_seen
		probe_result["penalty_role"] = penalty_snap.get("set_piece_role", -1)
		probe_result["penalty_local_taker"] = penalty_snap.get("set_piece_local_taker", false)
		probe_result["penalty_hud_player"] = penalty_snap.get("set_piece_hud_player", -1)
		probe_result["penalty_human_id"] = int(runtime.get_human_player_id())
		probe_result["penalty_aim_length"] = aim.length()
		_check(penalty_seen, "client did not see the forced penalty")
		_check(int(penalty_snap.get("set_piece_role", 0)) == 1,
			"client is not the penalty kicker")
		_check(aim.length() > 0.01, "client penalty aim point is empty")
		_check(bool(penalty_snap.get("set_piece_local_taker", false)),
			"client penalty taker is not local")
	return failures.is_empty()
