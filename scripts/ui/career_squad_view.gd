class_name CareerSquadView
extends Control
# Squad tab: the prototype's SquadOverview and PlanView (squad/schemes/roles
# plus the player details pages). Drawn directly so the pitch, cards and role
# glyphs follow the prototype's proportions; keyboard, gamepad and mouse share
# the same focus list.

signal changed
signal state_changed
# Overview -> the shared Game Plan screen, hosted by the hub as a full overlay.
signal plan_requested
# Overview <-> centre/details: the hub hides the main tabs and expands this view
# to the full body, so it animates the change.
signal view_changed(direction: int)
signal player_action_requested(action: String, player_id: String)
# The pointer moved into the custom-drawn page: the shell's tab strip must drop
# its viewport focus, like the real tiles do in Centre/Transfers.
signal pointer_focused

const GAP := 10.0
const FocusGrid := preload("res://scripts/ui/ui_focus_grid.gd")
const TAB_H := 52.0
const HEAD_H := 112.0
const BENCH_CLOSED := 112.0
const BENCH_OPEN := 460.0
const SCHEME_CARD_H := 124.0
const ROLE_H := 208.0
const DETAIL_PAGES := ["ATTRIBUTES", "STATUS", "STATISTICS", "FINANCE"]
const CENTRE_TABS := ["STATUS", "STATISTICS", "ATTRIBUTES", "FINANCE"]
const ATTRIBUTE_PAGES := ["OVERVIEW", "MENTAL", "PHYSICAL", "TECHNICAL"]

const PITCH_DARK := Color("0d3b2d")
const PITCH_MID := Color("176046")
const PITCH_LIGHT := Color("2a815f")
const PITCH_LINE := Color(1.0, 1.0, 1.0, 0.30)
const MARK_WIN := Color("2f7d4f")
const MARK_LOSS := Color("b23a48")
const MARK_WARN := Color("a66a00")
const POS_GK := Color("d96b00")
const POS_DEF := Color("a88600")
const POS_MID := Color("23864a")
const POS_FWD := Color("1f63b8")
const BENCH_BG := Color("f0f2f7")
const SCHEME_BG := Color("e8ecf2")
# Same shirt silhouette as the game's KitArt (240x196 view box), drawn inline
# so the pitch cards keep one control per view.
# shortcut: копия геометрии KitArt — при смене арта формы разъедется; заменить
# на KitArt-узлы вместе с унификацией плана (issue 11).
var SHIRT := PackedVector2Array([
	Vector2(80, 10), Vector2(58, 18), Vector2(26, 32), Vector2(8, 76),
	Vector2(50, 94), Vector2(66, 74), Vector2(66, 186), Vector2(174, 186),
	Vector2(174, 74), Vector2(190, 94), Vector2(232, 76), Vector2(214, 32),
	Vector2(182, 18), Vector2(160, 10), Vector2(150, 20), Vector2(135, 27),
	Vector2(120, 32), Vector2(105, 27), Vector2(92, 20),
])

const PLAN_TABS := [
	{"id": "squad", "label": "SQUAD", "disabled": false},
	{"id": "schemes", "label": "FORMATIONS", "disabled": false},
	{"id": "roles", "label": "ROLES", "disabled": false},
]

const OVERVIEW_TILES := [
	{"id": "club", "label": "CLUB", "note": "Current first team", "selected": true},
	{"id": "national", "label": "NATIONAL", "note": "Not available in this build",
		"icon": "globe", "disabled": true},
	{"id": "centre", "label": "SQUAD CENTRE",
		"note": "Status, statistics and finances", "icon": "users"},
	{"id": "national-squad", "label": "NATIONAL SQUAD",
		"note": "Manage your national team", "icon": "globe", "disabled": true},
	{"id": "main-squads", "label": "MAIN SQUADS",
		"note": "Development squads — #4", "icon": "layers", "disabled": true},
	{"id": "change", "label": "CHANGE CLUB", "note": "Choose another club",
		"icon": "lock", "disabled": true},
]

enum View { OVERVIEW, PLAN, DETAILS, CENTRE }

var career: Career
var catalog: TeamCatalog
var squad: Dictionary = {}
var view := View.OVERVIEW
var plan_tab := "squad"
var details_page := 0
var anchor_id := ""
var role_focus := "captain"
var role_picking := ""
var formation_index := 0
var formation_page := 0
var bench_open := false
var bench_scroll := 0.0
var centre_tab := 0
var centre_player := 0
var centre_scroll := 0.0
var centre_attribute_page := 0
var _actions_row: CareerSquadActionsRow
var _actions_bg: Panel
var _actions_player_id := ""

var _elements: Array = []
var _focus_id := ""
var _last_player_id := ""
var _tab_items: Array = []
var _centre_tabs_bar: UiTabBar
var _status := ""
var _status_error := false
var _club_logo: Texture2D
var _kit: Dictionary = {}
var _lineup_preview: PauseLineup
var _scheme_preview_id := ""
var _scheme_preview: Dictionary = {}
var _slide := 0.0
var _slide_tween: Tween
var _tab_marker := Rect2()
var _marker_from := Rect2()
var _marker_to := Rect2()
var _marker_ready := false
var _marker_tween: Tween


# The centre's tabs are the hub's TabBar component: same strip, plate and
# pacing as the main tabs. The view keeps its own focus model, so the bar runs
# in external-focus mode and only draws/labels.
func _build_centre_tabs() -> void:
	if _centre_tabs_bar != null:
		return
	_centre_tabs_bar = UiTabBar.new()
	_centre_tabs_bar.name = "CentreTabs"
	_centre_tabs_bar.external_focus = true
	var labels: Array[String] = []
	for label in CENTRE_TABS:
		labels.append(label)
	_centre_tabs_bar.setup(labels)
	_centre_tabs_bar.fit_width()
	_centre_tabs_bar.tab_selected.connect(_on_centre_tab_selected)
	for index in range(CENTRE_TABS.size()):
		var button := _centre_tabs_bar.get_tab_button(index)
		if button != null:
			button.mouse_entered.connect(_on_centre_tab_hover.bind(index))
	_centre_tabs_bar.visible = false
	add_child(_centre_tabs_bar)


# Hover focuses the virtual strip without switching; the click then selects the
# tab and keeps the strip focused, like the main career tabs.
func _on_centre_tab_hover(index: int) -> void:
	if view != View.CENTRE:
		return
	_set_focus("centre-tab:%d" % index)


func _on_centre_tab_selected(index: int) -> void:
	_set_centre_tab(index, true)


func _sync_centre_tabs() -> void:
	if _centre_tabs_bar == null:
		return
	_centre_tabs_bar.position = Vector2.ZERO
	# Only re-select when the active tab differs: a mouse click already started
	# the marker tween through the button, and selecting again snapped it.
	if _centre_tabs_bar.get_active_tab() != centre_tab:
		_centre_tabs_bar.select_tab(centre_tab, false)
	_centre_tabs_bar.set_focused(
		view == View.CENTRE and str(_focused_element().get("kind", "")) == "centre-tab")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_centre_tabs()
	_lineup_preview = PauseLineup.new()
	_lineup_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lineup_preview)
	resized.connect(_on_resized)


func setup(next_career: Career, next_catalog: TeamCatalog) -> void:
	career = next_career
	catalog = next_catalog
	view = View.OVERVIEW
	plan_tab = "squad"
	details_page = 0
	anchor_id = ""
	role_picking = ""
	bench_open = false
	bench_scroll = 0.0
	_status = ""
	_status_error = false
	refresh()
	_focus_id = "team"
	_rebuild_elements()
	queue_redraw()


func refresh() -> void:
	if career != null and catalog != null:
		CareerCondition.ensure_player_states(career, career.player_ids)
		CareerCondition.recover_condition(career, career.date)
		if career.player_contracts.is_empty():
			CareerSquad.ensure_finances(career,
				CareerSquad.roster(catalog, career, career.club_id, false))
	squad = CareerSquad.snapshot(catalog, career)
	_club_logo = null
	_kit = {}
	if not squad.is_empty():
		var club: Dictionary = catalog.career_club(int(career.club_id))
		_club_logo = UiAssets.team_logo(club)
		_kit = KitCatalog.new().default_kit(club, 0)
	_update_lineup_preview()
	formation_index = CareerFormations.formation_index(career.formation)
	formation_page = int(formation_index / 3.0)
	_scheme_preview_id = ""
	_scheme_preview = {}
	_rebuild_elements()
	_ensure_focus()
	queue_redraw()


func open() -> void:
	view = View.OVERVIEW
	plan_tab = "squad"
	details_page = 0
	anchor_id = ""
	role_picking = ""
	bench_open = false
	bench_scroll = 0.0
	_status = ""
	_status_error = false
	refresh()
	_focus_id = "team"
	_rebuild_elements()
	state_changed.emit()
	queue_redraw()


func close() -> void:
	bench_open = false
	_close_actions()


# Player actions accordion (ticket 06): the prototype grows the selected row and
# pushes the rest of the list down; here the row opens in a gap the list leaves
# under it, so it never covers a player. The list then scrolls to show the row
# and the plate together instead of lifting the plate off its row.
func _open_actions(player: Dictionary) -> void:
	if player.is_empty() or career == null:
		return
	if _actions_row == null:
		_actions_row = CareerSquadActionsRow.new()
		add_child(_actions_row)
		_actions_row.action_requested.connect(_on_actions_requested)
		_actions_row.changed.connect(_on_actions_changed)
		_actions_row.fold_changed.connect(_on_actions_fold)
	_actions_player_id = str(player.get("id", ""))
	var players := _centre_players()
	for index in range(players.size()):
		if str(players[index].get("id", "")) == _actions_player_id:
			centre_player = index
			break
	var m := _centre_metrics()
	var column: Rect2 = m["table"] if centre_tab == 3 else m["list"]
	_actions_row.size = Vector2(column.size.x, _actions_row.height_hint())
	_ensure_centre_visible(centre_player)
	_place_actions()
	_actions_row.setup(career, catalog, player)
	_actions_row.set_notice(bool(CareerSquadActions.negotiation_state(
		career, catalog, _actions_player_id).get("unread", false)))
	_actions_row.focus_initial()
	_actions_row.play_open()
	_rebuild_elements()
	state_changed.emit()
	queue_redraw()


func _on_actions_fold() -> void:
	# The plate grows and shrinks frame by frame: the rows under it have to
	# follow, otherwise the closing reads as a jump.
	var open := _actions_index()
	if open < 0:
		return
	_ensure_centre_visible(open)
	_place_actions()
	queue_redraw()


# The plate hangs right under its row, wherever the list is scrolled.
func _place_actions() -> void:
	var open := _actions_index()
	if open < 0:
		return
	var m := _centre_metrics()
	var column: Rect2 = m["table"] if centre_tab == 3 else m["list"]
	_actions_row.position = Vector2(column.position.x,
		column.position.y + 2.0 + _centre_row_offset(open)
		+ _centre_row_height() - centre_scroll)


# The row folds away instead of vanishing: it stays the host's row (and keeps
# ignoring input) until its close animation ends, then it is freed.
func _close_actions() -> void:
	if _actions_row == null:
		return
	var row := _actions_row
	var player_id := _actions_player_id
	row.play_close()
	state_changed.emit()
	queue_redraw()
	if not row.is_closed():
		await row.closed
	_actions_row = null
	_actions_player_id = ""
	if not player_id.is_empty() and view == View.CENTRE:
		_focus_id = "centre-row:%s" % player_id
		var index := _actions_index_of(player_id)
		if index >= 0:
			_ensure_centre_visible(index)
		_rebuild_elements()
	row.queue_free()
	state_changed.emit()
	queue_redraw()


# The row plays its close before it reports, so the action never opens a screen
# on top of a panel that is still on screen.
func _on_actions_requested(action: String, player_id: String) -> void:
	_close_actions()
	if action == "plan":
		plan_requested.emit()
		return
	player_action_requested.emit(action, player_id)


func _on_actions_changed() -> void:
	var player_id := _actions_player_id
	refresh()
	if _actions_row != null:
		for row in _centre_players():
			if str(row.get("id", "")) == player_id:
				_actions_row.setup(career, catalog, row)
				break
	changed.emit()


func focus_initial() -> void:
	match view:
		View.OVERVIEW:
			_focus_id = "team"
		View.DETAILS:
			_focus_id = "details"
		View.CENTRE:
			_focus_id = "centre-row:%s" % str(_centre_current().get("id", ""))
		View.PLAN:
			match plan_tab:
				"schemes":
					_focus_id = "scheme:%s" % _preview_formation().get("id", career.formation)
				"roles":
					_focus_id = "role:%s" % role_focus
				_:
					_focus_id = _first_card_id()
		_:
			_focus_id = "team"
	_rebuild_elements()
	queue_redraw()


func current_view() -> String:
	match view:
		View.OVERVIEW: return "overview"
		View.PLAN: return "plan"
		View.DETAILS: return "details"
	return "centre"


func current_plan_tab() -> String:
	return plan_tab


func focused_id() -> String:
	return _focus_id


func is_bench_open() -> bool:
	return bench_open


func previewed_formation() -> String:
	return str(_preview_formation().get("id", career.formation if career != null else ""))


func anchor() -> String:
	return anchor_id


func status() -> String:
	return _status


func status_error() -> bool:
	return _status_error


func hints() -> Array:
	if _actions_row != null:
		return _actions_row.hints()
	var gamepad := UiNav.using_gamepad()
	var tabs: Array = ["LB", "RB"] if gamepad else ["Q", "E"]
	var accept: Array = ["A"] if gamepad else ["ENTER"]
	var back: Array = ["B"] if gamepad else ["ESC"]
	var arrows: Array = ["L-STICK"] if gamepad else ["ARROWS"]
	if view == View.OVERVIEW:
		return [
			{"keys": accept, "label": "Game plan"},
			{"keys": tabs, "label": "Tabs"},
			{"keys": back, "label": "Back"},
		]
	if view == View.CENTRE:
		var list: Array = [
			{"keys": arrows, "label": "Navigate"},
			{"keys": tabs, "label": "Tabs"},
			{"keys": back, "label": "Back"},
		]
		return list
	if view == View.DETAILS:
		return [
			{"keys": tabs, "label": "Page"},
			{"keys": ["Y"] if gamepad else ["R"], "label": "Close details"},
			{"keys": back, "label": "Back"},
		]
	if plan_tab == "schemes":
		return [
			{"keys": tabs, "label": "Tabs"},
			{"keys": arrows, "label": "Formations"},
			{"keys": accept, "label": "Select"},
			{"keys": back, "label": "Back"},
		]
	if plan_tab == "roles" and not role_picking.is_empty():
		return [
			{"keys": arrows, "label": "Choose player"},
			{"keys": accept, "label": "Assign"},
			{"keys": back, "label": "Cancel"},
		]
	if plan_tab == "roles":
		return [
			{"keys": tabs, "label": "Tabs"},
			{"keys": arrows, "label": "Role"},
			{"keys": accept, "label": "Choose"},
			{"keys": back, "label": "Back"},
		]
	var select := "Select"
	if not anchor_id.is_empty():
		select = "Swap" if _can_swap() else "Unavailable"
	return [
		{"keys": arrows, "label": "Navigate"},
		{"keys": accept, "label": select},
		{"keys": ["Y"] if gamepad else ["R"], "label": "Details"},
		{"keys": back, "label": "Back" if anchor_id.is_empty() else "Clear"},
	]


# The main tab strip owns the focus: the overview must not keep drawing its own
# focused tile under a focused tab bar.
func blur() -> void:
	if view != View.OVERVIEW:
		return
	_focus_id = ""
	queue_redraw()


func handle_moved(direction: Vector2i) -> bool:
	if _actions_row != null:
		return _actions_row.handle_moved(direction)
	# The overview has no row above its top tiles: the geometric helper treats
	# a tile at the top edge as the top row (whatever its height) and reports
	# no neighbour, so Up hands focus back to the hub's active main tab.
	if view == View.OVERVIEW:
		return _move_focus(direction, 1.0)
	if view == View.DETAILS:
		return true
	if view == View.CENTRE:
		if str(_focused_element().get("kind", "")) == "centre-tab":
			if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
				# The strip follows the main hub: sideways pages its tabs and
				# keeps the focus on the strip. It never leaves the screen.
				_set_centre_tab(posmod(centre_tab
					+ (1 if direction == Vector2i.RIGHT else -1),
					CENTRE_TABS.size()), true)
				return true
			if direction == Vector2i.UP:
				# Up from the centre's own tab strip leaves the roster for the
				# squad overview (and Up there hands focus to the main tabs).
				_open_overview()
				return true
	if view == View.PLAN and plan_tab == "schemes":
		return _step_schemes(direction)
	return _move_focus(direction)


