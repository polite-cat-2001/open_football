class_name PauseScreen
extends Control
# In-match pause, ported from the prototype's IngamePage: a scoreboard header,
# the paused side's lineup card (opens the game plan) and a 2x3 bento grid,
# plus the settings sub-page. Input is the shell's UiNav router; the direct
# handle_key/handle_joy path stays for headless tests, which run without
# autoloads.
#
# shortcut: plain dim instead of a blur pass over the live match; upgrade with
# a screen-space blur if the reference look is required.

signal resume_requested
signal forfeit_requested
signal replay_requested
signal game_plan_requested
signal side_select_requested

const SIDE_SELECT_SCENE := preload("res://scenes/ui/settings_side_select.tscn")
const HEADER_H := 156.0
const PAUSE_W := 1700.0
const LINEUP_W := 840.0
const GRID_COLS := 2
const GRID_ROWS := 3
const SCREEN_OUT := 0.15
const SCREEN_IN := 0.24
const SCREEN_SCALE := 0.96

const QUIT_PAGES := [
	{"title": "QUIT MATCH", "glyph": "exit", "chip": "", "action": "quit"},
	{"title": "RESTART MATCH", "glyph": "resume", "chip": "SOON", "action": ""},
	{"title": "CHANGE TEAMS", "glyph": "sides", "chip": "SOON", "action": ""},
]

enum Page { MENU, SETTINGS }


# In-tile pager for a multi-page slot: "<- -> • • •", all clickable. Lives in
# the bottom-right corner of the tile.
class PagePager extends Control:
	signal page_requested(target: int)
	const DOT_START := 64.0
	const DOT_STEP := 22.0

	var count := 0
	var index := 0
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func setup(pages: int, current: int, ink: Color) -> void:
		count = pages
		index = current
		color = ink
		custom_minimum_size = Vector2(DOT_START + DOT_STEP * float(maxi(pages, 1)),
			34.0)
		queue_redraw()

	func _draw() -> void:
		var half := 7.0
		var center_y := size.y * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(14.0 - half, center_y),
			Vector2(14.0 + half, center_y - half),
			Vector2(14.0 + half, center_y + half),
		]), color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(36.0 + half, center_y),
			Vector2(36.0 - half, center_y - half),
			Vector2(36.0 - half, center_y + half),
		]), color)
		for i in count:
			var radius := 6.0 if i == index else 5.0
			var dot_color := color if i == index else Color(color, 0.38)
			draw_circle(Vector2(DOT_START + DOT_STEP * float(i), center_y),
				radius, dot_color)

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var x := mouse.position.x
		if x < 26.0:
			_emit((index - 1 + count) % count)
		elif x < 48.0:
			_emit((index + 1) % count)
		else:
			var slot := int(round((x - DOT_START) / DOT_STEP))
			if slot >= 0 and slot < count:
				_emit(slot)
		accept_event()

	func _emit(target: int) -> void:
		if target != index:
			page_requested.emit(target)

var design: Control
var scrim: ColorRect
var scoreboard: PauseScoreboard
var panel_wrap: Control
var lineup_tile: BentoTile
var menu_grid: BentoGrid
var continue_tile: BentoTile
var replay_tile: BentoTile
var ratings_tile: BentoTile
var info_tile: BentoTile
var settings_tile: BentoTile
var quit_tile: BentoTile
var settings_screen: SettingsScreen
var breadcrumb: UiBreadcrumb
var hints: UiHintsBar
var modal: UiModal

var lineup: PauseLineup
var content: Control
var _pager: PagePager
var _page_ms := 0
var _gamepad := false
var _built := false
var _viewport_connected := false
var _closing := false
var _switching := false
var _pending_entries: Array = []
var _pending_kit: Dictionary = {}

var _runtime: Node = null
var _local_side_select: SettingsSideSelect = null
var _local_side_layer: CanvasLayer = null
var _local_side_opening := false
var _package: Dictionary = {}
var _team_id := 0
var _page := Page.MENU
var _quit_page := 0
var _nav: Node = null
var _menu_tiles: Array[BentoTile] = []
# Phase break reuses this screen: the scoreboard shows the period caption and
# the continue tile starts the next period (original MatchPhasePage wording).
var _break_caption := ""
var _break_continue := ""


