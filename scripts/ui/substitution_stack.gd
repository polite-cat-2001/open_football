class_name SubstitutionStack
extends Control
# Top-centre stack of applied substitutions (ticket 10). One white row per
# swap: the player going off with a red down arrow, the incoming one with a
# green up arrow. Newest on top, at most MAX_CARDS visible, each lives LIFE_SEC.
# Draw-only; GpfHud pushes the "X off, Y on" lines from the snapshot.

const MAX_CARDS := 3
const LIFE_SEC := 3.0
const OUT_TIME := 0.24
const CARD_H := 54.0
const GAP := 8.0
const PAD := 14.0
const ARROW := 14.0
const TEXT_SIZE := 18
const MIN_W := 260.0
const MAX_W := 560.0
const ENTER_TIME := 0.18
const CREST := 28.0
const CREST_GAP := 10.0

var entries: Array = []

var _name_font: Font = UiTheme.barlow(700)
var _home_crest: Texture2D
var _away_crest: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)


func set_crests(home: Texture2D, away: Texture2D) -> void:
	_home_crest = home
	_away_crest = away
	_resize()
	queue_redraw()


func push_lines(lines: Array, teams: Array = [], now_ms := -1) -> void:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	var added := false
	for i in lines.size():
		var parts := _parse(str(lines[i]))
		if parts.is_empty():
			continue
		parts["team"] = int(teams[i]) if i < teams.size() else -1
		# A thin client builds the same notice twice (snapshot counter and its
		# own roster delta); keep one card for that frame.
		if not entries.is_empty() and not bool(entries[0].get("leaving", false)) \
				and now_ms - int(entries[0]["shown_ms"]) < 1000 \
				and entries[0]["out"] == parts["out"] and entries[0]["in"] == parts["in"]:
			continue
		parts["shown_ms"] = now_ms
		parts["style"] = _card_style()
		entries.push_front(parts)
		added = true
	while entries.size() > MAX_CARDS:
		entries.pop_back()
	if added:
		visible = true
		_resize()
		queue_redraw()


func tick(now_ms := -1) -> void:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	var changed := false
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		if not bool(entry.get("leaving", false)):
			if (now_ms - int(entry["shown_ms"])) / 1000.0 >= LIFE_SEC:
				entry["leaving"] = true
				entry["leave_ms"] = now_ms
				changed = true
		elif (now_ms - int(entry["leave_ms"])) / 1000.0 >= OUT_TIME:
			entries.remove_at(i)
			changed = true
	if changed:
		_resize()
		queue_redraw()
	if entries.is_empty():
		visible = false


func reset() -> void:
	entries.clear()
	visible = false
	size = Vector2.ZERO


func has_entries() -> bool:
	return not entries.is_empty()


func _process(_delta: float) -> void:
	if not entries.is_empty():
		tick()
		queue_redraw()


func _parse(line: String) -> Dictionary:
	var clean := line.strip_edges()
	var split := clean.find(" off, ")
	if split >= 0:
		return {
			"out": clean.substr(0, split),
			"in": clean.substr(split + 6).trim_suffix(" on"),
		}
	if not clean.is_empty():
		return {"out": clean, "in": ""}
	return {}


func _resize() -> void:
	var width := MIN_W
	var crest_space := CREST + CREST_GAP if _home_crest != null or _away_crest != null else 0.0
	for entry in entries:
		for key in ["out", "in"]:
			var name := String(entry[key])
			if name.is_empty():
				continue
			var text_width := _name_font.get_string_size(
				name, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
			width = maxf(width, PAD * 2 + ARROW + 8.0 + text_width + crest_space)
	width = minf(width, MAX_W)
	size = Vector2(width, entries.size() * CARD_H + maxi(0, entries.size() - 1) * GAP)
	pivot_offset = Vector2()


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.border_width_left = 4
	style.border_color = UiTokens.RAIL
	return style


func _draw() -> void:
	var now := Time.get_ticks_msec()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var age := (now - int(entry["shown_ms"])) / 1000.0
		var slide := maxf(0.0, 1.0 - age / ENTER_TIME)
		var alpha := clampf(age / ENTER_TIME, 0.0, 1.0)
		var lift := 0.0
		if bool(entry.get("leaving", false)):
			var out_age := (now - int(entry["leave_ms"])) / 1000.0
			var fade := clampf(1.0 - out_age / OUT_TIME, 0.0, 1.0)
			alpha *= fade
			lift = (1.0 - fade) * 10.0
		var y := i * (CARD_H + GAP) - slide * 18.0 - lift
		var style: StyleBoxFlat = entry["style"]
		style.bg_color = Color(UiTokens.TILE, 0.96 * alpha)
		draw_style_box(style, Rect2(0.0, y, size.x, CARD_H))
		var crest := _crest_for(int(entry.get("team", -1)))
		if crest != null:
			_draw_crest(crest, Rect2(size.x - PAD - CREST, y + (CARD_H - CREST) * 0.5,
				CREST, CREST), alpha)
		var text_width := size.x - PAD * 2 - ARROW - 8.0 \
			- (CREST + CREST_GAP if crest != null else 0.0)
		var out_name := String(entry["out"])
		var in_name := String(entry["in"])
		# Centre the two text lines on the card: baselines from the font's own
		# ascent/height, not fixed offsets (Barlow's line box is not 20 px).
		var line_h := _name_font.get_height(TEXT_SIZE)
		var block_top := (CARD_H - line_h * 2.0) * 0.5
		var baseline := y + block_top + _name_font.get_ascent(TEXT_SIZE)
		if not out_name.is_empty():
			_draw_arrow(Vector2(PAD + ARROW * 0.5, baseline - 5.5), false, alpha)
			draw_string(_name_font, Vector2(PAD + ARROW + 8.0, baseline), out_name,
				HORIZONTAL_ALIGNMENT_LEFT, text_width,
				TEXT_SIZE, Color(UiTokens.INK, alpha))
		baseline += line_h
		if not in_name.is_empty():
			_draw_arrow(Vector2(PAD + ARROW * 0.5, baseline - 5.5), true, alpha)
			draw_string(_name_font, Vector2(PAD + ARROW + 8.0, baseline), in_name,
				HORIZONTAL_ALIGNMENT_LEFT, text_width,
				TEXT_SIZE, Color(UiTokens.INK, alpha))


func _crest_for(team: int) -> Texture2D:
	if team == 0:
		return _home_crest
	if team == 1:
		return _away_crest
	return null


func _draw_crest(texture: Texture2D, rect: Rect2, alpha: float) -> void:
	var source := texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return
	var scale := minf(rect.size.x / source.x, rect.size.y / source.y)
	var drawn := source * scale
	draw_texture_rect(texture, Rect2(rect.position + (rect.size - drawn) * 0.5, drawn),
		false, Color(1.0, 1.0, 1.0, alpha))


func _draw_arrow(centre: Vector2, up: bool, alpha: float) -> void:
	var color := Color(UiTokens.SIDE_TONES[3], alpha) if up \
		else Color(UiTokens.RAIL, alpha)
	var tip := centre + Vector2(0.0, -6.0 if up else 6.0)
	var tail := centre + Vector2(0.0, 5.0 if up else -5.0)
	draw_line(tail, tip, color, 2.5, true)
	draw_line(tip, tip + Vector2(-5.0, 5.0 if up else -5.0), color, 2.5, true)
	draw_line(tip, tip + Vector2(5.0, 5.0 if up else -5.0), color, 2.5, true)
