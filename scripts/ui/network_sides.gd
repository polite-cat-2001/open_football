extends Control

# Network adapter for SideSelectView: mirrored player rows, sides and ready are
# the host-authoritative lobby, not local devices. `resume_mode` is the in-match
# overlay (the original page opened with isInGame/resumeOnClose): it never
# leaves the session, only commits/cancels the side select and gets out.
# Back here is a local leave: the peer drops the session alone (the other peer
# keeps the lobby and can be rejoined) instead of asking LEAVE TOO/STAY.

signal closed

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"
const MATCH_SCENE := "res://scenes/gpf_slice.tscn"
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
const NETWORK_MATCH := preload("res://scripts/net/network_match.gd")

const RESUME_STATUS_SECONDS := 5.0

# Set by the in-match caller before the node enters the tree: the overlay is a
# mirrored resume page over the frozen match, not a lobby screen.
var resume_mode := false

@onready var view: SideSelectView = $SideSelectView

var participants: Array = []

var _player_ids: Array = []
var _last_device := -1
var _guest_assigned := false
var _leaving := false
var _entering_match := false
var _saw_side_select := false
var _committed := false
var _cancel_requested := false
var _closing := false
var _status_text := ""
var _status_until_ms := 0


func _ready() -> void:
	add_to_group(&"ui_shell")
	theme = UiTheme.load_or_build()
	view.set_overlay_mode(resume_mode)
	view.setup([], {
		"input_mode": "local_player",
		"show_names": true,
		"row_layout": "stack",
		"back_label": "back" if resume_mode else "leave",
	})
	view.row_move_requested.connect(_on_row_move)
	view.row_confirm_requested.connect(_on_row_confirm)
	view.row_cancel_requested.connect(_on_row_cancel)
	view.back_requested.connect(_on_back)
	# A client landing here waits for MatchSetup: put the curtain up at once so the
	# pre-match side select cannot flash before the match takes over (a peer that
	# joins a running match gets its setup within a frame or two).
	if not resume_mode and bool(NET_SHELL.lobby(get_tree()).get("is_client", false)):
		_show_connecting()
	_poll_lobby()
	set_process(true)


func _show_connecting() -> void:
	var connecting := get_node_or_null("/root/UiConnecting")
	if connecting == null or bool(connecting.is_open()):
		return
	connecting.open(_cancel_connecting)


func _hide_connecting() -> void:
	var connecting := get_node_or_null("/root/UiConnecting")
	if connecting != null and bool(connecting.is_open()):
		connecting.close()


# The peer never reached the match, so leaving needs no vote from the host: drop
# the session and go back to the main menu behind the fading curtain.
func _cancel_connecting() -> void:
	if _leaving:
		return
	_leaving = true
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	for attempt in 120:
		if not is_inside_tree():
			return
		UiTransition.change_scene(MAIN_MENU_SCENE)
		await get_tree().process_frame
		if UiTransition.is_busy():
			break
	_hide_connecting()


func _rows() -> Array:
	var result: Array = []
	for i in participants.size():
		var participant: Dictionary = participants[i]
		result.append({
			"id": "player:%d" % int(participant.get("id", -1)),
			"kind": "gamepad" if int(participant.get("device", 0)) == 1 else "keyboard",
			"device": int(participant.get("device", 0)),
			"name": str(participant.get("name", "")),
			"side": int(participant.get("side", 0)),
			"ready": bool(participant.get("ready", false)),
			"local": bool(participant.get("is_local", false)),
			"tone_index": i,
		})
	return result


func _apply_rows() -> void:
	view.apply_rows(_rows())


func _poll_lobby() -> void:
	if _leaving or _entering_match or _closing:
		return
	if resume_mode:
		_poll_resume()
		return
	var info := NET_SHELL.lobby(get_tree())
	if info.is_empty() or not bool(info.get("active", false)):
		_leave()
		return
	if bool(info.get("is_client", false)) and int(info.get("connection", 0)) == 0:
		_leave()
		return

	var lobby: Dictionary = info.get("lobby", {})
	_refresh_players(info, lobby)
	_assign_guest_side(info)
	# A running match keeps the curtain up until the match scene closes it; a normal
	# pre-match lobby has nothing to wait for, so reveal this screen.
	if not bool(lobby.get("side_select", false)):
		_hide_connecting()

	if int(lobby.get("phase", -1)) == 1:
		_hide_connecting()
		UiTransition.change_scene(LOBBY_SCENE)
		return

	if bool(info.get("is_client", false)):
		var runtime := NET_SHELL.active_runtime(get_tree())
		if runtime != null:
			var setup: Dictionary = runtime.net_take_match_setup()
			if not setup.is_empty():
				_enter_match(setup, lobby)


