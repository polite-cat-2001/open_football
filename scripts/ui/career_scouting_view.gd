class_name CareerScoutingView
extends Control
# World network (scouting) screen of the Transfers tab, ported from the
# prototype's ScoutingHub.svelte state machine: the SCOUTS / TASKS tabs, the
# region → country network setup, the task editor and the REPORTS feed.
#
# The screen owns its input (UiNav) and its focus, reads CareerScouting once per
# refresh and reports mutations with `changed` so the host saves. Player routes
# (offer / contract) leave through `navigate`; B/Esc leaves through `closed`.

signal navigate(view: String, payload: Dictionary)
signal closed
signal changed
signal state_changed

const NETWORK_TABS := ["SCOUTS", "TASKS"]
const NETWORK_IDS := ["scouts", "tasks"]
const REPORT_TABS := [
	{"id": "all", "label": "ALL"},
	{"id": "requests", "label": "REQUESTS"},
	{"id": "GK", "label": "GK"},
	{"id": "DEF", "label": "DEF"},
	{"id": "MID", "label": "MID"},
	{"id": "FWD", "label": "FWD"},
]
const TASK_ROLES := ["", "GK", "DEF", "MID", "FWD"]
const COLUMNS := 3
const GAP := 10.0
const HEAD_H := 40.0
const ERROR_H := 34.0
const BODY_LEFT := 1.42
const BODY_RIGHT := 0.88
const UI_MODAL := preload("res://scripts/ui/ui_modal.gd")

var career: Career
var catalog: TeamCatalog
var snapshot: Dictionary = {}
var view := "scouts"
var network_tab := "scouts"
var report_filter := "all"

var _scout_id := ""
var _task_scout_id := ""
var _entry_id := ""
var _scout_filter := ""
var _reports_return := "network"

var _assign_scout_id := ""
var _region_id := ""
var _country_id := ""

var _task_scout := ""
var _task_draft: Dictionary = {}
var _task_field := ""
var _task_range := "min"
var _task_saved := true

var _error := ""
var _club_name := ""
var _report_can_discuss := false
var _open := false
var _body_tween: Tween
var _pending: Callable

var _tabs: UiTabBar
var _headline: Panel
var _head_title: Label
var _head_sub: Label
var _error_bar: Panel
var _error_label: Label
var _body: Control
var _scouts_body: Control
var _scout_grid: GridContainer
var _scout_panel: CareerScoutPanel
var _tasks_body: Control
var _task_grid: GridContainer
var _task_panel: CareerScoutTaskPanel
var _map: CareerScoutMapPanel
var _task_editor: CareerScoutTaskEditor
var _reports: CareerScoutReportsFeed

var _scout_cards: Array[Control] = []
var _scout_tiles: Array[Control] = []
var _task_cards: Array[Control] = []
var _task_tiles: Array[Control] = []
var _task_action: Button

var _scout_actions: CareerScoutActionsModal
var _hire_modal: CareerScoutHireModal
var _confirm
var _report_modal: CareerScoutingModal


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# Connect before building: the modals connect their own UiNav handlers when
	# they enter the tree, and the screen must see the modal stack first so the
	# very event a modal consumes does not also run the screen underneath.
	_connect_nav()
	_build()
	resized.connect(_layout)
	call_deferred("_layout")
	if _open:
		_apply_open()


# Host contract --------------------------------------------------------------

func open(next_career: Career, next_catalog: TeamCatalog, payload := {}) -> void:
	career = next_career
	catalog = next_catalog
	_open = true
	visible = true
	_error = ""
	_reset_state(payload)
	if not is_node_ready():
		return
	_apply_open()


func close() -> void:
	_open = false
	visible = false
	if _report_modal != null:
		_report_modal.close()
	if _scout_actions != null:
		_scout_actions.close()
	if _hire_modal != null:
		_hire_modal.close()
	if _confirm != null:
		_confirm.close()


func hints() -> Array:
	if not is_node_ready():
		return []
	var gamepad := false
	var nav := _ui_nav()
	if nav != null:
		gamepad = nav.using_gamepad()
	var move := {"keys": ["D-PAD"] if gamepad else ["↑", "↓", "←", "→"],
		"label": "navigation"}
	var select := {"keys": ["A"] if gamepad else ["ENTER"], "label": "select"}
	var back := {"keys": ["B"] if gamepad else ["ESC"], "label": "back"}
	var tabs := {"keys": ["LB", "RB"] if gamepad else ["TAB"], "label": "tabs"}
	if _confirm.is_open():
		return [
			{"keys": ["D-PAD"] if gamepad else ["↑", "↓"], "label": "choose"},
			{"keys": ["A"] if gamepad else ["ENTER"], "label": "confirm"},
			{"keys": ["B"] if gamepad else ["ESC"], "label": "cancel"},
		]
	if _report_modal.is_open():
		return [move, select, {"keys": ["X"], "label": "remove from report"}, back]
	if _scout_actions.is_open() or _hire_modal.is_open():
		return [move, select, back]
	if view == "reports":
		return [move, tabs, select, back]
	if view == "region" or view == "country":
		return [move, select, back]
	if view == "task":
		if not _task_field.is_empty():
			return [
				{"keys": ["←", "→"], "label": "value"},
				{"keys": ["↑", "↓"], "label": "min / max"},
				select, back,
			]
		return [move, select, {"keys": ["X"], "label": "default"}, back]
	return [move, tabs, select, {"keys": ["Y"], "label": "actions"}, back]


func focus_initial() -> void:
	if not is_inside_tree() or _tabs == null:
		return
	match view:
		"scouts":
			_focus_first_scout()
		"tasks":
			_focus_first_task()
		"region", "country":
			_focus_first_map()
		"task":
			_focus_first_editor()
		"reports":
			_focus_reports_initial()


func status() -> String:
	return _error


func status_error() -> bool:
	return not _error.is_empty()


# Open / state ---------------------------------------------------------------

func _reset_state(payload: Dictionary) -> void:
	var mode := str(payload.get("mode", "scouts"))
	var initial_entry := str(payload.get("player_id", ""))
	network_tab = "scouts"
	report_filter = "all"
	_scout_id = ""
	_task_scout_id = ""
	_scout_filter = ""
	_reports_return = "close" if mode == "reports" else "network"
	_task_scout = ""
	_task_draft = {}
	_task_field = ""
	_task_saved = true
	_assign_scout_id = ""
	_region_id = ""
	_country_id = ""
	_entry_id = initial_entry if mode == "reports" else ""
	view = "reports" if mode == "reports" else "scouts"
	_club_name = _club_name_of_career()
	snapshot = _snapshot()


func _apply_open() -> void:
	_refresh()
	_switch_body_instant()
	focus_initial()
	if view == "reports":
		_acknowledge()


