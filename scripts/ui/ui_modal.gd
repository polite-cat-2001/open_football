class_name UiModal
extends Control
# Confirmation modal ported from the prototype's warning plate: a full-viewport
# dark scrim, a light message block and full-width action rows (navy + lime for
# the focused row, white for the rest, with its shortcut key shown on the left).
#
# Reuse: add to a screen ROOT (not to the 1920x1080 Design canvas) so the scrim
# covers the whole viewport, then call open(message, actions). Actions are
# {id, label, key}; key is drawn as a keycap only on the focused row.

signal action_chosen(id: String)
signal closed

const PANEL_W := 900.0
const PAD := 44.0
const ROW_H := 46.0
const BODY := Color(0.740, 0.730, 0.800, 0.97)
const DIVIDER := Color(0.910, 0.910, 0.945, 1.0)
const SCRIM := Color(0.0, 0.0, 0.0, 0.72)


class ModalAction extends Button:
	var id := ""
	var key := ""
	var _bg: Panel
	var _cap: PanelContainer
	var _cap_label: Label
	var _label: Label
	var _normal_box: StyleBoxFlat
	var _focus_box: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_build()
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func setup(action_id: String, label_text: String, key_text: String) -> void:
		id = action_id
		key = key_text
		if _label != null:
			_label.text = label_text
			_cap_label.text = key_text
		_apply_state()

	func _build() -> void:
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_cap = PanelContainer.new()
		_cap.theme_type_variation = &"KbdBox"
		_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cap_label = Label.new()
		_cap_label.theme_type_variation = &"Kbd"
		_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cap.add_child(_cap_label)
		add_child(_cap)
		_label = Label.new()
		_label.add_theme_font_override(&"font", UiTheme.inter(600))
		_label.add_theme_font_size_override(&"font_size", 26)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		_normal_box = _make_box(UiTokens.TILE, UiTokens.SHADOW, 0, Vector2.ZERO)
		_focus_box = _make_box(UiTokens.FOCUS_FILL, UiTokens.SHADOW, 0, Vector2.ZERO)

	func _make_box(fill: Color, shadow: Color, blur: int, offset: Vector2) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.shadow_color = shadow
		box.shadow_size = blur
		box.shadow_offset = offset
		return box

	func _layout_content() -> void:
		if _bg == null:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		var focused := has_focus()
		_cap.visible = focused and not key.is_empty()
		var cap_width := 30.0
		if _cap.visible:
			var font := _cap_label.get_theme_font(&"font")
			var font_size := _cap_label.get_theme_font_size(&"font_size")
			cap_width = maxf(cap_width, font.get_string_size(
				_cap_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0)
		var cap_size := Vector2(cap_width, 22.0)
		_cap.position = Vector2(18.0, (size.y - cap_size.y) * 0.5)
		_cap.size = cap_size
		var text_x := 18.0 + cap_width + 8.0 if _cap.visible else 20.0
		_label.position = Vector2(text_x, 0.0)
		_label.size = Vector2(size.x - text_x - 20.0, size.y)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus_box if focused else _normal_box)
		_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
		_layout_content()


var _scrim: ColorRect
var _panel: PanelContainer
var _message: RichTextLabel
var _divider: ColorRect
var _actions: VBoxContainer
var _rows: Array[ModalAction] = []
var _panel_style: StyleBoxFlat
var _open := false
var _tween: Tween


func _ready() -> void:
	visible = false
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)

	_panel = PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = BODY
	_panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_panel_style.shadow_size = 40
	_panel_style.shadow_offset = Vector2(0.0, 24.0)
	_panel.add_theme_stylebox_override(&"panel", _panel_style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	_panel.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", int(PAD))
	margin.add_theme_constant_override(&"margin_right", int(PAD))
	margin.add_theme_constant_override(&"margin_top", 40)
	margin.add_theme_constant_override(&"margin_bottom", 36)
	box.add_child(margin)

	_message = RichTextLabel.new()
	_message.fit_content = true
	_message.scroll_active = false
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_override(&"normal_font", UiTheme.inter(600))
	_message.add_theme_font_size_override(&"normal_font_size", 28)
	_message.add_theme_color_override(&"default_color", UiTokens.INK)
	_message.add_theme_constant_override(&"line_separation", 10)
	margin.add_child(_message)

	_divider = ColorRect.new()
	_divider.color = DIVIDER
	_divider.custom_minimum_size = Vector2(0.0, 4.0)
	box.add_child(_divider)

	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override(&"separation", 0)
	box.add_child(_actions)


func open(message: String, actions: Array) -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for action in actions:
		var row := ModalAction.new()
		row.custom_minimum_size = Vector2(0.0, ROW_H)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_on_row_pressed.bind(String(action.get("id", ""))))
		_actions.add_child(row)
		row.setup(String(action.get("id", "")), String(action.get("label", "")),
			String(action.get("key", "")))
		_rows.append(row)
	_message.text = message
	if _tween != null:
		_tween.kill()
	_open = true
	visible = true
	move_to_front()
	_layout()
	focus_first()
	call_deferred("_layout")
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	_scrim.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.24)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.24)
	_tween.tween_property(_scrim, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not _open:
		if _tween != null:
			_tween.kill()
		visible = false
		return
	_open = false
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus != null:
		focus.release_focus()
	closed.emit()
	if _tween != null:
		_tween.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	_tween.tween_property(_panel, "scale", Vector2(0.96, 0.96), 0.15)
	_tween.tween_property(_scrim, "modulate:a", 0.0, 0.15)
	_tween.chain().tween_callback(func() -> void: visible = false)


func is_open() -> bool:
	return _open


func focus_first() -> void:
	if not _rows.is_empty():
		_rows[0].grab_focus()


func move_focus(direction: Vector2i) -> void:
	if _rows.is_empty() or (direction != Vector2i.UP and direction != Vector2i.DOWN):
		return
	var focus := get_viewport().gui_get_focus_owner()
	var index := _rows.find(focus)
	if index == -1:
		_rows[0].grab_focus()
		return
	var step := -1 if direction == Vector2i.UP else 1
	_rows[clampi(index + step, 0, _rows.size() - 1)].grab_focus()


func activate_focused() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var index := _rows.find(focus)
	if index >= 0:
		_rows[index].pressed.emit()


func _on_row_pressed(id: String) -> void:
	action_chosen.emit(id)


func _layout() -> void:
	if _scrim == null:
		return
	_scrim.position = Vector2.ZERO
	_scrim.size = size
	if _message == null or size.x <= 0.0:
		return
	_panel.custom_minimum_size.x = PANEL_W
	_message.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0, 0.0)
	var panel_height := maxf(_panel.get_combined_minimum_size().y, ROW_H * 2.0)
	_panel.size = Vector2(PANEL_W, panel_height)
	_panel.position = ((size - _panel.size) * 0.5).round()
	_panel.pivot_offset = _panel.size * 0.5
