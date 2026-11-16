class_name CareerScoutTaskEditor
extends Control
# Prototype career/scouting/ScoutTaskEditor.svelte: the task page of the
# network — four big cells (role, traits, contract, age) that edit the criteria
# of an existing network, with the live preview panel on the right (found/days,
# the pitch zone of the draft role, the region/country and the criteria line).
#
# The host owns the draft and the stepping: this screen only reports the cell
# under confirm and keeps its display in sync through setup().

signal field_selected(id: String)
signal reports_requested

const GAP := 10.0
const PAD := 16.0
const CELL_H := 210.0
const CELL_IDS := ["role", "traits", "contract", "age"]
const HINTS := {
	"role": "A — CHOOSE ROLE",
	"traits": "NOT EDITABLE YET",
	"contract": "YEARS",
	"age": "AGE",
}


# One big criteria cell: label, the current value and the bottom hint.
class Cell extends Button:
	var id := ""
	var enabled := true
	var editing := false
	var _bg: Panel
	var _rail: ColorRect
	var _label: Label
	var _value: Label
	var _hint: Label
	var _normal: StyleBoxFlat
	var _focus: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_normal = StyleBoxFlat.new()
		_normal.bg_color = UiTokens.TILE
		_normal.shadow_color = UiTokens.SHADOW
		_normal.shadow_size = 32
		_normal.shadow_offset = Vector2(0.0, 24.0)
		_focus = StyleBoxFlat.new()
		_focus.bg_color = UiTokens.FOCUS_FILL
		_focus.shadow_color = UiTokens.SHADOW_SELECTED
		_focus.shadow_size = 32
		_focus.shadow_offset = Vector2(0.0, 24.0)
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_rail = ColorRect.new()
		_rail.color = UiTokens.RAIL
		_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rail)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_override(&"font", UiTheme.inter(600))
		_label.add_theme_font_size_override(&"font_size", 16)
		add_child(_label)
		_value = Label.new()
		_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_value.clip_text = true
		_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_value.add_theme_font_override(&"font", UiTheme.barlow(800))
		_value.add_theme_font_size_override(&"font_size", 40)
		add_child(_value)
		_hint = Label.new()
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.clip_text = true
		_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_hint.add_theme_font_override(&"font", UiTheme.inter(600))
		_hint.add_theme_font_size_override(&"font_size", 16)
		add_child(_hint)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func setup(cell_id: String, title: String, value_text: String,
			hint: String, disabled := false) -> void:
		id = cell_id
		enabled = not disabled
		_label.text = title
		_value.text = value_text
		_hint.text = hint
		_apply_state()
		_layout_content()

	func _layout_content() -> void:
		_bg.position = Vector2.ZERO
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		var inner := maxf(0.0, size.x - PAD * 2.0)
		_label.position = Vector2(PAD, 16.0)
		_label.size = Vector2(inner, 20.0)
		_value.position = Vector2(PAD, 44.0)
		_value.size = Vector2(inner, 52.0)
		_hint.position = Vector2(PAD, size.y - 16.0 - 20.0)
		_hint.size = Vector2(inner, 20.0)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		var box: StyleBoxFlat = (_focus if focused else _normal).duplicate() as StyleBoxFlat
		if editing:
			box.border_color = UiTokens.INK if not focused else UiTokens.FOCUS_MARK
			box.border_width_bottom = 2
		_bg.add_theme_stylebox_override(&"panel", box)
		_rail.visible = focused
		var label_ink := UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
		var value_ink := UiTokens.FOCUS_MARK if focused else UiTokens.INK
		if not enabled:
			label_ink = Color(UiTokens.INK_2, 0.6)
			value_ink = Color(UiTokens.INK_2, 0.6)
		_label.add_theme_color_override(&"font_color", label_ink)
		_value.add_theme_color_override(&"font_color", value_ink)
		_hint.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)


var _draft: Dictionary = {}
var _field := ""
var _range_row := "min"

var _cells: Array[Cell] = []
var _grid: GridContainer
var _panel: Panel
var _title: Label
var _found: Label
var _days: Label
var _pitch: CareerScoutTaskPanel.Pitch
var _rows: VBoxContainer
var _scout_value: Label
var _region_value: Label
var _country_value: Label
var _criteria: Label
var _action: CareerScoutTaskPanel.ActionButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	resized.connect(_layout)
	call_deferred("_layout")


