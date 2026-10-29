class_name GpfHud
extends Node
# In-match HUD and its menus: score/clock/status bar, the set-piece taker overlay and
# the half-time / full-time phase menu.

const PHASE_NAMES := [
	"PRE-MATCH",
	"1ST HALF",
	"2ND HALF",
	"EXTRA TIME 1",
	"EXTRA TIME 2",
	"PENALTIES",
]

const SET_PIECE_NAMES := [
	"",
	"KICKOFF",
	"GOAL KICK",
	"FREE KICK",
	"CORNER",
	"THROW-IN",
	"PENALTY",
]

var hud: Label
var score_hud: Label
var taker_hint: Label

var taker_menu_layer: CanvasLayer
var taker_menu_label: Label
var taker_menu_open := false
var taker_menu_candidates: Array = []
var taker_menu_index := 0

var phase_menu_layer: CanvasLayer
var phase_menu_title: Label
var phase_menu_subtitle: Label
var phase_menu_score: Label
var phase_menu_details: Label
var phase_menu_hint: Label
var phase_menu_continue: Button
var phase_menu_quit: Button
var phase_menu_open := false
var phase_menu_game_over := false

var _runtime: Node


func setup(runtime: Node) -> void:
	_runtime = runtime
	_build_hud()
	_build_taker_menu()
	_build_phase_menu()


func update(snap: Dictionary, display_player_id: int, actor_count: int,
		stadium_camera: bool, lighting_name: String) -> void:
	_sync_phase_menu(snap)
	_sync_taker_ui(snap)
	if hud == null:
		return
	var status := _status_text(snap, display_player_id)
	if score_hud != null:
		# The shootout HUD is the two circles rows; no match clock or score.
		score_hud.visible = not bool(snap.get("shootout_active", false))
		var phase_text := _phase_name(int(snap.get("match_phase", 0)))
		if bool(snap.get("game_over", false)):
			phase_text = "FULL TIME"
		elif bool(snap.get("phase_break_pending", false)) or bool(snap.get("phase_break", false)):
			phase_text = "BREAK"
		score_hud.text = "%d : %d    %s    %s" % [
			int(snap.get("score0", 0)),
			int(snap.get("score1", 0)),
			_format_clock(int(snap.get("match_time_ms", 0))),
			phase_text,
		]
	var match_minutes := 5 + int(round(20.0 * float(_runtime.get("match_duration"))))
	var park_text := "F2 unpark opponents" if bool(snap.get("debug_park_opponents", false)) \
		else "F2 park opponents"
	var camera_text := "V broadcast cam" if stadium_camera else "V stadium cam"
	hud.text = "GPF slice  %s  tick %d  ball %.1f, %.1f  actors %d\nArrows move   E sprint   S pass   D shot   W through   A high   C dribble   Q switch   match ~%d min\nD+C curl   D+Q chip   double-E knock-on   P pen   Alt+P defend pen   F free kick   Y corner   G goal kick   O throw-in   Tab taker   F4 new match   %s   %s   F1 light: %s" % [
		status,
		int(snap.get("tick", 0)),
		(snap.get("ball_pos", Vector3.ZERO) as Vector3).x,
		(snap.get("ball_pos", Vector3.ZERO) as Vector3).y,
		actor_count,
		match_minutes,
		park_text,
		camera_text,
		lighting_name,
	]


func set_replay_mode(active: bool) -> void:
	if hud != null:
		hud.visible = not active
	if score_hud != null:
		score_hud.visible = not active


func reset() -> void:
	close_taker_menu(false)
	_close_phase_menu()
	phase_menu_game_over = false
	set_replay_mode(false)


func is_taker_menu_open() -> bool:
	return taker_menu_open