func handle_confirmed() -> bool:
	if _actions_row != null:
		return _actions_row.handle_confirmed()
	var element := _focused_element()
	if element.is_empty():
		return false
	match str(element.get("kind", "")):
		"team":
			plan_requested.emit()
			return true
		"tile":
			if str(element.get("id", "")) == "tile:centre":
				_open_centre()
				return true
			return true
		"tab":
			_open_plan_tab(str(element.get("data", {}).get("id", "")))
			return true
		"card", "bench":
			if view == View.PLAN and plan_tab == "roles" and not role_picking.is_empty():
				_assign_role(str(element.get("player_id", "")))
				return true
			_activate_player(str(element.get("player_id", "")))
			return true
		"scheme":
			_select_formation(str(element.get("data", {}).get("id", "")))
			return true
		"role":
			_start_role_pick(str(element.get("data", {}).get("id", "")))
			return true
		"details":
			return true
		"centre-tab":
			_set_centre_tab(int(element.get("data", {}).get("index", 0)))
			return true
		"centre-attr":
			centre_attribute_page = posmod(centre_attribute_page
				+ int(element.get("data", {}).get("delta", 1)), ATTRIBUTE_PAGES.size())
			state_changed.emit()
			queue_redraw()
			return true
		"centre-row":
			_open_actions(element.get("player", {}))
			return true
	return false


func handle_cancelled() -> bool:
	if _actions_row != null:
		_close_actions()
		return true
	if view == View.DETAILS:
		view = View.PLAN
		_focus_id = "card:%s" % _focused_player_id()
		_rebuild_elements()
		_animate_switch(-1)
		state_changed.emit()
		queue_redraw()
		return true
	if view == View.CENTRE:
		_open_overview()
		return true
	if view == View.PLAN:
		if not role_picking.is_empty():
			var role := role_picking
			role_picking = ""
			_focus_id = "role:%s" % role
			_rebuild_elements()
			state_changed.emit()
			queue_redraw()
			return true
		if plan_tab != "squad":
			_open_plan_tab("squad")
			return true
		if not anchor_id.is_empty():
			anchor_id = ""
			_rebuild_elements()
			state_changed.emit()
			queue_redraw()
			return true
		_open_overview()
		return true
	return false


func handle_tab(direction: int) -> bool:
	if view == View.DETAILS:
		details_page = posmod(details_page + (1 if direction > 0 else -1), DETAIL_PAGES.size())
		_animate_switch(1 if direction > 0 else -1)
		state_changed.emit()
		queue_redraw()
		return true
	if view == View.CENTRE:
		_set_centre_tab(posmod(centre_tab + (1 if direction > 0 else -1),
			CENTRE_TABS.size()))
		return true
	if view == View.PLAN:
		if not role_picking.is_empty():
			return true
		var enabled: Array = []
		for item in PLAN_TABS:
			if not item["disabled"]:
				enabled.append(str(item["id"]))
		var index := maxi(0, enabled.find(plan_tab))
		_open_plan_tab(str(enabled[posmod(index + (1 if direction > 0 else -1),
			enabled.size())]))
		return true
	return false


func handle_details() -> bool:
	if view == View.PLAN and plan_tab == "squad":
		anchor_id = ""
		bench_open = false
		details_page = 0
		view = View.DETAILS
		_focus_id = "details"
		_rebuild_elements()
		_animate_switch(1)
		state_changed.emit()
		queue_redraw()
		return true
	if view == View.DETAILS:
		view = View.PLAN
		_focus_id = "card:%s" % _focused_player_id()
		_rebuild_elements()
		_animate_switch(-1)
		state_changed.emit()
		queue_redraw()
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _element_at(event.position)
		if not hit.is_empty() and hit.get("disabled", false) == false:
			_take_pointer_focus()
			_set_focus(str(hit.get("id", "")))
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var hit := _element_at(button.position)
			if not hit.is_empty() and hit.get("disabled", false) == false:
				_take_pointer_focus()
				if str(hit.get("kind", "")) == "centre-tab":
					_set_centre_tab(int(hit.get("data", {}).get("index", 0)))
					return
				if str(hit.get("kind", "")) == "centre-row":
					_click_centre_row(hit)
					return
				_set_focus(str(hit.get("id", "")))
				handle_confirmed()


# A click on a player row opens or folds its plate — it never goes through
# handle_confirmed, which would press the action the plate has in focus.
func _click_centre_row(element: Dictionary) -> void:
	var player_id := str(element.get("player_id", ""))
	if _actions_row != null and _actions_player_id == player_id:
		_close_actions()
		return
	_set_focus(str(element.get("id", "")))
	_open_actions(element.get("player", {}))


func _take_pointer_focus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or is_ancestor_of(owner):
		return
	owner.release_focus()
	pointer_focused.emit()


func _on_resized() -> void:
	_rebuild_elements()
	_sync_tab_marker(false)
	_sync_centre_tabs()
	_place_lineup_preview()
	queue_redraw()


# Overview preview: the pause-menu lineup widget (perspective pitch + kit
# chips), not a second drawing of the plan.
func _update_lineup_preview() -> void:
	if _lineup_preview == null:
		return
	var entries: Array = []
	for slot in _lineup_slots():
		var player: Dictionary = slot.get("player", {})
		if player.is_empty():
			continue
		entries.append({
			"position": CareerPlan._position(slot),
			"role": str(slot.get("role", "")),
			"rating": int(round(float(player.get("overall", 0.0)))),
			"name": _player_name(player),
		})
	_lineup_preview.setup(entries, _kit)
	_lineup_preview.visible = view == View.OVERVIEW
	_place_lineup_preview()


func _place_lineup_preview() -> void:
	if _lineup_preview == null or view != View.OVERVIEW:
		return
	var tile: Rect2 = _overview_metrics()["team"]
	var rect := _team_pitch_rect(tile)
	_lineup_preview.position = rect.position
	_lineup_preview.size = rect.size


func _team_pitch_rect(rect: Rect2) -> Rect2:
	var pad_left := 28.0
	var pad_right := 22.0
	var pad_top := 20.0
	return Rect2(rect.position.x + pad_left, rect.position.y + pad_top + 112.0,
		rect.size.x - pad_left - pad_right,
		rect.size.y - 112.0 - pad_top - 16.0 - 21.0 - 12.0 - 12.0)


# Section animation --------------------------------------------------------

