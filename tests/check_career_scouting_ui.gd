extends SceneTree
# Headless check for the scouting screen (ticket 09 UI): the scouts grid and its
# panel, the tabs, hiring/dismissing through the action modals, the region в†’
# country network flow, the task editor values and the reports feed with its
# player report modal and offer/contract routes.
#
# Run:  godot --headless --path . -s res://tests/check_career_scouting_ui.gd

const WIDTH := 1480.0
const HEIGHT := 688.0

var failures: Array[String] = []
var _changed := 0
var _closed := 0
var _routes: Array[Dictionary] = []
var _screen: CareerScoutingView
var _nav: Node


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _finish() -> void:
	print("== check_career_scouting_ui: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _career(catalog: TeamCatalog) -> Career:
	var career := CareerFactory.create(catalog, 131, "Network Manager", 189, 42)
	if career == null:
		return null
	CareerScouting.ensure_scouts(career)
	return career


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := _career(catalog)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nav = root.get_node("UiNav")

	_screen = CareerScoutingView.new()
	_screen.position = Vector2(128.0, 120.0)
	_screen.size = Vector2(WIDTH, HEIGHT)
	host.add_child(_screen)
	_screen.navigate.connect(func(view: String, payload: Dictionary) -> void:
		_routes.append({"view": view, "payload": payload}))
	_screen.changed.connect(func() -> void: _changed += 1)
	_screen.closed.connect(func() -> void: _closed += 1)
	await _frames(2)

	_screen.open(career, catalog, {})
	await _frames(2)

	# Scouts ------------------------------------------------------------------
	_check(_screen.view == "scouts", "the screen opens on the scouts tab")
	_check((_screen.get("_scout_cards") as Array).size() == 2,
		"the two starting scouts are on the grid")
	_check((_screen.get("_scout_tiles") as Array).size() == 4,
		"the empty slots fill the rest of the grid")
	_check((_screen.get("_scout_panel") as Control).visible,
		"the scout panel is shown")
	_check(_screen.hints().size() == 5, "the scouts tab hints five controls")
	var cards: Array = _screen.get("_scout_cards")
	_check(cards[0].has_focus(), "the first scout takes focus")
	_check((cards[0] as CareerScoutCard).size.x > 100.0, "the tiles are laid out")
	_check(cards[1].position.x > cards[0].position.x,
		"the grid puts the scouts side by side")

	# Tabs --------------------------------------------------------------------
	_nav.tab_next.emit()
	await _frames(2)
	_check(_screen.view == "tasks", "Tab switches to the task board")
	_check((_screen.get("_task_cards") as Array).size() == 2, "the task board lists the scouts")
	var task_panel: CareerScoutTaskPanel = _screen.get("_task_panel")
	_check(task_panel.visible, "the task panel is shown")
	_nav.tab_previous.emit()
	await _frames(2)
	_check(_screen.view == "scouts", "Tab switches back to the scouts")
	# Q/E page the network tabs, like the hub/centre.
	var e_key := InputEventKey.new()
	e_key.keycode = KEY_E
	e_key.physical_keycode = KEY_E
	e_key.pressed = true
	_screen.call("_input", e_key)
	await _frames(2)
	_check(_screen.view == "tasks", "E switches the network tab")
	var q_key := InputEventKey.new()
	q_key.keycode = KEY_Q
	q_key.physical_keycode = KEY_Q
	q_key.pressed = true
	_screen.call("_input", q_key)
	await _frames(2)
	_check(_screen.view == "scouts", "Q switches back")
	# The strip is part of the navigation: sideways pages it, Up leaves the
	# content for it, Down drops back into the content.
	var tabs: UiTabBar = _screen.get("_tabs")
	tabs.focus_tab(0)
	await _frames(2)
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(2)
	_check(_screen.view == "tasks" and tabs.get_tab_button(1).has_focus(),
		"Right on the network strip pages the tabs and keeps the strip")
	_nav.moved.emit(Vector2i.LEFT)
	await _frames(2)
	_check(_screen.view == "scouts" and tabs.get_tab_button(0).has_focus(),
		"Left pages back")
	_nav.moved.emit(Vector2i.DOWN)
	await _frames(2)
	_check(cards[0].has_focus(), "Down from the strip enters the content")
	_nav.moved.emit(Vector2i.UP)
	await _frames(2)
	_check(tabs.get_tab_button(0).has_focus(), "Up from the top row reaches the strip")
	# The marker travels on a click (no layout re-fit snaps it).
	var marker: Control = tabs.get("_marker")
	tabs.get_tab_button(1).pressed.emit()
	await _frames(1)
	_check(marker.position.x > 1.0, "the network marker starts travelling")
	await create_timer(0.35).timeout
	_check(absf(marker.position.x - tabs.get_tab_button(1).position.x) < 0.5,
		"the network marker reaches the tab")
	tabs.get_tab_button(0).pressed.emit()
	await _frames(2)
	_check(_screen.view == "scouts", "the click switches back for the rest of the pass")

	# Hire --------------------------------------------------------------------
	var before: int = int(career.balance)
	_screen.call("_open_hire")
	await _frames(2)
	var hire: CareerScoutHireModal = _screen.get("_hire_modal")
	_check(hire.is_open(), "an empty slot opens the hire modal")
	_check(_nav.is_modal() and _nav.modal_owner() == hire, "the hire modal owns input")
	_check(hire.candidate_ids().size() > 0, "the hire modal lists candidates")
	# The card is one column: title, list and rows must not sit on another's rect,
	# and the card ends where its content ends (no leftover strip at the bottom).
	var hire_card: Control = hire.get_node("Card")
	var hire_box: Control = hire_card.get_node("Box")
	var hire_content: Control = hire.get_node("Card/Box/Content")
	_check(hire_box.get_child_count() >= 2, "the hire card stacks head and content")
	_check(hire_content.get_rect().position.y
		>= hire.get_node("Card/Box/Head").get_rect().end.y,
		"the hire list starts below the title")
	_check(absf(hire_card.size.y - hire_card.get_combined_minimum_size().y) < 1.0,
		"the hire card is as tall as its content")
	var hire_list: Control = hire_content.get_child(0)
	_check(hire_list.get_global_rect().end.y <= hire_card.get_global_rect().end.y - 15.0,
		"the last hire row keeps the same inset at the bottom as at the sides")
	_check(hire.get_node("Scrim").size == hire.size,
		"the hire scrim covers the whole screen")
	var candidate_id := str(hire.candidate_ids()[0])
	_nav.confirmed.emit()
	await _frames(2)
	var confirm = _screen.get("_confirm")
	_check(confirm.is_open(), "hiring asks for confirmation")
	_check(_nav.modal_owner() == confirm, "the confirmation owns input")
	_check(_screen.hints().size() == 3, "the confirmation hints choose / confirm / cancel")
	_nav.cancelled.emit()
	await _frames(2)
	_check(not confirm.is_open(), "back cancels the confirmation")
	_check(not _nav.is_modal(), "the modal stack is empty after the cancel")
	_check(not hire.is_open(), "the hire modal stays closed after the cancel")
	_check((_screen.get("_scout_cards") as Array).size() == 2, "nobody was hired by the cancel")

	_screen.call("_open_hire")
	await _frames(2)
	_nav.confirmed.emit()
	await _frames(2)
	_nav.confirmed.emit()
	await _frames(2)
	var scouts: Array = _screen.get("snapshot").get("scouts", [])
	_check(scouts.size() == 3, "confirming the hire adds a scout")
	_check(career.balance < before, "the scout fee is paid")
	_check((_screen.get("_scout_cards") as Array).size() == 3, "the grid shows the new scout")
	_check((_screen.get("_scout_tiles") as Array).size() == 3, "one empty slot is consumed")
	_check(_changed >= 1, "the hire reports the career change")

	# Scout actions: dismiss --------------------------------------------------
	_screen.call("_open_scout_actions", candidate_id)
	await _frames(2)
	var actions: CareerScoutActionsModal = _screen.get("_scout_actions")
	_check(actions.is_open(), "the scout actions modal opens")
	_check(actions.row_ids() == ["report", "move", "recall", "dismiss", "cancel"],
		"the actions list view/move/recall/dismiss/cancel")
	_check(not actions.row_enabled("report"), "a scout without reports cannot show one")
	_check(not actions.row_enabled("recall"), "a free scout cannot be recalled")
	var dismiss: int = actions.row_ids().find("dismiss")
	for index in dismiss:
		_nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_nav.confirmed.emit()
	await _frames(2)
	_check(confirm.is_open(), "dismissing asks for confirmation")
	_check(_screen.hints().size() == 3, "the modal hints three controls")
	_nav.confirmed.emit()
	await _frames(2)
	scouts = _screen.get("snapshot").get("scouts", [])
	_check(scouts.size() == 2, "confirming the dismissal removes the scout")
	_check((_screen.get("_scout_tiles") as Array).size() == 4, "the slot is free again")

	# Network setup -----------------------------------------------------------
	var scout_id := str((scouts[0] as Dictionary).get("id", ""))
	_screen.call("_start_assign", scout_id)
	await _frames(2)
	_check(_screen.view == "region", "sending a scout opens the region map")
	var map: CareerScoutMapPanel = _screen.get("_map")
	_check(map.step() == "region", "the map starts on the region step")
	_check(map.map_nodes().size() == CareerScouting.regions(catalog).size(),
		"every region has a node")
	_check(_screen.hints().size() == 3, "the map hints three controls")
	_check(map.map_nodes()[0].has_focus(), "the first region takes focus")
	_nav.confirmed.emit()
	await _frames(2)
	_check(_screen.view == "country", "choosing a region opens the country step")
	_check(map.step() == "country", "the map is on the country step")
	_check(map.map_nodes().size() > 0, "the region lists its countries")
	_check(map.side_rows().size() == 0, "the country step side list holds leagues, not rows")
	_screen.call("_focus", map.next_button())
	_check(map.next_button().has_focus(), "the action row takes focus")
	_nav.confirmed.emit()
	await _frames(2)
	_check(confirm.is_open(), "the network asks for confirmation")
	_nav.confirmed.emit()
	await _frames(2)
	_check(_screen.view == "tasks", "setting up the network returns to the task board")
	var tasks: Array = _screen.get("snapshot").get("tasks", [])
	_check(tasks.size() == 1, "the scout now has a network task")
	_check(_screen.snapshot.get("networks", []).size() == 1, "the network is saved")
	_check((_screen.get("snapshot").get("counts", {}) as Dictionary).get("new", 0) >= 0,
		"the counts survive")
	_check(_changed >= 2, "the network reports the career change")

	# Task editor -------------------------------------------------------------
	var task_card: Control = _screen.call("_task_card", scout_id)
	_screen.call("_focus", task_card)
	_nav.confirmed.emit()
	await _frames(2)
	_check(_screen.view == "task", "the task tile opens the editor")
	var editor: CareerScoutTaskEditor = _screen.get("_task_editor")
	_check(editor.cell_ids() == ["role", "traits", "contract", "age"],
		"the editor has four criteria cells")
	_screen.call("_focus", editor.focusables()[0])
	_nav.confirmed.emit()
	await _frames(1)
	_check(_screen.get("_task_field") == "role", "confirm selects the role field")
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_screen.get("_task_draft")["role"] == "GK", "right changes the role")
	_check(_screen.hints().size() == 4, "an edited field hints the value keys")
	_screen.call("_on_task_field_selected", "age")
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_screen.get("_task_draft")["age_min"] == 16, "right starts the age range")
	_nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(_screen.get("_task_range") == "max", "up switches to the maximum row")
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_screen.get("_task_draft")["age_max"] == 16, "right raises the maximum")
	_screen.call("_input", _key(KEY_X))
	await _frames(1)
	_check(_screen.get("_task_draft")["age_min"] == null, "X restores the default criteria")
	_check(_screen.get("_task_field") == "", "X also leaves the field")
	_nav.cancelled.emit()
	await _frames(2)
	_check(_screen.view == "tasks", "back saves the task and returns")

	# Reports -----------------------------------------------------------------
	_screen.call("_start_assign", scout_id)
	await _frames(2)
	var player_id := _scoutable_player(catalog, career)
	_check(not player_id.is_empty(), "a scoutable player is available")
	if not player_id.is_empty():
		var assigned := CareerScouting.assign(career, catalog, scout_id, player_id)
		_check(bool(assigned.get("ok", false)),
			"a report can be requested: " + str(assigned.get("error", "")))
	var from := career.date
	var to := CareerSearch.add_days(from, 8)
	career.data["date"] = to
	CareerScouting.process_days(career, catalog, from, to)
	var feed: Array = CareerScouting.snapshot(career, catalog).get("feed", [])
	_check(feed.size() > 0, "the tick produced reports for the feed")

	_changed = 0
	_screen.open(career, catalog, {"mode": "reports", "player_id": player_id})
	await _frames(2)
	_check(_screen.view == "reports", "the hub can open the reports mode directly")
	var reports: CareerScoutReportsFeed = _screen.get("_reports")
	_check(reports.entry_count() > 0, "the feed lists the reports")
	_check(_screen.hints().size() == 4, "the reports view hints four controls")
	_check(reports.active_tab() == 0, "the feed opens on the ALL tab")
	var acknowledged := bool((career.data["scout_reports"].get(player_id, {}) as Dictionary)
		.get("acknowledged", false))
	_check(acknowledged, "opening the feed acknowledges the new reports")
	_check(_changed >= 1, "the acknowledgement is reported as a change")
	_screen.call("_on_report_filter", "requests")
	await _frames(1)
	_check(_screen.report_filter == "requests", "the filter moves to the requests tab")
	_check(reports.entry_count() == (career.data["scout_reports"] as Dictionary).size(),
		"the requests tab shows only the requested reports")
	_screen.call("_on_report_filter", "all")
	await _frames(1)

	var report_card: Dictionary = _screen.call("_entry_for", player_id)
	_check(not (report_card as Dictionary).is_empty(), "the report player is in the feed")
	_screen.call("_focus_reports_initial")
	var report_cards: Array = reports.entry_cards()
	var target := -1
	for index in report_cards.size():
		if (report_cards[index] as CareerScoutReportCard).player_id() == player_id:
			target = index
	_check(target >= 0, "the report player has a card")
	if target >= 0:
		# Mouse = keyboard: a click on the card opens the modal, and a click on
		# the dark backdrop closes it again.
		_click(viewport, report_cards[target].get_global_rect().get_center())
		await _frames(2)
		var modal: CareerScoutingModal = _screen.get("_report_modal")
		_check(modal.is_open(), "a click on the report card opens the player modal")
		_check(modal.get_parent() == host and modal.size == host.size,
			"the report modal covers the whole screen")
		_check(modal.get_node("Scrim").size == modal.size,
			"the scrim darkens the whole screen")
		var modal_card: Control = modal.get_node("Card")
		_check(modal_card.size.y <= modal.size.y * 0.92 + 0.5,
			"the report card stays within 92% of the height")
		_check(modal_card.position.y >= 23.5 and modal_card.position.y
			+ modal_card.size.y <= modal.size.y - 23.5,
			"the report card keeps its margin on both sides")
		_click(viewport, Vector2(6.0, 6.0))
		await _frames(2)
		_check(not modal.is_open(), "a click on the backdrop closes the player modal")

		_screen.call("_focus", report_cards[target])
		_nav.confirmed.emit()
		await _frames(2)
		_check(modal.is_open(), "confirm opens the player report modal")
		_check(_nav.is_modal(), "the report modal owns input")
		_check(_screen.hints().size() == 4, "the report modal hints remove and back")
		var pane := modal.content() as CareerPlayerPane
		_check(pane != null, "the report modal embeds the player pane")
		if pane != null:
			_check(pane.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
				and not pane.get_v_scroll_bar().visible,
				"the report card shows everything without a scrollbar")
			_check((pane.get_child(0) as Control).size.y <= pane.size.y + 0.5,
				"the whole player pane fits the card")
			var buttons := pane.action_buttons()
			_check(buttons.size() == 5, "a club player gets five actions")
			_check(pane.player_id() == player_id, "the pane shows the report player")
			buttons[0].pressed.emit()
			await _frames(2)
			_check(_routes.size() == 1 and _routes[0]["view"] == "offer",
				"the transfer action routes to the offer screen")
			_check(str(_routes[0]["payload"].get("kind", "")) == "transfer",
				"the transfer route carries the kind")
			_check(str(_routes[0]["payload"].get("player_id", "")) == player_id,
				"the transfer route carries the player")
			_check((_routes[0]["payload"].get("preset", {}) as Dictionary).has("fee"),
				"the offer gets the proposal preset")
			_nav.confirmed.emit()
			await _frames(2)
			_screen.call("_focus", report_cards[target])
			_nav.confirmed.emit()
			await _frames(2)
			buttons = (modal.content() as CareerPlayerPane).action_buttons()
			buttons[1].pressed.emit()
			await _frames(2)
			_check(_routes.size() == 2 and _routes[1]["payload"]["kind"] == "loan",
				"the loan action routes with the loan kind")

	# Remove an entry with X --------------------------------------------------
	_screen.call("_focus", _report_card_for(reports, player_id))
	_nav.confirmed.emit()
	await _frames(2)
	_screen.call("_input", _key(KEY_X))
	await _frames(2)
	_check(not (career.data["scout_reports"] as Dictionary).has(player_id),
		"X removes the player from the report feed")
	_check(_screen.get("snapshot").get("feed", []).size() < feed.size(),
		"the feed snapshot is rebuilt without the player")

	# Back leaves the reports ------------------------------------------------
	_nav.cancelled.emit()
	await _frames(2)
	_check(_closed == 1, "B leaves the network screen")

	_screen.queue_free()
	await _frames(2)
	_finish()


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


# A real left click at `position` (viewport coordinates), the way a mouse does.
func _click(viewport: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	viewport.push_input(event)


func _report_card_for(feed: CareerScoutReportsFeed, player_id: String) -> Control:
	for card in feed.entry_cards():
		if (card as CareerScoutReportCard).player_id() == player_id:
			return card
	return null


func _scoutable_player(catalog: TeamCatalog, career: Career) -> String:
	var page := CareerSearch.search(catalog, career,
		{"league": "ES1", "sort": "overall", "direction": "desc"}, 120, 0)
	for item in page.get("items", []):
		if not (item is Dictionary):
			continue
		if str((item as Dictionary).get("club_id", "")) == str(career.club_id):
			continue
		if bool((item as Dictionary).get("scouted", false)):
			continue
		return str((item as Dictionary).get("player_id", ""))
	return ""