func _ready() -> void:
	_build_once()
	_connect_viewport()


# Bind and wire lazily: GpfPauseMenu is instantiated and opened from headless
# tests inside SceneTree._init(), where add_child() can run before this node's
# own _ready. Every public entry point calls this first.
func _build_once() -> void:
	if _built:
		return
	_built = true
	theme = UiTheme.load_or_build()

	design = $Design
	scrim = $Scrim
	scoreboard = $Design/Scoreboard
	panel_wrap = $Design/PanelWrap
	lineup_tile = $Design/PanelWrap/LineupTile
	menu_grid = $Design/PanelWrap/MenuGrid
	continue_tile = $Design/PanelWrap/MenuGrid/ContinueTile
	replay_tile = $Design/PanelWrap/MenuGrid/ReplayTile
	ratings_tile = $Design/PanelWrap/MenuGrid/RatingsTile
	info_tile = $Design/PanelWrap/MenuGrid/InfoTile
	settings_tile = $Design/PanelWrap/MenuGrid/SettingsTile
	quit_tile = $Design/PanelWrap/MenuGrid/QuitTile
	settings_screen = $Design/SettingsScreen
	breadcrumb = $Design/Breadcrumb
	hints = $Design/PanelWrap/Hints

	# Full-viewport modal: lives under the screen root (not the 1920x1080 Design
	# canvas) so its scrim covers the whole window at any aspect ratio.
	modal = UiModal.new()
	modal.name = "Modal"
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.action_chosen.connect(_on_modal_action)

	# All visible menu chrome lives under one node so it fades/scales in and out
	# exactly like the shell screens (UiTransition target group).
	content = Control.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_to_group(&"ui_transition_target")
	design.add_child(content)
	design.move_child(content, 0)
	for node in [scoreboard, breadcrumb, panel_wrap]:
		node.reparent(content)

	_pager = PagePager.new()
	_pager.visible = false
	_pager.z_index = 10
	_pager.page_requested.connect(_on_pager_page)
	content.add_child(_pager)
	quit_tile.focus_entered.connect(_update_pager)
	quit_tile.focus_exited.connect(_update_pager)

	_menu_tiles = [continue_tile, replay_tile, ratings_tile, info_tile,
		settings_tile, quit_tile]

	menu_grid.columns = GRID_COLS
	menu_grid.rows = GRID_ROWS
	menu_grid.add_cell(continue_tile, 1, 1)
	menu_grid.add_cell(replay_tile, 2, 1)
	menu_grid.add_cell(ratings_tile, 1, 2)
	menu_grid.add_cell(info_tile, 2, 2)
	menu_grid.add_cell(settings_tile, 1, 3)
	menu_grid.add_cell(quit_tile, 2, 3)

	settings_screen.set_scrim(false)
	settings_screen.closed.connect(_on_settings_closed)
	settings_screen.side_select_requested.connect(_on_settings_side_select)

	lineup_tile.pressed.connect(func(): game_plan_requested.emit())
	continue_tile.pressed.connect(_request_resume)
	replay_tile.pressed.connect(func(): replay_requested.emit())
	settings_tile.pressed.connect(_show_settings)
	quit_tile.pressed.connect(func(): _activate_quit(_quit_page))

	_nav = get_node_or_null("/root/UiNav")
	# In-match input is routed directly by GpfSlice; do not also subscribe to the
	# shell router here. The local side-select overlay adds "ui_shell", which
	# would otherwise wake these handlers and double-handle Esc/Enter.

	_install_lineup()
	_apply_hints()
	_layout()
	_connect_viewport()
	_show_page(Page.MENU)
	_apply_quit_page()
	visible = false


func _connect_viewport() -> void:
	if _viewport_connected:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	viewport.size_changed.connect(_layout)
	_viewport_connected = true