func _animate_switch(direction: int) -> void:
	_slide = 0.0
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if direction == 0 or UiTransition.instant or not is_inside_tree():
		queue_redraw()
		return
	_slide = 64.0 * float(direction)
	_slide_tween = create_tween()
	_slide_tween.tween_method(_set_slide, _slide, 0.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_slide(value: float) -> void:
	_slide = value
	queue_redraw()


# The active tab is one marker plate that slides between tabs; the labels stay
# put, so a tab change reads as a swipe like the main menu grid.
# The plan view still draws its own tab strip; the centre one is the hub's
# TabBar component (see _sync_centre_tabs).
func _sync_tab_marker(animate: bool) -> void:
	var items := _active_tab_items()
	var target := Rect2()
	for item in items:
		if str(item.get("id", "")) == plan_tab:
			target = item["rect"]
			break
	if target.size.x <= 0.0:
		_marker_ready = false
		return
	if not animate or not _marker_ready or UiTransition.instant or not is_inside_tree():
		_tab_marker = target
		_marker_ready = true
		queue_redraw()
		return
	_marker_from = _tab_marker
	_marker_to = target
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = create_tween()
	_marker_tween.tween_method(_set_marker_progress, 0.0, 1.0, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_marker_progress(t: float) -> void:
	_tab_marker = Rect2(
		(_marker_from.position as Vector2).lerp(_marker_to.position, t),
		(_marker_from.size as Vector2).lerp(_marker_to.size, t))
	queue_redraw()


func _active_tab_items() -> Array:
	if view == View.PLAN or view == View.DETAILS:
		return _plan_tab_rects((size.x - GAP) * 0.5)
	return []


func _draw_tab_marker() -> void:
	# Same shape as the hub's TabBar: a translucent strip behind the row and a
	# white plate with the rail rule under the active tab; the plate goes navy
	# and the rule lime while the row owns focus.
	if not _marker_ready:
		return
	var items := _active_tab_items()
	if not items.is_empty():
		var last: Rect2 = items[-1]["rect"]
		draw_rect(Rect2(0.0, 0.0, last.end.x, TAB_H),
			Color(UiTokens.TILE, 0.72), true)
	var focused := _tab_row_focused()
	draw_rect(_tab_marker, UiTokens.FOCUS_FILL if focused else UiTokens.TILE, true)
	draw_rect(Rect2(_tab_marker.position.x, _tab_marker.end.y - 4.0,
		_tab_marker.size.x, 4.0), UiTokens.FOCUS_MARK if focused else UiTokens.RAIL, true)


func _tab_row_focused() -> bool:
	var kind := str(_focused_element().get("kind", ""))
	return kind == "tab"


# Drawing ------------------------------------------------------------------

func _draw() -> void:
	if squad.is_empty():
		return
	if _centre_tabs_bar != null:
		_centre_tabs_bar.visible = view == View.CENTRE
		if view == View.CENTRE:
			_centre_tabs_bar.set_focused(
				str(_focused_element().get("kind", "")) == "centre-tab")
	match view:
		View.OVERVIEW:
			_draw_overview()
		View.PLAN, View.DETAILS:
			_draw_plan()
		View.CENTRE:
			_draw_centre()


func _draw_overview() -> void:
	var m := _overview_metrics()
	_draw_team_tile(m["team"])
	var tile_rects: Array = m["tiles"]
	for index in range(tile_rects.size()):
		_draw_squad_tile(tile_rects[index], OVERVIEW_TILES[index])


func _set_centre_tab(index: int, keep_tab_focus := false) -> void:
	_close_actions()
	var direction := signi(clampi(index, 0, CENTRE_TABS.size() - 1) - centre_tab)
	centre_tab = clampi(index, 0, CENTRE_TABS.size() - 1)
	centre_attribute_page = 0
	if keep_tab_focus:
		# Arrow paging leaves the focus on the strip, like the main hub tabs.
		_focus_id = "centre-tab:%d" % centre_tab
	else:
		var player := _centre_current()
		_focus_id = "centre-row:%s" % str(player.get("id", ""))
	_rebuild_elements()
	_ensure_centre_visible(centre_player)
	_animate_switch(direction)
	_sync_centre_tabs()
	state_changed.emit()
	queue_redraw()


func _draw_centre() -> void:
	var m := _centre_metrics()
	for item in (m["tabs"] as Array):
		_draw_centre_tab(item)
	draw_set_transform(Vector2(_slide, 0.0))
	if centre_tab == 3:
		var summary: Rect2 = m["summary"]
		var table: Rect2 = m["table"]
		var panel: Rect2 = m["panel"]
		_draw_finance_summary(summary)
		_draw_finance_table(table)
		_draw_centre_pane(panel)
	else:
		var list: Rect2 = m["list"]
		var panel: Rect2 = m["panel"]
		_draw_centre_roster(list)
		_draw_centre_pane(panel)
	draw_set_transform(Vector2.ZERO)


func _centre_metrics() -> Dictionary:
	var stage_w := size.x
	var left := (stage_w - GAP) * 1.05 / 2.0
	var right := stage_w - GAP - left
	var body_y := TAB_H + GAP
	var body_h := size.y - body_y
	if centre_tab == 3:
		return {
			"tabs": _centre_tab_rects(stage_w),
			"summary": Rect2(0.0, body_y, stage_w, 72.0),
			"table": Rect2(0.0, body_y + 82.0, left, body_h - 82.0),
			"panel": Rect2(left + GAP, body_y + 82.0, right, body_h - 82.0),
		}
	return {
		"tabs": _centre_tab_rects(stage_w),
		"list": Rect2(0.0, body_y, left, body_h),
		"panel": Rect2(left + GAP, body_y, right, body_h),
	}


func _centre_tab_rects(stage_w: float) -> Array:
	# The strip itself is the hub's TabBar (see _sync_centre_tabs); this maps its
	# rects onto the view's own focus model. No sync here: it would restart the
	# marker tween on every redraw, so the marker never slides.
	var items: Array = []
	if _centre_tabs_bar == null:
		return items
	for index in range(CENTRE_TABS.size()):
		items.append({
			"index": index, "label": CENTRE_TABS[index],
			"rect": _centre_tabs_bar.tab_rect(index),
		})
	return items


func _draw_centre_tab(item: Dictionary) -> void:
	# Drawn by the shared TabBar; kept so the metrics stay one list.
	if item.is_empty():
		return


func _draw_centre_roster(rect: Rect2) -> void:
	var players := _centre_players()
	for index in range(players.size()):
		var player: Dictionary = players[index]
		var row := Rect2(rect.position.x, rect.position.y + 2.0
			+ _centre_row_offset(index) - centre_scroll, rect.size.x, 50.0)
		if not _rect_intersects(row, rect):
			continue
		var focused := _focus_id == "centre-row:%s" % str(player.get("id", ""))
		_draw_tile(row, focused)
		var photo := Rect2(row.position.x + 12.0, row.position.y + 5.0, 32.0, 40.0)
		_draw_player_photo(photo, player)
		var name_rect := Rect2(row.position.x + 52.0, row.position.y + 4.0,
			row.size.x - 160.0, 21.0)
		var name_color := UiTokens.FOCUS_MARK if focused else UiTokens.INK
		_draw_text(name_rect, _initial_name(player), UiTheme.barlow(700), 19,
			name_color)
		var meta_y := row.position.y + 24.0
		var role := str(player.get("role", ""))
		var role_color := UiTokens.FOCUS_INK_2 if focused else _role_color(role)
		_draw_text(Rect2(row.position.x + 52.0, meta_y, 44.0, 18.0), role,
			UiTheme.inter(600), 14, role_color)
		_draw_text(Rect2(row.position.x + 98.0, meta_y, row.size.x - 220.0, 18.0),
			str(player.get("squad_role_short", "")), UiTheme.inter(500), 14,
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		if centre_tab == 1:
			var season: Dictionary = player.get("season_stats", {})
			_draw_text(Rect2(row.end.x - 300.0, row.position.y, 288.0, row.size.y),
				"%d APP · %d G · %d A · %d MIN" % [int(season.get("apps", 0)),
					int(season.get("goals", 0)), int(season.get("assists", 0)),
					int(season.get("minutes", 0))],
				UiTheme.inter(500), 15,
				UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2,
				HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			_draw_text(Rect2(row.end.x - 72.0, row.position.y, 40.0, row.size.y),
				str(int(round(float(player.get("overall", 0.0))))),
				UiTheme.barlow(700), 20,
				UiTokens.FOCUS_INK if focused else _rating_color(
					int(round(float(player.get("overall", 0.0))))))
			if centre_tab == 0:
				_draw_morale_face(Rect2(row.end.x - 34.0, row.position.y + 16.0,
					18.0, 18.0), player)


func _draw_morale_face(rect: Rect2, player: Dictionary) -> void:
	if int(player.get("expected_minutes", 0)) <= 0:
		_draw_text(rect, "—", UiTheme.inter(500), 16, UiTokens.INK_2,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	var morale := int(player.get("morale", 100))
	var color := MARK_WIN
	if morale < 40:
		color = MARK_LOSS
	elif morale < 70:
		color = MARK_WARN
	draw_circle(rect.get_center(), rect.size.x * 0.42, color)
	draw_circle(rect.get_center() + Vector2(-rect.size.x * 0.12, -rect.size.y * 0.08),
		rect.size.x * 0.06, UiTokens.FOCUS_INK)
	draw_circle(rect.get_center() + Vector2(rect.size.x * 0.12, -rect.size.y * 0.08),
		rect.size.x * 0.06, UiTokens.FOCUS_INK)


func _draw_finance_summary(rect: Rect2) -> void:
	var finance: Dictionary = squad.get("finance", {})
	var labels := ["CLUB BALANCE", "SQUAD VALUE", "WEEKLY WAGES"]
	var values := [
		_format_value(int(finance.get("balance", 0))),
		_format_value(int(finance.get("total_market_value", 0))),
		_format_value(int(finance.get("weekly_wage_bill", 0))) + " / WEEK",
	]
	var card_w := (rect.size.x - GAP * 2.0) / 3.0
	for index in range(3):
		var card := Rect2(rect.position.x + index * (card_w + GAP), rect.position.y,
			card_w, rect.size.y)
		draw_rect(card, UiTokens.TILE, true)
		_draw_text(Rect2(card.position.x + 20.0, card.position.y + 10.0,
			card.size.x - 40.0, 20.0), labels[index], UiTheme.inter(600), 15,
			UiTokens.INK_2)
		_draw_text(Rect2(card.position.x + 20.0, card.position.y + 32.0,
			card.size.x - 40.0, 32.0), values[index], UiTheme.barlow(700), 28,
			UiTokens.INK)


func _draw_finance_table(rect: Rect2) -> void:
	var header := Rect2(rect.position.x, rect.position.y, rect.size.x, 28.0)
	# Opaque like the prototype's `.finance-head` plate (var(--tile) at full alpha).
	draw_rect(header, Color(UiTokens.TILE, 1.0), true)
	var columns := _finance_columns(header)
	var photo_col: Rect2 = columns["photo"]
	var player_col: Rect2 = columns["player"]
	var age_col: Rect2 = columns["age"]
	var value_col: Rect2 = columns["value"]
	var wage_col: Rect2 = columns["wage"]
	var years_col: Rect2 = columns["years"]
	_draw_text(Rect2(photo_col.position.x, player_col.position.y,
		player_col.end.x - photo_col.position.x, player_col.size.y),
		"PLAYER", UiTheme.inter(600), 13, UiTokens.INK_2)
	_draw_text(age_col, "AGE", UiTheme.inter(600), 13, UiTokens.INK_2,
		HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text(value_col, "VALUE", UiTheme.inter(600), 13, UiTokens.INK_2,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_text(wage_col, "WAGE", UiTheme.inter(600), 13, UiTokens.INK_2,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_text(years_col, "CONTRACT", UiTheme.inter(600), 13, UiTokens.INK_2,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var list := Rect2(rect.position.x, rect.position.y + 28.0, rect.size.x,
		rect.size.y - 28.0)
	var players := _centre_players()
	for index in range(players.size()):
		var player: Dictionary = players[index]
		var row := Rect2(list.position.x, list.position.y + 2.0
			+ _centre_row_offset(index) - centre_scroll, list.size.x, 44.0)
		if not _rect_intersects(row, list):
			continue
		var focused := _focus_id == "centre-row:%s" % str(player.get("id", ""))
		_draw_tile(row, focused)
		var cols := _finance_columns(row)
		var row_pos: Rect2 = cols["pos"]
		var row_photo: Rect2 = cols["photo"]
		var row_player: Rect2 = cols["player"]
		var row_age: Rect2 = cols["age"]
		var row_value: Rect2 = cols["value"]
		var row_wage: Rect2 = cols["wage"]
		var row_years: Rect2 = cols["years"]
		_draw_player_photo(row_photo, player)
		_draw_text(row_pos, str(player.get("role", "")), UiTheme.inter(600), 14,
			UiTokens.FOCUS_INK_2 if focused else _role_color(str(player.get("role", ""))),
			HORIZONTAL_ALIGNMENT_CENTER)
		_draw_text(row_player, _initial_name(player), UiTheme.barlow(700), 18,
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
		_draw_text(row_age, str(int(player.get("age", 0))), UiTheme.inter(500),
			15, UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2,
			HORIZONTAL_ALIGNMENT_CENTER)
		_draw_text(row_value, _format_value(int(player.get("market_value", 0))),
			UiTheme.inter(500), 15,
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2,
			HORIZONTAL_ALIGNMENT_RIGHT)
		var contract: Dictionary = player.get("contract", {})
		_draw_text(row_wage, _format_value(int(contract.get("weekly_wage", 0))),
			UiTheme.inter(500), 15,
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2,
			HORIZONTAL_ALIGNMENT_RIGHT)
		_draw_text(row_years, "%d Y" % int(contract.get("years", 1)),
			UiTheme.inter(500), 15,
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2,
			HORIZONTAL_ALIGNMENT_RIGHT)


func _finance_columns(rect: Rect2) -> Dictionary:
	var y := rect.position.y
	var h := rect.size.y
	var right := rect.end.x - 12.0
	var years := Rect2(right - 78.0, y, 78.0, h)
	var wage := Rect2(years.position.x - 8.0 - 100.0, y, 100.0, h)
	var value := Rect2(wage.position.x - 8.0 - 100.0, y, 100.0, h)
	var age := Rect2(value.position.x - 8.0 - 42.0, y, 42.0, h)
	var photo := Rect2(rect.position.x + 12.0, y + maxf(0.0, (h - 30.0) * 0.5),
		24.0, minf(30.0, h))
	var pos := Rect2(photo.end.x + 8.0, y, 40.0, h)
	var player := Rect2(pos.end.x + 8.0, y, age.position.x - 8.0
		- pos.end.x - 8.0, h)
	return {"pos": pos, "player": player, "age": age, "value": value,
		"wage": wage, "years": years, "photo": photo}


func _draw_centre_pane(rect: Rect2) -> void:
	draw_rect(rect, UiTokens.TILE, true)
	var player := _centre_current()
	if player.is_empty():
		return
	if centre_tab == 2:
		for pair in [[-1, "◀"], [1, "▶"]]:
			var id := "centre-attr:%d" % int(pair[0])
			var arrow := Rect2(rect.end.x - (94.0 if int(pair[0]) < 0 else 54.0),
				rect.position.y + 10.0, 30.0, 26.0)
			var focused := _focus_id == id
			draw_rect(arrow, UiTokens.FOCUS_FILL if focused else Color(UiTokens.INK, 0.06), true)
			_draw_text(arrow, str(pair[1]), UiTheme.barlow(700), 18,
				UiTokens.FOCUS_MARK if focused else UiTokens.INK_2,
				HORIZONTAL_ALIGNMENT_CENTER)
	var pad := 18.0
	var photo := Rect2(rect.position.x + pad, rect.position.y + 14.0, 64.0, 78.0)
	_draw_player_photo(photo, player)
	var info_x := photo.end.x + 16.0
	var info_w := rect.end.x - info_x - pad
	var eyebrow: String = ["PLAYER STATUS", "PLAYER STATISTICS", "PLAYER ATTRIBUTES",
		"PLAYER FINANCE"][centre_tab]
	_draw_text(Rect2(info_x, rect.position.y + 14.0, info_w, 18.0), eyebrow,
		UiTheme.inter(600), 13, UiTokens.INK_2)
	_draw_text(Rect2(info_x, rect.position.y + 30.0, info_w, 30.0),
		_initial_name(player), UiTheme.barlow(700), 24, UiTokens.INK)
	_draw_text(Rect2(info_x, rect.position.y + 60.0, info_w, 20.0),
		"%s · %s · %d OVR" % [str(player.get("position", "")),
			str(player.get("role", "")), int(round(float(player.get("overall", 0.0))))],
		UiTheme.inter(500), 15, UiTokens.INK_2)
	var y := rect.position.y + 102.0
	match centre_tab:
		0:
			y = _draw_morale_block(rect, y, player)
			y = _draw_pane_block(rect, y, "PERSONAL", [
				["AGE", str(int(player.get("age", 0)))],
				["CITIZENSHIP", _citizenship(player)],
				["HEIGHT", "%d CM" % int(player.get("height", 0))],
				["WEIGHT", "%d KG" % int(player.get("weight", 0))],
				["FOOT", str(player.get("foot", "—"))],
				["NUMBER", str(player.get("shirt_number", "—"))],
			])
			var contract: Dictionary = player.get("contract", {})
			y = _draw_pane_block(rect, y, "CONTRACT", [
				["ROLE", str(player.get("squad_role_label", ""))],
				["YEARS", "%d" % int(contract.get("years", 1))],
				["WAGE", _format_value(int(contract.get("weekly_wage", 0))) + " / WEEK"],
				["RELEASE CLAUSE", _format_value(int(contract.get("release_clause", 0)))],
			])
			_draw_pane_block(rect, y, "AVAILABILITY", _availability(player))
		1:
			var season: Dictionary = player.get("season_stats", {})
			var keeper := str(player.get("role", "")) == "GK"
			var metrics: Array = [
				["APPS", int(season.get("apps", 0))],
				["MINUTES", int(season.get("minutes", 0))],
			]
			if keeper:
				metrics.append(["CLEAN SHEETS", int(season.get("clean_sheets", 0))])
			else:
				metrics.append(["GOALS", int(season.get("goals", 0))])
				metrics.append(["ASSISTS", int(season.get("assists", 0))])
			_draw_total_grid(rect, y, metrics)
			y += 104.0
			_draw_text(Rect2(rect.position.x + pad, y, rect.size.x - pad * 2.0, 20.0),
				"BY COMPETITION", UiTheme.inter(600), 14, UiTokens.INK_2)
			draw_line(Vector2(rect.position.x + pad, y + 24.0),
				Vector2(rect.end.x - pad, y + 24.0), Color(UiTokens.INK, 0.12), 1.0)
			y += 34.0
			var competitions: Array = player.get("competition_stats", [])
			if competitions.is_empty():
				_draw_text(Rect2(rect.position.x + pad, y, rect.size.x - pad * 2.0, 24.0),
					"Statistics appear after the first matches.",
					UiTheme.inter(500), 15, UiTokens.INK_2)
			else:
				for competition in competitions:
					_draw_text(Rect2(rect.position.x + pad, y, rect.size.x - pad * 2.0,
						22.0), str(competition.get("name", "")), UiTheme.inter(600),
						15, UiTokens.INK)
					y += 26.0
		2:
			_draw_attribute_pane(rect, y, player)
		3:
			var contract: Dictionary = player.get("contract", {})
			y = _draw_pane_block(rect, y, "FINANCE", [
				["MARKET VALUE", _format_value(int(player.get("market_value", 0)))],
				["WAGE", _format_value(int(contract.get("weekly_wage", 0))) + " / WEEK"],
				["RELEASE CLAUSE", _format_value(int(contract.get("release_clause", 0)))],
			])
			y = _draw_pane_block(rect, y, "CONTRACT", [
				["YEARS", "%d" % int(contract.get("years", 1))],
				["ROLE", str(player.get("squad_role_label", ""))],
			])
			_draw_pane_block(rect, y, "STATUS", _availability(player))


func _draw_morale_block(rect: Rect2, y: float, player: Dictionary) -> float:
	var box := Rect2(rect.position.x + 18.0, y, rect.size.x - 36.0, 66.0)
	draw_rect(box, Color(UiTokens.INK, 0.05), true)
	_draw_text(Rect2(box.position.x + 12.0, box.position.y + 8.0, 180.0, 20.0),
		"MORALE", UiTheme.inter(600), 14, UiTokens.INK_2)
	var expected := int(player.get("expected_minutes", 0))
	var value := "%d%%" % int(player.get("morale", 100)) if expected > 0 else "—"
	_draw_text(Rect2(box.end.x - 112.0, box.position.y + 4.0, 100.0, 24.0),
		value, UiTheme.barlow(700), 22, UiTokens.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var meta := "Expected minutes appear after the first matches."
	if expected > 0:
		meta = "Actual %d · Planned %d min · %d%% expected" % [
			int(player.get("actual_minutes", 0)), expected,
			int(round(float(player.get("expected_share", 0.0)) * 100.0))]
	_draw_text(Rect2(box.position.x + 12.0, box.position.y + 32.0,
		box.size.x - 24.0, 26.0), meta, UiTheme.inter(500), 14, UiTokens.INK_2,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	return y + 76.0


func _draw_pane_block(rect: Rect2, y: float, title: String, rows: Array) -> float:
	var pad := 18.0
	_draw_text(Rect2(rect.position.x + pad, y, rect.size.x - pad * 2.0, 20.0),
		title, UiTheme.inter(600), 14, UiTokens.INK_2)
	draw_line(Vector2(rect.position.x + pad, y + 24.0),
		Vector2(rect.end.x - pad, y + 24.0), Color(UiTokens.INK, 0.12), 1.0)
	y += 28.0
	for row in rows:
		_draw_text(Rect2(rect.position.x + pad, y, rect.size.x * 0.52, 22.0),
			str(row[0]), UiTheme.inter(500), 14, UiTokens.INK_2)
		_draw_text(Rect2(rect.position.x + rect.size.x * 0.52, y,
			rect.size.x * 0.48 - pad, 22.0), str(row[1]), UiTheme.inter(600), 14,
			UiTokens.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 22.0
	return y + 4.0


func _draw_total_grid(rect: Rect2, y: float, metrics: Array) -> void:
	var card_w := (rect.size.x - 36.0 - GAP * (metrics.size() - 1)) / metrics.size()
	for index in range(metrics.size()):
		var card := Rect2(rect.position.x + 18.0 + index * (card_w + GAP), y,
			card_w, 88.0)
		draw_rect(card, Color(UiTokens.INK, 0.05), true)
		_draw_text(Rect2(card.position.x + 12.0, card.position.y + 8.0,
			card.size.x - 24.0, 34.0), str(metrics[index][1]),
			UiTheme.barlow(700), 30, UiTokens.INK)
		_draw_text(Rect2(card.position.x + 12.0, card.position.y + 48.0,
			card.size.x - 24.0, 22.0), str(metrics[index][0]),
			UiTheme.inter(600), 13, UiTokens.INK_2)


func _draw_attribute_pane(rect: Rect2, y: float, player: Dictionary) -> void:
	if centre_attribute_page == 0:
		var radar_rect := Rect2(rect.position.x + 18.0, y + 4.0, 170.0, 170.0)
		if str(player.get("role", "")) != "GK":
			_draw_radar(radar_rect, _radar(player), [])
		else:
			_draw_text(radar_rect, "GOALKEEPER PROFILE", UiTheme.inter(600), 13,
				UiTokens.INK_2, HORIZONTAL_ALIGNMENT_CENTER)
		var facts_x := radar_rect.end.x + 18.0
		var facts_w := rect.end.x - facts_x - 18.0
		var season: Dictionary = player.get("season_stats", {})
		_draw_text(Rect2(facts_x, y, facts_w, 20.0), "GENERAL",
			UiTheme.inter(600), 14, UiTokens.INK_2)
		draw_line(Vector2(facts_x, y + 24.0), Vector2(rect.end.x - 18.0, y + 24.0),
			Color(UiTokens.INK, 0.12), 1.0)
		var facts := [
			["AGE", str(int(player.get("age", 0)))],
			["SQUAD ROLE", str(player.get("squad_role_short", ""))],
			["MORALE", "%d%%" % int(player.get("morale", 100))
				if int(player.get("expected_minutes", 0)) > 0 else "—"],
			["POTENTIAL", str(int(round(float(player.get("pot", 0.0)))))],
			["VALUE", _format_value(int(player.get("market_value", 0)))],
			["APPS", str(int(season.get("apps", 0)))],
		]
		var fy := y + 31.0
		for fact in facts:
			_draw_text(Rect2(facts_x, fy, facts_w * 0.55, 22.0), str(fact[0]),
				UiTheme.inter(500), 14, UiTokens.INK_2)
			_draw_text(Rect2(facts_x + facts_w * 0.55, fy, facts_w * 0.45, 22.0),
				str(fact[1]), UiTheme.inter(600), 14, UiTokens.INK,
				HORIZONTAL_ALIGNMENT_RIGHT)
			fy += 24.0
		var axis_y := maxf(y + 190.0, fy + 8.0)
		_draw_text(Rect2(rect.position.x + 18.0, axis_y, rect.size.x - 36.0, 20.0),
			"RADAR", UiTheme.inter(600), 14, UiTokens.INK_2)
		axis_y += 26.0
		var values := _radar(player)
		var per_row := 3
		for index in range(values.size()):
			var col := index % per_row
			var row := int(index / per_row)
			var cell := Rect2(rect.position.x + 18.0 + col * ((rect.size.x - 36.0) / 3.0),
				axis_y + row * 24.0, (rect.size.x - 36.0) / 3.0 - 10.0, 20.0)
			_draw_text(cell, str(values[index].get("label", "")), UiTheme.inter(500),
				13, UiTokens.INK_2)
			_draw_text(Rect2(cell.end.x - 36.0, cell.position.y, 36.0, 20.0),
				str(values[index].get("value", 0)), UiTheme.barlow(700), 15,
				_stat_color(int(values[index].get("value", 0))),
				HORIZONTAL_ALIGNMENT_RIGHT)
		return
	var groups := CareerSquad.attribute_groups(player.get("stats", {}))
	var wanted: String = ATTRIBUTE_PAGES[centre_attribute_page].to_lower()
	var group: Dictionary = {}
	for item in groups:
		if str(item.get("id", "")) == wanted:
			group = item
			break
	if group.is_empty():
		return
	_draw_text(Rect2(rect.position.x + 18.0, y, rect.size.x - 36.0, 20.0),
		str(group.get("label", "")), UiTheme.inter(600), 14, UiTokens.INK_2)
	draw_line(Vector2(rect.position.x + 18.0, y + 24.0),
		Vector2(rect.end.x - 18.0, y + 24.0), Color(UiTokens.INK, 0.12), 1.0)
	var rows: Array = group.get("rows", [])
	var row_y := y + 31.0
	var col_w := (rect.size.x - 36.0) / 2.0
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var col := index % 2
		var row_index := int(index / 2)
		var cell := Rect2(rect.position.x + 18.0 + col * col_w,
			row_y + row_index * 26.0, col_w - 14.0, 24.0)
		_draw_text(cell, str(row.get("label", "")), UiTheme.inter(500), 14,
			UiTokens.INK_2)
		_draw_text(Rect2(cell.end.x - 40.0, cell.position.y, 40.0, 24.0),
			str(row.get("value", "")), UiTheme.barlow(700), 16,
			_stat_color(int(row.get("value", 0))), HORIZONTAL_ALIGNMENT_RIGHT)


func _centre_players() -> Array:
	return squad.get("players", [])


func _centre_current() -> Dictionary:
	var players := _centre_players()
	if players.is_empty():
		return {}
	return players[clampi(centre_player, 0, players.size() - 1)]


func _citizenship(player: Dictionary) -> String:
	var value = player.get("citizenship", [])
	if value is Array:
		return ", ".join(PackedStringArray(value)) if not value.is_empty() else "—"
	return str(value) if not str(value).is_empty() else "—"


func _availability(player: Dictionary) -> Array:
	var rows: Array = []
	if player.get("injury") != null:
		var injury: Dictionary = player.get("injury", {})
		rows.append(["INJURY", str(injury.get("type", "—"))])
		rows.append(["RETURN", str(injury.get("until", "—"))])
	elif player.get("suspension") != null:
		var suspension: Dictionary = player.get("suspension", {})
		rows.append(["SUSPENSION", "%d MATCHES" % int(suspension.get("matches", 0))])
	else:
		rows.append(["STATUS", "READY TO PLAY"])
	rows.append(["CONDITION", "%d%%" % int(player.get("fatigue", 100))])
	return rows


func _draw_plan() -> void:
	var m := _plan_metrics()
	var tabs: Array = m["tabs"]
	_draw_tab_marker()
	for item in tabs:
		_draw_plan_tab(item)
	draw_set_transform(Vector2(_slide, 0.0))
	_draw_crest(m["crest"])
	if view == View.DETAILS:
		_draw_details(m["details"])
		draw_set_transform(Vector2.ZERO)
		return
	match plan_tab:
		"schemes":
			_draw_scheme_view(m)
		"roles":
			_draw_roles_view(m)
		_:
			_draw_squad_view(m)
	draw_set_transform(Vector2.ZERO)


func _overview_metrics() -> Dictionary:
	var usable := size.x - GAP
	var left := usable / 1.72
	var right := usable - left
	var team := Rect2(0.0, 0.0, left, size.y)
	var right_x := left + GAP
	var tile_w := (right - GAP) * 0.5
	var tile_h := (size.y - GAP * 2.0) / 3.0
	var tiles: Array = []
	for index in range(6):
		var col := index % 2
		var row := int(index / 2)
		tiles.append(Rect2(right_x + col * (tile_w + GAP), row * (tile_h + GAP),
			tile_w, tile_h))
	return {"team": team, "tiles": tiles}


func _plan_metrics() -> Dictionary:
	var stage_w := (size.x - GAP) * 0.5
	var stage := Rect2(0.0, 0.0, stage_w, size.y)
	var crest := Rect2(stage_w + GAP, 0.0, stage_w, size.y)
	var tabs: Array = _plan_tab_rects(stage_w)
	if view == View.DETAILS:
		return {
			"stage": stage, "crest": crest, "tabs": tabs,
			"details": Rect2(0.0, TAB_H + GAP, stage_w, size.y - TAB_H - GAP),
		}
	match plan_tab:
		"schemes":
			var panel_h := 30.0 + 8.0 + SCHEME_CARD_H + 8.0
			var pitch_h := size.y - TAB_H - GAP - GAP - panel_h
			return {
				"stage": stage, "crest": crest, "tabs": tabs,
				"pitch": Rect2(0.0, TAB_H + GAP, stage_w, pitch_h),
				"schemes": Rect2(0.0, TAB_H + GAP + pitch_h + GAP, stage_w, panel_h),
			}
		"roles":
			var pitch_h := size.y - TAB_H - GAP - GAP - ROLE_H
			return {
				"stage": stage, "crest": crest, "tabs": tabs,
				"pitch": Rect2(0.0, TAB_H + GAP, stage_w, pitch_h),
				"roles": Rect2(0.0, TAB_H + GAP + pitch_h + GAP, stage_w, ROLE_H),
			}
		_:
			var content_h := size.y - BENCH_CLOSED
			var pitch_h := content_h - TAB_H - GAP - HEAD_H - GAP
			var drawer_h := BENCH_OPEN if bench_open else BENCH_CLOSED
			return {
				"stage": stage, "crest": crest, "tabs": tabs,
				"head": Rect2(0.0, TAB_H + GAP, stage_w, HEAD_H),
				"pitch": Rect2(0.0, TAB_H + GAP + HEAD_H + GAP, stage_w, pitch_h),
				"bench": Rect2(0.0, size.y - drawer_h, stage_w, drawer_h),
			}


func _plan_tab_rects(stage_w: float) -> Array:
	var items: Array = []
	var x := 0.0
	for item in PLAN_TABS:
		var width := _text_width(str(item["label"]), UiTheme.inter(600), 16) + 32.0
		if x + width > stage_w:
			width = maxf(60.0, stage_w - x)
		items.append({
			"id": item["id"], "label": item["label"],
			"disabled": item["disabled"],
			"rect": Rect2(x, 0.0, width, TAB_H),
		})
		x += width + 6.0
	return items


func _draw_squad_view(m: Dictionary) -> void:
	var pitch: Rect2 = m["pitch"]
	_draw_player_head(m["head"])
	_draw_pitch(pitch, _lineup_slots(), true, false, true,
		_team_strength(), _team_delta(), "", anchor_id)
	_draw_bench_drawer(m["bench"])


func _draw_scheme_view(m: Dictionary) -> void:
	var preview := _scheme_lineup()
	_draw_pitch(m["pitch"], preview.get("slots", []), false, true, false, 0,
		0.0, str(preview.get("formation_label", "")), "")
	_draw_scheme_panel(m["schemes"])


func _draw_roles_view(m: Dictionary) -> void:
	var picking := not role_picking.is_empty()
	_draw_pitch(m["pitch"], _lineup_slots(), picking, false, false, 0,
		0.0, "", _role_anchor_id())
	_draw_role_panel(m["roles"])


func _draw_crest(rect: Rect2) -> void:
	if _club_logo == null:
		return
	var box := minf(320.0, rect.size.x * 0.72)
	var texture_size := _club_logo.get_size()
	var scale := minf(box / maxf(1.0, texture_size.x), box / maxf(1.0, texture_size.y))
	var draw_size := texture_size * scale
	var pos := rect.get_center() - draw_size * 0.5
	draw_texture_rect(_club_logo, Rect2(pos, draw_size), false,
		Color(1.0, 1.0, 1.0, 0.24))


func _draw_team_tile(rect: Rect2) -> void:
	var focused := _focus_id == "team"
	_draw_tile(rect, focused)
	var club: Dictionary = {}
	if catalog != null:
		club = catalog.career_club(int(career.club_id))
	var pad_left := 28.0
	var pad_right := 22.0
	var pad_top := 20.0
	var crest_size := 56.0
	var head_y := rect.position.y + pad_top
	if _club_logo != null:
		var face := _fit_texture(_club_logo, Vector2(crest_size, crest_size))
		draw_texture_rect(_club_logo, Rect2(Vector2(rect.position.x + pad_left,
			head_y + (crest_size - face.y) * 0.5), face), false)
	var text_x := rect.position.x + pad_left + crest_size + 16.0
	var text_w := rect.size.x - (text_x - rect.position.x) - pad_right - 140.0
	var ink := UiTokens.INK
	var ink_2 := UiTokens.INK_2
	var mark := UiTokens.INK
	if focused:
		ink_2 = UiTokens.FOCUS_INK_2
		mark = UiTokens.FOCUS_MARK
	_draw_text(Rect2(text_x, head_y, text_w, 21.0), "CLUB SQUAD",
		UiTheme.inter(600), 16, ink_2)
	_draw_text(Rect2(text_x, head_y + 19.0, text_w, 40.0),
		"%s: DEFAULT" % str(club.get("name", "")), UiTheme.barlow(700), 34, mark)
	_draw_text(Rect2(text_x, head_y + 58.0, text_w, 20.0),
		"%s · %s" % [career.formation,
			str(club.get("league_name", ""))], UiTheme.inter(500), 16, ink_2)
	_draw_text(Rect2(rect.end.x - pad_right - 136.0, head_y, 136.0, 20.0),
		"A · GAME PLAN", UiTheme.inter(600), 16, ink_2,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var summary: Dictionary = squad.get("summary", {})
	var foot_y := rect.end.y - 16.0 - 21.0
	var average_age = summary.get("average_age")
	var age_text := "—" if average_age == null else str(average_age)
	_draw_text(Rect2(rect.position.x + pad_left, foot_y,
		rect.size.x * 0.55, 21.0),
		"%d players · average age %s" % [int(summary.get("squad_size", 0)), age_text],
		UiTheme.inter(500), 16, ink_2)
	_draw_text(Rect2(rect.position.x + rect.size.x * 0.55, foot_y,
		rect.size.x * 0.45 - pad_right, 21.0),
		_format_value(int(summary.get("total_market_value", 0))),
		UiTheme.inter(500), 16, ink_2, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_squad_tile(rect: Rect2, tile: Dictionary) -> void:
	var id := str(tile.get("id", ""))
	var selected: bool = tile.get("selected", false)
	var disabled: bool = tile.get("disabled", false)
	var focused := _focus_id == "tile:%s" % id
	var alpha := 0.42 if disabled else 1.0
	_draw_tile(rect, focused, alpha)
	var label_color := UiTokens.INK
	var note_color := UiTokens.INK_2
	var icon_color := UiTokens.INK_2
	if focused:
		label_color = UiTokens.FOCUS_MARK
		note_color = UiTokens.FOCUS_INK_2
		icon_color = UiTokens.FOCUS_INK_2
	label_color = Color(label_color, label_color.a * alpha)
	note_color = Color(note_color, note_color.a * alpha)
	icon_color = Color(icon_color, icon_color.a * alpha)
	_draw_text(Rect2(rect.position.x + 24.0, rect.position.y + 18.0,
		rect.size.x - 48.0, 30.0), str(tile.get("label", "")),
		UiTheme.barlow(700), 26, label_color)
	_draw_text(Rect2(rect.position.x + 24.0, rect.end.y - 16.0 - 42.0,
		rect.size.x - 48.0, 42.0), str(tile.get("note", "")),
		UiTheme.inter(500), 16, note_color, HORIZONTAL_ALIGNMENT_LEFT, true)
	if selected:
		if _club_logo != null:
			var logo_size := _fit_texture(_club_logo, Vector2(60.0, 60.0))
			draw_texture_rect(_club_logo, Rect2(Vector2(
				rect.end.x - 18.0 - logo_size.x, rect.position.y + 18.0 + 46.0), logo_size),
				false, Color(1.0, 1.0, 1.0, alpha))
		_draw_glyph(Rect2(rect.end.x - 58.0, rect.position.y + 18.0, 18.0, 18.0),
			"check", icon_color)
	else:
		var icon_rect := Rect2(rect.end.x - 18.0 - 44.0,
			rect.position.y + (rect.size.y - 44.0) * 0.5 - 10.0, 44.0, 44.0)
		_draw_glyph(icon_rect, str(tile.get("icon", "globe")), icon_color)


func _draw_plan_tab(item: Dictionary) -> void:
	var rect: Rect2 = item["rect"]
	var disabled: bool = item["disabled"]
	var active := str(item["id"]) == plan_tab
	var focused := _focus_id == "tab:%s" % str(item["id"])
	if focused:
		draw_rect(rect, UiTokens.FOCUS_FILL, true)
		draw_rect(Rect2(rect.position.x, rect.end.y - 4.0, rect.size.x, 4.0),
			UiTokens.FOCUS_MARK, true)
	var color := UiTokens.INK_2
	if active:
		color = UiTokens.INK
	if focused:
		color = UiTokens.FOCUS_MARK if active else UiTokens.FOCUS_INK
	if disabled:
		color = Color(color, 0.5)
	_draw_text(rect, str(item["label"]), UiTheme.inter(600), 16, color,
		HORIZONTAL_ALIGNMENT_CENTER)


func _draw_player_head(rect: Rect2) -> void:
	_draw_tile(rect, false)
	var focused_player := _focused_player()
	if focused_player.is_empty():
		return
	var anchor_player := _player_by_id(anchor_id)
	var comparing := not anchor_player.is_empty() \
		and str(anchor_player.get("id", "")) != str(focused_player.get("id", ""))
	var radar_rect := Rect2(rect.position.x + rect.size.x * 0.5 - 48.0,
		rect.position.y + 8.0, 96.0, 96.0)
	if comparing:
		var block_w := (rect.size.x - 96.0 - 48.0) * 0.5
		_draw_player_block(Rect2(rect.position.x + 14.0, rect.position.y, block_w,
			rect.size.y), anchor_player, false, true, focused_player)
		_draw_radar(radar_rect, _radar(anchor_player), _radar(focused_player))
		_draw_player_block(Rect2(rect.end.x - 14.0 - block_w, rect.position.y,
			block_w, rect.size.y), focused_player, true, true, anchor_player)
	else:
		var block_w := rect.size.x - 96.0 - 42.0
		_draw_player_block(Rect2(rect.position.x + 14.0, rect.position.y, block_w,
			rect.size.y), focused_player, false, false, {})
		if str(focused_player.get("role", "")) != "GK":
			_draw_radar(radar_rect, _radar(focused_player), [])
		else:
			_draw_text(Rect2(radar_rect.position.x - 10.0, radar_rect.position.y + 28.0,
				radar_rect.size.x + 20.0, 20.0),
				"GOALKEEPER", UiTheme.inter(600), 12, UiTokens.INK_2,
				HORIZONTAL_ALIGNMENT_CENTER)
			_draw_text(Rect2(radar_rect.position.x - 10.0, radar_rect.position.y + 46.0,
				radar_rect.size.x + 20.0, 20.0),
				"NO RADAR", UiTheme.inter(500), 12, UiTokens.INK_2,
				HORIZONTAL_ALIGNMENT_CENTER)


func _draw_player_block(rect: Rect2, player: Dictionary, mirrored: bool,
		comparing: bool, counterpart: Dictionary) -> void:
	var photo_w := 60.0
	var photo_h := 74.0
	var photo_x := rect.end.x - photo_w if mirrored else rect.position.x
	var info_x := rect.position.x if mirrored else rect.position.x + photo_w + 12.0
	var info_w := rect.size.x - photo_w - 12.0
	if mirrored:
		info_w = rect.size.x - photo_w - 12.0
	_draw_player_photo(Rect2(photo_x, rect.position.y + 8.0, photo_w, photo_h), player)
	_draw_fatigue(Rect2(photo_x, rect.position.y + 8.0 + photo_h + 4.0, photo_w, 3.0),
		int(player.get("fatigue", 100)))
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var name_y := rect.position.y + 6.0
	var name := _initial_name(player)
	if int(player.get("shirt_number", -1)) > 0:
		name = "%d  %s" % [int(player.get("shirt_number", 0)), name]
	_draw_text(Rect2(info_x, name_y, info_w, 26.0), name, UiTheme.barlow(700), 24,
		UiTokens.INK, align)
	var role := CareerSquad.current_role(_lineup(), player)
	var rating := CareerSquad.rating_at(player, role)
	var row_y := name_y + 30.0
	var line_text := "%s  %d" % [role, rating]
	if comparing and not counterpart.is_empty():
		var target_slot := CareerSquad.slot_for(_lineup(), str(counterpart.get("id", "")))
		if not target_slot.is_empty():
			var target_role := str(target_slot.get("role", role))
			var target_rating := CareerSquad.rating_at(player, target_role)
			var delta := target_rating - rating
			var arrow := "–"
			if delta > 0:
				arrow = "▲"
			elif delta < 0:
				arrow = "▼"
			line_text = "%s  ›  %s %d %s" % [line_text, target_role, target_rating, arrow]
	_draw_text(Rect2(info_x, row_y, info_w, 24.0), line_text, UiTheme.barlow(700), 20,
		_rating_color(rating), align)
	var season: Dictionary = player.get("season_stats", {})
	_draw_text(Rect2(info_x, row_y + 30.0, info_w, 20.0),
		"%d APP · %d G · %d A · %d MIN" % [int(season.get("apps", 0)),
			int(season.get("goals", 0)), int(season.get("assists", 0)),
			int(season.get("minutes", 0))],
		UiTheme.inter(500), 15, UiTokens.INK_2, align)


func _draw_pitch(rect: Rect2, slots: Array, interactive: bool, preview: bool,
		show_strength: bool, strength: int, delta: float, corner := "",
		anchor := "") -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, PITCH_DARK, true)
	var top := Vector2(rect.position.x + rect.size.x * 0.13, rect.position.y + rect.size.y * 0.02)
	var top_r := Vector2(rect.position.x + rect.size.x * 0.87, rect.position.y + rect.size.y * 0.02)
	var bot_r := Vector2(rect.position.x + rect.size.x * 0.98, rect.position.y + rect.size.y * 0.98)
	var bot := Vector2(rect.position.x + rect.size.x * 0.02, rect.position.y + rect.size.y * 0.98)
	draw_colored_polygon(PackedVector2Array([top, top_r, bot_r, bot]), PITCH_MID)
	var stripe_color := Color(1.0, 1.0, 1.0, 0.03)
	for index in range(1, 13):
		var x := rect.position.x + rect.size.x * (0.13 + index * 0.06)
		if x < rect.position.x + rect.size.x * 0.87:
			draw_line(Vector2(x, rect.position.y + rect.size.y * 0.02),
				Vector2(x, rect.position.y + rect.size.y * 0.98), stripe_color, 1.0)
	for index in range(1, 10):
		var y := rect.position.y + rect.size.y * (0.02 + index * 0.096)
		var t := (y - rect.position.y) / rect.size.y
		var left_x := rect.position.x + rect.size.x * lerpf(0.13, 0.02, t)
		var right_x := rect.position.x + rect.size.x * lerpf(0.87, 0.98, t)
		draw_line(Vector2(left_x, y), Vector2(right_x, y), Color(0, 0, 0, 0.05), 1.0)
	var line_w := maxf(1.0, rect.size.x * 0.0035)
	var lines := [
		[top, top_r, bot_r, bot, top],
		[Vector2(rect.position.x + rect.size.x * 0.07, rect.position.y + rect.size.y * 0.5),
			Vector2(rect.position.x + rect.size.x * 0.93, rect.position.y + rect.size.y * 0.5)],
		[Vector2(rect.position.x + rect.size.x * 0.33, rect.position.y + rect.size.y * 0.02),
			Vector2(rect.position.x + rect.size.x * 0.67, rect.position.y + rect.size.y * 0.02),
			Vector2(rect.position.x + rect.size.x * 0.70, rect.position.y + rect.size.y * 0.18),
			Vector2(rect.position.x + rect.size.x * 0.30, rect.position.y + rect.size.y * 0.18),
			Vector2(rect.position.x + rect.size.x * 0.33, rect.position.y + rect.size.y * 0.02)],
		[Vector2(rect.position.x + rect.size.x * 0.25, rect.position.y + rect.size.y * 0.98),
			Vector2(rect.position.x + rect.size.x * 0.75, rect.position.y + rect.size.y * 0.98),
			Vector2(rect.position.x + rect.size.x * 0.70, rect.position.y + rect.size.y * 0.80),
			Vector2(rect.position.x + rect.size.x * 0.30, rect.position.y + rect.size.y * 0.80),
			Vector2(rect.position.x + rect.size.x * 0.25, rect.position.y + rect.size.y * 0.98)],
	]
	for poly in lines:
		var closed: Array = poly.duplicate()
		if poly.size() > 2 and poly[0] != poly[poly.size() - 1]:
			closed.append(poly[0])
		draw_polyline(PackedVector2Array(closed), PITCH_LINE, line_w, true)
	_draw_ellipse(rect.get_center(), rect.size.x * 0.12, rect.size.y * 0.16, PITCH_LINE, line_w)
	var card_w := clampf(rect.size.x * 0.095, 48.0, 80.0)
	var card_h := 72.0 if not preview else 80.0
	if not preview and not interactive:
		card_h = 72.0
	for slot in slots:
		var player: Dictionary = slot.get("player", {})
		if player.is_empty():
			continue
		var card_rect := _card_rect(rect, slot, card_w, card_h)
		var is_focused := interactive and _focus_id == "card:%s" % str(player.get("id", ""))
		var is_anchor := not anchor.is_empty() and str(player.get("id", "")) == anchor
		_draw_pitch_card(card_rect, player, str(slot.get("role", "")), interactive,
			preview, is_focused, is_anchor)
	if not corner.is_empty():
		var tag_w := _text_width(corner, UiTheme.barlow(700), 26) + 20.0
		var tag_rect := Rect2(rect.end.x - 10.0 - tag_w, rect.position.y + 8.0,
			tag_w, 32.0)
		draw_rect(tag_rect, Color(8.0 / 255.0, 20.0 / 255.0, 15.0 / 255.0, 0.72), true)
		_draw_text(tag_rect, corner, UiTheme.barlow(700), 26, UiTokens.FOCUS_INK,
			HORIZONTAL_ALIGNMENT_CENTER)
	if show_strength:
		_draw_strength(Rect2(rect.end.x - 12.0 - 84.0, rect.position.y + 12.0, 84.0,
			44.0), strength, delta)


func _card_rect(pitch: Rect2, slot: Dictionary, card_w: float, card_h: float) -> Rect2:
	var cx := pitch.position.x + pitch.size.x * float(slot.get("x", 50)) / 100.0
	var cy := pitch.position.y + pitch.size.y * float(slot.get("y", 50)) / 100.0
	if str(slot.get("position", "")) == "GK":
		cy = minf(cy, pitch.end.y - 40.0)
	return Rect2(cx - card_w * 0.5, cy - card_h * 0.5, card_w, card_h)


func _draw_pitch_card(rect: Rect2, player: Dictionary, role: String,
		interactive: bool, preview: bool, focused: bool, anchor: bool) -> void:
	var available: bool = player.get("available", true)
	var alpha := 1.0 if available else 0.55
	if focused:
		draw_rect(Rect2(rect.position.x, rect.position.y - 2.0, rect.size.x,
			rect.size.y + 6.0), Color(0.015, 0.035, 0.078, 0.4), true)
		draw_rect(rect, UiTokens.FOCUS_FILL, true)
	var photo_h := 36.0 if preview and not interactive else 30.0
	var photo := Rect2(rect.position.x + 4.0, rect.position.y + 2.0,
		rect.size.x - 8.0, photo_h)
	_draw_shirt(photo, alpha)
	var plate_h := 14.0
	var plate_w := minf(rect.size.x - 8.0, 40.0)
	var plate := Rect2(rect.position.x + (rect.size.x - plate_w) * 0.5,
		photo.end.y, plate_w, plate_h)
	draw_rect(plate, Color(8.0 / 255.0, 20.0 / 255.0, 15.0 / 255.0, 0.72), true)
	var plate_text := "%s %d" % [_short_role(role), int(round(float(player.get("overall", 0.0))))]
	_draw_text(plate, plate_text, UiTheme.barlow(700), 11,
		Color(UiTokens.FOCUS_INK, alpha), HORIZONTAL_ALIGNMENT_CENTER)
	var name_rect := Rect2(rect.position.x + 2.0, plate.end.y + 1.0,
		rect.size.x - 4.0, 16.0)
	var name_color := UiTokens.FOCUS_MARK if focused else UiTokens.FOCUS_INK
	_draw_text(name_rect, _player_name(player),
		UiTheme.barlow(700), 13 if preview else 12, Color(name_color, alpha),
		HORIZONTAL_ALIGNMENT_CENTER)
	var bar := Rect2(rect.position.x + 4.0, rect.end.y - 4.0, rect.size.x - 8.0, 2.0)
	draw_rect(bar, Color(UiTokens.FOCUS_INK, 0.28), true)
	var fatigue := clampf(float(player.get("fatigue", 100)), 0.0, 100.0)
	var fill := MARK_WIN if fatigue >= 50.0 else MARK_LOSS
	draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x * fatigue / 100.0,
		bar.size.y), Color(fill, alpha), true)
	if player.get("injury") != null:
		_draw_status_flag(Rect2(photo.end.x - 16.0, photo.position.y, 16.0, 16.0), alpha)
	if anchor:
		draw_rect(rect, UiTokens.RAIL, false, 2.0)


func _draw_bench_drawer(rect: Rect2) -> void:
	var expanded := bench_open
	draw_rect(rect, BENCH_BG, true)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 2.0),
		Color(UiTokens.INK, 0.12), true)
	var players := _bench_players()
	var inner := Rect2(rect.position.x + 10.0, rect.position.y + 10.0,
		rect.size.x - 20.0, rect.size.y - 20.0)
	var bench_count: int = squad.get("lineup", {}).get("bench", []).size()
	var grid_top := _bench_players_top(rect, expanded)
	var card_w := (inner.size.x - 8.0 * 3.0) / 4.0
	var card_h := 92.0
	for index in range(players.size()):
		var player: Dictionary = players[index]
		var is_bench := index < bench_count
		var row := index / 4
		var col := index % 4
		var extra := 0.0
		if not is_bench:
			extra = 22.0 if expanded else 0.0
		var card_rect := Rect2(inner.position.x + col * (card_w + 8.0),
			grid_top + extra + row * (card_h + 8.0) - bench_scroll, card_w, card_h)
		if not _rect_intersects(card_rect, inner):
			continue
		_draw_bench_card(card_rect, player, _focus_id == "bench:%s" % str(player.get("id", "")))
	if expanded:
		var y := rect.position.y + 10.0 - bench_scroll
		_draw_text(Rect2(inner.position.x + 2.0, y, inner.size.x, 18.0),
			"BENCH · %d" % bench_count, UiTheme.inter(600), 13, UiTokens.INK_2)
		var reserve_count := players.size() - bench_count
		if reserve_count > 0:
			var reserve_y := grid_top + int(ceil(float(bench_count) / 4.0)) * (card_h + 8.0) \
				- bench_scroll
			_draw_text(Rect2(inner.position.x + 2.0, reserve_y, inner.size.x, 18.0),
				"RESERVE · %d" % reserve_count, UiTheme.inter(600), 13, UiTokens.INK_2)


func _bench_players() -> Array:
	var result: Array = []
	var lineup: Dictionary = squad.get("lineup", {})
	result.append_array(lineup.get("bench", []))
	result.append_array(lineup.get("reserve", []))
	return result


func _bench_players_top(rect: Rect2, expanded: bool) -> float:
	var base := rect.position.y + 10.0
	if expanded:
		base += 22.0
	return base


func _draw_bench_card(rect: Rect2, player: Dictionary, focused: bool) -> void:
	var available: bool = player.get("available", true)
	if focused:
		draw_rect(rect, UiTokens.FOCUS_FILL, true)
	else:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.58), true)
	var alpha := 1.0 if available else 0.55
	var photo_h := 44.0
	var photo := Rect2(rect.position.x + rect.size.x * 0.30, rect.position.y + 6.0,
		rect.size.x * 0.40, photo_h)
	_draw_shirt(photo, alpha)
	var role_color := _role_color(_slot_role_for_player(player))
	var role_text_color := role_color if not focused else UiTokens.FOCUS_INK_2
	_draw_text(Rect2(rect.position.x + 6.0, rect.position.y + 8.0,
		rect.size.x * 0.30 - 8.0, 18.0), _short_role(_slot_role_for_player(player)),
		UiTheme.inter(600), 14, Color(role_text_color, alpha))
	_draw_text(Rect2(rect.end.x - rect.size.x * 0.26, rect.position.y + 8.0,
		rect.size.x * 0.26 - 8.0, 22.0),
		str(int(round(float(player.get("overall", 0.0))))),
		UiTheme.barlow(700), 22,
		Color(UiTokens.FOCUS_INK if focused else UiTokens.INK, alpha),
		HORIZONTAL_ALIGNMENT_RIGHT)
	var name_color := UiTokens.FOCUS_MARK if focused else UiTokens.INK
	_draw_text(Rect2(rect.position.x + 8.0, rect.position.y + 54.0,
		rect.size.x - 16.0, 18.0), _player_name(player),
		UiTheme.barlow(700), 16, Color(name_color, alpha), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_fatigue(Rect2(rect.position.x + 8.0, rect.end.y - 8.0, rect.size.x - 16.0, 3.0),
		int(player.get("fatigue", 100)))
	if player.get("injury") != null:
		_draw_status_flag(Rect2(photo.end.x - 16.0, photo.position.y, 16.0, 16.0), alpha)


func _draw_role_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(UiTokens.INK, 0.16), true)
	var tile_w := rect.size.x / 4.0
	var tile_h := rect.size.y / 2.0
	var roles: Array = CareerRoles.ROLE_IDS
	for index in range(roles.size()):
		var role := str(roles[index])
		var role_rect: Rect2
		if role == "captain":
			role_rect = Rect2(rect.position.x, rect.position.y, tile_w, rect.size.y)
		else:
			var slot_index := index - 1
			var col := 1 + (slot_index % 3)
			var row := int(slot_index / 3)
			role_rect = Rect2(rect.position.x + col * tile_w + (1.0 if col > 0 else 0.0),
				rect.position.y + row * tile_h + (1.0 if row > 0 else 0.0),
				tile_w - 1.0, tile_h - 1.0)
		var focused := _focus_id == "role:%s" % role
		var picking := role_picking == role
		if picking:
			draw_rect(role_rect, UiTokens.FOCUS_FILL, true)
			draw_rect(role_rect, UiTokens.FOCUS_MARK, false, 2.0)
		elif focused:
			draw_rect(role_rect, UiTokens.FOCUS_FILL, true)
		else:
			draw_rect(role_rect, UiTokens.TILE, true)
		var name_color := UiTokens.FOCUS_MARK if (focused or picking) else UiTokens.INK
		var icon_color := UiTokens.FOCUS_INK if (focused or picking) else UiTokens.INK_2
		var player_color := UiTokens.FOCUS_MARK if picking \
			else (UiTokens.FOCUS_INK if focused else UiTokens.INK)
		_draw_text(Rect2(role_rect.position.x + 8.0, role_rect.position.y + 7.0,
			role_rect.size.x - 16.0, 34.0), str(CareerRoles.LABELS.get(role, role)),
			UiTheme.barlow(700), 15, name_color, HORIZONTAL_ALIGNMENT_CENTER, true)
		var icon_rect := Rect2(role_rect.position.x + role_rect.size.x * 0.22,
			role_rect.position.y + 42.0, role_rect.size.x * 0.56,
			role_rect.size.y - 78.0)
		_draw_role_glyph(icon_rect, role, icon_color)
		var player := _role_player(role)
		var label := _player_name(player) if not player.is_empty() else "—"
		_draw_text(Rect2(role_rect.position.x + 6.0, role_rect.end.y - 27.0,
			role_rect.size.x - 12.0, 21.0), label, UiTheme.barlow(700), 16,
			player_color, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_scheme_panel(rect: Rect2) -> void:
	draw_rect(rect, UiTokens.TILE, true)
	var header := Rect2(rect.position.x, rect.position.y, rect.size.x, 30.0)
	draw_rect(header, Color(UiTokens.INK, 0.06), true)
	var club_name := ""
	if catalog != null:
		club_name = str(catalog.career_club(int(career.club_id)).get("name", ""))
	_draw_text(Rect2(header.position.x + 12.0, header.position.y, header.size.x * 0.75,
		header.size.y), "FORMATIONS: %s" % club_name, UiTheme.inter(600), 13,
		UiTokens.INK_2)
	var page_count := maxi(1, int(ceil(float(CareerFormations.ORDER.size()) / 3.0)))
	_draw_text(Rect2(header.end.x - 72.0, header.position.y, 60.0, header.size.y),
		"%d / %d" % [formation_page + 1, page_count], UiTheme.inter(600), 13,
		UiTokens.INK_2, HORIZONTAL_ALIGNMENT_RIGHT)
	var viewport := Rect2(rect.position.x + 8.0, header.end.y + 8.0,
		rect.size.x - 8.0 - 18.0, SCHEME_CARD_H)
	var card_w := (viewport.size.x - 16.0) / 3.0
	var visible := _visible_formations()
	for index in range(visible.size()):
		var formation: Dictionary = visible[index]
		var card := Rect2(viewport.position.x + index * (card_w + 8.0), viewport.position.y,
			card_w, SCHEME_CARD_H)
		_draw_scheme_card(card, formation)
	var rail_x := rect.end.x - 7.0
	draw_rect(Rect2(rail_x, viewport.position.y, 3.0, SCHEME_CARD_H),
		Color(UiTokens.INK, 0.14), true)
	var thumb_h := SCHEME_CARD_H / float(page_count)
	draw_rect(Rect2(rail_x, viewport.position.y + thumb_h * formation_page, 3.0,
		thumb_h), Color(UiTokens.INK_2, 0.5), true)


func _draw_scheme_card(rect: Rect2, formation: Dictionary) -> void:
	var id := str(formation.get("id", ""))
	var focused := _focus_id == "scheme:%s" % id
	var selected := id == career.formation
	if focused:
		draw_rect(rect, UiTokens.FOCUS_FILL, true)
	else:
		draw_rect(rect, SCHEME_BG, true)
	var name_color := UiTokens.FOCUS_MARK if focused else UiTokens.INK
	_draw_text(Rect2(rect.position.x + 8.0, rect.position.y + 6.0,
		rect.size.x - 16.0, 24.0), str(formation.get("label", id)),
		UiTheme.barlow(700), 22, name_color, HORIZONTAL_ALIGNMENT_LEFT, true)
	var mini := Rect2(rect.position.x + 8.0, rect.position.y + 34.0,
		rect.size.x - 16.0, rect.size.y - 42.0)
	draw_rect(mini, PITCH_DARK, true)
	var surface := PackedVector2Array([
		Vector2(mini.position.x + mini.size.x * 0.08, mini.position.y),
		Vector2(mini.position.x + mini.size.x * 0.92, mini.position.y),
		Vector2(mini.end.x, mini.end.y),
		Vector2(mini.position.x, mini.end.y),
	])
	draw_colored_polygon(surface, PITCH_MID)
	draw_polyline(PackedVector2Array([surface[0], surface[1], surface[2], surface[3],
		surface[0]]), Color(1, 1, 1, 0.30), 1.0, true)
	if selected:
		_draw_text(Rect2(rect.position.x + 6.0, rect.end.y - 22.0, 20.0, 18.0), "✓",
			UiTheme.barlow(700), 16, UiTokens.FOCUS_MARK)
	for slot in formation.get("slots", []):
		var dot := Vector2(mini.position.x + mini.size.x * float(slot.get("x", 50)) / 100.0,
			mini.position.y + mini.size.y * float(slot.get("y", 50)) / 100.0)
		var color := Color("ff4d6d") if str(slot.get("position", "")) == "GK" \
			else Color("f4f7fb")
		draw_circle(dot, 3.0, color)


func _draw_details(rect: Rect2) -> void:
	draw_rect(rect, UiTokens.TILE, true)
	if _focus_id == "details":
		draw_rect(Rect2(rect.position.x, rect.position.y, 2.0, rect.size.y),
			UiTokens.RAIL, true)
	var pad := 22.0
	_draw_text(Rect2(rect.position.x + pad, rect.position.y + 16.0,
		rect.size.x - pad * 2.0, 30.0), DETAIL_PAGES[details_page],
		UiTheme.barlow(700), 26, UiTokens.INK)
	var player := _focused_player()
	if player.is_empty():
		return
	var y := rect.position.y + 58.0
	match details_page:
		0:
			_draw_attributes_page(rect, y, player)
		1:
			_draw_status_page(rect, y, player)
		2:
			_draw_statistics_page(rect, y, player)
		_:
			_draw_finance_page(rect, y, player)
	var dots_w := DETAIL_PAGES.size() * 14.0
	var dots_x := rect.position.x + (rect.size.x - dots_w) * 0.5
	var dots_y := rect.end.y - 26.0
	for index in range(DETAIL_PAGES.size()):
		draw_rect(Rect2(dots_x + index * 14.0, dots_y, 8.0, 8.0),
			UiTokens.INK if index == details_page else Color(UiTokens.INK, 0.2), true)


# Ported from the game's GamePlanDetails: radar on the left, general facts on
# the right, then the three attribute groups in columns.
func _draw_attributes_page(rect: Rect2, y: float, player: Dictionary) -> void:
	var pad := 22.0
	var radar_rect := Rect2(rect.position.x + pad, y + 4.0, 190.0, 190.0)
	if str(player.get("role", "")) == "GK":
		_draw_text(radar_rect, "GOALKEEPER PROFILE", UiTheme.inter(600), 13,
			UiTokens.INK_2, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_draw_radar(radar_rect, _radar(player), [])
	var facts := Rect2(radar_rect.end.x + 18.0, rect.position.y,
		rect.end.x - radar_rect.end.x - 18.0 - pad, rect.size.y)
	_draw_pane_block(facts, y, "GENERAL", _general_rows(player))
	var groups := CareerSquad.attribute_groups(player.get("stats", {}))
	var top := y + 210.0
	var col_w := (rect.size.x - pad * 2.0) / 3.0
	for index in range(groups.size()):
		var group: Dictionary = groups[index]
		var x := rect.position.x + pad + index * col_w
		_draw_text(Rect2(x, top, col_w - 18.0, 20.0), str(group.get("label", "")),
			UiTheme.inter(600), 14, UiTokens.INK_2)
		draw_line(Vector2(x, top + 24.0), Vector2(x + col_w - 22.0, top + 24.0),
			Color(UiTokens.INK, 0.12), 1.0)
		var row_y := top + 30.0
		for row in group.get("rows", []):
			_draw_text(Rect2(x, row_y, col_w - 64.0, 20.0),
				str(row.get("label", "")), UiTheme.inter(500), 13, UiTokens.INK_2)
			_draw_text(Rect2(x + col_w - 60.0, row_y, 38.0, 20.0),
				str(row.get("value", "")), UiTheme.barlow(700), 15,
				_stat_color(int(row.get("value", 0))), HORIZONTAL_ALIGNMENT_RIGHT)
			row_y += 21.0


func _draw_status_page(rect: Rect2, y: float, player: Dictionary) -> void:
	var pad := 22.0
	var half := (rect.size.x - pad * 2.0 - 24.0) * 0.5
	var left := Rect2(rect.position.x + pad, rect.position.y, half, rect.size.y)
	var right := Rect2(left.end.x + 24.0, rect.position.y, half, rect.size.y)
	var rows := _availability(player)
	rows.append(["FATIGUE", "%d%%" % int(player.get("fatigue", 100))])
	_draw_pane_block(left, y, "AVAILABILITY", rows)
	var contract: Dictionary = player.get("contract", {})
	var expected := int(player.get("expected_minutes", 0))
	_draw_pane_block(right, y, "SQUAD ROLE", [
		["ROLE", str(player.get("squad_role_label", ""))],
		["MORALE", "%d%%" % int(player.get("morale", 100)) if expected > 0 else "—"],
		["EXPECTED", "%d MIN" % expected if expected > 0 else "AFTER FIRST MATCH"],
		["PLAYED", "%d MIN" % int(player.get("actual_minutes", 0))],
		["CONTRACT", "%d Y" % int(contract.get("years", 1))],
	])


func _draw_statistics_page(rect: Rect2, y: float, player: Dictionary) -> void:
	var pad := 22.0
	_draw_info_rows(rect, y, _season_rows(player))
	var list_y := y + _season_rows(player).size() * 28.0 + 14.0
	_draw_text(Rect2(rect.position.x + pad, list_y, rect.size.x - pad * 2.0, 20.0),
		"BY COMPETITION", UiTheme.inter(600), 14, UiTokens.INK_2)
	draw_line(Vector2(rect.position.x + pad, list_y + 24.0),
		Vector2(rect.end.x - pad, list_y + 24.0), Color(UiTokens.INK, 0.12), 1.0)
	var row_y := list_y + 32.0
	var competitions: Array = player.get("competition_stats", [])
	if competitions.is_empty():
		_draw_text(Rect2(rect.position.x + pad, row_y, rect.size.x - pad * 2.0, 22.0),
			"Statistics appear after the first matches.", UiTheme.inter(500), 15,
			UiTokens.INK_2)
		return
	for competition in competitions:
		_draw_text(Rect2(rect.position.x + pad, row_y, rect.size.x * 0.6, 22.0),
			str(competition.get("name", "")), UiTheme.inter(600), 15, UiTokens.INK)
		_draw_text(Rect2(rect.end.x - pad - 220.0, row_y, 220.0, 22.0),
			"%d APP · %d G · %d A" % [int(competition.get("apps", 0)),
				int(competition.get("goals", 0)), int(competition.get("assists", 0))],
			UiTheme.inter(500), 14, UiTokens.INK_2, HORIZONTAL_ALIGNMENT_RIGHT)
		row_y += 26.0


func _draw_finance_page(rect: Rect2, y: float, player: Dictionary) -> void:
	var pad := 22.0
	var half := (rect.size.x - pad * 2.0 - 24.0) * 0.5
	var left := Rect2(rect.position.x + pad, rect.position.y, half, rect.size.y)
	var right := Rect2(left.end.x + 24.0, rect.position.y, half, rect.size.y)
	var contract: Dictionary = player.get("contract", {})
	_draw_pane_block(left, y, "FINANCE", [
		["MARKET VALUE", _format_value(int(player.get("market_value", 0)))],
		["WAGE", _format_value(int(contract.get("weekly_wage", 0))) + " / WEEK"],
		["RELEASE CLAUSE", _format_value(int(contract.get("release_clause", 0)))],
	])
	_draw_pane_block(right, y, "CONTRACT", [
		["YEARS", "%d" % int(contract.get("years", 1))],
		["SQUAD ROLE", str(player.get("squad_role_label", ""))],
		["VALUE", _format_value(int(player.get("market_value", 0)))],
	])


func _draw_info_rows(rect: Rect2, start_y: float, rows: Array) -> float:
	var pad := 22.0
	var y := start_y
	for row in rows:
		var row_rect := Rect2(rect.position.x + pad, y, rect.size.x - pad * 2.0, 28.0)
		_draw_text(row_rect, str(row.get("left", "")), UiTheme.inter(600), 16,
			UiTokens.INK)
		_draw_text(Rect2(row_rect.position.x + row_rect.size.x * 0.35,
			row_rect.position.y, row_rect.size.x * 0.30, row_rect.size.y),
			str(row.get("label", "")), UiTheme.inter(500), 15, UiTokens.INK_2,
			HORIZONTAL_ALIGNMENT_CENTER)
		y += 28.0
	return y


func _draw_radar(rect: Rect2, values: Array, secondary: Array) -> void:
	if values.is_empty():
		return
	var center := rect.get_center()
	var radius := rect.size.x * 0.31
	var outer: Array = []
	var inner: Array = []
	for index in range(values.size()):
		var angle := TAU * float(index) / float(values.size()) - PI * 0.5
		outer.append(center + Vector2(cos(angle), sin(angle)) * radius)
		inner.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.5)
	draw_polyline(_closed(outer), Color(UiTokens.INK, 0.20), 1.0, true)
	draw_polyline(_closed(inner), Color(UiTokens.INK, 0.10), 1.0, true)
	if not secondary.is_empty():
		var secondary_points: Array = []
		for index in range(secondary.size()):
			var angle := TAU * float(index) / float(secondary.size()) - PI * 0.5
			var reach := float(secondary[index].get("value", 0)) / 100.0 * radius
			secondary_points.append(center + Vector2(cos(angle), sin(angle)) * reach)
		draw_polyline(_closed(secondary_points), Color(UiTokens.INK_2, 0.9), 1.0, true)
	var points: Array = []
	for index in range(values.size()):
		var angle := TAU * float(index) / float(values.size()) - PI * 0.5
		var reach := float(values[index].get("value", 0)) / 100.0 * radius
		points.append(center + Vector2(cos(angle), sin(angle)) * reach)
	if points.size() >= 3:
		draw_colored_polygon(PackedVector2Array(points), Color(UiTokens.INK, 0.07))
	draw_polyline(_closed(points), UiTokens.RAIL, 1.6, true)
	var label_size := 12 if rect.size.x > 140.0 else 10
	var label_w := 84.0 if rect.size.x > 140.0 else 56.0
	for index in range(values.size()):
		var angle := TAU * float(index) / float(values.size()) - PI * 0.5
		var pos := center + Vector2(cos(angle), sin(angle)) * radius * 1.28
		var label_rect := Rect2(pos.x - label_w * 0.5, pos.y - 9.0, label_w, 18.0)
		_draw_text(label_rect, str(values[index].get("label", "")),
			UiTheme.inter(600), label_size, UiTokens.INK_2,
			HORIZONTAL_ALIGNMENT_CENTER)


func _draw_strength(rect: Rect2, display: int, delta: float) -> void:
	draw_rect(rect, UiTokens.TILE, true)
	var shield := Rect2(rect.position.x + 10.0, rect.position.y + 8.0, 24.0, 28.0)
	var shield_points := PackedVector2Array([
		shield.position + Vector2(shield.size.x * 0.5, 0),
		shield.position + Vector2(shield.size.x, shield.size.y * 0.18),
		shield.position + Vector2(shield.size.x, shield.size.y * 0.48),
		shield.position + Vector2(shield.size.x * 0.5, shield.size.y),
		shield.position + Vector2(0, shield.size.y * 0.48),
		shield.position + Vector2(0, shield.size.y * 0.18),
		shield.position + Vector2(shield.size.x * 0.5, 0),
	])
	draw_polyline(shield_points, UiTokens.INK_2, 2.0, true)
	_draw_text(Rect2(rect.position.x + 38.0, rect.position.y, 28.0, rect.size.y),
		str(display), UiTheme.barlow(700), 28, UiTokens.INK)
	if absf(delta) > 0.05:
		_draw_text(Rect2(rect.end.x - 18.0, rect.position.y, 14.0, rect.size.y),
			"▲" if delta > 0.0 else "▼", UiTheme.inter(700), 14,
			MARK_WIN if delta > 0.0 else MARK_LOSS)


func _draw_role_glyph(rect: Rect2, role: String, color: Color) -> void:
	var scale := minf(rect.size.x / 64.0, rect.size.y / 40.0)
	if scale <= 0.0:
		return
	var origin := rect.get_center() - Vector2(32.0, 20.0) * scale
	if role == "captain":
		var box := minf(rect.size.x, rect.size.y) * 0.72
		var box_rect := Rect2(rect.get_center() - Vector2(box, box) * 0.5, Vector2(box, box))
		draw_rect(box_rect, color, false, 2.0)
		_draw_text(box_rect, "C", UiTheme.barlow(800), int(box * 0.66), color,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	var mirrored := role in ["free_kick_right", "corner_right"]
	var scale_x := -1.0 if mirrored else 1.0
	var p := func(x: float, y: float) -> Vector2:
		return origin + Vector2(x * scale_x, y) * scale
	var line := maxf(1.5, 2.0 * scale)
	if role == "penalties":
		draw_rect(Rect2(p.call(16, 7), Vector2(32, 13) * scale), color, false, line)
		draw_line(p.call(16, 7), p.call(16, 5), color, line)
		draw_line(p.call(48, 7), p.call(48, 5), color, line)
		draw_line(p.call(32, 31), p.call(32, 25), color, line)
		draw_line(p.call(28.5, 27.5), p.call(32, 24), color, line)
		draw_line(p.call(32, 24), p.call(35.5, 27.5), color, line)
		draw_circle(p.call(32, 34), 2.6 * scale, color)
		draw_line(p.call(14, 36), p.call(50, 36), color, line)
	elif role in ["corner_left", "corner_right"]:
		draw_line(p.call(13, 8), p.call(13, 32), color, line)
		draw_polyline(PackedVector2Array([p.call(13, 8), p.call(23, 8),
			p.call(20, 12), p.call(23, 16), p.call(13, 16)]), color, line)
		draw_circle(p.call(19, 32), 2.4 * scale, color)
		for index in range(1, 5):
			var a: Vector2 = p.call(20 + index * 4.5, 30 - index * 3.0)
			var b: Vector2 = p.call(20 + (index + 1) * 4.5, 30 - (index + 1) * 3.0)
			draw_line(a, b, color, line)
		draw_line(p.call(38, 16), p.call(42, 14), color, line)
		draw_line(p.call(42, 14), p.call(42, 18), color, line)
	else:
		draw_polyline(PackedVector2Array([p.call(46, 10), p.call(58, 10),
			p.call(58, 30), p.call(46, 30)]), color, line)
		draw_line(p.call(46, 14), p.call(50, 14), color, line)
		draw_line(p.call(46, 26), p.call(50, 26), color, line)
		if role == "free_kick_long":
			draw_rect(Rect2(p.call(40, 18), Vector2(7, 12) * scale), color, false, line)
			draw_circle(p.call(13, 31), 2.4 * scale, color)
			for index in range(1, 5):
				draw_line(p.call(16 + index * 4.5, 30 - index * 2.0),
					p.call(16 + (index + 1) * 4.5, 30 - (index + 1) * 2.0), color, line)
			draw_line(p.call(36, 19), p.call(41, 17), color, line)
			draw_line(p.call(41, 17), p.call(41, 21), color, line)
		else:
			draw_rect(Rect2(p.call(28, 19), Vector2(4, 11) * scale), color, false, line)
			draw_rect(Rect2(p.call(33, 18), Vector2(4, 12) * scale), color, false, line)
			draw_rect(Rect2(p.call(38, 20), Vector2(4, 10) * scale), color, false, line)
			draw_circle(p.call(14, 31), 2.4 * scale, color)
			for index in range(1, 5):
				draw_line(p.call(17 + index * 5.0, 29 - index * 3.0),
					p.call(17 + (index + 1) * 5.0, 29 - (index + 1) * 3.0), color, line)
			draw_line(p.call(38, 15), p.call(43, 17), color, line)
			draw_line(p.call(43, 17), p.call(40, 20), color, line)


func _draw_glyph(rect: Rect2, kind: String, color: Color) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	match kind:
		"check":
			draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.6, 0), c + Vector2(-r * 0.1, r * 0.5),
				c + Vector2(r * 0.7, -r * 0.6),
			]), color, 2.0, true)
		"globe":
			draw_arc(c, r * 0.85, 0, TAU, 32, color, 1.6, true)
			draw_line(c + Vector2(-r * 0.85, 0), c + Vector2(r * 0.85, 0), color, 1.4)
			draw_arc(c, r * 0.45, -PI * 0.5, PI * 0.5, 16, color, 1.4, true)
			draw_arc(c, r * 0.45, PI * 0.5, PI * 1.5, 16, color, 1.4, true)
		"users":
			draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.28, color)
			draw_circle(c + Vector2(r * 0.35, -r * 0.25), r * 0.24, color)
			draw_arc(c + Vector2(-r * 0.35, r * 0.55), r * 0.62, PI, TAU, 18, color, 1.6, true)
			draw_arc(c + Vector2(r * 0.35, r * 0.55), r * 0.52, PI, TAU, 18, color, 1.6, true)
		"layers":
			for index in range(3):
				var y := c.y - r * 0.5 + index * r * 0.45
				draw_polyline(PackedVector2Array([
					Vector2(c.x - r * 0.7, y), Vector2(c.x, y - r * 0.3),
					Vector2(c.x + r * 0.7, y), Vector2(c.x, y + r * 0.3),
					Vector2(c.x - r * 0.7, y),
				]), color, 1.4, true)
		"lock":
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.8)),
				color, false, 1.6)
			draw_arc(c + Vector2(0, -r * 0.1), r * 0.36, PI, TAU, 16, color, 1.6, true)


func _draw_status_flag(rect: Rect2, alpha: float) -> void:
	draw_rect(rect, Color(MARK_LOSS, alpha), true)
	_draw_text(rect, "+", UiTheme.barlow(800), 14,
		Color(UiTokens.FOCUS_INK, alpha), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_shirt(rect: Rect2, alpha := 1.0) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var scale := minf(rect.size.x / 240.0, rect.size.y / 196.0)
	var origin := rect.position + (rect.size - Vector2(240.0, 196.0) * scale) * 0.5
	draw_set_transform(origin, 0.0, Vector2(scale, scale))
	var shirt := Color(_kit_shirt(), alpha)
	draw_colored_polygon(SHIRT, shirt)
	var outline := SHIRT.duplicate()
	outline.append(SHIRT[0])
	draw_polyline(outline, Color(UiTokens.KIT_ART_EDGE, alpha), 1.4, true)
	draw_set_transform(Vector2(_slide, 0.0), 0.0, Vector2.ONE)


func _kit_shirt() -> Color:
	return _parse_kit_color(_kit.get("shirt"), Color(0.85, 0.89, 0.94))


func _parse_kit_color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	if not text.begins_with("#"):
		text = "#" + text
	return Color.from_string(text, fallback)


func _draw_player_photo(rect: Rect2, player: Dictionary, alpha := 1.0) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var texture := UiAssets.player_face(int(str(player.get("id", "0"))))
	if texture != null:
		var fit := _fit_texture(texture, rect.size)
		var dest := Rect2(Vector2(rect.position.x + (rect.size.x - fit.x) * 0.5,
			rect.end.y - fit.y), fit)
		draw_texture_rect(texture, dest, false, Color(1, 1, 1, alpha))
		return
	var c := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.17
	draw_circle(Vector2(c.x, rect.position.y + rect.size.y * 0.34), radius,
		Color(0.78, 0.80, 0.84, alpha))
	draw_arc(Vector2(c.x, rect.end.y), rect.size.x * 0.30, PI, TAU, 18,
		Color(0.78, 0.80, 0.84, alpha), maxf(2.0, rect.size.x * 0.12), true)


func _draw_fatigue(rect: Rect2, fatigue: int) -> void:
	draw_rect(rect, Color(UiTokens.INK, 0.18), true)
	var fill := MARK_WIN if fatigue >= 50 else MARK_LOSS
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fatigue / 100.0, 0.0, 1.0),
		rect.size.y)), fill, true)


