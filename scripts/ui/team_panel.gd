class_name TeamPanel
extends Control
# One side card of the team select screen. It only renders the snapshot data it
# is given (adapter owns state); the view owns focus and input.

const FIELD_COUNTRY := "country"
const FIELD_TEAM := "team"
const FIELD_COMPETITION := "competition"

var _country_block: TeamBlock
var _team_block: TeamBlock
var _competition_block: TeamBlock
var _cues := {}
var _owner_label: Label
var _country_name: Label
var _country_art: TextureRect
var _country_fallback: TextureRect
var _country_mark: Label
var _team_name: Label
var _crest: TextureRect
var _crest_fallback: TextureRect
var _stars: TeamStars
var _stat_labels: Array[Label] = []
var _stat_values: Array[Label] = []
var _competition_name: Label
var _competition_art: TextureRect
var _competition_fallback: TextureRect
var _ready_mark: Label

var _country_has_texture := false
var _competition_has_texture := false
var _crest_has_texture := false
var _is_ready := false
var _live := true
var _focus := ""
var _choices := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _country_name == null:
		_build()


func setup(data: Dictionary) -> void:
	if _country_name == null:
		_build()
	var label := str(data.get("label", "HOME"))
	var owner := str(data.get("owner", ""))
	_is_ready = bool(data.get("ready", false))
	_live = bool(data.get("live", false))
	_focus = str(data.get("focus", ""))
	_choices = data.get("choices", {})

	var country: Dictionary = data.get("country", {})
	var team: Dictionary = data.get("team", {})
	var competition: Dictionary = data.get("competition", {})
	var rating: Dictionary = data.get("rating", {})

	_country_name.text = _entry_name(country)
	_team_name.text = _entry_name(team)
	_competition_name.text = _entry_name(competition)
	_owner_label.text = owner
	_owner_label.visible = not owner.is_empty()
	_country_mark.text = label
	_ready_mark.text = "READY!"

	_country_has_texture = _set_entry(_country_art, _country_fallback, country, "globe")
	_fit_flag(_country_art)
	_crest_has_texture = _set_entry(_crest, _crest_fallback, team, "shirt")
	_competition_has_texture = _set_entry(
		_competition_art, _competition_fallback, competition, "shirt")

	_stars.set_stars(float(rating.get("stars", 0.0)))
	_set_stat(0, rating.get("attack"))
	_set_stat(1, rating.get("midfield"))
	_set_stat(2, rating.get("defence"))

	_apply_ready()
	_apply_colors()
	modulate.a = 1.0 if (_live or _is_ready) else UiTokens.TEAM_IDLE_ALPHA


func set_focus(field: String) -> void:
	if _focus == field:
		return
	_focus = field
	_apply_colors()


func country_name_text() -> String:
	return _country_name.text


func team_name_text() -> String:
	return _team_name.text


func competition_name_text() -> String:
	return _competition_name.text


func owner_text() -> String:
	return _owner_label.text if _owner_label.visible else ""


func stars_value() -> float:
	return _stars.stars


func focus_field() -> String:
	return _focus


func block_mode(field: String) -> int:
	return _block(field).mode


func cue_visible(field: String) -> bool:
	var cues: Dictionary = _cues.get(field, {})
	if cues.is_empty():
		return false
	return (cues["left"] as Polygon2D).visible and (cues["right"] as Polygon2D).visible


func cue_center_y(field: String) -> float:
	var cues: Dictionary = _cues.get(field, {})
	if cues.is_empty():
		return -1.0
	var polygon := (cues["left"] as Polygon2D).polygon
	return polygon[0].y if polygon.size() > 0 else -1.0


func cue_tip_x(field: String, left: bool) -> float:
	var cues: Dictionary = _cues.get(field, {})
	if cues.is_empty():
		return -1.0
	var polygon := (cues["left" if left else "right"] as Polygon2D).polygon
	if polygon.is_empty():
		return -1.0
	return polygon[0].x if left else polygon[1].x


func ready_marks_visible() -> bool:
	return _country_mark.visible and _ready_mark.visible


func crest_visible() -> bool:
	return _crest.visible or _crest_fallback.visible


