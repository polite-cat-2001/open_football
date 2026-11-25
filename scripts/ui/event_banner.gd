class_name EventBanner
extends "res://scripts/ui/banner_control.gd"
# Bottom-centre banner for a goal (GOAL + scorer) or a referee caption (card,
# offside, advantage). Draw-only; appears and disappears with the shell's
# 150/240 ms fade+scale so it never pops.

const WIDTH := 760.0
const EVENT_H := 56.0
const GOAL_H := 100.0
const TEXT_SIZE := 22

var goal := false
var title := ""
var text := ""
var minute := ""
var card := ""

var _title_font: Font = UiTheme.barlow(800)
var _minute_font: Font = UiTheme.barlow(800)
var _text_font: Font = UiTheme.barlow(600)
var _plate := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, EVENT_H)
	_plate.bg_color = Color(UiTokens.FOCUS_FILL, 0.93)
	_plate.set_corner_radius_all(8)
	_plate.border_width_left = 4
	_plate.border_color = UiTokens.RAIL
	visible = false
	resized.connect(queue_redraw)


func set_goal(scorer: String, goal_minute := "", own_goal := false) -> void:
	var new_title := "OWN GOAL" if own_goal else "GOAL"
	if goal and text == scorer and minute == goal_minute and title == new_title:
		return
	goal = true
	title = new_title
	text = scorer
	minute = goal_minute
	card = ""
	_plate.border_color = UiTokens.FOCUS_MARK
	_set_height(GOAL_H)
	queue_redraw()


func set_message(message: String) -> void:
	var lower := message.to_lower()
	var new_card := "yellow" if lower.contains("yellow") \
		else ("red" if lower.contains("red") else "")
	var clean := message.strip_edges()
	var bang := clean.find("!")
	if bang >= 0:
		clean = clean.substr(0, bang + 1) + clean.substr(bang + 1).replace("!", "")
	if not clean.is_empty():
		clean = clean.substr(0, 1).to_upper() + clean.substr(1)
	if new_card == "yellow":
		clean = clean.replace("yellow", "Yellow")
	elif new_card == "red":
		clean = clean.replace("red", "Red")
	if not goal and text == clean and card == new_card:
		return
	goal = false
	title = ""
	text = clean
	card = new_card
	_plate.border_color = UiTokens.RAIL
	# Size the plate to the caption; 760 is only the upper bound.
	var x := 20.0 + (30.0 if not card.is_empty() else 0.0)
	var text_width := _text_font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	size = Vector2(clampf(x + text_width + 20.0, 240.0, WIDTH), EVENT_H)
	pivot_offset = size * 0.5
	queue_redraw()


func _set_height(height: float) -> void:
	size = Vector2(WIDTH, height)
	pivot_offset = size * 0.5


func _draw() -> void:
	draw_style_box(_plate, Rect2(Vector2.ZERO, size))
	var x := 20.0
	if not card.is_empty():
		var chip := Rect2(x, (size.y - 22.0) * 0.5, 14.0, 22.0)
		draw_rect(chip, Color(0.98, 0.82, 0.10) if card == "yellow" \
			else Color(0.92, 0.13, 0.16), true)
		draw_rect(chip, Color(0, 0, 0, 0.55), false, 1.0)
		x += 30.0
	var text_width := size.x - x - 20.0
	if goal:
		var minute_width := 200.0
		var name_width := maxf(0.0, text_width - minute_width - 20.0)
		draw_string(_title_font, Vector2(x, 48.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, name_width, 42, UiTokens.FOCUS_INK)
		draw_string(_text_font, Vector2(x, 82.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, name_width, 24, UiTokens.FOCUS_INK_2)
		if not minute.is_empty():
			draw_string(_minute_font, Vector2(size.x - 24.0 - minute_width, 70.0),
				minute, HORIZONTAL_ALIGNMENT_RIGHT, minute_width, 48, UiTokens.FOCUS_MARK)
	else:
		draw_multiline_string(_text_font, Vector2(x, 34.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, TEXT_SIZE, 1, UiTokens.FOCUS_INK)
