class_name CareerHubNextTile
extends BentoTile
# Centre "Next match" hero tile: eyebrow + headline, month, a week strip with
# the fixture day marked, the fixture itself and the recent-form pills. Ported
# from the prototype's NextMatchTile.svelte; uses BentoTile for the plate,
# rail, focus state and selected push.

const PAD := 24.0
const DAY_H := 56.0
const CREST := 42.0
const PILL := 28.0
const PILL_GAP := 6.0

var _eyebrow: Label
var _headline: Label
var _month: Label
var _days: Control
var _track: Control
var _day_cells: Array = []
var _day_keys: Array = []
var _day_offset := 0
var _offset_tween: Tween
var _match_crest: Texture2D
var _fixture: Control
var _home_crest: TextureRect
var _away_crest: TextureRect
var _home_name: Label
var _away_name: Label
var _vs: Label
var _meta: Label
var _form: Control
var _pills: Array = []


func _ready() -> void:
	super._ready()
	_eyebrow = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_eyebrow.text = "CALENDAR"
	_headline = _label(52, UiTheme.barlow(800), UiTokens.INK)
	_month = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_month.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_days = Control.new()
	_days.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_days.clip_contents = true
	_track = Control.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_days.add_child(_track)
	_fixture = Control.new()
	_fixture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_crest = _crest_rect()
	_away_crest = _crest_rect()
	_home_name = _label(24, UiTheme.barlow(700), UiTokens.INK)
	_home_name.clip_text = true
	_away_name = _label(24, UiTheme.barlow(700), UiTokens.INK)
	_away_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_away_name.clip_text = true
	_vs = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta = _label(16, UiTheme.inter(500), UiTokens.INK_2)
	_meta.clip_text = true
	_form = Control.new()
	_form.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixture.add_child(_home_crest)
	_fixture.add_child(_away_crest)
	_fixture.add_child(_home_name)
	_fixture.add_child(_away_name)
	_fixture.add_child(_vs)
	add_child(_eyebrow)
	add_child(_headline)
	add_child(_month)
	add_child(_days)
	add_child(_fixture)
	add_child(_meta)
	add_child(_form)
	_layout_content()


func setup(model: Dictionary) -> void:
	if _eyebrow == null:
		return
	_eyebrow.text = str(model.get("eyebrow", ""))
	_headline.text = str(model.get("title", ""))
	_month.text = str(model.get("month", ""))
	_home_name.text = str(model.get("home_name", "")).to_upper()
	_away_name.text = str(model.get("away_name", "")).to_upper()
	_home_crest.texture = _logo(str(model.get("home_logo", "")))
	_away_crest.texture = _logo(str(model.get("away_logo", "")))
	_match_crest = _logo(str(model.get("opponent_logo", "")))
	_meta.text = str(model.get("meta", ""))
	var complete := bool(model.get("season_complete", false))
	_days.visible = not complete
	_fixture.visible = not complete
	_form.visible = not complete
	_day_offset = int(model.get("day_offset", 0))
	var changed := _build_days(model.get("days", []))
	if changed:
		_days.modulate.a = 1.0
	else:
		_slide_to(_day_offset)
	_build_form(model.get("form", []))
	if changed and size.x > 0.0:
		_layout_content()
	_apply_state(false)


func _build_days(days: Array) -> bool:
	var keys: Array = []
	for day in days:
		keys.append(str(day.get("key", "")))
	if keys == _day_keys:
		for index in range(mini(_day_cells.size(), days.size())):
			_day_cells[index]["today"] = bool(days[index].get("today", false))
			_day_cells[index]["match"] = bool(days[index].get("match", false))
		return false
	for cell in _day_cells:
		cell["panel"].queue_free()
	_day_cells.clear()
	_day_keys = keys
	for day in days:
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override(&"panel", _day_box(false, false))
		var week := _label(10, UiTheme.inter(600), UiTokens.FOCUS_INK_2)
		week.text = str(day.get("weekday", ""))
		week.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var number := _label(22, UiTheme.barlow(700), UiTokens.FOCUS_INK)
		number.text = str(int(day.get("day", 0)))
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(week)
		panel.add_child(number)
		var crest: TextureRect = null
		if bool(day.get("match", false)):
			crest = _crest_rect()
			crest.texture = _match_crest
			panel.add_child(crest)
		_track.add_child(panel)
		_day_cells.append({
			"panel": panel, "week": week, "number": number, "crest": crest,
			"today": bool(day.get("today", false)),
			"match": bool(day.get("match", false)),
		})
	return true


func _build_form(form: Array) -> void:
	for pill in _pills:
		pill["panel"].queue_free()
	_pills.clear()
	for item in form:
		var outcome := str(item.get("outcome", ""))
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := _label(15, UiTheme.inter(700), UiTokens.INK)
		label.text = outcome
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		_form.add_child(panel)
		_pills.append({"panel": panel, "label": label})


