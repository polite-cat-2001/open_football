extends Control
# UI stand: show the in-match HUD and shootout overlays from canned snapshots,
# without starting the C++ runtime. Number keys choose a state, Left/Right cycle.

const STATE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]

var hud: GpfHud
var shootout: GpfShootoutView
var pause_menu: GpfPauseMenu
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
	return states


func set_state(index: int) -> void:
	if _states.is_empty():
		return
	state_index = wrapi(index, 0, _states.size())
	_current = _states[state_index]
	if pause_menu.is_open():
		pause_menu.close()
	hud.reset()
	shootout.reset()
	var snap: Dictionary = _current["snap"]
	hud.apply_snapshot(snap, int(snap.get("display_player", -1)))
	shootout.update(snap, 0.0)
	if String(_current.get("name", "")) == "PAUSE":
		pause_menu.open()
	caption.text = "UI LAB  [1..%d] state  Left/Right  —  %s" % [
		_states.size(), String(_current.get("name", "")),
	]


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
