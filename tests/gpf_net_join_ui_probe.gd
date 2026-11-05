extends SceneTree
# Child process for the live LAN UI check: runs the real design-system Join
# screen, enters the lobby, readies, then accepts the host's BackToSides and
# LeaveSession dialog requests. Reports the result as JSON.
#
# Args: ADDRESS PORT RESULT_PATH READY_MARKER
# Run:  godot --headless --path . -s res://tests/gpf_net_join_ui_probe.gd -- ...

const NET_SHELL := preload("res://scripts/net/net_shell.gd")

var failures: Array[String] = []
var result: Dictionary = {}
var dialog_actions: Array[int] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		print("JOIN UI PROBE: expected ADDRESS PORT RESULT_PATH READY_MARKER")
		quit(1)
		return
	result = {
		"status": "fail",
		"stage": "init",
		"address": args[0],
		"port": int(args[1]),
		"dialog_actions": [],
	}
	call_deferred("_run", args[0], int(args[1]), args[2], args[3])


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("JOIN UI PROBE FAIL: ", message)
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


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("JOIN UI PROBE: cannot write ", path)
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _scene_name() -> String:
	return current_scene.name if current_scene != null else ""


func _run(address: String, port: int, result_path: String, ready_marker: String) -> void:
	NetworkSettings.config_path = "user://gpf_join_ui_probe.cfg"
	change_scene_to_file("res://scenes/network_join.tscn")
	await _frames(8)
	var join := current_scene
	if not _check(join != null and join.name == "NetworkJoin", "the join scene opens"):
		_finish(result_path)
		return

	var address_row: UiFormRow = join.get("address_row")
	var port_row: UiFormRow = join.get("port_row")
	var name_row: UiFormRow = join.get("name_row")
	address_row.set_value(address)
	port_row.set_value(str(port))
	name_row.set_value("UI Guest")
	join.call("_connect")
	result["stage"] = "connecting"
	if not _check(await _wait_until(func(): return _scene_name() == "NetworkSides", 20000),
			"the UI joined the side screen"):
		var status: Label = join.get("status_label") if join != null else null
		result["join_status"] = status.text if status != null else ""
		_finish(result_path)
		return
	result["connected"] = true
	result["sides_seen"] = true
	result["stage"] = "sides"

	var marker := {"ready": true}
	_write(ready_marker, marker)
	NET_SHELL.action(self, "set_ready", 0, 1, 0)
	if not _check(await _wait_until(func(): return _scene_name() == "NetworkLobby", 20000),
			"both peers reached the team screen"):
		_finish(result_path)
		return
	result["teams_seen"] = true
	result["stage"] = "teams"

	var lobby_vote := await _wait_for_dialog("NetworkLobby", 20000)
	if not _check(lobby_vote == NetworkBackVote.VOTE_BACK_TO_SIDES,
			"the team screen offered the BackToSides dialog"):
		_finish(result_path)
		return
	dialog_actions.append(lobby_vote)
	result["dialog_actions"] = dialog_actions
	result["stage"] = "back-to-sides"
	if not _check(await _wait_until(func(): return _scene_name() == "NetworkSides", 15000),
			"the team-screen vote returned to the side screen"):
		_finish(result_path)
		return

	var sides_vote := await _wait_for_dialog("NetworkSides", 20000)
	if not _check(sides_vote == NetworkBackVote.VOTE_LEAVE_SESSION,
			"the side screen offered the LeaveSession dialog"):
		_finish(result_path)
		return
	dialog_actions.append(sides_vote)
	result["dialog_actions"] = dialog_actions
	result["stage"] = "leave-session"
	if not _check(await _wait_until(func(): return _scene_name() == "NetworkMenu", 15000),
			"the leave vote returned to the network menu"):
		_finish(result_path)
		return
	result["left"] = true
	result["stage"] = "done"
	_finish(result_path)


func _wait_for_dialog(scene_name: String, timeout_ms: int) -> int:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if _scene_name() != scene_name:
			return -1
		var vote: NetworkBackVote = current_scene.get("back_vote") if current_scene != null else null
		if vote != null:
			var dialog := vote.get_node_or_null("Dialog")
			if dialog != null and dialog.visible:
				var action := int(vote.get("_incoming_action"))
				vote.call("_accept_incoming")
				return action
		await process_frame
	return -1


func _finish(result_path: String) -> void:
	result["status"] = "ok" if failures.is_empty() else "fail"
	result["failures"] = failures
	_write(result_path, result)
	print("JOIN UI PROBE: ", result["status"], " stage=", result.get("stage", ""))
	for failure in failures:
		print("JOIN UI PROBE FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

