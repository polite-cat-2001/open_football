extends SceneTree
# Headless check for the shared TeamSelectView: prototype geometry, focus/cues,
# ready marks, idle panel, device routing, Tab between local network slots and
# the 1280x720 scale.

const VIEW_SCENE := preload("res://scenes/ui/team_select_view.tscn")
const FIXTURE := preload("res://tests/team_select_fixture.gd")

var failures: Array[String] = []
var moves: Array = []
var confirms: Array = []
var cancels: Array = []
var backs := 0
var retries := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event


func _tap(code: int) -> void:
	Input.parse_input_event(_key(code, true))
	await _frames(2)
	Input.parse_input_event(_key(code, false))
	await _frames(1)


func _on_move(side: int, field: String, delta: int, input: Dictionary) -> void:
	moves.append({"side": side, "field": field, "delta": delta, "input": input})


func _on_confirm(side: int, input: Dictionary) -> void:
	confirms.append({"side": side, "input": input})


func _on_cancel(side: int, input: Dictionary) -> void:
	cancels.append({"side": side, "input": input})


func _on_back() -> void:
	backs += 1


func _on_retry() -> void:
	retries += 1


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view: TeamSelectView = VIEW_SCENE.instantiate()
	host.add_child(view)
	await _frames(4)
	view.add_to_group(&"ui_shell")
	view.side_move_requested.connect(_on_move)
	view.side_confirm_requested.connect(_on_confirm)
	view.side_cancel_requested.connect(_on_cancel)
	view.back_requested.connect(_on_back)
	view.retry_requested.connect(_on_retry)
	view.setup(FIXTURE.state_1p(), {"back_label": "leave"})
	await _frames(3)

	_check(is_equal_approx(view.design_scale_value(), 1.0), "design scale 1 at 1920")
	var home_panel: TeamPanel = view.get_node("Design/PanelWrap/Teams/HomePanel")
	var away_panel: TeamPanel = view.get_node("Design/PanelWrap/Teams/AwayPanel")
	_check(absf(home_panel.position.x - 111.5) < 0.01, "home card x 111.5")
	_check(absf(away_panel.position.x - 856.5) < 0.01, "away card x 856.5")
	_check(is_equal_approx(home_panel.size.x, 512.0), "card width 512")
	_check(is_equal_approx(home_panel.size.y, 820.0), "card height 820")
	var country_block: TeamBlock = home_panel.get("_country_block")
	var team_block: TeamBlock = home_panel.get("_team_block")
	var competition_block: TeamBlock = home_panel.get("_competition_block")
	_check(absf(country_block.size.y - 155.8) < 0.01, "country block is 19% high")
	_check(absf(team_block.size.y - 431.0) < 0.01, "club block takes the middle")
	_check(absf(competition_block.size.y - 213.2) < 0.01, "competition block is 26% high")
	_check(absf(home_panel.cue_center_y("country") - 92.0) < 0.01,
		"country cues centre on the flag")
	_check(absf(home_panel.cue_center_y("team") - 198.0) < 0.01,
		"club cues centre on the crest")
	_check(absf(home_panel.cue_center_y("competition") - 108.6) < 0.01,
		"league cues centre on the logo")
	_check(absf(home_panel.cue_tip_x("team", true) - 119.0) < 0.01,
		"left cue sits beside the art column")
	_check(absf(home_panel.cue_tip_x("team", false) - 393.0) < 0.01,
		"right cue sits beside the art column")
	_check(home_panel.cue_visible("team"), "cues show when the focused field has choices")
	var single_choice: Dictionary = FIXTURE.state_1p()
	single_choice["sides"][0]["choices"] = {"country": 1, "competition": 1, "team": 1}
	view.setup(single_choice, {"back_label": "leave"})
	await _frames(2)
	_check(not home_panel.cue_visible("team"),
		"no cues when the focused field has a single choice")
	view.setup(FIXTURE.state_1p(), {"back_label": "leave"})
	await _frames(2)
	var wide_flag := FIXTURE.state_1p()
	var flag_image := Image.create(512, 341, false, Image.FORMAT_RGBA8)
	flag_image.fill(Color.WHITE)
	wide_flag["sides"][0]["country"]["texture"] = ImageTexture.create_from_image(flag_image)
	view.setup(wide_flag, {"back_label": "leave"})
	await _frames(2)
	var flag_art: TextureRect = home_panel.get("_country_art")
	_check(is_equal_approx(flag_art.size.y, 64.0), "flags keep a fixed 64 px height")
	_check(absf(flag_art.size.x - 96.0) < 0.5, "flag width follows the aspect")
	view.setup(FIXTURE.state_1p(), {"back_label": "leave"})
	await _frames(2)
	_check(home_panel.country_name_text() == "SPAIN", "country names are uppercased")
	_check(home_panel.team_name_text() == "FC BARCELONA", "club names are uppercased")
	_check(home_panel.competition_name_text() == "LA LIGA", "league names are uppercased")
	_check(absf(home_panel.stars_value() - 3.5) < 0.01, "the rating stars reach the panel")
	_check(home_panel.crest_visible(), "a missing crest falls back to the shirt glyph")
	_check(home_panel.block_mode("team") == TeamBlock.Mode.FOCUS,
		"the default focused block is inverted")
	_check(home_panel.block_mode("country") == TeamBlock.Mode.NORMAL,
		"the other blocks stay light")
	_check(away_panel.modulate.a < 0.99, "the idle panel is dimmed")

	moves.clear()
	await _tap(KEY_UP)
	_check(view.focus_for(0) == "country", "Up moves focus to the country block")
	_check(home_panel.block_mode("country") == TeamBlock.Mode.FOCUS,
		"the country block inverts when focused")
	await _tap(KEY_UP)
	_check(view.focus_for(0) == "country", "Up clamps at the top block")
	await _tap(KEY_DOWN)
	await _tap(KEY_DOWN)
	_check(view.focus_for(0) == "competition", "Down reaches the competition block")
	await _tap(KEY_DOWN)
	_check(view.focus_for(0) == "competition", "Down clamps at the bottom block")

	moves.clear()
	await _tap(KEY_RIGHT)
	_check(moves.size() == 1, "Right emits one move request")
	if not moves.is_empty():
		_check(int(moves[0]["side"]) == 0, "the home side owns the keyboard move")
		_check(str(moves[0]["field"]) == "competition", "the focused block is requested")
		_check(int(moves[0]["delta"]) == 1, "Right requests delta +1")
		_check(str(moves[0]["input"].get("kind", "")) == "keyboard",
			"the move carries the keyboard input kind")

	view.setup(FIXTURE.state_away(), {"back_label": "leave"})
	await _frames(3)
	_check(home_panel.ready_marks_visible(), "the ready panel draws HOME and READY!")
	_check(home_panel.block_mode("team") == TeamBlock.Mode.DARK,
		"the ready panel is dark")
	_check(away_panel.modulate.a > 0.99, "the revealed away panel is not dimmed")

	view.setup(FIXTURE.state_2p(), {"back_label": "leave"})
	await _frames(3)
	moves.clear()
	await _tap(KEY_LEFT)
	_check(moves.size() == 1 and int(moves[0]["side"]) == 0,
		"the keyboard drives its own 2P panel")
	var nav := root.get_node_or_null("UiNav")
	_check(nav != null, "UiNav is available")
	if nav != null:
		moves.clear()
		nav.moved_gamepad.emit(Vector2i.LEFT, 1)
		await _frames(2)
		_check(moves.size() == 1 and int(moves[0]["side"]) == 1,
			"the gamepad drives its own 2P panel")
		_check(str(moves[0]["input"].get("kind", "")) == "gamepad",
			"the gamepad move carries the device kind")

	view.setup(FIXTURE.state_network(), {"back_label": "leave"})
	await _frames(3)
	_check(home_panel.owner_text() == "YOU  ALEX", "the local network player is marked")
	_check(away_panel.owner_text() == "MARIA", "the remote name is mirrored")
	_check(view.active_side() == 0, "the first local slot is active")
	await _tap(KEY_TAB)
	_check(view.active_side() == 1, "Tab switches between the local player's slots")
	await _tap(KEY_TAB)
	_check(view.active_side() == 0, "Tab cycles back")

	view.setup(FIXTURE.state_network_ready(), {"back_label": "leave"})
	await _frames(3)
	_check(home_panel.ready_marks_visible() and away_panel.ready_marks_visible(),
		"both network panels render the ready state")

	confirms.clear()
	view.setup(FIXTURE.state_1p(), {"back_label": "leave"})
	await _frames(2)
	await _tap(KEY_ENTER)
	_check(confirms.size() == 1 and int(confirms[0]["side"]) == 0,
		"Enter requests ready for the active panel")

	cancels.clear()
	view.setup(FIXTURE.state_away(), {"back_label": "leave"})
	await _frames(2)
	await _tap(KEY_ESCAPE)
	_check(cancels.size() == 1 and int(cancels[0]["side"]) == 1,
		"Esc requests cancel for the live panel")

	retries = 0
	view.setup(FIXTURE.state_error(), {"back_label": "leave"})
	await _frames(2)
	_check(view.status_text().contains("not found"), "the error status is shown")
	await _tap(KEY_ENTER)
	_check(retries == 1, "Enter retries the catalog in the error state")

	view.setup(FIXTURE.state_1p(), {"back_label": "leave"})
	await _frames(2)
	viewport.size = Vector2i(1280, 720)
	await _frames(4)
	_check(absf(view.design_scale_value() - 2.0 / 3.0) < 0.001,
		"1280x720 scales the 1920 canvas by 2/3")
	var panel_rect := view.panel_rect(0)
	_check(absf(panel_rect.size.x - 512.0 * 2.0 / 3.0) < 0.5,
		"the card scales to 341.3 px at 1280x720")

	view.remove_from_group(&"ui_shell")
	viewport.queue_free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: team select view")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
