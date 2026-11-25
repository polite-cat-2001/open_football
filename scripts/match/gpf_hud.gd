class_name GpfHud
extends Node
# In-match HUD and its overlays: score/clock/status bar and the set-piece taker
# overlay. The phase break is not drawn here: it reuses the design-system pause
# screen (GpfPauseMenu.open_break). The end-of-match screens live in GpfMatchOver.

const SET_PIECE_NAMES := [
	"",
	"KICKOFF",
	"GOAL KICK",
	"FREE KICK",
	"CORNER",
	"THROW-IN",
	"PENALTY",
]

const TV_LOGO := "res://assets/gpf/media/menu/tvlogo.png"

enum BannerMode { NONE, EVENT, GOAL, KICKOFF }

var hud: Label
var scoreboard: MatchScoreboard
var tv_logo: TextureRect
var charge_bar: ChargeBar
var set_piece_hints: SetPieceHints
var substitution_stack: SubstitutionStack
var _sub_notice_counter := -1
var _legacy_hidden := false
var _force_hidden := false

var event_banner: EventBanner
var kickoff_banner: KickoffBanner
var _last_score0 := 0
var _last_score1 := 0
var _spam_counter := -1
var _spam_hide_at_ms := 0
var _spam_active := false
var _spam_text := ""
var _shootout_active := false
var _goal_log: Array[Dictionary] = []
var _card_log: Array[Dictionary] = []
var _red_ids: Array = [[], []]
var _card_baseline := true
var _score_baseline := true
var _goal_seen := false
var _last_match_ms := 0
var _player_names: Dictionary = {}

var taker_menu: GpfSetPieceTakerMenu

var root_layer: CanvasLayer

var _runtime: Node
var _replay_mode := false
var _chrome_visible := true
var net_client := false


func setup(runtime: Node) -> void:
	_runtime = runtime
	_build_hud()
	_build_taker_menu()


func set_net_client(value: bool) -> void:
	net_client = value


# Stable presentation seam: the HUD is a pure function of the snapshot. The
# runtime (C++ bridge) is only needed for actions, never for drawing.
func apply_snapshot(snap: Dictionary, display_player_id: int = -1,
		actor_count: int = 0, stadium_camera: bool = false,
		lighting_name: String = "Afternoon") -> void:
	update(snap, display_player_id, actor_count, stadium_camera, lighting_name)


