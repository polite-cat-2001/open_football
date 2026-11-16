class_name CareerScoutCard
extends Control
# Prototype career/scouting/ScoutCard.svelte: one tile of the scouts grid — flag,
# name, the current task/report status and the five judgement stars. A focusable
# Control like CareerPlayerCard (a Button cannot declare its own pressed(id)),
# so the host owns confirm and clicks only emit pressed.

signal pressed(scout_id: String)

const PAD := 18.0
const FLAG_W := 40.0
const FLAG_H := 26.0
const NAME_TOP := 48.0
const NAME_H := 52.0
const STATUS_TOP := 106.0
const DETAIL_TOP := 128.0
const STAR_H := 22.0
const MIN_H := 210.0
const STAR_OFF := Color(0.113725, 0.129412, 0.219608, 0.18)

var _scout: Dictionary = {}
var _scout_id := ""
var _status: Dictionary = {}
var _selected := false

var _bg: Panel
var _rail: ColorRect
var _flag: TextureRect
var _name: Label
var _status_label: Label
var _detail: Label
var _stars: HBoxContainer
var _judgement_label: Label
var _normal_box: StyleBoxFlat
var _focus_box: StyleBoxFlat


# Empty slot tile: "HIRE A SCOUT" with the prototype's plus in the corner.
class Empty extends Button:
	const PAD := 18.0

	var _bg: Panel
	var _rail: ColorRect
	var _label: Label
	var _plus: Label
	var _normal_box: StyleBoxFlat
	var _focus_box: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_normal_box = StyleBoxFlat.new()
		_normal_box.bg_color = UiTokens.TILE
		_normal_box.anti_aliasing = true
		_focus_box = StyleBoxFlat.new()
		_focus_box.bg_color = UiTokens.FOCUS_FILL
		_focus_box.anti_aliasing = true
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_rail = ColorRect.new()
		_rail.color = UiTokens.RAIL
		_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rail.visible = false
		add_child(_rail)
		_label = Label.new()
		_label.text = "HIRE A SCOUT"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_override(&"font", UiTheme.barlow(700))
		_label.add_theme_font_size_override(&"font_size", 22)
		add_child(_label)
		_plus = Label.new()
		_plus.text = "+"
		_plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_plus.add_theme_font_override(&"font", UiTheme.barlow(600))
		_plus.add_theme_font_size_override(&"font_size", 44)
		add_child(_plus)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func _layout_content() -> void:
		_bg.position = Vector2.ZERO
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		_label.position = Vector2(PAD, size.y - 44.0)
		_label.size = Vector2(maxf(0.0, size.x - PAD * 2.0), 28.0)
		_plus.position = Vector2(size.x - PAD - 30.0, size.y - 54.0)
		_plus.size = Vector2(30.0, 46.0)

	func _apply_state() -> void:
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus_box if focused else _normal_box)
		_rail.visible = focused
		_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK_2)
		_plus.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)


# Shared helper statics ------------------------------------------------------

static func status_for(scout: Dictionary) -> Dictionary:
	var report = scout.get("report")
	if report is Dictionary:
		var days := int((report as Dictionary).get("days_left", 0))
		return {
			"tone": "active",
			"title": "WATCHING %s" % str(
				(report as Dictionary).get("player_name", "")).to_upper(),
			"detail": "%d %s LEFT" % [days, "DAY" if days == 1 else "DAYS"],
		}
	var task = scout.get("task")
	if task is Dictionary:
		var found := int((task as Dictionary).get("found_count", 0))
		return {
			"tone": "active",
			"title": "SCOUTING %s" % str(
				(task as Dictionary).get("country_name", "")).to_upper(),
			"detail": "%d %s FOUND" % [found, "PLAYER" if found == 1 else "PLAYERS"],
		}
	return {"tone": "free", "title": "SCOUT AVAILABLE", "detail": ""}


static func flag_texture(scout: Dictionary) -> Texture2D:
	var tm_id := str(scout.get("nationality_id", ""))
	if tm_id.is_empty():
		return null
	return UiAssets.usable_texture(UiAssets.country_flag({"tm_id": tm_id}))


