class_name NetShell
extends RefCounted
# Shell-side access to the one original runtime node. The C++ runtime can only
# be initialized once per process, so LAN screens bring it up without a match
# (auto_start_match = false) and reuse the same node in the match scene.

const RUNTIME_SCENE := preload("res://scenes/gpf_runtime.tscn")
const RUNTIME_GROUP := "gpf_runtime"

static var last_host_port := 27015
static var last_host_name := "Host"
static var last_join_address := "127.0.0.1"
static var last_join_port := 27015
static var last_join_name := "Player"


static func runtime(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var node := tree.get_first_node_in_group(RUNTIME_GROUP)
	if node == null:
		node = RUNTIME_SCENE.instantiate()
		node.set("manual_step", true)
		node.set("auto_start_match", false)
		node.add_to_group(RUNTIME_GROUP)
		tree.root.add_child(node)
	if not bool(node.is_runtime_ready()):
		node.set("auto_start_match", false)
		if str(node.get_data_root()).is_empty():
			node.set("data_root", TeamCatalog.new().resolve_data_root())
		node.start_runtime_now()
	return node


static func active_runtime(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var node := tree.get_first_node_in_group(RUNTIME_GROUP)
	if node == null or not bool(node.is_net_active()):
		return null
	return node


static func is_active(tree: SceneTree) -> bool:
	return active_runtime(tree) != null


static func leave(tree: SceneTree) -> void:
	var node := active_runtime(tree)
	if node != null:
		node.net_leave()


static func lobby(tree: SceneTree) -> Dictionary:
	var node := active_runtime(tree)
	if node == null:
		return {}
	return node.net_lobby()


static func action(tree: SceneTree, action_type, side: int = 0, value: int = 0,
		value2: int = 0) -> bool:
	var node := active_runtime(tree)
	if node == null:
		return false
	return bool(node.net_action(action_type, side, value, value2))


static func note_local_device(tree: SceneTree, kind: String, device_id: int) -> void:
	# Record the last device the peer used so the match binds it (the host's
	# NetMatchSession chooses the lobby 'device' type; the shell forwards its
	# raw input through InputSetup's slot map).
	var side := local_side_text(tree)
	if side.is_empty():
		return
	var node := runtime(tree)
	if node == null:
		return
	if kind == "gamepad" and device_id >= 0:
		node.register_gamepad(device_id)
	ShellState.set_controllers([{
		"side": side,
		"kind": kind,
		"device": device_id,
		"name": "Gamepad" if kind == "gamepad" else "Keyboard",
	}])


static func local_side_text(tree: SceneTree) -> String:
	var info := lobby(tree)
	if info.is_empty():
		return ""
	var local_id := int(info.get("local_id", -1))
	var players: Array = info.get("lobby", {}).get("players", [])
	for player in players:
		if int(player.get("id", -1)) != local_id:
			continue
		var side := int(player.get("side", -1))
		if side == 0:
			return "home"
		if side == 1:
			return "away"
		return ""
	return ""


static func local_team_id(lobby_info: Dictionary) -> int:
	var local_id := int(lobby_info.get("local_id", -1))
	var players: Array = lobby_info.get("lobby", {}).get("players", [])
	for player in players:
		if int(player.get("id", -1)) != local_id:
			continue
		var side := int(player.get("side", -1))
		if side == 0:
			return 0
		if side == 1:
			return 1
	return -1
