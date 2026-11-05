class_name UiFormRow
extends Button
# Focusable form row used by the LAN setup screens: label on the left, value
# and hint/error on the right. Focus is the selection (dark inversion + rail
# hidden), mouse hover focuses, a click opens the on-screen keyboard.

@export var field_title := ""
@export var field_value := ""
@export var field_hint := ""
@export var field_error := ""

var _bg: Panel
var _rail: ColorRect
var _title: Label
var _value: Label
var _hint: Label
var _error: Label
var _normal_box: StyleBoxFlat
var _focused_box: StyleBoxFlat


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = UiTokens.FORM_ROW_H
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build()
	_init_boxes()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	_apply_state()
	call_deferred("_layout_content")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_layout_content()
		_apply_state()


func set_value(value: String) -> void:
	field_value = value
	if _value != null:
		_value.text = value
		_layout_content()


func set_hint(hint: String) -> void:
	field_hint = hint
	_layout_content()


func set_error(error: String) -> void:
	field_error = error
	_layout_content()


func value_text() -> String:
	return field_value


func error_text() -> String:
	return field_error


func _build() -> void:
	_bg = Panel.new()
	_bg.name = "Bg"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_rail = ColorRect.new()
	_rail.name = "Rail"
	_rail.color = UiTokens.RAIL
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)

	_title = Label.new()
	_title.name = "Title"
	_title.text = field_title
	_title.theme_type_variation = &"FormLabel"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_value = Label.new()
	_value.name = "Value"
	_value.text = field_value
	_value.theme_type_variation = &"FormValue"
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_value)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = field_hint
	_hint.theme_type_variation = &"FormHint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_error = Label.new()
	_error.name = "Error"
	_error.text = field_error
	_error.theme_type_variation = &"FormError"
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_error.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_error)


func _init_boxes() -> void:
	_normal_box = StyleBoxFlat.new()
	_normal_box.bg_color = UiTokens.FORM_ROW
	_normal_box.border_color = UiTokens.FORM_ROW_BORDER
	_normal_box.set_border_width_all(1)
	_normal_box.anti_aliasing = true

	_focused_box = StyleBoxFlat.new()
	_focused_box.bg_color = UiTokens.FORM_ROW_FOCUS
	_focused_box.anti_aliasing = true


func _layout_content() -> void:
	if _bg == null or size.x <= 0.0:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)

	var pad := 24.0
	var label_width := maxf(0.0, size.x * (1.0 - UiTokens.FORM_VALUE_W) - pad * 2.0)
	_title.position = Vector2(pad, 0.0)
	_title.size = Vector2(label_width, size.y)

	var value_x := pad + label_width
	var value_width := size.x - value_x - pad
	var has_detail := not field_hint.is_empty() or not field_error.is_empty()
	var value_height := 30.0
	var value_y := (size.y - value_height) * 0.5 if not has_detail else 16.0
	_value.position = Vector2(value_x, value_y)
	_value.size = Vector2(value_width, value_height)

	_hint.position = Vector2(value_x, value_y + value_height + 2.0)
	_hint.size = Vector2(value_width, UiTokens.FORM_HINT_H)
	_hint.visible = field_error.is_empty() and not field_hint.is_empty()
	_hint.text = field_hint

	_error.position = Vector2(value_x, value_y + value_height + 2.0)
	_error.size = Vector2(value_width, UiTokens.FORM_ERROR_H)
	_error.visible = not field_error.is_empty()
	_error.text = field_error


func _apply_state() -> void:
	if _bg == null:
		return
	var selected := has_focus()
	_bg.add_theme_stylebox_override(&"panel", _focused_box if selected else _normal_box)
	_rail.visible = not selected
	var title_color := UiTokens.FOCUS_MARK if selected else UiTokens.INK
	var value_color := UiTokens.FOCUS_INK if selected else UiTokens.INK
	var hint_color := UiTokens.FOCUS_INK_2 if selected else UiTokens.FORM_HINT
	_title.add_theme_color_override(&"font_color", title_color)
	_value.add_theme_color_override(&"font_color", value_color)
	_hint.add_theme_color_override(&"font_color", hint_color)
	_error.add_theme_color_override(&"font_color", UiTokens.ERROR_PINK)
