class_name HubCommandCell
extends Button
# One prototype .command__cell: light tile in the hub, inverted when selected.
# Mouse hover selects it too, so the keyboard/gamepad focus and the pointer
# never point at different actions.

signal selected

var command := ""

var _bg: Panel
var _label: Label
var _glyph: TextureRect
var _normal_box: StyleBoxFlat
var _selected_box: StyleBoxFlat
var _selected := false
var _tween: Tween


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build()
	_init_boxes()
	resized.connect(_layout_content)
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	mouse_entered.connect(_on_mouse_entered)
	_apply_state(false)
	call_deferred("_layout_content")


func setup(command_id: String, label_text: String, glyph_name: String,
		enabled := true) -> void:
	command = command_id
	_label.text = label_text.to_upper()
	_glyph.texture = UiIcon.texture(glyph_name)
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_apply_state(false)
	_layout_content()


func set_label(label_text: String) -> void:
	_label.text = label_text.to_upper()


func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_apply_state(_selected and enabled)


func label_text() -> String:
	return _label.text if _label != null else ""


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_apply_state(value)


func is_selected() -> bool:
	return _selected


func _build() -> void:
	_bg = Panel.new()
	_bg.name = "Bg"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_label = Label.new()
	_label.name = "Label"
	_label.theme_type_variation = &"HubCommandLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph)


func _init_boxes() -> void:
	_normal_box = StyleBoxFlat.new()
	_normal_box.bg_color = UiTokens.TILE
	_normal_box.shadow_color = UiTokens.SHADOW
	_normal_box.shadow_size = 18
	_normal_box.shadow_offset = Vector2(0.0, 18.0)
	_selected_box = StyleBoxFlat.new()
	_selected_box.bg_color = UiTokens.FOCUS_FILL
	_selected_box.shadow_color = UiTokens.SHADOW_SELECTED
	_selected_box.shadow_size = 24
	_selected_box.shadow_offset = Vector2(0.0, 24.0)


func _apply_state(selected_now: bool) -> void:
	_selected = selected_now
	var box := _selected_box if selected_now else _normal_box
	if disabled:
		box = _normal_box
	_bg.add_theme_stylebox_override(&"panel", box)
	_label.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if selected_now else UiTokens.INK)
	_glyph.modulate = UiTokens.RAIL if selected_now else Color(UiTokens.INK, 0.72)
	modulate = Color(1.0, 1.0, 1.0, 0.55) if disabled else Color.WHITE
	var target_scale := UiTokens.SELECTED_SCALE if selected_now else 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_inside_tree():
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2(target_scale, target_scale),
			UiTokens.TILE_MOVE)
	else:
		scale = Vector2(target_scale, target_scale)
	queue_redraw()


func _layout_content() -> void:
	if _bg == null:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	var label_h := 24.0
	var glyph_h := UiTokens.HUB_COMMAND_GLYPH
	var total := label_h + UiTokens.HUB_COMMAND_INNER_GAP + glyph_h
	var top := (size.y - total) * 0.5
	_label.position = Vector2(0.0, top)
	_label.size = Vector2(size.x, label_h)
	_glyph.position = Vector2((size.x - glyph_h) * 0.5, top + label_h + UiTokens.HUB_COMMAND_INNER_GAP)
	_glyph.size = Vector2(glyph_h, glyph_h)


func _on_focus_changed() -> void:
	_apply_state(has_focus())


func _on_mouse_entered() -> void:
	if disabled:
		return
	if not has_focus():
		grab_focus()
	selected.emit()
