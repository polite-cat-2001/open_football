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