func _install_lineup() -> void:
	if lineup != null:
		return
	if not lineup_tile.is_node_ready():
		lineup_tile.ready.connect(_install_lineup, CONNECT_ONE_SHOT)
		return
	lineup = PauseLineup.new()
	lineup.name = "Lineup"
	lineup_tile.add_child(lineup)
	lineup_tile.move_child(lineup, 1)
	lineup.setup(_pending_entries, _pending_kit)
	_layout()


func set_match(runtime_node: Node, package: Dictionary) -> void:
	_runtime = runtime_node
	_package = package


func set_team(team_id: int) -> void:
	_team_id = clampi(team_id, 0, 1)


# Empty caption returns the screen to the regular pause wording.
func set_break_mode(caption: String, continue_label: String) -> void:
	_break_caption = caption
	_break_continue = continue_label
	if not _built:
		return
	if is_open():
		_refresh_data()
		_apply_hints()


func tiles() -> Array:
	_build_once()
	return _menu_tiles


func open(team_id := -1) -> void:
	_build_once()
	if team_id >= 0:
		_team_id = team_id if team_id <= 1 else 0
	var was_open := visible
	_switching = false
	if modal != null:
		modal.close()
	_page = Page.MENU
	_quit_page = 0
	visible = true
	_local_side_clear()
	settings_screen.dismiss()
	_refresh_data()
	_apply_quit_page()
	_show_page(Page.MENU)
	_focus_initial()
	if not was_open:
		_animate_open()


# Resume after an in-match side-select overlay: land on the settings screen
# that opened it, not on the pause root.
func open_settings_page() -> void:
	_build_once()
	var was_open := visible
	_switching = false
	_page = Page.SETTINGS
	visible = true
	_refresh_data()
	_show_page(Page.SETTINGS)
	if not was_open:
		_animate_open()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var transition := get_node_or_null("/root/UiTransition")
	if transition == null or bool(transition.get("instant")):
		_finish_close()
		return
	transition.hide_target(content, _finish_close)


func _finish_close() -> void:
	_closing = false
	hide_now()
	resume_requested.emit()


func _animate_open() -> void:
	var transition := get_node_or_null("/root/UiTransition")
	if transition == null or bool(transition.get("instant")):
		content.modulate.a = 1.0
		content.scale = Vector2.ONE
		return
	transition.show_target(content)


func hide_now() -> void:
	visible = false
	_closing = false
	_switching = false
	_local_side_clear()
	if content != null:
		content.modulate.a = 1.0
		content.scale = Vector2.ONE
	if not _built:
		return
	if settings_screen != null:
		settings_screen.dismiss()
	if modal != null:
		modal.close()
	var viewport := get_viewport()
	if viewport != null:
		var focus := viewport.gui_get_focus_owner()
		if focus != null:
			focus.release_focus()


func is_open() -> bool:
	return visible


func is_closing() -> bool:
	return _closing


func is_confirm_open() -> bool:
	return modal != null and modal.is_open()


func is_settings_page() -> bool:
	return _page == Page.SETTINGS


func set_status(text: String) -> void:
	_build_once()
	hints.set_status(text)


func set_waiting(text: String) -> void:
	_build_once()
	continue_tile.set_note(text)


func handle_key(event: InputEventKey) -> bool:
	if not visible or not event.pressed:
		return false
	if has_local_side_select():
		return true
	_set_gamepad(false)
	if _page == Page.SETTINGS:
		# Settings owns every key while open; debug/menu hotkeys underneath
		# (Tab, F1..F3, V) must not fire through the overlay.
		settings_screen.handle_key(event)
		return true
	match event.keycode:
		KEY_UP:
			_on_moved(Vector2i.UP)
		KEY_DOWN:
			_on_moved(Vector2i.DOWN)
		KEY_LEFT:
			_on_moved(Vector2i.LEFT)
		KEY_RIGHT:
			_on_moved(Vector2i.RIGHT)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_on_confirmed()
		KEY_ESCAPE:
			_on_cancelled()
		KEY_Q:
			_page_focused(-1)
		KEY_E:
			_page_focused(1)
		_:
			return false
	return true