func toggle_taker_menu() -> void:
	if taker_menu_open:
		close_taker_menu(false)
		return
	if not _runtime.is_set_piece_taker_menu_available():
		return
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_S) \
			or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A):
		return
	if not _runtime.open_set_piece_taker_menu():
		return
	taker_menu_candidates = _runtime.get_set_piece_taker_candidates()
	if taker_menu_candidates.is_empty():
		_runtime.close_set_piece_taker_menu()
		return
	taker_menu_index = 0
	for i in taker_menu_candidates.size():
		if bool(taker_menu_candidates[i].get("current", false)):
			taker_menu_index = i
			break
	taker_menu_open = true
	taker_menu_layer.visible = true
	_refresh_taker_menu()


func handle_taker_menu_key(event: InputEventKey) -> void:
	if not event.pressed:
		return
	match event.keycode:
		KEY_UP:
			_move_taker_menu(-1)
		KEY_DOWN:
			_move_taker_menu(1)
		KEY_ENTER, KEY_KP_ENTER:
			close_taker_menu(true)
		KEY_ESCAPE:
			close_taker_menu(false)
		KEY_D, KEY_S, KEY_W, KEY_A, KEY_Q, KEY_E, KEY_C:
			close_taker_menu(false)


func close_taker_menu(apply_choice: bool) -> void:
	if not taker_menu_open:
		return
	if apply_choice and taker_menu_index >= 0 and taker_menu_index < taker_menu_candidates.size():
		var chosen := int(taker_menu_candidates[taker_menu_index].get("id", -1))
		if chosen >= 0:
			_runtime.request_set_piece_taker(chosen)
	_runtime.close_set_piece_taker_menu()
	taker_menu_open = false
	taker_menu_layer.visible = false


func is_phase_menu_open() -> bool:
	return phase_menu_open


func is_phase_menu_game_over() -> bool:
	return phase_menu_game_over


func handle_phase_menu_key(event: InputEventKey) -> void:
	if not event.pressed:
		return
	if phase_menu_game_over:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_quit_game()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		continue_phase_break()


func continue_phase_break() -> void:
	if not phase_menu_open or phase_menu_game_over:
		return
	_runtime.continue_after_phase_break()
	_close_phase_menu()


func _sync_taker_ui(snap: Dictionary) -> void:
	if taker_menu_open and not bool(snap.get("set_piece_taker_menu_open", false)):
		close_taker_menu(false)
	if taker_hint != null:
		taker_hint.visible = bool(snap.get("set_piece_local_taker", false)) \
			and not taker_menu_open and not phase_menu_open \
			and not bool(snap.get("shootout_active", false)) \
			and bool(snap.get("in_set_piece", false))


func _sync_phase_menu(snap: Dictionary) -> void:
	# The shootout presentation owns the end of the match: it shows its own winner banner and quits.
	if bool(snap.get("shootout_active", false)):
		if phase_menu_open:
			_close_phase_menu()
		return
	var game_over := bool(snap.get("game_over", false))
	var phase_break := bool(snap.get("phase_break_pending", false)) \
		or bool(snap.get("phase_break", false))
	if not game_over and not phase_break:
		if phase_menu_open:
			_close_phase_menu()
		return
	if not phase_menu_open:
		if not game_over and not bool(snap.get("phase_break", false)):
			_runtime.begin_phase_break()
		_open_phase_menu(snap)
	else:
		_refresh_phase_menu(snap)


func _open_phase_menu(snap: Dictionary) -> void:
	if taker_menu_open:
		close_taker_menu(false)
	phase_menu_open = true
	phase_menu_layer.visible = true
	_refresh_phase_menu(snap)
	if phase_menu_game_over:
		phase_menu_quit.grab_focus()
	else:
		phase_menu_continue.grab_focus()