func update(snap: Dictionary, display_player_id: int, actor_count: int,
		stadium_camera: bool, lighting_name: String) -> void:
	_sync_taker_ui(snap, display_player_id)
	_sync_substitution_notice(snap)
	_sync_spam_message(snap)
	_update_goal_log(snap)
	_update_card_log(snap)
	if hud == null:
		return
	var status := _status_text(snap, display_player_id)
	var on_break := bool(snap.get("phase_break_pending", false)) \
		or bool(snap.get("phase_break", false))
	var paused := bool(snap.get("paused", false)) or on_break
	var chrome_visible := _replay_mode or not paused
	_chrome_visible = chrome_visible
	root_layer.visible = not _force_hidden and not paused
	if scoreboard != null:
		scoreboard.apply(int(snap.get("score0", 0)), int(snap.get("score1", 0)),
			_format_clock(int(snap.get("match_time_ms", 0))))
		scoreboard.set_cards(int(snap.get("red_cards0", 0)), int(snap.get("red_cards1", 0)))
		scoreboard.visible = chrome_visible
	if tv_logo != null:
		tv_logo.visible = chrome_visible
	_sync_banners(snap, chrome_visible)
	var duration := 1.0
	if _runtime != null:
		duration = float(_runtime.get("match_duration"))
	elif snap.has("match_duration"):
		duration = float(snap.get("match_duration", 1.0))
	var match_minutes := int(round(MatchPackage.minutes_from_duration(duration)))
	# The ported taker overlay replaces the dev key legend while it is up: the
	# original page draws over the pitch and has no second text block under it.
	hud.visible = not _replay_mode and not is_taker_menu_open() and not _legacy_hidden
	var park_text := "F2 unpark opponents" if bool(snap.get("debug_park_opponents", false)) \
		else "F2 park opponents"
	var camera_text := "F6 broadcast cam" if stadium_camera else "F6 stadium cam"
	hud.text = "%s\nArrows move   E sprint   S pass   D shot   W through   A high   C dribble   Q switch   match ~%d min\nD+C curl   D+Q chip   double-E knock-on   P pen   Alt+P defend pen   F free kick   Y corner   G goal kick   O throw-in   Tab taker   F4 new match   F5 skip to break   %s   %s   F7 pitch   F8 time: %s" % [
		status,
		match_minutes,
		park_text,
		camera_text,
		lighting_name,
	]
	# The control legend must fit 1280-wide screens too: wrap it to the
	# viewport and push the taker hint below the wrapped block.
	var viewport := get_viewport()
	var view := viewport.get_visible_rect().size if viewport != null else Vector2(1920, 1080)
	var view_width := view.x
	var view_height := view.y
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.size = Vector2(maxf(320.0, view_width - 48.0), 0)
	hud.size.y = hud.get_minimum_size().y
	var stack_on := substitution_stack != null and substitution_stack.has_entries() \
		and chrome_visible
	var legend_top := 64.0
	if scoreboard != null and scoreboard.visible:
		legend_top += maxf(0.0, scoreboard.size.y - MatchScoreboard.PLATE_H)
	if _shootout_active:
		# The series dots hang under the scoreboard; the dev legend starts below
		# them instead of drawing through the circles.
		legend_top += ShootoutDots.HEIGHT + 10.0
	if stack_on:
		# The stack shares the scoreboard's top line; keep the dev text below it.
		legend_top = maxf(legend_top, 14.0 + substitution_stack.size.y + 8.0)
	hud.position = Vector2(24, legend_top)
	# The contextual plate lives on the right, vertically centred.
	if set_piece_hints != null:
		set_piece_hints.position = Vector2(
			roundf(view_width - set_piece_hints.size.x - 24.0),
			roundf((view_height - set_piece_hints.size.y) * 0.5))
	if substitution_stack != null:
		substitution_stack.position = Vector2(
			roundf((view_width - substitution_stack.size.x) * 0.5), 14.0)
		substitution_stack.visible = stack_on


func set_replay_mode(active: bool) -> void:
	_replay_mode = active
	if hud != null:
		hud.visible = not active and not is_taker_menu_open()
	if charge_bar != null:
		charge_bar.visible = false
	if event_banner != null:
		event_banner.present(false)
	if kickoff_banner != null:
		kickoff_banner.present(false)
	if set_piece_hints != null:
		set_piece_hints.visible = false
	if substitution_stack != null:
		substitution_stack.visible = false


# The bar is screen-space: gpf_slice projects an anchor point and pushes it here
# every frame. Set pieces anchor above the striker's head (the close camera puts
# the feet at the bottom edge); open play anchors under the feet.
func set_charge(ratio: float, screen_pos: Vector2, above_head := false) -> void:
	if charge_bar == null:
		return
	var show := ratio > 0.01 and screen_pos.is_finite() and _chrome_visible \
		and not _replay_mode
	charge_bar.visible = show
	if show:
		charge_bar.set_ratio(ratio)
		var view := get_viewport().get_visible_rect().size
		var offset := Vector2(-ChargeBar.BAR_W * 0.5, -16.0 if above_head else 14.0)
		var pos := screen_pos + offset
		pos.x = clampf(pos.x, 8.0, view.x - ChargeBar.BAR_W - 8.0)
		pos.y = clampf(pos.y, 8.0, view.y - ChargeBar.BAR_H - 8.0)
		charge_bar.position = pos.round()


