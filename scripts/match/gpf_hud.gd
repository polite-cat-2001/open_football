class_name GpfHud
extends Node
# In-match HUD and its overlays: score/clock/status bar, the set-piece taker overlay and
# the full-time result menu. The phase break is not drawn here: it reuses the
# design-system pause screen (GpfPauseMenu.open_break).

signal main_menu_requested

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
var substitution_notice: Label
var _sub_notice_counter := -1
var _sub_notice_hide_ms := 0

# Match message (goal scorer, referee call): the original draws one centred
# caption at 5% height and hides it on messageCaptionRemoveTime_ms. Our score
# line occupies that band, so the caption sits just below it (8.5%). The bridge
# only has the display duration, so the HUD anchors it to actual_time_ms.
var message_label: Label
var _spam_counter := -1
var _spam_hide_at_ms := 0
var _spam_active := false
var _shootout_active := false

var taker_menu: GpfSetPieceTakerMenu
var _hint_player_id := -2

var root_layer: CanvasLayer
var phase_menu_layer: CanvasLayer
var phase_menu_title: Label
var phase_menu_subtitle: Label
var phase_menu_score: Label
var phase_menu_details: Label
var phase_menu_hint: Label
var phase_menu_quit: Button
var phase_menu_open := false
var phase_menu_game_over := false

var _runtime: Node
var _replay_mode := false


func setup(runtime: Node) -> void:
	_runtime = runtime
	_build_hud()
	_build_taker_menu()
	_build_phase_menu()


# Stable presentation seam: the HUD is a pure function of the snapshot. The
# runtime (C++ bridge) is only needed for actions, never for drawing.
func apply_snapshot(snap: Dictionary, display_player_id: int = -1,
		actor_count: int = 0, stadium_camera: bool = false,
		lighting_name: String = "Afternoon") -> void:
	update(snap, display_player_id, actor_count, stadium_camera, lighting_name)


func update(snap: Dictionary, display_player_id: int, actor_count: int,
		stadium_camera: bool, lighting_name: String) -> void:
	_sync_game_over_menu(snap)
	_sync_taker_ui(snap)
	_sync_substitution_notice(snap)
	_sync_spam_message(snap)
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
	var duration := 1.0
	if _runtime != null:
		duration = float(_runtime.get("match_duration"))
	elif snap.has("match_duration"):
		duration = float(snap.get("match_duration", 1.0))
	var match_minutes := int(round(MatchPackage.minutes_from_duration(duration)))
	# The ported taker overlay replaces the dev key legend while it is up: the
	# original page draws over the pitch and has no second text block under it.
	hud.visible = not _replay_mode and not is_taker_menu_open()
	var park_text := "F2 unpark opponents" if bool(snap.get("debug_park_opponents", false)) \
		else "F2 park opponents"
	var camera_text := "V broadcast cam" if stadium_camera else "V stadium cam"
	hud.text = "%s\nArrows move   E sprint   S pass   D shot   W through   A high   C dribble   Q switch   match ~%d min\nD+C curl   D+Q chip   double-E knock-on   P pen   Alt+P defend pen   F free kick   Y corner   G goal kick   O throw-in   Tab taker   F4 new match   %s   %s   F1 light: %s" % [
		status,
		match_minutes,
		park_text,
		camera_text,
		lighting_name,
	]
	# The control legend must fit 1280-wide screens too: wrap it to the
	# viewport and push the taker hint below the wrapped block. A visible match
	# message sits under the score line, so the dev legend moves down while it
	# is up instead of printing through the caption.
	var view_width := get_viewport().get_visible_rect().size.x
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.size = Vector2(maxf(320.0, view_width - 48.0), 0)
	hud.size.y = hud.get_minimum_size().y
	var legend_top := 64.0
	if _message_showing():
		# Room for two wrapped caption lines plus a gap.
		legend_top = maxf(64.0, message_label.position.y + 96.0)
	hud.position = Vector2(24, legend_top)
	if taker_hint != null:
		taker_hint.position = Vector2(24, legend_top + hud.size.y + 6.0)


func set_replay_mode(active: bool) -> void:
	_replay_mode = active
	if hud != null:
		hud.visible = not active and not is_taker_menu_open()
	if score_hud != null:
		score_hud.visible = not active
	_refresh_message_visibility()


func reset() -> void:
	close_taker_menu(false)
	_close_phase_menu()
	phase_menu_game_over = false
	_hint_player_id = -2
	set_replay_mode(false)
	_sub_notice_counter = -1
	if substitution_notice != null:
		substitution_notice.visible = false
	_spam_counter = -1
	_spam_hide_at_ms = 0
	_spam_active = false
	_shootout_active = false
	if message_label != null:
		message_label.text = ""
	_refresh_message_visibility()


