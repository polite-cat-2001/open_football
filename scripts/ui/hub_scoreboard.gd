class_name HubScoreboard
extends Control
# Prototype MatchHub scoreboard: competition/meta line and two club blocks with
# crest, stars and ATT/MID/DEF. It reuses TeamStars for the rating row.

const CLUB_COUNT := 2

var _meta: Label
var _meta_strong: Label
var _clubs: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_layout()


func setup(state: Dictionary) -> void:
	var meta: Dictionary = state.get("meta", {})
	var competition := str(meta.get("competition", "FRIENDLY")).to_upper()
	var difficulty := float(meta.get("difficulty", 0.8))
	var duration := float(meta.get("duration", 1.0))
	_meta.text = competition
	_meta_strong.text = "DIFFICULTY %.2f  ·  ~%d MIN" % [
		difficulty, 5 + int(round(20.0 * duration))
	]
	var sides: Array = state.get("sides", [])
	for index in CLUB_COUNT:
		_apply_club(index, sides[index] if index < sides.size() else {})
	_layout()


func _build() -> void:
	_meta = _label(&"HubMeta", HORIZONTAL_ALIGNMENT_CENTER)
	_meta_strong = _label(&"HubMetaStrong", HORIZONTAL_ALIGNMENT_CENTER)
	for index in CLUB_COUNT:
		var club := {
			"venue": _label(&"HubVenue", HORIZONTAL_ALIGNMENT_CENTER),
			"name": _label(&"HubTeamName", HORIZONTAL_ALIGNMENT_CENTER),
			"crest": TextureRect.new(),
			"stars": TeamStars.new(),
			"stats": [],
		}
		var crest: TextureRect = club["crest"]
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(crest)
		var stars: TeamStars = club["stars"]
		stars.on_dark = true
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stars)
		for stat_index in 3:
			var caption := _label(&"HubStatLabel", HORIZONTAL_ALIGNMENT_CENTER)
			var value := _label(&"HubStatValue", HORIZONTAL_ALIGNMENT_CENTER)
			caption.text = ["ATT", "MID", "DEF"][stat_index]
			value.text = "—"
			(club["stats"] as Array).append({"caption": caption, "value": value})
		_clubs.append(club)