# The in-match page: NetworkSideSelectBackend::Process/PollClosed. The host
# commits once every peer (spectators included) is ready; a client waits for
# the mirrored flag to clear. Leaving the connection is not an option here.
func _poll_resume() -> void:
	var info := NET_SHELL.lobby(get_tree())
	if info.is_empty() or not bool(info.get("active", false)):
		_close_resume()
		return
	if bool(info.get("is_client", false)) and int(info.get("connection", 0)) == 0:
		_close_resume()
		return

	var lobby: Dictionary = info.get("lobby", {})
	_refresh_players(info, lobby)
	var side_select := bool(lobby.get("side_select", false))
	if side_select:
		_saw_side_select = true
	if _saw_side_select and not side_select:
		_close_resume()
		return
	if not side_select:
		return

	if not _committed and not _cancel_requested and bool(info.get("is_host", false)) \
			and _all_ready():
		_committed = true
		_set_status("starting...", 0.0)
		var runtime := NET_SHELL.active_runtime(get_tree())
		if runtime != null:
			runtime.net_side_select_commit()


func _refresh_players(info: Dictionary, lobby: Dictionary) -> void:
	var players: Array = lobby.get("players", [])
	var ids: Array = []
	var new_participants: Array = []
	var local_id := int(info.get("local_id", -1))
	for player in players:
		var id := int(player.get("id", -1))
		ids.append(id)
		new_participants.append({
			"id": id,
			"name": str(player.get("name", "")),
			"side": _net_to_side(int(player.get("side", 2))),
			"ready": bool(player.get("ready", false)),
			"device": int(player.get("device", 0)),
			"is_local": id == local_id,
		})
	participants = new_participants

	var previous_ids := _player_ids
	var roster_changed := ids != _player_ids
	_player_ids = ids
	_apply_rows()
	if resume_mode and roster_changed and not previous_ids.is_empty():
		_note_roster_change(previous_ids, ids)


func _note_roster_change(previous_ids: Array, ids: Array) -> void:
	for id in previous_ids:
		if not ids.has(id):
			_set_status("Player disconnected", RESUME_STATUS_SECONDS)
			return
	for id in ids:
		if not previous_ids.has(id):
			_set_status("Player joined", RESUME_STATUS_SECONDS)
			return


func _all_ready() -> bool:
	# NetworkSideSelectBackend::AllReady: every player row, spectators too.
	if participants.is_empty():
		return false
	for participant in participants:
		if not bool(participant.get("ready", false)):
			return false
	return true


func set_status(text: String, seconds: float = RESUME_STATUS_SECONDS) -> void:
	_set_status(text, seconds)


func _set_status(text: String, seconds: float) -> void:
	_status_text = text
	_status_until_ms = (Time.get_ticks_msec() + int(seconds * 1000.0)) if seconds > 0.0 else 0
	if view != null:
		view.set_status(text)


func _refresh_status() -> void:
	if _status_text.is_empty():
		return
	if _status_until_ms != 0 and Time.get_ticks_msec() < _status_until_ms:
		return
	_status_text = ""
	if view != null:
		view.set_status("")


func _cancel_resume() -> void:
	# NetworkSideSelectBackend::Cancel: the host applies the sides and stays
	# paused; a client asks the host and waits for the mirrored flag to clear
	# (the page stays up until then, like the original).
	if _closing or _cancel_requested:
		return
	_cancel_requested = true
	_set_status("leaving side selection...", 0.0)
	var runtime := NET_SHELL.active_runtime(get_tree())
	if runtime != null:
		runtime.net_side_select_cancel()


func _close_resume() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()