func _build() -> void:
	var country_height := UiTokens.TEAM_PANEL_H * UiTokens.TEAM_BLOCK_COUNTRY_RATIO
	var competition_height := UiTokens.TEAM_PANEL_H * UiTokens.TEAM_BLOCK_COMPETITION_RATIO
	var team_height := UiTokens.TEAM_PANEL_H - country_height - competition_height \
		- UiTokens.TEAM_GAP * 2.0

	_country_block = _make_block("CountryBlock", 0.0, country_height)
	_team_block = _make_block("TeamBlock", country_height + UiTokens.TEAM_GAP, team_height)
	_competition_block = _make_block("CompetitionBlock",
		country_height + team_height + UiTokens.TEAM_GAP * 2.0, competition_height)

	_owner_label = _make_label(_country_block, "Owner", UiTokens.TEAM_SIDE_PAD,
		UiTokens.TEAM_OWNER_TOP, UiTokens.TEAM_CONTENT_W, UiTokens.TEAM_OWNER_H, &"TeamOwner")
	_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_country_name = _make_label(_country_block, "CountryName", UiTokens.TEAM_SIDE_PAD,
		UiTokens.TEAM_COUNTRY_NAME_TOP, UiTokens.TEAM_CONTENT_W,
		UiTokens.TEAM_COUNTRY_NAME_H, &"TeamCountry")
	_country_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var flag_x := (UiTokens.TEAM_PANEL_W - UiTokens.TEAM_FLAG_MAX_W) * 0.5
	_country_art = _make_art(_country_block, "CountryArt", flag_x,
		UiTokens.TEAM_COUNTRY_ART_TOP, UiTokens.TEAM_FLAG_MAX_W, UiTokens.TEAM_FLAG_H)
	var globe_x := (UiTokens.TEAM_PANEL_W - UiTokens.TEAM_FLAG_H) * 0.5
	_country_fallback = _make_art(_country_block, "CountryFallback", globe_x,
		UiTokens.TEAM_COUNTRY_ART_TOP, UiTokens.TEAM_FLAG_H, UiTokens.TEAM_FLAG_H)
	_add_cues(FIELD_COUNTRY, _country_block,
		UiTokens.TEAM_COUNTRY_ART_TOP + UiTokens.TEAM_FLAG_H * 0.5)
	_country_mark = _make_label(_country_block, "CountryMark", UiTokens.TEAM_SIDE_PAD,
		UiTokens.TEAM_COUNTRY_MARK_TOP, UiTokens.TEAM_CONTENT_W, UiTokens.TEAM_MARK_H,
		&"TeamMark")
	_country_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_team_name = _make_label(_team_block, "TeamName", UiTokens.TEAM_SIDE_PAD,
		UiTokens.TEAM_TEAM_NAME_TOP, UiTokens.TEAM_CONTENT_W,
		UiTokens.TEAM_TEAM_NAME_H, &"TeamClub")
	_team_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var crest_x := (UiTokens.TEAM_PANEL_W - UiTokens.TEAM_ART) * 0.5
	_crest = _make_art(_team_block, "Crest", crest_x, UiTokens.TEAM_CREST_TOP,
		UiTokens.TEAM_ART, UiTokens.TEAM_ART)
	_crest_fallback = _make_art(_team_block, "CrestFallback", crest_x,
		UiTokens.TEAM_CREST_TOP, UiTokens.TEAM_ART, UiTokens.TEAM_ART)
	_add_cues(FIELD_TEAM, _team_block, UiTokens.TEAM_CREST_TOP + UiTokens.TEAM_ART * 0.5)
	_stars = TeamStars.new()
	_stars.name = "Stars"
	_stars.position = Vector2(crest_x, UiTokens.TEAM_STARS_TOP)
	_stars.size = Vector2(UiTokens.TEAM_ART, UiTokens.TEAM_STARS_H)
	_team_block.add_child(_stars)
	_build_stats(crest_x, UiTokens.TEAM_STATS_TOP)

	_competition_name = _make_label(_competition_block, "CompetitionName",
		UiTokens.TEAM_SIDE_PAD, UiTokens.TEAM_COMP_NAME_TOP, UiTokens.TEAM_CONTENT_W,
		UiTokens.TEAM_COMP_NAME_H, &"TeamCompetition")
	_competition_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var competition_x := (UiTokens.TEAM_PANEL_W - UiTokens.TEAM_COMP_ART_W) * 0.5
	_competition_art = _make_art(_competition_block, "CompetitionArt", competition_x,
		UiTokens.TEAM_COMP_ART_TOP, UiTokens.TEAM_COMP_ART_W, UiTokens.TEAM_COMP_ART_H)
	_competition_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var fallback_x := (UiTokens.TEAM_PANEL_W - UiTokens.TEAM_LEAGUE_MAX_W) * 0.5
	_competition_fallback = _make_art(_competition_block, "CompetitionFallback",
		fallback_x, UiTokens.TEAM_COMP_FALLBACK_TOP, UiTokens.TEAM_LEAGUE_MAX_W,
		UiTokens.TEAM_LEAGUE_H)
	_add_cues(FIELD_COMPETITION, _competition_block,
		UiTokens.TEAM_COMP_ART_TOP + UiTokens.TEAM_COMP_ART_H * 0.5)
	_ready_mark = _make_label(_competition_block, "ReadyMark", UiTokens.TEAM_SIDE_PAD,
		UiTokens.TEAM_READY_MARK_TOP, UiTokens.TEAM_CONTENT_W,
		UiTokens.TEAM_READY_MARK_H, &"TeamMarkReady")
	_ready_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_mark.text = "READY!"


