class_name SetPieceHints
extends Control
# Right-side set-piece hints (ticket 10): key chips for the taker change and
# the shot/pass/cross actions, shown only while a set piece is alive. Draw-only;
# GpfHud builds the rows from the snapshot and places the plate under the TV logo.

const PAD_X := 14.0
const PAD_Y := 8.0
const ROW_H := 24.0
const ROW_GAP := 4.0
const CHIP_H := 20.0
const CHIP_PAD := 6.0
const CHIP_MIN_W := 26.0
const CHIP_GAP := 8.0
const KEY_SIZE := 13
const LABEL_SIZE := 16

var rows: Array = []

var _key_font: Font = UiTheme.barlow(800)
var _label_font: Font = UiTheme.barlow(600)
var _plate := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_plate.bg_color = Color(UiTokens.FOCUS_FILL, 0.90)
	_plate.set_corner_radius_all(6)
	_plate.border_width_right = 4
	_plate.border_color = UiTokens.RAIL


func set_hints(new_rows: Array) -> void:
	if new_rows == rows:
		return
	rows = new_rows.duplicate(true)
	_resize()
	queue_redraw()


func reset() -> void:
	rows.clear()
	visible = false
	size = Vector2.ZERO


func has_hint(label: String) -> bool:
	return not key_for(label).is_empty()


func key_for(label: String) -> String:
	for row in rows:
		if String(row.get("label", "")) == label:
			return String(row.get("key", ""))
	return ""


func _resize() -> void:
	if rows.is_empty():
		size = Vector2.ZERO
		return
	var width := 0.0
	for row in rows:
		width = maxf(width, _chip_width(String(row.get("key", ""))) + CHIP_GAP
			+ _label_font.get_string_size(String(row.get("label", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x)
	size = Vector2(PAD_X * 2 + width,
		PAD_Y * 2 + rows.size() * ROW_H + maxi(0, rows.size() - 1) * ROW_GAP)


func _chip_width(key: String) -> float:
	return maxf(CHIP_MIN_W, _key_font.get_string_size(
		key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_SIZE).x + CHIP_PAD * 2)


func _draw() -> void:
	if rows.is_empty():
		return
	draw_style_box(_plate, Rect2(Vector2.ZERO, size))
	for i in rows.size():
		var row: Dictionary = rows[i]
		var top := PAD_Y + i * (ROW_H + ROW_GAP)
		var key := String(row.get("key", ""))
		var chip_w := _chip_width(key)
		var chip_rect := Rect2(PAD_X, top + (ROW_H - CHIP_H) * 0.5, chip_w, CHIP_H)
		draw_rect(chip_rect, UiTokens.KBD_FILL, true)
		draw_rect(chip_rect, UiTokens.KBD_BORDER, false, 1.0)
		draw_string(_key_font, Vector2(chip_rect.position.x, top + 16.0), key,
			HORIZONTAL_ALIGNMENT_CENTER, chip_w, KEY_SIZE, UiTokens.FOCUS_INK)
		draw_string(_label_font, Vector2(PAD_X + chip_w + CHIP_GAP, top + 17.0),
			String(row.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - PAD_X * 2 - chip_w - CHIP_GAP, LABEL_SIZE, UiTokens.LEGEND_INK)