# Build ----------------------------------------------------------------------

func _build() -> void:
	_tabs = UiTabBar.new()
	_tabs.name = "NetworkTabs"
	add_child(_tabs)
	var labels: Array[String] = []
	for tab in NETWORK_TABS:
		labels.append(str(tab))
	_tabs.setup(labels)
	_tabs.fit_width()
	_tabs.tab_selected.connect(_on_network_tab_selected)

	_headline = Panel.new()
	_headline.name = "Headline"
	_headline.add_theme_stylebox_override(&"panel", _tile_box())
	add_child(_headline)
	_head_title = _label(UiTheme.barlow(800), 22)
	_head_title.add_theme_color_override(&"font_color", UiTokens.INK)
	_headline.add_child(_head_title)
	_head_sub = _label(UiTheme.inter(500), 16)
	_head_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_head_sub.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_headline.add_child(_head_sub)

	_error_bar = Panel.new()
	_error_bar.name = "Error"
	var error_box := StyleBoxFlat.new()
	error_box.bg_color = UiTokens.TILE
	error_box.border_color = Color("b23a48")
	error_box.border_width_left = 6
	error_box.shadow_color = UiTokens.SHADOW
	error_box.shadow_size = 24
	error_box.shadow_offset = Vector2(0.0, 16.0)
	_error_bar.add_theme_stylebox_override(&"panel", error_box)
	_error_bar.visible = false
	add_child(_error_bar)
	_error_label = _label(UiTheme.inter(600), 16)
	_error_label.add_theme_color_override(&"font_color", Color("b23a48"))
	_error_bar.add_child(_error_label)

	_body = Control.new()
	_body.name = "Body"
	add_child(_body)

	_scouts_body = Control.new()
	_scouts_body.name = "Scouts"
	_body.add_child(_scouts_body)
	_scout_grid = GridContainer.new()
	_scout_grid.columns = COLUMNS
	_scout_grid.add_theme_constant_override(&"h_separation", int(GAP))
	_scout_grid.add_theme_constant_override(&"v_separation", int(GAP))
	_scouts_body.add_child(_scout_grid)
	_scout_panel = CareerScoutPanel.new()
	_scouts_body.add_child(_scout_panel)

	_tasks_body = Control.new()
	_tasks_body.name = "Tasks"
	_body.add_child(_tasks_body)
	_task_grid = GridContainer.new()
	_task_grid.columns = COLUMNS
	_task_grid.add_theme_constant_override(&"h_separation", int(GAP))
	_task_grid.add_theme_constant_override(&"v_separation", int(GAP))
	_tasks_body.add_child(_task_grid)
	_task_panel = CareerScoutTaskPanel.new()
	_tasks_body.add_child(_task_panel)
	_task_panel.reports_requested.connect(_on_task_reports_requested)
	_task_action = _task_panel.action_button()

	_map = CareerScoutMapPanel.new()
	_map.name = "Map"
	_body.add_child(_map)
	_map.region_focused.connect(_on_region_focused)
	_map.region_selected.connect(_on_region_selected)
	_map.country_focused.connect(_on_country_focused)
	_map.country_selected.connect(_on_country_selected)
	_map.next_requested.connect(_on_map_next)

	_task_editor = CareerScoutTaskEditor.new()
	_task_editor.name = "TaskEditor"
	_body.add_child(_task_editor)
	_task_editor.field_selected.connect(_on_task_field_selected)
	_task_editor.reports_requested.connect(_on_task_editor_reports)

	_reports = CareerScoutReportsFeed.new()
	_reports.name = "Reports"
	_body.add_child(_reports)
	_reports.filter_selected.connect(_on_report_filter)
	_reports.entry_focused.connect(_on_entry_focused)
	_reports.entry_activated.connect(_open_report_modal)

	_scout_actions = CareerScoutActionsModal.new()
	_scout_actions.name = "ScoutActions"
	add_child(_scout_actions)
	_scout_actions.action_chosen.connect(_on_scout_action)
	_scout_actions.closed.connect(_on_modal_closed)

	_hire_modal = CareerScoutHireModal.new()
	_hire_modal.name = "Hire"
	add_child(_hire_modal)
	_hire_modal.hire_requested.connect(_on_hire_requested)
	_hire_modal.closed.connect(_on_modal_closed)

	_confirm = UI_MODAL.new()
	_confirm.name = "Confirm"
	add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.action_chosen.connect(_on_confirm_action)
	_confirm.closed.connect(_on_confirm_closed)

	_report_modal = CareerScoutingModal.new()
	_report_modal.name = "Report"
	add_child(_report_modal)
	_report_modal.closed.connect(_on_modal_closed)


func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	return label


func _tile_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 24
	box.shadow_offset = Vector2(0.0, 16.0)
	return box


# Layout ---------------------------------------------------------------------

func _layout() -> void:
	if _tabs == null or size.x <= 0.0:
		return
	_tabs.position = Vector2.ZERO
	_headline.position = Vector2.ZERO
	_headline.size = Vector2(size.x, HEAD_H)
	_head_title.position = Vector2(20.0, 0.0)
	_head_title.size = Vector2(size.x * 0.5, HEAD_H)
	_head_sub.position = Vector2(size.x * 0.5, 0.0)
	_head_sub.size = Vector2(size.x * 0.5 - 20.0, HEAD_H)

	var top := 0.0
	if view == "scouts" or view == "tasks":
		top = UiTokens.TAB_H + GAP
	elif view != "reports":
		top = HEAD_H + GAP
	_error_bar.position = Vector2(0.0, top)
	_error_bar.size = Vector2(size.x, ERROR_H)
	_error_label.position = Vector2(16.0, 0.0)
	_error_label.size = Vector2(maxf(0.0, size.x - 32.0), ERROR_H)
	if _error_bar.visible:
		top += ERROR_H + 6.0
	_body.position = Vector2(0.0, top)
	_body.size = Vector2(size.x, maxf(0.0, size.y - top))

	for child in _body.get_children():
		(child as Control).position = Vector2.ZERO
		(child as Control).size = _body.size

	_layout_scouts()
	_layout_tasks()


func _layout_scouts() -> void:
	var body := _body.size
	if body.x <= 0.0 or body.y <= 0.0:
		return
	var left_w := floorf((body.x - GAP) * BODY_LEFT / (BODY_LEFT + BODY_RIGHT))
	_scout_grid.position = Vector2.ZERO
	_scout_grid.size = Vector2(left_w, body.y)
	_scout_panel.position = Vector2(left_w + GAP, 0.0)
	_scout_panel.size = Vector2(maxf(0.0, body.x - left_w - GAP), body.y)
	var card_w := floorf((left_w - float(COLUMNS - 1) * GAP) / float(COLUMNS))
	var card_h := floorf((body.y - GAP) * 0.5)
	for card in _scout_cards + _scout_tiles:
		card.custom_minimum_size = Vector2(card_w, card_h)


