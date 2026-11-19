class_name CareerMatchOverlay
extends Control
# Full-body career match overlay: the pre-match/live/final simulation screen
# and the two-step matchday review (results -> table), ported from the
# prototype's MatchScreen/MatchdayScreen. The hub owns input, hints and the
# fade/scale transition; this node only draws.

const PAD := 24.0
const CREST := 42.0
const TABLE_ROW := 28.0
const HEAD_ROW := 26.0
# Event mark colours, the prototype's --mark-win/loss/warn.
const MARK_WIN := Color("2f7d4f")
const MARK_LOSS := Color("b23a48")
const MARK_WARN := Color("a66a00")

var _card: Panel
var _content: Control
var _open := false
var _card_rect := Rect2()
var _mode := ""
var _setup: Dictionary = {}
var _match: Dictionary = {}
var _phase := "setup"
var _minute := 0
var _matchday: Dictionary = {}
var _step := "results"
var _review: Dictionary = {}
var _review_step := 0
var _review_club: Dictionary = {}
var _review_center: Control
var _review_season_start := ""
var _table_scroll: ScrollContainer
var _ink := UiTokens.INK
var _ink_2 := UiTokens.INK_2


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = Panel.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.clip_contents = true
	add_child(_card)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.clip_contents = true
	_card.add_child(_content)


func render_simulation(setup: Dictionary, match: Dictionary, phase: String,
		minute: int) -> void:
	_mode = "simulation"
	_setup = setup
	_match = match
	_phase = phase
	_minute = minute
	_style_card("simulation")
	_render()


func render_matchday(data: Dictionary, step: String) -> void:
	_mode = "matchday"
	_matchday = data
	_step = step
	_style_card("matchday")
	_render()


func render_season_review(review: Dictionary, step: int, club: Dictionary,
		season_start: String) -> void:
	_mode = "review"
	_review = review
	_review_step = step
	_review_club = club
	_review_season_start = season_start
	_style_card("matchday")
	_render()


func layout_overlay(card_rect: Rect2) -> void:
	if _card == null:
		return
	_card_rect = card_rect
	_card.position = card_rect.position
	_card.size = card_rect.size
	_card.pivot_offset = card_rect.size * 0.5
	_content.position = Vector2(PAD, PAD)
	_content.size = card_rect.size - Vector2(PAD * 2.0, PAD * 2.0)
	if not _mode.is_empty():
		_render()


func open() -> void:
	_open = true
	visible = true
	move_to_front()
	_render()


func close() -> void:
	_open = false


func hide_card() -> void:
	visible = false


func card() -> Control:
	return _card


func is_open() -> bool:
	return _open


func phase() -> String:
	return _phase


func step() -> String:
	return _step


func scroll_step(direction: int) -> void:
	if _table_scroll == null or direction == 0:
		return
	_table_scroll.scroll_vertical = maxi(0,
		_table_scroll.scroll_vertical + int(signf(direction)) * int(TABLE_ROW))


# Event marker drawn in code, the prototype's EventGlyph (ball, card, sub arrow,
# injury cross). Colour comes from the mark type; the size is 14 in the lineups
# and 16 in the event feed.
class EventMark extends Control:
	var kind := "goal"
	var tint := Color.WHITE

	func setup(mark: String, color: Color, pixels: float) -> void:
		kind = mark
		tint = color
		custom_minimum_size = Vector2(pixels, pixels)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var s := size.x
		var c := size * 0.5
		var line := maxf(1.0, s * 0.09)
		var radius := s * 0.34
		match kind:
			"yellow", "red":
				draw_rect(Rect2(c - Vector2(s * 0.21, s * 0.33),
					Vector2(s * 0.42, s * 0.66)), tint, true)
			"sub-in", "sub-out":
				var up := kind == "sub-in"
				var tip := c + Vector2(0.0, -s * 0.34 if up else s * 0.34)
				var tail := c + Vector2(0.0, s * 0.34 if up else -s * 0.34)
				draw_line(tail, tip, tint, line)
				var wing := s * 0.20
				var wing_y := tip.y + (wing if up else -wing)
				draw_polyline(PackedVector2Array([
					Vector2(tip.x - wing, wing_y),
					tip,
					Vector2(tip.x + wing, wing_y),
				]), tint, line)
			"injury":
				draw_line(c - Vector2(s * 0.28, 0.0), c + Vector2(s * 0.28, 0.0), tint, line)
				draw_line(c - Vector2(0.0, s * 0.28), c + Vector2(0.0, s * 0.28), tint, line)
			"penalty":
				draw_arc(c, radius, 0.0, TAU, 24, tint, line)
				draw_line(c + Vector2(-s * 0.10, -s * 0.16),
					c + Vector2(-s * 0.10, s * 0.20), tint, line)
				draw_line(c + Vector2(-s * 0.10, -s * 0.16),
					c + Vector2(s * 0.15, -s * 0.16), tint, line)
				draw_line(c + Vector2(s * 0.15, -s * 0.16),
					c + Vector2(s * 0.15, s * 0.03), tint, line)
			_:
				draw_arc(c, radius, 0.0, TAU, 24, tint, line)
				draw_circle(c, s * 0.09, tint)


