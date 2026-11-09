class_name SettingsSideSelect
extends Control
# Local side select opened from the prematch hub's settings screen. It reuses
# the shared SideSelectView (its own stadium stage) on top of the settings,
# writes ShellState.controllers and closes back to the settings screen.

signal closed
signal controllers_changed

const SIDE_VIEW_SCENE := preload("res://scenes/ui/side_select_view.tscn")
const TRANSITION_OUT := 0.15
const TRANSITION_IN := 0.24
const TRANSITION_SCALE := 0.96

var runtime: Node
var view: SideSelectView
var participants: Array = []

var _committed := false
var _closing := false
var _device_order: Array[String] = []


func _ready() -> void:
	add_to_group(&"ui_shell")
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.load_or_build()
	view = SIDE_VIEW_SCENE.instantiate() as SideSelectView
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	view.set_overlay_mode(runtime != null)
	if runtime != null and view.stage != null:
		# In-match side select over the frozen match: no extra dim veil.
		var dim := view.stage.overlay.color
		dim.a = 0.0
		view.stage.overlay.color = dim
	view.row_move_requested.connect(_on_row_move)
	view.row_confirm_requested.connect(_on_row_confirm)
	view.row_cancel_requested.connect(_on_row_cancel)
	view.back_requested.connect(_close)
	_build_participants()
	view.setup(_rows(), {
		"input_mode": "devices",
		"show_names": false,
		"row_layout": "stack",
		"back_label": "back",
		"title": "SIDE SELECT",
	})
	_show_animated()


func _show_animated() -> void:
	if _animations_instant() or view == null:
		return
	# Animate the content only: the stage photo matches the hub backdrop, so
	# fading it in would visibly "redraw" the same background.
	var panel := view.panel_wrap
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * TRANSITION_SCALE
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, TRANSITION_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, TRANSITION_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)



func _build_participants() -> void:
	var devices := InputSetup.available_devices()
	var saved: Array = ShellState.controllers if ShellState.controllers_configured else []
	participants.clear()
	_device_order.clear()
	for i in devices.size():
		var device: Dictionary = devices[i]
		var side := 0
		if devices.size() == 1 and i == 0:
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


func _on_row_move(row_id: String, delta: int, _input: Dictionary) -> void:
	if _closing:
		return
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
	view.apply_rows(_rows())


func _on_row_confirm(row_id: String, _input: Dictionary) -> void:
	if _closing:
		return
	var participant := _participant_by_id(row_id)
	if participant.is_empty():
		return
	if int(participant["side"]) == 0:
		view.set_status("Choose a side first.", true)
		return
	participant["ready"] = true
	view.set_status("")
	view.apply_rows(_rows())
	if _all_ready():
		_commit()


func _on_row_cancel(row_id: String, _input: Dictionary) -> void:
	if _closing:
		return
	var participant := _participant_by_id(row_id)
	if participant.is_empty():
		_close()
		return
	if bool(participant["ready"]):
		participant["ready"] = false
		view.set_status("")
		view.apply_rows(_rows())
		return
	_close()


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
	_apply_to_runtime()
	controllers_changed.emit()
	_close()


func _apply_to_runtime() -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	InputSetup.apply_to_runtime(runtime, ShellState.controllers)
	if runtime.has_method("refresh_human_controllers"):
		runtime.refresh_human_controllers()


func _close() -> void:
	if _closing:
		return
	_closing = true
	if not _committed:
		_committed = true
	if _animations_instant():
		closed.emit()
		return
	var panel := view.panel_wrap
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, TRANSITION_OUT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2.ONE * TRANSITION_SCALE,
		TRANSITION_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	closed.emit()


func _animations_instant() -> bool:
	return DisplayServer.get_name() == "headless" or not is_inside_tree()


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