func _layout_tasks() -> void:
	var body := _body.size
	if body.x <= 0.0 or body.y <= 0.0:
		return
	var left_w := floorf((body.x - GAP) * BODY_LEFT / (BODY_LEFT + BODY_RIGHT))
	_task_grid.position = Vector2.ZERO
	_task_grid.size = Vector2(left_w, body.y)
	_task_panel.position = Vector2(left_w + GAP, 0.0)
	_task_panel.size = Vector2(maxf(0.0, body.x - left_w - GAP), body.y)
	var card_w := floorf((left_w - float(COLUMNS - 1) * GAP) / float(COLUMNS))
	var card_h := floorf((body.y - GAP) * 0.5)
	for card in _task_cards + _task_tiles:
		card.custom_minimum_size = Vector2(card_w, card_h)


# Snapshot helpers -----------------------------------------------------------

func _snapshot() -> Dictionary:
	if career == null or catalog == null:
		return {}
	return CareerScouting.snapshot(career, catalog)


func _scouts() -> Array:
	var scouts = snapshot.get("scouts", [])
	return scouts if scouts is Array else []


func _scout(scout_id: String) -> Dictionary:
	for scout in _scouts():
		if scout is Dictionary and str((scout as Dictionary).get("id", "")) == scout_id:
			return scout
	return {}


func _select_scout() -> Dictionary:
	if _scout_id.is_empty() or _scout(_scout_id).is_empty():
		var scouts := _scouts()
		_scout_id = str((scouts[0] as Dictionary).get("id", "")) if not scouts.is_empty() \
			else ""
	return _scout(_scout_id)


func _select_task_scout() -> Dictionary:
	if _task_scout_id.is_empty() or _scout(_task_scout_id).is_empty():
		var scouts := _scouts()
		_task_scout_id = str((scouts[0] as Dictionary).get("id", "")) \
			if not scouts.is_empty() else ""
	return _scout(_task_scout_id)


func _refresh() -> void:
	if career == null or catalog == null:
		return
	snapshot = _snapshot()
	_refresh_error()
	_show_header()
	match view:
		"scouts":
			_refresh_scouts()
		"tasks":
			_refresh_tasks()
		"region", "country":
			_refresh_map()
		"task":
			_refresh_task_editor()
		"reports":
			_refresh_reports()
	_layout()


func _show_header() -> void:
	var network := view == "scouts" or view == "tasks"
	_tabs.visible = network
	_headline.visible = not network and view != "reports"
	if network:
		var index := maxi(0, NETWORK_IDS.find(network_tab))
		if _tabs.get_active_tab() != index:
			_tabs.select_tab(index, false)
	if _headline.visible:
		match view:
			"region":
				_head_title.text = "SELECT REGION"
			"country":
				_head_title.text = "SELECT COUNTRY"
			_:
				_head_title.text = "SCOUT TASK"
		_head_sub.text = "%s · %s" % [_club_name,
			CareerScoutReportsFeed._date_label(career.date if career != null else "")]


func _refresh_error() -> void:
	_error_bar.visible = not _error.is_empty()
	_error_label.text = "error: %s" % _error if not _error.is_empty() else ""


func _go(next: String) -> void:
	if next == view:
		_refresh()
		_animate_body()
		return
	view = next
	_error = ""
	_switch_body()
	_refresh()
	focus_initial()
	_animate_body()
	state_changed.emit()


func _switch_body_instant() -> void:
	_switch_body()
	if _body_tween != null:
		_body_tween.kill()
	_body.modulate.a = 1.0
	_body.scale = Vector2.ONE


func _switch_body() -> void:
	for child in _body.get_children():
		(child as Control).visible = false
	var current := _current_body()
	if current != null:
		current.visible = true
	_layout()


func _current_body() -> Control:
	match view:
		"scouts":
			return _scouts_body
		"tasks":
			return _tasks_body
		"region", "country":
			return _map
		"task":
			return _task_editor
		"reports":
			return _reports
	return _scouts_body


func _animate_body() -> void:
	if not is_inside_tree() or _instant():
		_body.modulate.a = 1.0
		_body.scale = Vector2.ONE
		return
	if _body_tween != null:
		_body_tween.kill()
	_body.pivot_offset = _body.size * 0.5
	_body.modulate.a = 0.0
	_body.scale = Vector2(0.985, 0.985)
	_body_tween = create_tween().set_parallel(true)
	_body_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_body, "modulate:a", 1.0, UiTokens.SCREEN_IN)
	_body_tween.tween_property(_body, "scale", Vector2.ONE, UiTokens.SCREEN_IN)


# Scouts tab ----------------------------------------------------------------

func _refresh_scouts() -> void:
	var scouts := _scouts()
	for card in _scout_cards:
		_scout_grid.remove_child(card)
		card.queue_free()
	_scout_cards.clear()
	for tile in _scout_tiles:
		_scout_grid.remove_child(tile)
		tile.queue_free()
	_scout_tiles.clear()
	for scout in scouts:
		if not (scout is Dictionary):
			continue
		var card := CareerScoutCard.new()
		_scout_grid.add_child(card)
		card.setup(scout, CareerScoutCard.status_for(scout))
		card.pressed.connect(_open_scout)
		card.focus_entered.connect(_on_scout_focused.bind(card))
		_scout_cards.append(card)
	var slots := int(snapshot.get("max_scouts", 6)) - scouts.size()
	for _slot in maxi(0, slots):
		var tile := CareerScoutCard.Empty.new()
		_scout_grid.add_child(tile)
		tile.pressed.connect(_open_hire)
		_scout_tiles.append(tile)
	var selected := _select_scout()
	for card in _scout_cards:
		card.set_selected(card.scout_id() == _scout_id)
	_scout_panel.setup(selected, CareerScoutCard.status_for(selected) \
		if not selected.is_empty() else {}, _criteria_line(selected.get("task", {})))
	_layout()