func _style_card(kind: String) -> void:
	var box := StyleBoxFlat.new()
	var simulation := kind == "simulation"
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0) if simulation else UiTokens.TILE
	box.shadow_size = 0 if simulation else 16
	box.shadow_color = UiTokens.SHADOW
	box.shadow_offset = Vector2(0.0, 12.0)
	_card.add_theme_stylebox_override(&"panel", box)
	_ink = UiTokens.INK
	_ink_2 = UiTokens.INK_2


func _render() -> void:
	if _content == null or _content.size.x <= 0.0:
		return
	for child in _content.get_children():
		child.free()
	_table_scroll = null
	if _mode == "simulation":
		_render_simulation()
	elif _mode == "matchday":
		var root := VBoxContainer.new()
		root.position = Vector2.ZERO
		root.size = _content.size
		root.add_theme_constant_override(&"separation", 16)
		_content.add_child(root)
		_render_matchday(root)
	elif _mode == "review":
		var root := VBoxContainer.new()
		root.position = Vector2.ZERO
		root.size = _content.size
		root.add_theme_constant_override(&"separation", 8)
		_content.add_child(root)
		_render_review(root)


# Match simulation (prototype MatchScreen): the dark scoreboard strip above two
# light lineup cards on the left, and the light side panel with the dark clock
# and the event feed on the right.
func _render_simulation() -> void:
	var data := _match if not _match.is_empty() else _setup
	var events := _visible_events()
	var stage := HBoxContainer.new()
	stage.position = Vector2.ZERO
	stage.size = _content.size
	stage.add_theme_constant_override(&"separation", int(UiTokens.GAP))
	_content.add_child(stage)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override(&"separation", int(UiTokens.GAP))
	main.add_child(_board(data, events))
	var lineups := HBoxContainer.new()
	lineups.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lineups.add_theme_constant_override(&"separation", int(UiTokens.GAP))
	lineups.add_child(_team_tile("home", _dict(data.get("home_team")),
		_dict(data.get("home_lineup")), events))
	lineups.add_child(_team_tile("away", _dict(data.get("away_team")),
		_dict(data.get("away_lineup")), events))
	main.add_child(lineups)
	stage.add_child(main)
	stage.add_child(_side_tile(data, events))


func _panel(dark: bool, left: float, right: float, top: float,
		bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_FILL if dark else UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 18
	box.shadow_offset = Vector2(0.0, 12.0)
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	panel.add_theme_stylebox_override(&"panel", box)
	return panel


func _board(data: Dictionary, events: Array) -> Control:
	var board := _panel(true, 20.0, 20.0, 12.0, 12.0)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 16)
	var competition := _label(16, UiTheme.inter(600), UiTokens.FOCUS_INK_2)
	competition.text = "%s · ROUND %d" % [
		str(data.get("competition", "")).to_upper(),
		int(data.get("round", 0)),
	]
	competition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	competition.clip_text = true
	competition.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var date := _label(16, UiTheme.inter(600), UiTokens.FOCUS_INK_2)
	date.text = _long_date(str(data.get("date", "")))
	top.add_child(competition)
	top.add_child(date)
	box.add_child(top)

	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 20)
	line.add_child(_board_club(_dict(data.get("home_team")), false))
	var centre := VBoxContainer.new()
	centre.custom_minimum_size.x = 190.0
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	var score := _label(52, UiTheme.barlow(800), UiTokens.FOCUS_INK)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.text = _score_label(events)
	var minute := _label(16, UiTheme.inter(600), UiTokens.FOCUS_INK_2)
	minute.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minute.text = _minute_label()
	centre.add_child(score)
	centre.add_child(minute)
	line.add_child(centre)
	line.add_child(_board_club(_dict(data.get("away_team")), true))
	box.add_child(line)
	board.add_child(box)
	return board