static func star_row() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 3)
	for index in 5:
		var star := Label.new()
		star.text = "★"
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.add_theme_font_override(&"font", UiTheme.inter(600))
		star.add_theme_font_size_override(&"font_size", 18)
		box.add_child(star)
	return box


static func paint_stars(box: HBoxContainer, filled: int, on: Color, off: Color) -> void:
	var index := 0
	for child in box.get_children():
		(child as Label).add_theme_color_override(&"font_color",
			on if index < filled else off)
		index += 1


# Lifecycle ------------------------------------------------------------------

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
	_build()
	_apply_state()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	call_deferred("_layout_content")


func setup(scout: Dictionary, status := {}) -> void:
	_scout = scout
	_scout_id = str(scout.get("id", ""))
	_status = status if not status.is_empty() else status_for(scout)
	if _name == null:
		return
	_refresh()


func scout_id() -> String:
	return _scout_id


func set_selected(value: bool) -> void:
	_selected = value
	_apply_state()


func is_selected() -> bool:
	return _selected


func _build() -> void:
	_bg = Panel.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_rail = ColorRect.new()
	_rail.color = UiTokens.RAIL
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)

	_flag = TextureRect.new()
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flag)

	_name = _make_label(UiTheme.barlow(700), 24)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_status_label = _make_label(UiTheme.inter(600), 16)
	_detail = _make_label(UiTheme.inter(500), 16)

	_stars = star_row()
	add_child(_stars)
	_judgement_label = _make_label(UiTheme.inter(600), 14)
	_judgement_label.text = "JUDGEMENT"


func _make_label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label


func _refresh() -> void:
	_name.text = str(_scout.get("name", "")).to_upper()
	_flag.texture = flag_texture(_scout)
	_flag.visible = _flag.texture != null
	_status_label.text = str(_status.get("title", ""))
	_detail.text = str(_status.get("detail", ""))
	paint_stars(_stars, int(_scout.get("judgement", 0)), UiTokens.INK, STAR_OFF)
	_layout_content()
	_apply_state()


func _layout_content() -> void:
	if _bg == null:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)
	_flag.position = Vector2(PAD, 14.0)
	_flag.size = Vector2(FLAG_W, FLAG_H)
	var inner := maxf(40.0, size.x - PAD * 2.0)
	_name.position = Vector2(PAD, NAME_TOP)
	_name.size = Vector2(inner, NAME_H)
	_status_label.position = Vector2(PAD, STATUS_TOP)
	_status_label.size = Vector2(inner, 20.0)
	_detail.position = Vector2(PAD, DETAIL_TOP)
	_detail.size = Vector2(inner, 20.0)
	_stars.position = Vector2(PAD, size.y - 12.0 - STAR_H)
	_stars.size = Vector2(5.0 * 21.0, STAR_H)
	var stars_w := 5.0 * 21.0
	_judgement_label.position = Vector2(PAD + stars_w + 6.0,
		size.y - 12.0 - STAR_H + 1.0)
	_judgement_label.size = Vector2(maxf(0.0, size.x - PAD * 2.0 - stars_w - 6.0),
		STAR_H - 2.0)


func _apply_state() -> void:
	if _bg == null:
		return
	var focused := has_focus()
	_bg.add_theme_stylebox_override(&"panel", _focus_box if focused else _normal_box)
	_rail.visible = _selected or not focused
	var body := UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
	var title := UiTokens.FOCUS_MARK if focused else UiTokens.INK
	_name.add_theme_color_override(&"font_color", title)
	_status_label.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK if focused else (
			UiTokens.INK_2 if str(_status.get("tone", "")) == "free" else UiTokens.INK))
	_detail.add_theme_color_override(&"font_color", body)
	_judgement_label.add_theme_color_override(&"font_color", body)
	paint_stars(_stars, int(_scout.get("judgement", 0)),
		UiTokens.FOCUS_INK if focused else UiTokens.INK,
		Color(UiTokens.FOCUS_INK, 0.24) if focused else STAR_OFF)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			pressed.emit(_scout_id)
			accept_event()


func activate() -> void:
	pressed.emit(_scout_id)