func _refresh_tasks() -> void:
	var scouts := _scouts()
	for card in _task_cards:
		_task_grid.remove_child(card)
		card.queue_free()
	_task_cards.clear()
	for tile in _task_tiles:
		_task_grid.remove_child(tile)
		tile.queue_free()
	_task_tiles.clear()
	for scout in scouts:
		if not (scout is Dictionary):
			continue
		var data: Dictionary = scout
		var card := CareerScoutTaskCard.new()
		_task_grid.add_child(card)
		var task = data.get("task")
		var report = data.get("report")
		var found := ""
		var days := ""
		if task is Dictionary:
			found = "FOUND %d" % int((task as Dictionary).get("found_count", 0))
		if report is Dictionary:
			var left := int((report as Dictionary).get("days_left", 0))
			days = "%d %s LEFT" % [left, "DAY" if left == 1 else "DAYS"]
		card.setup(data, _task_title(data), _task_subtitle(data), found, days)
		card.pressed.connect(_open_task_card)
		card.focus_entered.connect(_on_task_focused.bind(card))
		_task_cards.append(card)
	var slots := int(snapshot.get("max_scouts", 6)) - scouts.size()
	for _slot in maxi(0, slots):
		var tile := CareerScoutCard.Empty.new()
		_task_grid.add_child(tile)
		tile.pressed.connect(_open_hire)
		_task_tiles.append(tile)
	var selected := _select_task_scout()
	for card in _task_cards:
		card.set_selected(card.scout_id() == _task_scout_id)
	_task_panel.setup(selected, _criteria_line(selected.get("task", {})))
	_layout()


# Map / network --------------------------------------------------------------

func _regions() -> Array:
	var regions = snapshot.get("regions", [])
	return regions if regions is Array else []


func _region() -> Dictionary:
	var regions := _regions()
	if regions.is_empty():
		return {}
	if _region_id.is_empty():
		_region_id = str((regions[0] as Dictionary).get("id", ""))
	for region in regions:
		if str((region as Dictionary).get("id", "")) == _region_id:
			return region
	return regions[0]


func _country() -> Dictionary:
	var region := _region()
	var countries = region.get("countries", [])
	if not (countries is Array) or (countries as Array).is_empty():
		return {}
	if _country_id.is_empty():
		_country_id = str((countries[0] as Dictionary).get("id", ""))
	for country in countries:
		if str((country as Dictionary).get("id", "")) == _country_id:
			return country
	_country_id = str((countries[0] as Dictionary).get("id", ""))
	return countries[0]


func _refresh_map() -> void:
	var region := _region()
	var country := _country()
	var leagues: Array = []
	if not country.is_empty() and catalog != null:
		leagues = catalog.leagues_for_country(int(country.get("id", 0)))
	_map.setup(view, _regions(), region, country, snapshot.get("networks", []),
		_scouts(), _assign_scout_id, leagues)
	_layout()


# Task editor ----------------------------------------------------------------

func _task_for(scout: Dictionary) -> Dictionary:
	var task = scout.get("task")
	return task if task is Dictionary else {}


func _refresh_task_editor() -> void:
	var scout := _scout(_task_scout)
	_task_editor.setup(_task_draft, _task_field, _task_range,
		str(scout.get("name", "")), _task_for(scout), _criteria_line(_task_draft))
	_layout()


# Reports --------------------------------------------------------------------

func _entries() -> Array:
	var feed = snapshot.get("feed", [])
	var reports = snapshot.get("reports", [])
	var source: Array = []
	if report_filter == "requests":
		source = reports if reports is Array else []
	else:
		source = feed if feed is Array else []
	var result: Array = []
	for entry in source:
		if not (entry is Dictionary):
			continue
		var player: Dictionary = (entry as Dictionary).get("player", {}) \
			if (entry as Dictionary).get("player") is Dictionary else {}
		if report_filter != "requests" and report_filter != "all" \
				and str(player.get("position_group", "")) != report_filter:
			continue
		if not _scout_filter.is_empty() \
				and str((entry as Dictionary).get("scout_id", "")) != _scout_filter:
			continue
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_date := str(a.get("date", ""))
		var right_date := str(b.get("date", ""))
		if left_date != right_date:
			return left_date > right_date
		var left: Dictionary = a.get("player", {}) if a.get("player") is Dictionary else {}
		var right: Dictionary = b.get("player", {}) if b.get("player") is Dictionary else {}
		return str(left.get("name", "")).to_lower() < str(right.get("name", "")).to_lower())
	return result


func _refresh_reports() -> void:
	var entries := _entries()
	if _entry_id.is_empty() and not entries.is_empty():
		_entry_id = _player_id(entries[0])
	_reports.setup(entries, REPORT_TABS, report_filter,
		str(_scout(_scout_filter).get("name", "")), career.date)
	_reports.select(_entry_id)
	_layout()


func _entry_for(player_id: String) -> Dictionary:
	for entry in _entries():
		if _player_id(entry) == player_id:
			return entry
	return {}


static func _player_id(entry: Dictionary) -> String:
	var player: Dictionary = entry.get("player", {}) if entry.get("player") is Dictionary \
		else {}
	return str(player.get("player_id", ""))


static func _criteria_line(criteria) -> String:
	if not (criteria is Dictionary):
		return ""
	return CareerScoutTaskPanel.criteria_line(criteria)


func _task_title(scout: Dictionary) -> String:
	var task = scout.get("task")
	if task is Dictionary:
		return "NETWORK IN %s" % str(
			(task as Dictionary).get("country_name", "")).to_upper()
	if scout.get("report") is Dictionary:
		return "REPORT REQUEST"
	return "ADD A NEW TASK"


func _task_subtitle(scout: Dictionary) -> String:
	var task = scout.get("task")
	if task is Dictionary:
		return _criteria_line((task as Dictionary).get("criteria", {}))
	var report = scout.get("report")
	if report is Dictionary:
		return "Watching %s" % str((report as Dictionary).get("player_name", ""))
	return "Choose a search region"


# Focus ----------------------------------------------------------------------

func _focus(control: Control) -> void:
	if control != null:
		control.grab_focus()


func _focus_by_id(id: String) -> bool:
	for item in _focusables():
		if _id_of(item) == id:
			_focus(item)
			return true
	return false


func _id_of(control: Control) -> String:
	if control is CareerScoutCard:
		return "scout:" + (control as CareerScoutCard).scout_id()
	if control is CareerScoutTaskCard:
		return "scout:" + (control as CareerScoutTaskCard).scout_id()
	if control is CareerScoutReportCard:
		return "entry:" + (control as CareerScoutReportCard).player_id()
	if control == _task_action:
		return "action"
	return ""


func _focusables() -> Array[Control]:
	var list: Array[Control] = []
	match view:
		"scouts":
			list.append_array(_scout_cards)
			list.append_array(_scout_tiles)
		"tasks":
			list.append_array(_task_cards)
			list.append_array(_task_tiles)
			if _task_action.visible:
				list.append(_task_action)
		"region", "country":
			list.append_array(_map.map_nodes())
			list.append_array(_map.side_rows())
			list.append(_map.next_button())
		"task":
			list.append_array(_task_editor.focusables())
		"reports":
			list.append_array(_reports.tab_buttons())
			list.append_array(_reports.entry_cards())
	return list


func _focus_first_scout() -> void:
	if _focus_by_id("scout:" + _scout_id):
		return
	var list := _focusables()
	if not list.is_empty():
		_focus(list[0])


