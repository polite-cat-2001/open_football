extends Control
# Godot port of SideSelectPage in network mode (src/menu/sideselect.cpp,
# NetworkSideSelectBackend): mirrored player rows, sides and ready are the
# host-authoritative lobby, not local devices. `resume_mode` is the in-match
# overlay (the original page opened with isInGame/resumeOnClose): it never
# leaves the session, only commits/cancels the side select and gets out.

signal closed

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"
const MATCH_SCENE := "res://scenes/gpf_slice.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
const NETWORK_MATCH := preload("res://scripts/net/network_match.gd")
const KEYBOARD_ICON := preload("res://assets/ui/controller/keyboard_small.png")
const GAMEPAD_ICON := preload("res://assets/ui/controller/controller_small.png")
const READY_MARK := preload("res://scripts/ui/ready_mark.gd")

const ROW_REPEAT_MS := 250
const RESUME_STATUS_SECONDS := 5.0

# Set by the in-match caller before the node enters the tree: the overlay is a
# mirrored resume page over the frozen match, not a lobby screen.
var resume_mode := false

var participants: Array = []
var row_icons: Array[TextureRect] = []
var row_names: Array[Label] = []
var row_marks: Array = []

var home_caption: Label
var away_caption: Label
var phase_caption: Label
var help_label: Label
var status_label: Label
var panel: ColorRect

var _player_ids: Array = []
var _last_device := -1
var _help_device := -1
var _gamepad_repeat := {}
var _leaving := false
var _entering_match := false
var _saw_side_select := false
var _committed := false
var _cancel_requested := false
var _closing := false
var _status_text := ""
var _status_until_ms := 0


func _ready() -> void:
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_poll_lobby()
	set_process(true)


func _build_ui() -> void:
	var background := ColorRect.new()
	# The resume overlay keeps the frozen match visible underneath.
	background.color = (Color(0.02, 0.03, 0.02, 0.60) if resume_mode
		else Color(0.02, 0.03, 0.02))
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	panel = ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.62)
	add_child(panel)

	home_caption = _caption("HOME", Color(0.95, 0.92, 0.82))
	away_caption = _caption("AWAY", Color(0.95, 0.92, 0.82))
	phase_caption = _caption("choose your side", Color(0.78, 0.78, 0.70))
	help_label = _caption("Left/Right: side    Enter: ready    Esc: leave",
		Color(0.72, 0.72, 0.66))
	status_label = _caption("", Color(1.0, 0.68, 0.30))


func _caption(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0 or view.y <= 0:
		return
	panel.position = Vector2(view.x * 0.10, view.y * 0.15)
	panel.size = Vector2(view.x * 0.80, view.y * 0.70)

	var caption_size := maxi(16, int(round(view.y * 0.035)))
	for label in [home_caption, away_caption, phase_caption, help_label, status_label]:
		label.add_theme_font_size_override("font_size", caption_size)

	_place(home_caption, 0.25, 0.10, 0.30, 0.06)
	_place(away_caption, 0.75, 0.10, 0.30, 0.06)
	_place(phase_caption, 0.50, 0.05, 0.40, 0.05)
	_place(help_label, 0.50, 0.88, 0.70, 0.05)
	_place(status_label, 0.50, 0.82, 0.70, 0.04)
	_position_rows()


func _place(label: Label, center_x: float, top: float, width: float, height: float) -> void:
	var view := get_viewport_rect().size
	label.position = Vector2(view.x * center_x - view.x * width * 0.5, view.y * top)
	label.size = Vector2(view.x * width, view.y * height)


func _position_rows() -> void:
	var view := get_viewport_rect().size
	for i in participants.size():
		if i >= row_icons.size():
			break
		var participant: Dictionary = participants[i]
		var side := int(participant.get("side", 0))
		var icon: TextureRect = row_icons[i]
		var icon_size := Vector2(view.x * 0.14, view.y * 0.10)
		var center_x := view.x * (0.25 if side < 0 else (0.75 if side > 0 else 0.50))
		var top := view.y * 0.20 + float(i) * view.y * 0.15
		icon.position = Vector2(center_x - icon_size.x * 0.5, top)
		icon.size = icon_size

		var label: Label = row_names[i]
		var name := str(participant.get("name", ""))
		label.text = ("> " + name) if bool(participant.get("is_local", false)) else name
		label.position = Vector2(center_x - view.x * 0.15, top + view.y * 0.10)
		label.size = Vector2(view.x * 0.30, view.y * 0.04)
		label.add_theme_font_size_override("font_size", maxi(12, int(view.y * 0.022)))

		var mark = row_marks[i]
		mark.position = Vector2(center_x + view.x * 0.05, top + view.y * 0.13)
		mark.size = Vector2(view.x * 0.03, view.y * 0.03)
		mark.set_checked(bool(participant.get("ready", false)))
		mark.queue_redraw()


func _rebuild_rows() -> void:
	for icon in row_icons:
		icon.queue_free()
	for label in row_names:
		label.queue_free()
	for mark in row_marks:
		mark.queue_free()
	row_icons.clear()
	row_names.clear()
	row_marks.clear()

	for participant in participants:
		var icon := TextureRect.new()
		icon.texture = GAMEPAD_ICON if int(participant.get("device", 0)) == 1 else KEYBOARD_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(icon)
		row_icons.append(icon)

		var label := Label.new()
		label.add_theme_font_override("font", MENU_FONT)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.84))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		row_names.append(label)

		var mark = READY_MARK.new()
		mark.visible = false
		add_child(mark)
		row_marks.append(mark)

	_position_rows()


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

	if int(lobby.get("phase", -1)) == 1:
		get_tree().change_scene_to_file(LOBBY_SCENE)
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
	if ids != _player_ids:
		_player_ids = ids
		_rebuild_rows()
		if resume_mode and not previous_ids.is_empty():
			_note_roster_change(previous_ids, ids)
	else:
		_position_rows()

	for participant in participants:
		if bool(participant.get("is_local", false)):
			var device := int(participant.get("device", 0))
			if device != _help_device:
				_help_device = device
				var back_caption := "back" if resume_mode else "leave"
				help_label.text = ("Left/Right: side    A: ready    B: " + back_caption
					if device == 1
					else "Left/Right: side    Enter: ready    Esc: " + back_caption)
			break


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
	if status_label != null:
		status_label.text = text


