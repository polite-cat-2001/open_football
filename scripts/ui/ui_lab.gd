extends Control
# UI stand: show the in-match HUD and shootout overlays from canned snapshots,
# without starting the C++ runtime. Number keys choose a state, Left/Right cycle.

const STATE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var hud: GpfHud
var shootout: GpfShootoutView
var pause_menu: GpfPauseMenu
var game_plan: GpfGamePlan
var caption: Label
var state_index := 0
var _states: Array = []
var _current: Dictionary = {}


func _ready() -> void:
	_build_background()
	var layers := CanvasLayer.new()
	layers.layer = 10
	add_child(layers)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	caption.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.offset_left = -470
	caption.offset_top = -44
	caption.offset_right = -24
	caption.offset_bottom = -14
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	caption.add_theme_constant_override("outline_size", 4)
	layers.add_child(caption)

	hud = GpfHud.new()
	add_child(hud)
	hud.setup(null)
	shootout = GpfShootoutView.new()
	add_child(shootout)
	shootout.setup()
	pause_menu = GpfPauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup()
	var plan_layer := CanvasLayer.new()
	plan_layer.layer = 5
	add_child(plan_layer)
	game_plan = GpfGamePlan.new()
	game_plan.name = "GamePlan"
	game_plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plan_layer.add_child(game_plan)

	_states = _build_states()
	set_state(0)


func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.22, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var stripe := ColorRect.new()
	stripe.color = Color(0.08, 0.27, 0.11)
	stripe.position = Vector2(0, 180)
	stripe.size = Vector2(2400, 180)
	add_child(stripe)


func _base_state(name: String) -> Dictionary:
	return {
		"name": name,
		"snap": {
			"score0": 0, "score1": 0, "match_time_ms": 0, "match_phase": 1,
			"team0_name": "ALASHKERT", "team1_name": "AFGHANISTAN",
			"match_duration": 1.0, "human_team": 0,
			"in_play": false, "in_set_piece": false,
			"phase_break_pending": false, "phase_break": false,
			"phase_break_next_phase": 0,
			"game_over": false, "paused": false, "goal_scored": false,
			"shootout_active": false,
			"possession0_ms": 1500000, "possession1_ms": 1200000,
			"shots0": 9, "shots1": 6,
			"display_player": 0,
			"actual_time_ms": 1000,
		},
	}


func _with(base: Dictionary, overrides: Dictionary) -> Dictionary:
	base["snap"].merge(overrides, true)
	return base


