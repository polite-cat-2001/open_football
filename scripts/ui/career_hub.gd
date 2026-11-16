extends UiScreen
# Career hub: the prototype's tabbed shell (Centre / Squad / Transfers /
# Scouting) with the Centre dashboard, save and exit. Only the Centre tab is
# built; the other tabs show the shared "in progress" panel until their
# tickets land. Input goes through UiNav; the active tab is saved in the career.

const START_SCENE := "res://scenes/career_start.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ADVANCE_TICK := 1.0
const FocusGrid := preload("res://scripts/ui/ui_focus_grid.gd")

enum Zone { TABS, GRID }

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var body: Control = $Design/PanelWrap/Body
@onready var tab_bar: UiTabBar = $Design/PanelWrap/Body/TabBar
@onready var breadcrumb: UiBreadcrumb = $Design/PanelWrap/Body/Breadcrumb
@onready var grid: BentoGrid = $Design/PanelWrap/Body/Grid
@onready var next_tile: CareerHubNextTile = $Design/PanelWrap/Body/Grid/NextTile
@onready var play_tile: BentoTile = $Design/PanelWrap/Body/Grid/PlayTile
@onready var simulation_tile: BentoTile = $Design/PanelWrap/Body/Grid/SimulationTile
@onready var table_tile: CareerHubTableTile = $Design/PanelWrap/Body/Grid/TableTile
@onready var transfer_tile: BentoTile = $Design/PanelWrap/Body/Grid/TransferTile
@onready var news_tile: BentoTile = $Design/PanelWrap/Body/Grid/NewsTile
@onready var training_tile: BentoTile = $Design/PanelWrap/Body/Grid/TrainingTile
@onready var placeholder: UiMenuPanel = $Design/PanelWrap/Body/Placeholder
@onready var squad_view: CareerSquadView = $Design/PanelWrap/Body/SquadView
@onready var transfers_view: CareerTransfersView = $Design/PanelWrap/Body/TransfersView
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
@onready var overlay: CareerHubOverlay = $Design/Overlay
@onready var _match_overlay: CareerMatchOverlay = $Design/MatchOverlay
@onready var plan_host: Control = $Design/PlanHost

var _plan: GpfGamePlan
var _plan_open := false
var _plan_transition := false
var _squad_screen: Control
var _squad_screen_kind := ""

const SQUAD_SCREENS := {
	"renew": "res://scripts/ui/career_negotiation.gd",
	"number": "res://scripts/ui/career_shirt_number.gd",
	"release": "res://scripts/ui/career_release.gd",
}
const SQUAD_CRUMBS := {
	"renew": "CONTRACT TALKS",
	"number": "SHIRT NUMBER",
	"release": "RELEASE PLAYER",
}

var _snapshot: Dictionary = {}
var _career: Career
var _transfers_entry := "hub"
var _tabs_shown := true
var _path_shown := false
var _tabs_tween: Tween
var _zone := Zone.GRID
var _tab := 0
var _busy := false
var _advancing := false
var _advance_token := 0
var _sim_start := ""
var _sim_date := ""
var _match_day := false
var _match_phase := ""
var _match_setup: Dictionary = {}
var _match_result: Dictionary = {}
var _matchday: Dictionary = {}
var _match_minute := 0
var _match_token := 0
var _match_confirm_guard_until := 0


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	_career = CareerSession.career
	if _career == null or CareerSession.catalog == null:
		call_deferred("_leave", START_SCENE)
		return
	# Compiling the career screens is the slow part of the first entry; do it
	# while the dashboard is up instead of on the next click.
	CareerWarmup.start(self, CareerWarmup.TRANSFERS)
	CareerScouting.forget_own_players(_career)
	# Reading the 120k-row players table takes seconds; do it on a worker thread
	# while the user reads the dashboard instead of on the first search.
	CareerSession.catalog.warm_search_rows()
	# Same for the teams table behind the search screen's club picker.
	CareerSession.catalog.warm_clubs()
	var loaded_tick := CareerAdvance.tick(_career, CareerSession.catalog)
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	if _snapshot.is_empty():
		call_deferred("_leave", START_SCENE)
		return
	if bool(loaded_tick.get("changed", false)):
		_save()
		_show_tick_event(loaded_tick.get("events", []))

	overlay.z_index = 10
	_match_overlay.z_index = 10
	plan_host.z_index = 10
	hints.z_index = 20
	hints.visible = true
	hints.set_status_visible(false)
	tab_bar.setup(CareerHubModel.TABS)
	tab_bar.tab_selected.connect(_on_tab_selected)
	tab_bar.bar_focused.connect(_on_bar_focused)
	grid.add_cell(next_tile, 1, 1, 2, 1)
	grid.add_cell(play_tile, 1, 1)
	grid.add_cell(simulation_tile, 2, 1)
	grid.add_cell(table_tile, 3, 1, 2, 1)
	grid.add_cell(transfer_tile, 1, 2)
	grid.add_cell(news_tile, 2, 2, 2, 1)
	grid.add_cell(training_tile, 4, 2)
	for tile in [news_tile, training_tile]:
		tile.focus_mode = Control.FOCUS_NONE
	transfer_tile.pressed.connect(_open_transfers_tab)
	transfer_tile.focus_entered.connect(_on_tile_focused)
	squad_view.setup(_career, CareerSession.catalog)
	squad_view.changed.connect(_on_squad_changed)
	squad_view.state_changed.connect(_on_squad_state_changed)
	squad_view.pointer_focused.connect(_on_squad_pointer_focused)
	squad_view.view_changed.connect(_on_squad_view_changed)
	squad_view.plan_requested.connect(_open_plan_overlay)
	squad_view.player_action_requested.connect(_open_squad_screen)
	transfers_view.changed.connect(_on_transfers_changed)
	transfers_view.view_changed.connect(_on_transfers_view_changed)
	transfers_view.view_opening.connect(_on_transfers_opening)
	transfers_view.exit_requested.connect(_on_transfers_exit)
	transfers_view.tab_requested.connect(_on_transfers_tab)
	transfers_view.edge_requested.connect(_on_grid_edge)
	_plan = GpfGamePlan.new()
	_plan.name = "GamePlan"
	_plan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plan.close_requested.connect(_close_plan_overlay)
	plan_host.add_child(_plan)
	next_tile.pressed.connect(_on_next_pressed)
	play_tile.pressed.connect(_on_play_pressed)
	simulation_tile.pressed.connect(_on_simulation_pressed)
	table_tile.pressed.connect(_open_overlay)
	next_tile.focus_entered.connect(_on_tile_focused)
	play_tile.focus_entered.connect(_on_tile_focused)
	simulation_tile.focus_entered.connect(_on_tile_focused)
	table_tile.focus_entered.connect(_on_tile_focused)
	_apply_snapshot()

	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_on_nav_cancelled)
	UiNav.tab_previous.connect(_on_nav_tab_previous)
	UiNav.tab_next.connect(_on_nav_tab_next)
	UiNav.device_changed.connect(_on_device_changed)

	_tab = maxi(0, CareerHubModel.TAB_IDS.find(_career.hub_tab))
	tab_bar.select_tab(_tab, false)
	_apply_tab()
	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_focus_initial")
	call_deferred("_reclaim_focus")


