class_name KitSelectView
extends UiScreen
# Shared kit-select screen: two HOME/AWAY kit panels and a static 3D broadcast
# preview. Layout and input live here; adapters only supply a state snapshot and
# handle the requested actions.

signal side_move_requested(side: int, delta: int, input: Dictionary)
signal side_confirm_requested(side: int, input: Dictionary)
signal side_cancel_requested(side: int, input: Dictionary)
signal back_requested
signal retry_requested

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var kits: Control = $Design/PanelWrap/Kits
@onready var home_panel: KitPanel = $Design/PanelWrap/Kits/HomePanel
@onready var preview: KitPreview = $Design/PanelWrap/Kits/Preview
@onready var away_panel: KitPanel = $Design/PanelWrap/Kits/AwayPanel
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
var status_label: Label
var legend: UiLegend

var _ui_nav: Node
var _sides: Array = []
var _active_side := 0
var _editable_key := ""
var _error := false
var _status_text := ""
var _status_error := false
var _back_label := "back"


func _ready() -> void:
	_ui_nav = get_node_or_null("/root/UiNav")
	if _ui_nav != null:
		_ui_nav.moved.connect(_on_nav_moved)
		if _ui_nav.has_signal("moved_gamepad"):
			_ui_nav.moved_gamepad.connect(_on_nav_gamepad_moved)
		_ui_nav.confirmed.connect(_on_nav_confirmed)
		_ui_nav.cancelled.connect(_on_nav_cancelled)
		_ui_nav.tab_previous.connect(_on_nav_tab)
		_ui_nav.tab_next.connect(_on_nav_tab)
		_ui_nav.device_changed.connect(_on_device_changed)
	status_label = hints.status_label
	legend = hints.legend
	hints.setup(_keyboard_hints())
	theme_changed.connect(_layout)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	refresh_legend()
	_layout()


func setup(state: Dictionary, options: Dictionary = {}) -> void:
	_back_label = str(options.get("back_label", _back_label))
	_status_text = str(options.get("status", _status_text))
	_status_error = bool(options.get("status_error", _status_error))
	apply_state(state)
	_layout()


func apply_state(state: Dictionary) -> void:
	_sides = state.get("sides", [])
	_error = bool(state.get("error", false))
	if state.has("status"):
		_status_text = str(state.get("status", ""))
	if state.has("status_error"):
		_status_error = bool(state.get("status_error", false))
	set_status(_status_text, _status_error)

	var editable := _editable_sides()
	var editable_key := str(editable)
	var key_changed := editable_key != _editable_key
	_editable_key = editable_key
	if not editable.is_empty():
		_active_side = _first_unready(editable) if key_changed else _pick_active(editable)
	for side in 2:
		_apply_panel(side)
	preview.setup(state.get("preview", {}))
	refresh_legend()


func set_status(text: String, error := false) -> void:
	_status_text = text
	_status_error = error
	if hints == null:
		return
	hints.set_status(text, error)


func status_text() -> String:
	return _status_text


func sides() -> Array:
	return _sides


func side_state(side: int) -> Dictionary:
	return _side_state(side)


func active_side() -> int:
	return _active_side


func focus_for(side: int) -> bool:
	return _visible_focus(side)


func panel_rect(side: int) -> Rect2:
	var panel := _panel(side)
	return Rect2() if panel == null else panel.get_global_rect()


func preview_rect() -> Rect2:
	return preview.get_global_rect()


func design_scale_value() -> float:
	return design.scale.x


func _side_state(side: int) -> Dictionary:
	if side < 0 or side >= _sides.size() or not (_sides[side] is Dictionary):
		return {}
	return _sides[side]


func _panel(side: int) -> KitPanel:
	return home_panel if side == 0 else away_panel


func _apply_panel(side: int) -> void:
	var side_state := _side_state(side)
	var panel := _panel(side)
	if panel == null:
		return
	var data := side_state.duplicate(true)
	data["focus"] = _visible_focus(side)
	panel.setup(data)


func _visible_focus(side: int) -> bool:
	var side_state := _side_state(side)
	if side_state.is_empty():
		return false
	if not bool(side_state.get("live", false)) or bool(side_state.get("ready", false)):
		return false
	if _shares_device() and side != _active_side:
		return false
	return true


func _layout() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	layout_canvas()
	var hints_height := hints.height()
	var total := UiTokens.KIT_PANEL_H + UiTokens.HINTS_GAP + hints_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)
	kits.position = Vector2.ZERO
	kits.size = Vector2(UiTokens.PANEL_W, UiTokens.KIT_PANEL_H)

	var available := UiTokens.PANEL_W - UiTokens.GAP * 2.0
	var unit := available / (UiTokens.KIT_HOME_FRACTION + UiTokens.KIT_MIDDLE_FRACTION
		+ UiTokens.KIT_HOME_FRACTION)
	var home_width := unit * UiTokens.KIT_HOME_FRACTION
	var middle_width := maxf(UiTokens.KIT_MIDDLE_MIN, unit * UiTokens.KIT_MIDDLE_FRACTION)
	var away_width := unit * UiTokens.KIT_HOME_FRACTION
	home_panel.position = Vector2.ZERO
	home_panel.size = Vector2(home_width, UiTokens.KIT_PANEL_H)
	preview.position = Vector2(home_width + UiTokens.GAP, 0.0)
	preview.size = Vector2(middle_width, UiTokens.KIT_PANEL_H)
	away_panel.position = Vector2(home_width + UiTokens.GAP + middle_width + UiTokens.GAP, 0.0)
	away_panel.size = Vector2(away_width, UiTokens.KIT_PANEL_H)

	var status_y := UiTokens.KIT_PANEL_H + UiTokens.HINTS_GAP
	hints.position = Vector2(0.0, status_y)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)