func _board_club(team: Dictionary, away: bool) -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN if away \
		else BoxContainer.ALIGNMENT_END
	var crest := _crest_rect()
	crest.custom_minimum_size = Vector2(54.0, 54.0)
	crest.texture = _logo(str(team.get("logo", "")))
	var name := _label(28, UiTheme.barlow(700), UiTokens.FOCUS_INK)
	name.text = str(team.get("name", "")).to_upper()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if away \
		else HORIZONTAL_ALIGNMENT_RIGHT
	if away:
		box.add_child(name)
		box.add_child(crest)
	else:
		box.add_child(crest)
		box.add_child(name)
	return box


func _score_label(events: Array) -> String:
	if _phase == "setup":
		return "VS"
	var goals := {"home": 0, "away": 0}
	for event in events:
		if str(event.get("type", "")) in ["goal", "penalty"]:
			goals[str(event.get("team", ""))] += 1
	return "%d : %d" % [goals["home"], goals["away"]]


func _minute_label() -> String:
	if _phase == "setup":
		return "Match not started"
	if _phase == "done":
		return "90 min."
	return "%d min." % _minute


func _team_tile(side: String, team: Dictionary, lineup: Dictionary,
		events: Array) -> Control:
	var panel := _panel(false, 16.0, 14.0, 6.0, 6.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	var team_label := _label(18, UiTheme.barlow(700), _ink)
	team_label.text = str(team.get("name", "")).to_upper()
	team_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_label.clip_text = true
	team_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var formation := _label(18, UiTheme.barlow(700), _ink_2)
	formation.text = str(lineup.get("formation_label", lineup.get("formation", "")))
	head.add_child(team_label)
	head.add_child(formation)
	column.add_child(head)
	column.add_child(_rule(0.15))
	var players := VBoxContainer.new()
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players.add_theme_constant_override(&"separation", 0)
	for slot in lineup.get("slots", []):
		players.add_child(_player_line(_dict(slot.get("player")), side, events, false))
	var bench: Array = lineup.get("bench", [])
	if not bench.is_empty():
		for player in bench:
			players.add_child(_player_line(_dict(player), side, events, true))
	column.add_child(players)
	panel.add_child(column)
	return panel


func _player_line(player: Dictionary, side: String, events: Array,
		bench: bool) -> Control:
	var panel := _panel_line()
	panel.custom_minimum_size.y = 22.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END if side == "away" \
		else BoxContainer.ALIGNMENT_BEGIN
	var marks := _marks_box(str(player.get("id", "")), side, events, 14.0)
	var name := _label(16, UiTheme.inter(500), _ink_2 if bench else _ink)
	name.text = _display_name(player)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if side == "away" \
		else HORIZONTAL_ALIGNMENT_LEFT
	if side == "away":
		row.add_child(marks)
		row.add_child(name)
	else:
		row.add_child(name)
		row.add_child(marks)
	panel.add_child(row)
	return panel


func _marks_box(player_id: String, side: String, events: Array,
		pixels: float) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	box.custom_minimum_size.x = 16.0
	for mark in _marks_for(player_id, side, events):
		var glyph := EventMark.new()
		glyph.setup(mark, _mark_color(mark), pixels)
		box.add_child(glyph)
	return box


func _marks_for(player_id: String, side: String, visible_events: Array) -> Array:
	var marks: Array = []
	var seen := {}
	for event in visible_events:
		if str(event.get("team", "")) != side:
			continue
		var mark := ""
		if str(event.get("type", "")) == "sub":
			if str(_dict(event.get("player_out")).get("id", "")) == player_id:
				mark = "sub-out"
			elif str(_dict(event.get("player")).get("id", "")) == player_id:
				mark = "sub-in"
		elif str(_dict(event.get("player")).get("id", "")) == player_id:
			mark = str(event.get("type", ""))
		if mark.is_empty() or seen.has(mark):
			continue
		seen[mark] = true
		marks.append(mark)
		if marks.size() >= 4:
			break
	return marks


func _side_tile(data: Dictionary, events: Array) -> Control:
	var panel := _panel(false, 10.0, 10.0, 10.0, 10.0)
	panel.custom_minimum_size.x = 320.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.4
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	column.add_child(_clock_box())
	var head_wrap := MarginContainer.new()
	head_wrap.add_theme_constant_override(&"margin_left", 8)
	head_wrap.add_theme_constant_override(&"margin_right", 8)
	head_wrap.add_theme_constant_override(&"margin_top", 10)
	head_wrap.add_theme_constant_override(&"margin_bottom", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	var head_label := _label(16, UiTheme.inter(600), _ink_2)
	head_label.text = "MATCH FEED"
	head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count := _label(16, UiTheme.inter(600), _ink_2)
	count.text = str(events.size())
	head.add_child(head_label)
	head.add_child(count)
	head_wrap.add_child(head)
	column.add_child(head_wrap)
	column.add_child(_rule(0.15))
	column.add_child(_feed(data, events))
	panel.add_child(column)
	return panel


func _clock_box() -> Control:
	var setup := _phase == "setup"
	var panel := _panel(true, 16.0, 16.0, 10.0 if setup else 12.0,
		10.0 if setup else 12.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	if not setup:
		var label := _label(16, UiTheme.inter(600), UiTokens.FOCUS_INK_2)
		label.text = "LIVE" if _phase == "live" else "FINAL"
		box.add_child(label)
	var value := _label(28 if setup else 40, UiTheme.barlow(700),
		UiTokens.FOCUS_INK if setup else UiTokens.FOCUS_MARK)
	value.text = _minute_label()
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.clip_text = true
	box.add_child(value)
	panel.add_child(box)
	return panel


func _feed(data: Dictionary, events: Array) -> Control:
	if _phase != "setup" and events.is_empty():
		return _feed_empty()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 4)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 0)
	if _phase == "setup":
		body.add_child(_setup_panel(data))
	else:
		for event in events:
			body.add_child(_feed_event_row(event, data))
	margin.add_child(body)
	scroll.add_child(margin)
	return scroll


func _feed_empty() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 14)
	var dot := ColorRect.new()
	dot.color = _ink_2
	dot.custom_minimum_size = Vector2(10.0, 10.0)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(dot)
	var text := _label(16, UiTheme.inter(500), _ink_2)
	text.text = "Events appear as the match unfolds."
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	return box