# The scene transition swaps scenes under us, so the grab scheduled from _ready
# can land before the old screen releases the viewport; take it again once the
# viewport has no owner, but never steal focus from the player.
func _reclaim_focus() -> void:
	for step in 8:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if get_viewport().gui_get_focus_owner() != null:
			return
		_focus_initial()


func _apply_snapshot() -> void:
	var model := CareerHubModel.next_tile(_snapshot)
	next_tile.setup(model)
	var was_match_day := _match_day
	_match_day = bool(model.get("match_day", false))
	next_tile.visible = not _match_day
	play_tile.visible = _match_day
	simulation_tile.visible = _match_day
	if _match_day:
		_setup_match_actions(model)
		# The calendar tile hides itself as the match day arrives, so hand focus
		# to PLAY instead of leaving it on a hidden control.
		if not was_match_day and not _match_overlay.is_open():
			call_deferred("_focus_matchday_tile")
	table_tile.setup(CareerHubModel.table_tile(_snapshot))
	var unread := CareerIncomingOffers.unread_count(_career)
	transfer_tile.set_copy("TRANSFER CENTRE", "Offers, talks and signings.", "")
	transfer_tile.set_badge("" if unread == 0 else "%d NEW" % unread)


func _focus_matchday_tile() -> void:
	if not _match_day or _tab != 0 or _busy \
			or not is_inside_tree() or _match_overlay.is_open():
		return
	play_tile.grab_focus()
	_zone = Zone.GRID


func _setup_match_actions(model: Dictionary) -> void:
	var next = _snapshot.get("season", {}).get("next")
	if not (next is Dictionary):
		return
	var opponent: Dictionary = next.get("opponent", {})
	var meta := "ROUND %d В· %s В· %s" % [
		int(next.get("round", 0)),
		CareerHubModel.short_date(str(next.get("date", ""))),
		"HOME" if bool(next.get("home", true)) else "AWAY",
	]
	play_tile.set_copy("PLAY", "vs %s" % str(opponent.get("name", "")), meta, "MATCH")
	simulation_tile.set_copy("SIMULATION", "Watch the match unfold", meta, "MATCH")
	play_tile.set_art(_logo(str(model.get("opponent_logo", ""))))
	simulation_tile.set_art(null)


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	var hints_height := hints.height()
	var total := UiTokens.TAB_H + UiTokens.GAP + UiTokens.GRID_H \
		+ UiTokens.HINTS_GAP + hints_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)
	var content_top := UiTokens.TAB_H + UiTokens.GAP
	body.position = Vector2.ZERO
	body.size = Vector2(UiTokens.PANEL_W, content_top + UiTokens.GRID_H)
	if _squad_screen != null:
		_squad_screen.position = Vector2(0.0, content_top)
		_squad_screen.size = Vector2(UiTokens.PANEL_W, body.size.y - content_top)
	tab_bar.position = Vector2.ZERO
	tab_bar.fit_width()
	grid.position = Vector2(0.0, content_top)
	grid.size = Vector2(UiTokens.PANEL_W, UiTokens.GRID_H)
	placeholder.position = grid.position
	placeholder.size = grid.size
	_apply_tab_layout()
	hints.position = Vector2(0.0, content_top + UiTokens.GRID_H + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)
	# The overlay is a full shell replacement: it covers the tabs too, like the
	# prototype hides the hub while a tournament/match screen is open.
	overlay.layout_overlay(Rect2(panel_wrap.position, body.size))
	_match_overlay.layout_overlay(Rect2(panel_wrap.position, body.size))


func _focus_initial() -> void:
	_focus_tabs()


func _apply_tab() -> void:
	var centre := _tab == 0
	var squad_tab := _tab == 1
	var transfers_tab := _tab == 2
	grid.visible = centre
	squad_view.visible = squad_tab
	transfers_view.visible = transfers_tab
	placeholder.visible = not (centre or squad_tab or transfers_tab)
	if centre:
		squad_view.close()
		transfers_view.close()
	elif squad_tab:
		squad_view.open()
		transfers_view.close()
	elif transfers_tab:
		squad_view.close()
		transfers_view.open(_career, CareerSession.catalog, _transfers_entry)
	else:
		# ACADEMY / OFFICE: placeholders until their tickets land.
		squad_view.close()
		transfers_view.close()
		placeholder.setup("", [])
	_apply_tab_layout()
	_update_hints()


