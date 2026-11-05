class_name NetworkBackVote
extends Control
# Peer-equal Back confirmation for the pre-match LAN screens. Votes travel in
# the lobby's existing hub-vote channel; the peer that did not ask sees a modal
# with two choices. The component only interprets snapshots and sends votes;
# the screen adapter performs the actual scene transition after `agreed`.

signal action_agreed(action: int)
signal state_changed(status: String)

# Mirrors GameplayFootball's e_NetHubVote in netmessages.hpp.
const VOTE_NONE := 0
const VOTE_BACK_TO_TEAMS := 1
const VOTE_START_MATCH := 2
const VOTE_BACK_TO_SIDES := 3
const VOTE_LEAVE_SESSION := 4

const DIALOG_W := 760.0

var _action := VOTE_NONE
var _provider: Callable
var _sender: Callable
var _local_vote := 0
var _local_vote_until_ms := 0
var _pending := false

var _agreed_emitted := false
var _incoming_id := -1
var _incoming_name := ""
var _incoming_action := 0
var _dismissed_id := -1
var _status := ""
var _last_signature := ""

var _dialog: Control
var _dialog_panel: PanelContainer
var _dialog_title: Label
var _dialog_text: Label
var _dialog_rows: Array[UiMenuRow] = []
var _dialog_index := 0
var _previous_focus: Control


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 55
	_build_dialog()
	_connect_nav()
	set_process(true)
	call_deferred("_layout_dialog")



func setup(action: int, options: Dictionary = {}) -> void:
	_action = action
	_provider = options.get("provider", Callable())
	_sender = options.get("sender", Callable())
	_local_vote = 0
	_local_vote_until_ms = 0
	_pending = false

	_agreed_emitted = false
	_incoming_id = -1
	_incoming_name = ""
	_incoming_action = 0
	_dismissed_id = -1
	_close_dialog()
	_emit_state()


func request() -> void:
	if _action == VOTE_NONE:
		return
	if _local_vote == _action:
		_send_vote(VOTE_NONE)
		_local_vote = VOTE_NONE
		_local_vote_until_ms = 0
		_pending = false
		_status = ""
	else:
		_send_vote(_action)
		_local_vote = _action
		_local_vote_until_ms = Time.get_ticks_msec() + 1500
		_pending = true
		_dismissed_id = -1
		_status = "WAITING FOR THE OTHER PLAYER..."

	_emit_state()


func withdraw() -> void:
	if _local_vote == VOTE_NONE:
		return
	_send_vote(VOTE_NONE)
	_local_vote = VOTE_NONE
	_local_vote_until_ms = 0
	_pending = false
	_status = ""
	_emit_state()


func clear_server_vote() -> void:
	_send_vote(VOTE_NONE)
	_local_vote = VOTE_NONE
	_local_vote_until_ms = 0
	_pending = false
	_agreed_emitted = false
	_status = ""
	_emit_state()




func is_pending() -> bool:
	return _pending


func status_text() -> String:
	return _status


func _process(_delta: float) -> void:
	if _action == VOTE_NONE:
		return
	_poll()


func _poll() -> void:
	var info := _lobby_info()
	if info.is_empty() or not bool(info.get("active", false)):
		_reset_state()
		return
	var lobby: Dictionary = info.get("lobby", {})
	var local_id := int(info.get("local_id", -1))
	var players: Array = lobby.get("players", [])
	var local_vote := 0
	for player in players:
		if int(player.get("id", -1)) == local_id:
			local_vote = int(player.get("hub_vote", 0))
			break
	if local_vote != _local_vote:
		if _local_vote != VOTE_NONE and local_vote == VOTE_NONE \
				and Time.get_ticks_msec() < _local_vote_until_ms:
			# The vote is still travelling to the host; keep the local pending
			# state instead of flickering back to idle every frame.
			pass
		else:
			_local_vote = local_vote
			_local_vote_until_ms = 0
			_pending = _local_vote != VOTE_NONE
			_agreed_emitted = false
	elif local_vote != VOTE_NONE:
		_local_vote_until_ms = 0


	var agreed := int(lobby.get("hub_vote", VOTE_NONE))
	if not _agreed_emitted and _local_vote != VOTE_NONE and agreed == _local_vote:
		_agreed_emitted = true
		_pending = false
		_status = ""
		_close_dialog()
		_emit_state()
		action_agreed.emit(_local_vote)
		return

	if _local_vote == VOTE_NONE:
		var incoming := _first_incoming(players, local_id)
		if not incoming.is_empty():
			if int(incoming.get("id", -1)) != _dismissed_id:
				_open_dialog(incoming)
			if _dialog != null and _dialog.visible:
				return
		elif _dialog != null and _dialog.visible:
			_close_dialog()
			_dismissed_id = -1
		else:
			_dismissed_id = -1

	elif _dialog != null and _dialog.visible:
		_close_dialog()

	_status = "WAITING FOR THE OTHER PLAYER..." if _pending else ""
	_emit_state()