func _setup_panel(data: Dictionary) -> Control:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override(&"separation", 10)
	var eyebrow := _label(16, UiTheme.inter(600), _ink_2)
	eyebrow.text = "BEFORE THE MATCH"
	panel.add_child(eyebrow)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 0)
	var home := _dict(data.get("home_lineup"))
	var away := _dict(data.get("away_lineup"))
	rows.add_child(_info_row("Competition", str(data.get("competition", ""))))
	rows.add_child(_info_row("Round", str(int(data.get("round", 0)))))
	rows.add_child(_info_row("Formations", "%s — %s" % [
		str(home.get("formation_label", home.get("formation", ""))),
		str(away.get("formation_label", away.get("formation", ""))),
	]))
	rows.add_child(_info_row("Venue", "Home" if bool(data.get("home", false))
		else "Away"))
	panel.add_child(rows)
	var hint := _label(16, UiTheme.inter(500), _ink_2)
	hint.text = "Events appear after kick-off."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(hint)
	return panel


func _info_row(key: String, value: String) -> Control:
	var panel := _panel_line(7.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var key_label := _label(16, UiTheme.inter(500), _ink_2)
	key_label.text = key
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label(16, UiTheme.inter(600), _ink)
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(key_label)
	row.add_child(value_label)
	panel.add_child(row)
	return panel


func _feed_event_row(event: Dictionary, data: Dictionary) -> Control:
	var panel := _panel_line(5.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var minute := _label(16, UiTheme.inter(600), _ink_2)
	minute.text = "%d′" % int(event.get("minute", 0))
	minute.custom_minimum_size.x = 42.0
	minute.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(minute)
	var mark := str(event.get("type", ""))
	if mark == "sub":
		mark = "sub-in"
	var glyph := EventMark.new()
	glyph.setup(mark, _mark_color(mark), 16.0)
	row.add_child(glyph)
	var text := _label(16, UiTheme.inter(500), _ink)
	text.text = _event_text(event)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(text)
	var club := _label(16, UiTheme.inter(600), _ink_2)
	club.text = str(_dict(data.get("%s_team" % event.get("team", ""))).get("abbr", ""))
	club.custom_minimum_size.x = 38.0
	club.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(club)
	panel.add_child(row)
	return panel


func _panel_line(pad := 0.0) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_bottom = 1
	style.border_color = Color(UiTokens.INK, 0.10)
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


func _rule(alpha: float) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(UiTokens.INK, alpha)
	rule.custom_minimum_size.y = 1.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _event_text(event: Dictionary) -> String:
	var player := _display_name(_dict(event.get("player")))
	match str(event.get("type", "")):
		"sub":
			return "%s → %s" % [player, _display_name(_dict(event.get("player_out")))]
		"penalty":
			return "Penalty · %s" % player
		"injury":
			return "Injury · %s" % player
	return player
func _render_matchday(root: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	var eyebrow := _label(16, UiTheme.inter(600), _ink_2)
	eyebrow.text = "%s · ROUND %d · %s" % [
		str(_matchday.get("competition", "")).to_upper(),
		int(_matchday.get("round", 0)),
		_long_date(str(_matchday.get("date", ""))),
	]
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var step_label := _label(16, UiTheme.inter(600), _ink_2)
	step_label.text = "1 / 2" if _step == "results" else "2 / 2"
	header.add_child(eyebrow)
	header.add_child(step_label)
	root.add_child(header)
	if _step == "results":
		var title := _label(34, UiTheme.barlow(800), _ink)
		title.text = "RESULTS OF THE DAY"
		root.add_child(title)
		var results := VBoxContainer.new()
		results.add_theme_constant_override(&"separation", 0)
		results.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var items: Array = _matchday.get("results", [])
		for item in items:
			results.add_child(_result_row(item))
		root.add_child(results)
	else:
		root.add_child(_standings_table())


func _result_row(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TABLE_ROW_OWN if bool(item.get("own", false)) \
		else Color(0.0, 0.0, 0.0, 0.0)
	box.border_width_bottom = 1
	box.border_color = UiTokens.TABLE_DIVIDER
	panel.add_theme_stylebox_override(&"panel", box)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 42.0
	row.add_theme_constant_override(&"separation", 10)
	var home := _dict(item.get("home"))
	var away := _dict(item.get("away"))
	row.add_child(_result_side(home, false))
	var score := _label(22, UiTheme.barlow(700), _ink)
	score.text = "%d : %d" % [
		int(_dict(item.get("score")).get("home", 0)),
		int(_dict(item.get("score")).get("away", 0)),
	]
	score.custom_minimum_size.x = 96.0
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(score)
	row.add_child(_result_side(away, true))
	panel.add_child(row)
	return panel


func _result_side(team: Dictionary, away: bool) -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 8)
	var crest := _crest_rect()
	crest.custom_minimum_size = Vector2(24.0, 24.0)
	crest.size = Vector2(24.0, 24.0)
	crest.texture = _logo(str(team.get("logo", "")))
	var name := _label(16, UiTheme.inter(600), _ink)
	name.text = str(team.get("name", ""))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if away:
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(name)
		box.add_child(crest)
	else:
		box.add_child(crest)
		box.add_child(name)
	return box


func _standings_table() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table_scroll = scroll
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 0)
	body.add_child(_table_head())
	for row in _matchday.get("standings", []):
		body.add_child(_table_row(row))
	scroll.add_child(body)
	return scroll


func _table_head() -> Control:
	return _table_line({
		"position": "#", "club_name": "CLUB", "played": "P", "won": "W",
		"drawn": "D", "lost": "L", "goals_for": "GF", "goals_against": "GA",
		"goal_difference": "GD", "points": "PTS",
	}, true, false)


func _table_row(item: Dictionary) -> Control:
	return _table_line(item, false, bool(item.get("own", false)))


func _table_line(item: Dictionary, head: bool, own: bool) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TABLE_ROW_OWN if own else Color(0.0, 0.0, 0.0, 0.0)
	box.border_width_bottom = 1
	box.border_color = UiTokens.TABLE_DIVIDER
	panel.add_theme_stylebox_override(&"panel", box)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HEAD_ROW if head else TABLE_ROW
	row.add_theme_constant_override(&"separation", 0)
	var rail := ColorRect.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.custom_minimum_size.x = 2.0
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.color = UiTokens.RAIL if own else Color(0.0, 0.0, 0.0, 0.0)
	row.add_child(rail)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size.x = 4.0
	row.add_child(gap)
	var weight := UiTheme.inter(600) if head else UiTheme.inter(500)
	var size := 15 if head else 16
	var pos := _label(size, weight, _ink_2)
	pos.text = str(item.get("position", "")) if not head else "#"
	pos.custom_minimum_size.x = 40.0
	row.add_child(pos)
	var crest := _crest_rect()
	crest.custom_minimum_size = Vector2(26.0, 20.0)
	crest.size = Vector2(26.0, 20.0)
	if not head:
		crest.texture = _logo(str(item.get("club_logo", "")))
	row.add_child(crest)
	var name := _label(size, weight, _ink_2)
	name.text = str(item.get("club_name", "")) if not head else "CLUB"
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	row.add_child(name)
	var columns := {
		"played": {"label": "P", "width": 50.0},
		"won": {"label": "W", "width": 50.0},
		"drawn": {"label": "D", "width": 50.0},
		"lost": {"label": "L", "width": 50.0},
		"goals_for": {"label": "GF", "width": 60.0},
		"goals_against": {"label": "GA", "width": 60.0},
		"goal_difference": {"label": "GD", "width": 70.0},
		"points": {"label": "PTS", "width": 60.0},
	}
	for key in columns:
		var column: Dictionary = columns[key]
		var value := _label(size, weight, _ink_2)
		value.text = str(item.get(key, "")) if not head else str(column["label"])
		value.custom_minimum_size.x = float(column["width"])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
	var right := Control.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size.x = 8.0
	row.add_child(right)
	panel.add_child(row)
	return panel


func _render_review(root: VBoxContainer) -> void:
	var review := _review
	var league := _dict(review.get("league"))
	var head := VBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 20)
	var eyebrow := _label(16, UiTheme.inter(600), _ink_2)
	if _review_step == 0:
		eyebrow.text = "SEASON REVIEW · %s" % _review_season_start.substr(0, 4)
	else:
		eyebrow.text = "NEW SEASON"
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(eyebrow)
	var right := _label(16, UiTheme.inter(600), _ink_2)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _review_step == 0:
		var own := _own_review_row()
		if not own.is_empty():
			right.text = "%d%s · %d PTS" % [int(own.get("position", 0)),
				CareerHubModel._ordinal(int(own.get("position", 0))),
				int(own.get("points", 0))]
	else:
		right.text = _next_season_label()
	top.add_child(right)
	head.add_child(top)
	var title := _label(34, UiTheme.barlow(800), _ink)
	var next_league := _dict(_dict(review.get("next")).get("league", {}))
	if _review_step == 0:
		title.text = str(league.get("name", "")).to_upper()
	else:
		title.text = str(next_league.get("name", "")).to_upper()
	head.add_child(title)
	head.add_child(_rule(0.15))
	root.add_child(head)
	if _review_step == 0:
		root.add_child(_review_table())
		root.add_child(_review_zones())
	else:
		var widget := _review_transition()
		root.add_child(widget)
		_reveal_widget(_review_center if _review_center != null else widget)
		root.add_child(_review_next_grid())


func _reviews_row_style(own: bool, up: bool, down: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TABLE_ROW_OWN if own else Color(UiTokens.INK, 0.045)
	box.border_width_left = 4 if up or down else 0
	box.border_color = MARK_WIN if up else MARK_LOSS
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	return box


func _review_table() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override(&"separation", 2)
	wrap.add_child(_review_line({}, true, false, false, false))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table_scroll = scroll
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 2)
	for row in _review.get("standings", []):
		body.add_child(_review_line(row, false,
			_has_ref(_review.get("promoted", []), str(row.get("club_id", ""))),
			_has_ref(_review.get("relegated", []), str(row.get("club_id", ""))),
			str(row.get("club_id", "")) == str(_review_club.get("id", ""))))
	scroll.add_child(body)
	wrap.add_child(scroll)
	_scroll_review_to_own()
	return wrap


func _scroll_review_to_own() -> void:
	# The prototype centres the career club's row; without it the bottom of a
	# 18/20-club table hides the row that matters most.
	if _table_scroll == null:
		return
	await get_tree().process_frame
	if _table_scroll == null or not is_instance_valid(_table_scroll):
		return
	var own_id := str(_review_club.get("id", ""))
	var rows: Array = _review.get("standings", [])
	var index := -1
	for row_index in range(rows.size()):
		if str(rows[row_index].get("club_id", "")) == own_id:
			index = row_index
			break
	if index < 0:
		return
	var target := float(index) * 27.0 - (_table_scroll.size.y - 25.0) * 0.5
	_table_scroll.scroll_vertical = int(maxf(0.0, target))


func _review_line(row: Dictionary, head: bool, up: bool, down: bool,
		own: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _reviews_row_style(own, up, down))
	var line := HBoxContainer.new()
	line.custom_minimum_size.y = 26.0 if head else 25.0
	line.add_theme_constant_override(&"separation", 10)
	var weight := UiTheme.inter(600) if head else UiTheme.inter(500)
	var pos := _label(16, weight, _ink_2 if not own else _ink)
	pos.text = str(row.get("position", "")) if not head else "#"
	pos.custom_minimum_size.x = 26.0
	line.add_child(pos)
	if not head:
		var crest := _crest_rect()
		crest.custom_minimum_size = Vector2(24.0, 24.0)
		crest.size = Vector2(24.0, 24.0)
		crest.texture = _logo(str(row.get("club_logo", "")))
		line.add_child(crest)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size.x = 24.0
		line.add_child(spacer)
	var name := _label(16, weight, _ink if not own else _ink)
	name.text = str(row.get("club_name", "")) if not head else "CLUB"
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	line.add_child(name)
	for column in [
		{"key": "played", "label": "P", "width": 52.0},
		{"key": "goal_difference", "label": "GD", "width": 60.0},
		{"key": "points", "label": "PTS", "width": 56.0},
	]:
		var value := _label(16, UiTheme.inter(700) if not head else weight, _ink_2)
		if head:
			value.text = str(column["label"])
		elif str(column["key"]) == "goal_difference" and int(row.get("goal_difference", 0)) > 0:
			value.text = "+%d" % int(row.get("goal_difference", 0))
		else:
			value.text = str(row.get(column["key"], ""))
		value.custom_minimum_size.x = float(column["width"])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
	panel.add_child(line)
	return panel


func _review_zones() -> Control:
	var zones := HBoxContainer.new()
	zones.add_theme_constant_override(&"separation", int(UiTokens.GAP))
	var promoted: Array = _review.get("promoted", [])
	var relegated: Array = _review.get("relegated", [])
	if not promoted.is_empty():
		zones.add_child(_review_zone("PROMOTED TO %s" % _league_name(_review.get("promoted_to")),
			promoted, MARK_WIN))
	if not relegated.is_empty():
		zones.add_child(_review_zone("RELEGATED TO %s" % _league_name(_review.get("relegated_to")),
			relegated, MARK_LOSS))
	if promoted.is_empty() != relegated.is_empty():
		# A lone zone keeps the left half; the right half stays empty.
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zones.add_child(spacer)
	return zones


func _review_zone(title: String, clubs: Array, mark: Color) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.045)
	box.border_width_left = 4
	box.border_color = mark
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override(&"panel", box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	var label := _label(16, UiTheme.inter(600), _ink_2)
	label.text = title
	column.add_child(label)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 16)
	chips.add_theme_constant_override(&"v_separation", 6)
	for club in clubs:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override(&"separation", 8)
		var crest := _crest_rect()
		crest.custom_minimum_size = Vector2(20.0, 20.0)
		crest.size = Vector2(20.0, 20.0)
		crest.texture = _logo(str(club.get("logo", "")))
		var name := _label(16, UiTheme.inter(500), _ink)
		name.text = str(club.get("name", ""))
		chip.add_child(crest)
		chip.add_child(name)
		chips.add_child(chip)
	column.add_child(chips)
	panel.add_child(column)
	return panel


