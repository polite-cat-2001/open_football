extends SceneTree
# Windowed-only check that the hub's System Settings fades/scales in and out
# (headless applies the end state instantly, so the test skips there).

const VIEW_SCENE := preload("res://scenes/ui/match_hub_view.tscn")
const FIXTURE := preload("res://tests/match_hub_fixture.gd")

var failures: Array[String] = []


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


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("== check_settings_animation: SKIP (headless) ==")
		quit(0)
		return
	root.size = Vector2i(1280, 720)
	var host := Control.new()
	root.add_child(host)
	host.size = Vector2(1280, 720)
	var view: MatchHubView = VIEW_SCENE.instantiate()
	host.add_child(view)
	view.setup(FIXTURE.state_settings_sides(), {"back_label": "back"})
	await _frames(4)

	view.open_settings()
	await _wait(0.05)
	_check(view.panel_wrap.modulate.a < 0.99, "the hub panel fades out")
	_check(not view.settings_screen.visible,
		"settings stay hidden until the hub panel is gone")
	await _wait(0.18)
	_check(view.settings_screen.visible,
		"settings appear after the hub panel fades out")
	_check(view.settings_screen.modulate.a < 0.99,
		"settings fade in instead of popping")
	await _wait(0.35)
	_check(view.settings_screen.modulate.a > 0.95, "settings finish their fade-in")

	# Category tile -> slider page and back animate too.
	var grid: Control = view.settings_screen.get("_grid")
	view.settings_screen.handle_confirm()
	await _wait(0.05)
	_check(grid.modulate.a < 0.99, "the category tiles fade out")
	await _wait(0.18)
	_check(view.settings_screen.mode_name() == "gameplay",
		"the slider page is built after the fade-out")
	var panel: Control = view.settings_screen.get("_panel")
	_check(panel.modulate.a < 0.99, "the slider page fades in")
	await _wait(0.35)
	_check(panel.modulate.a > 0.95, "the slider page finishes its fade-in")
	view.settings_screen.handle_cancel()
	await _wait(0.05)
	_check(panel.modulate.a < 0.99, "the slider page fades out on back")
	await _wait(0.5)
	_check(view.settings_screen.mode_name() == "menu", "back returns to the grid")

	# Side Selection overlay fades in and out too.
	view.settings_screen.handle_nav(Vector2i.DOWN)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	view.settings_screen.handle_nav(Vector2i.RIGHT)
	view.settings_screen.handle_confirm()
	await _wait(0.06)
	_check(view.side_select == null and view.settings_screen.modulate.a < 0.99,
		"the settings screen fades out first")
	await _wait(0.2)
	_check(view.side_select != null, "Side Selection opens after the fade-out")
	if view.side_select != null:
		_check(view.side_select.view.panel_wrap.modulate.a < 0.99,
			"Side Selection content fades in")
		await _wait(0.35)
		_check(view.side_select.view.panel_wrap.modulate.a > 0.95,
			"Side Selection content finishes its fade-in")
		view.side_select.call("_close")
		await _wait(0.05)
		_check(view.side_select != null
			and view.side_select.view.panel_wrap.modulate.a < 0.99,
			"Side Selection content fades out")
		await _wait(0.3)
		_check(view.side_select == null, "Side Selection closes after the fade")
		await _wait(0.3)
		_check(view.settings_screen.modulate.a > 0.9,
			"the settings screen fades back in")

	view.settings_screen.close()
	await _wait(0.05)
	_check(view.settings_screen.modulate.a < 0.99, "settings fade out on close")
	await _wait(0.5)
	_check(not view.settings_screen.visible, "settings hide after the close animation")

	print("== check_settings_animation: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)