# The plan/centre/details screens and the transfers subviews replace the whole
# body: the main tab strip hides and the view grows over the space the tabs used.
func _apply_tab_layout() -> void:
	# Only the transfers subviews (player search first) crossfade the row for
	# now; the rest of the hub still swaps it instantly.
	var animate := _tab == 2 and transfers_view.visible
	if _squad_screen != null:
		_set_tabs_row(false, true, false)
		return
	var view: Control = null
	if _tab == 1 and squad_view.visible:
		view = squad_view
	elif _tab == 2 and transfers_view.visible:
		view = transfers_view
	if view == null:
		_set_tabs_row(true, false, animate)
		return
	var overlay := transfers_view.is_overlay() if view == transfers_view \
		else squad_view.current_view() != "overview"
	# The squad centre has its own tabs and no breadcrumb, so the row can be
	# empty; the transfers subviews swap the strip for the path.
	if view == transfers_view:
		_set_tabs_row(not overlay, overlay, animate)
	else:
		_set_tabs_row(not overlay, false, animate)
	if view == transfers_view and overlay:
		breadcrumb.set_items(transfers_view.breadcrumb())
		breadcrumb.position = Vector2.ZERO
		view.position = Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP)
		view.size = Vector2(UiTokens.PANEL_W, body.size.y - UiTokens.TAB_H - UiTokens.GAP)
		return
	if overlay:
		view.position = Vector2.ZERO
		view.size = Vector2(UiTokens.PANEL_W, body.size.y)
	else:
		view.position = grid.position
		view.size = grid.size


# Swapping the tab strip for the path (and back) crossfades, so entering and
# leaving a subview does not pop. `_tabs_shown`/`_path_shown` are the logical
# state; the visibility flags lag by the tween.
func _set_tabs_row(show_tabs: bool, show_path: bool, animate := true) -> void:
	if _tabs_shown == show_tabs and _path_shown == show_path:
		return
	var leaving: Control = null
	if _tabs_shown and not show_tabs:
		leaving = tab_bar
	elif _path_shown and not show_path:
		leaving = breadcrumb
	var arriving: Control = null
	if show_tabs and not _tabs_shown:
		arriving = tab_bar
	elif show_path and not _path_shown:
		arriving = breadcrumb
	_tabs_shown = show_tabs
	_path_shown = show_path
	if _tabs_tween != null and _tabs_tween.is_valid():
		_tabs_tween.kill()
	if not animate or UiTransition.instant or not is_inside_tree() \
			or (leaving == null and arriving == null):
		tab_bar.visible = show_tabs
		breadcrumb.visible = show_path
		tab_bar.modulate.a = 1.0
		breadcrumb.modulate.a = 1.0
		return
	if arriving != null:
		arriving.visible = true
		arriving.modulate.a = 0.0
	_tabs_tween = create_tween().set_parallel(true)
	if leaving != null:
		# Same clock as the view swap (CareerTransfersView._show): the old row
		# fades out while the old screen does, the new row fades in together
		# with the new screen, so nothing arrives early or late.
		_tabs_tween.tween_property(leaving, "modulate:a", 0.0, UiTransition.OUT_TIME)
	if arriving != null:
		_tabs_tween.tween_property(arriving, "modulate:a", 1.0, UiTransition.IN_TIME) \
			.set_delay(UiTransition.OUT_TIME)
	_tabs_tween.chain().tween_callback(func() -> void:
		if leaving != null:
			leaving.visible = false
			leaving.modulate.a = 1.0)


func _on_squad_view_changed(direction: int) -> void:
	_apply_tab_layout()
	_slide_in(squad_view, direction)
	_update_hints()


func _on_tab_selected(index: int) -> void:
	_set_section(index, signi(index - _tab))


func _switch_section(delta: int, suppress_landing := false) -> void:
	var target := posmod(_tab + delta, CareerHubModel.TABS.size())
	if suppress_landing and target == 2:
		# The landing reads UiNav itself: drop the same move/tab event that
		# brings it on screen, or it also walks/activates a card.
		transfers_view.suppress_event()
	_set_section(target, delta)


func _set_section(index: int, direction: int) -> void:
	_tab = index
	if _career != null:
		_career.hub_tab = CareerHubModel.TAB_IDS[index]
	tab_bar.select_tab(index, false)
	_apply_tab()
	# Keep the strip focused only if it already had the focus; coming from a
	# tile lands on the new page's top-left tile.
	if _zone == Zone.TABS:
		_focus_tabs()
	else:
		_focus_first_tile()
	_play_section_entrance(direction)


func _play_section_entrance(direction: int) -> void:
	if direction == 0 or not is_inside_tree():
		return
	if _tab == 0:
		grid.play_entrance(direction)
	elif _tab == 1:
		_slide_in(squad_view, direction)
	elif _tab == 2:
		_slide_in(transfers_view, direction)
	else:
		_slide_in(placeholder, direction)


func _slide_in(node: Control, direction: int) -> void:
	if direction == 0 or UiTransition.instant or not node.visible:
		return
	var target := node.position
	node.position = target + Vector2(64.0 * float(direction), 0.0)
	node.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "position", target, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.16)


# A push at the edge of a section's own card grid: Up leaves for the main tab
# strip, Left/Right page through the sections, like the Centre dashboard.
func _on_grid_edge(direction: Vector2i) -> void:
	if _busy or _advancing:
		return
	if direction == Vector2i.UP:
		_focus_active_tab()
	elif direction == Vector2i.LEFT:
		_switch_section(-1)
	elif direction == Vector2i.RIGHT:
		_switch_section(1)


func _on_bar_focused() -> void:
	_zone = Zone.TABS
	if _tab == 1 and squad_view.visible:
		squad_view.blur()
	_update_hints()

func _on_tile_focused() -> void:
	_zone = Zone.GRID


func _focus_first_tile() -> void:
	if _tab == 0:
		if _match_day:
			play_tile.grab_focus()
		else:
			next_tile.grab_focus()
		_zone = Zone.GRID
	elif _tab == 1:
		squad_view.focus_initial()
		# The squad overview is custom-drawn and never takes viewport focus, so
		# leaving the strip for it would keep the tab button focused and the
		# strip would stay in its focused look. Drop focus like Centre does.
		get_viewport().gui_release_focus()
		_zone = Zone.GRID
	elif _tab == 2:
		transfers_view.set_shell_focused(false)
		transfers_view.focus_initial()
		_zone = Zone.GRID
	else:
		tab_bar.focus_tab(_tab)
		_zone = Zone.TABS
	_update_hints()


