extends SceneTree
# Headless check for the shared MatchHubView: prototype geometry, lineup rows,
# scoreboard, command cells, options overlay and the 1280x720 scale.

const VIEW_SCENE := preload("res://scenes/ui/match_hub_view.tscn")
const FIXTURE := preload("res://tests/match_hub_fixture.gd")

var failures: Array[String] = []
var starts: Array = []
var backs: Array = []
var game_plan_requests := 0
var option_changes: Array = []
var exits := 0


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


func _tap(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _on_start(input: Dictionary) -> void:
	starts.append(input)


func _on_back(input: Dictionary) -> void:
	backs.append(input)


func _on_game_plan() -> void:
	game_plan_requests += 1


func _on_option(field: String, value: float) -> void:
	option_changes.append({"field": field, "value": value})


func _on_exit() -> void:
	exits += 1


func _run() -> void:
	var view := await _make_view(Vector2i(1920, 1080))
	view.start_requested.connect(_on_start)
	view.back_requested.connect(_on_back)
	view.game_plan_requested.connect(_on_game_plan)
	view.option_changed.connect(_on_option)
	view.exit_requested.connect(_on_exit)
	view.setup(FIXTURE.state_1p(), {"back_label": "back"})
	await _frames(4)

	_check(is_equal_approx(view.design_scale_value(), 1.0), "design scale 1 at 1920")
	var wrap: Control = view.get_node("Design/PanelWrap")
	_check(absf(wrap.position.x - 220.0) < 0.01, "panel starts at x 220")
	_check(absf(wrap.position.y - 162.0) < 0.01, "panel is vertically centred")
	_check(is_equal_approx(wrap.size.x, 1480.0), "panel width 1480")
	var home_lineup: Control = view.get_node("Design/PanelWrap/HubTop/HomeLineup")
	var scoreboard: Control = view.get_node("Design/PanelWrap/HubTop/Scoreboard")
	var away_lineup: Control = view.get_node("Design/PanelWrap/HubTop/AwayLineup")
	var command: Control = view.get_node("Design/PanelWrap/Command")
	_check(is_equal_approx(home_lineup.size.x, 362.5), "home lineup column 362.5")
	_check(absf(scoreboard.position.x - 372.5) < 0.01, "scoreboard starts at 372.5")
	_check(is_equal_approx(scoreboard.size.x, 735.0), "scoreboard width 735")
	_check(absf(away_lineup.position.x - 1117.5) < 0.01, "away lineup starts at 1117.5")
	_check(is_equal_approx(command.size.y, 110.0), "command bar height 110")
	_check(absf(command.position.y - 570.0) < 0.01, "command bar below the hub top")
	_check(view.home_lineup.row_count() == 11, "home column lists 11 starters")
	_check(view.away_lineup.row_count() == 11, "away column lists 11 starters")
	_check(is_equal_approx(view.scoreboard.stars_value(0), 4.5), "home stars reach the scoreboard")
	_check(is_equal_approx(view.scoreboard.stars_value(1), 4.0), "away stars reach the scoreboard")
	var home_name_label: Label = view.scoreboard.get("_clubs")[0]["name"]
	_check(home_name_label.get_theme_font_size("font_size") == UiTokens.SIZE_HUB_TEAM,
		"hub team names use the 40px theme variation")
	var home_stat_label: Label = view.scoreboard.get("_clubs")[0]["stats"][0]["caption"]
	_check(home_stat_label.get_theme_font_size("font_size") == UiTokens.SIZE_TEAM_STAT_LABEL,
		"hub stat labels use the 12px theme variation")
	var home_stars: Rect2 = view.scoreboard.stars_rect(0)
	var home_stats: Rect2 = view.scoreboard.stats_rect(0)
	_check(absf(home_stars.size.x - home_stats.size.x) < 0.5,
		"home stats share the stars width")
	var away_stars: Rect2 = view.scoreboard.stars_rect(1)
	var away_stats: Rect2 = view.scoreboard.stats_rect(1)
	_check(absf(away_stars.size.x - away_stats.size.x) < 0.5,
		"away stats share the stars width")
	_check(view.command_cell(0).label_text() == "START MATCH", "start cell label")
	_check(view.command_cell(1).label_text() == "TEAM MANAGEMENT", "manage cell label")
	_check(view.command_cell(2).label_text() == "MATCH OPTIONS", "options cell label")
	_check(view.command_cell(3).label_text() == "EXIT", "exit cell label")
	_check(not view.command_cell(0).disabled, "start is enabled locally")

	await _tap(KEY_RIGHT)
	_check(view.command_index() == 1, "Right moves to the next command cell")
	await _tap(KEY_LEFT)
	_check(view.command_index() == 0, "Left moves back")

	await _tap(KEY_ENTER)
	_check(starts.size() == 1, "Enter on Start emits start_requested")
	_check(starts.size() == 1 and str(starts[0].get("kind", "")) == "keyboard",
		"start carries the keyboard input")

	await _tap(KEY_RIGHT)
	await _tap(KEY_RIGHT)
	_check(view.command_index() == 2, "Right reaches Match options")
	await _tap(KEY_ENTER)
	_check(view.options_overlay.visible, "Enter opens the options overlay")
	_check(view.options_overlay.slider_value("difficulty") == 0.8,
		"options show the snapshot difficulty")
	view.options_overlay.adjust(1)
	await _frames(2)
	_check(not option_changes.is_empty(), "slider change emits option_changed")
	if not option_changes.is_empty():
		_check(str(option_changes[0]["field"]) == "difficulty",
			"the changed field is difficulty")
	await _tap(KEY_ESCAPE)
	_check(not view.options_overlay.visible, "Esc closes the options overlay")

	await _tap(KEY_RIGHT)
	_check(view.command_index() == 3, "Right reaches Exit")
	await _tap(KEY_ENTER)
	_check(exits == 1, "Enter on Exit emits exit_requested")

	view.setup(FIXTURE.state_2p(), {"back_label": "back"})
	await _frames(3)
	_check(view.command_cell(0).label_text() == "START MATCH (1/2)",
		"2P shows the start vote tally")
	_check(view.status_text() == "START 1/2", "2P status carries the vote tally")

	view.setup(FIXTURE.state_network_client(), {"back_label": "back"})
	await _frames(3)
	_check(view.command_cell(0).disabled, "client Start is disabled")
	_check(view.command_cell(0).label_text() == "WAITING FOR HOST",
		"client Start says it waits for the host")
	_check(view.status_text() == "WAITING FOR HOST", "client status mirrors the wait")
	_check(not view.options_overlay.is_editable(), "client options are read-only")

	var small := await _make_view(Vector2i(1280, 720))
	small.setup(FIXTURE.state_1p())
	await _frames(3)
	_check(absf(small.design_scale_value() - (2.0 / 3.0)) < 0.001,
		"design scale 2/3 at 1280x720")
	small.queue_free()
	view.queue_free()
	await _frames(2)
	_finish()


func _make_view(size: Vector2i) -> MatchHubView:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view: MatchHubView = VIEW_SCENE.instantiate()
	host.add_child(view)
	await _frames(3)
	return view


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: match hub view")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