func set_match_package(package: Dictionary) -> void:
	if scoreboard != null:
		scoreboard.set_teams(package.get("home", {}), package.get("away", {}))
	if kickoff_banner != null:
		kickoff_banner.set_teams(package.get("home", {}), package.get("away", {}))
	if substitution_stack != null:
		substitution_stack.set_crests(
			UiAssets.package_crest(package.get("home", {})),
			UiAssets.package_crest(package.get("away", {})))
	_player_names.clear()
	for side in ["home", "away"]:
		for player in package.get(side, {}).get("players", []):
			var id := int(player.get("database_id", -1))
			var name := str(player.get("last_name", ""))
			if name.is_empty():
				name = str(player.get("first_name", ""))
			if id > 0:
				_player_names[id] = name


func reset() -> void:
	close_taker_menu(false)
	set_replay_mode(false)
	if charge_bar != null:
		charge_bar.visible = false
	if event_banner != null:
		event_banner.present(false)
	if kickoff_banner != null:
		kickoff_banner.present(false)
	if set_piece_hints != null:
		set_piece_hints.visible = false
	if substitution_stack != null:
		substitution_stack.visible = false
	_sub_notice_counter = -1
	_legacy_hidden = false
	if substitution_stack != null:
		substitution_stack.reset()
	if set_piece_hints != null:
		set_piece_hints.reset()
	_spam_counter = -1
	_spam_hide_at_ms = 0
	_spam_active = false
	_spam_text = ""
	_shootout_active = false
	_goal_log.clear()
	_card_log.clear()
	_red_ids = [[], []]
	_card_baseline = true
	_score_baseline = true
	_goal_seen = false
	_last_match_ms = 0
	_last_score0 = 0
	_last_score1 = 0


# Alt+X hides only the old text HUD (legend + status); the design-system pieces
# stay on screen (ticket 10).
func toggle_legacy_hud() -> void:
	_legacy_hidden = not _legacy_hidden
	if hud != null:
		hud.visible = not _legacy_hidden and not _replay_mode \
			and not is_taker_menu_open()


func is_legacy_hidden() -> bool:
	return _legacy_hidden


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


func _sync_taker_ui(snap: Dictionary, display_player_id: int) -> void:
	if taker_menu != null and taker_menu.is_open():
		# Auto-close on the strike / end of the set piece / losing the human
		# taker, exactly like SetPieceTakerPage::Process(). If the bridge still
		# reports the overlay open, close it there too.
		var still_taker := bool(snap.get("set_piece_taker_menu_open", false)) \
			and bool(snap.get("in_set_piece", false)) \
			and bool(snap.get("set_piece_local_taker", false))
		if not still_taker:
			taker_menu.close(false, bool(snap.get("set_piece_taker_menu_open", false)))
	if set_piece_hints == null:
		return
	var rows: Array = []
	var paused := bool(snap.get("paused", false)) \
		or bool(snap.get("phase_break_pending", false)) \
		or bool(snap.get("phase_break", false))
	if bool(snap.get("in_set_piece", false)) \
			and not bool(snap.get("shootout_active", false)) \
			and not paused and not _replay_mode:
		var piece := int(snap.get("referee_set_piece", 0))
		if piece == 0:
			piece = int(snap.get("set_piece_type", 0))
		var role := int(snap.get("set_piece_role", 0))
		if bool(snap.get("set_piece_local_taker", false)) \
				and (taker_menu == null or not taker_menu.is_open()):
			rows.append({"key": "Select" if _taker_owner_kind(snap) == "gamepad" else "Tab",
				"label": "change taker"})
		if role == 2:
			rows.append({"key": "Arrows", "label": "dive"})
		elif role == 1:
			var keys := _action_keys(snap)
			if piece == 6:
				rows.append({"key": keys["shot"], "label": "shot"})
			else:
				rows.append({"key": keys["pass"], "label": "pass"})
				rows.append({"key": keys["shot"], "label": "shot"})
				rows.append({"key": keys["cross"], "label": "cross"})
		elif piece == 6:
			var human_team := _human_team_of(snap, display_player_id)
			if human_team >= 0 and int(snap.get("referee_team", -1)) != human_team:
				rows.append({"key": "Arrows", "label": "dive"})
	set_piece_hints.set_hints(rows)
	set_piece_hints.visible = not rows.is_empty()


