extends UiScreen
# Career hub: the prototype's tabbed shell (Centre / Squad / Transfers /
# Scouting) with the Centre dashboard, save and exit. Only the Centre tab is
# built; the other tabs show the shared "in progress" panel until their
# tickets land. Input goes through UiNav; the active tab is saved in the career.

const START_SCENE := "res://scenes/career_start.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ADVANCE_TICK := 1.0

enum Zone { TABS, GRID }

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var body: Control = $Design/PanelWrap/Body
@onready var tab_bar: UiTabBar = $Design/PanelWrap/Body/TabBar
@onready var grid: BentoGrid = $Design/PanelWrap/Body/Grid
@onready var next_tile: CareerHubNextTile = $Design/PanelWrap/Body/Grid/NextTile
@onready var play_tile: BentoTile = $Design/PanelWrap/Body/Grid/PlayTile
@onready var simulation_tile: BentoTile = $Design/PanelWrap/Body/Grid/SimulationTile
@onready var table_tile: CareerHubTableTile = $Design/PanelWrap/Body/Grid/TableTile
@onready var transfer_tile: BentoTile = $Design/PanelWrap/Body/Grid/TransferTile
@onready var news_tile: BentoTile = $Design/PanelWrap/Body/Grid/NewsTile
@onready var training_tile: BentoTile = $Design/PanelWrap/Body/Grid/TrainingTile
@onready var placeholder: UiMenuPanel = $Design/PanelWrap/Body/Placeholder
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
@onready var overlay: CareerHubOverlay = $Design/Overlay
@onready var _match_overlay: CareerMatchOverlay = $Design/MatchOverlay