func _make_block(node_name: String, top: float, height: float) -> TeamBlock:
	var block := TeamBlock.new()
	block.name = node_name
	block.position = Vector2(0.0, top)
	block.size = Vector2(UiTokens.TEAM_PANEL_W, height)
	add_child(block)
	return block


func _add_cues(field: String, block: TeamBlock, center_y: float) -> void:
	var half := UiTokens.TEAM_CUE_H * 0.5
	var art_left := (UiTokens.TEAM_PANEL_W - UiTokens.TEAM_ART) * 0.5
	var left_base := art_left - UiTokens.TEAM_CUE_GAP
	var left_tip := left_base - UiTokens.TEAM_CUE_W
	var right_base := art_left + UiTokens.TEAM_ART + UiTokens.TEAM_CUE_GAP
	var right_tip := right_base + UiTokens.TEAM_CUE_W
	var left := Polygon2D.new()
	left.polygon = PackedVector2Array([
		Vector2(left_tip, center_y),
		Vector2(left_base, center_y - half),
		Vector2(left_base, center_y + half),
	])
	left.color = UiTokens.FOCUS_MARK
	left.visible = false
	block.add_child(left)
	var right := Polygon2D.new()
	right.polygon = PackedVector2Array([
		Vector2(right_base, center_y - half),
		Vector2(right_tip, center_y),
		Vector2(right_base, center_y + half),
	])
	right.color = UiTokens.FOCUS_MARK
	right.visible = false
	block.add_child(right)
	_cues[field] = {"left": left, "right": right}


func _set_cues(field: String, visible: bool) -> void:
	var cues: Dictionary = _cues.get(field, {})
	if cues.is_empty():
		return
	(cues["left"] as Polygon2D).visible = visible
	(cues["right"] as Polygon2D).visible = visible


