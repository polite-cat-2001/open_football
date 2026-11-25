class_name MatchScoreboard
extends Control
# In-match broadcast scoreboard: home crest, score, away crest and the match
# clock on one compact dark plate (4% of the 1080p design height, ticket 07).
# Draw-only; GpfHud pushes the snapshot values and the package crests.

const PLATE_H := 44.0
const CREST := 30.0
const PAD := 12.0
const GAP := 8.0
const SCORE_W := 80.0
const DIVIDER_GAP := 12.0
const CLOCK_W := 70.0
const SCORE_SIZE := 26
const CLOCK_SIZE := 26
const CARD_W := 9.0
const CARD_H := 14.0
const CARD_GAP := 3.0
const CARD_STRIP := 17.0

var score0 := 0
var score1 := 1
var clock_text := "00:00"
var red_cards0 := 0
var red_cards1 := 0
var home_crest: Texture2D
var away_crest: Texture2D
var home_tint := Color(0.96, 0.97, 0.98, 0.14)
var away_tint := Color(0.96, 0.97, 0.98, 0.14)

var _score_font: Font = UiTheme.barlow(800)
var _clock_font: Font = UiTheme.barlow(800)
var _plate := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The crests are 180 px originals drawn at 30 px; mipmaps keep them from
	# aliasing into noise.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size = Vector2(PAD * 2 + CREST * 2 + SCORE_W + GAP * 2 + DIVIDER_GAP * 2 + CLOCK_W, PLATE_H)
	_plate.bg_color = Color(UiTokens.FOCUS_FILL, 0.92)
	_plate.set_corner_radius_all(6)
	_plate.border_width_bottom = 3
	_plate.border_color = UiTokens.RAIL
	resized.connect(queue_redraw)


func set_teams(home: Dictionary, away: Dictionary) -> void:
	home_crest = UiAssets.package_crest(home)
	away_crest = UiAssets.package_crest(away)
	home_tint = _tint(home)
	away_tint = _tint(away)
	queue_redraw()


func apply(new_score0: int, new_score1: int, new_clock: String) -> void:
	if new_score0 == score0 and new_score1 == score1 and new_clock == clock_text:
		return
	score0 = new_score0
	score1 = new_score1
	clock_text = new_clock
	queue_redraw()


func set_cards(new_red0: int, new_red1: int) -> void:
	if new_red0 == red_cards0 and new_red1 == red_cards1:
		return
	red_cards0 = new_red0
	red_cards1 = new_red1
	# Cards hang below the plate; the control grows so they never cover a crest.
	size.y = PLATE_H + (CARD_STRIP if red_cards0 + red_cards1 > 0 else 0.0)
	queue_redraw()


func _draw() -> void:
	draw_style_box(_plate, Rect2(0.0, 0.0, size.x, PLATE_H))
	_draw_cards(red_cards0, true)
	_draw_cards(red_cards1, false)
	var x := PAD
	_draw_crest(home_crest, home_tint, Rect2(x, (PLATE_H - CREST) * 0.5, CREST, CREST))
	x += CREST + GAP
	draw_string(_score_font, Vector2(x, _baseline(_score_font, SCORE_SIZE)),
		"%d - %d" % [score0, score1], HORIZONTAL_ALIGNMENT_CENTER, SCORE_W,
		SCORE_SIZE, UiTokens.FOCUS_INK)
	x += SCORE_W + GAP
	_draw_crest(away_crest, away_tint, Rect2(x, (PLATE_H - CREST) * 0.5, CREST, CREST))
	x += CREST + DIVIDER_GAP
	draw_line(Vector2(x, 8.0), Vector2(x, PLATE_H - 8.0), Color(UiTokens.FOCUS_INK, 0.18), 1.0)
	x += DIVIDER_GAP
	draw_string(_clock_font, Vector2(x, _baseline(_clock_font, CLOCK_SIZE)),
		clock_text, HORIZONTAL_ALIGNMENT_CENTER, CLOCK_W, CLOCK_SIZE, UiTokens.FOCUS_INK)


func _tint(team: Dictionary) -> Color:
	var tint: Vector3 = team.get("color1", Vector3.ZERO)
	if tint == Vector3.ZERO:
		return Color(0.96, 0.97, 0.98, 0.14)
	return Color(tint.x, tint.y, tint.z, 0.35)


# draw_string places the baseline, so centre the digits' ink (not the font line
# box, which reserves descender space) on the plate.
func _baseline(font: Font, font_size: int) -> float:
	var interface := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var glyph := interface.font_get_glyph_index(rid, font_size, "0".unicode_at(0), 0)
	var ink := interface.font_get_glyph_size(rid, Vector2i(font_size, 0), glyph)
	var bearing := interface.font_get_glyph_offset(rid, Vector2i(font_size, 0), glyph)
	return PLATE_H * 0.5 - (bearing.y + ink.y * 0.5)


func _draw_crest(texture: Texture2D, tint: Color, rect: Rect2) -> void:
	if texture == null:
		draw_rect(rect, tint, true)
		return
	var source := texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return
	var scale := minf(rect.size.x / source.x, rect.size.y / source.y)
	var drawn := source * scale
	draw_texture_rect(texture, Rect2(rect.position + (rect.size - drawn) * 0.5, drawn), false)


func _draw_cards(count: int, home: bool) -> void:
	var shown := mini(count, 5)
	if shown <= 0:
		return
	var width := shown * CARD_W + (shown - 1) * CARD_GAP
	var start := PAD if home else size.x - PAD - width
	for i in shown:
		var card := Rect2(start + i * (CARD_W + CARD_GAP), PLATE_H + 2.0, CARD_W, CARD_H)
		draw_rect(card, Color(0.92, 0.13, 0.16), true)
		draw_rect(card, Color(0, 0, 0, 0.65), false, 1.0)