func _input(event: InputEvent) -> void:
	if not visible or has_local_side_select():
		return
	if not (event is InputEventJoypadMotion):
		return
	var motion := event as InputEventJoypadMotion
	if _page == Page.SETTINGS:
		settings_screen.handle_motion(motion)
		get_viewport().set_input_as_handled()
		return
	if _page != Page.MENU:
		return
	if motion.axis != JOY_AXIS_RIGHT_X or absf(motion.axis_value) <= 0.6:
		return
	_set_gamepad(true)
	var now := Time.get_ticks_msec()
	if now - _page_ms < 220:
		return
	_page_ms = now
	_page_focused(1 if motion.axis_value > 0.0 else -1)


func _set_gamepad(value: bool) -> void:
	if value == _gamepad:
		return
	_gamepad = value
	_apply_hints()


func handle_joy(event: InputEventJoypadButton) -> bool:
	if not visible or not event.pressed:
		return false
	if has_local_side_select():
		return true
	_set_gamepad(true)
	if _page == Page.SETTINGS:
		settings_screen.handle_joy(event)
		return true
	match int(event.button_index):
		JOY_BUTTON_A:
			_on_confirmed()
		JOY_BUTTON_B:
			_on_cancelled()
		JOY_BUTTON_DPAD_UP:
			_on_moved(Vector2i.UP)
		JOY_BUTTON_DPAD_DOWN:
			_on_moved(Vector2i.DOWN)
		JOY_BUTTON_DPAD_LEFT:
			_on_moved(Vector2i.LEFT)
		JOY_BUTTON_DPAD_RIGHT:
			_on_moved(Vector2i.RIGHT)
		_:
			return false
	return true


func _layout() -> void:
	if get_viewport() == null:
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var scale := minf(view.x / UiTokens.DESIGN_SIZE.x, view.y / UiTokens.DESIGN_SIZE.y)
	design.scale = Vector2(scale, scale)
	design.position = (view - UiTokens.DESIGN_SIZE * scale) * 0.5
	design.size = UiTokens.DESIGN_SIZE
	design.pivot_offset = Vector2.ZERO

	var panel_x := (UiTokens.DESIGN_SIZE.x - PAUSE_W) * 0.5
	var hints_height := hints.height()
	var total_height := HEADER_H + UiTokens.GAP + UiTokens.GRID_H \
		+ UiTokens.HINTS_GAP + hints_height
	var top := (UiTokens.DESIGN_SIZE.y - total_height) * 0.5

	scoreboard.position = Vector2(panel_x, top)
	scoreboard.size = Vector2(PAUSE_W, HEADER_H)

	panel_wrap.position = Vector2(panel_x, top + HEADER_H + UiTokens.GAP)
	panel_wrap.size = Vector2(PAUSE_W, UiTokens.GRID_H + UiTokens.HINTS_GAP
		+ hints_height)

	lineup_tile.position = Vector2.ZERO
	lineup_tile.size = Vector2(LINEUP_W, UiTokens.GRID_H)
	menu_grid.position = Vector2(LINEUP_W + UiTokens.GAP, 0.0)
	menu_grid.size = Vector2(PAUSE_W - LINEUP_W - UiTokens.GAP,
		UiTokens.GRID_H)

	breadcrumb.position = Vector2(panel_x, top + 2.0)

	hints.position = Vector2(0.0, UiTokens.GRID_H + UiTokens.HINTS_GAP)
	hints.size = Vector2(PAUSE_W, hints_height)

	lineup.position = Vector2(24.0, 104.0)
	lineup.size = Vector2(LINEUP_W - 48.0, UiTokens.GRID_H - 128.0)

	settings_screen.position = Vector2(panel_x, top)
	settings_screen.size = Vector2(PAUSE_W, total_height)

	_update_pager()


func _update_pager() -> void:
	if _pager == null or quit_tile == null:
		return
	var show := _page == Page.MENU and not (modal != null and modal.is_open()) \
		and quit_tile.page_count > 1
	_pager.visible = show
	if not show:
		return
	var ink := UiTokens.FOCUS_INK if quit_tile.has_focus() else UiTokens.INK
	_pager.setup(quit_tile.page_count, quit_tile.page_index, ink)
	_pager.size = _pager.custom_minimum_size
	var base := panel_wrap.position + menu_grid.position + quit_tile.position
	_pager.position = Vector2(base.x + quit_tile.size.x - _pager.size.x - 14.0,
		base.y + quit_tile.size.y - _pager.size.y - 10.0)