func _layout_content() -> void:
	super._layout_content()
	if _eyebrow == null or size.x <= 0.0:
		return
	var width := size.x
	_eyebrow.position = Vector2(PAD, 14.0)
	_eyebrow.size = Vector2(width - PAD * 2.0, 20.0)
	_headline.position = Vector2(PAD, 34.0)
	_headline.size = Vector2(width - PAD * 2.0, 62.0)
	_month.position = Vector2(width - PAD - 160.0, 16.0)
	_month.size = Vector2(160.0, 20.0)

	_days.position = Vector2(PAD, 106.0)
	_days.size = Vector2(width - PAD * 2.0, DAY_H)
	var gap := 3.0
	var cell_width := _cell_width(width, gap)
	_track.position = Vector2(-float(_day_offset) * (cell_width + gap), 0.0)
	_track.size = Vector2(_day_cells.size() * (cell_width + gap), DAY_H)
	for index in range(_day_cells.size()):
		var cell: Dictionary = _day_cells[index]
		var panel: Panel = cell["panel"]
		panel.position = Vector2(index * (cell_width + gap), 0.0)
		panel.size = Vector2(cell_width, DAY_H)
		var week: Label = cell["week"]
		week.position = Vector2(0.0, 6.0)
		week.size = Vector2(cell_width, 14.0)
		var number: Label = cell["number"]
		number.position = Vector2(0.0, 20.0)
		number.size = Vector2(cell_width, 30.0)
		var crest: TextureRect = cell["crest"]
		if crest != null:
			crest.position = Vector2(cell_width - 26.0, 4.0)
			crest.size = Vector2(22.0, 22.0)
		panel.add_theme_stylebox_override(
			&"panel", _day_box(bool(cell["today"]), bool(cell["match"]),
				has_focus() and not disabled))

	_fixture.position = Vector2(PAD, 176.0)
	_fixture.size = Vector2(width - PAD * 2.0, CREST)
	var inner := width - PAD * 2.0
	_home_crest.position = Vector2.ZERO
	_home_crest.size = Vector2(CREST, CREST)
	_away_crest.position = Vector2(inner - CREST, 0.0)
	_away_crest.size = Vector2(CREST, CREST)
	_vs.position = Vector2(inner * 0.5 - 24.0, 0.0)
	_vs.size = Vector2(48.0, CREST)
	_home_name.position = Vector2(CREST + 10.0, 0.0)
	_home_name.size = Vector2(inner * 0.5 - CREST - 44.0, CREST)
	_away_name.position = Vector2(inner * 0.5 + 34.0, 0.0)
	_away_name.size = Vector2(inner * 0.5 - CREST - 44.0, CREST)

	_meta.position = Vector2(PAD, size.y - 44.0)
	_meta.size = Vector2(width - PAD * 2.0 - 190.0, 20.0)
	var pills_width := _pills.size() * PILL + maxi(0, _pills.size() - 1) * PILL_GAP
	_form.position = Vector2(width - PAD - pills_width, size.y - 48.0)
	_form.size = Vector2(pills_width, PILL)
	for index in range(_pills.size()):
		var pill: Dictionary = _pills[index]
		var panel: Panel = pill["panel"]
		panel.position = Vector2(index * (PILL + PILL_GAP), 0.0)
		panel.size = Vector2(PILL, PILL)
		var label: Label = pill["label"]
		label.position = Vector2.ZERO
		label.size = Vector2(PILL, PILL)


func _cell_width(width: float, gap: float) -> float:
	return (width - PAD * 2.0 - gap * 6.0) / 7.0


func _slide_to(offset: int) -> void:
	if _track == null or size.x <= 0.0:
		return
	var gap := 3.0
	var target := -float(offset) * (_cell_width(size.x, gap) + gap)
	if _offset_tween != null and _offset_tween.is_valid():
		_offset_tween.kill()
	if UiTransition.instant:
		_track.position.x = target
		return
	_offset_tween = create_tween()
	_offset_tween.tween_property(_track, "position:x", target, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func play_advance_in() -> void:
	if _days == null or size.x <= 0.0:
		return
	if _offset_tween != null and _offset_tween.is_valid():
		_offset_tween.kill()
	var gap := 3.0
	var target := -float(_day_offset) * (_cell_width(size.x, gap) + gap)
	if UiTransition.instant:
		_days.modulate.a = 1.0
		_track.position.x = target
		return
	_days.modulate.a = 0.0
	_track.position.x = target + 10.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_days, "modulate:a", 1.0, 0.22)
	tween.tween_property(_track, "position:x", target, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_state(animate: bool) -> void:
	super._apply_state(animate)
	if _eyebrow == null:
		return
	var focused := has_focus() and not disabled
	var ink := UiTokens.FOCUS_INK if focused else UiTokens.INK
	var ink_2 := UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
	for label in [_eyebrow, _month, _vs, _meta]:
		label.add_theme_color_override(&"font_color", ink_2)
	for label in [_headline, _home_name, _away_name]:
		label.add_theme_color_override(&"font_color", ink)
	for cell in _day_cells:
		(cell["week"] as Label).add_theme_color_override(&"font_color", ink_2)
		(cell["number"] as Label).add_theme_color_override(&"font_color", ink)
		(cell["panel"] as Panel).add_theme_stylebox_override(
			&"panel", _day_box(bool(cell["today"]), bool(cell["match"]), focused))
	for pill in _pills:
		(pill["label"] as Label).add_theme_color_override(&"font_color", ink)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.FOCUS_INK, 0.14) if focused \
			else Color(UiTokens.INK, 0.12)
		(pill["panel"] as Panel).add_theme_stylebox_override(&"panel", box)


func _day_box(today: bool, is_match: bool, focused := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if today or is_match:
		box.bg_color = Color(UiTokens.FOCUS_INK, 0.18) if focused \
			else Color(UiTokens.FOCUS_FILL, 0.10)
	else:
		box.bg_color = Color(UiTokens.FOCUS_INK, 0.055) if focused \
			else Color(UiTokens.INK, 0.035)
	return box


func _crest_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return rect


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
	return UiAssets.usable_texture(
		UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