func _refresh_phase_menu(snap: Dictionary) -> void:
	phase_menu_game_over = bool(snap.get("game_over", false))
	var game_over := phase_menu_game_over
	var next_phase := int(snap.get("phase_break_next_phase", 0))
	if game_over:
		var after_extra := int(snap.get("match_time_ms", 0)) >= 7200000 \
			or int(snap.get("match_phase", 0)) == 5
		phase_menu_title.text = "AFTER EXTRA TIME" if after_extra else "FULL TIME"
		phase_menu_subtitle.text = "Final score"
	else:
		phase_menu_title.text = _phase_break_title(next_phase)
		phase_menu_subtitle.text = _phase_break_subtitle(next_phase)
	var home := String(snap.get("team0_name", ""))
	if home == "":
		home = "HOME"
	var away := String(snap.get("team1_name", ""))
	if away == "":
		away = "AWAY"
	phase_menu_score.text = "%s   %d : %d   %s" % [
		home,
		int(snap.get("score0", 0)),
		int(snap.get("score1", 0)),
		away,
	]
	var possession0 := int(snap.get("possession0_ms", 0))
	var possession1 := int(snap.get("possession1_ms", 0))
	var possession_total := possession0 + possession1
	var possession_pct0 := 50
	if possession_total > 0:
		possession_pct0 = int(round(100.0 * float(possession0) / float(possession_total)))
	phase_menu_details.text = "Possession   %d%% - %d%%\nShots        %d - %d" % [
		possession_pct0,
		100 - possession_pct0,
		int(snap.get("shots0", 0)),
		int(snap.get("shots1", 0)),
	]
	phase_menu_continue.visible = not game_over
	if game_over:
		phase_menu_hint.text = "Enter / Esc: exit"
		phase_menu_quit.text = "Exit"
	else:
		phase_menu_hint.text = "Enter / Space: continue"
		phase_menu_quit.text = "Quit"


func _phase_break_title(next_phase: int) -> String:
	match next_phase:
		2:
			return "HALF TIME"
		3:
			return "END OF 90"
		4:
			return "EXTRA TIME"
	return "BREAK"


func _phase_break_subtitle(next_phase: int) -> String:
	match next_phase:
		2:
			return "Begin second half"
		3:
			return "Begin extra time"
		4:
			return "Begin second extra time"
	return "Continue"


func _close_phase_menu() -> void:
	phase_menu_open = false
	phase_menu_layer.visible = false


func _quit_game() -> void:
	get_tree().quit()


func _status_text(snap: Dictionary, display_player_id: int) -> String:
	if bool(snap.get("game_over", false)):
		return "MATCH OVER"
	if bool(snap.get("paused", false)):
		return "PAUSED"
	if bool(snap.get("goal_scored", false)):
		return "GOAL — restart"
	var piece := int(snap.get("referee_set_piece", 0))
	var role := int(snap.get("set_piece_role", 0))
	if bool(snap.get("in_set_piece", false)):
		var human_team := int(_runtime.get_human_team_id())
		if piece == 6 and human_team >= 0 and int(snap.get("referee_team", -1)) != human_team:
			return "PENALTY - keeper: arrows to dive"
		if role == 2:
			return "PENALTY - keeper: arrows to dive"
		var piece_name := _set_piece_name(piece)
		if piece_name == "":
			piece_name = _set_piece_name(int(snap.get("set_piece_type", 0)))
		if piece_name == "":
			piece_name = "SET PIECE"
		var taker := int(snap.get("referee_taker", -1))
		if taker < 0:
			taker = int(snap.get("set_piece_taker", -1))
		if role == 1:
			if piece == 6:
				return "PENALTY - arrows aim, D shot"
			if piece == 2 or piece == 3 or piece == 4:
				return "%s - arrows aim, S/D kick" % piece_name
		if taker == display_player_id:
			return "%s - S pass / D shot" % piece_name
		return "%s - waiting" % piece_name
	if bool(snap.get("referee_active", false)) and piece != 0:
		return "%s — setup" % _set_piece_name(piece)
	if bool(snap.get("in_play", false)):
		return "LIVE"
	return "PRE-MATCH"