func _focus_first_task() -> void:
	if _focus_by_id("scout:" + _task_scout_id):
		return
	var list := _focusables()
	if not list.is_empty():
		_focus(list[0])


func _focus_first_map() -> void:
	var list := _focusables()
	if not list.is_empty():
		_focus(list[0])


func _focus_first_editor() -> void:
	var list := _focusables()
	if not list.is_empty():
		_focus(list[0])


func _focus_reports_initial() -> void:
	if not _entry_id.is_empty() and _focus_by_id("entry:" + _entry_id):
		return
	var cards := _reports.entry_cards()
	if not cards.is_empty():
		_focus(cards[0])
		return
	var tabs := _reports.tab_buttons()
	if not tabs.is_empty():
		_focus(tabs[mini(_reports.active_tab(), tabs.size() - 1)])


func _focus_grid_item(items: Array, direction: Vector2i) -> bool:
	var focus := _focus_owner()
	var index := items.find(focus)
	if index < 0:
		return false
	match direction:
		Vector2i.LEFT:
			if index % COLUMNS == 0:
				return false
			index -= 1
		Vector2i.RIGHT:
			if index % COLUMNS == COLUMNS - 1 or index + 1 >= items.size():
				return false
			index += 1
		Vector2i.UP:
			if index < COLUMNS:
				return false
			index -= COLUMNS
		Vector2i.DOWN:
			if index + COLUMNS >= items.size():
				return false
			index += COLUMNS
		_:
			return false
	_focus(items[index])
	return true


func _focus_linear(items: Array, direction: Vector2i) -> void:
	if items.is_empty():
		return
	var focus := _focus_owner()
	var index := items.find(focus)
	if index < 0:
		_focus(items[0])
		return
	var step := -1 if direction == Vector2i.LEFT or direction == Vector2i.UP else 1
	_focus(items[clampi(index + step, 0, items.size() - 1)])


# Input ----------------------------------------------------------------------

func _is_active() -> bool:
	if not _open or not is_visible_in_tree():
		return false
	var nav := _ui_nav()
	return nav == null or not nav.is_modal()


func _connect_nav() -> void:
	var nav := _ui_nav()
	if nav == null:
		return
	nav.moved.connect(_on_nav_moved)
	nav.confirmed.connect(_on_nav_confirmed)
	nav.cancelled.connect(_on_nav_cancelled)
	nav.tab_previous.connect(_on_tab_previous)
	nav.tab_next.connect(_on_tab_next)


func _on_nav_moved(direction: Vector2i) -> void:
	if _confirm.is_open():
		_confirm.move_focus(direction)
		return
	if not _is_active():
		return
	var owner := _focus_owner()
	if owner != null and _tabs.visible and _tabs.is_ancestor_of(owner):
		# The network strip is part of the navigation: sideways pages its tabs,
		# Down drops into the content. It never leaves the screen.
		if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
			_handle_tabs(-1 if direction == Vector2i.LEFT else 1)
		elif direction == Vector2i.DOWN:
			focus_initial()
		return
	match view:
		"scouts":
			var items: Array = _scout_cards + _scout_tiles
			var index := items.find(owner)
			if direction == Vector2i.UP and index >= 0 and index < COLUMNS:
				_focus_active_tab()
			else:
				_focus_grid_item(items, direction)
		"tasks":
			var task_items: Array = _task_cards + _task_tiles
			var task_index := task_items.find(owner)
			if direction == Vector2i.UP and task_index >= 0 and task_index < COLUMNS:
				_focus_active_tab()
			else:
				_move_tasks(direction)
		"region", "country":
			_focus_linear(_focusables(), direction)
		"task":
			_move_task(direction)
		"reports":
			_move_reports(direction)


func _move_tasks(direction: Vector2i) -> void:
	var items: Array = _task_cards + _task_tiles
	if _focus_owner() == _task_action:
		if direction == Vector2i.LEFT or direction == Vector2i.UP:
			var target := items.find(_task_card(_task_scout_id))
			_focus(items[maxi(0, target)] if not items.is_empty() else _task_action)
		return
	if _focus_grid_item(items, direction):
		return
	if direction == Vector2i.RIGHT and _task_action.visible:
		var index := items.find(_focus_owner())
		if index >= 0 and (index % COLUMNS == COLUMNS - 1 or index == items.size() - 1):
			_focus(_task_action)


func _task_card(scout_id: String) -> Control:
	for card in _task_cards:
		if (card as CareerScoutTaskCard).scout_id() == scout_id:
			return card
	return null


func _move_task(direction: Vector2i) -> void:
	if not _task_field.is_empty():
		_step_field(direction)
		return
	var cells := _task_editor.focusables()
	var focus := _focus_owner()
	if focus == _task_action:
		if direction == Vector2i.UP or direction == Vector2i.LEFT:
			_focus(cells[maxi(0, cells.size() - 2)])
		return
	var index := cells.find(focus)
	if index < 0:
		_focus(cells[0])
		return
	match direction:
		Vector2i.LEFT:
			if index % 2 == 1:
				_focus(cells[index - 1])
		Vector2i.RIGHT:
			if index % 2 == 0 and index + 1 < cells.size() - 1:
				_focus(cells[index + 1])
		Vector2i.UP:
			if index >= 2:
				_focus(cells[index - 2])
		Vector2i.DOWN:
			if index < 2:
				_focus(cells[index + 2])
			elif cells.size() > 4:
				_focus(_task_action)


func _move_reports(direction: Vector2i) -> void:
	var tabs := _reports.tab_buttons()
	var cards := _reports.entry_cards()
	var focus := _focus_owner()
	if tabs.has(focus):
		if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
			var index := clampi(tabs.find(focus) + (-1 if direction == Vector2i.LEFT else 1),
				0, tabs.size() - 1)
			_reports.select_tab_index(index)
		elif direction == Vector2i.DOWN and not cards.is_empty():
			_focus(cards[0])
		return
	if not cards.has(focus):
		return
	var index := cards.find(focus)
	match direction:
		Vector2i.UP:
			if index < COLUMNS:
				_focus(tabs[mini(_reports.active_tab(), tabs.size() - 1)])
			else:
				_focus(cards[index - COLUMNS])
		Vector2i.DOWN:
			_focus(cards[mini(index + COLUMNS, cards.size() - 1)])
		Vector2i.LEFT:
			_focus(cards[maxi(0, index - 1)])
		Vector2i.RIGHT:
			_focus(cards[mini(index + 1, cards.size() - 1)])