func set_taker_hint_key(key_name: String) -> void:
	if taker_hint != null:
		taker_hint.text = "%s: change taker" % key_name


func is_taker_menu_open() -> bool:
	return taker_menu != null and taker_menu.is_open()


func accepts_taker_menu_keyboard() -> bool:
	return taker_menu != null and taker_menu.accepts_keyboard()


func accepts_taker_menu_joy(device: int) -> bool:
	return taker_menu != null and taker_menu.accepts_joy(device)


# Only the device of the human who actually takes this set piece may open the
# menu (original #30). owner_kind is "keyboard" or "gamepad", owner_device the
# Godot joypad id. Returns true when the overlay is now open.
func toggle_taker_menu(owner_kind: String = "keyboard", owner_device: int = 0) -> bool:
	if taker_menu == null:
		return false
	if taker_menu.is_open():
		# Toggle only with the device that opened it: another local player's
		# Tab/Select must not close this taker's overlay either.
		if taker_menu.owner_kind == owner_kind \
				and (owner_kind == "keyboard" or taker_menu.owner_device == owner_device):
			taker_menu.close(false)
		return false
	if _runtime == null or not _runtime.is_set_piece_taker_menu_available():
		return false
	if owner_kind == "keyboard" and (Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_S) \
			or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A)):
		return false
	if owner_kind == "gamepad" and (Input.is_joy_button_pressed(owner_device, JOY_BUTTON_A) \
			or Input.is_joy_button_pressed(owner_device, JOY_BUTTON_B) \
			or Input.is_joy_button_pressed(owner_device, JOY_BUTTON_X) \
			or Input.is_joy_button_pressed(owner_device, JOY_BUTTON_Y)):
		return false
	var snap: Dictionary = _runtime.get_snapshot()
	if not _owns_taker_menu(owner_kind, owner_device, snap):
		return false
	if not _runtime.open_set_piece_taker_menu():
		return false
	var candidates: Array = _runtime.get_set_piece_taker_candidates()
	if candidates.is_empty():
		_runtime.close_set_piece_taker_menu()
		return false
	return taker_menu.open(candidates, owner_kind, owner_device)


func handle_taker_menu_key(event: InputEventKey) -> bool:
	if taker_menu == null:
		return false
	return taker_menu.handle_key(event)


func handle_taker_menu_joy(event: InputEventJoypadButton) -> bool:
	if taker_menu == null:
		return false
	return taker_menu.handle_joy(event)


func handle_taker_menu_joy_motion(event: InputEventJoypadMotion) -> bool:
	if taker_menu == null:
		return false
	return taker_menu.handle_joy_motion(event)


func close_taker_menu(apply_choice: bool) -> void:
	if taker_menu != null:
		taker_menu.close(apply_choice)


func show_taker_menu_demo(candidates: Array, current_index: int = -1) -> void:
	if taker_menu == null:
		return
	taker_menu.open(candidates, "keyboard", 0, current_index)


func _owns_taker_menu(kind: String, device: int, snap: Dictionary = {}) -> bool:
	if snap.is_empty():
		if _runtime == null:
			return false
		snap = _runtime.get_snapshot()
	var side := _taker_side(snap)
	if side == "":
		return false
	for controller in ShellState.controllers:
		if not (controller is Dictionary):
			continue
		if _controller_side(controller) != side:
			continue
		var controller_kind := str(controller.get("kind", "keyboard"))
		if controller_kind != kind:
			continue
		if kind == "gamepad" and int(controller.get("device", -1)) != device:
			continue
		return true
	return false


# The taking side, resolved from the human in the taker's team (snapshot
# set_piece_hud_player) or the actual taker, never from "the first human".
func _taker_side(snap: Dictionary) -> String:
	var players: Array = []
	if _runtime != null and _runtime.has_method("get_player_ids"):
		players = _runtime.get_player_ids()
	for key in ["set_piece_hud_player", "referee_taker"]:
		var player_id := int(snap.get(key, -1))
		if player_id < 0:
			continue
		for entry in players:
			if int(entry.get("id", -1)) == player_id:
				var team := int(entry.get("team", -1))
				if team == 0:
					return "home"
				if team == 1:
					return "away"
	var team := int(snap.get("referee_team", -1))
	if team == 0:
		return "home"
	if team == 1:
		return "away"
	return ""


func _controller_side(controller: Dictionary) -> String:
	return "away" if str(controller.get("side", "home")) == "away" else "home"


