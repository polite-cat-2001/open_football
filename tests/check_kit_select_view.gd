extends SceneTree
# Headless check for the shared KitSelectView: prototype geometry, focus/ready,
# kit carousel, one-kit state, 2P/network device routing, error retry and the
# 1280x720 scale.

const VIEW_SCENE := preload("res://scenes/ui/kit_select_view.tscn")
const FIXTURE := preload("res://tests/kit_select_fixture.gd")

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


func _on_move(side: int, delta: int, input: Dictionary) -> void:
	moves.append({"side": side, "delta": delta, "input": input})


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
	var view: KitSelectView = VIEW_SCENE.instantiate()
	host.add_child(view)
	await _frames(4)
	view.add_to_group(&"ui_shell")
	view.side_move_requested.connect(_on_move)
	view.side_confirm_requested.connect(_on_confirm)
	view.side_cancel_requested.connect(_on_cancel)
	view.back_requested.connect(_on_back)
	view.retry_requested.connect(_on_retry)
	view.setup(FIXTURE.state_1p(), {"back_label": "back"})
	await _frames(3)

	_check(is_equal_approx(view.design_scale_value(), 1.0), "design scale 1 at 1920")
	var home: KitPanel = view.get_node("Design/PanelWrap/Kits/HomePanel")
	var away: KitPanel = view.get_node("Design/PanelWrap/Kits/AwayPanel")
	var preview: KitPreview = view.get_node("Design/PanelWrap/Kits/Preview")
	_check(is_equal_approx(home.position.x, 0.0), "home panel starts at x 0")
	_check(absf(home.size.x - 524.6875) < 0.01, "home panel is 1.15fr")
	_check(absf(preview.position.x - 534.6875) < 0.01, "preview starts after the gap")
	_check(absf(preview.size.x - 410.625) < 0.01, "preview is 0.9fr")
	_check(absf(away.position.x - 955.3125) < 0.01, "away panel starts after the preview")
	_check(absf(away.size.x - 524.6875) < 0.01, "away panel is 1.15fr")
	_check(is_equal_approx(home.size.y, 420.0), "kit panel height is 420")
	_check(home.count_text() == "1 / 4", "home count shows the selected kit")
	_check(home.kit_name_text() == "HOME", "home kit label is HOME")
	_check(home.arrows_visible(), "arrows show with more than one kit")
	_check(home.dots_count() == 4 and home.dots_visible(), "four carousel dots")
	_check(not home.ready_visible(), "a live panel is not ready")
	_check(home.mode == KitPanel.Mode.FOCUS, "the live panel is inverted")
	_check(away.mode == KitPanel.Mode.NORMAL, "the idle panel stays light")
	_check(preview.home_name_text() == "FC BARCELONA", "preview mirrors the home team")
	_check(preview.away_name_text() == "REAL MADRID", "preview mirrors the away team")
	_check(preview.render_size() == Vector2i(640, 480), "preview uses a 640x480 3D viewport")

	moves.clear()
	await _tap(KEY_RIGHT)
	_check(moves.size() == 1, "Right emits one kit move")
	if not moves.is_empty():
		_check(int(moves[0]["side"]) == 0, "the home side owns the keyboard move")
		_check(int(moves[0]["delta"]) == 1, "Right requests delta +1")
		_check(str(moves[0]["input"].get("kind", "")) == "keyboard",
			"the move carries the keyboard input kind")
	await _tap(KEY_DOWN)
	_check(moves.size() == 1, "Down does not move the kit")

	confirms.clear()
	await _tap(KEY_ENTER)
	_check(confirms.size() == 1 and int(confirms[0]["side"]) == 0,
		"Enter requests ready for the live panel")
	cancels.clear()
	await _tap(KEY_ESCAPE)
	_check(cancels.size() == 1 and int(cancels[0]["side"]) == 0,
		"Esc requests cancel for the live panel")

	view.setup(FIXTURE.state_away(), {"back_label": "back"})
	await _frames(3)
	_check(home.ready_visible(), "a ready panel shows READY!")
	_check(home.mode == KitPanel.Mode.READY, "the ready panel is dark")
	_check(not home.arrows_visible(), "ready hides the arrows")
	_check(not home.dots_visible(), "ready hides the dots")
	_check(away.mode == KitPanel.Mode.FOCUS, "the revealed away panel is live")

	view.setup(FIXTURE.state_2p(), {"back_label": "back"})
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

	view.setup(FIXTURE.state_network(), {"back_label": "back"})
	await _frames(3)
	_check(view.active_side() == 0, "the first shared slot is active")
	await _tap(KEY_TAB)
	_check(view.active_side() == 1, "Tab switches between the shared slots")
	await _tap(KEY_TAB)
	_check(view.active_side() == 0, "Tab cycles back")

	view.setup(FIXTURE.state_single_kit(), {"back_label": "back"})
	await _frames(3)
	_check(home.count_text() == "1 / 1", "a single kit still shows 1 / 1")
	_check(not home.arrows_visible(), "a single kit hides the arrows")
	_check(not home.dots_visible(), "a single kit hides the dots")

	view.setup(FIXTURE.state_network_ready(), {"back_label": "back"})
	await _frames(3)
	_check(home.ready_visible() and away.ready_visible(), "both network panels can be ready")

	retries = 0
	view.setup(FIXTURE.state_error(), {"back_label": "back"})
	await _frames(2)
	_check(view.status_text().contains("not found"), "the error status is shown")
	await _tap(KEY_ENTER)
	_check(retries == 1, "Enter retries the kit data in the error state")

	view.setup(FIXTURE.state_1p(), {"back_label": "back"})
	await _frames(2)
	viewport.size = Vector2i(1280, 720)
	await _frames(4)
	_check(absf(view.design_scale_value() - 2.0 / 3.0) < 0.001,
		"1280x720 scales the 1920 canvas by 2/3")
	_check(absf(view.panel_rect(0).size.x - 524.6875 * 2.0 / 3.0) < 0.5,
		"the panel scales to 349.8 px at 1280x720")

	view.remove_from_group(&"ui_shell")
	viewport.queue_free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: kit select view")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