func _on_nav_confirmed() -> void:
	if _confirm.is_open():
		_confirm.activate_focused()
		return
	if not _is_active():
		return
	var owner := _focus_owner()
	if owner != null and _tabs.visible and _tabs.is_ancestor_of(owner):
		focus_initial()
		return
	var focus := _focus_owner()
	if focus == null or not _focusables().has(focus):
		_restore_focus()
		return
	match view:
		"scouts":
			if focus is CareerScoutCard:
				_open_scout((focus as CareerScoutCard).scout_id())
			else:
				_open_hire()
		"tasks":
			if focus is CareerScoutTaskCard:
				_open_task_card((focus as CareerScoutTaskCard).scout_id())
			elif focus == _task_action:
				_on_task_reports_requested()
			else:
				_open_hire()
		"region", "country":
			_confirm_map(focus)
		"task":
			if focus == _task_action:
				_open_task_editor_reports()
			elif focus is CareerScoutTaskEditor.Cell:
				_on_task_field_selected((focus as CareerScoutTaskEditor.Cell).id)
		"reports":
			if focus is CareerScoutReportCard:
				_open_report_modal((focus as CareerScoutReportCard).player_id())
			elif focus is Button:
				(focus as Button).pressed.emit()


func _on_nav_cancelled() -> void:
	if _confirm.is_open():
		_confirm.close()
		return
	if not _is_active() or _event_was_modal():
		return
	_back()


func _back() -> void:
	match view:
		"region":
			_go("scouts")
		"country":
			_go("region")
		"task":
			if not _task_field.is_empty():
				_task_field = ""
				_refresh()
				_focus_first_editor()
				return
			_save_task()
			_go("tasks")
		"reports":
			if _reports_return == "close":
				closed.emit()
			else:
				_go(network_tab)
		_:
			closed.emit()


func _input(event: InputEvent) -> void:
	if not _open or not is_visible_in_tree() or _confirm.is_open():
		return
	var nav := _ui_nav()
	if nav != null and nav.is_modal() \
			and not (_report_modal.is_open() and nav.modal_owner() == _report_modal):
		return
	if _is_key(event, KEY_Q):
		get_viewport().set_input_as_handled()
		_handle_tabs(-1)
		return
	if _is_key(event, KEY_E):
		get_viewport().set_input_as_handled()
		_handle_tabs(1)
		return
	if _is_key(event, KEY_X) or _is_button(event, JOY_BUTTON_X):
		get_viewport().set_input_as_handled()
		if view == "reports" and _report_modal.is_open():
			_remove_entry(_entry_id)
		elif view == "task":
			_reset_task_draft()
		return
	if _is_key(event, KEY_Y) or _is_key(event, KEY_W) \
			or _is_button(event, JOY_BUTTON_Y):
		get_viewport().set_input_as_handled()
		if view == "scouts" or view == "tasks":
			_open_scout_actions(_scout_id if view == "scouts" else _task_scout_id)


func _is_key(event: InputEvent, code: Key) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == code or key.physical_keycode == code)


func _is_button(event: InputEvent, button: JoyButton) -> bool:
	if not (event is InputEventJoypadButton):
		return false
	var joy := event as InputEventJoypadButton
	return joy.pressed and joy.button_index == button


func _event_was_modal() -> bool:
	var nav := _ui_nav()
	return nav != null and bool(nav.event_was_modal())


func _focus_owner() -> Control:
	var viewport := get_viewport()
	return viewport.gui_get_focus_owner() if viewport != null else null


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


# Tabs -----------------------------------------------------------------------

func _on_tab_previous() -> void:
	_handle_tabs(-1)


func _on_tab_next() -> void:
	_handle_tabs(1)


func _handle_tabs(delta: int) -> void:
	if not _is_active():
		return
	if view == "scouts" or view == "tasks":
		var owner := _focus_owner()
		var was_tab := owner != null and _tabs.visible and _tabs.is_ancestor_of(owner)
		network_tab = "tasks" if network_tab == "scouts" else "scouts"
		_go(network_tab)
		if was_tab:
			_focus_active_tab()
	elif view == "reports":
		var index := 0
		for cursor in REPORT_TABS.size():
			if str((REPORT_TABS[cursor] as Dictionary).get("id", "")) == report_filter:
				index = cursor
		index = posmod(index + delta, REPORT_TABS.size())
		_on_report_filter(str((REPORT_TABS[index] as Dictionary).get("id", "all")))


func _focus_active_tab() -> void:
	_tabs.focus_tab(maxi(0, NETWORK_IDS.find(network_tab)))


func _on_network_tab_selected(index: int) -> void:
	if index == NETWORK_IDS.find(network_tab):
		return
	network_tab = NETWORK_IDS[clampi(index, 0, NETWORK_IDS.size() - 1)]
	_go(network_tab)
	# A click from the strip keeps the strip focused, like the main hub tabs.
	_tabs.focus_tab(clampi(index, 0, NETWORK_IDS.size() - 1))


# Scout actions --------------------------------------------------------------

func _on_scout_focused(card: CareerScoutCard) -> void:
	_scout_id = card.scout_id()
	for other in _scout_cards:
		(other as CareerScoutCard).set_selected(other == card)
	var scout := _scout(_scout_id)
	_scout_panel.setup(scout, CareerScoutCard.status_for(scout) \
		if not scout.is_empty() else {}, "")


func _on_task_focused(card: CareerScoutTaskCard) -> void:
	_task_scout_id = card.scout_id()
	for other in _task_cards:
		(other as CareerScoutTaskCard).set_selected(other == card)
	var scout := _scout(_task_scout_id)
	_task_panel.setup(scout, _criteria_line(scout.get("task", {})))


func _open_scout(scout_id: String) -> void:
	var scout := _scout(scout_id)
	if scout.is_empty():
		return
	_scout_id = scout_id
	var report = scout.get("report")
	var task = scout.get("task")
	if report is Dictionary:
		_open_reports("requests", str((report as Dictionary).get("player_id", "")),
			scout_id, network_tab)
		return
	if task is Dictionary:
		_open_reports("all", "", scout_id, network_tab)
		return
	_start_assign(scout_id)


func _open_task_card(scout_id: String) -> void:
	var scout := _scout(scout_id)
	if scout.is_empty():
		return
	_task_scout_id = scout_id
	var task = scout.get("task")
	if task is Dictionary:
		_open_task_editor(scout)
		return
	var report = scout.get("report")
	if report is Dictionary:
		_open_reports("requests", str((report as Dictionary).get("player_id", "")),
			scout_id, "tasks")
		return
	_start_assign(scout_id)


func _open_scout_actions(scout_id: String) -> void:
	var scout := _scout(scout_id)
	if scout.is_empty():
		return
	_scout_id = scout_id
	_scout_actions.setup_scout(scout, _scout_has_report(scout),
		scout.get("task") is Dictionary or scout.get("report") is Dictionary)
	_scout_actions.open()
	state_changed.emit()


