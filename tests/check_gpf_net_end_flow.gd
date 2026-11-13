extends SceneTree
# LAN end-of-match check: this process hosts, a child process joins, runs the real
# match scene as the thin client, and the host finishes the match from outside a
# simulated tick (the 90:00 DRAW). Asserts the client's overlay opens promptly вЂ”
# a paused host freezes its clock, and the client used to hold stale snapshots.
#
#   godot --headless --path . -s res://tests/check_gpf_net_end_flow.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const CLIENT_SCRIPT := "res://tests/gpf_net_slice_probe.gd"
const PORT_FIRST := 27851
const PORT_TRIES := 20
# The client polls every frame, but this harness occasionally stalls the stream
# for a few seconds (two processes, wall-clock marker): the bound still catches
# the real regression, where a paused client never applied snapshots and the
# overlay only opened when the match resumed (20 s timeout).
const MAX_LATENCY_MS := 6000

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

	var result_path := ProjectSettings.globalize_path("user://gpf_net_slice_result.json")
	var live_path := ProjectSettings.globalize_path("user://gpf_net_slice_live.json")
	var ready_path := ProjectSettings.globalize_path("user://gpf_net_slice_ready.json")
	var over_path := ProjectSettings.globalize_path("user://gpf_net_slice_over.json")
	var client_log_path := ProjectSettings.globalize_path("user://gpf_net_slice_client.log")
	for path in [result_path, live_path, ready_path, over_path, client_log_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	var args := PackedStringArray([
		"--headless",
		"--log-file", client_log_path,
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", CLIENT_SCRIPT,
		"--",
		"127.0.0.1", str(port), result_path, live_path, ready_path, over_path,
	])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		print("CHECK FAIL: could not start the client process")
		runtime.net_leave()
		quit(1)
		return

	_run(port, result_path, live_path, ready_path, over_path, client_log_path)

	if runtime.is_net_active():
		runtime.net_leave()
	if OS.is_process_running(pid):
		OS.kill(pid)
	for path in [result_path, live_path, ready_path, over_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("== check_gpf_net_end_flow: ", "PASS" if failures.is_empty() else "FAIL", " ===")
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
	return (_lobby().get("players", []) as Array).size() >= count


func _phase_is(phase: int) -> bool:
	return int(_lobby().get("phase", -1)) == phase


func _options_ready() -> bool:
	var state := _lobby()
	return int(state.get("phase", -1)) == 2 \
		and state.get("team_ids", []) == [3, 8] \
		and state.get("team_ready", []) == [true, true]


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
	return bool(last_snapshot.get("in_play", false)) \
		and bool(last_snapshot.get("in_set_piece", false)) \
		and int(last_snapshot.get("referee_taker", -1)) > 0


func _poll_kickoff_taken() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return bool(last_snapshot.get("in_play", false)) \
		and not bool(last_snapshot.get("in_set_piece", true))


func _poll_client_result(path: String) -> bool:
	# Small step + a real sleep: the client is a separate process and needs the
	# CPU. A 10-tick burst per poll starved it and made this check flaky.
	runtime.step_fixed(1)
	OS.delay_msec(10)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if String(parsed.get("status", "")) == "running":
		return false
	client_result = parsed
	return true


func _write_marker(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _run(port: int, result_path: String, live_path: String, ready_path: String,
		over_path: String, client_log_path: String) -> void:
	print("  hosting on 127.0.0.1:", port)
	if not _wait_until(_has_players.bind(2), 20000):
		_check(false, "the client never joined the lobby")
		return
	_check(true, "the client joined the lobby")
	_check(runtime.net_action("set_ready", 0, 1, 0), "host SetReady is accepted")
	if not _wait_until(_phase_is.bind(1), 10000):
		_check(false, "the lobby did not reach Teams")
		return

	_check(runtime.net_action("set_selection", 0, 0, 0), "host country selection is accepted")
	_check(runtime.net_action("set_selection", 0, 2, 3), "host team selection is accepted")
	_check(runtime.net_action("set_team_ready", 0, 1, 0), "host team confirmation is accepted")
	if not _wait_until(_options_ready, 15000):
		_check(false, "the lobby did not reach its options phase: " + str(_lobby()))
		return

	_check(runtime.net_start(), "host net_start succeeds: " + String(runtime.get_last_error()))
	if not _wait_until(_poll_kickoff_ready, 45000):
		var failed_snap: Dictionary = runtime.get_snapshot()
		_check(false, "the host net match never reached its kickoff (in_play=%s set_piece=%s taker=%s phase=%s paused=%s) client=%s" % [
			failed_snap.get("in_play"), failed_snap.get("in_set_piece"), failed_snap.get("referee_taker"),
			failed_snap.get("match_phase"), failed_snap.get("paused"), _read_text(client_log_path)])
		return
	runtime.select_player(int(last_snapshot.get("referee_taker", -1)))
	runtime.set_button(6, true)
	runtime.step_fixed(5)
	runtime.set_button(6, false)
	if not _wait_until(_poll_kickoff_taken, 15000):
		_check(false, "the host could not take the net kickoff")
		return
	_check(true, "the host runs a live net match")

	# The client mounts the real match scene once it sees this marker.
	_write_marker(live_path, "live")
	if not _wait_until(_poll_file_exists.bind(ready_path), 30000):
		_check(false, "the client never mounted its match scene")
		return
	_check(true, "the client runs the real match scene")

	# End the match from outside a simulated tick (the 90:00 DRAW path): a paused
	# host freezes its clock, so the client used to hold stale snapshots and open
	# this overlay seconds later.
	# Diagnostic: a plain pause first (the 90:00 break pauses before the choice).
	runtime.pause_match()
	for i in 20:
		runtime.step_fixed(5)
		OS.delay_msec(10)
	var paused_snap: Dictionary = runtime.get_snapshot()
	print("  host paused: paused=", paused_snap.get("paused"), " game_over=", paused_snap.get("game_over"))
	_write_marker(over_path, str(Time.get_unix_time_from_system() * 1000.0))
	runtime.step_fixed(1)
	var before_iterations := int(runtime.debug_get_iterations())
	runtime.debug_force_game_over()
	# Sent while paused: proves discrete snapshot state still reaches the peer.
	runtime.debug_spam_message("paused-probe", 9000)
	runtime.step_fixed(20)
	var host_snap: Dictionary = runtime.get_snapshot()
	print("  host after game over: game_over=", host_snap.get("game_over"),
		" paused=", host_snap.get("paused"),
		" iterations ", before_iterations, " -> ", int(runtime.debug_get_iterations()))

	if not _wait_until(_poll_client_result.bind(result_path), 30000, 20):
		_check(false, "the client never reported its overlay: " + str(client_result))
		return
	_check(true, "the client reported its end-of-match overlay")
	_check(bool(client_result.get("game_over", false)),
		"the client snapshot carries the relayed game over")
	_check(int(client_result.get("spam", 0)) > 0,
		"a snapshot sent while paused reaches the client")
	_check(bool(client_result.get("overlay_open", false)),
		"the client opened the end-of-match screen: " + str(client_result.get("failures", [])))
	var latency := int(client_result.get("latency_ms", -1))
	_check(latency >= 0 and latency <= MAX_LATENCY_MS,
		"the client overlay opens promptly (latency %s ms)" % latency)
	print("  client latency: ", latency, " ms")
	print("  client samples: ", client_result.get("samples", []))


func _poll_file_exists(path: String) -> bool:
	runtime.step_fixed(10)
	return FileAccess.file_exists(path)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