func is_phase_menu_open() -> bool:
	return phase_menu_open


func handle_phase_menu_key(event: InputEventKey) -> void:
	if not event.pressed or not phase_menu_game_over:
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_quit_game()


func _sync_taker_ui(snap: Dictionary) -> void:
	if taker_menu != null and taker_menu.is_open():
		# Auto-close on the strike / end of the set piece / losing the human
		# taker, exactly like SetPieceTakerPage::Process(). If the bridge still
		# reports the overlay open, close it there too.
		var still_taker := bool(snap.get("set_piece_taker_menu_open", false)) \
			and bool(snap.get("in_set_piece", false)) \
			and bool(snap.get("set_piece_local_taker", false))
		if not still_taker:
			taker_menu.close(false, bool(snap.get("set_piece_taker_menu_open", false)))
	var hint_visible := bool(snap.get("set_piece_local_taker", false)) \
		and (taker_menu == null or not taker_menu.is_open()) and not phase_menu_open \
		and not bool(snap.get("shootout_active", false)) \
		and bool(snap.get("in_set_piece", false))
	if taker_hint != null:
		taker_hint.visible = hint_visible
		if hint_visible:
			var hud_player := int(snap.get("set_piece_hud_player", -1))
			if hud_player != _hint_player_id:
				_hint_player_id = hud_player
				taker_hint.text = "Select: change taker" \
					if _taker_owner_kind(snap) == "gamepad" else "Tab: change taker"
		else:
			_hint_player_id = -2


func _taker_owner_kind(snap: Dictionary) -> String:
	var side := _taker_side(snap)
	for controller in ShellState.controllers:
		if controller is Dictionary and _controller_side(controller) == side:
			return str(controller.get("kind", "keyboard"))
	return "keyboard"


func show_substitution_notice(lines: Array) -> void:
	if substitution_notice == null or lines.is_empty():
		return
	var text_lines := PackedStringArray()
	for line in lines:
		text_lines.append(str(line))
	substitution_notice.text = "\n".join(text_lines)
	substitution_notice.visible = true
	_sub_notice_hide_ms = Time.get_ticks_msec() + 5000


func _sync_substitution_notice(snap: Dictionary) -> void:
	if substitution_notice == null:
		return
	var counter := int(snap.get("substitution_notice_counter", 0))
	if _sub_notice_counter < 0:
		# First snapshot of this presentation (a rejoin can already carry the
		# host's substitution history): treat it as the baseline, do not replay
		# someone else's old substitutions as fresh banners.
		_sub_notice_counter = counter
	elif counter != _sub_notice_counter:
		if counter > _sub_notice_counter:
			var notices: Array = snap.get("substitution_notices", [])
			var start_index := maxi(_sub_notice_counter, 0)
			var fresh := notices.slice(mini(start_index, notices.size()))
			show_substitution_notice(fresh)
		_sub_notice_counter = counter
	if substitution_notice.visible and Time.get_ticks_msec() > _sub_notice_hide_ms:
		substitution_notice.visible = false


# Original Match::Process draws one caption at 50% width / 5% height and hides
# it when messageCaptionRemoveTime_ms (actual match time, not wall clock)
# passes. Dedupe by counter, never by text: the host and a thin client both
# re-create the caption from the same counter, and the first snapshot of a
# presentation is a baseline so a rejoin does not replay an old message.
func _sync_spam_message(snap: Dictionary) -> void:
	if message_label == null:
		return
	var counter := int(snap.get("spam_message_counter", 0))
	var text := String(snap.get("spam_message", ""))
	var now := int(snap.get("actual_time_ms", 0))
	# The shootout draws its own circle rows at the top and owns the end of the
	# match; a match caption would land on them.
	_shootout_active = bool(snap.get("shootout_active", false))
	if _spam_counter < 0:
		_spam_counter = counter
	elif counter != _spam_counter:
		_spam_counter = counter
		if text != "":
			message_label.text = text
			_spam_active = true
			_spam_hide_at_ms = now + maxi(0, int(snap.get("spam_message_time_ms", 3000)))
	if _spam_active and now >= _spam_hide_at_ms:
		_spam_active = false
	_refresh_message_visibility()


func _refresh_message_visibility() -> void:
	if message_label == null:
		return
	message_label.visible = _spam_active and not _replay_mode and not _shootout_active


func _message_showing() -> bool:
	return message_label != null and message_label.visible