func _enter_match(setup: Dictionary, lobby: Dictionary) -> void:
	if _entering_match:
		return
	var options := {
		"difficulty": float(lobby.get("match_difficulty", 0.8)),
		"duration": float(lobby.get("match_duration", 1.0)),
	}
	var runtime := NET_SHELL.active_runtime(get_tree())
	var package := NETWORK_MATCH.apply_setup(get_tree(), runtime, setup, options)
	if package.is_empty():
		view.set_status(NETWORK_MATCH.error, true)
		return
	# `UiTransition` silently drops a scene change requested while its own
	# animation is still running — a peer that joins a running match gets
	# MatchSetup in the middle of the screen fade. Without the retry the screen
	# stayed here forever: the poll and the cursor were dead, the row frozen.
	_entering_match = true
	for attempt in 120:
		if not is_inside_tree():
			return
		UiTransition.change_scene(MATCH_SCENE)
		await get_tree().process_frame
	_entering_match = false
	view.set_status("could not enter the match", true)


func _process(_delta: float) -> void:
	if resume_mode:
		_refresh_status()
	_poll_lobby()


func _local_participant() -> Dictionary:
	for participant in participants:
		if bool(participant.get("is_local", false)):
			return participant
	return {}


# A joining client takes the guest (away) side with its own input by default;
# either player can still move sides on this screen afterwards.
func _assign_guest_side(info: Dictionary) -> void:
	if _guest_assigned or not bool(info.get("is_client", false)):
		return
	var local := _local_participant()
	if local.is_empty() or int(local.get("side", 0)) != 0:
		return
	_guest_assigned = true
	NET_SHELL.action(get_tree(), "set_side", 1, 0, 0)


func _on_row_move(_row_id: String, delta: int, input: Dictionary) -> void:
	if _leaving or _entering_match or _closing:
		return
	_note_input(input)
	var local := _local_participant()
	if local.is_empty():
		return
	var current := int(local.get("side", 0))
	var spatial := _spatial_index(current) + delta
	spatial = clampi(spatial, 0, 2)
	var side := _side_from_spatial(spatial)
	if side == current:
		return
	NET_SHELL.action(get_tree(), "set_side", _side_to_net(side), 0, 0)


func _on_row_confirm(_row_id: String, input: Dictionary) -> void:
	if _leaving or _entering_match or _closing:
		return
	_note_input(input)
	_toggle_ready()


func _on_row_cancel(_row_id: String, input: Dictionary) -> void:
	if _leaving or _entering_match or _closing:
		return
	_note_input(input)
	if resume_mode:
		_cancel_resume()
		return
	var local := _local_participant()
	if not local.is_empty() and bool(local.get("ready", false)):
		NET_SHELL.action(get_tree(), "set_ready", 0, 0, 0)
		return
	# Not ready yet: cancel leaves the session (a ready row only un-readies).
	_leave()


func _on_back() -> void:
	if resume_mode:
		_cancel_resume()
		return
	_leave()


func _note_input(input: Dictionary) -> void:
	var kind := str(input.get("kind", "keyboard"))
	_send_device(0 if kind == "keyboard" else 1)
	NET_SHELL.note_local_device(get_tree(), kind, int(input.get("device", 0)))


func _toggle_ready() -> void:
	var local := _local_participant()
	if local.is_empty():
		return
	NET_SHELL.action(get_tree(), "set_ready", 0, 0 if bool(local.get("ready", false)) else 1, 0)


func _send_device(device: int) -> void:
	if device == _last_device:
		return
	_last_device = device
	NET_SHELL.action(get_tree(), "set_device", 0, device, 0)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_hide_connecting()
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	UiTransition.change_scene(NETWORK_MENU_SCENE)


func _spatial_index(side: int) -> int:
	if side < 0:
		return 0
	if side > 0:
		return 2
	return 1


func _side_from_spatial(spatial: int) -> int:
	if spatial <= 0:
		return -1
	if spatial >= 2:
		return 1
	return 0


func _net_to_side(side: int) -> int:
	if side == 0:
		return -1
	if side == 1:
		return 1
	return 0


func _side_to_net(side: int) -> int:
	if side < 0:
		return 0
	if side > 0:
		return 1
	return 2