var _snapshot: Dictionary = {}
var _career: Career
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
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	if _snapshot.is_empty():
		call_deferred("_leave", START_SCENE)
		return

	overlay.z_index = 10
	_match_overlay.z_index = 10
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
	for tile in [transfer_tile, news_tile, training_tile]:
		tile.focus_mode = Control.FOCUS_NONE
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
	var meta := "ROUND %d · %s · %s" % [
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
	tab_bar.position = Vector2.ZERO
	tab_bar.fit_width()
	grid.position = Vector2(0.0, content_top)
	grid.size = Vector2(UiTokens.PANEL_W, UiTokens.GRID_H)
	placeholder.position = grid.position
	placeholder.size = grid.size
	hints.position = Vector2(0.0, content_top + UiTokens.GRID_H + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)
	# The overlay is a full shell replacement: it covers the tabs too, like the
	# prototype hides the hub while a tournament/match screen is open.
	overlay.layout_overlay(Rect2(panel_wrap.position, body.size))
	_match_overlay.layout_overlay(Rect2(panel_wrap.position, body.size))


func _focus_initial() -> void:
	if _tab == 0:
		if _match_day:
			play_tile.grab_focus()
		else:
			next_tile.grab_focus()
		_zone = Zone.GRID
	else:
		tab_bar.focus_tab(_tab)
		_zone = Zone.TABS


func _apply_tab() -> void:
	var centre := _tab == 0
	grid.visible = centre
	placeholder.visible = not centre
	if not centre:
		placeholder.setup("%s arrives in a later build." % CareerHubModel.TABS[_tab], [])
	_update_hints()


func _on_tab_selected(index: int) -> void:
	_tab = index
	if _career != null:
		_career.hub_tab = CareerHubModel.TAB_IDS[index]
	_apply_tab()
	if _zone == Zone.GRID:
		_focus_first_tile()


func _on_bar_focused() -> void:
	_zone = Zone.TABS


func _on_tile_focused() -> void:
	_zone = Zone.GRID


func _cycle_tab(delta: int) -> void:
	var next := posmod(_tab + delta, CareerHubModel.TABS.size())
	_tab = next
	if _career != null:
		_career.hub_tab = CareerHubModel.TAB_IDS[next]
	tab_bar.select_tab(next, false)
	_apply_tab()
	if _zone == Zone.GRID:
		_focus_first_tile()
	else:
		tab_bar.focus_tab(next)


func _focus_first_tile() -> void:
	if _tab == 0:
		if _match_day:
			play_tile.grab_focus()
		else:
			next_tile.grab_focus()
		_zone = Zone.GRID
	else:
		tab_bar.focus_tab(_tab)
		_zone = Zone.TABS


func _focus_active_tab() -> void:
	tab_bar.focus_tab(_tab)
	_zone = Zone.TABS


func _on_nav_moved(direction: Vector2i) -> void:
	if _match_overlay.is_open():
		if _match_phase == "matchday_table" \
				and (direction == Vector2i.UP or direction == Vector2i.DOWN):
			_match_overlay.scroll_step(-1 if direction == Vector2i.UP else 1)
		return
	if _busy or _advancing:
		return
	if overlay.is_open():
		if direction == Vector2i.UP or direction == Vector2i.DOWN:
			overlay.scroll_step(-1 if direction == Vector2i.UP else 1)
		return
	if _zone == Zone.TABS:
		if direction == Vector2i.LEFT:
			_cycle_tab(-1)
		elif direction == Vector2i.RIGHT:
			_cycle_tab(1)
		elif direction == Vector2i.DOWN:
			_focus_first_tile()
		return
	var focus := get_viewport().gui_get_focus_owner()
	var row: Array = [play_tile, simulation_tile] if _match_day else [next_tile]
	var index := row.find(focus)
	if direction == Vector2i.UP:
		_focus_active_tab()
	elif direction == Vector2i.LEFT:
		if focus == table_tile:
			(row[-1] as Control).grab_focus()
		elif index > 0:
			(row[index - 1] as Control).grab_focus()
	elif direction == Vector2i.RIGHT:
		if index >= 0:
			if index + 1 < row.size():
				(row[index + 1] as Control).grab_focus()
			else:
				table_tile.grab_focus()


func _on_nav_confirmed() -> void:
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
	if _zone == Zone.TABS:
		_focus_first_tile()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()


func _on_nav_cancelled() -> void:
	if _match_overlay.is_open():
		_match_back()
		return
	if _busy or _advancing:
		return
	if overlay.is_open():
		_close_overlay()
		return
	if UiNav.event_was_modal():
		return
	if _tab != 0:
		_cycle_tab(-_tab)
		return
	_exit()


func _on_nav_tab_previous() -> void:
	if _busy or _advancing or overlay.is_open() or _match_overlay.is_open():
		return
	_cycle_tab(-1)


func _on_nav_tab_next() -> void:
	if _busy or _advancing or overlay.is_open() or _match_overlay.is_open():
		return
	_cycle_tab(1)


func _on_device_changed(_gamepad: bool) -> void:
	if _match_overlay.is_open():
		hints.setup(_match_hints())
		hints.set_status(_match_note())
		return
	if overlay.is_open():
		hints.setup(_overlay_hints())
		return
	_update_hints()


func _input(event: InputEvent) -> void:
	if _match_overlay.is_open():
		if _match_phase == "live" and _is_skip_event(event):
			get_viewport().set_input_as_handled()
			_finish_simulation()
		return
	if _busy or _advancing or overlay.is_open() or UiNav.is_modal():
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
		hints.set_status("Match day · the match screen arrives in the next build.")
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
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	_apply_snapshot()
	next_tile.play_advance_in()
	if not _save():
		return
	var next = _snapshot.get("season", {}).get("next")
	var round_no := int(next.get("round", 0)) if next is Dictionary else 0
	hints.set_status("Advanced to %s · round %d" % [
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
	if _matchday.is_empty():
		_matchday = _matchday_data()
	_match_phase = "matchday_results" if step == "results" else "matchday_table"
	_render_match_overlay()


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
			return "Simulation · lineups"
		"live":
			return "Simulation · 1 minute per second"
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
				{"keys": ["L-STICK"] if gamepad else ["↑", "↓"], "label": "scroll"},
				{"keys": ["A"] if gamepad else ["ENTER"], "label": "hub"},
				{"keys": ["B"] if gamepad else ["ESC"], "label": "results"},
			]
	return []


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
	hints.set_status("Career saved · %s" % _timestamp(_career.updated_at))
	return true


func _exit() -> void:
	if not _save():
		return
	CareerSession.clear()
	_leave(MAIN_MENU_SCENE)


func _leave(path: String) -> void:
	UiTransition.change_scene(path)


func _update_hints() -> void:
	if _match_overlay.is_open():
		hints.setup(_match_hints())
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
		{"keys": ["↑", "↓"], "label": "scroll"},
		{"keys": ["ESC"], "label": "back"},
	]


static func _timestamp(iso: String) -> String:
	return iso.substr(0, 16).replace("T", " ") if iso.length() >= 16 else iso


func _logo(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return UiAssets.usable_texture(
		UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
