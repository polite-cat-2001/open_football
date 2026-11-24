class_name CareerTournamentIntro
extends Control
# The first-time tournament intro. A modal card over the hub with the
# competition logo (or its code as a monogram when no logo is downloaded) and the
# facts CareerIntro builds from the format. The hub owns input and the calendar
# pause; this node draws.

const CARD_W := 760.0
const PAD := 32.0
const LOGO := 96.0
const LINE_H := 26.0
const LINE_GAP := 8.0

var _backdrop: ColorRect
var _card: Panel
var _logo: TextureRect
var _monogram: Label
var _title: Label
var _lines: Array[Label] = []
var _hint: Label
var _open := false
var _area := Rect2()
var _card_rect := Rect2()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = ColorRect.new()
	_backdrop.color = Color(UiTokens.STAGE_BG, 0.72)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_card = Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.TILE, 1.0)
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 24
	box.shadow_offset = Vector2(0.0, 16.0)
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)

	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card.add_child(_logo)
	_monogram = _label(30, UiTheme.inter(700), UiTokens.INK)
	_monogram.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monogram.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_child(_monogram)
	_title = _label(30, UiTheme.inter(700), UiTokens.INK)
	_card.add_child(_title)
	_hint = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_card.add_child(_hint)
	_hint.text = "A / ENTER: continue"


func _label(size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func setup(facts: Dictionary) -> void:
	_open = false
	var competition := str(facts.get("competition", ""))
	_title.text = str(facts.get("label", competition))
	var texture := UiAssets.tournament_logo(competition)
	_logo.texture = texture
	_logo.visible = texture != null
	_monogram.visible = texture == null
	_monogram.text = competition.to_upper()
	for label in _lines:
		label.queue_free()
	_lines.clear()
	var rows: Array = facts.get("lines", [])
	for row in rows:
		var label := _label(19, UiTheme.inter(500), UiTokens.INK_2)
		label.text = str(row)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(CARD_W - PAD * 2.0, 0.0)
		_card.add_child(label)
		_lines.append(label)
	layout_overlay(_area)


func open() -> void:
	_open = true
	visible = true
	move_to_front()


func close() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func layout_overlay(area: Rect2) -> void:
	if _card == null:
		return
	_area = area
	if _card_rect.size == Vector2.ZERO:
		_card_rect = Rect2(area.position, Vector2(CARD_W, PAD * 2.0 + LOGO))
	_backdrop.position = area.position
	_backdrop.size = area.size
	var body_h := 0.0
	for index in range(_lines.size()):
		body_h += _lines[index].get_combined_minimum_size().y + LINE_GAP
	var height := PAD * 2.0 + LOGO + 24.0 + body_h + 24.0 + LINE_H
	_card_rect.size.y = height
	_card.position = Vector2(area.position.x + (area.size.x - CARD_W) / 2.0,
		area.position.y + maxf(24.0, (area.size.y - height) / 2.0))
	_card.size = _card_rect.size
	_logo.position = Vector2(PAD, PAD)
	_logo.size = Vector2(LOGO, LOGO)
	_monogram.position = Vector2(PAD, PAD)
	_monogram.size = Vector2(LOGO, LOGO)
	_title.position = Vector2(PAD + LOGO + 24.0, PAD + LOGO / 2.0 - 22.0)
	_title.size = Vector2(CARD_W - PAD * 2.0 - LOGO - 24.0, 44.0)
	var y := PAD + LOGO + 24.0
	for label in _lines:
		label.position = Vector2(PAD, y)
		label.size = Vector2(CARD_W - PAD * 2.0,
			label.get_combined_minimum_size().y)
		y += label.get_combined_minimum_size().y + LINE_GAP
	_hint.position = Vector2(PAD, _card_rect.size.y - PAD - LINE_H + 6.0)
	_hint.size = Vector2(CARD_W - PAD * 2.0, LINE_H)