func _reveal_widget(node: Control) -> void:
	# The prototype's review-move-in, with the direction of the outcome:
	# stayed -> slide right, promoted -> slide up, relegated -> slide down.
	if UiTransition.instant:
		return
	node.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(node):
		return
	var amplitude := 40.0
	var base := node.position
	var movement = _review.get("movement")
	var offset := Vector2(-amplitude, 0.0)
	if movement == "up":
		offset = Vector2(0.0, amplitude)
	elif movement == "down":
		offset = Vector2(0.0, -amplitude)
	node.position = base + offset
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.22)
	tween.tween_property(node, "position", base, 0.22)


func _review_transition() -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.045)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 24.0
	box.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override(&"panel", box)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override(&"separation", 24)
	_review_center = row
	var movement = _review.get("movement")
	var mark := MARK_WIN if movement == "up" else (MARK_LOSS if movement == "down" else _ink_2)
	var arrow := _label(96, UiTheme.barlow(700), mark)
	arrow.text = "↑" if movement == "up" else ("↓" if movement == "down" else "→")
	row.add_child(arrow)
	if not UiTransition.instant:
		arrow.pivot_offset = arrow.get_combined_minimum_size() * 0.5
		arrow.scale = Vector2(0.72, 0.72)
		var arrow_tween := create_tween()
		arrow_tween.tween_property(arrow, "scale", Vector2.ONE, 0.22) \
			.set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var crest := _crest_rect()
	crest.custom_minimum_size = Vector2(96.0, 96.0)
	crest.size = Vector2(96.0, 96.0)
	var club_logo := str(_review_club.get("career_logo", ""))
	if club_logo.is_empty():
		club_logo = str(_review_club.get("logo", ""))
	crest.texture = _logo(club_logo)
	row.add_child(crest)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override(&"separation", 6)
	var name := _label(40, UiTheme.barlow(700), _ink)
	name.text = str(_review_club.get("name", "")).to_upper()
	copy.add_child(name)
	var line := _label(18, UiTheme.inter(600), mark)
	var league := _league_name(_dict(_review.get("next")).get("league"))
	if movement == "up":
		line.text = "PROMOTED TO %s" % league
	elif movement == "down":
		line.text = "RELEGATED TO %s" % league
	else:
		line.text = "STAYED IN %s" % league
	copy.add_child(line)
	row.add_child(copy)
	panel.add_child(row)
	return panel


