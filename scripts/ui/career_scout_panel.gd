class_name CareerScoutPanel
extends Control
# Prototype career/scouting/ScoutPanel.svelte: the right-hand card of the SCOUTS
# tab. Scout identity, the live status plate, the current network task, the
# player report in progress and the profile rows (experience / judgement /
# price). Purely presentational; the host rebuilds it from the snapshot.

const PAD := 16.0
const FLAG_W := 40.0
const FLAG_H := 26.0
const ROW_H := 26.0


# Thin progress bar of the player report (prototype .sc-progress).
class Bar extends Control:
	var ratio := 0.0
	var color := UiTokens.INK

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.INK, 0.12), true)
		var width := clampf(ratio, 0.0, 1.0) * size.x
		draw_rect(Rect2(0.0, 0.0, width, size.y), color, true)


var _bg: Panel
var _scroll: ScrollContainer
var _card: PanelContainer
var _content: VBoxContainer
var _flag: TextureRect
var _name: Label
var _country: Label
var _stars: HBoxContainer
var _status_plate: PanelContainer
var _status_title: Label
var _status_detail: Label
var _task: VBoxContainer
var _task_country: Label
var _task_region: Label
var _task_days: Label
var _task_found: Label
var _task_criteria: Label
var _report: VBoxContainer
var _report_player: Label
var _report_bar: Bar
var _report_note: Label
var _profile: VBoxContainer
var _experience: Label
var _judgement: Label
var _price: Label
var _empty: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	resized.connect(_layout)
	call_deferred("_layout")


func setup(scout: Dictionary, status := {}, criteria_line := "") -> void:
	if _card == null:
		return
	var empty := scout.is_empty()
	for child in _content.get_children():
		(child as Control).visible = not empty
	_empty.visible = empty
	if empty:
		return
	var state := status if not status.is_empty() else CareerScoutCard.status_for(scout)
	_name.text = str(scout.get("name", "")).to_upper()
	_country.text = str(scout.get("nationality", ""))
	_flag.texture = CareerScoutCard.flag_texture(scout)
	_flag.visible = _flag.texture != null
	CareerScoutCard.paint_stars(_stars, int(scout.get("judgement", 0)),
		UiTokens.INK, CareerScoutCard.STAR_OFF)

	var free := str(state.get("tone", "")) == "free"
	_status_title.text = str(state.get("title", ""))
	_status_detail.text = str(state.get("detail", ""))
	_status_detail.visible = not _status_detail.text.is_empty()
	_status_plate.add_theme_stylebox_override(&"panel", _plate_box(free))

	var task = scout.get("task")
	_task.visible = task is Dictionary
	if task is Dictionary:
		var data: Dictionary = task
		_task_country.text = str(data.get("country_name", "")).to_upper()
		_task_region.text = str(data.get("region_name", ""))
		_task_days.text = str(int(data.get("days_worked", 0)))
		_task_found.text = str(int(data.get("found_count", 0)))
		_task_criteria.text = criteria_line
		_task_criteria.visible = not criteria_line.is_empty()

	var report = scout.get("report")
	_report.visible = report is Dictionary
	if report is Dictionary:
		var data: Dictionary = report
		_report_player.text = str(data.get("player_name", "")).to_upper()
		_report_bar.ratio = float(data.get("progress", 0.0))
		var days := int(data.get("days_left", 0))
		_report_note.text = "%d %s left · %d / %d" % [days,
			"day" if days == 1 else "days",
			int(data.get("days_worked", 0)), int(data.get("days_total", 0))]

	_experience.text = "%d / 5" % int(scout.get("experience", 0))
	_judgement.text = "%d / 5" % int(scout.get("judgement", 0))
	_price.text = CareerPlayerPane.money(int(scout.get("price", 0)))


