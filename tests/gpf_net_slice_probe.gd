extends SceneTree
# LAN client probe that runs the REAL match scene (gpf_slice) as the thin client,
# so the end-of-match overlay can be observed without a human at the keyboard.
# Started as a child process by check_gpf_net_end_flow.gd.
#
#   godot --headless --path . -s res://tests/gpf_net_slice_probe.gd -- \
#       ADDRESS PORT RESULT_PATH LIVE_MARKER READY_MARKER OVER_MARKER
#
# The waits after the scene is mounted yield process frames (the scene only
# progresses in its own _process), so this probe is a coroutine from that point.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []
var runtime: Node
var slice: Node
var probe_result: Dictionary = {}
var match_setup: Dictionary = {}
var last_snapshot: Dictionary = {}
var result_path := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		print("PROBE FAIL: expected ADDRESS PORT RESULT LIVE READY OVER")
		quit(1)
		return
	probe_result = {"status": "fail", "stage": "init"}
	result_path = args[2]
	_run(args[0], int(args[1]), args[3], args[4], args[5])


# The host test kills this process when it gives up, which drops buffered stdout:
# flush the current stage to the result file so a hang is visible from outside.
func _stage(name: String) -> void:
	probe_result["stage"] = name
	# "running" keeps the host from reading a half-written progress flush as the
	# final result.
	probe_result["status"] = "running"
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(probe_result))
		file.close()


func _finish() -> void:
	probe_result["status"] = "ok" if failures.is_empty() else "fail"
	probe_result["failures"] = failures
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(probe_result))
		file.close()
	print("PROBE: ", probe_result["status"], " stage=", probe_result.get("stage", ""))
	for failure in failures:
		print("PROBE FAIL: ", failure)
	quit(0 if probe_result["status"] == "ok" else 1)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("PROBE FAIL: ", message)
	return condition


func _wait_until(predicate: Callable, timeout_ms: int, poll_ms: int = 20) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		OS.delay_msec(poll_ms)
	return false