func _refresh_status() -> void:
	if _status_text.is_empty():
		return
	if _status_until_ms != 0 and Time.get_ticks_msec() < _status_until_ms:
		return
	_status_text = ""
	if status_label != null:
		status_label.text = ""


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
	_entering_match = true
	var options := {
		"difficulty": float(lobby.get("match_difficulty", 0.8)),
		"duration": float(lobby.get("match_duration", 1.0)),
	}
	var runtime := NET_SHELL.active_runtime(get_tree())
	var package := NETWORK_MATCH.apply_setup(get_tree(), runtime, setup, options)
	if package.is_empty():
		_entering_match = false
		status_label.text = NETWORK_MATCH.error
		return
	get_tree().change_scene_to_file(MATCH_SCENE)


func _process(_delta: float) -> void:
	if resume_mode:
		_refresh_status()
	_poll_lobby()


func _local_participant() -> Dictionary:
	for participant in participants:
		if bool(participant.get("is_local", false)):
			return participant
	return {}


func _change_side(delta: int) -> void:
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
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	get_tree().change_scene_to_file(NETWORK_MENU_SCENE)


func _input(event: InputEvent) -> void:
	if _leaving or _entering_match or _closing:
		return
	if resume_mode:
		_handle_resume_input(event)
		# The overlay owns every input event while it is up; the match must not
		# see the same buttons (double action).
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo or not key.pressed:
			return
		_send_device(0)
		NET_SHELL.note_local_device(get_tree(), "keyboard", 0)
		match key.keycode:
			KEY_LEFT:
				_change_side(-1)
			KEY_RIGHT:
				_change_side(1)
			KEY_ENTER, KEY_KP_ENTER:
				_toggle_ready()
			KEY_ESCAPE:
				var local := _local_participant()
				if not local.is_empty() and bool(local.get("ready", false)):
					NET_SHELL.action(get_tree(), "set_ready", 0, 0, 0)
				else:
					_leave()
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if not joy.pressed:
			return
		_send_device(1)
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(joy.device))
		match int(joy.button_index):
			JOY_BUTTON_DPAD_LEFT:
				_change_side(-1)
			JOY_BUTTON_DPAD_RIGHT:
				_change_side(1)
			JOY_BUTTON_A:
				_toggle_ready()
			JOY_BUTTON_B:
				_leave()
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if int(motion.axis) != JOY_AXIS_LEFT_X or absf(motion.axis_value) < 0.5:
			return
		_send_device(1)
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(motion.device))
		var now := Time.get_ticks_msec()
		var device := int(motion.device)
		if now - int(_gamepad_repeat.get(device, 0)) < ROW_REPEAT_MS:
			return
		_gamepad_repeat[device] = now
		_change_side(-1 if motion.axis_value < 0.0 else 1)


func _handle_resume_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo or not key.pressed:
			return
		_send_device(0)
		NET_SHELL.note_local_device(get_tree(), "keyboard", 0)
		match key.keycode:
			KEY_LEFT:
				_change_side(-1)
			KEY_RIGHT:
				_change_side(1)
			KEY_ENTER, KEY_KP_ENTER:
				_toggle_ready()
			KEY_ESCAPE:
				_cancel_resume()
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if not joy.pressed:
			return
		_send_device(1)
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(joy.device))
		match int(joy.button_index):
			JOY_BUTTON_DPAD_LEFT:
				_change_side(-1)
			JOY_BUTTON_DPAD_RIGHT:
				_change_side(1)
			JOY_BUTTON_A:
				_toggle_ready()
			JOY_BUTTON_B:
				_cancel_resume()
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if int(motion.axis) != JOY_AXIS_LEFT_X or absf(motion.axis_value) < 0.5:
			return
		_send_device(1)
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(motion.device))
		var now := Time.get_ticks_msec()
		var device := int(motion.device)
		if now - int(_gamepad_repeat.get(device, 0)) < ROW_REPEAT_MS:
			return
		_gamepad_repeat[device] = now
		_change_side(-1 if motion.axis_value < 0.0 else 1)


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