func _on_pager_page(target: int) -> void:
	quit_tile.grab_focus()
	_quit_page = clampi(target, 0, QUIT_PAGES.size() - 1)
	_apply_quit_page()


# The settings page is the shared SettingsScreen overlay; it owns its own
# breadcrumb, grid and hints, so the pause chrome is hidden behind it.
func _settings_context() -> Dictionary:
	var options: Dictionary = _package.get("options", {})
	return {
		"runtime": _runtime,
		"animate_close": true,
		"options": {
			"difficulty": float(options.get("difficulty", 0.8)),
			"duration": float(options.get("duration", 1.0)),
			"editable": false,
		},
		"side_select_available": true,
	}


func _refresh_data() -> void:
	var snapshot: Dictionary = {}
	if _runtime != null and is_instance_valid(_runtime):
		snapshot = _runtime.get_snapshot()
	var home: Dictionary = _package.get("home", {})
	var away: Dictionary = _package.get("away", {})
	scoreboard.setup(home, away, int(snapshot.get("score0", 0)),
		int(snapshot.get("score1", 0)),
		_format_clock(int(snapshot.get("match_time_ms", 0))),
		_break_caption)
	continue_tile.set_page("CONTINUE MATCH" if _break_continue.is_empty() else _break_continue,
		"resume", "")

	var team: Dictionary = home if _team_id == 0 else away
	var entries := _squad_entries(team)
	var formation := _formation_label(entries)
	var team_name := str(team.get("name", "")).to_upper()
	if team_name.is_empty():
		team_name = "HOME" if _team_id == 0 else "AWAY"
	lineup_tile.set_heading(team_name, formation)
	_pending_entries = entries
	_pending_kit = team.get("kit", {})
	if lineup == null:
		_install_lineup()
	if lineup != null:
		lineup.setup(_pending_entries, _pending_kit)


func _squad_entries(team: Dictionary) -> Array:
	# Same source as the prematch hub's plan: the package starters carry the
	# MatchLineup formation positions and the squad base_stat ratings.
	var entries: Array = []
	var formation: Array = team.get("formation", [])
	var players: Array = team.get("players", [])
	for i in mini(mini(formation.size(), players.size()), Formation.SLOT_COUNT):
		var player: Dictionary = players[i]
		var slot: Dictionary = formation[i]
		var stats: Dictionary = player.get("stats", {})
		var rating := int(round(float(player.get("base_stat", 0.0)) * 100.0))
		if rating <= 0 and not stats.is_empty():
			rating = int(round(PlayerStats.average(stats) * 100.0))
		var name := str(player.get("last_name", "")).strip_edges()
		if name.is_empty():
			name = str(player.get("first_name", "")).strip_edges()
		entries.append({
			"name": name,
			"role": str(slot.get("role", "CM")),
			"position": slot.get("position", slot.get("database_position", Vector2.ZERO)),
			"rating": rating,
		})
	if not entries.is_empty():
		return entries
	for entry in TacticalSchemes.SCHEMES[1]["entries"]:
		entries.append({
			"name": "",
			"role": str(entry.get("role", "CM")),
			"position": entry.get("position", Vector2.ZERO),
			"rating": -1,
		})
	return entries


func _formation_label(entries: Array) -> String:
	var lines := [0, 0, 0, 0]
	for entry in entries:
		var role := str(entry.get("role", "CM"))
		var line := int(TacticalSchemes.ROLE_LINES.get(role, 2))
		lines[line] += 1
	return "%d-%d-%d" % [lines[1], lines[2], lines[3]]