func setup(draft: Dictionary, field: String, range_row: String,
		scout_name: String, task: Dictionary, criteria_line: String) -> void:
	_draft = draft
	_field = field
	_range_row = range_row
	if _grid == null:
		return
	var contract_hint := HINTS["contract"]
	var age_hint := HINTS["age"]
	if field == "contract":
		contract_hint = _editing_hint()
	elif field == "age":
		age_hint = _editing_hint()
	_cells[0].setup("role", "ROLE", CareerScoutTaskPanel.role_label(
		str(draft.get("role", ""))),
		"A — CHOOSE ROLE" if _field != "role" else _editing_hint())
	_cells[0].editing = _field == "role"
	_cells[1].setup("traits", "TRAITS", "NONE", HINTS["traits"], true)
	_cells[2].setup("contract", "CONTRACT", CareerScoutTaskPanel.range_label(
		draft.get("contract_min"), draft.get("contract_max")), contract_hint)
	_cells[2].editing = _field == "contract"
	_cells[3].setup("age", "AGE", CareerScoutTaskPanel.range_label(
		draft.get("age_min"), draft.get("age_max")), age_hint)
	_cells[3].editing = _field == "age"
	for cell in _cells:
		cell._apply_state()

	_found.text = str(int(task.get("found_count", 0))) if not task.is_empty() else "0"
	_days.text = str(int(task.get("days_worked", 0))) if not task.is_empty() else "0"
	_pitch.zone = CareerScoutTaskPanel.pitch_zone(str(draft.get("role", "")))
	_pitch.queue_redraw()
	_scout_value.text = scout_name if not scout_name.is_empty() else "—"
	_region_value.text = str(task.get("region_name", ""))
	_country_value.text = str(task.get("country_name", ""))
	if _region_value.text.is_empty():
		_region_value.text = "—"
	if _country_value.text.is_empty():
		_country_value.text = "—"
	_criteria.text = criteria_line
	_criteria.visible = not criteria_line.is_empty()


func cell_ids() -> Array:
	var ids: Array = []
	for cell in _cells:
		ids.append(cell.id)
	return ids


func focusables() -> Array[Control]:
	var list: Array[Control] = []
	for cell in _cells:
		list.append(cell)
	list.append(_action)
	return list


func _editing_hint() -> String:
	return "← → VALUE · ↑ ↓ %s" % ("MIN" if _range_row == "min" else "MAX")


func _build() -> void:
	_grid = GridContainer.new()
	_grid.name = "Cells"
	_grid.columns = 2
	_grid.add_theme_constant_override(&"h_separation", int(GAP))
	_grid.add_theme_constant_override(&"v_separation", int(GAP))
	add_child(_grid)
	for cell_id in CELL_IDS:
		var cell := Cell.new()
		cell.custom_minimum_size = Vector2(240.0, CELL_H)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grid.add_child(cell)
		cell.pressed.connect(func() -> void: field_selected.emit(cell.id))
		_cells.append(cell)

	_panel = Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)

	_title = _label(UiTheme.barlow(700), 24)
	_title.text = "SCOUTING NETWORK"
	_panel.add_child(_title)
	var stats := HBoxContainer.new()
	_panel.add_child(stats)
	stats.add_theme_constant_override(&"separation", 16)
	_found = _stat_pair(stats, "PLAYERS FOUND")
	_days = _stat_pair(stats, "DAYS SCOUTING")

	_pitch = CareerScoutTaskPanel.Pitch.new()
	_pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_pitch)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	_panel.add_child(_rows)
	_scout_value = _row("SCOUT")
	_region_value = _row("REGION")
	_country_value = _row("COUNTRY")
	_criteria = _label(UiTheme.inter(400), 16)
	_criteria.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_criteria.max_lines_visible = 3
	_criteria.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_panel.add_child(_criteria)

	_action = CareerScoutTaskPanel.ActionButton.new()
	_action.pressed.connect(func() -> void: reports_requested.emit())
	_panel.add_child(_action)


func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", UiTokens.INK)
	return label


func _stat_pair(parent: Control, title: String) -> Label:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	parent.add_child(column)
	var label := _label(UiTheme.inter(500), 16)
	label.text = title
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	column.add_child(label)
	var value := _label(UiTheme.barlow(700), 22)
	value.text = "0"
	column.add_child(value)
	return value


func _row(title: String) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 26.0
	row.add_theme_constant_override(&"separation", 12)
	_rows.add_child(row)
	var label := _label(UiTheme.inter(500), 16)
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	row.add_child(label)
	var value := _label(UiTheme.inter(600), 16)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value


func _layout() -> void:
	if _grid == null or size.x <= 0.0:
		return
	var left_w := floorf((size.x - GAP) * 1.42 / 2.30)
	var right_w := maxf(0.0, size.x - left_w - GAP)
	_grid.position = Vector2.ZERO
	_grid.size = Vector2(left_w, size.y)
	var cell_w := floorf((left_w - GAP) * 0.5)
	var cell_h := floorf((size.y - GAP) * 0.5)
	for cell in _cells:
		cell.custom_minimum_size = Vector2(cell_w, cell_h)

	_panel.position = Vector2(left_w + GAP, 0.0)
	_panel.size = Vector2(right_w, size.y)
	var inner := maxf(0.0, right_w - PAD * 2.0)
	_title.position = Vector2(PAD, 10.0)
	_title.size = Vector2(inner, 28.0)
	var stats_top := 44.0
	var stats := _panel.get_child(1) as Control
	if stats != null:
		stats.position = Vector2(PAD, stats_top)
		stats.size = Vector2(inner, 46.0)
	_pitch.position = Vector2(PAD, stats_top + 54.0)
	_pitch.size = Vector2(inner, 150.0)
	_rows.position = Vector2(PAD, stats_top + 214.0)
	_rows.size = Vector2(inner, 3.0 * 26.0 + 4.0)
	_criteria.position = Vector2(PAD, stats_top + 300.0)
	_criteria.size = Vector2(inner, 44.0)
	_action.position = Vector2(PAD, maxf(stats_top + 350.0,
		size.y - PAD - 46.0))
	_action.size = Vector2(inner, 46.0)