func _draw_tile(rect: Rect2, focused: bool, alpha := 1.0) -> void:
	for index in range(4):
		var shadow := Rect2(rect.position + Vector2(0.0, 8.0 + index * 3.0),
			rect.size + Vector2(0.0, 4.0))
		draw_rect(shadow, Color(0.015, 0.035, 0.078, 0.06 * alpha), true)
	var fill := UiTokens.FOCUS_FILL if focused else Color(UiTokens.TILE, alpha)
	draw_rect(rect, fill, true)


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var points: Array = []
	for index in range(49):
		var angle := TAU * float(index) / 48.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polyline(PackedVector2Array(points), color, width, true)


# Layout / focus -----------------------------------------------------------

func _rebuild_elements() -> void:
	_elements.clear()
	_tab_items.clear()
	if squad.is_empty():
		return
	match view:
		View.OVERVIEW:
			var m := _overview_metrics()
			_elements.append({"id": "team", "kind": "team", "rect": m["team"]})
			var tiles: Array = m["tiles"]
			for index in range(tiles.size()):
				var tile: Dictionary = OVERVIEW_TILES[index]
				if tile.get("disabled", false):
					continue
				_elements.append({
					"id": "tile:%s" % str(tile["id"]), "kind": "tile",
					"rect": tiles[index], "data": tile,
				})
		View.CENTRE:
			var m := _centre_metrics()
			for item in m["tabs"]:
				_elements.append({
					"id": "centre-tab:%d" % int(item["index"]), "kind": "centre-tab",
					"rect": item["rect"], "data": {"index": int(item["index"])},
				})
			if centre_tab == 2:
				var pane: Rect2 = m["panel"]
				_elements.append({
					"id": "centre-attr:-1", "kind": "centre-attr",
					"rect": Rect2(pane.end.x - 94.0, pane.position.y + 10.0, 30.0, 26.0),
					"data": {"delta": -1},
				})
				_elements.append({
					"id": "centre-attr:1", "kind": "centre-attr",
					"rect": Rect2(pane.end.x - 54.0, pane.position.y + 10.0, 30.0, 26.0),
					"data": {"delta": 1},
				})
			var players := _centre_players()
			if centre_tab == 3:
				var table: Rect2 = m["table"]
				var list := Rect2(table.position.x, table.position.y + 28.0,
					table.size.x, table.size.y - 28.0)
				for index in range(players.size()):
					var player: Dictionary = players[index]
					_elements.append({
						"id": "centre-row:%s" % str(player.get("id", "")),
						"kind": "centre-row",
						"rect": Rect2(list.position.x, list.position.y + 2.0
							+ _centre_row_offset(index) - centre_scroll,
							list.size.x, 44.0),
						"player_id": str(player.get("id", "")), "player": player,
					})
			else:
				var list: Rect2 = m["list"]
				for index in range(players.size()):
					var player: Dictionary = players[index]
					_elements.append({
						"id": "centre-row:%s" % str(player.get("id", "")),
						"kind": "centre-row",
						"rect": Rect2(list.position.x, list.position.y + 2.0
							+ _centre_row_offset(index) - centre_scroll,
							list.size.x, 50.0),
						"player_id": str(player.get("id", "")), "player": player,
					})
		View.PLAN, View.DETAILS:
			var m := _plan_metrics()
			_tab_items = m["tabs"]
			if view == View.DETAILS:
				_elements.append({"id": "details", "kind": "details",
					"rect": m["details"]})
				return
			for item in _tab_items:
				if item.get("disabled", false):
					continue
				_elements.append({"id": "tab:%s" % str(item["id"]), "kind": "tab",
					"rect": item["rect"], "data": item})
			match plan_tab:
				"schemes":
					_add_scheme_elements(m)
				"roles":
					_add_role_elements(m)
				_:
					_add_squad_elements(m)
		_:
			pass


