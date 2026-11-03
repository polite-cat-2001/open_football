class_name SideSelectView
extends Control

signal row_move_requested(row_id: String, delta: int, input: Dictionary)
signal row_confirm_requested(row_id: String, input: Dictionary)
signal row_cancel_requested(row_id: String, input: Dictionary)
signal back_requested

const STADIUM_TEXTURE := "res://assets/ui/menu/stadium.jpg"

@onready var stage: Control = $Stage
@onready var photo: TextureRect = $Stage/Photo
@onready var overlay: ColorRect = $Stage/Overlay
@onready var scrim: ColorRect = $Stage/Scrim
@onready var design: Control = $Design
@onready var panel_wrap: Control = $Design/PanelWrap
@onready var head: PanelContainer = $Design/PanelWrap/Head
@onready var title_label: Label = $Design/PanelWrap/Head/Title
@onready var body: Control = $Design/PanelWrap/Body
@onready var body_fill: TextureRect = $Design/PanelWrap/Body/BodyFill
@onready var home_label: SideSelectVerticalLabel = $Design/PanelWrap/Body/HomeLabel
@onready var away_label: SideSelectVerticalLabel = $Design/PanelWrap/Body/AwayLabel
@onready var track: Control = $Design/PanelWrap/Body/Track
@onready var status_label: Label = $Design/PanelWrap/Status
@onready var legend: UiLegend = $Design/PanelWrap/Legend

var overlay_mode := false

var _ui_nav: Node
var _input_override: Dictionary = {}
var _rows: Array = []
var _row_nodes: Dictionary = {}
var _row_geometry: Array = []
var _input_mode := "devices"
var _show_names := false
var _row_layout := "stack"
var _back_label := "back"
var _body_height := 0.0


func _ready() -> void:
	photo.texture = load(STADIUM_TEXTURE)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	body_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body_fill.stretch_mode = TextureRect.STRETCH_SCALE
	body_fill.texture = _body_gradient()
	_apply_overlay_mode()
	_ui_nav = get_node_or_null("/root/UiNav")
	if _ui_nav != null:
		_ui_nav.moved.connect(_on_nav_moved)
		if _ui_nav.has_signal("moved_gamepad"):
			_ui_nav.moved_gamepad.connect(_on_nav_gamepad_moved)
		_ui_nav.confirmed.connect(_on_nav_confirmed)
		_ui_nav.cancelled.connect(_on_nav_cancelled)
		_ui_nav.device_changed.connect(_on_device_changed)
	legend.setup(_keyboard_hints())
	theme_changed.connect(_layout)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func setup(new_rows: Array, options: Dictionary = {}) -> void:
	_input_mode = str(options.get("input_mode", _input_mode))
	_show_names = bool(options.get("show_names", _show_names))
	_row_layout = str(options.get("row_layout", _row_layout))
	_back_label = str(options.get("back_label", _back_label))
	set_title(str(options.get("title", "SIDE SELECT")))
	overlay_mode = bool(options.get("overlay", overlay_mode))
	_apply_overlay_mode()
	set_status(
		str(options.get("status", "")),
		bool(options.get("status_error", false))
	)
	legend.setup(
		_gamepad_hints() if _ui_nav != null and _ui_nav.using_gamepad()
		else _keyboard_hints()
	)
	apply_rows(new_rows)
	_layout()