func _first_incoming(players: Array, local_id: int) -> Dictionary:
	for player in players:
		if int(player.get("id", -1)) == local_id:
			continue
		var vote := int(player.get("hub_vote", VOTE_NONE))
		if vote > VOTE_NONE and vote != VOTE_START_MATCH:
			return player
	return {}


func _open_dialog(player: Dictionary) -> void:
	_incoming_id = int(player.get("id", -1))
	_incoming_name = str(player.get("name", ""))
	_incoming_action = int(player.get("hub_vote", VOTE_NONE))
	_dialog_title.text = "%s WANTS TO GO BACK" % _incoming_name.to_upper()
	_dialog_text.text = "Go to %s with them?" % _destination_label(_incoming_action)
	visible = true
	_dialog.visible = true
	_dialog_index = 0
	_previous_focus = get_viewport().gui_get_focus_owner()
	var ui_nav := _ui_nav()
	if ui_nav != null:
		ui_nav.push_modal(self)
	_layout_dialog()
	_focus_dialog(0)
	_emit_state()



func _close_dialog() -> void:
	if _dialog == null or not _dialog.visible:
		return
	_dialog.visible = false
	visible = false
	var ui_nav := _ui_nav()
	if ui_nav != null:
		ui_nav.pop_modal(self)
	if _previous_focus != null and is_instance_valid(_previous_focus) \
			and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	_incoming_id = -1
	_incoming_name = ""
	_incoming_action = VOTE_NONE


func _accept_incoming() -> void:
	if _incoming_action == VOTE_NONE:
		return
	var action := _incoming_action
	_send_vote(action)
	_local_vote = action
	_local_vote_until_ms = Time.get_ticks_msec() + 1500
	_pending = true

	_agreed_emitted = false
	_dismissed_id = -1
	_close_dialog()
	_status = "WAITING FOR THE OTHER PLAYER..."
	_emit_state()


func _stay() -> void:
	_dismissed_id = _incoming_id
	_close_dialog()
	_status = ""
	_emit_state()


func _send_vote(value: int) -> void:
	if _sender.is_valid():
		_sender.call(value)
		return
	if get_tree() == null:
		return
	NetShell.action(get_tree(), "hubvote", 0, value, 0)


func _lobby_info() -> Dictionary:
	if _provider.is_valid():
		return _provider.call()
	if get_tree() == null:
		return {}
	return NetShell.lobby(get_tree())


func _emit_state() -> void:
	var signature := "%s|%s|%d" % [_status, str(_pending), _incoming_id]
	if signature == _last_signature:
		return
	_last_signature = signature
	state_changed.emit(_status)


func _reset_state() -> void:
	_status = ""
	_pending = false
	_local_vote = VOTE_NONE
	_local_vote_until_ms = 0
	_agreed_emitted = false
	_dismissed_id = -1

	_close_dialog()
	_emit_state()


func _destination_label(action: int) -> String:
	match action:
		VOTE_BACK_TO_TEAMS:
			return "TEAM SELECT"
		VOTE_BACK_TO_SIDES:
			return "SIDE SELECT"
		VOTE_LEAVE_SESSION:
			return "NETWORK MENU"
	return "BACK"