func _scout_has_report(scout: Dictionary) -> bool:
	if scout.get("task") is Dictionary:
		return true
	var scout_id := str(scout.get("id", ""))
	for entry in snapshot.get("feed", []):
		if entry is Dictionary and str((entry as Dictionary).get("scout_id", "")) == scout_id:
			return true
	return false


func _on_scout_action(id: String) -> void:
	var scout := _scout(_scout_id)
	_scout_actions.close()
	if scout.is_empty():
		return
	match id:
		"report":
			_open_reports("all", "", _scout_id, network_tab)
		"move":
			_start_assign(_scout_id)
		"recall":
			_after_action(CareerScouting.recall(career, _scout_id))
		"dismiss":
			_ask("%s will leave your staff. Are you sure?" % str(scout.get("name", "")),
				func() -> void:
					_after_action(CareerScouting.dismiss(career, _scout_id)),
				"DISMISS SCOUT")
		_:
			pass


func _open_hire() -> void:
	if _scouts().size() >= int(snapshot.get("max_scouts", 6)):
		_error = "all scout slots are occupied"
		_settle()
		return
	var candidates = snapshot.get("candidates", [])
	if not (candidates is Array) or (candidates as Array).is_empty():
		_error = "no scouts are available"
		_settle()
		return
	_hire_modal.setup_candidates(candidates, _balance())
	_hire_modal.open()
	state_changed.emit()


func _on_hire_requested(scout_id: String) -> void:
	var candidate := {}
	for item in snapshot.get("candidates", []):
		if item is Dictionary and str((item as Dictionary).get("id", "")) == scout_id:
			candidate = item
			break
	if candidate.is_empty():
		return
	_hire_modal.close()
	if not bool(candidate.get("affordable", true)):
		_error = "not enough money to hire this scout"
		_settle()
		return
	_ask("%s will become your new scout. Are you sure?" % str(candidate.get("name", "")),
		func() -> void:
			_after_action(CareerScouting.hire(career, scout_id)),
		"HIRE SCOUT")


func _balance() -> int:
	if career == null or career.balance == null:
		return 0
	return int(career.balance)


# Network --------------------------------------------------------------------

func _start_assign(scout_id: String) -> void:
	_assign_scout_id = scout_id
	_region_id = str(_region().get("id", ""))
	_country_id = ""
	_go("region")


func _on_region_focused(id: String) -> void:
	_region_id = id
	_country_id = ""
	_refresh_map()
	_restore_focus()


func _on_region_selected(id: String) -> void:
	_region_id = id
	_country_id = ""
	_go("country")


func _on_country_focused(id: String) -> void:
	_country_id = id
	_refresh_map()
	_restore_focus()


func _on_country_selected(id: String) -> void:
	_country_id = id
	_refresh_map()
	_restore_focus()


func _on_map_next() -> void:
	if view == "region":
		_go("country")
		return
	var country := _country()
	if country.is_empty():
		return
	_ask("Set up a scouting network in %s?" % str(country.get("name", "")),
		func() -> void:
			_after_action(CareerScouting.network(career, catalog, _assign_scout_id,
				_region_id, str(country.get("id", ""))), "tasks"),
		"SET UP NETWORK")


func _confirm_map(focus: Control) -> void:
	if _map.map_nodes().has(focus):
		if view == "region":
			_on_region_selected(_node_id(focus))
		else:
			_on_country_selected(_node_id(focus))
		return
	if _map.side_rows().has(focus):
		_on_country_selected(_node_id(focus))
		return
	if focus == _map.next_button():
		_on_map_next()


static func _node_id(node: Control) -> String:
	return str(node.get("id"))


# Task editor ----------------------------------------------------------------

func _open_task_editor(scout: Dictionary) -> void:
	_task_scout = str(scout.get("id", ""))
	var task := _task_for(scout)
	var criteria = task.get("criteria")
	_task_draft = CareerScouting.normalize_criteria(criteria) if criteria != null \
		else CareerScouting.default_criteria()
	_task_field = ""
	_task_range = "min"
	_task_saved = true
	_go("task")


func _on_task_field_selected(id: String) -> void:
	if id != "role" and id != "age" and id != "contract":
		return
	if _task_field == id:
		_task_field = ""
	else:
		_task_field = id
		_task_range = "min"
	_refresh_task_editor()


func _step_field(direction: Vector2i) -> void:
	if _task_field == "role":
		if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
			_step_role(-1 if direction == Vector2i.LEFT else 1)
		return
	if direction == Vector2i.UP or direction == Vector2i.DOWN:
		_task_range = "max" if _task_range == "min" else "min"
		_refresh_task_editor()
		return
	_step_range(-1 if direction == Vector2i.LEFT else 1)


func _step_role(delta: int) -> void:
	var index := TASK_ROLES.find(str(_task_draft.get("role", "")))
	index = posmod(index + delta, TASK_ROLES.size())
	_task_draft["role"] = TASK_ROLES[index]
	_task_saved = false
	_refresh_task_editor()


func _step_range(delta: int) -> void:
	var bounds := [int(snapshot.get("age_min", 16)), int(snapshot.get("age_max", 35))] \
		if _task_field == "age" \
		else [int(snapshot.get("contract_min", 0)), int(snapshot.get("contract_max", 5))]
	var minimum_key := "%s_min" % _task_field
	var maximum_key := "%s_max" % _task_field
	var key := minimum_key if _task_range == "min" else maximum_key
	var current = _task_draft.get(key)
	var next
	if current == null:
		next = bounds[0] if delta > 0 else bounds[1]
	else:
		next = int(current) + delta
		if next < int(bounds[0]) or next > int(bounds[1]):
			next = null
	_task_draft[key] = next
	var low = _task_draft.get(minimum_key)
	var high = _task_draft.get(maximum_key)
	if low != null and high != null and int(low) > int(high):
		if _task_range == "min":
			_task_draft[maximum_key] = low
		else:
			_task_draft[minimum_key] = high
	_task_saved = false
	_refresh_task_editor()


func _reset_task_draft() -> void:
	_task_draft = CareerScouting.default_criteria()
	_task_field = ""
	_task_saved = false
	_refresh_task_editor()


func _save_task() -> void:
	if _task_scout.is_empty() or _task_saved:
		return
	var result := CareerScouting.set_task(career, _task_scout, _task_draft)
	if bool(result.get("ok", false)):
		_task_saved = true
		changed.emit()
		snapshot = _snapshot()
	else:
		_error = str(result.get("error", ""))
		_refresh_error()


func _open_task_editor_reports() -> void:
	_save_task()
	_open_reports("all", "", _task_scout, "tasks")


func _on_task_editor_reports() -> void:
	_open_task_editor_reports()