func _sync_game_over_menu(snap: Dictionary) -> void:
	# The shootout presentation owns the end of the match: it shows its own winner banner and quits.
	if bool(snap.get("shootout_active", false)):
		if phase_menu_open:
			_close_phase_menu()
		return
	if not bool(snap.get("game_over", false)):
		if phase_menu_open:
			_close_phase_menu()
		return
	if not phase_menu_open:
		_open_phase_menu(snap)
	else:
		_refresh_phase_menu(snap)


func _open_phase_menu(snap: Dictionary) -> void:
	if is_taker_menu_open():
		close_taker_menu(false)
	phase_menu_open = true
	phase_menu_layer.visible = true
	_refresh_phase_menu(snap)
	phase_menu_quit.grab_focus()


func _refresh_phase_menu(snap: Dictionary) -> void:
	phase_menu_game_over = true
	var after_extra := int(snap.get("match_time_ms", 0)) >= 7200000 \
		or int(snap.get("match_phase", 0)) == 5
	phase_menu_title.text = "AFTER EXTRA TIME" if after_extra else "FULL TIME"
	phase_menu_subtitle.text = "Final score"
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
	phase_menu_hint.text = "Enter / Esc: main menu"
	phase_menu_quit.text = "Main menu"


func _close_phase_menu() -> void:
	phase_menu_open = false
	phase_menu_layer.visible = false


func _quit_game() -> void:
	# The result menu's "Main menu" leaves; the scene orchestrator stops the
	# match on its way out.
	main_menu_requested.emit()


func _status_text(snap: Dictionary, display_player_id: int) -> String:
	if bool(snap.get("shootout_active", false)):
		return "SHOOTOUT"
	if bool(snap.get("game_over", false)):
		return "MATCH OVER"
	if bool(snap.get("paused", false)):
		return "PAUSED"
	if bool(snap.get("goal_scored", false)):
		return "GOAL — restart"
	var piece := int(snap.get("referee_set_piece", 0))
	var role := int(snap.get("set_piece_role", 0))
	if bool(snap.get("in_set_piece", false)):
		var human_team := -1
		if _runtime != null:
			human_team = int(_runtime.get_human_team_id())
		elif snap.has("human_team"):
			human_team = int(snap.get("human_team", -1))
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
		if taker == display_player_id or bool(snap.get("set_piece_human_taker", false)):
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


func set_visible(value: bool) -> void:
	if root_layer != null:
		root_layer.visible = value


func _build_hud() -> void:
	root_layer = CanvasLayer.new()
	var layer := root_layer
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

	substitution_notice = Label.new()
	substitution_notice.anchor_left = 0.10
	substitution_notice.anchor_right = 0.90
	substitution_notice.anchor_top = 0.24
	substitution_notice.anchor_bottom = 0.34
	substitution_notice.offset_left = 0
	substitution_notice.offset_right = 0
	substitution_notice.offset_top = 0
	substitution_notice.offset_bottom = 0
	substitution_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	substitution_notice.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	substitution_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	substitution_notice.add_theme_font_size_override("font_size", 26)
	substitution_notice.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	substitution_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	substitution_notice.add_theme_constant_override("outline_size", 5)
	substitution_notice.text = ""
	substitution_notice.visible = false
	layer.add_child(substitution_notice)

	message_label = Label.new()
	message_label.name = "MatchMessage"
	message_label.anchor_left = 0.05
	message_label.anchor_right = 0.95
	message_label.anchor_top = 0.085
	message_label.anchor_bottom = 0.085
	message_label.offset_left = 0
	message_label.offset_right = 0
	message_label.offset_top = 0
	message_label.offset_bottom = 64
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 30)
	message_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.text = ""
	message_label.visible = false
	layer.add_child(message_label)


func _build_taker_menu() -> void:
	# SetPieceTakerPage draws over the pitch without a blackout (only the main
	# menu blacks out), so this overlay is transparent except for its buttons.
	var layer := CanvasLayer.new()
	layer.name = "TakerMenu"
	layer.layer = 2
	add_child(layer)
	taker_menu = GpfSetPieceTakerMenu.new()
	taker_menu.name = "SetPieceTakerMenu"
	layer.add_child(taker_menu)
	taker_menu.setup(_runtime)


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

	phase_menu_quit = Button.new()
	phase_menu_quit.text = "Main menu"
	phase_menu_quit.custom_minimum_size = Vector2(160, 40)
	buttons.add_child(phase_menu_quit)
	phase_menu_quit.pressed.connect(_quit_game)

	phase_menu_hint = Label.new()
	phase_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_hint.add_theme_font_size_override("font_size", 14)
	phase_menu_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(phase_menu_hint)

	phase_menu_layer.visible = false
