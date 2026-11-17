extends SceneTree
# Headless check for the ticket-06 player actions UI: the squad actions row
# (transfer status toggles, shirt number / game plan / renewal / release hooks)
# and the three screens it opens — CONTRACT TALKS, SHIRT NUMBER and RELEASE —
# against a real career fixture and catalog.
#
# Run:  godot --headless --path . -s res://tests/check_career_squad_actions_ui.gd

var failures: Array[String] = []

var _changed := 0
var _closed := 0
var _requested: Array = []

var _host: Control
var _nav: Node
var _row: CareerSquadActionsRow
var _negotiation: CareerNegotiationScreen
var _number: CareerShirtNumberScreen
var _release: CareerReleaseScreen


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
	print("== check_career_squad_actions_ui: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _career(catalog: TeamCatalog) -> Career:
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	career.data["date"] = "2026-07-01"
	return career


func _squad(career: Career, catalog: TeamCatalog) -> Array:
	return CareerSquad.enrich_players(career,
		catalog.career_players_by_ids(career.player_ids, false))


func _focus_to(screen: Control, id: String) -> void:
	var ids: Array = screen.call("_focus_ids")
	screen.set("_focus", ids.find(id))


func _advance_to_due(career: Career, player_id: String) -> void:
	var state_value: Dictionary = career.negotiations.get(player_id, {})
	career.data["date"] = str(state_value.get("due", career.date))
	CareerSquadActions.process_due(career, catalog_ref, career.date)


var catalog_ref: TeamCatalog


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	catalog_ref = catalog
	var career := _career(catalog)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	_host = Control.new()
	_host.theme = UiTheme.load_or_build()
	viewport.add_child(_host)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nav = root.get_node("UiNav")

	var players := _squad(career, catalog)
	_check(players.size() >= 12, "the fixture squad has players to act on")
	var player: Dictionary = players[0]
	var player_id := str(player.get("id", ""))

	# --- squad actions row ---------------------------------------------------
	_row = CareerSquadActionsRow.new()
	_row.position = Vector2(40.0, 40.0)
	_row.size = Vector2(600.0, 170.0)
	_host.add_child(_row)
	_row.action_requested.connect(func(action: String, id: String) -> void:
		_requested.append({"action": action, "player_id": id}))
	_row.changed.connect(func() -> void: _changed += 1)
	_row.setup(career, catalog, player)
	await _frames(2)

	_check(_row.action_ids().size() == 7, "the row carries seven actions")
	_check(_row.action_label("transfer") == "ON TRANSFER", "the transfer action offers a listing")
	_check(_row.action_label("loan") == "LOAN", "the loan action offers a loan")
	_check(_row.action_label("blocked") == "BLOCK", "the block action offers a block")
	_check(_row.action_label("plan") == "MANAGE TEAM", "the squad column manages the team")
	_check(_row.action_label("number") == "CHANGE NUMBER", "the squad column changes the number")
	_check(_row.action_label("renew") == "RENEW CONTRACT", "the contract column renews")
	_check(_row.action_label("release") == "RELEASE PLAYER", "the contract column releases")
	_check(_row.hints().size() == 3, "the row hints describe navigate/select/close")

	# Accordion: the row unfolds under the focused card instead of popping.
	_check(_row.size.y == 170.0, "a freshly built row sits at its full height")
	_row.play_open()
	_check(_row.size.y == 0.0 and not _row.handle_confirmed(),
		"the open animation starts folded and ignores input")
	_row.finish_animation()
	_check(is_equal_approx(_row.size.y, 170.0), "the open animation ends at the full height")

	_row.focus_initial()
	_check(_row.focused_id() == "transfer", "the first action owns the focus")
	_check(_row.handle_moved(Vector2i.RIGHT) and _row.focused_id() == "plan",
		"right walks to the squad column")
	_check(_row.handle_moved(Vector2i.DOWN) and _row.focused_id() == "number",
		"down walks the squad column")
	_check(not _row.handle_moved(Vector2i.DOWN) and _row.focused_id() == "number",
		"the squad column stops at its last action")
	_check(_row.handle_moved(Vector2i.RIGHT) and _row.focused_id() == "release",
		"right reaches the contract column")
	_check(_row.handle_moved(Vector2i.UP) and _row.focused_id() == "renew",
		"up reaches the renewal")
	_check(_row.handle_moved(Vector2i.DOWN) and _row.focused_id() == "release",
		"down returns to the release")
	_check(_row.handle_moved(Vector2i.LEFT) and _row.focused_id() == "number",
		"left returns to the squad column on the same row")
	_check(_row.handle_moved(Vector2i.LEFT) and _row.focused_id() == "loan",
		"left returns to the transfer column on the same row")
	_check(_row.handle_moved(Vector2i.UP) and _row.focused_id() == "transfer",
		"up returns to the first action")

	# Transfer statuses toggle through CareerTransfers.set_status.
	_check(_row.handle_confirmed(), "confirm applies the focused status")
	_check(str(career.player_transfers.get(player_id, "")) == "transfer",
		"the player is listed for transfer")
	_check(_row.action_label("transfer") == "REMOVE", "the label flips to remove")
	_check(_changed == 1, "the status change is announced")
	_row.handle_confirmed()
	_check(str(career.player_transfers.get(player_id, "")) == "",
		"repeating the status clears it")
	_check(_row.action_label("transfer") == "ON TRANSFER", "the label flips back")
	_check(_changed == 2, "the cleared status is announced")

	_row.handle_moved(Vector2i.DOWN)
	_row.handle_confirmed()
	_check(str(career.player_transfers.get(player_id, "")) == "loan",
		"the loan status is applied")
	_check(_row.action_label("loan") == "RECALL FROM LOAN", "the loan label flips")
	_row.handle_confirmed()
	_check(str(career.player_transfers.get(player_id, "")) == "",
		"the loan status clears again")
	_row.handle_moved(Vector2i.DOWN)
	_row.handle_confirmed()
	_check(str(career.player_transfers.get(player_id, "")) == "blocked",
		"the block status is applied")
	_check(_row.action_label("blocked") == "UNBLOCK", "the block label flips")
	_row.handle_confirmed()
	_check(str(career.player_transfers.get(player_id, "")) == "",
		"the block status clears again")

	# Row hooks: the host routes these to the screens / game plan. A host action
	# folds the accordion first and reports only after the close has finished.
	_requested.clear()
	_row.set_notice(true)
	_check(_row.notice(), "the unread renewal dot is raised")
	_row.play_open()
	_row.finish_animation()
	_row.focus_initial()
	_row.handle_moved(Vector2i.RIGHT)
	_row.handle_confirmed()
	_check(_requested.is_empty() and _row.is_inside_tree() and _row.is_closing(),
		"a host action keeps the row alive while it closes")
	_check(not _row.handle_confirmed(), "a second press during the close is ignored")
	_row.finish_animation()
	_check(_requested.size() == 1 and str(_requested[0]["action"]) == "plan"
		and str(_requested[0]["player_id"]) == player_id,
		"manage team asks the host for the game plan once the close is done")
	_row.play_open()
	_row.finish_animation()
	_row.handle_moved(Vector2i.DOWN)
	_row.handle_confirmed()
	_row.finish_animation()
	_check(str(_requested[-1]["action"]) == "number", "change number asks the host")
	_row.play_open()
	_row.finish_animation()
	_row.handle_moved(Vector2i.UP)
	_row.handle_moved(Vector2i.RIGHT)
	_row.handle_confirmed()
	_row.finish_animation()
	_check(str(_requested[-1]["action"]) == "renew", "renew asks the host")
	_row.play_open()
	_row.finish_animation()
	_row.handle_moved(Vector2i.DOWN)
	_row.handle_confirmed()
	_row.finish_animation()
	_check(str(_requested[-1]["action"]) == "release", "release asks the host")
	_row.set_notice(false)
	_check(not _row.notice(), "the unread dot clears")

	# --- the host keeps the row alive while it closes -------------------------
	# Loaded by path: a bare CareerSquadView reference would compile the view at
	# parse time, before the autoloads exist (see the row's own /root/UiNav note).
	var view = load("res://scripts/ui/career_squad_view.gd").new()
	view.set("career", career)
	view.set("catalog", catalog)
	view.size = Vector2(1480.0, 626.0)
	_host.add_child(view)
	view.call("refresh")
	view.call("_open_centre")
	view.call("_open_actions", player)
	var actions := view.get("_actions_row") as CareerSquadActionsRow
	_check(actions != null, "the host opens the actions row")
	var asked: Array = []
	view.connect("player_action_requested",
		func(action: String, _id: String) -> void: asked.append(action))
	actions.finish_animation()
	actions.focus_initial()
	actions.handle_moved(Vector2i.RIGHT)
	actions.handle_moved(Vector2i.RIGHT)
	actions.handle_confirmed()
	_check(view.get("_actions_row") != null and actions.is_inside_tree()
		and asked.is_empty(), "the host does not free the row before its close animation")
	actions.finish_animation()
	_check(asked == ["renew"], "the host action fires after the close animation")
	_check(view.get("_actions_row") == null, "the close animation releases the row")

	# A player at the end of the list: the plate opens under its row and the list
	# scrolls to keep both of them on screen (it never lifts off the row).
	var rows: Array = view.call("_centre_players")
	var last_player: Dictionary = rows[-1]
	view.call("_open_actions", last_player)
	var last_row := view.get("_actions_row") as CareerSquadActionsRow
	_check(last_row != null, "the last player of the list opens the actions row")
	if last_row != null:
		last_row.finish_animation()
		await _frames(1)
		var m: Dictionary = view.call("_centre_metrics")
		var list_rect: Rect2 = m["list"]
		var scroll := float(view.get("centre_scroll"))
		var row_top := list_rect.position.y + 2.0 \
			+ float(view.call("_centre_row_offset", rows.size() - 1)) - scroll
		_check(row_top >= list_rect.position.y - 0.5
			and row_top + 50.0 <= list_rect.end.y + 0.5,
			"the list scrolls the last row into view")
		_check(last_row.position.y >= row_top + 50.0 - 0.5,
			"the plate opens under its row instead of covering it")
		_check(last_row.position.y + last_row.size.y <= list_rect.end.y + 0.5,
			"the plate fits inside the list after the scroll")
		view.call("_close_actions")
		last_row.finish_animation()
		await _frames(2)
		var content_h := float(view.call("_centre_content_height", 50.0))
		_check(float(view.get("centre_scroll"))
			<= maxf(0.0, content_h - list_rect.size.y) + 0.5,
			"closing the plate keeps the scroll inside the list")

	# A second click on the open row folds the plate instead of pressing the
	# action that happens to own the focus.
	var click_player: Dictionary = rows[1]
	view.call("_open_actions", click_player)
	var click_row := view.get("_actions_row") as CareerSquadActionsRow
	click_row.finish_animation()
	await _frames(1)
	var click_id := str(click_player.get("id", ""))
	var row_rect := Rect2()
	for element in (view.get("_elements") as Array):
		if str(element.get("id", "")) == "centre-row:%s" % click_id:
			row_rect = element["rect"]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = row_rect.get_center()
	view.call("_gui_input", click)
	_check(click_row.is_closing(), "a second click on the row folds the plate")
	_check(str(career.player_transfers.get(click_id, "")) == "",
		"the click does not press the action in focus")
	click_row.finish_animation()
	await _frames(2)
	_check(view.get("_actions_row") == null, "the folded plate is released")
	view.free()

	# --- contract talks ------------------------------------------------------
	_negotiation = CareerNegotiationScreen.new()
	_negotiation.position = Vector2(220.0, 210.0)
	_negotiation.size = Vector2(1480.0, 626.0)
	_host.add_child(_negotiation)
	_negotiation.closed.connect(func() -> void: _closed += 1)
	_negotiation.changed.connect(func() -> void: _changed += 1)
	_changed = 0
	_closed = 0

	_negotiation.open(career, catalog, {"player_id": player_id})
	await _frames(2)
	var contract: Dictionary = career.player_contracts[player_id]
	var state_value := _negotiation.state()
	_check(str(state_value.get("error", "")) == "", "the talks open without error")
	_check(int(_negotiation.draft().get("years", 0)) == int(contract.get("years", 0)),
		"the draft starts at the current years")
	_check(int(_negotiation.draft().get("weekly_wage", 0))
		== int(contract.get("weekly_wage", 0)), "the draft starts at the current wage")
	_check(_negotiation.focused_id() == "years", "the years own the first focus")
	_check(_negotiation.hints().size() == 3, "the talks hints describe adjust/select/back")

	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(int(_negotiation.draft().get("years", 0))
		== mini(5, int(contract.get("years", 1)) + 1), "right adds a contract year")
	_nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(int(_negotiation.draft().get("years", 0)) == int(contract.get("years", 1)),
		"left removes the year again")

	_nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(_negotiation.focused_id() == "weekly_wage", "down reaches the wage")
	var wage_before := int(_negotiation.draft().get("weekly_wage", 0))
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(int(_negotiation.draft().get("weekly_wage", 0)) > wage_before,
		"right raises the wage by the step")
	_nav.confirmed.emit()
	await _frames(1)
	var modal = _negotiation.get("_amount_modal")
	_check(modal != null and modal.is_open(), "confirm on the wage opens the amount modal")
	if modal != null:
		modal.set("_digits", PackedInt32Array([0, 0, 0, 0, 0, 5, 0, 0, 0]))
		_nav.confirmed.emit()
		await _frames(1)
		_check(not modal.is_open(), "the amount modal closes after applying")
		_check(int(_negotiation.draft().get("weekly_wage", 0)) == 5000,
			"the typed wage lands in the draft")

	_nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(_negotiation.focused_id() == "squad_role", "down reaches the squad role")
	var role_before := str(_negotiation.draft().get("squad_role", ""))
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(str(_negotiation.draft().get("squad_role", "")) != role_before,
		"right cycles the squad role")
	_nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(_negotiation.focused_id() == "release_clause", "down reaches the release clause")
	var clause_before := int(_negotiation.draft().get("release_clause", 0))
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(int(_negotiation.draft().get("release_clause", 0)) > clause_before,
		"right raises the release clause")

	# Submit -> pending: the note, the terms and only OK.
	_focus_to(_negotiation, "submit")
	_check(_negotiation.focused_id() == "submit", "submit can be focused")
	_nav.confirmed.emit()
	await _frames(1)
	_check(str(_negotiation.state().get("status", "")) == "pending",
		"submitting starts the player's thinking time")
	_check(_changed == 1, "the submit reports the change")
	_check(_negotiation.focused_id() == "ok", "the pending screen only offers OK")
	_check(_negotiation.hints().size() == 2, "the pending hints drop the adjust row")
	_check(bool((_negotiation.get("_note") as Control).visible),
		"the pending note shows the reply date")
	_check(bool((_negotiation.get("_terms") as Control).visible),
		"the pending screen shows the offered terms")
	_nav.cancelled.emit()
	await _frames(1)
	_check(_closed == 1, "back closes the talks")

	# The answer arrives: a counter is unread, opening acknowledges it.
	_advance_to_due(career, player_id)
	_check(str(career.negotiations[player_id].get("status", "")) == "counter",
		"the lowball offer draws a counter")
	_check(not bool(career.negotiations[player_id].get("acknowledged", true)),
		"the counter starts unread")
	_negotiation.open(career, catalog, {"player_id": player_id})
	await _frames(2)
	_check(bool(career.negotiations[player_id].get("acknowledged", false)),
		"opening the talks acknowledges the answer")
	_check(not bool(_negotiation.state().get("unread", true)),
		"the unread flag clears")
	_check(str(_negotiation.state().get("status", "")) == "counter",
		"the counter is still on screen")
	_check(bool((_negotiation.get("_reply") as Control).visible),
		"the counter block is shown")
	_check(bool((_negotiation.get("_reply_terms") as Control).visible),
		"the counter terms are shown")
	_check((_negotiation.call("_focus_ids") as Array).has("accept_counter"),
		"the counter can be accepted")

	# The wage fund blocks the counter.
	var balance = career.balance
	career.balance = 0
	_negotiation.open(career, catalog, {"player_id": player_id})
	await _frames(1)
	_check((_negotiation.state().get("affordable") == false),
		"the counter above the wage fund is not affordable")
	_check(not (_negotiation.call("_focus_ids") as Array).has("accept_counter"),
		"an unaffordable counter cannot be accepted")
	_check(bool((_negotiation.get("_warning") as Control).visible),
		"the affordability warning is shown")
	career.balance = balance
	_negotiation.open(career, catalog, {"player_id": player_id})
	await _frames(1)
	_changed = 0
	_closed = 0
	_focus_to(_negotiation, "accept_counter")
	_nav.confirmed.emit()
	await _frames(1)
	_check(_changed == 1 and _closed == 1, "accepting the counter closes the talks")
	_check(career.negotiations.is_empty(), "accepting the counter signs the contract")

	# A full demand is accepted and signed from the accepted screen.
	var demand_player_id := str(career.player_ids[1])
	var demand_player := {}
	for entry in _squad(career, catalog):
		if str((entry as Dictionary).get("id", "")) == demand_player_id:
			demand_player = entry
	var demand := CareerSquadActions.demand(catalog, career, demand_player)
	_negotiation.open(career, catalog, {"player_id": demand_player_id})
	await _frames(1)
	_negotiation.set("_draft", demand.duplicate(true))
	_focus_to(_negotiation, "submit")
	_nav.confirmed.emit()
	await _frames(1)
	_advance_to_due(career, demand_player_id)
	_changed = 0
	_closed = 0
	_negotiation.open(career, catalog, {"player_id": demand_player_id})
	await _frames(1)
	_check(str(_negotiation.state().get("status", "")) == "accepted",
		"the full demand is accepted")
	_check(_negotiation.focused_id() == "sign", "sign is the only action left")
	_check(bool(_negotiation.state().get("can_sign", false)), "the accepted deal can be signed")
	_nav.confirmed.emit()
	await _frames(1)
	_check(_changed == 1 and _closed == 1, "signing closes the talks")
	_check(int(career.player_contracts[demand_player_id].get("weekly_wage", 0))
		== int(demand["weekly_wage"]), "the signed contract carries the demand")

	# Refused: two counters and then the player walks away; the form returns.
	var refused_career := _career(catalog)
	var refused_id := str(refused_career.player_ids[2])
	var refused_lowball := {
		"years": 1, "weekly_wage": 1000,
		"squad_role": str(refused_career.player_contracts[refused_id]["squad_role"]),
		"release_clause": 0,
	}
	for round_index in 3:
		CareerSquadActions.start(refused_career, catalog, refused_id, refused_lowball)
		_advance_to_due(refused_career, refused_id)
		if str(refused_career.negotiations[refused_id].get("status", "")) == "refused":
			break
	_negotiation.open(refused_career, catalog, {"player_id": refused_id})
	await _frames(1)
	_check(str(_negotiation.state().get("status", "")) == "refused",
		"the player refuses after two counters")
	_check(bool((_negotiation.get("_reply") as Control).visible),
		"the refusal block is shown")
	_check((_negotiation.call("_focus_ids") as Array).has("submit"),
		"the talks can be reopened")
	_check(action_label_of(_negotiation, "submit") == "OFFER AGAIN",
		"the submit becomes an offer again")

	# Unknown players keep the prototype's inline error.
	_changed = 0
	_closed = 0
	_negotiation.open(career, catalog, {"player_id": "999999999"})
	await _frames(1)
	_check(str(_negotiation.state().get("error", "")) == "player is not in this squad",
		"unknown players cannot be renewed")
	_check(_negotiation.status_error(), "the error is reported to the host")
	_check(_negotiation.focused_id() == "ok", "the error state only offers OK")
	_check((_negotiation.call("_focus_ids") as Array).size() == 1,
		"no field is editable without a negotiation")
	_nav.confirmed.emit()
	await _frames(1)
	_check(_closed == 1, "OK closes the error state")

	# --- shirt number --------------------------------------------------------
	# The host swaps screens; hide the talks so they ignore the same input.
	_negotiation.visible = false
	_number = CareerShirtNumberScreen.new()
	_number.position = Vector2(220.0, 210.0)
	_number.size = Vector2(1480.0, 626.0)
	_host.add_child(_number)
	_number.closed.connect(func() -> void: _closed += 1)
	_number.changed.connect(func() -> void: _changed += 1)
	_changed = 0
	_closed = 0

	_number.open(career, catalog, {"player_id": player_id})
	await _frames(2)
	var free: Array = _number.free_numbers()
	_check(not free.is_empty(), "the squad has free shirt numbers")
	_check(free.has(_number.candidate()), "the candidate is a free number")
	_check(_number.candidate() == _number.current_number(),
		"the current number stays when nobody else wears it")
	_check(_number.hints().size() == 3, "the number hints describe cycle/confirm/cancel")
	var first_pick := _number.candidate()
	var free_index := free.find(first_pick)
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_number.candidate() == int(free[(free_index + 1) % free.size()]),
		"right walks to the next free number")
	_check(not _is_taken(career, player_id, _number.candidate()),
		"taken numbers are skipped")
	_nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(_number.candidate() == first_pick, "left walks back")

	var picked := _number.candidate()
	_nav.confirmed.emit()
	await _frames(1)
	_check(_changed == 1 and _closed == 1, "confirming the number closes the screen")
	_check(int(career.shirt_numbers.get(player_id, 0)) == picked,
		"the number is stored on the player")

	# Wrap-around and the occupancy conflict.
	_number.open(career, catalog, {"player_id": player_id})
	await _frames(1)
	var free_now: Array = _number.free_numbers()
	_number.set("_candidate", int(free_now[-1]))
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_number.candidate() == int(free_now[0]), "the cycle wraps to the first free number")
	var other_id := ""
	for entry in _squad(career, catalog):
		var candidate_id := str((entry as Dictionary).get("id", ""))
		if candidate_id != player_id:
			other_id = candidate_id
			break
	career.shirt_numbers[other_id] = _number.candidate()
	_changed = 0
	_closed = 0
	_nav.confirmed.emit()
	await _frames(1)
	_check(_number.status() == "shirt number is already taken",
		"a used number is refused inline")
	_check(_changed == 0 and _closed == 0, "a refused number keeps the screen open")
	career.shirt_numbers.erase(other_id)

	# --- release -------------------------------------------------------------
	_number.visible = false
	_release = CareerReleaseScreen.new()
	_release.position = Vector2(220.0, 210.0)
	_release.size = Vector2(1480.0, 626.0)
	_host.add_child(_release)
	_release.closed.connect(func() -> void: _closed += 1)
	_release.changed.connect(func() -> void: _changed += 1)
	_changed = 0
	_closed = 0

	_release.open(career, catalog, {"player_id": player_id})
	await _frames(2)
	_check(bool(_release.preview().get("can_release", false)),
		"a big squad can release a player")
	_check(_release.focused_id() == "cancel", "cancel owns the first focus")
	_check(_release.hints().size() == 2, "the release hints describe select/back")
	_nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(_release.focused_id() == "release", "up reaches the danger action")
	_nav.confirmed.emit()
	await _frames(1)
	_check(_changed == 1 and _closed == 1, "releasing closes the screen")
	_check(not career.player_ids.has(player_id), "the player leaves the squad")

	# Eleven players: the release is blocked with the prototype's reason.
	var small := _career(catalog)
	small.data["player_ids"] = (small.player_ids as Array).slice(0, 11)
	var small_id := str(small.player_ids[3])
	_release.open(small, catalog, {"player_id": small_id})
	await _frames(1)
	_check(not bool(_release.preview().get("can_release", true)),
		"eleven players cannot release another")
	_check(str(_release.preview().get("reason", ""))
		== "the squad cannot drop below 11 players",
		"the preview explains the eleven-player floor")
	_check(not (_release.call("_focus_ids") as Array).has("release"),
		"the blocked release cannot be focused")
	_check(_release.focused_id() == "cancel", "the focus stays on cancel")
	_release.call("_set_focus", "release")
	_check(_release.focused_id() == "cancel", "a blocked release refuses the focus")
	_changed = 0
	_closed = 0
	_nav.cancelled.emit()
	await _frames(1)
	_check(_closed == 1, "back cancels the release")

	_finish()


func _is_taken(career: Career, player_id: String, number: int) -> bool:
	for other_id in career.player_ids:
		if str(other_id) == player_id:
			continue
		if int(career.shirt_numbers.get(str(other_id), 0)) == number:
			return true
	return false


func action_label_of(screen: Control, id: String) -> String:
	for action in (screen.get("_actions") as Array):
		if str(action["id"]) == id:
			return str((action["label"] as Label).text)
	return ""