# Frame-yielding wait: the mounted scene only advances inside its own _process.
func _wait_frames(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


func _now_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0


func _read_ms(path: String) -> float:
	if not FileAccess.file_exists(path):
		return 0.0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0.0
	var text := file.get_as_text()
	file.close()
	return float(text.strip_edges())


func _write_marker(path: String, text: String) -> void:
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _lobby_state() -> Dictionary:
	return Dictionary(runtime.net_lobby().get("lobby", {}))


func _poll_connected() -> bool:
	return int(runtime.net_lobby().get("connection", 0)) == 3


func _poll_teams_phase() -> bool:
	return int(_lobby_state().get("phase", -1)) == 1


func _poll_setup() -> bool:
	match_setup = runtime.net_take_match_setup()
	return not match_setup.is_empty()


func _poll_remote() -> bool:
	last_snapshot = runtime.get_snapshot()
	return int(last_snapshot.get("match_time_ms", 0)) > 0


func _poll_overlay() -> bool:
	last_snapshot = runtime.get_snapshot()
	if slice == null:
		return false
	var over = slice.get("match_over")
	return over != null and bool(over.is_open())


func _run(address: String, port: int, live_marker: String, ready_marker: String,
		over_marker: String) -> void:
	_stage("runtime")
	var bootstrap := MatchPackageFixture.build(DATA_ROOT, 3, 8)
	if not _check(not bootstrap.is_empty(), "client could not build the bootstrap package"):
		_finish()
		return

	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if not _check(runtime != null, "GpfRuntimeNode is not registered"):
		_finish()
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	if not _check(runtime.set_match_package(bootstrap), "client bootstrap package rejected"):
		_finish()
		return
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not _check(runtime.is_runtime_ready(),
			"client runtime did not start: " + String(runtime.get_last_error())):
		_finish()
		return
	runtime.stop_match()

	_stage("join")
	if not _check(runtime.net_join(address, port, "Client"),
			"net_join failed: " + String(runtime.get_last_error())):
		_finish()
		return
	if not _check(_wait_until(_poll_connected, 15000), "client did not connect"):
		_finish()
		return

	_stage("lobby")
	_check(runtime.net_action("set_side", 1, 1, 0), "client SetSide failed")
	_check(runtime.net_action("set_ready", 0, 1, 0), "client SetReady failed")
	if not _check(_wait_until(_poll_teams_phase, 15000), "the lobby did not reach the Teams phase"):
		_finish()
		return
	_check(runtime.net_action("set_selection", 1, 0, 0), "client country selection failed")
	_check(runtime.net_action("set_selection", 1, 2, 8), "client team selection failed")
	_check(runtime.net_action("set_team_ready", 1, 1, 0), "client team confirmation failed")

	_stage("match-setup")
	if not _check(_wait_until(_poll_setup, 30000), "client did not receive NetMatchSetup"):
		_finish()
		return
	var ids: Array = match_setup.get("team_ids", [])
	if not _check(ids.size() == 2 and int(ids[0]) == 3 and int(ids[1]) == 8,
			"unexpected MatchSetup team ids: " + str(ids)):
		_finish()
		return

	_stage("build-match")
	var package := MatchPackageFixture.build(DATA_ROOT, int(ids[0]), int(ids[1]))
	if not _check(not package.is_empty(), "client could not build the match package"):
		_finish()
		return
	if not _check(runtime.set_match_package(package), "client match package rejected"):
		_finish()
		return
	if not _check(runtime.start_match(),
			"client could not start the remote match: " + String(runtime.get_last_error())):
		_finish()
		return

	# Mount the real match scene: it takes the running runtime from the group and
	# attaches its presentation to the live remote match instead of restarting it.
	_stage("slice")
	ShellState.set_match_package(package)
	if not runtime.is_in_group("gpf_runtime"):
		runtime.add_to_group("gpf_runtime")
	slice = (load("res://scenes/gpf_slice.tscn") as PackedScene).instantiate()
	get_root().add_child(slice)
	for i in 10:
		await process_frame
	if not _check(bool(slice.get("started")), "the client match scene did not start"):
		_finish()
		return

	_stage("live")
	if not _check(await _wait_frames(_file_exists.bind(live_marker), 30000),
			"client did not see the host live marker"):
		_finish()
		return
	if not _check(await _wait_frames(_poll_remote, 15000), "client received no remote snapshot"):
		_finish()
		return
	probe_result["net_is_client"] = bool(last_snapshot.get("net_is_client", false))
	_check(bool(probe_result["net_is_client"]), "client snapshot is not marked as client")
	_check(not bool(last_snapshot.get("game_over", false)), "the match was already over")
	_write_marker(ready_marker, "ready")

	_stage("game-over")
	# Live-play sanity: the client's match time must move before the host pauses,
	# or no snapshot ever reaches this peer (and the end-of-match state cannot).
	var time_before := int(runtime.get_snapshot().get("match_time_ms", 0))
	for i in 60:
		await process_frame
	var time_after := int(runtime.get_snapshot().get("match_time_ms", 0))
	probe_result["live_time_before"] = time_before
	probe_result["live_time_after"] = time_after
	_check(time_after > time_before,
		"the client is not receiving live snapshots (%s -> %s ms)" % [time_before, time_after])
	if not _check(await _wait_frames(_file_exists.bind(over_marker), 30000),
			"client did not see the host game-over marker"):
		_finish()
		return
	var started_ms := _read_ms(over_marker)
	var samples: Array = []
	var opened := false
	var next_sample := 0
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		last_snapshot = runtime.get_snapshot()
		if slice != null:
			var over = slice.get("match_over")
			opened = over != null and bool(over.is_open())
		if opened:
			break
		if Time.get_ticks_msec() >= next_sample:
			next_sample = Time.get_ticks_msec() + 1000
			samples.append({
				"ms": int(_now_ms() - started_ms),
				"game_over": bool(last_snapshot.get("game_over", false)),
				"paused": bool(last_snapshot.get("paused", false)),
				"spam": int(last_snapshot.get("spam_message_counter", -1)),
				"time": int(last_snapshot.get("match_time_ms", -1)),
			})
		await process_frame
	probe_result["samples"] = samples
	probe_result["overlay_open"] = opened
	probe_result["latency_ms"] = -1
	if opened and started_ms > 0.0:
		probe_result["latency_ms"] = int(_now_ms() - started_ms)
	var over = slice.get("match_over") if slice != null else null
	probe_result["is_choice"] = over != null and bool(over.is_choice())
	probe_result["game_over"] = bool(last_snapshot.get("game_over", false))
	probe_result["paused"] = bool(last_snapshot.get("paused", false))
	probe_result["spam"] = int(last_snapshot.get("spam_message_counter", 0))
	_check(opened, "the client never opened the end-of-match screen")
	_finish()
