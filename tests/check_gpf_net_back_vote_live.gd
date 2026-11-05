extends SceneTree
# Live two-process UI check for the LAN Back chain: the host runs the real Host
# screen, the child runs the real Join screen. They ready into Teams, the host
# asks to go back to Sides (both sides confirm), then asks to leave the session
# (both sides confirm) and both return to the network menu.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_net_back_vote_live.gd

const NETWORK_HOST := "res://scenes/network_host.tscn"
const PROBE := "res://tests/gpf_net_join_ui_probe.gd"
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
const TEST_CONFIG := "user://network_back_vote_live.cfg"
const PORT_FIRST := 28651
const PORT_TRIES := 20

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)
	return condition


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_until(predicate: Callable, timeout_ms: int, poll_ms: int = 50) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		OS.delay_msec(poll_ms)
		await process_frame
	return false


func _scene_name() -> String:
	return current_scene.name if current_scene != null else ""


func _lobby() -> Dictionary:
	return Dictionary(NetShell.lobby(self).get("lobby", {}))


func _phase_is(phase: int) -> bool:
	return int(_lobby().get("phase", -1)) == phase


func _run() -> void:
	NetworkSettings.config_path = TEST_CONFIG
	NetworkSettings.reset()
	change_scene_to_file(NETWORK_HOST)
	await _frames(6)
	var host_screen := current_scene
	if not _check(host_screen != null and host_screen.name == "NetworkHost",
			"the host screen opens"):
		_finish()
		return
	var port_row: UiFormRow = host_screen.get("port_row")
	var name_row: UiFormRow = host_screen.get("name_row")
	var bound_port := 0
	for offset in PORT_TRIES:
		bound_port = PORT_FIRST + offset
		port_row.set_value(str(bound_port))
		name_row.set_value("Vote Host")
		host_screen.call("_open_lobby")
		await _frames(3)
		if _scene_name() == "NetworkSides":
			break
	if not _check(_scene_name() == "NetworkSides", "the host opens the side screen"):
		_finish()
		return
	runtime = NetShell.active_runtime(self)
	if not _check(runtime != null and bool(runtime.is_net_host()), "the host runtime is running"):
		_finish()
		return

	var result_path := ProjectSettings.globalize_path("user://gpf_join_ui_result.json")
	var ready_path := ProjectSettings.globalize_path("user://gpf_join_ui_ready.json")
	for path in [result_path, ready_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", PROBE,
		"--",
		"127.0.0.1", str(bound_port), result_path, ready_path,
	])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if not _check(pid > 0, "the join UI process starts"):
		_finish()
		return

	if not _check(await _wait_until(func(): return FileAccess.file_exists(ready_path), 30000),
			"the join UI reached the side screen"):
		_cleanup(pid, result_path, ready_path)
		_finish()
		return
	_check(NetShell.action(self, "set_ready", 0, 1, 0), "the host readies")
	if not _check(await _wait_until(func(): return _phase_is(1) and _scene_name() == "NetworkLobby",
			20000), "both peers reach the team screen"):
		_cleanup(pid, result_path, ready_path)
		_finish()
		return

	var lobby_screen := current_scene
	var lobby_vote: NetworkBackVote = lobby_screen.get("back_vote")
	if not _check(lobby_vote != null, "the team screen mounts the Back vote"):
		_cleanup(pid, result_path, ready_path)
		_finish()
		return
	lobby_vote.request()
	if not _check(await _wait_until(func(): return _phase_is(0) and _scene_name() == "NetworkSides",
			20000), "the BackToSides vote returns both peers to the side screen"):
		_cleanup(pid, result_path, ready_path)
		_finish()
		return

	var sides_screen := current_scene
	var sides_vote: NetworkBackVote = sides_screen.get("back_vote")
	if not _check(sides_vote != null, "the side screen mounts the Back vote"):
		_cleanup(pid, result_path, ready_path)
		_finish()
		return
	sides_vote.request()
	if not _check(await _wait_until(func(): return _scene_name() == "NetworkMenu", 20000),
			"the LeaveSession vote returns the host to the network menu"):
		_cleanup(pid, result_path, ready_path)
		_finish()
		return

	if not _check(await _wait_until(func(): return FileAccess.file_exists(result_path), 20000),
			"the join UI reports its result"):
		_cleanup(pid, result_path, ready_path)
		_finish()
		return
	var child := _read_result(result_path)
	_check(String(child.get("status", "")) == "ok",
		"the join UI accepts both dialogs: " + str(child.get("failures", [])))
	var actions: Array = child.get("dialog_actions", [])
	_check(actions.size() == 2 and int(actions[0]) == NetworkBackVote.VOTE_BACK_TO_SIDES
		and int(actions[1]) == NetworkBackVote.VOTE_LEAVE_SESSION,
		"the join UI saw BackToSides then LeaveSession")
	_check(bool(child.get("left", false)), "the join UI leaves to the network menu")
	_cleanup(pid, result_path, ready_path)
	_finish()


func _read_result(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _cleanup(pid: int, result_path: String, ready_path: String) -> void:
	if NetShell.is_active(self):
		NetShell.leave(self)
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	for path in [result_path, ready_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _finish() -> void:
	NetworkSettings.reset()
	NetworkSettings.config_path = NetworkSettings.CONFIG_PATH
	if failures.is_empty():
		print("== check_gpf_net_back_vote_live: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_gpf_net_back_vote_live: FAIL ==")
	quit(0 if failures.is_empty() else 1)