func _human_team_of(snap: Dictionary, display_player_id: int) -> int:
	if _runtime != null:
		# The selected player's team from the bridge roster; the raw human-team
		# id is unreliable on a LAN host after controller rebinds.
		for entry in _runtime.get_player_ids():
			if int(entry.get("id", -1)) == display_player_id:
				return int(entry.get("team", -1))
	elif snap.has("human_team"):
		return int(snap.get("human_team", -1))
	return -1


func _action_keys(snap: Dictionary) -> Dictionary:
	if _taker_owner_kind(snap) == "gamepad":
		return {"pass": "A", "shot": "X", "cross": "B"}
	return {"pass": "S", "shot": "D", "cross": "A"}


func _taker_owner_kind(snap: Dictionary) -> String:
	var side := _taker_side(snap)
	for controller in ShellState.controllers:
		if controller is Dictionary and _controller_side(controller) == side:
			return str(controller.get("kind", "keyboard"))
	return "keyboard"


func show_substitution_notice(lines: Array, teams: Array = []) -> void:
	if substitution_stack == null or lines.is_empty():
		return
	substitution_stack.push_lines(lines, teams)


func _sync_substitution_notice(snap: Dictionary) -> void:
	if substitution_stack == null:
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
			var notice_teams: Array = snap.get("substitution_notice_teams", [])
			var start_index := maxi(_sub_notice_counter, 0)
			var fresh := notices.slice(mini(start_index, notices.size()))
			var fresh_teams := notice_teams.slice(mini(start_index, notice_teams.size()))
			show_substitution_notice(fresh, fresh_teams)
		_sub_notice_counter = counter


# Original Match::Process draws one caption at 50% width / 5% height and hides
# it when messageCaptionRemoveTime_ms (actual match time, not wall clock)
# passes. Dedupe by counter, never by text: the host and a thin client both
# re-create the caption from the same counter, and the first snapshot of a
# presentation is a baseline so a rejoin does not replay an old message.
func _sync_spam_message(snap: Dictionary) -> void:
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
		# "advantage" is an original debug-only notice; the port does not show it.
		if text.to_lower().strip_edges() == "advantage":
			text = ""
		if text != "":
			_spam_text = text
			_spam_active = true
			_spam_hide_at_ms = now + maxi(0, int(snap.get("spam_message_time_ms", 3000)))
	if _spam_active and now >= _spam_hide_at_ms:
		_spam_active = false
		_spam_text = ""


# Goal log: one entry per goal, built from the same snapshot on every peer (no
# extra network message). The minute is the match clock at the goal edge, so the
# kickoff banner can list the scorers until play restarts.
func _update_goal_log(snap: Dictionary) -> void:
	var now_ms := int(snap.get("match_time_ms", 0))
	var goal := bool(snap.get("goal_scored", false))
	var score0 := int(snap.get("score0", 0))
	var score1 := int(snap.get("score1", 0))
	# A rejoin (or a new match) starts without a known previous score. Take the
	# first snapshot as the baseline and skip the goal that is already in
	# progress: guessing from 0:0 can put the goal on the wrong side.
	if _score_baseline:
		_score_baseline = false
		_last_match_ms = now_ms
		_last_score0 = score0
		_last_score1 = score1
		_goal_seen = goal
		return
	if now_ms + 5000 < _last_match_ms and not goal:
		_goal_log.clear()
		_card_log.clear()
		_red_ids = [[], []]
		_card_baseline = true
		_score_baseline = true
		_spam_counter = -1
		_spam_hide_at_ms = 0
		_spam_active = false
		_spam_text = ""
	_last_match_ms = now_ms
	if goal and not _goal_seen:
		# The bridge never learns the host's goal team on a thin client (the
		# C++ value stays 0), so use the score change there instead.
		var team := -1 if net_client else int(snap.get("last_goal_team", -1))
		if team < 0:
			if score0 > _last_score0:
				team = 0
			elif score1 > _last_score1:
				team = 1
		_goal_log.append({
			"team": team,
			"name": _goal_scorer_name(snap),
			"minute": maxi(1, now_ms / 60000 + 1),
			"own_goal": _is_own_goal(),
		})
	elif goal and not _goal_log.is_empty() \
			and String(_goal_log[-1].get("name", "")).is_empty():
		# A thin client learns the scorer from the relayed goal caption, which may
		# arrive a frame after the goal flag.
		var entry := _goal_log[-1]
		entry["name"] = _goal_scorer_name(snap)
		if _is_own_goal():
			entry["own_goal"] = true
	_goal_seen = goal
	_last_score0 = score0
	_last_score1 = score1


