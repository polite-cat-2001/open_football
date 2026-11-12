class_name PauseScoreboard
extends Control
# Pause header: a dark scoreboard strip with both crests, the score and the
# frozen match clock. Data is pushed from PauseScreen on open; the control only
# draws.

const PAD := 36.0
const CREST := 104.0
const SCORE_SIZE := 64

var _home: Dictionary = {}
var _away: Dictionary = {}
var _score0 := 0
var _score1 := 0
var _clock := "00:00"
# Phase break replaces the frozen clock with the period caption (HALF TIME).
var _caption := ""

var _name_font: Font = UiTheme.barlow(800)
var _score_font: Font = UiTheme.barlow(800)
var _clock_font: Font = UiTheme.barlow(600)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(home: Dictionary, away: Dictionary, score0: int, score1: int,
		clock: String, caption := "") -> void:
	_home = home
	_away = away
	_score0 = score0
	_score1 = score1
	_clock = clock
	_caption = caption
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.FOCUS_FILL, 0.96), true)

	var center := size.x * 0.5
	_draw_crest(_home, Rect2(PAD, (size.y - CREST) * 0.5, CREST, CREST))
	_draw_crest(_away, Rect2(size.x - PAD - CREST, (size.y - CREST) * 0.5,
		CREST, CREST))

	if _caption.is_empty():
		draw_string(_clock_font, Vector2(center - 90.0, 34.0), _clock,
			HORIZONTAL_ALIGNMENT_CENTER, 180.0, 18, UiTokens.FOCUS_INK_2)
	else:
		draw_string(_name_font, Vector2(center - 240.0, 36.0), _caption,
			HORIZONTAL_ALIGNMENT_CENTER, 480.0, 22, UiTokens.FOCUS_MARK)

	var score_y := _score_baseline()
	draw_string(_score_font, Vector2(center - 74.0, score_y), str(_score0),
		HORIZONTAL_ALIGNMENT_CENTER, 52.0, SCORE_SIZE, UiTokens.FOCUS_INK)
	draw_string(_score_font, Vector2(center - 8.0, score_y), "-",
		HORIZONTAL_ALIGNMENT_CENTER, 16.0, 40, UiTokens.FOCUS_INK_2)
	draw_string(_score_font, Vector2(center + 22.0, score_y), str(_score1),
		HORIZONTAL_ALIGNMENT_CENTER, 52.0, SCORE_SIZE, UiTokens.FOCUS_INK)

	var side_left := PAD + CREST + 28.0
	var side_right := size.x - PAD - CREST - 28.0
	var gap_w := 120.0
	draw_string(_name_font, Vector2(side_left, score_y),
		_team_name(_home), HORIZONTAL_ALIGNMENT_RIGHT,
		maxf(0.0, center - gap_w - side_left), 40, UiTokens.FOCUS_INK)
	draw_string(_name_font, Vector2(center + gap_w, score_y),
		_team_name(_away), HORIZONTAL_ALIGNMENT_LEFT,
		maxf(0.0, side_right - center - gap_w), 40, UiTokens.FOCUS_INK)


func _team_name(team: Dictionary) -> String:
	return str(team.get("name", "")).to_upper()


# draw_string places the baseline, so centre the digits' actual ink (not the
# line box, which reserves descender space) on the widget's middle.
func _score_baseline() -> float:
	var interface := TextServerManager.get_primary_interface()
	var rid: RID = _score_font.get_rids()[0]
	var glyph := interface.font_get_glyph_index(rid, SCORE_SIZE, "0".unicode_at(0), 0)
	var ink := interface.font_get_glyph_size(rid, Vector2i(SCORE_SIZE, 0), glyph)
	var bearing := interface.font_get_glyph_offset(rid, Vector2i(SCORE_SIZE, 0), glyph)
	return size.y * 0.5 - (bearing.y + ink.y * 0.5)


func _draw_crest(team: Dictionary, rect: Rect2) -> void:
	var texture: Texture2D = null
	var path := str(team.get("logo_url", ""))
	if not path.is_empty():
		texture = UiAssets.usable_texture(UiAssets.load_texture(path))
	if texture == null:
		# The package logo_url points at the original data tree layout; the
		# imported crests live under images_teams/<team_id>.png.
		texture = UiAssets.usable_texture(UiAssets.team_logo(
			{"id": int(team.get("database_id", 0))}))
	if texture == null:
		var color := Color(0.96, 0.97, 0.98, 0.14)
		var tint: Vector3 = team.get("color1", Vector3.ZERO)
		if tint != Vector3.ZERO:
			color = Color(tint.x, tint.y, tint.z, 0.35)
		draw_rect(rect, color, true)
		return
	var source := texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return
	var scale := minf(rect.size.x / source.x, rect.size.y / source.y)
	var drawn := source * scale
	draw_texture_rect(texture,
		Rect2(rect.position + (rect.size - drawn) * 0.5, drawn), false)