func _review_next_grid() -> Control:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override(&"separation", int(UiTokens.GAP))
	var next_block := _dict(_review.get("next"))
	var from_above: Array = next_block.get("from_above", [])
	var from_below: Array = next_block.get("from_below", [])
	var columns := 0
	if not from_above.is_empty():
		grid.add_child(_review_next_column("FROM %s" % _league_name(next_block.get("above")),
			from_above))
		columns += 1
	if not from_below.is_empty():
		grid.add_child(_review_next_column("FROM %s" % _league_name(next_block.get("below")),
			from_below))
		columns += 1
	if columns == 1:
		# One column keeps the same half-width slot as the two-column case.
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(spacer)
	return grid


func _review_next_column(title: String, rows: Array) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.045)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override(&"panel", box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	var label := _label(16, UiTheme.inter(600), _ink_2)
	label.text = title
	column.add_child(label)
	for index in range(rows.size()):
		var item: Dictionary = rows[index]
		var club := _dict(item.get("club"))
		var league := _dict(item.get("league"))
		var line := HBoxContainer.new()
		line.custom_minimum_size.y = 28.0
		line.add_theme_constant_override(&"separation", 10)
		var crest := _crest_rect()
		crest.custom_minimum_size = Vector2(24.0, 24.0)
		crest.size = Vector2(24.0, 24.0)
		crest.texture = _logo(str(club.get("logo", "")))
		line.add_child(crest)
		var name := _label(16, UiTheme.inter(500), _ink)
		name.text = str(club.get("name", ""))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		line.add_child(name)
		var league_label := _label(16, UiTheme.inter(500), _ink_2)
		league_label.text = str(league.get("name", ""))
		line.add_child(league_label)
		var row_panel := PanelContainer.new()
		var row_box := StyleBoxFlat.new()
		row_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		if index < rows.size() - 1:
			row_box.border_width_bottom = 1
			row_box.border_color = Color(UiTokens.INK, 0.10)
		row_panel.add_theme_stylebox_override(&"panel", row_box)
		row_panel.add_child(line)
		column.add_child(row_panel)
	panel.add_child(column)
	return panel


func _own_review_row() -> Dictionary:
	var club_id := str(_review_club.get("id", ""))
	for row in _review.get("standings", []):
		if str(row.get("club_id", "")) == club_id:
			return row
	return {}


func _has_ref(rows: Array, club_id: String) -> bool:
	for row in rows:
		if str(row.get("id", "")) == club_id:
			return true
	return false


func _league_name(value) -> String:
	if not (value is Dictionary):
		return "—"
	return str(value.get("name", "—"))


func _next_season_label() -> String:
	if _review_season_start.length() < 4:
		return ""
	var year := int(_review_season_start.substr(0, 4)) + 1
	return "%d/%02d" % [year, (year + 1) % 100]


func _visible_events() -> Array:
	if _phase == "setup" or _match.is_empty():
		return []
	var events: Array = []
	for event in _match.get("events", []):
		if int(event.get("minute", 0)) <= _minute:
			events.append(event)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var minute_a := int(a.get("minute", 0))
		var minute_b := int(b.get("minute", 0))
		if minute_a != minute_b:
			return minute_a > minute_b
		return str(a.get("id", "")) > str(b.get("id", "")))
	return events


func _mark_color(mark: String) -> Color:
	match mark:
		"goal", "penalty":
			return _ink
		"yellow":
			return MARK_WARN
		"red", "injury":
			return MARK_LOSS
		"sub-in":
			return MARK_WIN
		"sub-out":
			return _ink_2
	return _ink_2


func _display_name(player: Dictionary) -> String:
	var last_name := str(player.get("last_name", ""))
	if not last_name.is_empty():
		return last_name
	var name := str(player.get("name", ""))
	return name if not name.is_empty() else "—"


func _long_date(iso: String) -> String:
	if iso.length() < 10:
		return iso
	return "%s %s" % [CareerHubModel.short_date(iso), iso.substr(0, 4)]


func _dict(value) -> Dictionary:
	return value if value is Dictionary else {}


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
