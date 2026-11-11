class_name CareerHubOverlay
extends Control
# Tournament overlay from the prototype's TournamentOverlay.svelte: a light card
# with the competition header and the full standings, shown over the hub.
# The hub owns input, hints and the fade/scale transition; this node draws and
# scrolls.

const PAD := 24.0
const ROW_H := 32.0
const HEAD_H := 26.0
const COLUMNS := [
	{"key": "position", "width": 40.0, "label": "#", "align": "left"},
	{"key": "crest", "width": 26.0, "label": "", "align": "left"},
	{"key": "club_name", "width": 0.0, "label": "CLUB", "align": "left"},
	{"key": "played", "width": 50.0, "label": "P", "align": "right"},
	{"key": "won", "width": 50.0, "label": "W", "align": "right"},
	{"key": "drawn", "width": 50.0, "label": "D", "align": "right"},
	{"key": "lost", "width": 50.0, "label": "L", "align": "right"},
	{"key": "goals_for", "width": 60.0, "label": "GF", "align": "right"},
	{"key": "goals_against", "width": 60.0, "label": "GA", "align": "right"},
	{"key": "goal_difference", "width": 70.0, "label": "GD", "align": "right"},
	{"key": "points", "width": 60.0, "label": "PTS", "align": "right"},
]

var _card: Panel
var _eyebrow: Label
var _divider: ColorRect
var _scroll: ScrollContainer
var _body: Control
var _rows: Array = []
var _open := false
var _card_rect := Rect2()
var _row_h := ROW_H


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.TILE, 1.0)
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 16
	box.shadow_offset = Vector2(0.0, 12.0)
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)

	_eyebrow = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_divider = ColorRect.new()
	_divider.color = Color(UiTokens.INK, 0.15)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_body = Control.new()
	_scroll.add_child(_body)
	for node in [_eyebrow, _divider, _scroll]:
		_card.add_child(node)


func setup(model: Dictionary) -> void:
	var round := int(model.get("round", 0))
	_eyebrow.text = "%s%s" % [
		str(model.get("competition", "")).to_upper(),
		" · ROUND %d" % round if round > 0 else "",
	]
	for row in _rows:
		(row["root"] as Control).queue_free()
	_rows.clear()
	var head := _make_row(true)
	_set_texts(head, {"position": "#", "club_name": "CLUB", "played": "P", "won": "W",
		"drawn": "D", "lost": "L", "goals_for": "GF", "goals_against": "GA",
		"goal_difference": "GD", "points": "PTS"})
	_rows.append(head)
	for item in model.get("standings", []):
		var row := _make_row(false)
		_set_texts(row, item)
		row["own"] = bool(item.get("own", false))
		_rows.append(row)
	if _card_rect.size != Vector2.ZERO:
		layout_overlay(_card_rect)


func open() -> void:
	_open = true
	visible = true
	move_to_front()
	_scroll.scroll_vertical = 0


func close() -> void:
	_open = false


func hide_card() -> void:
	visible = false


func card() -> Control:
	return _card


func is_open() -> bool:
	return _open


func scroll_step(direction: int) -> void:
	if not _open or direction == 0:
		return
	_scroll.scroll_vertical = maxi(0,
		_scroll.scroll_vertical + int(signf(direction)) * int(_row_h))


func layout_overlay(card_rect: Rect2) -> void:
	if _card == null:
		return
	_card_rect = card_rect
	_card.position = card_rect.position
	_card.size = card_rect.size
	_card.pivot_offset = _card.size * 0.5
	var width := card_rect.size.x
	_eyebrow.position = Vector2(PAD, 16.0)
	_eyebrow.size = Vector2(width - PAD * 2.0, 20.0)
	_divider.position = Vector2(PAD, 44.0)
	_divider.size = Vector2(width - PAD * 2.0, 2.0)
	_scroll.position = Vector2(PAD, 56.0)
	_scroll.size = Vector2(width - PAD * 2.0, card_rect.size.y - 56.0 - 16.0)
	# Squeeze the rows so a full 20-club league fits without scrolling; taller
	# leagues still scroll at the natural row height.
	var row_count := maxi(1, _rows.size() - 1)
	_row_h = minf(ROW_H, (_scroll.size.y - HEAD_H) / float(row_count))
	_body.custom_minimum_size = Vector2(_scroll.size.x - 8.0, HEAD_H + _row_h * row_count)
	for index in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var root: Control = row["root"]
		root.position = Vector2(0.0, 0.0 if index == 0 else HEAD_H + _row_h * (index - 1))
		root.size = Vector2(_body.custom_minimum_size.x,
			HEAD_H if index == 0 else _row_h)
		_layout_row(row)


func _make_row(head: bool) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail := ColorRect.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	root.add_child(rail)
	var cells: Dictionary = {}
	for column in COLUMNS:
		if str(column["key"]) == "crest":
			var crest := TextureRect.new()
			crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			root.add_child(crest)
			cells["crest"] = crest
			continue
		var label := _label(15 if head else 16,
			UiTheme.inter(600) if head else UiTheme.inter(500), UiTokens.INK_2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT \
			if str(column["align"]) == "right" else HORIZONTAL_ALIGNMENT_LEFT
		root.add_child(label)
		cells[str(column["key"])] = label
	_body.add_child(root)
	return {"root": root, "bg": bg, "rail": rail, "cells": cells,
		"own": false, "head": head}


func _set_texts(row: Dictionary, item: Dictionary) -> void:
	var cells: Dictionary = row["cells"]
	for column in COLUMNS:
		var key := str(column["key"])
		if key == "crest":
			var crest: TextureRect = cells["crest"]
			var logo := str(item.get("club_logo", ""))
			crest.texture = _logo(logo) if not logo.is_empty() else null
			crest.visible = not logo.is_empty()
			continue
		(cells[key] as Label).text = str(item.get(key, ""))


func _layout_row(row: Dictionary) -> void:
	var root: Control = row["root"]
	var cells: Dictionary = row["cells"]
	var own := bool(row.get("own", false)) and not bool(row.get("head", false))
	var bg: Panel = row["bg"]
	bg.position = Vector2.ZERO
	bg.size = root.size
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.10)
	bg.add_theme_stylebox_override(&"panel", box)
	bg.visible = own
	var rail: ColorRect = row["rail"]
	rail.position = Vector2.ZERO
	rail.size = Vector2(2.0, root.size.y)
	rail.color = Color(UiTokens.INK, 0.18)
	rail.visible = own

	var x := 6.0
	for column in COLUMNS:
		var key := str(column["key"])
		var width := float(column["width"])
		if width <= 0.0:
			width = root.size.x - x - 458.0
		if key == "crest":
			var crest: TextureRect = cells["crest"]
			crest.position = Vector2(x, (root.size.y - 20.0) * 0.5)
			crest.size = Vector2(20.0, 20.0)
		else:
			var label: Label = cells[key]
			label.position = Vector2(x, 0.0)
			label.size = Vector2(width, root.size.y)
		x += width


func _label(size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _logo(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return UiAssets.usable_texture(UiAssets.load_texture(path.trim_prefix("/")))