func _format_clock(milliseconds: int) -> String:
	var total_seconds := int(maxf(0.0, float(milliseconds)) / 1000.0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _phase_name(phase: int) -> String:
	if phase >= 0 and phase < PHASE_NAMES.size():
		return PHASE_NAMES[phase]
	return "PHASE %d" % phase


func _set_piece_name(piece: int) -> String:
	if piece > 0 and piece < SET_PIECE_NAMES.size():
		return SET_PIECE_NAMES[piece]
	return ""


func _move_taker_menu(delta: int) -> void:
	var count := taker_menu_candidates.size()
	if count == 0:
		return
	taker_menu_index = (taker_menu_index + delta + count) % count
	_refresh_taker_menu()


func _refresh_taker_menu() -> void:
	var lines := PackedStringArray()
	for i in taker_menu_candidates.size():
		var entry: Dictionary = taker_menu_candidates[i]
		var prefix := "> " if i == taker_menu_index else "  "
		var name := String(entry.get("name", ""))
		var suffix := "  (GK)" if String(entry.get("role", "")) == "goalkeeper" else ""
		var current := "  *" if bool(entry.get("current", false)) else ""
		lines.append("%s%s%s%s" % [prefix, name, suffix, current])
	taker_menu_label.text = "\n".join(lines)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudOverlay"
	add_child(layer)

	score_hud = Label.new()
	score_hud.position = Vector2(24, 14)
	score_hud.add_theme_font_size_override("font_size", 34)
	score_hud.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	score_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	score_hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(score_hud)

	hud = Label.new()
	hud.position = Vector2(24, 64)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)

	taker_hint = Label.new()
	taker_hint.position = Vector2(24, 150)
	taker_hint.add_theme_font_size_override("font_size", 18)
	taker_hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	taker_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	taker_hint.add_theme_constant_override("outline_size", 4)
	taker_hint.text = "Tab: change taker"
	taker_hint.visible = false
	layer.add_child(taker_hint)


func _build_taker_menu() -> void:
	taker_menu_layer = CanvasLayer.new()
	taker_menu_layer.layer = 2
	add_child(taker_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	taker_menu_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	taker_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.96)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SET-PIECE TAKER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(title)

	taker_menu_label = Label.new()
	taker_menu_label.add_theme_font_size_override("font_size", 20)
	taker_menu_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	box.add_child(taker_menu_label)

	var hint := Label.new()
	hint.text = "Up/Down select    Enter apply    Esc/Tab close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(hint)

	taker_menu_layer.visible = false


func _build_phase_menu() -> void:
	phase_menu_layer = CanvasLayer.new()
	phase_menu_layer.layer = 3
	add_child(phase_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_menu_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	phase_menu_title = Label.new()
	phase_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_title.add_theme_font_size_override("font_size", 32)
	phase_menu_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(phase_menu_title)

	phase_menu_subtitle = Label.new()
	phase_menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_subtitle.add_theme_font_size_override("font_size", 18)
	phase_menu_subtitle.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
	box.add_child(phase_menu_subtitle)

	phase_menu_score = Label.new()
	phase_menu_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_score.add_theme_font_size_override("font_size", 28)
	phase_menu_score.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	box.add_child(phase_menu_score)

	phase_menu_details = Label.new()
	phase_menu_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_details.add_theme_font_size_override("font_size", 18)
	phase_menu_details.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	box.add_child(phase_menu_details)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	phase_menu_continue = Button.new()
	phase_menu_continue.text = "Continue"
	phase_menu_continue.custom_minimum_size = Vector2(160, 40)
	buttons.add_child(phase_menu_continue)
	phase_menu_continue.pressed.connect(continue_phase_break)

	phase_menu_quit = Button.new()
	phase_menu_quit.text = "Quit"
	phase_menu_quit.custom_minimum_size = Vector2(160, 40)
	buttons.add_child(phase_menu_quit)
	phase_menu_quit.pressed.connect(_quit_game)

	phase_menu_hint = Label.new()
	phase_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_hint.add_theme_font_size_override("font_size", 14)
	phase_menu_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(phase_menu_hint)

	phase_menu_layer.visible = false
