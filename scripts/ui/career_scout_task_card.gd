class_name CareerScoutTaskCard
extends Control
# Prototype career/scouting/ScoutTaskCard.svelte: one tile of the TASKS grid —
# the scout's name, the task title ("Network in Spain" / "Report request" /
# "Add a new task"), the criteria line and the found/days-left chips.

signal pressed(scout_id: String)

const PAD := 18.0
const MIN_H := 210.0
const OWNER_H := 20.0
const TITLE_H := 54.0
const SUB_H := 42.0
const CHIP_H := 22.0

var _scout_id := ""
var _selected := false

var _bg: Panel
var _rail: ColorRect
var _owner: Label
var _title: Label
var _sub: Label
var _chip_a: Label
var _chip_b: Label
var _normal_box: StyleBoxFlat
var _focus_box: StyleBoxFlat


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = MIN_H
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_normal_box = StyleBoxFlat.new()
	_normal_box.bg_color = UiTokens.TILE
	_normal_box.shadow_color = UiTokens.SHADOW
	_normal_box.shadow_size = 32
	_normal_box.shadow_offset = Vector2(0.0, 24.0)
	_normal_box.anti_aliasing = true
	_focus_box = StyleBoxFlat.new()
	_focus_box.bg_color = UiTokens.FOCUS_FILL
	_focus_box.shadow_color = UiTokens.SHADOW_SELECTED
	_focus_box.shadow_size = 32
	_focus_box.shadow_offset = Vector2(0.0, 24.0)
	_focus_box.anti_aliasing = true
	_bg = Panel.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_rail = ColorRect.new()
	_rail.color = UiTokens.RAIL
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)
	_owner = _make_label(UiTheme.inter(600), 16)
	_owner.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_title = _make_label(UiTheme.barlow(700), 24)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = 2
	_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_sub = _make_label(UiTheme.inter(500), 16)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.max_lines_visible = 2
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_chip_a = _make_label(UiTheme.inter(600), 16)
	_chip_b = _make_label(UiTheme.inter(600), 16)
	_apply_state()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	call_deferred("_layout_content")


# `found`/`days` are "" when the card has no such chip.
func setup(scout: Dictionary, title: String, subtitle: String,
		found: String, days: String) -> void:
	_scout_id = str(scout.get("id", ""))
	if _owner == null:
		return
	_owner.text = str(scout.get("name", "")).to_upper()
	_title.text = title
	_sub.text = subtitle
	_chip_a.text = found
	_chip_a.visible = not found.is_empty()
	_chip_b.text = days
	_chip_b.visible = not days.is_empty()
	_layout_content()
	_apply_state()


func scout_id() -> String:
	return _scout_id


func set_selected(value: bool) -> void:
	_selected = value
	_apply_state()


func _make_label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label


func _layout_content() -> void:
	if _bg == null:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)
	var inner := maxf(40.0, size.x - PAD * 2.0)
	_owner.position = Vector2(PAD, 14.0)
	_owner.size = Vector2(inner, OWNER_H)
	_title.position = Vector2(PAD, 38.0)
	_title.size = Vector2(inner, TITLE_H)
	_sub.position = Vector2(PAD, 38.0 + TITLE_H)
	_sub.size = Vector2(inner, SUB_H)
	var chip_y := size.y - 16.0 - CHIP_H
	_chip_a.position = Vector2(PAD, chip_y)
	_chip_a.size = Vector2(inner * 0.5, CHIP_H)
	_chip_b.position = Vector2(PAD + inner * 0.5, chip_y)
	_chip_b.size = Vector2(inner * 0.5, CHIP_H)


func _apply_state() -> void:
	if _bg == null:
		return
	var focused := has_focus()
	_bg.add_theme_stylebox_override(&"panel", _focus_box if focused else _normal_box)
	_rail.visible = _selected or not focused
	_owner.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
	_title.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if focused else UiTokens.INK)
	_sub.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
	for chip in [_chip_a, _chip_b]:
		chip.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			pressed.emit(_scout_id)
			accept_event()


func activate() -> void:
	pressed.emit(_scout_id)