func apply_rows(new_rows: Array) -> void:
	var ids: Array[String] = []
	for raw_row in new_rows:
		if raw_row is Dictionary:
			ids.append(str((raw_row as Dictionary).get("id", "row:%d" % ids.size())))
	for id in _row_nodes.keys():
		if not ids.has(id):
			var removed: Dictionary = _row_nodes[id]
			(removed["root"] as Node).queue_free()
			_row_nodes.erase(id)

	var changed: Dictionary = {}
	_rows.clear()
	for i in new_rows.size():
		var row: Dictionary = new_rows[i] if new_rows[i] is Dictionary \
			else {"id": "row:%d" % i}
		var id := str(row.get("id", "row:%d" % i))
		var node: Dictionary = _row_nodes.get(id, {})
		var created := node.is_empty()
		if created:
			node = _create_row()
			node["root"].name = "Row_%s" % id.validate_node_name()
			_row_nodes[id] = node
		_rows.append(row)

		var side := int(row.get("side", 0))
		var last_side := int(node.get("last_side", side))
		if created:
			changed[id] = "new"
		elif side != last_side:
			changed[id] = "move"
		node["last_side"] = side

		var kind := str(row.get("kind", "keyboard"))
		(node["icon"] as TextureRect).texture = UiIcon.texture(
			"gamepad" if kind == "gamepad" else "keyboard"
		)
		var tone_index := int(row.get("tone_index", i))
		(node["icon"] as TextureRect).modulate = UiTokens.SIDE_TONES[
			posmod(tone_index, UiTokens.SIDE_TONES.size())
		]
		(node["ready"] as ReadyMark).set_checked(bool(row.get("ready", false)))
		(node["left_cue"] as Polygon2D).visible = side != -1
		(node["right_cue"] as Polygon2D).visible = side != 1
		_place_ready_badge(node, side)
		var name := str(row.get("name", ""))
		if bool(row.get("local", false)) and not name.is_empty():
			name = "YOU  " + name
		(node["name_label"] as Label).text = name

	_update_row_geometry()
	for i in _rows.size():
		var id := str(_rows[i].get("id", "row:%d" % i))
		var node: Dictionary = _row_nodes.get(id, {})
		if node.is_empty():
			continue
		if changed.get(id, "") == "move":
			_apply_device_x(node, i, true)
		elif changed.get(id, "") == "new":
			_apply_device_x(node, i, false)


func set_title(text: String) -> void:
	if title_label != null:
		title_label.text = text


func set_status(text: String, error := false) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.visible = not text.is_empty()
	status_label.theme_type_variation = &"SideStatusError" if error else &"SideStatus"


func set_overlay_mode(enabled: bool) -> void:
	overlay_mode = enabled
	_apply_overlay_mode()


func rows_count() -> int:
	return _rows.size()


func head_height() -> float:
	return UiTokens.SIDE_HEAD_H


func body_height() -> float:
	return _body_height


func device_size() -> float:
	return UiTokens.SIDE_DEVICE


func edge_inset() -> float:
	return UiTokens.SIDE_DEVICE_INSET


func design_scale_value() -> float:
	return design.scale.x


func row_device_x(row_id: String) -> float:
	var node: Dictionary = _row_nodes.get(row_id, {})
	if node.is_empty():
		return -1.0
	return (node["device"] as Control).position.x


func row_device_rect(row_id: String) -> Rect2:
	var node: Dictionary = _row_nodes.get(row_id, {})
	if node.is_empty():
		return Rect2()
	return (node["device"] as Control).get_global_rect()


func row_ready_visible(row_id: String) -> bool:
	var node: Dictionary = _row_nodes.get(row_id, {})
	return not node.is_empty() and (node["ready"] as ReadyMark).visible


func row_ready_x(row_id: String) -> float:
	var node: Dictionary = _row_nodes.get(row_id, {})
	return -1.0 if node.is_empty() else (node["ready"] as Control).position.x


func row_ready_y(row_id: String) -> float:
	var node: Dictionary = _row_nodes.get(row_id, {})
	return -1.0 if node.is_empty() else (node["ready"] as Control).position.y


func row_cue_visible(row_id: String, left: bool) -> bool:
	var node: Dictionary = _row_nodes.get(row_id, {})
	if node.is_empty():
		return false
	return bool((node["left_cue" if left else "right_cue"] as Polygon2D).visible)


func row_tone(row_id: String) -> Color:
	var node: Dictionary = _row_nodes.get(row_id, {})
	if node.is_empty():
		return Color.TRANSPARENT
	return (node["icon"] as TextureRect).modulate


func row_name_text(row_id: String) -> String:
	var node: Dictionary = _row_nodes.get(row_id, {})
	return "" if node.is_empty() else (node["name_label"] as Label).text


func status_text() -> String:
	return status_label.text