func _label(variation: StringName, alignment: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _apply_club(index: int, side: Dictionary) -> void:
	var club: Dictionary = _clubs[index]
	var team: Dictionary = side.get("team", {})
	var rating: Dictionary = team.get("rating", {})
	(club["venue"] as Label).text = "HOME" if index == 0 else "AWAY"
	(club["name"] as Label).text = str(team.get("name", "—")).to_upper()
	var crest: TextureRect = club["crest"]
	var texture: Texture2D = team.get("texture")
	if texture != null:
		crest.texture = texture
		crest.modulate = Color.WHITE
	else:
		crest.texture = UiIcon.texture("shirt")
		crest.modulate = UiTokens.FOCUS_INK_2
	var stars: TeamStars = club["stars"]
	stars.set_stars(float(rating.get("stars", 0.0)))
	var values := [rating.get("attack", "—"), rating.get("midfield", "—"),
		rating.get("defence", "—")]
	var stats: Array = club["stats"]
	for stat_index in stats.size():
		var value_label: Label = stats[stat_index]["value"]
		var value = values[stat_index]
		value_label.text = "—" if value == null or str(value).is_empty() else str(value)


func _layout() -> void:
	if _meta == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var meta_h := _meta_height()
	_meta.position = Vector2(UiTokens.HUB_SCORE_META_SIDE, UiTokens.HUB_SCORE_META_TOP)
	_meta.size = Vector2(size.x - UiTokens.HUB_SCORE_META_SIDE * 2.0, 18.0)
	_meta_strong.position = _meta.position + Vector2(0.0, 18.0 + UiTokens.HUB_SCORE_META_GAP)
	_meta_strong.size = _meta.size
	var club_w := size.x * 0.5
	var area_h := size.y - meta_h
	var crest_size := clampf(size.y * 0.326, UiTokens.HUB_CREST_MIN, UiTokens.HUB_CREST_MAX)
	var stack_h := 18.0 + 80.0 + crest_size + UiTokens.HUB_STARS_H \
		+ UiTokens.HUB_STAT_LABEL_H + UiTokens.HUB_STAT_VALUE_H \
		+ UiTokens.HUB_SCORE_CLUB_GAP * 5.0
	var y := meta_h + (area_h - stack_h) * 0.5
	for index in CLUB_COUNT:
		var club: Dictionary = _clubs[index]
		var x := club_w * float(index)
		var content_x := x + UiTokens.HUB_SCORE_CLUB_SIDE
		var content_w := club_w - UiTokens.HUB_SCORE_CLUB_SIDE * 2.0
		(club["venue"] as Label).position = Vector2(content_x, y)
		(club["venue"] as Label).size = Vector2(content_w, 18.0)
		y += 18.0 + UiTokens.HUB_SCORE_CLUB_GAP
		(club["name"] as Label).position = Vector2(content_x, y)
		(club["name"] as Label).size = Vector2(content_w, 80.0)
		y += 80.0 + UiTokens.HUB_SCORE_CLUB_GAP
		var crest: TextureRect = club["crest"]
		crest.position = Vector2(x + (club_w - crest_size) * 0.5, y)
		crest.size = Vector2(crest_size, crest_size)
		y += crest_size + UiTokens.HUB_SCORE_CLUB_GAP
		var stars: TeamStars = club["stars"]
		var stars_w := minf(content_w, 210.0)
		stars.position = Vector2(x + (club_w - stars_w) * 0.5, y)
		stars.size = Vector2(stars_w, UiTokens.HUB_STARS_H)
		y += UiTokens.HUB_STARS_H + UiTokens.HUB_STATS_TOP
		var stats: Array = club["stats"]
		var stats_w := stars_w
		var stats_x := x + (club_w - stats_w) * 0.5
		var stat_w := (stats_w - UiTokens.HUB_STATS_SEP * 2.0) / 3.0
		for stat_index in stats.size():
			var entry: Dictionary = stats[stat_index]
			var stat_x := stats_x + (stat_w + UiTokens.HUB_STATS_SEP) * float(stat_index)
			(entry["caption"] as Label).position = Vector2(stat_x, y)
			(entry["caption"] as Label).size = Vector2(stat_w, UiTokens.HUB_STAT_LABEL_H)
			(entry["value"] as Label).position = Vector2(stat_x, y + UiTokens.HUB_STAT_LABEL_H)
			(entry["value"] as Label).size = Vector2(stat_w, UiTokens.HUB_STAT_VALUE_H)
		y = meta_h + (area_h - stack_h) * 0.5
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	var colors := PackedColorArray([
		UiTokens.HUB_PANEL_TOP,
		UiTokens.HUB_PANEL_TOP,
		UiTokens.HUB_PANEL_BOTTOM,
		UiTokens.HUB_PANEL_BOTTOM,
	])
	draw_polygon(points, colors)
	var meta_h := _meta_height()
	draw_line(Vector2(0.0, meta_h), Vector2(size.x, meta_h),
		UiTokens.HUB_DIVIDER_STRONG, 1.0)
	draw_line(Vector2(size.x * 0.5, meta_h), Vector2(size.x * 0.5, size.y),
		UiTokens.HUB_DIVIDER_STRONG, 1.0)


func _meta_height() -> float:
	return UiTokens.HUB_SCORE_META_TOP + 18.0 + UiTokens.HUB_SCORE_META_GAP + 18.0 \
		+ UiTokens.HUB_SCORE_META_BOTTOM


func crest_rect(side: int) -> Rect2:
	if side < 0 or side >= _clubs.size():
		return Rect2()
	var crest: TextureRect = _clubs[side]["crest"]
	return crest.get_global_rect()


func stars_value(side: int) -> float:
	if side < 0 or side >= _clubs.size():
		return 0.0
	return (_clubs[side]["stars"] as TeamStars).stars


func stars_rect(side: int) -> Rect2:
	if side < 0 or side >= _clubs.size():
		return Rect2()
	return (_clubs[side]["stars"] as TeamStars).get_global_rect()


func stats_rect(side: int) -> Rect2:
	if side < 0 or side >= _clubs.size():
		return Rect2()
	var rect := Rect2()
	var stats: Array = _clubs[side]["stats"]
	for entry in stats:
		var caption: Label = entry["caption"]
		var value: Label = entry["value"]
		var row: Rect2 = caption.get_global_rect().merge(value.get_global_rect())
		rect = row if rect.size == Vector2.ZERO else rect.merge(row)
	return rect


func team_name(side: int) -> String:
	if side < 0 or side >= _clubs.size():
		return ""
	return (_clubs[side]["name"] as Label).text


func meta_text() -> String:
	return _meta.text if _meta != null else ""


func meta_strong_text() -> String:
	return _meta_strong.text if _meta_strong != null else ""
