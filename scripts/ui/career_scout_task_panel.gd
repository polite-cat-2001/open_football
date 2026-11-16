class_name CareerScoutTaskPanel
extends Control
# Prototype career/scouting/ScoutTaskPanel.svelte: the right-hand card of the
# TASKS tab — the network totals, the pitch diagram with the scouted zone, the
# task's region/country/criteria and the "open scout reports" action.
#
# Also owns the task formatting helpers and the Pitch diagram, reused by the
# task editor (CareerScoutTaskPanel.Pitch).

signal reports_requested

const PAD := 16.0
const ROW_H := 26.0
const PITCH_H := 150.0

const ROLE_LABELS := {
	"": "ANY POSITION",
	"GK": "GOALKEEPER",
	"DEF": "DEFENDER",
	"MID": "MIDFIELDER",
	"FWD": "FORWARD",
}
const ROLE_GROUPS := ["", "GK", "DEF", "MID", "FWD"]


# The prototype's half-pitch diagram: stripes, halfway line, centre circle,
# both boxes and the highlighted zone of the scouted role.
class Pitch extends Control:
	var zone := "all"

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.INK, 0.055), true)
		var stripe := size.x / 8.0
		for index in 8:
			if index % 2 == 1:
				draw_rect(Rect2(index * stripe, 0.0, stripe, size.y),
					Color(UiTokens.INK, 0.03), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.INK, 0.16), false, 2.0)
		draw_line(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5),
			Color(UiTokens.INK, 0.20), 2.0)
		draw_circle(Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.12,
			Color(UiTokens.INK, 0.20), false, 2.0)
		for top in [true, false]:
			var box_h := size.y * 0.16
			var y := 0.0 if top else size.y - box_h
			draw_rect(Rect2(size.x * 0.27, y, size.x * 0.46, box_h),
				Color(UiTokens.INK, 0.20), false, 2.0)
		_draw_zone()

	func _draw_zone() -> void:
		var rect := Rect2()
		match zone:
			"all":
				rect = Rect2(0.0, size.y * 0.08, size.x, size.y * 0.84)
			"fwd":
				rect = Rect2(size.x * 0.1, size.y * 0.06, size.x * 0.8, size.y * 0.20)
			"mid":
				rect = Rect2(size.x * 0.1, size.y * 0.40, size.x * 0.8, size.y * 0.20)
			"def":
				rect = Rect2(size.x * 0.1, size.y - 0.06 * size.y - 0.20 * size.y,
					size.x * 0.8, size.y * 0.20)
			"gk":
				rect = Rect2(size.x * 0.36, size.y - 0.04 * size.y - 0.10 * size.y,
					size.x * 0.28, size.y * 0.10)
		if rect.size.x <= 0.0:
			return
		draw_rect(rect, Color(UiTokens.INK, 0.04 if zone == "all" else 0.08), true)
		draw_rect(rect, Color(UiTokens.INK, 0.16 if zone == "all" else 0.22), false, 2.0)


# One bottom action row: label on the left, the confirm key on the right.
class ActionButton extends Button:
	var _bg: Panel
	var _label: Label
	var _key: Label
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
		_normal.bg_color = Color(UiTokens.INK, 0.06)
		_normal.anti_aliasing = true
		_focus = StyleBoxFlat.new()
		_focus.bg_color = UiTokens.FOCUS_FILL
		_focus.anti_aliasing = true
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_label = Label.new()
		_label.text = "OPEN SCOUT REPORTS"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.add_theme_font_override(&"font", UiTheme.inter(600))
		_label.add_theme_font_size_override(&"font_size", 16)
		add_child(_label)
		_key = Label.new()
		_key.text = "A"
		_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_key.add_theme_font_override(&"font", UiTheme.inter(600))
		_key.add_theme_font_size_override(&"font_size", 16)
		add_child(_key)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func set_copy(text: String) -> void:
		_label.text = text
		_layout_content()

	func _layout_content() -> void:
		_bg.position = Vector2.ZERO
		_bg.size = size
		var key_w := 26.0
		_key.position = Vector2(size.x - 14.0 - key_w, (size.y - 26.0) * 0.5)
		_key.size = Vector2(key_w, 26.0)
		_label.position = Vector2(18.0, 0.0)
		_label.size = Vector2(maxf(0.0, size.x - 32.0 - key_w - 10.0), size.y)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus if focused else _normal)
		_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if focused else UiTokens.INK)
		_key.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)


var _bg: Panel
var _scroll: ScrollContainer
var _card: PanelContainer
var _content: VBoxContainer
var _found: Label
var _days: Label
var _pitch: Pitch
var _rows: VBoxContainer
var _scout_value: Label
var _region_value: Label
var _country_value: Label
var _note: Label
var _action: ActionButton