func _editable_sides() -> Array:
	var result: Array = []
	for side in _sides.size():
		if _sides[side] is Dictionary and bool((_sides[side] as Dictionary).get("editable", false)):
			result.append(side)
	return result


func _pick_active(editable: Array) -> int:
	# A ready slot keeps its chooser permission but cannot be edited; when both
	# slots belong to one device (1P or a network player owning both sides), the
	# focus must move to the other slot after ready.
	if editable.has(_active_side) and not bool(_side_state(_active_side).get("ready", false)):
		return _active_side
	return _first_unready(editable)


func _first_unready(editable: Array) -> int:
	for raw_side in editable:
		var side := int(raw_side)
		if not bool(_side_state(side).get("ready", false)):
			return side
	return int(editable[0])


func _device_key(side: int) -> String:
	var side_state := _side_state(side)
	var device: Dictionary = side_state.get("device", {})
	return "%s:%d" % [str(device.get("kind", "keyboard")), int(device.get("device", -1))]


func _shares_device() -> bool:
	var editable := _editable_sides()
	if editable.size() < 2:
		return false
	var key := _device_key(int(editable[0]))
	for side in editable.slice(1):
		if _device_key(int(side)) != key:
			return false
	return true


func _input_side(input: Dictionary) -> int:
	var editable := _editable_sides()
	if editable.is_empty():
		return -1
	if editable.size() == 1:
		return int(editable[0])
	if _shares_device():
		return _active_side
	var kind := str(input.get("kind", "keyboard"))
	var device_id := int(input.get("device", -1))
	for raw_side in editable:
		var side := int(raw_side)
		var side_device: Dictionary = _side_state(side).get("device", {})
		if str(side_device.get("kind", "keyboard")) != kind:
			continue
		if kind == "keyboard" or int(side_device.get("device", -1)) == device_id:
			return side
	return -1


func _current_input() -> Dictionary:
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return {"kind": "gamepad", "device": int(_ui_nav.last_device_id())}
	return {"kind": "keyboard", "device": 0}


func _is_live(side: int) -> bool:
	var side_state := _side_state(side)
	return not side_state.is_empty() and bool(side_state.get("live", false)) \
		and not bool(side_state.get("ready", false))


func _handle_move(direction: Vector2i, input: Dictionary) -> void:
	if _error:
		return
	var side := _input_side(input)
	if side < 0 or not _is_live(side):
		return
	if direction == Vector2i.LEFT:
		side_move_requested.emit(side, -1, input)
	elif direction == Vector2i.RIGHT:
		side_move_requested.emit(side, 1, input)


func _on_nav_moved(direction: Vector2i) -> void:
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	if _ui_nav != null and _ui_nav.last_input_gamepad():
		return
	_handle_move(direction, {"kind": "keyboard", "device": 0})


func _on_nav_gamepad_moved(direction: Vector2i, device: int) -> void:
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	_handle_move(direction, {"kind": "gamepad", "device": device})


func _on_nav_confirmed() -> void:
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	if _error:
		retry_requested.emit()
		return
	var side := _input_side(_current_input())
	if side < 0:
		return
	side_confirm_requested.emit(side, _current_input())


func _on_nav_cancelled() -> void:
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	if _error:
		back_requested.emit()
		return
	var side := _input_side(_current_input())
	if side < 0:
		back_requested.emit()
		return
	side_cancel_requested.emit(side, _current_input())


func _on_nav_tab() -> void:
	if _ui_nav != null and _ui_nav.event_was_modal():
		return
	if _error or not _shares_device():
		return
	var editable := _editable_sides()
	if editable.size() < 2:
		return
	var index := editable.find(_active_side)
	if index < 0:
		index = 0
	_active_side = int(editable[(index + 1) % editable.size()])
	for side in 2:
		_apply_panel(side)


func _on_device_changed(_gamepad: bool) -> void:
	refresh_legend()


func refresh_legend() -> void:
	if hints == null:
		return
	hints.setup(_gamepad_hints() if _ui_nav != null and _ui_nav.using_gamepad()
		else _keyboard_hints())


func _keyboard_hints() -> Array:
	if _error:
		return [
			{"keys": ["ENTER"], "label": "retry"},
			{"keys": ["ESC"], "label": _back_label},
		]
	var hints := [
		{"keys": ["в†ђ", "в†’"], "label": "kit"},
		{"keys": ["ENTER"], "label": "ready"},
		{"keys": ["ESC"], "label": _back_label},
	]
	if _shares_device():
		hints.insert(2, {"keys": ["TAB"], "label": "panel"})
	return hints


func _gamepad_hints() -> Array:
	if _error:
		return [
			{"keys": ["A"], "label": "retry"},
			{"keys": ["B"], "label": _back_label},
		]
	var hints := [
		{"keys": ["D-PAD"], "label": "kit"},
		{"keys": ["A"], "label": "ready"},
		{"keys": ["B"], "label": _back_label},
	]
	if _shares_device():
		hints.insert(2, {"keys": ["LB/RB"], "label": "panel"})
	return hints