func _goal_scorer_name(snap: Dictionary) -> String:
	var name := _player_name(int(snap.get("last_goal_scorer", -1)))
	if not name.is_empty():
		return name
	# The host's goal caption carries the surname; the client has no scorer id.
	if _spam_text.begins_with("OWN GOAL! ") and _spam_text.ends_with(" is so unlucky!"):
		return _spam_text.trim_prefix("OWN GOAL! ").trim_suffix(" is so unlucky!")
	if _spam_text.begins_with("GOAL for ") and _spam_text.ends_with(" scores!"):
		var rest := _spam_text.trim_prefix("GOAL for ")
		var bang := rest.find("! ")
		if bang >= 0:
			return rest.substr(bang + 2).trim_suffix(" scores!")
	return ""


func _is_own_goal() -> bool:
	return _spam_text.contains("OWN GOAL")


# Pre-kickoff scoreboard: from the moment the referee places the ball on the
# centre spot (the prepare phase, a couple of seconds before the whistle) until
# the kickoff is actually taken. `in_set_piece` only becomes true at the whistle,
# so the prepare window is what makes the banner appear in time. A thin client
# gets the host's prepare state relayed in the snapshot.
func _is_kickoff_setup(snap: Dictionary) -> bool:
	if bool(snap.get("in_set_piece", false)):
		return int(snap.get("set_piece_type", 0)) == 1
	if int(snap.get("referee_set_piece", 0)) != 1:
		return false
	return bool(snap.get("referee_active", false)) \
		and int(snap.get("actual_time_ms", 0)) >= int(snap.get("referee_prepare_time", 0))


func _sync_banners(snap: Dictionary, chrome_visible: bool) -> void:
	var mode := BannerMode.NONE
	if not _replay_mode and not _shootout_active and chrome_visible:
		if _is_kickoff_setup(snap):
			mode = BannerMode.KICKOFF
		elif bool(snap.get("goal_scored", false)) and not _goal_log.is_empty():
			mode = BannerMode.GOAL
		elif _spam_active:
			mode = BannerMode.EVENT
	var viewport := get_viewport()
	var view := viewport.get_visible_rect().size if viewport != null else Vector2(1920, 1080)
	if event_banner != null:
		if mode == BannerMode.GOAL:
			var entry := _goal_log[-1]
			event_banner.set_goal(String(entry.get("name", "")),
				"%d'" % int(entry.get("minute", 0)),
				bool(entry.get("own_goal", false)))
		elif mode == BannerMode.EVENT:
			event_banner.set_message(_spam_text)
		var event_on := mode == BannerMode.GOAL or mode == BannerMode.EVENT
		event_banner.present(event_on)
		# The two banners share the bottom slot; a 240 ms crossfade would draw
		# their texts on top of each other on the goal -> kickoff flip.
		if mode == BannerMode.KICKOFF:
			event_banner.modulate.a = 0.0
		event_banner.position = Vector2(roundf((view.x - event_banner.size.x) * 0.5),
			roundf(view.y * 0.855))
	if kickoff_banner != null:
		if mode == BannerMode.KICKOFF:
			kickoff_banner.set_match(int(snap.get("score0", 0)),
				int(snap.get("score1", 0)), _team_events(0), _team_events(1))
		kickoff_banner.present(mode == BannerMode.KICKOFF)
		if mode == BannerMode.GOAL or mode == BannerMode.EVENT:
			kickoff_banner.modulate.a = 0.0
		kickoff_banner.position = Vector2(
			roundf((view.x - KickoffBanner.WIDTH) * 0.5),
			roundf(view.y - kickoff_banner.size.y - 28.0))