func _on_task_reports_requested() -> void:
	_open_reports("all", "", _task_scout_id, "tasks")


# Reports --------------------------------------------------------------------

func _open_reports(filter: String, entry_id: String, scout_id: String,
		return_to: String) -> void:
	report_filter = filter
	_entry_id = entry_id
	_scout_filter = scout_id
	_reports_return = return_to if not return_to.is_empty() else "network"
	view = "reports"
	_error = ""
	_switch_body()
	_refresh()
	_focus_reports_initial()
	_animate_body()
	_acknowledge()
	state_changed.emit()


func _acknowledge() -> void:
	if career == null:
		return
	var counts = snapshot.get("counts", {})
	if int((counts as Dictionary).get("new", 0)) <= 0:
		return
	CareerScouting.ack(career)
	# The snapshot in hand keeps its flags so the NEW markers stay visible until
	# the feed is rebuilt by a later action (the prototype acknowledges on entry
	# too, which hid them immediately вЂ” this keeps the marker design visible).
	changed.emit()


func _on_report_filter(id: String) -> void:
	report_filter = id
	_entry_id = ""
	_refresh_reports()
	_focus_reports_tab(_report_tab_index(id))


func _report_tab_index(id: String) -> int:
	for index in REPORT_TABS.size():
		if str((REPORT_TABS[index] as Dictionary).get("id", "")) == id:
			return index
	return 0


func _focus_reports_tab(index: int) -> void:
	var tabs := _reports.tab_buttons()
	if index >= 0 and index < tabs.size():
		_focus(tabs[index])


func _on_entry_focused(player_id: String) -> void:
	_entry_id = player_id
	_reports.select(player_id)


func _open_report_modal(player_id: String) -> void:
	var entry := _entry_for(player_id)
	if entry.is_empty():
		return
	var player: Dictionary = entry.get("player", {}) \
		if entry.get("player") is Dictionary else {}
	if player.is_empty():
		return
	_entry_id = player_id
	_reports.select(player_id)
	var pane := CareerPlayerPane.new()
	_report_modal.setup("SCOUT REPORT",
		"%s · %s · %s" % [
			"SCOUT REPORT READY" if str(entry.get("kind", "")) == "report" \
				else "PLAYER FOUND",
			str(entry.get("scout_name", "")),
			CareerScoutReportsFeed._date_label(str(entry.get("date", "")))],
		[])
	_report_modal.set_content(pane)
	# The report card shows the whole player at once (the prototype's scouting
	# modal has no scroll here): without a scrolling axis the pane reports its
	# full height and the shell sizes the card from it.
	pane.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.setup(player, {
		"action_rows": _report_rows(player),
		"show_actions": true,
		"date": career.date,
	})
	pane.action_chosen.connect(_on_report_action.bind(player_id))
	_report_modal.open()
	state_changed.emit()


func _report_rows(player: Dictionary) -> Array:
	var rows: Array = []
	if not str(player.get("club_id", "")).is_empty():
		rows.append({"id": "offer_transfer", "label": "MAKE TRANSFER OFFER"})
		rows.append({"id": "offer_loan", "label": "MAKE LOAN OFFER"})
	var can_discuss := career != null and catalog != null \
		and CareerTransferContracts.can_discuss(catalog, career, player)
	_report_can_discuss = can_discuss
	rows.append({"id": "discuss", "label": "DISCUSS MOVE",
		"key": "" if can_discuss else "NOT EXPIRING"})
	rows.append({"id": "remove", "label": "REMOVE FROM REPORT"})
	rows.append({"id": "close", "label": "CLOSE"})
	return rows


func _on_report_action(id: String, player_id: String) -> void:
	_report_modal.close()
	match id:
		"offer_transfer":
			navigate.emit("offer", {"player_id": player_id, "kind": "transfer",
				"preset": CareerTransferOffers.proposal(career, catalog, player_id,
					"transfer")})
		"offer_loan":
			navigate.emit("offer", {"player_id": player_id, "kind": "loan",
				"preset": CareerTransferOffers.proposal(career, catalog, player_id,
					"loan")})
		"discuss":
			if _report_can_discuss:
				navigate.emit("contract", {"player_id": player_id})
			else:
				_error = "contract talks are only available for free agents or expiring contracts"
				_settle()
		"remove":
			_remove_entry(player_id)


func _remove_entry(player_id: String) -> void:
	if player_id.is_empty():
		return
	_report_modal.close()
	_entry_id = ""
	_after_action(CareerScouting.remove(career, player_id))


# Shared action plumbing -----------------------------------------------------

# The confirmation is the design system's UiModal (the same plate the career
# load screen uses for "delete career"): a message and two full-width rows.
func _ask(message: String, action: Callable, confirm_label := "YES") -> void:
	_pending = action
	var gamepad := false
	var nav := _ui_nav()
	if nav != null:
		gamepad = nav.using_gamepad()
	CareerScoutingModal.host_overlay(_confirm)
	_confirm.open(message, [
		{"id": "yes", "label": confirm_label, "key": "A" if gamepad else "ENTER"},
		{"id": "cancel", "label": "CANCEL", "key": "B" if gamepad else "ESC"},
	])
	if nav != null:
		nav.push_modal(_confirm)
	state_changed.emit()


func _on_confirm_action(id: String) -> void:
	_confirm.close()
	if id != "yes":
		_pending = Callable()
		return
	var action := _pending
	_pending = Callable()
	if action.is_valid():
		action.call()


func _on_confirm_closed() -> void:
	var nav := _ui_nav()
	if nav != null:
		nav.pop_modal(_confirm)
	_on_modal_closed()


func _after_action(result: Dictionary, next_view := "") -> void:
	if not bool(result.get("ok", false)):
		_error = str(result.get("error", ""))
		_settle()
		return
	_error = ""
	_task_saved = true
	if not next_view.is_empty():
		network_tab = next_view
	snapshot = _snapshot()
	changed.emit()
	if next_view == "tasks":
		_task_scout_id = _assign_scout_id
		_go("tasks")
		return
	_refresh()
	_restore_focus()


func _settle() -> void:
	_refresh_error()
	_layout()


func _restore_focus() -> void:
	var owner := _focus_owner()
	if owner != null and is_ancestor_of(owner) and owner.is_visible_in_tree():
		return
	match view:
		"scouts":
			_focus_first_scout()
		"tasks":
			_focus_first_task()
		"region", "country":
			_focus_first_map()
		"task":
			_focus_first_editor()
		"reports":
			_focus_reports_initial()


func _on_modal_closed() -> void:
	state_changed.emit()
	_restore_focus()


func _club_name_of_career() -> String:
	if catalog == null or career == null:
		return ""
	return str(catalog.career_club(int(career.club_id)).get("name", ""))