func _add_squad_elements(m: Dictionary) -> void:
	var pitch: Rect2 = m["pitch"]
	var card_w := clampf(pitch.size.x * 0.095, 48.0, 80.0)
	for slot in _lineup_slots():
		var player: Dictionary = slot.get("player", {})
		if player.is_empty():
			continue
		_elements.append({
			"id": "card:%s" % str(player.get("id", "")), "kind": "card",
			"rect": _card_rect(pitch, slot, card_w, 72.0),
			"player_id": str(player.get("id", "")), "player": player,
		})
	var players := _bench_players()
	var bench_count: int = squad.get("lineup", {}).get("bench", []).size()
	var inner := Rect2(m["bench"].position.x + 10.0, m["bench"].position.y + 10.0,
		m["bench"].size.x - 20.0, m["bench"].size.y - 20.0)
	var grid_top := _bench_players_top(m["bench"], bench_open)
	var card_width := (inner.size.x - 8.0 * 3.0) / 4.0
	for index in range(players.size()):
		var player: Dictionary = players[index]
		var row := index / 4
		var col := index % 4
		var extra := 0.0 if index < bench_count or not bench_open else 22.0
		_elements.append({
			"id": "bench:%s" % str(player.get("id", "")), "kind": "bench",
			"rect": Rect2(inner.position.x + col * (card_width + 8.0),
				grid_top + extra + row * 100.0 - bench_scroll,
				card_width, 92.0),
			"player_id": str(player.get("id", "")), "player": player,
		})


