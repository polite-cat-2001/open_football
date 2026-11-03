extends Control

# Local adapter for SideSelectView: devices come from InputSetup and the
# confirmed sides go to ShellState. The shared view owns the layout and input.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"
const PREMATCH_SCENE := "res://scenes/prematch.tscn"

@onready var view: SideSelectView = $SideSelectView

var participants: Array = []
var status_label: Label
var _committed := false
var _device_order: Array[String] = []


func _ready() -> void:
	add_to_group(&"ui_shell")
	theme = UiTheme.load_or_build()
	_build_participants()
	status_label = view.status_label
	view.setup(_rows(), {
		"input_mode": "devices",
		"show_names": false,
		"row_layout": "stack",
		"back_label": "leave",
	})
	view.row_move_requested.connect(_on_row_move)
	view.row_confirm_requested.connect(_on_row_confirm)
	view.row_cancel_requested.connect(_on_row_cancel)
	view.back_requested.connect(_leave)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _build_participants() -> void:
	var devices := InputSetup.available_devices()
	var count := devices.size()
	var saved: Array = ShellState.controllers if ShellState.controllers_configured else []
	participants.clear()
	_device_order.clear()
	for i in count:
		var device: Dictionary = devices[i]
		var side := 0
		# A lone keyboard starts on home. With several devices every row starts in
		# the centre until it is moved: a pre-assigned home row would otherwise
		# block the other device's ready (all active rows must confirm).
		if count == 1 and i == 0:
			side = -1
		for entry in saved:
			if not (entry is Dictionary):
				continue
			if str(entry.get("kind", "")) == str(device.get("kind", "")) \
					and int(entry.get("device", -1)) == int(device.get("device", -2)):
				side = _side_value(str(entry.get("side", "home")))
				break
		var participant := _make_participant(device, side, i)
		participants.append(participant)
		_device_order.append(str(participant["id"]))


func _make_participant(device: Dictionary, side: int, index: int) -> Dictionary:
	return {
		"id": _row_id(device),
		"device": int(device.get("device", 0)),
		"kind": str(device.get("kind", "keyboard")),
		"name": str(device.get("name", "Device")),
		"side": side,
		"ready": false,
		"tone_index": index,
		"row": index,
	}


# Reconciles the rows with the currently connected devices. Existing rows keep
# their side/ready and their place; a new device starts in the centre and is
# appended below the others (connection order); removed devices vanish.
func _sync_participants(devices: Array = []) -> void:
	if devices.is_empty():
		devices = InputSetup.available_devices()
	var by_id := {}
	var scan_order: Array[String] = []
	for device in devices:
		if not (device is Dictionary):
			continue
		var id := _row_id(device)
		by_id[id] = device
		scan_order.append(id)
		if not _device_order.has(id):
			_device_order.append(id)
	var ordered: Array[String] = []
	for id in _device_order:
		if by_id.has(id) and not ordered.has(id):
			ordered.append(id)
	for id in scan_order:
		if not ordered.has(id):
			ordered.append(id)
	_device_order = ordered

	var previous := {}
	for participant in participants:
		previous[str(participant["id"])] = participant
	var next: Array = []
	for i in _device_order.size():
		var id := _device_order[i]
		var device: Dictionary = by_id[id]
		var participant: Dictionary
		if previous.has(id):
			participant = previous[id]
			participant["device"] = int(device.get("device", participant["device"]))
			participant["kind"] = str(device.get("kind", participant["kind"]))
			participant["name"] = str(device.get("name", participant["name"]))
		else:
			participant = _make_participant(device, 0, i)
		participant["tone_index"] = i
		participant["row"] = i
		next.append(participant)
	participants = next
	_refresh_view()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if _committed:
		return
	var id := _row_id({"kind": "gamepad", "device": device})
	if connected:
		if not _device_order.has(id):
			_device_order.append(id)
	else:
		_device_order.erase(id)
	_sync_participants()


func _rows() -> Array:
	var result: Array = []
	for participant in participants:
		result.append({
			"id": str(participant["id"]),
			"kind": str(participant["kind"]),
			"device": int(participant["device"]),
			"name": "",
			"side": int(participant["side"]),
			"ready": bool(participant["ready"]),
			"local": true,
			"tone_index": int(participant["tone_index"]),
		})
	return result


func _refresh_view() -> void:
	view.apply_rows(_rows())


func _on_row_move(row_id: String, delta: int, _input: Dictionary) -> void:
	var participant := _participant_by_id(row_id)
	if participant.is_empty():
		return
	var spatial := _spatial_index(int(participant["side"])) + delta
	spatial = clampi(spatial, 0, 2)
	var side := _side_from_spatial(spatial)
	if side == int(participant["side"]):
		return
	participant["side"] = side
	participant["ready"] = false
	view.set_status("")
	_refresh_view()


func _on_row_confirm(row_id: String, _input: Dictionary) -> void:
	var participant := _participant_by_id(row_id)
	if participant.is_empty():
		return
	if int(participant["side"]) == 0:
		view.set_status("Choose a side first.", true)
		return
	participant["ready"] = true
	view.set_status("")
	_refresh_view()
	if _all_ready():
		_commit()


func _on_row_cancel(row_id: String, _input: Dictionary) -> void:
	var participant := _participant_by_id(row_id)
	if participant.is_empty():
		_leave()
		return
	if bool(participant["ready"]):
		participant["ready"] = false
		view.set_status("")
		_refresh_view()
		return
	_leave()


func _participant_by_id(row_id: String) -> Dictionary:
	for participant in participants:
		if str(participant["id"]) == row_id:
			return participant
	return {}


func _all_ready() -> bool:
	var active := 0
	for participant in participants:
		if int(participant["side"]) == 0:
			continue
		active += 1
		if not bool(participant["ready"]):
			return false
	return active > 0


func _commit() -> void:
	if _committed:
		return
	var active: Array = []
	for participant in participants:
		if int(participant["side"]) == 0:
			continue
		active.append({
			"side": "away" if int(participant["side"]) > 0 else "home",
			"kind": str(participant["kind"]),
			"device": int(participant["device"]),
			"name": str(participant["name"]),
		})
	if active.is_empty():
		view.set_status("Choose a side first.", true)
		return
	_committed = true
	ShellState.set_controllers(active)
	var target := PREMATCH_SCENE if ShellState.has_selection() else TEAM_SELECT_SCENE
	UiTransition.change_scene(target)


func _leave() -> void:
	if _committed:
		return
	_committed = true
	UiTransition.change_scene(MAIN_MENU_SCENE)


func _row_id(device: Dictionary) -> String:
	return "%s:%d" % [str(device.get("kind", "keyboard")), int(device.get("device", 0))]


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


func _side_value(side: String) -> int:
	return 1 if side == "away" else -1