func _update_card_log(snap: Dictionary) -> void:
	var now_ms := int(snap.get("match_time_ms", 0))
	# shortcut: the minute is when the sent-off id first appears; the card show is
	# delayed ~6 s in the original, so a card at 45:50 can read 46'. A card-time
	# field on the wire would fix it.
	if _card_baseline:
		# A rejoin's first snapshot already carries the host's cards; record
		# them without inventing a minute (the goal log has no history either).
		_card_baseline = false
		for team in 2:
			var ids: Array = snap.get("red_card_ids0" if team == 0 else "red_card_ids1", [])
			for raw_id in ids:
				_red_ids[team].append(int(raw_id))
		return
	for team in 2:
		var ids: Array = snap.get("red_card_ids0" if team == 0 else "red_card_ids1", [])
		for raw_id in ids:
			var player_id := int(raw_id)
			if _red_ids[team].has(player_id):
				continue
			_red_ids[team].append(player_id)
			_card_log.append({
				"team": team,
				"name": _player_name(player_id),
				"minute": maxi(1, now_ms / 60000 + 1),
			})


# A team's kickoff-banner event lines: goals and red cards in match order.
func _team_events(team: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for entry in _goal_log:
		if int(entry.get("team", -1)) == team:
			var name := String(entry.get("name", ""))
			if bool(entry.get("own_goal", false)):
				name = (name + " (OG)") if not name.is_empty() else "OWN GOAL"
			events.append({"minute": int(entry["minute"]),
				"name": name, "card": false})
	for entry in _card_log:
		if int(entry.get("team", -1)) == team:
			events.append({"minute": int(entry["minute"]),
				"name": String(entry.get("name", "")), "card": true})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["minute"]) < int(b["minute"]))
	return events


func _player_name(player_id: int) -> String:
	return str(_player_names.get(player_id, ""))


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
		var human_team := _human_team_of(snap, display_player_id)
		if piece == 6 and human_team >= 0 \
				and int(snap.get("referee_team", -1)) != human_team:
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


func _set_piece_name(piece: int) -> String:
	if piece > 0 and piece < SET_PIECE_NAMES.size():
		return SET_PIECE_NAMES[piece]
	return ""


func set_visible(value: bool) -> void:
	_force_hidden = not value
	if root_layer != null:
		root_layer.visible = value


func _build_hud() -> void:
	root_layer = CanvasLayer.new()
	var layer := root_layer
	layer.name = "HudOverlay"
	add_child(layer)

	scoreboard = MatchScoreboard.new()
	scoreboard.name = "Scoreboard"
	scoreboard.position = Vector2(24, 14)
	layer.add_child(scoreboard)

	tv_logo = TextureRect.new()
	tv_logo.name = "TvLogo"
	tv_logo.texture = load(TV_LOGO) as Texture2D
	tv_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tv_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tv_logo.anchor_left = 1.0
	tv_logo.anchor_right = 1.0
	tv_logo.offset_left = -120.0
	tv_logo.offset_right = -24.0
	tv_logo.offset_top = 14.0
	tv_logo.offset_bottom = 62.0
	tv_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tv_logo)

	charge_bar = ChargeBar.new()
	charge_bar.name = "ChargeBar"
	layer.add_child(charge_bar)

	hud = Label.new()
	hud.position = Vector2(24, 64)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)

	set_piece_hints = SetPieceHints.new()
	set_piece_hints.name = "SetPieceHints"
	layer.add_child(set_piece_hints)

	substitution_stack = SubstitutionStack.new()
	substitution_stack.name = "SubstitutionStack"
	layer.add_child(substitution_stack)

	event_banner = EventBanner.new()
	event_banner.name = "EventBanner"
	layer.add_child(event_banner)

	kickoff_banner = KickoffBanner.new()
	kickoff_banner.name = "KickoffBanner"
	layer.add_child(kickoff_banner)


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