func _add_scheme_elements(m: Dictionary) -> void:
	var panel: Rect2 = m["schemes"]
	var viewport := Rect2(panel.position.x + 8.0, panel.position.y + 38.0,
		panel.size.x - 26.0, SCHEME_CARD_H)
	var card_w := (viewport.size.x - 16.0) / 3.0
	var visible := _visible_formations()
	for index in range(visible.size()):
		var formation: Dictionary = visible[index]
		_elements.append({
			"id": "scheme:%s" % str(formation.get("id", "")), "kind": "scheme",
			"rect": Rect2(viewport.position.x + index * (card_w + 8.0),
				viewport.position.y, card_w, SCHEME_CARD_H),
			"data": formation,
		})


func _add_role_elements(m: Dictionary) -> void:
	var picking := not role_picking.is_empty()
	if not picking:
		var panel: Rect2 = m["roles"]
		var tile_w := panel.size.x / 4.0
		var tile_h := panel.size.y / 2.0
		for index in range(CareerRoles.ROLE_IDS.size()):
			var role := str(CareerRoles.ROLE_IDS[index])
			var rect: Rect2
			if role == "captain":
				rect = Rect2(panel.position.x, panel.position.y, tile_w, panel.size.y)
			else:
				var slot_index := index - 1
				var col := 1 + (slot_index % 3)
				var row := int(slot_index / 3)
				rect = Rect2(panel.position.x + col * tile_w + (1.0 if col > 0 else 0.0),
					panel.position.y + row * tile_h + (1.0 if row > 0 else 0.0),
					tile_w - 1.0, tile_h - 1.0)
			_elements.append({
				"id": "role:%s" % role, "kind": "role", "rect": rect,
				"data": {"id": role},
			})
		return
	var pitch: Rect2 = m["pitch"]
	var card_w := clampf(pitch.size.x * 0.095, 48.0, 80.0)
	for slot in _lineup_slots():
		var player: Dictionary = slot.get("player", {})
		if player.is_empty():
			continue
		_elements.append({
			"id": "card:%s" % str(player.get("id", "")), "kind": "card",
			"rect": _card_rect(pitch, slot, card_w, 72.0),
			"player_id": str(player.get("id", "")), "player": player,
		})