func _format_clock(milliseconds: int) -> String:
	var total_seconds := int(maxf(0.0, float(milliseconds)) / 1000.0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _show_page(page: int) -> void:
	_page = page
	var menu_page := page == Page.MENU
	scoreboard.visible = menu_page
	panel_wrap.visible = menu_page
	lineup_tile.visible = menu_page
	menu_grid.visible = menu_page
	breadcrumb.visible = false
	settings_screen.visible = not menu_page
	if not menu_page:
		settings_screen.open(_settings_context())
		_animate_screen(settings_screen, true)
	_update_pager()
	_apply_hints()


func _on_settings_closed() -> void:
	if _page != Page.SETTINGS:
		return
	if _animations_instant():
		settings_screen.dismiss()
		_switch_page(Page.MENU)
		return
	await _animate_screen(settings_screen, false)
	settings_screen.dismiss()
	_switch_page(Page.MENU)


func _animate_screen(target: Control, show: bool) -> void:
	if target == null:
		return
	if _animations_instant():
		target.modulate.a = 1.0
		target.scale = Vector2.ONE
		return
	target.pivot_offset = target.size * 0.5
	if show:
		target.modulate.a = 0.0
		target.scale = Vector2.ONE * SCREEN_SCALE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 1.0 if show else 0.0,
		SCREEN_IN if show else SCREEN_OUT) \
		.set_trans(Tween.TRANS_CUBIC if show else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT if show else Tween.EASE_IN)
	tween.tween_property(target, "scale",
		Vector2.ONE if show else Vector2.ONE * SCREEN_SCALE,
		SCREEN_IN if show else SCREEN_OUT) \
		.set_trans(Tween.TRANS_CUBIC if show else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT if show else Tween.EASE_IN)
	await tween.finished


func _animations_instant() -> bool:
	return DisplayServer.get_name() == "headless"


func _on_settings_side_select() -> void:
	# Network matches use the host-authoritative mirrored overlay; a local
	# match re-binds the HumanGamers through the C++ controller setup.
	if _runtime != null and is_instance_valid(_runtime) \
			and _runtime.has_method("is_net_active") and bool(_runtime.is_net_active()):
		side_select_requested.emit()
		return
	if has_local_side_select() or _local_side_layer != null:
		return
	_local_side_opening = true
	if not _animations_instant():
		await _animate_screen(settings_screen, false)
	if not visible or _local_side_layer != null:
		_local_side_opening = false
		return
	settings_screen.visible = false
	_local_side_layer = CanvasLayer.new()
	_local_side_layer.name = "LocalSideSelectLayer"
	_local_side_layer.layer = 9
	add_child(_local_side_layer)
	_local_side_select = SIDE_SELECT_SCENE.instantiate() as SettingsSideSelect
	_local_side_select.name = "LocalSideSelect"
	_local_side_select.runtime = _runtime
	_local_side_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_local_side_select.closed.connect(_close_local_side_select)
	_local_side_layer.add_child(_local_side_select)
	_local_side_opening = false


func _close_local_side_select() -> void:
	_local_side_clear()
	if not visible or settings_screen == null or not settings_screen.is_open():
		# settings_screen.visible was false while the overlay was up; restore it.
		if settings_screen != null:
			settings_screen.visible = true
	if settings_screen != null and _page == Page.SETTINGS:
		_animate_screen(settings_screen, true)


func _local_side_clear() -> void:
	if _local_side_layer != null:
		_local_side_layer.queue_free()
		_local_side_layer = null
	_local_side_select = null
	_local_side_opening = false


func has_local_side_select() -> bool:
	return _local_side_select != null or _local_side_opening


func _show_settings() -> void:
	_switch_page(Page.SETTINGS)


func _switch_page(target: int) -> void:
	if _switching:
		return
	var transition := get_node_or_null("/root/UiTransition")
	if transition == null or bool(transition.get("instant")):
		_show_page(target)
		_focus_page(target)
		return
	_switching = true
	while transition.is_busy():
		await get_tree().process_frame
	await transition.change_content(content, func(): _show_page(target))
	_switching = false
	_focus_page(target)


func _focus_page(target: int) -> void:
	if target == Page.SETTINGS:
		return
	settings_tile.grab_focus()