func _build_states() -> Array:
	var states: Array = []

	var kickoff := _base_state("KICKOFF")
	states.append(_with(kickoff, {
		"in_set_piece": true, "referee_set_piece": 1, "set_piece_type": 1,
		"set_piece_role": 1, "set_piece_local_taker": true, "referee_taker": 0,
	}))

	var live := _base_state("LIVE")
	states.append(_with(live, {
		"score0": 1, "score1": 0, "match_time_ms": 754000, "in_play": true,
	}))

	var goal := _base_state("GOAL")
	states.append(_with(goal, {
		"score0": 2, "score1": 1, "match_time_ms": 2700000,
		"goal_scored": true, "last_goal_team": 0,
		"spam_message": "GOAL for ALASHKERT! KRAMER scores!",
		"spam_message_time_ms": 4000, "spam_message_counter": 1,
	}))

	var free_kick := _base_state("FREE KICK")
	states.append(_with(free_kick, {
		"score0": 2, "score1": 1, "match_time_ms": 2730000,
		"in_set_piece": true, "referee_set_piece": 3, "set_piece_type": 3,
		"set_piece_role": 1, "set_piece_local_taker": true,
	}))

	var halftime := _base_state("HALF TIME")
	states.append(_with(halftime, {
		"score0": 2, "score1": 1, "match_time_ms": 2700000,
		"phase_break_pending": true, "phase_break": true,
		"phase_break_next_phase": 2,
	}))

	var fulltime := _base_state("FULL TIME")
	states.append(_with(fulltime, {
		"score0": 3, "score1": 2, "match_time_ms": 5400000,
		"match_phase": 2, "game_over": true,
	}))

	var shootout := _base_state("SHOOTOUT")
	states.append(_with(shootout, {
		"score0": 2, "score1": 2, "match_time_ms": 7200000, "match_phase": 5,
		"shootout_active": true, "shootout_phase": 2,
		"shootout_score0": 3, "shootout_score1": 2,
		"shootout_kicks0": [1, 1, 2, 1, 0],
		"shootout_kicks1": [1, 2, 1, 0, 0],
		"shootout_outcome": 1, "shootout_outcome_counter": 0,
	}))

	var shootout_end := _base_state("SHOOTOUT END")
	states.append(_with(shootout_end, {
		"score0": 2, "score1": 2, "match_time_ms": 7200000, "match_phase": 5,
		"shootout_active": true, "shootout_phase": 6,
		"shootout_score0": 4, "shootout_score1": 2,
		"shootout_kicks0": [1, 1, 1, 1, 1],
		"shootout_kicks1": [1, 1, 2, 2, 0],
		"shootout_outcome": 1, "shootout_outcome_counter": 0,
	}))

	var pause := _base_state("PAUSE")
	states.append(_with(pause, {
		"score0": 1, "score1": 1, "match_time_ms": 3120000, "in_play": true,
	}))

	var plan := _base_state("GAME PLAN")
	states.append(_with(plan, {
		"score0": 1, "score1": 0, "match_time_ms": 1800000, "in_play": true,
	}))

	var plan_2p := _base_state("GAME PLAN 2P")
	states.append(_with(plan_2p, {
		"score0": 1, "score1": 1, "match_time_ms": 1800000, "in_play": true,
		"human_team": 0,
	}))

	var plan_tactics := _base_state("GAME PLAN TACTICS")
	states.append(_with(plan_tactics, {
		"score0": 1, "score1": 1, "match_time_ms": 1800000, "in_play": true,
	}))

	var plan_roles := _base_state("GAME PLAN ROLES")
	states.append(_with(plan_roles, {
		"score0": 1, "score1": 1, "match_time_ms": 1800000, "in_play": true,
	}))

	var plan_select := _base_state("GAME PLAN SELECT")
	states.append(_with(plan_select, {
		"score0": 1, "score1": 1, "match_time_ms": 1800000, "in_play": true,
	}))

	var sub_notice := _base_state("SUBSTITUTION")
	states.append(_with(sub_notice, {
		"score0": 1, "score1": 1, "match_time_ms": 1900000, "in_play": true,
		"substitution_notice_counter": 1,
		"substitution_notices": ["RIVERA off, KOVAL on"],
	}))

	var card := _base_state("CARD")
	states.append(_with(card, {
		"score0": 1, "score1": 1, "match_time_ms": 2000000, "in_play": true,
		"spam_message": "FOUL! YELLOW CARD", "spam_message_time_ms": 3000,
		"spam_message_counter": 1,
	}))

	var taker := _base_state("SET-PIECE TAKER")
	states.append(_with(taker, {
		"score0": 2, "score1": 1, "match_time_ms": 2730000,
		"in_set_piece": true, "referee_set_piece": 3, "set_piece_type": 3,
		"set_piece_role": 1, "set_piece_local_taker": true,
		"set_piece_human_taker": true, "set_piece_hud_player": 105,
		"referee_taker": 105, "referee_team": 0,
		"set_piece_taker_menu_available": true, "set_piece_taker_menu_open": true,
	}))
	return states


func _demo_taker_candidates() -> Array:
	var captions := [
		"KRAMER", "VELASCO", "BRANDT", "DUARTE", "OKAFOR", "SORENSEN",
		"ALMEIDA", "MARCHETTI", "IWU", "KOVAL", "RIVERA",
	]
	var entries: Array = []
	for index in captions.size():
		entries.append({
			"id": 100 + index,
			"team": 0,
			"name": captions[index],
			"role": "goalkeeper" if index == 0 else "player",
			"current": index == 4,
		})
	return entries