func _move_focus(direction: Vector2i, top_px := -1.0) -> bool:
	_rebuild_elements()
	if _elements.is_empty():
		return false
	var current := _focused_element()
	if current.is_empty():
		_set_focus(str(_elements[0].get("id", "")))
		return true
	var rect: Rect2 = current.get("rect", Rect2())
	var current_kind := str(current.get("kind", ""))
	if current_kind == "card" and direction == Vector2i.DOWN:
		var special := _card_down_target(rect.get_center())
		if not special.is_empty():
			_set_focus(str(special.get("id", "")))
			return true
	if current_kind == "bench" and direction == Vector2i.DOWN:
		var bench := _bench_target(index_of(_elements, current) + 1)
		if not bench.is_empty():
			_set_focus(str(bench.get("id", "")))
			return true
	var rects: Array[Rect2] = []
	for element in _elements:
		rects.append(element.get("rect", Rect2()))
	var index := FocusGrid.neighbour(rects, rect, direction, top_px)
	if index < 0:
		return false
	_set_focus(str(_elements[index].get("id", "")))
	return true


func _card_down_target(center: Vector2) -> Dictionary:
	var current := _focused_element()
	var role := str(current.get("player", {}).get("role", ""))
	if role in ["CB", "LB", "RB"]:
		for element in _elements:
			if str(element.get("kind", "")) == "card" \
					and str(element.get("player", {}).get("role", "")) == "GK":
				var other: Rect2 = element["rect"]
				if other.get_center().y > center.y + 10.0:
					return element
	for element in _elements:
		if str(element.get("kind", "")) != "card":
			continue
		var other: Rect2 = element["rect"]
		if other.get_center().y > center.y + 10.0:
			return {}
	for element in _elements:
		if str(element.get("kind", "")) == "bench":
			return element
	return {}


func _bench_target(start: int) -> Dictionary:
	for index in range(start, _elements.size()):
		if str(_elements[index].get("kind", "")) == "bench":
			return _elements[index]
	return {}


func _set_focus(id: String) -> void:
	if id.is_empty() or id == _focus_id:
			return
	_focus_id = id
	var element := _focused_element()
	bench_open = str(element.get("kind", "")) in ["bench"]
	if bench_open:
		_ensure_bench_visible(element)
		_rebuild_elements()
	if str(element.get("kind", "")) == "scheme":
		var formation: Dictionary = element.get("data", {})
		formation_index = maxi(0, CareerFormations.ORDER.find(str(formation.get("id", ""))))
		formation_page = int(formation_index / 3.0)
		_scheme_preview_id = ""
	elif str(element.get("kind", "")) == "role":
		role_focus = str(element.get("data", {}).get("id", "captain"))
	elif str(element.get("kind", "")) in ["card", "bench"]:
		_last_player_id = str(element.get("player_id", ""))
	elif str(element.get("kind", "")) == "centre-row":
		var rows := _centre_players()
		var player_id := str(element.get("player_id", ""))
		for index in range(rows.size()):
			if str(rows[index].get("id", "")) == player_id:
				centre_player = index
				break
		_ensure_centre_visible(centre_player)
		_rebuild_elements()
	state_changed.emit()
	queue_redraw()


func _ensure_focus() -> void:
	if _focused_element().is_empty():
		match view:
			View.OVERVIEW:
				_focus_id = "team"
			View.DETAILS:
				_focus_id = "details"
			View.PLAN:
				if plan_tab == "schemes":
					_focus_id = "scheme:%s" % previewed_formation()
				elif plan_tab == "roles":
					_focus_id = "role:%s" % role_focus
				else:
					_focus_id = _first_card_id()
			View.CENTRE:
				_focus_id = "centre-row:%s" % str(
					_centre_current().get("id", ""))
			_:
				_focus_id = "team"


func _focused_element() -> Dictionary:
	for element in _elements:
		if str(element.get("id", "")) == _focus_id:
			return element
	return {}


func _element_at(point: Vector2) -> Dictionary:
	for index in range(_elements.size() - 1, -1, -1):
		var element: Dictionary = _elements[index]
		if (element.get("rect", Rect2()) as Rect2).has_point(point):
			return element
	return {}


func _ensure_bench_visible(element: Dictionary) -> void:
	var players := _bench_players()
	var player_id := str(element.get("player_id", ""))
	var index := -1
	for i in range(players.size()):
		if str(players[i].get("id", "")) == player_id:
			index = i
			break
	if index < 0:
		return
	var m := _plan_metrics()
	var bench_rect: Rect2 = m["bench"]
	var inner_h := bench_rect.size.y - 20.0
	var card_h := 92.0
	var row_top := float(int(index / 4)) * (card_h + 8.0)
	var reserve_offset := 22.0 if index >= squad.get("lineup", {}).get("bench", []).size() else 0.0
	row_top += reserve_offset
	if row_top + card_h > bench_scroll + inner_h:
		bench_scroll = row_top + card_h - inner_h
	if row_top < bench_scroll:
		bench_scroll = row_top
	bench_scroll = maxf(0.0, bench_scroll)