func _apply_quit_page() -> void:
	var page: Dictionary = QUIT_PAGES[_quit_page]
	quit_tile.set_page(String(page["title"]), String(page["glyph"]),
		String(page["chip"]))
	quit_tile.set_pages(QUIT_PAGES.size(), _quit_page, false)
	_update_pager()


func _activate_quit(page: int) -> void:
	if String(QUIT_PAGES[page]["action"]) == "quit":
		_open_confirm()


func _focus_initial() -> void:
	continue_tile.grab_focus()


func _on_moved(direction: Vector2i) -> void:
	if _switching:
		return
	if modal != null and modal.is_open():
		modal.move_focus(direction)
		return
	if _page == Page.SETTINGS:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == lineup_tile:
		if direction == Vector2i.RIGHT or direction == Vector2i.DOWN:
			continue_tile.grab_focus()
		return
	var index := _menu_tiles.find(focus)
	if index == -1:
		continue_tile.grab_focus()
		return
	if direction == Vector2i.LEFT:
		if index % GRID_COLS == 0:
			lineup_tile.grab_focus()
		else:
			_focus_menu_tile(index - 1)
		return
	if direction == Vector2i.RIGHT:
		if index % GRID_COLS == 0:
			_focus_menu_tile(index + 1)
		return
	var step := -GRID_COLS if direction == Vector2i.UP else GRID_COLS
	var next := index + step
	while next >= 0 and next < _menu_tiles.size():
		if not _menu_tiles[next].disabled:
			_menu_tiles[next].grab_focus()
			return
		next += step


func _focus_menu_tile(index: int) -> void:
	if index >= 0 and index < _menu_tiles.size() and not _menu_tiles[index].disabled:
		_menu_tiles[index].grab_focus()


func _cycle_quit_page(delta: int) -> void:
	_quit_page = posmod(_quit_page + delta, QUIT_PAGES.size())
	_apply_quit_page()
	quit_tile.grab_focus()


func _page_focused(delta: int) -> void:
	var viewport := get_viewport()
	if viewport == null or viewport.gui_get_focus_owner() != quit_tile:
		return
	_cycle_quit_page(delta)


func _on_confirmed() -> void:
	if _switching:
		return
	if modal != null and modal.is_open():
		modal.activate_focused()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == lineup_tile:
		game_plan_requested.emit()
		return
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()


func _on_cancelled() -> void:
	if _switching:
		return
	if modal != null and modal.is_open():
		modal.close()
		_update_pager()
		quit_tile.grab_focus()
		return
	if _page == Page.SETTINGS:
		_switch_page(Page.MENU)
		return
	_request_resume()


func _request_resume() -> void:
	# A network pause is a vote, not an exit: keep the menu up so voting does not
	# blink the overlay (close then reopen); the caller only edits the Continue note.
	if _runtime != null and is_instance_valid(_runtime) \
			and _runtime.has_method("is_net_active") and bool(_runtime.is_net_active()):
		resume_requested.emit()
		return
	close()


func _open_confirm() -> void:
	if modal == null:
		return
	modal.open("Are you sure you want to quit?\n\nUnsaved progress will be lost.", [
		{"id": "quit", "label": "QUIT MATCH", "key": "↵"},
		{"id": "cancel", "label": "CANCEL", "key": "ESC"},
	])
	_update_pager()


func _on_modal_action(id: String) -> void:
	modal.close()
	_update_pager()
	if id == "quit":
		forfeit_requested.emit()
	else:
		quit_tile.grab_focus()


func _on_device_changed(_gamepad: bool) -> void:
	_apply_hints()


func _apply_hints() -> void:
	var gamepad := _gamepad or (_nav != null and bool(_nav.using_gamepad()))
	if _page == Page.SETTINGS:
		hints.setup([
			{"keys": ["D-PAD"] if gamepad else ["в†ђ", "в†‘", "в†“", "в†’"], "label": "move"},
			{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
			{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
		])
		return
	hints.setup([
		{"keys": ["D-PAD"] if gamepad else ["в†ђ", "в†‘", "в†“", "в†’"], "label": "move"},
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
		{"keys": ["B"] if gamepad else ["ESC"],
			"label": "resume" if _break_continue.is_empty() else _break_continue.to_lower()},
	])