func _build() -> void:
	_bg = Panel.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_theme_stylebox_override(&"panel", _card_box())
	add_child(_bg)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	_card = PanelContainer.new()
	_card.name = "Card"
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
	_content.name = "Content"
	_content.add_theme_constant_override(&"separation", 10)
	_card.add_child(_content)

	# Head -------------------------------------------------------------------
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	_content.add_child(head)
	_flag = TextureRect.new()
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flag.custom_minimum_size = Vector2(FLAG_W, FLAG_H)
	_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_flag)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override(&"separation", 2)
	head.add_child(who)
	_name = _label(UiTheme.barlow(700), 24)
	who.add_child(_name)
	_country = _label(UiTheme.inter(500), 16)
	who.add_child(_country)
	_stars = CareerScoutCard.star_row()
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_stars)

	# Status -----------------------------------------------------------------
	_status_plate = PanelContainer.new()
	_content.add_child(_status_plate)
	var plate := HBoxContainer.new()
	plate.add_theme_constant_override(&"separation", 10)
	_status_plate.add_child(plate)
	_status_title = _label(UiTheme.inter(600), 16)
	_status_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.add_child(_status_title)
	_status_detail = _label(UiTheme.inter(500), 16)
	_status_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	plate.add_child(_status_detail)

	# Task -------------------------------------------------------------------
	_task = _section("CURRENT TASK")
	_task_country = _big(_task)
	_task_region = _muted(_task)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 16)
	_task.add_child(stats)
	stats.add_child(_stat_pair("DAYS WORKED", 0))
	_task_days = stats.get_child(0).get_child(1) as Label
	stats.add_child(_stat_pair("PLAYERS FOUND", 1))
	_task_found = stats.get_child(1).get_child(1) as Label
	_task_criteria = _muted(_task)

	# Report -----------------------------------------------------------------
	_report = _section("PLAYER REPORT")
	_report_player = _big(_report)
	_report_bar = Bar.new()
	_report_bar.custom_minimum_size = Vector2(0.0, 6.0)
	_report_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_report.add_child(_report_bar)
	_report_note = _muted(_report)

	# Profile ----------------------------------------------------------------
	_profile = _section("SCOUT PROFILE")
	_experience = _profile_row(_profile, "EXPERIENCE")
	_judgement = _profile_row(_profile, "JUDGEMENT")
	_price = _profile_row(_profile, "PRICE")

	_empty = _label(UiTheme.inter(500), 16)
	_empty.text = "No scout selected. Hire one to start building your network."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.visible = false
	_content.add_child(_empty)


func _card_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	return box


func _layout() -> void:
	if _bg == null or size.x <= 0.0:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_scroll.position = Vector2.ZERO
	_scroll.size = size


func _plate_box(free: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.035 if free else 0.055)
	box.border_color = Color(UiTokens.INK, 0.12)
	box.border_width_left = 2
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	return box


func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", UiTokens.INK)
	return label


func _section(title: String) -> VBoxContainer:
	var line := ColorRect.new()
	line.color = Color(UiTokens.INK, 0.12)
	line.custom_minimum_size.y = 1.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(line)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	_content.add_child(box)
	var label := _label(UiTheme.inter(600), 16)
	label.text = title
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	box.add_child(label)
	return box


func _big(parent: VBoxContainer) -> Label:
	var label := _label(UiTheme.barlow(700), 22)
	parent.add_child(label)
	return label


func _muted(parent: VBoxContainer) -> Label:
	var label := _label(UiTheme.inter(400), 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	parent.add_child(label)
	return label


func _stat_pair(title: String, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.name = "Stat%d" % index
	var label := _label(UiTheme.inter(500), 16)
	label.text = title
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	row.add_child(label)
	var value := _label(UiTheme.barlow(700), 18)
	row.add_child(value)
	return row


func _profile_row(parent: VBoxContainer, title: String) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_H
	row.add_theme_constant_override(&"separation", 12)
	parent.add_child(row)
	var label := _label(UiTheme.inter(500), 16)
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	row.add_child(label)
	var value := _label(UiTheme.inter(600), 16)
	value.name = "Value"
	# A clipped Label reports a 1px minimum width, which an EXPAND_FILL title
	# then squeezes to nothing; let the value size itself from its text.
	value.clip_text = false
	value.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(value)
	return value
