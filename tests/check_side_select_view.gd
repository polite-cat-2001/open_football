extends SceneTree
# Headless check for the shared SideSelectView: prototype geometry, tones,
# cues, ready badge, the 340 ms device move, the UiNav request seam and the
# resume overlay mode.
#
# Run:  godot --headless --path . -s res://tests/check_side_select_view.gd

const VIEW_SCENE := preload("res://scenes/ui/side_select_view.tscn")
const FIXTURE := preload("res://tests/side_select_fixture.gd")

var failures: Array[String] = []
var moves: Array = []


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


func _on_move(row_id: String, delta: int, input: Dictionary) -> void:
	moves.append({"id": row_id, "delta": delta, "input": input})


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view: Node = VIEW_SCENE.instantiate()
	host.add_child(view)
	await _frames(4)
	view.add_to_group(&"ui_shell")
	view.row_move_requested.connect(_on_move)
	view.setup(FIXTURE.rows_2p(), {
		"input_mode": "devices",
		"show_names": true,
		"back_label": "leave",
	})
	await _frames(3)

	_check(is_equal_approx(view.head_height(), 56.0), "header 56")
	_check(absf(view.body_height() - 691.2) < 0.01, "body 691.2")
	_check(is_equal_approx(view.device_size(), 112.0), "device 112")
	_check(is_equal_approx(view.edge_inset(), 260.0), "edge inset 260")
	_check(is_equal_approx(view.design_scale_value(), 1.0), "design scale 1 on 1920")

	_check(is_equal_approx(view.row_device_x("keyboard:0"), 260.0), "home x 260")
	_check(absf(view.row_device_x("gamepad:1") - 684.0) < 0.5, "centre x 684")
	_check(view.row_tone("keyboard:0") == UiTokens.SIDE_TONES[0], "tone 0 by index")
	_check(view.row_tone("gamepad:1") == UiTokens.SIDE_TONES[1], "tone 1 by index")
	_check(not view.row_cue_visible("keyboard:0", true)
		and view.row_cue_visible("keyboard:0", false), "home cue is right only")
	_check(view.row_cue_visible("gamepad:1", true)
		and view.row_cue_visible("gamepad:1", false), "centre has both cues")
	_check(view.row_ready_x("keyboard:0") < 0.0,
		"home ready badge sits on the arrow-free left side")
	_check(absf(view.row_ready_y("keyboard:0") - 44.0) < 0.5,
		"home ready badge is vertically centred like the arrow")
	_check(absf(view.row_ready_x("gamepad:1") - 44.0) < 0.5,
		"centre ready badge sits above the icon")
	_check(absf(view.row_ready_y("gamepad:1") + 8.0) < 0.5,
		"centre ready badge stays at the top")
	var keyboard_rect: Rect2 = view.row_device_rect("keyboard:0")
	var pad_rect: Rect2 = view.row_device_rect("gamepad:1")
	_check(keyboard_rect.position.y < pad_rect.position.y, "devices stack top-down")
	_check(pad_rect.position.y - keyboard_rect.position.y <= 170.0,
		"devices stack compactly")

	moves.clear()
	await _tap(KEY_RIGHT)
	await _frames(2)
	_check(moves.size() == 1, "UiNav Right emits one move request")
	if not moves.is_empty():
		_check(str(moves[0]["id"]) == "keyboard:0", "the keyboard row owns the move")
		_check(int(moves[0]["delta"]) == 1, "Right requests delta +1")
		_check(str(moves[0]["input"].get("kind", "")) == "keyboard",
			"the move carries the keyboard input kind")

	var nav := root.get_node_or_null("UiNav")
	_check(nav != null, "UiNav is available")
	if nav != null:
		var motion := InputEventJoypadMotion.new()
		motion.device = 1
		motion.axis = JOY_AXIS_LEFT_X
		motion.axis_value = 1.0
		Input.parse_input_event(motion)
		await _frames(2)
		moves.clear()
		nav.moved_gamepad.emit(Vector2i.RIGHT, 1)
		await _frames(2)
		_check(moves.size() == 1 and str(moves[0]["id"]) == "gamepad:1",
			"a gamepad move is routed to its own row")
		_check(str(moves[0]["input"].get("kind", "")) == "gamepad",
			"the gamepad move carries the gamepad kind")

	var rows: Array = FIXTURE.rows_2p()
	rows[0]["side"] = 0
	view.apply_rows(rows)
	await create_timer(0.4).timeout
	_check(absf(view.row_device_x("keyboard:0") - 684.0) < 0.5,
		"the device tweens to the centre")

	rows[0]["ready"] = true
	view.apply_rows(rows)
	await _frames(2)
	_check(view.row_ready_visible("keyboard:0"), "ready badge appears on the device")
	_check(absf(view.row_ready_x("keyboard:0") - 44.0) < 0.5,
		"centre ready badge moves above the icon")
	_check(absf(view.row_ready_y("keyboard:0") + 8.0) < 0.5,
		"centre ready badge uses the top position")
	_check(not view.row_ready_visible("gamepad:1"), "other rows stay unmarked")

	rows[1]["side"] = 1
	rows[1]["ready"] = true
	view.apply_rows(rows)
	await _frames(2)
	_check(view.row_ready_x("gamepad:1") > view.device_size() * 0.5,
		"away ready badge sits on the arrow-free right side")
	_check(absf(view.row_ready_y("gamepad:1") - 44.0) < 0.5,
		"away ready badge is vertically centred like the arrow")
	_check(view.row_cue_visible("gamepad:1", true)
		and not view.row_cue_visible("gamepad:1", false), "away cue is left only")

	view.set_status("Choose a side first.", true)
	_check(view.status_text().contains("Choose a side"), "status text is visible")
	var status := view.get_node("Design/PanelWrap/Hints/Status") as Label
	_check(status.theme_type_variation == &"SideStatusError", "error style is applied")

	view.set_overlay_mode(true)
	_check(not (view.get_node("Stage/Photo") as Control).visible,
		"resume overlay hides the stadium")
	_check((view.get_node("Stage/Overlay") as Control).visible,
		"resume overlay keeps a dim layer")

	view.setup(FIXTURE.rows_network(), {
		"input_mode": "local_player",
		"show_names": true,
		"back_label": "back",
		"overlay": true,
		"status": "Player disconnected",
	})
	await _frames(3)
	_check(view.row_name_text("player:0") == "YOU  ALEX",
		"the local network row is marked")
	_check(view.row_name_text("player:1") == "MARIA", "remote names stay clean")
	_check(view.status_text() == "Player disconnected", "network status is mirrored")

	viewport.size = Vector2i(1280, 720)
	await _frames(4)
	_check(absf(view.design_scale_value() - 2.0 / 3.0) < 0.001,
		"1280x720 scales the 1920 canvas by 2/3")
	var head_rect := (view.get_node("Design/PanelWrap/Head") as Control).get_global_rect()
	_check(absf(head_rect.size.y - 56.0 * 2.0 / 3.0) < 0.5,
		"the header scales to 37.3 px at 1280x720")
	var body_rect := (view.get_node("Design/PanelWrap/Body") as Control).get_global_rect()
	_check(absf(body_rect.size.y - 691.2 * 2.0 / 3.0) < 0.5,
		"the body scales to 460.8 px at 1280x720")

	view.remove_from_group(&"ui_shell")
	viewport.queue_free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: side select view")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)