func _body_gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		UiTokens.SIDE_BODY,
		UiTokens.SIDE_BODY,
		UiTokens.SIDE_BODY_FADE,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 256
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


func _apply_overlay_mode() -> void:
	if photo == null:
		return
	photo.visible = not overlay_mode
	scrim.visible = not overlay_mode
	overlay.visible = overlay_mode


func _layout() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return

	stage.position = Vector2.ZERO
	photo.position = -view * UiTokens.SIDE_PHOTO_INSET
	photo.size = view * UiTokens.SIDE_PHOTO_SCALE
	photo.pivot_offset = photo.size * 0.5
	overlay.position = Vector2.ZERO
	overlay.size = view
	scrim.position = Vector2.ZERO
	scrim.size = view

	var design_scale := minf(
		view.x / UiTokens.DESIGN_SIZE.x,
		view.y / UiTokens.DESIGN_SIZE.y
	)
	design.scale = Vector2(design_scale, design_scale)
	design.position = (view - UiTokens.DESIGN_SIZE * design_scale) * 0.5
	design.size = UiTokens.DESIGN_SIZE
	design.pivot_offset = Vector2.ZERO

	_body_height = clampf(
		UiTokens.SIDE_BODY_RATIO * UiTokens.DESIGN_SIZE.y,
		UiTokens.SIDE_BODY_MIN,
		UiTokens.SIDE_BODY_MAX
	)
	var legend_height := maxf(24.0, legend.get_combined_minimum_size().y)
	var total_height := UiTokens.SIDE_HEAD_H + UiTokens.GAP + _body_height \
		+ UiTokens.SIDE_STATUS_GAP + UiTokens.SIDE_STATUS_H \
		+ UiTokens.SIDE_LEGEND_GAP + legend_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total_height) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total_height)

	head.position = Vector2.ZERO
	head.size = Vector2(UiTokens.PANEL_W, UiTokens.SIDE_HEAD_H)

	var body_position := Vector2(0.0, UiTokens.SIDE_HEAD_H + UiTokens.GAP)
	body.position = body_position
	body.size = Vector2(UiTokens.PANEL_W, _body_height)
	body_fill.position = Vector2.ZERO
	body_fill.size = body.size
	home_label.position = Vector2(UiTokens.SIDE_LABEL_OFFSET, 0.0)
	home_label.size = Vector2(UiTokens.SIDE_LABEL_BOX, _body_height)
	away_label.position = Vector2(
		UiTokens.PANEL_W - UiTokens.SIDE_LABEL_OFFSET - UiTokens.SIDE_LABEL_BOX,
		0.0
	)
	away_label.size = Vector2(UiTokens.SIDE_LABEL_BOX, _body_height)

	track.position = Vector2(0.0, UiTokens.SIDE_TRACK_INSET)
	track.size = Vector2(
		UiTokens.PANEL_W,
		_body_height - UiTokens.SIDE_TRACK_INSET * 2.0
	)

	var status_y := body_position.y + _body_height + UiTokens.SIDE_STATUS_GAP
	status_label.position = Vector2(0.0, status_y)
	status_label.size = Vector2(UiTokens.PANEL_W, UiTokens.SIDE_STATUS_H)
	legend.position = Vector2(
		0.0,
		status_y + UiTokens.SIDE_STATUS_H + UiTokens.SIDE_LEGEND_GAP
	)
	legend.size = Vector2(UiTokens.PANEL_W, legend_height)

	_update_row_geometry()
	for i in _rows.size():
		var id := str(_rows[i].get("id", "row:%d" % i))
		var node: Dictionary = _row_nodes.get(id, {})
		if not node.is_empty():
			_apply_device_x(node, i, false)