func _make_label(parent: Control, node_name: String, x: float, y: float,
		width: float, height: float, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.position = Vector2(x, y)
	label.size = Vector2(width, height)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _make_art(parent: Control, node_name: String, x: float, y: float,
		width: float, height: float) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.position = Vector2(x, y)
	art.size = Vector2(width, height)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(art)
	return art


func _build_stats(x: float, y: float) -> void:
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.position = Vector2(x, y)
	stats.size = Vector2(UiTokens.TEAM_ART, UiTokens.TEAM_STATS_H)
	stats.add_theme_constant_override(&"separation", int(UiTokens.TEAM_STATS_SEP))
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_team_block.add_child(stats)
	for index in 3:
		var column := VBoxContainer.new()
		column.name = ["Attack", "Midfield", "Defence"][index]
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override(&"separation", int(UiTokens.TEAM_STAT_GAP))
		stats.add_child(column)
		var label := Label.new()
		label.theme_type_variation = &"TeamStatLabel"
		label.text = ["ATT", "MID", "DEF"][index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
		var value := Label.new()
		value.theme_type_variation = &"TeamStatValue"
		value.text = "—"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(value)
		_stat_labels.append(label)
		_stat_values.append(value)


func _entry_name(entry: Dictionary) -> String:
	var name := str(entry.get("name", "")).strip_edges()
	return name.to_upper() if not name.is_empty() else "—"


func _set_entry(art: TextureRect, fallback: TextureRect, entry: Dictionary,
		fallback_icon: String) -> bool:
	var name := str(entry.get("name", "")).strip_edges()
	var texture = entry.get("texture", null)
	if texture is Texture2D:
		art.texture = texture
		art.visible = true
		fallback.visible = false
		return true
	art.texture = null
	art.visible = false
	fallback.texture = UiIcon.texture(fallback_icon)
	fallback.visible = not name.is_empty()
	return false


func _fit_flag(art: TextureRect) -> void:
	if art.texture == null:
		return
	var aspect := float(art.texture.get_width()) / float(art.texture.get_height())
	var width := minf(UiTokens.TEAM_FLAG_MAX_W, UiTokens.TEAM_FLAG_H * aspect)
	art.size = Vector2(width, UiTokens.TEAM_FLAG_H)
	art.position.x = (UiTokens.TEAM_PANEL_W - width) * 0.5
	art.stretch_mode = TextureRect.STRETCH_SCALE


func _set_stat(index: int, value) -> void:
	if value == null:
		_stat_values[index].text = "—"
		return
	_stat_values[index].text = str(int(value))


func _block(field: String) -> TeamBlock:
	match field:
		FIELD_COUNTRY:
			return _country_block
		FIELD_COMPETITION:
			return _competition_block
		_:
			return _team_block


func _apply_ready() -> void:
	_country_name.visible = not _is_ready
	_country_art.visible = not _is_ready and _country_has_texture
	_country_fallback.visible = not _is_ready and not _country_has_texture \
		and _country_name.text != "—"
	_country_mark.visible = _is_ready
	_competition_name.visible = not _is_ready
	_competition_art.visible = not _is_ready and _competition_has_texture
	_competition_fallback.visible = not _is_ready and not _competition_has_texture \
		and _competition_name.text != "—"
	_ready_mark.visible = _is_ready


func _apply_colors() -> void:
	var live_focus := _live and not _is_ready and not _focus.is_empty()
	var dark_team := _is_ready or (live_focus and _focus == FIELD_TEAM)
	var focus_country := live_focus and _focus == FIELD_COUNTRY
	var focus_competition := live_focus and _focus == FIELD_COMPETITION

	_country_block.set_mode(_block_mode(FIELD_COUNTRY))
	_team_block.set_mode(_block_mode(FIELD_TEAM))
	_competition_block.set_mode(_block_mode(FIELD_COMPETITION))
	_set_cues(FIELD_COUNTRY, focus_country and _has_choice(FIELD_COUNTRY))
	_set_cues(FIELD_TEAM, dark_team and not _is_ready and _has_choice(FIELD_TEAM))
	_set_cues(FIELD_COMPETITION, focus_competition and _has_choice(FIELD_COMPETITION))

	_country_name.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if focus_country else UiTokens.INK)
	_team_name.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK if _is_ready else (
			UiTokens.FOCUS_MARK if dark_team else UiTokens.INK))
	_competition_name.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if focus_competition else UiTokens.INK)
	_owner_label.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK_2 if (_is_ready or focus_country) else UiTokens.INK_2)
	for label in _stat_labels:
		label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if dark_team else UiTokens.INK_2)
	for value in _stat_values:
		value.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if dark_team else UiTokens.INK)

	_stars.set_on_dark(dark_team)
	_tint_fallback(_country_fallback, focus_country, _is_ready)
	_tint_fallback(_competition_fallback, focus_competition, _is_ready)
	_tint_fallback(_crest_fallback, dark_team, _is_ready)


func _has_choice(field: String) -> bool:
	return int(_choices.get(field, 0)) > 1


func _block_mode(field: String) -> int:
	if _is_ready:
		return TeamBlock.Mode.DARK
	if _live and not _focus.is_empty() and _focus == field:
		return TeamBlock.Mode.FOCUS
	return TeamBlock.Mode.NORMAL


func _tint_fallback(art: TextureRect, focused: bool, ready: bool) -> void:
	if ready:
		art.modulate = UiTokens.FOCUS_INK
	elif focused:
		art.modulate = UiTokens.FOCUS_MARK
	else:
		art.modulate = UiTokens.INK
