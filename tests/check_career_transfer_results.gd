extends SceneTree
# Headless check for CareerTransferResults (prototype TransferResults.svelte /
# TransferPlayers.svelte): the first page and the header, the two-column card
# grid, selection following focus, the right-hand pane, load-more at the end of
# the list, the player-actions modal (rows, disabled reasons, shortlist, offer
# and contract routes), the free-agent variant, the scout picker and the
# empty/error states.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_results.gd

const FIXTURE := "res://tests/fixtures/career_save_prototype.json"
const SCOUTS := [
	{"id": "s1", "name": "Ivan Petrov", "experience": 3, "judgement": 4},
]

var failures: Array[String] = []
var _routes: Array[Dictionary] = []
var _changed := 0
var _closed := 0
var _scout_requests: Array = []
var _viewport: SubViewport


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


# Search is synchronous, so "loaded" means the deferred first page ran and the
# loading flag dropped again.
func _wait(screen) -> void:
	for index in 600:
		if not bool(screen.get("_loading")):
			await _frames(3)
			return
		await process_frame


func _finish() -> void:
	print("== check_career_transfer_results: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check(raw is Dictionary, "the prototype save fixture parses")
	if not (raw is Dictionary):
		_finish()
		return
	var career := Career.from_save(raw)
	_check(career != null, "the prototype career loads")
	if career == null:
		_finish()
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	_viewport = viewport
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var screen := CareerTransferResults.new()
	screen.position = Vector2(128.0, 120.0)
	screen.size = Vector2(1664.0, 900.0)
	host.add_child(screen)
	screen.navigate.connect(func(view: String, payload: Dictionary) -> void:
		_routes.append({"view": view, "payload": payload}))
	screen.changed.connect(func() -> void: _changed += 1)
	screen.closed.connect(func() -> void: _closed += 1)
	screen.scout_requested.connect(func(player_id: String, scout_id: String) -> void:
		_scout_requests.append([player_id, scout_id]))
	await _frames(2)

	# First page ------------------------------------------------------------
	screen.setup(career, catalog, {
		"filters": {"league": "ES1", "sort": "overall", "direction": "desc"},
		"scouts": [],
	})
	await _wait(screen)
	var nav := root.get_node("UiNav")
	_check(screen.item_count() == 40, "the first page holds forty players")
	_check(screen.total() > 40, "the header counts every match")
	_check((screen.get("_cards") as Array).size() == 40, "one card per player")
	_check((screen.get("_meta") as Label).text.begins_with(
		CareerTransferResults._grouped(screen.total())), "the header groups the total")
	_check((screen.get("_meta") as Label).text.contains(
		CareerHubModel.month_label(career.date)), "the header shows the career date")
	_check(screen.filters()["league"] == "ES1", "the screen reports its filters")
	_check(screen.hints().size() == 3, "the results hint three controls")

	var cards: Array = screen.get("_cards")
	_check(absf(cards[0].size.x - cards[1].size.x) < 2.0, "the grid splits into two columns")
	_check(cards[0].size.x > cards[0].size.y, "a card is wider than tall")
	_check(cards[2].position.y > cards[0].position.y, "the third card starts the second row")
	_check((screen.get("_pane") as Control).visible, "the detail pane is shown")
	_check((screen.get("_right") as Control).position.x
		>= (screen.get("_left") as Control).size.x, "the pane sits right of the results")

	# Selection follows focus ----------------------------------------------
	screen.focus_initial()
	await _frames(2)
	var items: Array = screen.get("_items")
	var first_id := screen.selected_id()
	_check(first_id == str(items[0]["player_id"]), "the first card is selected")
	_check((screen.get("_pane") as CareerPlayerPane).player_id() == first_id,
		"the pane shows the selected player")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(screen.selected_id() == str(items[1]["player_id"]),
		"right selects the next player")
	_check((screen.get("_pane") as CareerPlayerPane).player_id() == screen.selected_id(),
		"the pane follows the selection")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(screen.selected_id() == str(items[1]["player_id"]),
		"right does not wrap onto the next row")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.selected_id() == str(items[3]["player_id"]), "down moves to the next row")
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(screen.selected_id() == str(items[1]["player_id"]), "up returns to the previous row")

	# Load more --------------------------------------------------------------
	screen.call("_focus_card", 37)
	await _frames(3)
	_check(screen.item_count() >= 80,
		"reaching the end of the page loads the next one (%d)" % screen.item_count())
	items = screen.get("_items")

	# Player actions on a club player ---------------------------------------
	var index := -1
	for cursor in items.size():
		var item: Dictionary = items[cursor]
		if not bool(item.get("scouted", false)) \
				and not str(item.get("club_id", "")).is_empty():
			index = cursor
			break
	_check(index >= 0, "the page lists an unscouted club player")
	screen.call("_focus_card", index)
	await _frames(2)
	var player_id := screen.selected_id()
	nav.confirmed.emit()
	await _frames(2)
	var actions: CareerPlayerActions = screen.get("_actions")
	_check(actions.is_open(), "confirm opens the player actions")
	_check(nav.is_modal(), "the actions modal owns input")
	_check(screen.hints().size() == 2, "the hints shrink to the modal's two controls")
	_check(actions.row_ids() == ["scout", "shortlist", "offer_transfer", "offer_loan",
		"discuss"], "a club player gets all five actions")
	_check(actions.row_label("scout") == "HIRE A SCOUT", "without scouts the row asks to hire")
	_check(not actions.row_enabled("scout"), "hiring is not a row action")
	_check(actions.row_ticket("scout") == "NETWORK", "the hire row points at the network")
	_check(actions.row_label("shortlist") == "ADD TO SHORTLIST", "the shortlist offers to add")
	var can_discuss := CareerTransferContracts.can_discuss(catalog, career, items[index])
	_check(actions.row_enabled("discuss") == can_discuss,
		"DISCUSS MOVE follows the contract rules")
	_check(actions.row_ticket("discuss") == ("A" if can_discuss else "NOT EXPIRING"),
		"the discuss row explains a refusal")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.selected_id() == player_id, "the results ignore input under the modal")

	# The pane is still in place behind the scrim, and Back returns focus.
	nav.cancelled.emit()
	await _frames(2)
	_check(not actions.is_open(), "Back closes the actions modal")
	_check(not nav.is_modal(), "input returns to the results")
	_check(screen.selected_id() == player_id, "the same card stays selected")

	# Shortlist toggle -------------------------------------------------------
	nav.confirmed.emit()
	await _frames(2)
	_check(actions.is_open(), "the modal opens again")
	_check(not career.shortlist.has(player_id), "the player starts off the shortlist")
	var shortlist_row: CareerPlayerActions.Row = actions.get("_by_id")["shortlist"]
	shortlist_row.grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(career.shortlist.has(player_id), "the toggle writes the shortlist")
	_check(_changed == 1, "the screen reports the career change once")
	_check(actions.row_label("shortlist") == "REMOVE FROM SHORTLIST",
		"the row text flips in place")
	_check(actions.is_open(), "toggling keeps the modal open")

	# Transfer / loan routes -------------------------------------------------
	var transfer_row: CareerPlayerActions.Row = actions.get("_by_id")["offer_transfer"]
	transfer_row.grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(not actions.is_open(), "choosing an offer closes the modal")
	_check(_routes.size() == 1 and _routes[0]["view"] == "offer",
		"the offer route leaves the screen")
	var payload: Dictionary = _routes[0]["payload"]
	_check(str(payload.get("player_id", "")) == player_id, "the offer carries the player")
	_check(str(payload.get("kind", "")) == "transfer", "the transfer offer is a transfer")
	_check((payload.get("preset", {}) as Dictionary).has("fee"),
		"the offer screen gets the proposal preset")

	nav.confirmed.emit()
	await _frames(2)
	actions.get("_by_id")["offer_loan"].grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(_routes.size() == 2 and _routes[1]["payload"]["kind"] == "loan",
		"the loan offer routes with the loan kind")

	# Free agent + scout picker ---------------------------------------------
	screen.setup(career, catalog, {
		"filters": {"status": "free", "sort": "name", "direction": "asc"},
		"scouts": SCOUTS,
	})
	await _wait(screen)
	_check(screen.item_count() > 0, "free agents are found")
	var free_item: Dictionary = (screen.get("_items"))[0]
	_check(str(free_item.get("club_id", "")).is_empty(), "the first free agent has no club")
	screen.focus_initial()
	await _frames(2)
	nav.confirmed.emit()
	await _frames(2)
	_check(actions.is_open(), "a free agent also opens the actions")
	_check(actions.row_ids() == ["scout", "shortlist", "discuss"],
		"a free agent has no club offers")
	_check(actions.row_enabled("discuss"), "a free agent can discuss a move")
	_check(actions.row_label("scout") == "ASSIGN SCOUT", "free scouts offer an assignment")
	actions.get("_by_id")["scout"].grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	var picker: CareerScoutPicker = actions.get("_picker")
	_check(picker != null and picker.is_open(), "the scout picker opens over the modal")
	_check(picker.scout_ids() == ["s1"], "the picker lists the free scouts")
	_check(nav.modal_owner() == picker, "the picker sits on top of the actions")
	nav.confirmed.emit()
	await _frames(2)
	_check(not picker.is_open(), "assigning closes the picker")
	_check(actions.is_open(), "the actions modal stays open")
	_check(_scout_requests.size() == 1, "the screen forwards the assignment")
	if _scout_requests.size() == 1:
		_check(str(_scout_requests[0][0]) == str(free_item["player_id"]),
			"the assignment carries the player")
		_check(str(_scout_requests[0][1]) == "s1", "the assignment carries the scout")

	actions.get("_by_id")["discuss"].grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(_routes.size() == 3 and _routes[2]["view"] == "contract",
		"discussing a free agent opens the contract")
	_check(str(_routes[2]["payload"].get("player_id", ""))
		== str(free_item["player_id"]), "the contract carries the player")

	# Empty / error states ---------------------------------------------------
	screen.setup(career, catalog, {"filters": {"name": "zzzznotaplayer", "sort": "name"}})
	await _wait(screen)
	_check(screen.item_count() == 0 and screen.total() == 0, "an empty search shows no cards")
	_check((screen.get("_note") as Label).text.contains("Nobody found"),
		"the empty state explains itself")
	_check(not (screen.get("_pane") as Control).visible, "the pane hides without a player")
	_check((screen.get("_meta") as Label).text.begins_with("0 "), "the header shows a zero count")

	screen.setup(career, null, {"filters": {}})
	await _wait(screen)
	_check((screen.get("_note") as Label).text == "transfer search is unavailable",
		"a missing catalog shows the search error")

	# Back leaves the screen -------------------------------------------------
	nav.cancelled.emit()
	await _frames(1)
	_check(_closed == 1, "Back leaves the results screen")

	screen.queue_free()
	await _frames(2)
	_finish()