func _update_row_geometry() -> void:
	_row_geometry.clear()
	var count := _rows.size()
	if count == 0:
		return
	var row_gap := UiTokens.SIDE_ROW_GAP
	var row_height := (
		track.size.y - row_gap * float(count - 1)
	) / float(count)
	if _row_layout == "stack":
		var extra := 0.0
		if _show_names:
			extra = UiTokens.SIDE_NAME_GAP + UiTokens.SIDE_NAME_H
		var stack_height := UiTokens.SIDE_DEVICE + UiTokens.SIDE_ROW_PAD + extra
		if stack_height * float(count) + row_gap * float(count - 1) <= track.size.y:
			row_height = stack_height
	for i in count:
		var top := float(i) * (row_height + row_gap)
		_row_geometry.append({"top": top, "height": row_height})
		var id := str(_rows[i].get("id", "row:%d" % i))
		var node: Dictionary = _row_nodes.get(id, {})
		if node.is_empty():
			continue
		var root := node["root"] as Control
		root.position = Vector2(0.0, top)
		root.size = Vector2(track.size.x, row_height)
		var device := node["device"] as Control
		device.position.y = row_height * 0.5 - UiTokens.SIDE_DEVICE * 0.5
		var name_label := node["name_label"] as Label
		name_label.visible = _show_names and not name_label.text.is_empty() \
			and row_height >= UiTokens.SIDE_NAME_MIN_ROW


func _apply_device_x(node: Dictionary, index: int, animate: bool) -> void:
	if index < 0 or index >= _row_geometry.size():
		return
	var side := int(_rows[index].get("side", 0))
	var position_ratio := 0.0 if side < 0 else (1.0 if side > 0 else 0.5)
	var x := UiTokens.SIDE_DEVICE_INSET + (
		track.size.x - UiTokens.SIDE_DEVICE - UiTokens.SIDE_DEVICE_INSET * 2.0
	) * position_ratio
	var device := node["device"] as Control
	var current: Tween = node.get("tween")
	if current != null and current.is_valid():
		current.kill()
	node["tween"] = null
	if not animate:
		device.position.x = x
		return
	var tween := create_tween()
	tween.tween_property(device, "position:x", x, UiTokens.SIDE_DEVICE_MOVE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	node["tween"] = tween


func _place_ready_badge(node: Dictionary, side: int) -> void:
	var ready := node["ready"] as Control
	var x := (UiTokens.SIDE_DEVICE - UiTokens.SIDE_READY) * 0.5
	var y := (UiTokens.SIDE_DEVICE - UiTokens.SIDE_READY) * 0.5
	if side < 0:
		x = -UiTokens.SIDE_READY - UiTokens.SIDE_READY_SIDE_GAP
	elif side > 0:
		x = UiTokens.SIDE_DEVICE + UiTokens.SIDE_READY_SIDE_GAP
	else:
		y = UiTokens.SIDE_READY_LIFT
	ready.position = Vector2(x, y)


func _create_row() -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(root)

	var device := Control.new()
	device.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.size = Vector2(UiTokens.SIDE_DEVICE, UiTokens.SIDE_DEVICE)
	root.add_child(device)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(
		(UiTokens.SIDE_DEVICE - UiTokens.SIDE_GLYPH) * 0.5,
		(UiTokens.SIDE_DEVICE - UiTokens.SIDE_GLYPH) * 0.5
	)
	icon.size = Vector2(UiTokens.SIDE_GLYPH, UiTokens.SIDE_GLYPH)
	device.add_child(icon)

	var center_y := UiTokens.SIDE_DEVICE * 0.5
	var half_cue := UiTokens.SIDE_CUE_H * 0.5
	var left_base := -UiTokens.SIDE_CUE_GAP + UiTokens.SIDE_CUE_W
	var left_tip := -UiTokens.SIDE_CUE_GAP
	var left_cue := Polygon2D.new()
	left_cue.polygon = PackedVector2Array([
		Vector2(left_tip, center_y),
		Vector2(left_base, center_y - half_cue),
		Vector2(left_base, center_y + half_cue),
	])
	left_cue.color = UiTokens.SIDE_CUE
	device.add_child(left_cue)

	var right_tip := UiTokens.SIDE_DEVICE + UiTokens.SIDE_CUE_GAP
	var right_base := right_tip - UiTokens.SIDE_CUE_W
	var right_cue := Polygon2D.new()
	right_cue.polygon = PackedVector2Array([
		Vector2(right_base, center_y - half_cue),
		Vector2(right_tip, center_y),
		Vector2(right_base, center_y + half_cue),
	])
	right_cue.color = UiTokens.SIDE_CUE
	device.add_child(right_cue)

	var ready := ReadyMark.new()
	ready.size = Vector2(UiTokens.SIDE_READY, UiTokens.SIDE_READY)
	ready.position = Vector2(
		UiTokens.SIDE_DEVICE - UiTokens.SIDE_READY + UiTokens.SIDE_READY_INSET,
		UiTokens.SIDE_READY_LIFT
	)
	ready.visible = false
	device.add_child(ready)

	var name_label := Label.new()
	name_label.theme_type_variation = &"SidePlayerName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(
		UiTokens.SIDE_DEVICE * 0.5 - UiTokens.SIDE_NAME_W * 0.5,
		UiTokens.SIDE_DEVICE + UiTokens.SIDE_NAME_GAP
	)
	name_label.size = Vector2(UiTokens.SIDE_NAME_W, UiTokens.SIDE_NAME_H)
	name_label.visible = false
	device.add_child(name_label)

	return {
		"root": root,
		"device": device,
		"icon": icon,
		"left_cue": left_cue,
		"right_cue": right_cue,
		"ready": ready,
		"name_label": name_label,
		"last_side": 0,
		"tween": null,
	}


