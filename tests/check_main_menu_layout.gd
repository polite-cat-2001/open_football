extends SceneTree
# Geometry and navigation check for the ported main menu. Values are the
# prototype's computed CSS at a 1920x1080 canvas; at 1280x720 the whole design
# surface must scale uniformly by 2/3.
#
# Run:  godot --headless --path . -s res://tests/check_main_menu_layout.gd

const MAIN_MENU := "res://scenes/main_menu.tscn"
const TOLERANCE := 2.0

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) <= TOLERANCE,
		"%s (actual %.2f, expected %.2f)" % [message, actual, expected])


func _check_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	_check_close(actual.x, expected.x, message + ".x")
	_check_close(actual.y, expected.y, message + ".y")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _finish() -> void:
	print("== check_main_menu_layout: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	CareerSaveStore.root_override = "user://main_menu_layout_empty_%d" % Time.get_ticks_usec()
	await _check_geometry(Vector2i(1920, 1080), 1.0)
	await _check_geometry(Vector2i(1280, 720), 2.0 / 3.0)
	await _check_navigation()
	var transition := root.get_node_or_null("UiTransition")
	_check(transition != null and transition.instant, "UiTransition is instant in headless")
	_finish()


func _check_geometry(size: Vector2i, scale: float) -> void:
	print("-- geometry @ %dx%d" % [size.x, size.y])
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var screen: Node = load(MAIN_MENU).instantiate()
	viewport.add_child(screen)
	await _frames(8)
	await create_timer(0.4).timeout

	var design: Control = screen.get_node("Design")
	var panel_wrap: Control = screen.get_node("Design/PanelWrap")
	var tab := screen.get_node("Design/PanelWrap/TabBar") as UiTabBar
	var grid: Control = screen.get_node("Design/PanelWrap/PlayGrid")
	var quick := screen.get_node("Design/PanelWrap/PlayGrid/QuickMatchTile") as BentoTile
	var continued := screen.get_node(
		"Design/PanelWrap/PlayGrid/ContinueCareerTile") as BentoTile
	var career := screen.get_node("Design/PanelWrap/PlayGrid/CareerTile") as BentoTile
	var network := screen.get_node("Design/PanelWrap/PlayGrid/NetworkTile") as BentoTile

	_check_vec(design.scale, Vector2(scale, scale), "design scale")
	_check_vec(design.position, Vector2.ZERO, "design position")
	_check_vec(panel_wrap.position, Vector2(220.0, 157.8), "panel wrap position")
	_check_vec(panel_wrap.size, Vector2(1480.0, 764.4), "panel wrap size")
	_check_vec(tab.position, Vector2.ZERO, "tab bar position")
	_check_vec(tab.size, Vector2(1480.0, 52.0), "tab bar size")
	_check_vec(grid.position, Vector2(0.0, 62.0), "grid position")
	_check_vec(grid.size, Vector2(1480.0, 626.4), "grid size")
	_check_vec(quick.size, Vector2(735.0, 626.4), "hero size")
	_check_vec(quick.position, Vector2(-6.0, 0.0), "hero selected push")
	_check_vec(continued.position, Vector2(745.0, 0.0), "wide tile position")
	_check_vec(continued.size, Vector2(735.0, 308.2), "wide tile size")
	_check_vec(career.position, Vector2(745.0, 318.2), "small tile position")
	_check_vec(career.size, Vector2(362.5, 308.2), "small tile size")
	_check_vec(network.position, Vector2(1117.5, 318.2), "network tile position")
	_check_vec(network.size, Vector2(362.5, 308.2), "network tile size")
	_check(quick.get("_title_label").get_theme_font_size(&"font_size") == 64,
		"hero title is 64px")
	_check(continued.get("_title_label").get_theme_font_size(&"font_size") == 52,
		"wide title is 52px")
	_check(career.get("_title_label").get_theme_font_size(&"font_size") == 44,
		"small title is 44px")
	_check(tab.get_tab_button(0).get_theme_font_size(&"font_size") == 23,
		"tab label is 23px")
	_check(continued.disabled and continued.focus_mode == Control.FOCUS_NONE,
		"Continue Career is disabled and unfocusable without saves")
	_check(not career.disabled and career.focus_mode == Control.FOCUS_ALL,
		"Career is enabled and focusable")
	_check(quick.find_next_valid_focus() == career,
		"focus follows hero -> career when Continue is disabled")

	viewport.queue_free()
	await _frames(1)


func _check_navigation() -> void:
	print("-- navigation")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var screen: Node = load(MAIN_MENU).instantiate()
	viewport.add_child(screen)
	await _frames(8)

	var panel_wrap: Control = screen.get_node("Design/PanelWrap")
	var ui_nav := root.get_node("UiNav")
	var tab := screen.get_node("Design/PanelWrap/TabBar") as UiTabBar
	var breadcrumb: Control = screen.get_node("Design/PanelWrap/Breadcrumb")
	var panel: Control = screen.get_node("Design/PanelWrap/MenuPanel")
	var settings_grid: Control = screen.get_node("Design/PanelWrap/SettingsGrid")
	var gameplay := screen.get_node(
		"Design/PanelWrap/SettingsGrid/GameplayTile") as BentoTile
	var controls := screen.get_node(
		"Design/PanelWrap/SettingsGrid/ControlsTile") as BentoTile
	var audio := screen.get_node(
		"Design/PanelWrap/SettingsGrid/AudioTile") as BentoTile

	_check(tab.get_active_tab() == 0, "starts on the Play tab")
	_joy(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(4)
	_check(tab.get_active_tab() == 1, "RB switches to Settings")
	_check(settings_grid.visible, "Settings grid is shown")

	# Down from the tab bar must land on the first tile, not skip to the bottom row.
	tab.focus_tab(1)
	await _frames(2)
	ui_nav.moved.emit(Vector2i.DOWN)
	await _frames(2)
	_check(viewport.gui_get_focus_owner() == gameplay, "DOWN from tabs focuses Gameplay")
	ui_nav.moved.emit(Vector2i.UP)
	await _frames(2)
	_check(viewport.gui_get_focus_owner() == tab.get_tab_button(1), "UP from the grid focuses the active tab")
	ui_nav.moved.emit(Vector2i.DOWN)
	await _frames(2)

	audio.grab_focus()
	await _frames(2)
	ui_nav.moved.emit(Vector2i.UP)
	await _frames(2)
	_check(viewport.gui_get_focus_owner() == controls, "UP from Audio focuses Controls")
	ui_nav.moved.emit(Vector2i.UP)
	await _frames(2)
	_check(viewport.gui_get_focus_owner() == tab.get_tab_button(1),
		"UP from the top row focuses the active tab")
	gameplay.grab_focus()
	await _frames(2)

	gameplay.pressed.emit()
	await _frames(3)
	_check(breadcrumb.visible and panel.visible, "Settings tile opens the panel")
	_check(not tab.visible, "tab bar is hidden while the panel is open")

	_joy(JOY_BUTTON_B)
	await _frames(4)
	_check(not breadcrumb.visible and not panel.visible, "B closes the panel")
	_check(tab.visible and settings_grid.visible, "Settings grid returns after close")
	_check_vec(panel_wrap.position, Vector2(220.0, 157.8), "panel wrap position restored")
	_check_vec(panel_wrap.size, Vector2(1480.0, 764.4), "panel wrap size restored")

	_joy(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(4)
	_check(tab.get_active_tab() == 0, "LB switches back to Play")

	viewport.queue_free()
	await _frames(1)


func _joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)