# Shared formatting ----------------------------------------------------------

static func role_label(role: String) -> String:
	return str(ROLE_LABELS.get(role.to_upper(), ROLE_LABELS[""]))


static func range_label(minimum, maximum) -> String:
	if minimum == null and maximum == null:
		return "ANY"
	var low := "—" if minimum == null else str(int(minimum))
	var high := "—" if maximum == null else str(int(maximum))
	return "%s – %s" % [low, high]


static func criteria_line(criteria: Dictionary) -> String:
	if criteria.is_empty():
		return ""
	var parts: Array[String] = [role_label(str(criteria.get("role", "")))]
	if criteria.get("age_min") != null or criteria.get("age_max") != null:
		parts.append("AGE %s" % range_label(
			criteria.get("age_min"), criteria.get("age_max")))
	if criteria.get("contract_min") != null or criteria.get("contract_max") != null:
		parts.append("CONTRACT %s" % range_label(
			criteria.get("contract_min"), criteria.get("contract_max")))
	return " · ".join(parts)


static func pitch_zone(role: String) -> String:
	match role.to_upper():
		"GK":
			return "gk"
		"DEF":
			return "def"
		"MID":
			return "mid"
		"FWD":
			return "fwd"
	return "all"


# Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	resized.connect(_layout)
	call_deferred("_layout")


func setup(scout: Dictionary, criteria_line_text := "") -> void:
	if _card == null:
		return
	var task = scout.get("task") if not scout.is_empty() else null
	var report = scout.get("report") if not scout.is_empty() else null
	var task_data: Dictionary = task if task is Dictionary else {}
	var report_data: Dictionary = report if report is Dictionary else {}
	var found := int(task_data.get("found_count", 0))
	_found.text = str(found)
	var worked := int(task_data.get("days_worked", 0)) if not task_data.is_empty() \
		else int(report_data.get("days_worked", 0))
	_days.text = str(worked)
	var role := str((task_data.get("criteria", {}) as Dictionary).get("role", ""))
	_pitch.zone = pitch_zone(role)
	_pitch.queue_redraw()
	_scout_value.text = str(scout.get("name", "—")) if not scout.is_empty() else "—"
	_region_value.text = str(task_data.get("region_name", ""))
	_country_value.text = str(task_data.get("country_name", ""))
	if _region_value.text.is_empty():
		_region_value.text = "—"
	if _country_value.text.is_empty():
		_country_value.text = "—"
	var note := criteria_line_text
	if task_data.is_empty() and not report_data.is_empty():
		var days := int(report_data.get("days_left", 0))
		note = "Watching %s · %d %s left" % [
			str(report_data.get("player_name", "")), days,
			"day" if days == 1 else "days"]
	elif task_data.is_empty():
		note = "No network yet. Hire a scout and pick a search region."
	_note.text = note
	_note.visible = not note.is_empty()
	_action.visible = not task_data.is_empty()


func action_button() -> Button:
	return _action


func _layout() -> void:
	if _bg == null or size.x <= 0.0:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_scroll.position = Vector2.ZERO
	_scroll.size = size


func _build() -> void:
	_bg = Panel.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	_bg.add_theme_stylebox_override(&"panel", box)
	add_child(_bg)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	_card = PanelContainer.new()
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pad := StyleBoxFlat.new()
	pad.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	pad.content_margin_left = PAD
	pad.content_margin_right = PAD
	pad.content_margin_top = PAD
	pad.content_margin_bottom = PAD
	_card.add_theme_stylebox_override(&"panel", pad)
	_scroll.add_child(_card)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 10)
	_card.add_child(_content)

	var title := _label(UiTheme.barlow(700), 24)
	title.text = "SCOUTING NETWORK"
	_content.add_child(title)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 16)
	_content.add_child(stats)
	_found = _stat_pair(stats, "PLAYERS FOUND")
	_days = _stat_pair(stats, "DAYS SCOUTING")

	_pitch = Pitch.new()
	_pitch.custom_minimum_size = Vector2(0.0, PITCH_H)
	_pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_pitch)

	var line := ColorRect.new()
	line.color = Color(UiTokens.INK, 0.12)
	line.custom_minimum_size.y = 1.0
	_content.add_child(line)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	_content.add_child(_rows)
	_scout_value = _row("SCOUT")
	_region_value = _row("REGION")
	_country_value = _row("COUNTRY")
	_note = _label(UiTheme.inter(400), 16)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.max_lines_visible = 3
	_note.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_content.add_child(_note)

	_action = ActionButton.new()
	_action.custom_minimum_size.y = 46.0
	_action.pressed.connect(func() -> void: reports_requested.emit())
	_content.add_child(_action)


func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	row.custom_minimum_size.y = ROW_H
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