func _input_row() -> Dictionary:
	if _rows.is_empty():
		return {}
	if _input_mode == "local_player":
		for row in _rows:
			if bool(row.get("local", false)):
				return {"row": row}
		return {}
	if not _input_override.is_empty():
		return _gamepad_row(int(_input_override.get("device", -1)))
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return _gamepad_row(int(_ui_nav.last_device_id()))
	for row in _rows:
		if str(row.get("kind", "")) == "keyboard" and bool(row.get("local", true)):
			return {"row": row}
	return {}


func _gamepad_row(device_id: int) -> Dictionary:
	for row in _rows:
		if str(row.get("kind", "")) == "gamepad" \
				and int(row.get("device", -1)) == device_id \
				and bool(row.get("local", true)):
			return {"row": row}
	return {}


func _current_input() -> Dictionary:
	if not _input_override.is_empty():
		return _input_override
	if _ui_nav == null or not _ui_nav.last_input_gamepad():
		return {"kind": "keyboard", "device": 0}
	return {"kind": "gamepad", "device": int(_ui_nav.last_device_id())}


func _on_nav_moved(direction: Vector2i) -> void:
	# Gamepad directions arrive per device on moved_gamepad, so each player can
	# move their own row at the same time in 2P.
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return
	_emit_move(direction)


func _on_nav_gamepad_moved(direction: Vector2i, device: int) -> void:
	_input_override = {"kind": "gamepad", "device": device}
	_emit_move(direction)
	_input_override = {}


func _emit_move(direction: Vector2i) -> void:
	if direction != Vector2i.LEFT and direction != Vector2i.RIGHT:
		return
	var target := _input_row()
	if target.is_empty():
		return
	var row: Dictionary = target["row"]
	row_move_requested.emit(
		str(row.get("id", "")),
		-1 if direction == Vector2i.LEFT else 1,
		_current_input()
	)


func _on_nav_confirmed() -> void:
	var target := _input_row()
	if target.is_empty():
		return
	var row: Dictionary = target["row"]
	row_confirm_requested.emit(str(row.get("id", "")), _current_input())


func _on_nav_cancelled() -> void:
	var target := _input_row()
	if target.is_empty():
		back_requested.emit()
		return
	var row: Dictionary = target["row"]
	row_cancel_requested.emit(str(row.get("id", "")), _current_input())


func _on_device_changed(gamepad: bool) -> void:
	legend.setup(_gamepad_hints() if gamepad else _keyboard_hints())


func _keyboard_hints() -> Array:
	return [
		{"keys": ["←", "→"], "label": "move"},
		{"keys": ["ENTER"], "label": "ready"},
		{"keys": ["ESC"], "label": _back_label},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["D-PAD"], "label": "move"},
		{"keys": ["A"], "label": "ready"},
		{"keys": ["B"], "label": _back_label},
	]