func _focus_active_tab() -> void:
	_focus_tabs()


func _focus_tabs() -> void:
	if _tab == 1 and squad_view.visible:
		squad_view.blur()
	transfers_view.set_shell_focused(true)
	tab_bar.focus_tab(_tab)
	_zone = Zone.TABS
	_update_hints()


func _open_transfers_tab() -> void:
	# The tile's badge counts unread offers, so it lands straight on them.
	_transfers_entry = "centre" \
		if CareerIncomingOffers.unread_count(_career) > 0 else "hub"
	_set_section(2, 1)
	_transfers_entry = "hub"


# The shared Game Plan screen (same as the prematch hub / match pause) opened
# full-screen over the hub. It edits MatchLineup models; the career reads them
# back when the plan closes.
# Ticket 06 screens (contract talks, shirt number, release) replace the body
# under a breadcrumb, like the squad plan does.
func _open_squad_screen(action: String, player_id: String) -> void:
	if _squad_screen != null or _plan_open or _busy:
		return
	var path := str(SQUAD_SCREENS.get(action, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var script := load(path) as Script
	if script == null:
		return
	var screen := script.new() as Control
	if screen == null:
		return
	screen.name = "SquadAction"
	screen.position = Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP)
	screen.size = Vector2(UiTokens.PANEL_W,
		body.size.y - UiTokens.TAB_H - UiTokens.GAP)
	screen.visible = false
	body.add_child(screen)
	_squad_screen = screen
	_squad_screen_kind = action
	squad_view.visible = false
	if screen.has_signal("closed"):
		screen.connect("closed", _close_squad_screen)
	if screen.has_signal("changed"):
		screen.connect("changed", _on_squad_screen_changed)
	screen.call("open", _career, CareerSession.catalog, {"player_id": player_id})
	screen.visible = true
	breadcrumb.set_items(["CAREER", "SQUAD",
		str(SQUAD_CRUMBS.get(action, action.to_upper()))])
	breadcrumb.position = Vector2.ZERO
	_set_tabs_row(false, true, false)
	await _fade_in(screen)
	if screen.has_method("focus_initial"):
		screen.focus_initial()
	_update_hints()


func _close_squad_screen() -> void:
	if _squad_screen == null:
		return
	var screen := _squad_screen
	_squad_screen = null
	_squad_screen_kind = ""
	if screen.has_method("close"):
		screen.close()
	await _fade_out(screen)
	screen.queue_free()
	squad_view.visible = _tab == 1
	_apply_tab_layout()
	_update_hints()
	squad_view.focus_initial()


func _on_squad_screen_changed() -> void:
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	_apply_snapshot()
	squad_view.refresh()
	_save()
	_update_hints()


func _open_plan_overlay() -> void:
	if _plan_open or _plan_transition or _busy or _advancing:
		return
	var opponent_id := 0
	var next = _snapshot.get("season", {}).get("next")
	if next is Dictionary:
		opponent_id = int((next.get("opponent", {}) as Dictionary).get("id", 0))
	var models := CareerPlan.build(CareerSession.catalog, _career,
		int(_career.club_id), opponent_id)
	ShellState.home_team = CareerSession.catalog.career_club(int(_career.club_id))
	ShellState.away_team = CareerSession.catalog.career_club(opponent_id) \
		if opponent_id > 0 else {}
	_plan.formation_source = CareerPlan.formation_source()
	_plan.formation_id = _career.formation
	_plan.setup_prematch(models["home"], models["away"], [0])
	_plan_open = true
	_plan_transition = true
	panel_wrap.visible = false
	plan_host.visible = true
	plan_host.modulate.a = 0.0
	plan_host.scale = Vector2.ONE * UiTransition.SCALE_FROM
	plan_host.pivot_offset = plan_host.size * 0.5
	_plan.open_plan()
	hints.visible = false
	_set_tabs_row(false, false, false)
	await _fade_in(plan_host)
	_plan_transition = false


func _close_plan_overlay() -> void:
	if not _plan_open or _plan_transition:
		return
	_plan_transition = true
	var model: MatchLineup = _plan.lineup_model(0)
	if model != null:
		CareerPlan.apply(_career, model, _plan.formation_id)
	await _fade_out(plan_host)
	_plan.close_plan()
	plan_host.visible = false
	plan_host.modulate.a = 1.0
	plan_host.scale = Vector2.ONE
	_plan_open = false
	_plan_transition = false
	hints.visible = true
	panel_wrap.visible = true
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	_apply_snapshot()
	squad_view.refresh()
	_save()
	_apply_tab_layout()
	_update_hints()
	_focus_first_tile()


func _plan_action(action: String, device := -1) -> bool:
	if _plan == null or _plan_transition:
		return true
	return _plan.handle_ui_action(action, device)


func _direction_action(direction: Vector2i) -> String:
	if direction == Vector2i.LEFT:
		return "left"
	if direction == Vector2i.RIGHT:
		return "right"
	if direction == Vector2i.UP:
		return "up"
	if direction == Vector2i.DOWN:
		return "down"
	return ""


func _on_nav_moved(direction: Vector2i) -> void:
	if _plan_open:
		_plan_action(_direction_action(direction))
		return
	if _match_overlay.is_open():
		if _match_phase == "matchday_table" \
				and (direction == Vector2i.UP or direction == Vector2i.DOWN):
			_match_overlay.scroll_step(-1 if direction == Vector2i.UP else 1)
		return
	if _busy or _advancing:
		return
	if _squad_screen != null:
		_update_hints()
		return
	if overlay.is_open():
		if direction == Vector2i.UP or direction == Vector2i.DOWN:
			overlay.scroll_step(-1 if direction == Vector2i.UP else 1)
		return
	# The strip comes first: a custom-drawn section (squad, transfers) also
	# reads UiNav, so its move handler would eat Left/Right while the tabs have
	# focus and the sections would never page.
	if _zone == Zone.TABS:
		if direction == Vector2i.LEFT:
			_switch_section(-1)
		elif direction == Vector2i.RIGHT:
			_switch_section(1)
		elif direction == Vector2i.DOWN:
			_focus_first_tile()
		return
	if _tab == 0:
		# The Centre dashboard follows the tiles' real positions: the next-match
		# tile spans the top-left, the table the top-right, Transfer Centre sits
		# under the next-match tile. Edge pushes page sections / reach the tabs.
		var neighbour := _focus_grid_neighbour(direction)
		if neighbour != null:
			neighbour.grab_focus()
			return
		if direction == Vector2i.UP:
			_focus_active_tab()
		elif direction == Vector2i.LEFT:
			_switch_section(-1, true)
		elif direction == Vector2i.RIGHT:
			_switch_section(1, true)
		return
	if _tab == 1 and squad_view.visible:
		if squad_view.handle_moved(direction):
			return
		if squad_view.current_view() != "overview":
			return
		if direction == Vector2i.UP:
			_focus_active_tab()
		elif direction == Vector2i.LEFT:
			_switch_section(-1, true)
		elif direction == Vector2i.RIGHT:
			_switch_section(1, true)
		return
	if _tab == 2 and transfers_view.visible:
		# The transfers screens read UiNav themselves; the hub only keeps the
		# hint bar in sync with their internal mode.
		_update_hints()
		return


# Nearest focusable tile in the pushed direction, measured on the real rects:
# the dashboard's cells have different spans, so a hardcoded row/column map
# drifts away from what the player sees.
func _focus_grid_neighbour(direction: Vector2i) -> Control:
	var current := get_viewport().gui_get_focus_owner() as Control
	if current == null or not grid.is_ancestor_of(current):
		return null
	var tiles: Array[Control] = []
	var rects: Array[Rect2] = []
	for child in grid.get_children():
		var tile := child as Control
		if tile == null or not tile.is_visible_in_tree() \
				or tile.focus_mode == Control.FOCUS_NONE:
			continue
		tiles.append(tile)
		rects.append(tile.get_global_rect())
	# The focused tile is pushed/scaled by a few px; the tolerance keeps a tall
	# top-row tile recognised as the top row.
	var index := FocusGrid.neighbour(rects, current.get_global_rect(), direction,
		UiTokens.SELECTED_PUSH * 2.0)
	return tiles[index] if index >= 0 else null


func _on_nav_confirmed() -> void:
	if _plan_open:
		_plan_action("confirm")
		return
	if _match_overlay.is_open():
		if Time.get_ticks_msec() < _match_confirm_guard_until:
			return
		_match_action()
		return
	if _advancing:
		_stop_advance()
		return
	if _busy or overlay.is_open():
		return
	if _squad_screen != null:
		_update_hints()
		return
	if _zone == Zone.TABS:
		_focus_first_tile()
		return
	if _tab == 1 and squad_view.visible:
		squad_view.handle_confirmed()
		return
	if _tab == 2 and transfers_view.visible:
		_update_hints()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()


func _on_nav_cancelled() -> void:
	if _plan_open:
		if not _plan_action("cancel"):
			_close_plan_overlay()
		return
	if _match_overlay.is_open():
		_match_back()
		return
	if _busy or _advancing:
		return
	if _squad_screen != null:
		_update_hints()
		return
	if overlay.is_open():
		_close_overlay()
		return
	if UiNav.event_was_modal():
		return
	if _tab == 1 and squad_view.visible and squad_view.handle_cancelled():
		return
	if _tab == 2 and transfers_view.visible:
		_update_hints()
		return
	if _tab != 0:
		_set_section(0, -1)
		return
	_exit()


func _on_nav_tab_previous(suppress_landing := true) -> void:
	if _plan_open:
		_plan_action("tab_prev")
		return
	if _busy or _advancing or overlay.is_open() or _match_overlay.is_open() \
			or _squad_screen != null:
		return
	if _tab == 1 and squad_view.visible and squad_view.handle_tab(-1):
		return
	if _tab == 2 and transfers_view.visible and transfers_view.is_overlay():
		# A transfers sub-screen (search, centre, offer…) owns the tab keys
		# itself; on the landing the strip still pages through the sections.
		return
	_switch_section(-1, suppress_landing)


func _on_nav_tab_next(suppress_landing := true) -> void:
	if _plan_open:
		_plan_action("tab_next")
		return
	if _busy or _advancing or overlay.is_open() or _match_overlay.is_open() \
			or _squad_screen != null:
		return
	if _tab == 1 and squad_view.visible and squad_view.handle_tab(1):
		return
	if _tab == 2 and transfers_view.visible and transfers_view.is_overlay():
		return
	_switch_section(1, suppress_landing)


func _on_squad_state_changed() -> void:
	_update_hints()


func _on_squad_pointer_focused() -> void:
	_zone = Zone.GRID
	_update_hints()


func _on_squad_changed() -> void:
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	_apply_snapshot()
	_save()
	_update_hints()


func _on_transfers_view_changed() -> void:
	_apply_tab_layout()
	_update_hints()


# The row fades together with the view fade, so entering/leaving the search
# does not look delayed.
func _on_transfers_opening(view: String) -> void:
	if view == "hub":
		_set_tabs_row(true, false)
		return
	breadcrumb.set_items(transfers_view.breadcrumb(view))
	breadcrumb.position = Vector2.ZERO
	_set_tabs_row(false, true)


func _on_transfers_changed() -> void:
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	_apply_snapshot()
	squad_view.refresh()
	_save()
	_update_hints()


func _on_transfers_exit() -> void:
	_set_section(0, -1)


func _on_transfers_tab(delta: int) -> void:
	_switch_section(delta)


func _show_tick_event(events: Array) -> void:
	if events.is_empty():
		return
	var last = events[-1]
	if last is Dictionary:
		hints.set_status(str(last.get("message", "")))


func _on_device_changed(_gamepad: bool) -> void:
	if _plan_open:
		if _plan != null:
			_plan.refresh_hints()
		return
	if _match_overlay.is_open():
		hints.setup(_match_hints())
		hints.set_status(_match_note())
		return
	if overlay.is_open():
		hints.setup(_overlay_hints())
		return
	_update_hints()


func _input(event: InputEvent) -> void:
	if _plan_open:
		if _is_details_event(event):
			get_viewport().set_input_as_handled()
			_plan_action("details")
		elif _is_key(event, KEY_Q):
			get_viewport().set_input_as_handled()
			_plan_action("tab_prev")
		elif _is_key(event, KEY_E):
			get_viewport().set_input_as_handled()
			_plan_action("tab_next")
		return
	if _match_overlay.is_open():
		if _match_phase == "live" and _is_skip_event(event):
			get_viewport().set_input_as_handled()
			_finish_simulation()
		return
	if _busy or _advancing or overlay.is_open() or UiNav.is_modal():
		return
	if _squad_screen == null and (_tab != 2 or _zone == Zone.TABS):
		# On the Transfers landing the transfer screen reads Q/E itself, but
		# while the main strip is focused the hub must page the sections.
		if _is_key(event, KEY_Q):
			get_viewport().set_input_as_handled()
			_on_nav_tab_previous(false)
			return
		if _is_key(event, KEY_E):
			get_viewport().set_input_as_handled()
			_on_nav_tab_next(false)
			return
	if _tab == 1 and squad_view.visible and _is_details_event(event):
		get_viewport().set_input_as_handled()
		squad_view.handle_details()
		return
	var wants_save := false
	if event is InputEventKey:
		var key := event as InputEventKey
		wants_save = key.pressed and not key.echo and (
			key.keycode == KEY_S or key.physical_keycode == KEY_S)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		wants_save = button.pressed and button.button_index == JOY_BUTTON_START
	if wants_save:
		get_viewport().set_input_as_handled()
		_save()


func _on_next_pressed() -> void:
	if _advancing:
		_stop_advance()
		return
	if _busy:
		return
	var next = _snapshot.get("season", {}).get("next")
	if not (next is Dictionary):
		hints.set_status("The season is complete.")
		return
	var match_date := str(next.get("date", ""))
	if _career.date >= match_date:
		hints.set_status("Match day В· the match screen arrives in the next build.")
		return
	_sim_start = _career.date
	_sim_date = _career.date
	if UiTransition.instant:
		_commit_advance(match_date)
		return
	_advancing = true
	_advance_token += 1
	_render_simulation()
	_run_advance(match_date, _advance_token)


func _render_simulation() -> void:
	next_tile.setup(CareerHubModel.next_tile(_snapshot, _sim_date, _sim_start))


func _run_advance(match_date: String, token: int) -> void:
	while _advancing and _advance_token == token and _sim_date < match_date:
		await get_tree().create_timer(ADVANCE_TICK).timeout
		if not is_inside_tree() or not _advancing or _advance_token != token:
			return
		_sim_date = CareerSeason.add_days(_sim_date, 1)
		if _sim_date > match_date:
			_sim_date = match_date
		_render_simulation()
	if _advancing and _advance_token == token:
		_commit_advance(_sim_date)


func _stop_advance() -> void:
	if not _advancing:
		return
	_commit_advance(_sim_date)


func _commit_advance(target: String) -> void:
	_advancing = false
	_advance_token += 1
	_sim_start = ""
	_sim_date = ""
	var league_clubs := CareerSession.catalog.all_teams_for_league(_career.league_id)
	var strengths := {}
	for club in league_clubs:
		var club_id := str(club.get("id", ""))
		strengths[club_id] = CareerSeason.squad_strength(
			CareerSession.catalog.career_squad(int(club_id)))
	if not CareerSeason.advance_to(_career, target, league_clubs, strengths):
		hints.set_status(CareerSeason.last_error, true)
		_apply_snapshot()
		return
	var tick := CareerAdvance.tick(_career, CareerSession.catalog)
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	_apply_snapshot()
	next_tile.play_advance_in()
	if not _save():
		return
	_show_tick_event(tick.get("events", []))
	var next = _snapshot.get("season", {}).get("next")
	var round_no := int(next.get("round", 0)) if next is Dictionary else 0
	hints.set_status("Advanced to %s В· round %d" % [
		CareerHubModel.short_date(target), round_no,
	])


func _on_play_pressed() -> void:
	if _busy or _advancing or _match_overlay.is_open():
		return
	_busy = true
	_match_setup = _build_match_setup()
	if _match_setup.is_empty():
		_busy = false
		return
	if not _play_current_match():
		_busy = false
		return
	_matchday = _matchday_data()
	_match_phase = "matchday_results"
	_busy = false
	_open_match_overlay()


func _on_simulation_pressed() -> void:
	if _busy or _advancing or _match_overlay.is_open():
		return
	_busy = true
	_match_setup = _build_match_setup()
	if _match_setup.is_empty():
		_busy = false
		return
	_match_result = {}
	_matchday = {}
	_match_phase = "setup"
	_match_minute = 0
	_match_confirm_guard_until = 0
	_busy = false
	_open_match_overlay()


func _open_match_overlay() -> void:
	if _match_overlay.is_open() or _busy:
		return
	_busy = true
	_render_match_overlay()
	await _fade_out(body)
	body.visible = false
	_match_overlay.open()
	if _match_phase == "matchday_results" and not UiTransition.instant:
		_match_confirm_guard_until = Time.get_ticks_msec() + 300
	await _fade_in(_match_overlay.card())
	_busy = false


func _close_match_overlay() -> void:
	if not _match_overlay.is_open() or _busy:
		return
	_busy = true
	_match_token += 1
	_match_phase = ""
	_match_confirm_guard_until = 0
	_match_overlay.close()
	await _fade_out(_match_overlay.card())
	_match_overlay.hide_card()
	body.visible = true
	await _fade_in(body)
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	_apply_snapshot()
	hints.set_status("")
	_update_hints()
	_focus_first_tile()
	_busy = false


func _render_match_overlay() -> void:
	if _match_phase in ["setup", "live", "done"]:
		_match_overlay.render_simulation(
			_match_setup, _match_result, _match_phase, _match_minute)
	elif _match_phase in ["matchday_results", "matchday_table"]:
		_match_overlay.render_matchday(_matchday,
			"results" if _match_phase == "matchday_results" else "table")
	hints.setup(_match_hints())
	hints.set_status(_match_note())


func _match_action() -> void:
	if _busy:
		return
	match _match_phase:
		"setup":
			_begin_simulation()
		"live":
			_finish_simulation()
		"done":
			_show_matchday("results")
		"matchday_results":
			_show_matchday("table")
		"matchday_table":
			_close_match_overlay()


func _match_back() -> void:
	if _busy:
		return
	match _match_phase:
		"setup", "matchday_results":
			_close_match_overlay()
		"matchday_table":
			_show_matchday("results")


func _begin_simulation() -> void:
	if _match_phase != "setup":
		return
	_busy = true
	if not _play_current_match():
		_busy = false
		return
	_match_phase = "live"
	_match_minute = 0
	_match_token += 1
	_render_match_overlay()
	_busy = false
	_run_match_clock(_match_token)


func _finish_simulation() -> void:
	if _match_phase != "live":
		return
	_match_token += 1
	_match_minute = 90
	_match_phase = "done"
	_render_match_overlay()


func _show_matchday(step: String) -> void:
	if _busy:
		return
	if _matchday.is_empty():
		_matchday = _matchday_data()
	_busy = true
	await _fade_out(_match_overlay.card())
	_match_phase = "matchday_results" if step == "results" else "matchday_table"
	_render_match_overlay()
	await _fade_in(_match_overlay.card())
	_busy = false


func _run_match_clock(token: int) -> void:
	while _match_phase == "live" and _match_token == token and _match_minute < 90:
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or _match_phase != "live" or _match_token != token:
			return
		_match_minute += 1
		if _match_minute >= 90:
			_finish_simulation()
			return
		_render_match_overlay()


func _play_current_match() -> bool:
	var fixture := CareerSeason.next_fixture(_career)
	if fixture.is_empty():
		hints.set_status("The season is complete.", true)
		return false
	if _career.date < str(fixture.get("date", "")):
		hints.set_status("Advance to the match day first.", true)
		return false
	if _match_setup.is_empty():
		hints.set_status("The lineup is not ready.", true)
		return false
	var league_clubs := _league_clubs()
	var strengths := _strengths(league_clubs)
	if CareerSeason.play_next_match(_career, league_clubs, strengths).is_empty():
		hints.set_status(CareerSeason.last_error, true)
		return false
	var score = _career.results.get(str(fixture.get("id", "")))
	if not (score is Dictionary):
		hints.set_status("The match produced no result.", true)
		return false
	_match_result = CareerMatch.build_match_simulation(
		_career.seed, fixture, _match_setup, score)
	CareerCondition.apply_match_outcome(
		_career, fixture, _match_setup, _match_result, _career.league_id)
	var tick := CareerAdvance.tick(_career, CareerSession.catalog)
	if bool(tick.get("changed", false)):
		_show_tick_event(tick.get("events", []))
	return _save()


func _build_match_setup() -> Dictionary:
	var fixture := CareerSeason.next_fixture(_career)
	if fixture.is_empty():
		hints.set_status("The season is complete.", true)
		return {}
	if _career.date < str(fixture.get("date", "")):
		hints.set_status("Advance to the match day first.", true)
		return {}
	var catalog := CareerSession.catalog
	var clubs := {}
	for club_id in [str(fixture.get("home", "")), str(fixture.get("away", ""))]:
		clubs[club_id] = catalog.career_club(int(club_id))
	var our_players := catalog.career_squad(int(_career.club_id))
	if our_players.is_empty():
		hints.set_status("The career squad is missing from the database.", true)
		return {}
	var our_ids: Array = []
	for player in our_players:
		our_ids.append(str(player.get("id", "")))
	CareerCondition.ensure_player_states(_career, our_ids)
	CareerCondition.recover_condition(_career, _career.date)
	var blocked := CareerCondition.blocked_player_ids(_career)
	var own_home := str(fixture.get("home", "")) == _career.club_id
	var home_players := our_players if own_home \
		else catalog.career_squad(int(fixture.get("home", "")))
	var away_players := our_players if not own_home \
		else catalog.career_squad(int(fixture.get("away", "")))
	var home_lineup := CareerMatch.build_lineup(
		home_players,
		_career.lineup if own_home else [],
		_career.bench_order if own_home else [],
		blocked if own_home else [],
		_career.formation if own_home else CareerFormations.DEFAULT)
	var away_lineup := CareerMatch.build_lineup(
		away_players,
		_career.lineup if not own_home else [],
		_career.bench_order if not own_home else [],
		blocked if not own_home else [],
		_career.formation if not own_home else CareerFormations.DEFAULT)
	var own_lineup := home_lineup if own_home else away_lineup
	var starters: Array = []
	for slot in own_lineup.get("slots", []):
		starters.append(str(slot.get("player", {}).get("id", "")))
	var bench: Array = []
	for player in own_lineup.get("bench", []):
		bench.append(str(player.get("id", "")))
	_career.lineup = starters
	_career.bench_order = bench
	return CareerMatch.build_match_setup(
		_career, fixture, _league_name(), clubs, home_lineup, away_lineup)


func _matchday_data() -> Dictionary:
	var clubs := {}
	for club in _league_clubs():
		var club_id := str(club.get("id", ""))
		clubs[club_id] = CareerSession.catalog.career_club(int(club_id))
	return CareerSeason.matchday_state(_career, clubs, _league_name())


func _league_clubs() -> Array:
	return CareerSession.catalog.all_teams_for_league(_career.league_id)


func _strengths(league_clubs: Array) -> Dictionary:
	var strengths := {}
	for club in league_clubs:
		var club_id := str(club.get("id", ""))
		strengths[club_id] = CareerSeason.squad_strength(
			CareerSession.catalog.career_squad(int(club_id)))
	return strengths


func _league_name() -> String:
	return str(_snapshot.get("club", {}).get("league_name", ""))


func _match_note() -> String:
	match _match_phase:
		"setup":
			return "Simulation В· lineups"
		"live":
			return "Simulation В· 1 minute per second"
		"done":
			return "Match finished"
		"matchday_results":
			return "Results of the day"
		"matchday_table":
			return "Table after the round"
	return ""


func _match_hints() -> Array:
	var gamepad := UiNav.using_gamepad()
	match _match_phase:
		"setup":
			return [
				{"keys": ["A"] if gamepad else ["ENTER"], "label": "start"},
				{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
			]
		"live":
			return [{"keys": ["Y"] if gamepad else ["R"], "label": "skip"}]
		"done":
			return [{"keys": ["A"] if gamepad else ["ENTER"], "label": "continue"}]
		"matchday_results":
			return [
				{"keys": ["A"] if gamepad else ["ENTER"], "label": "table"},
				{"keys": ["B"] if gamepad else ["ESC"], "label": "hub"},
			]
		"matchday_table":
			return [
				{"keys": ["L-STICK"] if gamepad else ["в†‘", "в†“"], "label": "scroll"},
				{"keys": ["A"] if gamepad else ["ENTER"], "label": "hub"},
				{"keys": ["B"] if gamepad else ["ESC"], "label": "results"},
			]
	return []


func _is_key(event: InputEvent, code: Key) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == code or key.physical_keycode == code)


func _is_details_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo \
			and (key.keycode == KEY_R or key.physical_keycode == KEY_R)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index == JOY_BUTTON_Y
	return false


func _is_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo \
			and (key.keycode == KEY_R or key.physical_keycode == KEY_R)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index == JOY_BUTTON_Y
	return false


func _open_overlay() -> void:
	if overlay.is_open() or _busy or _advancing or _match_overlay.is_open():
		return
	_busy = true
	overlay.setup(CareerHubModel.overlay(_snapshot))
	hints.setup(_overlay_hints())
	await _fade_out(body)
	body.visible = false
	overlay.open()
	await _fade_in(overlay.card())
	_busy = false


func _close_overlay() -> void:
	if not overlay.is_open() or _busy:
		return
	_busy = true
	overlay.close()
	await _fade_out(overlay.card())
	overlay.hide_card()
	body.visible = true
	await _fade_in(body)
	_update_hints()
	table_tile.grab_focus()
	_zone = Zone.GRID
	_busy = false


func _fade_out(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	if UiTransition.instant:
		node.modulate.a = 0.0
		node.scale = Vector2.ONE * UiTransition.SCALE_FROM
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, UiTransition.OUT_TIME)
	tween.tween_property(node, "scale", Vector2.ONE * UiTransition.SCALE_FROM,
		UiTransition.OUT_TIME)
	await tween.finished


func _fade_in(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	if UiTransition.instant:
		node.modulate.a = 1.0
		node.scale = Vector2.ONE
		return
	node.modulate.a = 0.0
	node.scale = Vector2.ONE * UiTransition.SCALE_FROM
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, UiTransition.IN_TIME)
	tween.tween_property(node, "scale", Vector2.ONE, UiTransition.IN_TIME)
	await tween.finished


func _save() -> bool:
	if _career == null:
		return false
	_career.touch()
	var store := CareerSession.store if CareerSession.store != null else CareerSaveStore.new()
	if not store.save(_career):
		hints.set_status(store.last_error, true)
		return false
	CareerSession.store = store
	hints.set_status("Career saved В· %s" % _timestamp(_career.updated_at))
	return true


func _exit() -> void:
	if not _save():
		return
	CareerSession.clear()
	_leave(MAIN_MENU_SCENE)


func _leave(path: String) -> void:
	UiTransition.change_scene(path)


func _update_hints() -> void:
	if _squad_screen != null:
		hints.setup(_squad_screen.hints() if _squad_screen.has_method("hints") else [])
		if _squad_screen.has_method("status"):
			hints.set_status(str(_squad_screen.status()),
				bool(_squad_screen.status_error()) if _squad_screen.has_method("status_error") else false)
		return
	if _match_overlay.is_open():
		hints.setup(_match_hints())
		return
	if _zone == Zone.TABS:
		hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())
		return
	if _tab == 1 and squad_view.visible:
		hints.setup(squad_view.hints())
		hints.set_status(squad_view.status(), squad_view.status_error())
		return
	if _tab == 2 and transfers_view.visible:
		hints.setup(transfers_view.hints())
		hints.set_status(transfers_view.status(), transfers_view.status_error())
		return
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())


func _keyboard_hints() -> Array:
	return [
		{"keys": ["Q", "E"], "label": "tabs"},
		{"keys": ["ENTER"], "label": "select"},
		{"keys": ["ESC"], "label": "menu"},
		{"keys": ["S"], "label": "save"},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["LB", "RB"], "label": "tabs"},
		{"keys": ["A"], "label": "select"},
		{"keys": ["B"], "label": "menu"},
		{"keys": ["START"], "label": "save"},
	]


func _overlay_hints() -> Array:
	if UiNav.using_gamepad():
		return [
			{"keys": ["L-STICK"], "label": "scroll"},
			{"keys": ["B"], "label": "back"},
		]
	return [
		{"keys": ["в†‘", "в†“"], "label": "scroll"},
		{"keys": ["ESC"], "label": "back"},
	]


static func _timestamp(iso: String) -> String:
	return iso.substr(0, 16).replace("T", " ") if iso.length() >= 16 else iso


func _logo(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return UiAssets.usable_texture(
		UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