func _build_dialog() -> void:
	_dialog = Control.new()
	_dialog.name = "Dialog"
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.visible = false
	add_child(_dialog)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiTokens.OSK_SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	_dialog.add_child(scrim)

	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "Panel"
	_dialog_panel.theme_type_variation = &"FormPanel"
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.add_child(_dialog_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override(&"separation", 10)
	_dialog_panel.add_child(content)

	var eyebrow := Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.theme_type_variation = &"FormEyebrow"
	eyebrow.text = "BACK REQUEST"
	content.add_child(eyebrow)

	_dialog_title = Label.new()
	_dialog_title.name = "Title"
	_dialog_title.theme_type_variation = &"FormTitle"
	_dialog_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_dialog_title)

	_dialog_text = Label.new()
	_dialog_text.name = "Text"
	_dialog_text.theme_type_variation = &"FormValue"
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_dialog_text)

	var accept := UiMenuRow.new()
	accept.name = "Accept"
	accept.title_text = "LEAVE TOO"
	accept.sub_text = "Follow the other player"
	accept.pressed.connect(_accept_incoming)
	content.add_child(accept)
	_dialog_rows.append(accept)

	var stay := UiMenuRow.new()
	stay.name = "Stay"
	stay.title_text = "STAY"
	stay.sub_text = "Keep this screen"
	stay.pressed.connect(_stay)
	content.add_child(stay)
	_dialog_rows.append(stay)

	_dialog_panel.custom_minimum_size.x = DIALOG_W
	_dialog_panel.size = Vector2(DIALOG_W, _dialog_panel.get_combined_minimum_size().y)


func _layout_dialog() -> void:
	if _dialog_panel == null:
		return
	var panel_size := Vector2(DIALOG_W, _dialog_panel.get_combined_minimum_size().y)
	_dialog_panel.size = panel_size
	var view_size := size
	if view_size.x <= 0.0:
		view_size = get_viewport_rect().size
	_dialog_panel.position = (view_size - panel_size) * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_dialog()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_stay()


func _connect_nav() -> void:
	var ui_nav := _ui_nav()
	if ui_nav == null:
		return
	ui_nav.moved.connect(_on_nav_moved)
	ui_nav.moved_gamepad.connect(_on_nav_gamepad_moved)
	ui_nav.confirmed.connect(_on_nav_confirmed)
	ui_nav.cancelled.connect(_on_nav_cancelled)


func _on_nav_moved(direction: Vector2i) -> void:
	if not _dialog_open():
		return
	if ui_nav_last_gamepad():
		return
	_move_dialog(direction)


func _on_nav_gamepad_moved(direction: Vector2i, _device: int) -> void:
	if not _dialog_open():
		return
	_move_dialog(direction)


func _on_nav_confirmed() -> void:
	if not _dialog_open():
		return
	_activate_dialog()


func _on_nav_cancelled() -> void:
	if not _dialog_open():
		return
	_stay()


func _move_dialog(direction: Vector2i) -> void:
	if direction == Vector2i.UP:
		_dialog_index = 0
	elif direction == Vector2i.DOWN:
		_dialog_index = 1
	_focus_dialog(_dialog_index)


func _activate_dialog() -> void:
	if _dialog_index == 0:
		_accept_incoming()
	else:
		_stay()


func _focus_dialog(index: int) -> void:
	_dialog_index = clampi(index, 0, _dialog_rows.size() - 1)
	if _dialog_rows[_dialog_index] != null:
		_dialog_rows[_dialog_index].grab_focus()


func _dialog_open() -> bool:
	if _dialog == null or not _dialog.visible:
		return false
	var ui_nav := _ui_nav()
	return ui_nav != null and ui_nav.modal_owner() == self


func ui_nav_last_gamepad() -> bool:
	var ui_nav := _ui_nav()
	return ui_nav != null and ui_nav.last_input_gamepad()


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _exit_tree() -> void:
	if _dialog != null and _dialog.visible:
		_close_dialog()