func _ensure_centre_visible(index: int) -> void:
	var g := _centre_list_metrics()
	var row_h: float = g["row_h"]
	var inner_h: float = g["inner_h"]
	var row_top := 2.0 + _centre_row_offset(index)
	# The open plate travels with its row: both have to end up on screen.
	var bottom := row_top + row_h
	if _actions_row != null and _actions_index() == index:
		bottom = row_top + _centre_row_height() + _actions_row.size.y + 2.0
	if bottom > centre_scroll + inner_h:
		centre_scroll = bottom - inner_h
	if row_top < centre_scroll:
		centre_scroll = row_top
	centre_scroll = clampf(centre_scroll, 0.0, maxf(0.0,
		_centre_content_height(row_h) - inner_h))


# Visible height of the centre list and the height of one of its rows.
func _centre_list_metrics() -> Dictionary:
	if centre_tab == 3:
		var table: Rect2 = _centre_metrics()["table"]
		return {"inner_h": table.size.y - 28.0, "row_h": 44.0}
	var list: Rect2 = _centre_metrics()["list"]
	return {"inner_h": list.size.y, "row_h": 50.0}


# Rows under the open plate carry its height, so the list grows by that much
# even when the plate hangs under the last row.
func _centre_content_height(row_h: float) -> float:
	var players := _centre_players()
	if players.is_empty():
		return 0.0
	var content := 2.0 + _centre_row_offset(players.size() - 1) + row_h
	var open := _actions_index()
	if _actions_row != null and open >= 0:
		content = maxf(content, 2.0 + _centre_row_offset(open) + _centre_row_height()
			+ _actions_row.size.y + 2.0)
	return content


# The accordion pushes the rows under it down instead of covering them: every
# index after the open one carries the panel's height as extra offset.
func _centre_row_height() -> float:
	return 46.0 if centre_tab == 3 else 53.0


func _actions_index() -> int:
	if _actions_row == null or _actions_player_id.is_empty():
		return -1
	return _actions_index_of(_actions_player_id)


func _actions_index_of(player_id: String) -> int:
	if player_id.is_empty():
		return -1
	var players := _centre_players()
	for index in range(players.size()):
		if str(players[index].get("id", "")) == player_id:
			return index
	return -1


func _centre_row_offset(index: int) -> float:
	var offset := index * _centre_row_height()
	if _actions_row == null:
		return offset
	var open := _actions_index()
	var gap := _actions_row.size.y + 2.0
	if open >= 0 and index > open:
		return offset + gap
	return offset


func _step_schemes(direction: Vector2i) -> bool:
	var total := CareerFormations.ORDER.size()
	if total == 0:
		return true
	if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
		var delta := 1 if direction == Vector2i.RIGHT else -1
		formation_index = clampi(formation_index + delta, 0, total - 1)
	elif direction == Vector2i.UP or direction == Vector2i.DOWN:
		var page_delta := 1 if direction == Vector2i.DOWN else -1
		var pages := int(ceil(float(total) / 3.0))
		formation_page = clampi(formation_page + page_delta, 0, pages - 1)
		formation_index = mini(total - 1, formation_page * 3 + (formation_index % 3))
	formation_page = int(formation_index / 3.0)
	_focus_id = "scheme:%s" % str(CareerFormations.ORDER[formation_index])
	_scheme_preview_id = ""
	_rebuild_elements()
	state_changed.emit()
	queue_redraw()
	return true


# State actions ------------------------------------------------------------

func _open_plan() -> void:
	view = View.PLAN
	plan_tab = "squad"
	details_page = 0
	anchor_id = ""
	bench_open = false
	_status = ""
	_status_error = false
	_focus_id = _player_focus_id()
	_rebuild_elements()
	_sync_tab_marker(false)
	view_changed.emit(1)
	state_changed.emit()
	queue_redraw()


func _open_overview() -> void:
	_close_actions()
	view = View.OVERVIEW
	plan_tab = "squad"
	anchor_id = ""
	bench_open = false
	_status = ""
	_status_error = false
	_focus_id = "team"
	_rebuild_elements()
	_marker_ready = false
	_update_lineup_preview()
	view_changed.emit(-1)
	state_changed.emit()
	queue_redraw()


func _open_centre() -> void:
	view = View.CENTRE
	centre_tab = 0
	centre_player = 0
	centre_scroll = 0.0
	centre_attribute_page = 0
	_focus_id = "centre-row:%s" % _first_centre_player_id()
	_rebuild_elements()
	if _lineup_preview != null:
		_lineup_preview.visible = false
	_sync_tab_marker(false)
	_sync_centre_tabs()
	view_changed.emit(1)
	state_changed.emit()
	queue_redraw()


func _open_plan_tab(tab: String) -> void:
	if not ["squad", "schemes", "roles"].has(tab):
		return
	var direction := signi(_plan_tab_index(tab) - _plan_tab_index(plan_tab))
	plan_tab = tab
	anchor_id = ""
	role_picking = ""
	_status = ""
	_status_error = false
	bench_open = false
	bench_scroll = 0.0
	details_page = 0
	if tab == "schemes":
		formation_index = CareerFormations.formation_index(career.formation)
		formation_page = int(formation_index / 3.0)
		_focus_id = "scheme:%s" % str(CareerFormations.ORDER[formation_index])
	elif tab == "roles":
		role_focus = str(CareerRoles.ROLE_IDS[0])
		var assigned := _role_player(role_focus)
		_focus_id = "role:%s" % role_focus
		if not assigned.is_empty():
			anchor_id = ""
	else:
		_focus_id = _player_focus_id()
	_rebuild_elements()
	_animate_switch(direction)
	_sync_tab_marker(true)
	state_changed.emit()
	queue_redraw()


func _plan_tab_index(tab: String) -> int:
	for index in range(PLAN_TABS.size()):
		if str(PLAN_TABS[index]["id"]) == tab:
			return index
	return 0


func _activate_player(player_id: String) -> void:
	if player_id.is_empty():
		return
	var player := _player_by_id(player_id)
	if player.is_empty() or player.get("available", true) == false:
		_status = "Player is unavailable"
		_status_error = true
		state_changed.emit()
		return
	if anchor_id.is_empty():
		anchor_id = player_id
		_status = ""
		_status_error = false
		state_changed.emit()
		_rebuild_elements()
		queue_redraw()
		return
	if anchor_id == player_id:
		anchor_id = ""
		_status = ""
		_status_error = false
		state_changed.emit()
		_rebuild_elements()
		queue_redraw()
		return
	if not _can_swap():
		_status = "Player is unavailable"
		_status_error = true
		state_changed.emit()
		return
	var ok := CareerSquad.swap_players(career, _squad_players(), anchor_id, player_id)
	if not ok:
		_status = CareerSquad.last_error.capitalize()
		_status_error = true
		state_changed.emit()
		return
	anchor_id = ""
	_status = ""
	_status_error = false
	_last_player_id = player_id
	refresh()
	_focus_id = "card:%s" % player_id if _is_starter(player_id) else "bench:%s" % player_id
	_rebuild_elements()
	changed.emit()
	state_changed.emit()
	queue_redraw()


func _start_role_pick(role: String) -> void:
	if role_picking == role:
		return
	role_focus = role
	role_picking = role
	var assigned := _role_player(role)
	if not assigned.is_empty():
		_focus_id = "card:%s" % str(assigned.get("id", ""))
	else:
		_focus_id = _first_card_id()
	_rebuild_elements()
	state_changed.emit()
	queue_redraw()


func _assign_role(player_id: String) -> void:
	if role_picking.is_empty() or player_id.is_empty():
		return
	var role := role_picking
	if str(_role_player(role).get("id", "")) != player_id:
		var ok := CareerSquad.set_role(career, _squad_players(), role, player_id)
		if not ok:
			_status = CareerSquad.last_error.capitalize()
			_status_error = true
			state_changed.emit()
			return
	role_picking = ""
	_status = ""
	_status_error = false
	refresh()
	_focus_id = "role:%s" % role
	_rebuild_elements()
	changed.emit()
	state_changed.emit()
	queue_redraw()


func _select_formation(formation: String) -> void:
	if formation.is_empty() or formation == career.formation:
		return
	var ok := CareerSquad.set_formation(career, _squad_players(), formation)
	if not ok:
		_status = CareerSquad.last_error.capitalize()
		_status_error = true
		state_changed.emit()
		return
	_status = ""
	_status_error = false
	refresh()
	formation_index = CareerFormations.formation_index(formation)
	formation_page = int(formation_index / 3.0)
	_focus_id = "scheme:%s" % formation
	_rebuild_elements()
	changed.emit()
	state_changed.emit()
	queue_redraw()


# Squad helpers ------------------------------------------------------------

func _squad_players() -> Array:
	return squad.get("players", [])


func _lineup() -> Dictionary:
	return squad.get("lineup", {})


func _lineup_slots() -> Array:
	return _lineup().get("slots", [])


func _first_card_id() -> String:
	for slot in _lineup_slots():
		var player: Dictionary = slot.get("player", {})
		if not player.is_empty():
			return "card:%s" % str(player.get("id", ""))
	return ""


func _player_focus_id() -> String:
	if _last_player_id.is_empty():
		return _first_card_id()
	if _is_starter(_last_player_id):
		return "card:%s" % _last_player_id
	for player in _bench_players():
		if str(player.get("id", "")) == _last_player_id:
			return "bench:%s" % _last_player_id
	return _first_card_id()


func _first_centre_player_id() -> String:
	var players: Array = squad.get("players", [])
	if players.is_empty():
		return ""
	return str(players[0].get("id", ""))


func _focused_player_id() -> String:
	var element := _focused_element()
	if not element.is_empty() and element.has("player_id"):
		return str(element.get("player_id", ""))
	var slots := _lineup_slots()
	if slots.is_empty():
		return ""
	return str(slots[0].get("player", {}).get("id", ""))


func _focused_player() -> Dictionary:
	return _player_by_id(_focused_player_id())


func _player_by_id(player_id: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	for player in _squad_players():
		if str(player.get("id", "")) == player_id:
			return player
	for slot in _lineup_slots():
		var player: Dictionary = slot.get("player", {})
		if str(player.get("id", "")) == player_id:
			return player
	for player in _bench_players():
		if str(player.get("id", "")) == player_id:
			return player
	return {}


func _is_starter(player_id: String) -> bool:
	for slot in _lineup_slots():
		if str(slot.get("player", {}).get("id", "")) == player_id:
			return true
	return false


func _can_swap() -> bool:
	if anchor_id.is_empty():
		return false
	var player := _focused_player()
	if player.is_empty():
		return false
	var anchor_player := _player_by_id(anchor_id)
	return not anchor_player.is_empty() and player.get("available", true) != false \
		and anchor_player.get("available", true) != false


func _team_strength() -> int:
	return int(round(CareerSquad.team_average(_lineup())))


func _team_delta() -> float:
	if anchor_id.is_empty():
		return 0.0
	var focused := _focused_player_id()
	if focused.is_empty() or focused == anchor_id:
		return 0.0
	return CareerSquad.projected_average(_lineup(), anchor_id, focused) \
		- CareerSquad.team_average(_lineup())


func _preview_formation() -> Dictionary:
	var formations: Array = squad.get("formations", [])
	if formations.is_empty():
		return {}
	if _scheme_preview_id == str(formations[formation_index].get("id", "")):
		return formations[formation_index]
	return formations[clampi(formation_index, 0, formations.size() - 1)]


func _scheme_lineup() -> Dictionary:
	var preview_id := previewed_formation()
	if preview_id.is_empty() or preview_id == str(_lineup().get("formation", "")):
		return _lineup()
	if _scheme_preview_id != preview_id or _scheme_preview.is_empty():
		_scheme_preview = CareerSquad.preview_lineup(_lineup(), preview_id)
		_scheme_preview_id = preview_id
	return _scheme_preview


func _visible_formations() -> Array:
	var formations: Array = squad.get("formations", [])
	var start := formation_page * 3
	return formations.slice(start, mini(formations.size(), start + 3))


func _role_anchor_id() -> String:
	if role_focus.is_empty():
		return ""
	return str(_role_player(role_focus).get("id", ""))


func _role_player(role: String) -> Dictionary:
	var assignments: Dictionary = squad.get("roles", {})
	var player_id := str(assignments.get(role, ""))
	return _player_by_id(player_id)


func _radar(player: Dictionary) -> Array:
	var stats: Dictionary = player.get("stats", {})
	return CareerSquad.radar_values(stats) if not stats.is_empty() else []


func _slot_role_for_player(player: Dictionary) -> String:
	for slot in _lineup_slots():
		if str(slot.get("player", {}).get("id", "")) == str(player.get("id", "")):
			return str(slot.get("role", player.get("role", "")))
	return str(player.get("role", ""))


func _general_rows(player: Dictionary) -> Array:
	var values := CareerSquad.info_values(player)
	return [
		["POSITION", str(values["position"])],
		["AGE", str(values["age"])],
		["HEIGHT", str(values["height"])],
		["WEIGHT", str(values["weight"])],
		["FOOT", str(values["foot"])],
		["NUMBER", str(values["shirtNumber"])],
		["POTENTIAL", str(values["potential"])],
	]


func _season_rows(player: Dictionary) -> Array:
	var season: Dictionary = player.get("season_stats", {})
	return [
		{"label": "APPS", "left": str(int(season.get("apps", 0)))},
		{"label": "STARTS", "left": str(int(season.get("starts", 0)))},
		{"label": "MINUTES", "left": str(int(season.get("minutes", 0)))},
		{"label": "GOALS", "left": str(int(season.get("goals", 0)))},
		{"label": "ASSISTS", "left": str(int(season.get("assists", 0)))},
		{"label": "YELLOW", "left": str(int(season.get("yellow", 0)))},
		{"label": "RED", "left": str(int(season.get("red", 0)))},
	]


# Drawing helpers ----------------------------------------------------------

func _draw_text(rect: Rect2, text: String, font: Font, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, ellipsis := false) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var value := text
	if ellipsis:
		value = _ellipsize(text, font, font_size, rect.size.x)
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	var baseline := rect.position.y + (rect.size.y - (asc + desc)) * 0.5 + asc
	draw_string(font, Vector2(rect.position.x, baseline), value, align, rect.size.x,
		font_size, color)


func _ellipsize(text: String, font: Font, font_size: int, max_width: float) -> String:
	if max_width <= 0.0:
		return text
	if _text_width(text, font, font_size) <= max_width:
		return text
	var low := 0
	var high := text.length()
	while low < high:
		var mid := int((low + high + 1) / 2)
		if _text_width(text.substr(0, mid) + "…", font, font_size) <= max_width:
			low = mid
		else:
			high = mid - 1
	return text.substr(0, low) + "…"


func _text_width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _fit_texture(texture: Texture2D, box: Vector2) -> Vector2:
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return box
	var scale := minf(box.x / size.x, box.y / size.y)
	return size * scale


func _closed(points: Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if points.size() > 2 and points[0] != points[points.size() - 1]:
		closed.append(points[0])
	return PackedVector2Array(closed)


func _rect_intersects(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b, true)


func _player_name(player: Dictionary) -> String:
	var last := str(player.get("lastname", "")).strip_edges()
	if last.is_empty():
		last = str(player.get("name", "")).strip_edges()
	return last


func _short_role(role: String) -> String:
	return role if not role.is_empty() else "—"


func _role_color(role: String) -> Color:
	if role == "GK":
		return POS_GK
	if role in ["CB", "LB", "RB"]:
		return POS_DEF
	if role in ["DM", "CM", "LM", "RM", "AM"]:
		return POS_MID
	return POS_FWD


func _rating_color(rating: int) -> Color:
	if rating >= 90:
		return UiTokens.INK
	if rating >= 80:
		return MARK_WIN
	if rating >= 70:
		return MARK_WARN
	if rating >= 60:
		return MARK_WARN
	return MARK_LOSS


func _stat_color(value: int) -> Color:
	if value >= 85:
		return MARK_WIN
	if value >= 75:
		return MARK_WIN
	if value >= 60:
		return MARK_WARN
	return MARK_LOSS


func _initial_name(player: Dictionary) -> String:
	var first := str(player.get("firstname", "")).strip_edges()
	var last := str(player.get("lastname", ""))
	if last.is_empty():
		last = str(player.get("name", ""))
	var initial := ""
	if not first.is_empty():
		initial = "%s. " % first.substr(0, 1)
	return ("%s%s" % [initial, last]).to_upper()


func _format_value(value: int) -> String:
	if value >= 1000000000:
		return "€%.1fB" % (float(value) / 1000000000.0)
	if value >= 1000000:
		var millions := float(value) / 1000000.0
		return "€%.0fM" % millions if value >= 10000000 else "€%.1fM" % millions
	if value >= 1000:
		return "€%dK" % int(round(float(value) / 1000.0))
	return "€%d" % value


func index_of(array: Array, item: Dictionary) -> int:
	for index in range(array.size()):
		if str(array[index].get("id", "")) == str(item.get("id", "")):
			return index
	return -1