func _demo_team(name: String, color: Color, pending: bool = false) -> Dictionary:
	var roles := ["GK", "CB", "CB", "LB", "RB", "DM", "CM", "CM", "LM", "RM", "ST"]
	var positions := [
		Vector2(-1.0, 0.0), Vector2(-0.8, -0.2), Vector2(-0.8, 0.2),
		Vector2(-0.7, -0.75), Vector2(-0.7, 0.75), Vector2(-0.45, 0.0),
		Vector2(-0.1, -0.25), Vector2(-0.1, 0.25), Vector2(0.25, -0.7),
		Vector2(0.25, 0.7), Vector2(0.8, 0.0),
	]
	var bench_roles := ["GK", "CB", "LB", "DM", "CM", "LM", "ST"]
	var players: Array = []
	for index in roles.size():
		players.append({
			"id": 100 + index,
			"slot": index,
			"name": "%s %d" % [name.substr(0, 3), index + 1],
			"role": roles[index],
			"position": positions[index],
			"active": true,
			"left_pitch": false,
			"pending_out": pending and index == 6,
			"pending_in": false,
			"rating": 62 + (index * 3) % 30,
			"fatigue": 100 - index * 7,
		})
	for index in bench_roles.size():
		players.append({
			"id": 200 + index,
			"slot": roles.size() + index,
			"name": "%s SUB %d" % [name.substr(0, 3), index + 1],
			"role": bench_roles[index],
			"position": Vector2.ZERO,
			"active": false,
			"left_pitch": false,
			"pending_out": false,
			"pending_in": pending and index == 3,
			"rating": 58 + (index * 4) % 25,
			"fatigue": 100,
		})
	return {
		"name": name,
		"color": color,
		"players": players,
		"roles": [5, 10, 7, 8, 9, 6],
	}


func set_state(index: int) -> void:
	if _states.is_empty():
		return
	state_index = wrapi(index, 0, _states.size())
	_current = _states[state_index]
	if pause_menu.is_open():
		pause_menu.close()
	if game_plan.is_open():
		game_plan.close_plan()
	hud.reset()
	shootout.reset()
	var snap: Dictionary = _current["snap"]
	var state_name := String(_current.get("name", ""))
	# The HUD treats the first snapshot after reset as a baseline (rejoin/F4),
	# so the stand primes it before presenting a state with an announcement.
	var baseline: Dictionary = _base_state("baseline")["snap"]
	baseline["actual_time_ms"] = 0
	hud.apply_snapshot(baseline, int(snap.get("display_player", -1)), 0, false,
		"Afternoon")
	if state_name == "SET-PIECE TAKER":
		hud.show_taker_menu_demo(_demo_taker_candidates(), 4)
	hud.apply_snapshot(snap, int(snap.get("display_player", -1)), 0, false,
		"Afternoon")
	shootout.update(snap, 0.0)
	if state_name == "PAUSE":
		pause_menu.open()
	elif state_name == "GAME PLAN":
		game_plan.setup_demo(_demo_team("ALASHKERT", Color(0.2, 0.4, 0.9)),
			_demo_team("AFGHANISTAN", Color(0.9, 0.2, 0.2)), [0])
		game_plan.open_plan()
	elif state_name == "GAME PLAN 2P":
		game_plan.setup_demo(_demo_team("ALASHKERT", Color(0.2, 0.4, 0.9), true),
			_demo_team("AFGHANISTAN", Color(0.9, 0.2, 0.2)), [0, 1])
		game_plan.open_plan()
	elif state_name.begins_with("GAME PLAN"):
		game_plan.setup_demo(_demo_team("ALASHKERT", Color(0.2, 0.4, 0.9)),
			_demo_team("AFGHANISTAN", Color(0.9, 0.2, 0.2)), [0])
		game_plan.open_plan()
		if state_name == "GAME PLAN TACTICS":
			game_plan.call("_set_section", (game_plan.get("_panels") as Array)[0], 0)
		elif state_name == "GAME PLAN ROLES":
			game_plan.call("_set_section", (game_plan.get("_panels") as Array)[0], 2)
		elif state_name == "GAME PLAN SELECT":
			var panel: Dictionary = (game_plan.get("_panels") as Array)[0]
			game_plan.call("_set_section", panel, 1)
			panel["cursor"] = int((panel["pitch_entries"] as Array)[3])
			panel["held"] = int((panel["pitch_entries"] as Array)[4])
			game_plan.call("_refresh_panel", panel)
			game_plan.call("set_status", "Selected player - choose any other player", 60000)
	caption.text = "UI LAB  [1..9,0] state  Left/Right  —  %s" % [state_name]


func state_name() -> String:
	return String(_current.get("name", ""))


func set_caption_visible(value: bool) -> void:
	caption.visible = value


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	shootout.update(_current["snap"], delta)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key in STATE_KEYS:
		set_state(STATE_KEYS.find(key))
	elif key == KEY_RIGHT:
		set_state(state_index + 1)
	elif key == KEY_LEFT:
		set_state(state_index - 1)
	else:
		return
	get_viewport().set_input_as_handled()
