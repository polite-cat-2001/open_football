class_name KickoffBanner
extends "res://scripts/ui/banner_control.gd"
# Pre-kickoff scoreboard (ticket 09): home crest + name on the left, the score in
# the centre, away on the right, and each team's event list (goals and red cards)
# above its name along the outer edge. The banner holds only a couple of seconds
# (referee prepare to kickoff), so the list is shown whole: it grows upwards and
# compacts above TIGHT_AFTER lines instead of scrolling. Shown while a kickoff set
# piece is being set up and animated like every shell overlay.

const WIDTH := 1040.0
const BASE_H := 96.0
const SCORER_LINE := 20.0
const TIGHT_LINE := 16.0
const TIGHT_AFTER := 8
const SCORER_GAP := 14.0
const EVENTS_TOP := 14.0
const MAX_LINES := 12
const PAD := 28.0
const CREST := 48.0
const NAME_SIZE := 24
const SCORE_SIZE := 54
const SCORER_SIZE := 17
const TIGHT_SIZE := 14

var home: Dictionary = {}
var away: Dictionary = {}
var score0 := 0
var score1 := 1
var home_events: Array[Dictionary] = []
var away_events: Array[Dictionary] = []

var _name_font: Font = UiTheme.barlow(800)
var _score_font: Font = UiTheme.barlow(800)
var _event_font: Font = UiTheme.barlow(600)
var _plate := StyleBoxFlat.new()
var _home_lines: Array[Dictionary] = []
var _away_lines: Array[Dictionary] = []
var _line := SCORER_LINE
var _font_size := SCORER_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Crest images are 180 px originals drawn at 48 px.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size = Vector2(WIDTH, BASE_H)
	pivot_offset = size * 0.5
	_plate.bg_color = Color(UiTokens.FOCUS_FILL, 0.93)
	_plate.set_corner_radius_all(10)
	_plate.border_width_top = 4
	_plate.border_color = UiTokens.FOCUS_MARK
	visible = false
	resized.connect(queue_redraw)


func set_teams(home_team: Dictionary, away_team: Dictionary) -> void:
	home = home_team
	away = away_team
	queue_redraw()


func set_match(new_score0: int, new_score1: int, new_home: Array[Dictionary],
		new_away: Array[Dictionary]) -> void:
	if new_score0 == score0 and new_score1 == score1 \
			and new_home == home_events and new_away == away_events:
		return
	score0 = new_score0
	score1 = new_score1
	home_events = new_home
	away_events = new_away
	_home_lines = _visible_events(home_events)
	_away_lines = _visible_events(away_events)
	var lines := maxi(_home_lines.size(), _away_lines.size())
	_line = SCORER_LINE if lines <= TIGHT_AFTER else TIGHT_LINE
	_font_size = SCORER_SIZE if lines <= TIGHT_AFTER else TIGHT_SIZE
	var extra := SCORER_GAP if lines > 0 else 0.0
	size = Vector2(WIDTH, BASE_H + lines * _line + extra)
	pivot_offset = size * 0.5
	queue_redraw()


# The earliest events fold into one marker line once the list outgrows the cap.
func _visible_events(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first := maxi(0, events.size() - MAX_LINES)
	if first > 0:
		out.append({"more": first})
	for i in range(first, events.size()):
		out.append(events[i])
	return out


func _draw() -> void:
	draw_style_box(_plate, Rect2(Vector2.ZERO, size))
	var center := size.x * 0.5
	var side_width := center - PAD - 120.0
	var row_top := size.y - (BASE_H - 18.0)

	_draw_events(_home_lines, PAD, side_width, true)
	_draw_events(_away_lines, size.x - PAD, side_width, false)
	_draw_side(home, Rect2(PAD, row_top, CREST, CREST), PAD + CREST + 12.0,
		PAD + 12.0 + side_width, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_side(away, Rect2(size.x - PAD - CREST, row_top, CREST, CREST),
		size.x - PAD - CREST - 12.0 - side_width, size.x - PAD - CREST - 12.0,
		HORIZONTAL_ALIGNMENT_RIGHT)

	draw_string(_score_font, Vector2(center - 110.0, row_top + 46.0),
		"%d : %d" % [score0, score1], HORIZONTAL_ALIGNMENT_CENTER, 220.0,
		SCORE_SIZE, UiTokens.FOCUS_INK)


func _draw_events(lines: Array[Dictionary], edge: float, width: float, home_side: bool) -> void:
	for i in lines.size():
		var baseline := EVENTS_TOP + i * _line + _font_size
		var event := lines[i]
		if event.has("more"):
			draw_string(_event_font, Vector2(edge if home_side else edge - width, baseline),
				"… +%d" % int(event["more"]),
				HORIZONTAL_ALIGNMENT_LEFT if home_side else HORIZONTAL_ALIGNMENT_RIGHT,
				width, _font_size, Color(UiTokens.FOCUS_INK_2, 0.7))
			continue
		var name := String(event.get("name", ""))
		var text := "%d'%s" % [int(event.get("minute", 0)),
			(" " + name) if not name.is_empty() else ""]
		var card := bool(event.get("card", false))
		if card:
			var chip_x := edge if home_side else edge - 10.0
			draw_rect(Rect2(chip_x, baseline - 12.0, 10.0, 14.0),
				Color(0.92, 0.13, 0.16), true)
			draw_rect(Rect2(chip_x, baseline - 12.0, 10.0, 14.0),
				Color(0, 0, 0, 0.65), false, 1.0)
		var text_width := width - (16.0 if card else 0.0)
		var text_x := edge + (16.0 if card else 0.0)
		if not home_side:
			text_x = edge - (16.0 if card else 0.0) - text_width
		draw_string(_event_font, Vector2(text_x, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT if home_side else HORIZONTAL_ALIGNMENT_RIGHT,
			text_width, _font_size, UiTokens.FOCUS_INK_2)


func _draw_side(team: Dictionary, crest_rect: Rect2, name_x: float, name_right: float,
		alignment: int) -> void:
	var texture := UiAssets.package_crest(team)
	if texture != null:
		var source := texture.get_size()
		if source.x > 0.0 and source.y > 0.0:
			var scale := minf(crest_rect.size.x / source.x, crest_rect.size.y / source.y)
			var drawn := source * scale
			draw_texture_rect(texture,
				Rect2(crest_rect.position + (crest_rect.size - drawn) * 0.5, drawn), false)
	var name := str(team.get("name", ""))
	var short := str(team.get("short_name", ""))
	if name.is_empty():
		name = short
	# Long club names would run into the score; fall back to the short tag.
	var available := maxf(0.0, name_right - name_x)
	if not short.is_empty() and _name_font.get_string_size(
			name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x > available:
		name = short
	draw_string(_name_font, Vector2(name_x, crest_rect.position.y + 40.0),
		name, alignment, available, NAME_SIZE, UiTokens.FOCUS_INK)
