extends SceneTree
# Headless check for the TRANSFER CENTRE screen (TransferCentre.svelte): the
# four tabs and the unread badge, the shortlist card list and its
# CareerPlayerActions modal, the sent-offer accordion actions (accept counter,
# withdraw, re-offer, contract talks), the received offers (accept, refuse,
# counter through the shared amount modal, unread ack on open), our own list
# (remove from list), the detail panes, empty states, hints and focus.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_centre.gd

const CENTRE_SCRIPT := "res://scripts/ui/career_transfer_centre.gd"
const OFFERS_GOLDEN := "res://tests/fixtures/career_transfer_offers_golden.json"
const CLUB_ID := 131
const SCREEN_SIZE := Vector2(1480.0, 564.0)

var failures: Array[String] = []
var catalog: TeamCatalog


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


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _finish() -> void:
	print("== check_career_transfer_centre: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	if not _load_catalog():
		_finish()
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(OFFERS_GOLDEN))
	_check(golden is Dictionary, "the offers golden loads")
	if not (golden is Dictionary):
		_finish()
		return

	var nav := root.get_node("UiNav")

	# ---------------------------------------------------------------- career A
	var career := _career()
	var seeded := _seed_sent(career, golden)
	_check(bool(seeded.get("ok", false)), "the sent offers are seeded: "
		+ str(seeded.get("error", "")))
	if not bool(seeded.get("ok", false)):
		_finish()
		return
	career.data["date"] = "2026-07-12"
	CareerTransfers.toggle_shortlist(career, catalog, str(golden["players"]["free_agent"]))
	var own := str(career.player_ids[0])
	CareerTransfers.set_status(career, catalog, own, "loan")
	_seed_incoming(career)

	var changed := [0]
	var navigated: Array = []
	var closes := [0]
	var screen = load(CENTRE_SCRIPT).new()
	screen.name = "TransferCentre"
	root.add_child(screen)
	screen.size = SCREEN_SIZE
	screen.changed.connect(func() -> void: changed[0] += 1)
	screen.navigate.connect(func(view: String, payload: Dictionary) -> void:
		navigated.append({"view": view, "payload": payload}))
	screen.closed.connect(func() -> void: closes[0] += 1)
	await _frames(2)

	screen.open(career, catalog, {})
	await _frames(2)
	_check(screen.tab() == "shortlist", "the centre opens on SHORTLIST")
	_check(screen.tab_ids() == ["shortlist", "sent", "received", "listed"],
		"four tabs: shortlist / sent / received / listed")
	_check(screen.tab_label("received") == "RECEIVED", "the RECEIVED tab is labelled")
	_check(screen.unread_badge() == 2, "the received offers carry an unread badge")
	_check(screen.tab_badge("received") == 2, "the badge sits on the RECEIVED tab")
	_check(screen.tab_badge("sent") == 0, "other tabs have no badge")
	_check(screen.zone() == "tabs" and screen.focused_tab() == 0,
		"open focuses the active tab")

	var hints: Array = screen.hints()
	_check(hints.size() == 4, "the shortlist lists four hints")
	_check(hints[0]["keys"] == ["↑", "↓", "←", "→"] and str(hints[0]["label"]) == "players",
		"arrows walk the players")
	_check(hints[1]["keys"] == ["Q", "E"] and str(hints[1]["label"]) == "tabs",
		"Q/E switch tabs")
	_check(hints[2]["keys"] == ["ENTER"] and hints[3]["keys"] == ["ESC"],
		"keyboard hints list select and back")

	# Shortlist: cards, the player pane and the shared actions modal.
	_check(screen.card_count() == 1, "the shortlist shows one card")
	_check(screen.card_ids() == [str(golden["players"]["free_agent"])],
		"the card is the shortlisted player")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.zone() == "list" and screen.focused_row() == 0,
		"Down enters the shortlist")
	nav.confirmed.emit()
	await _frames(1)
	_check(screen._actions.is_open(), "confirm opens the player actions")
	var action_hints: Array = screen.hints()
	_check(action_hints.size() == 2, "the actions modal narrows the hints")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	nav.confirmed.emit()
	await _frames(2)
	_check(CareerTransfers.shortlist_rows(career, catalog).is_empty(),
		"the actions modal toggles the shortlist")
	_check(screen.card_count() == 0 and screen.is_empty_state(),
		"the empty shortlist shows the empty state")
	_check(changed[0] >= 1, "the shortlist change asks the host to save")
	nav.cancelled.emit()
	await _frames(2)
	_check(not screen._actions.is_open(), "Back closes the player actions")

	# Sent offers: rows, detail, accordion actions.
	screen.open(career, catalog, {"tab": "sent"})
	await _frames(2)
	_check(screen.tab() == "sent", "the payload opens SENT")
	_check(screen.row_count() == 3, "three sent offers are listed")
	var ids: Dictionary = seeded["ids"]
	_check(screen.row_ids() == [ids["buyout"], ids["loan"], ids["target"]],
		"the newest offer is first")
	_check(screen.detail_title() == "SENT OFFERS", "the sent detail pane is titled")
	_check(screen.selected_id() == ids["buyout"], "the first row drives the detail")
	_check(not screen.is_empty_state(), "a populated tab hides the empty state")

	# Pending buyout: only END TALKS.
	screen.focus_row_at(0)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.open_id() == ids["buyout"], "confirm opens the row accordion")
	_check(screen.zone() == "actions", "an open row hands focus to its actions")
	_check(screen.action_ids() == ["withdraw"], "a pending offer can only be ended")
	_check(screen.action_label("withdraw") == "END TALKS", "the action is labelled")
	var sent_hints: Array = screen.hints()
	_check(str(sent_hints[1]["label"]) == "apply", "an open row advertises apply")
	nav.confirmed.emit()
	await _frames(2)
	_check(CareerTransferOffers.find_offer(career, ids["buyout"]).is_empty(),
		"withdraw removes the offer")
	_check(screen.row_count() == 2, "the withdrawn offer leaves the list")

	# Accepted counter: accept the club's terms, then continue in contract talks.
	screen.focus_row_at(0)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.open_id() == ids["loan"], "the loan counter opens")
	_check(screen.action_ids() == ["accept_counter", "reoffer", "withdraw"],
		"a counter offers accept / re-offer / end talks")
	_check(screen.action_label("accept_counter") == "ACCEPT COUNTER-OFFER",
		"the accept action is labelled")
	_check(screen.action_enabled("accept_counter"), "the counter is affordable")
	nav.confirmed.emit()
	await _frames(2)
	var loan_offer := CareerTransferOffers.find_offer(career, ids["loan"])
	_check(str(loan_offer.get("status", "")) == "accepted", "the counter is accepted")
	_check(screen.open_id().is_empty(), "the accordion closes after an action")
	screen.focus_row_at(0)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.action_ids() == ["contract", "withdraw"],
		"an accepted offer offers contract talks")
	nav.confirmed.emit()
	await _frames(1)
	_check(navigated.size() == 1 and str(navigated[0]["view"]) == "contract",
		"contract talks navigate to the contract screen")
	var contract_payload: Dictionary = navigated[0]["payload"]
	_check(str(contract_payload.get("offer_id", "")) == ids["loan"]
		and str(contract_payload.get("player_id", "")) == str(golden["players"]["loan"])
		and str(contract_payload.get("kind", "")) == "loan",
		"the contract payload carries the offer player and kind")

	# Refused offer: send a new one, with the old amount as the preset.
	screen.focus_row_at(1)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.open_id() == ids["target"], "the refused offer opens")
	_check(screen.action_ids() == ["reoffer"], "a refused offer can be sent again")
	_check(screen.action_label("reoffer") == "SEND OFFER AGAIN", "the re-offer label")
	nav.confirmed.emit()
	await _frames(1)
	_check(navigated.size() == 2 and str(navigated[1]["view"]) == "offer",
		"re-offer navigates to the offer screen")
	var offer_payload: Dictionary = navigated[1]["payload"]
	var preset: Dictionary = offer_payload.get("preset", {})
	_check(str(offer_payload.get("player_id", "")) == str(golden["players"]["target"])
		and str(offer_payload.get("kind", "")) == "transfer"
		and int(preset.get("amount", 0)) == 1000,
		"the re-offer preset carries the old amount")

	# Our own transfer list: remove from list.
	screen.open(career, catalog, {"tab": "listed"})
	await _frames(2)
	_check(screen.tab() == "listed", "the payload opens LISTED")
	_check(screen.row_count() == 1, "the listed player is shown")
	_check(screen.row_ids() == [own], "the list row is the listed player")
	var listed_box: Control = screen.get("_listed_box")
	var tabs_panel: Control = screen.get("_tabs_panel")
	_check(listed_box.position.y >= tabs_panel.size.y,
		"the listed list starts below the tab strip, so the tabs stay reachable")
	screen.focus_row_at(0)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.action_ids() == ["remove"], "the listed row has one action")
	_check(screen.action_label("remove") == "REMOVE FROM LIST", "the action is labelled")
	nav.confirmed.emit()
	await _frames(2)
	_check(CareerTransfers.listed_rows(career, catalog).is_empty(),
		"remove from list clears the status")
	_check(screen.row_count() == 0 and screen.is_empty_state(),
		"the empty list shows the empty state")
	_check(screen.empty_title() == "LISTED FOR TRANSFER",
		"the empty state names the tab")

	# Tab strip: arrows and Q/E cycle, Back closes.
	screen.open(career, catalog, {"tab": "shortlist"})
	await _frames(2)
	screen.focus_initial()
	await _frames(1)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(screen.tab() == "sent", "Right cycles the tab strip")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(screen.tab() == "shortlist", "Left cycles back")
	screen._input(_key(KEY_E))
	_check(screen.tab() == "sent", "E switches to the next tab")
	screen._input(_key(KEY_Q))
	_check(screen.tab() == "shortlist", "Q switches to the previous tab")
	var closes_before: int = closes[0]
	nav.cancelled.emit()
	_check(closes[0] == closes_before + 1, "Back leaves the centre")

	# Empty sent tab on a fresh career.
	var fresh := _career()
	screen.open(fresh, catalog, {"tab": "sent"})
	await _frames(2)
	_check(screen.row_count() == 0 and screen.is_empty_state(),
		"a fresh career has no sent offers")
	_check(screen.empty_title() == "SENT OFFERS", "the empty sent state is titled")
	_check(screen.empty_text() == "No offers have been sent yet.",
		"the empty sent state explains itself")

	# ---------------------------------------------------------------- career B
	# Received offers: accept one, refuse the other.
	var second := _career()
	_seed_incoming(second)
	var received_before := CareerIncomingOffers.received_rows(second, catalog)
	_check(received_before.size() == 2, "the window seeds two incoming offers")
	screen.open(second, catalog, {"tab": "received"})
	await _frames(2)
	_check(screen.row_count() == 2, "both received offers are listed")
	_check(screen.unread_badge() == 2 and screen.tab_badge("received") == 2,
		"the unread badge counts both offers")
	_check(screen.detail_title() == "TRANSFER OFFERS", "the received detail is titled")
	var first_id := str(received_before[0].get("offer_id", ""))
	_check(screen.selected_id() == first_id, "the newest received offer drives the detail")
	screen.focus_row_at(0)
	nav.confirmed.emit()
	await _frames(2)
	_check(CareerIncomingOffers.unread_count(second) == 1,
		"opening an offer acknowledges it")
	_check(screen.unread_badge() == 1, "the badge follows the acknowledgement")
	_check(screen.action_ids() == ["accept", "refuse", "counter"],
		"a received transfer offers accept / refuse / counter")
	_check(screen.action_label("accept") == "ACCEPT OFFER", "the accept label")
	nav.confirmed.emit()
	await _frames(2)
	_check(str(CareerIncomingOffers.find_offer(second, first_id).get("status", "")) == "accepted",
		"accepting the offer sells the player")
	_check(screen.row_count() == 1, "the accepted offer leaves the list")
	var last_id := str(CareerIncomingOffers.received_rows(second, catalog)[0].get("offer_id", ""))
	screen.focus_row_at(0)
	nav.confirmed.emit()
	await _frames(2)
	_check(screen.open_id() == last_id, "the second offer opens")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	nav.confirmed.emit()
	await _frames(2)
	_check(str(CareerIncomingOffers.find_offer(second, last_id).get("status", "")) == "refused",
		"refusing the offer declines it")
	_check(screen.row_count() == 0 and screen.is_empty_state(),
		"the empty received tab shows the empty state")
	_check(screen.empty_title() == "RECEIVED OFFERS", "the empty received state is titled")
	_check(screen.unread_badge() == 0, "the badge clears once every offer is read")

	# ---------------------------------------------------------------- career C
	# Received counter through the shared amount modal.
	var third := _career()
	_seed_incoming(third)
	screen.open(third, catalog, {"tab": "received"})
	await _frames(2)
	screen.focus_row_at(0)
	nav.confirmed.emit()
	await _frames(2)
	var counter_id := str(screen.selected_id())
	var counter_row: Dictionary = {}
	for row in CareerIncomingOffers.received_rows(third, catalog):
		if str(row.get("offer_id", "")) == counter_id:
			counter_row = row
	var demand := int((counter_row.get("demand", {}) as Dictionary).get("amount", 0))
	nav.moved.emit(Vector2i.DOWN)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.amount_open(), "counter opens the amount modal")
	_check(screen._amount.value() == demand, "the modal is prefilled with the demand")

	# The inline error path: a counter below the current offer is rejected.
	screen._on_amount_applied(0)
	_check(screen.status_error(), "a rejected counter reports an error inline")
	_check(screen.status() == "counter-offer amount must be positive",
		"the error keeps the module wording")
	nav.confirmed.emit()
	await _frames(2)
	var countered := CareerIncomingOffers.find_offer(third, counter_id)
	_check(str(countered.get("status", "")) == "counter", "the counter is sent")
	var counter_terms = countered.get("counter")
	_check(counter_terms is Dictionary
		and int((counter_terms as Dictionary).get("amount", 0)) == demand,
		"the counter carries the modal amount")
	_check(not screen.amount_open(), "the modal closes after applying")
	_check(not screen.status_error(), "a successful action clears the error")
	_check(screen.row_count() == 2, "a countered offer stays in the list")

	screen.queue_free()
	_finish()


func _load_catalog() -> bool:
	catalog = TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	return catalog.is_loaded()


func _career() -> Career:
	var career := CareerFactory.create(catalog, CLUB_ID, "Golden Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		return null
	career.data["created_at"] = "2026-07-01T00:00:00.000000Z"
	career.data["date"] = "2026-07-01"
	return career


# A refused transfer, a countered loan and a pending buyout, oldest first.
func _seed_sent(career: Career, golden: Dictionary) -> Dictionary:
	var players: Dictionary = golden["players"]
	var steps: Dictionary = golden["steps"]
	var target := str(players["target"])
	var low := CareerTransferOffers.submit(career, catalog, target, "transfer", 1000)
	if not bool(low.get("ok", false)):
		return {"ok": false, "error": str(low.get("error", ""))}
	career.data["date"] = str(steps["submit_low"]["due"])
	CareerTransferOffers.process_due(career, catalog, career.date)
	career.data["date"] = str(steps["loan_submit"]["created_at"])
	var loan := CareerTransferOffers.submit(career, catalog, str(players["loan"]), "loan",
		int(steps["loan_submit"]["amount"]), int(steps["loan_submit"]["loan_fee"]),
		int(steps["loan_submit"]["wage_share"]))
	if not bool(loan.get("ok", false)):
		return {"ok": false, "error": str(loan.get("error", ""))}
	career.data["date"] = str((loan.get("offer", {}) as Dictionary).get("due", career.date))
	CareerTransferOffers.process_due(career, catalog, career.date)
	var buyout := CareerTransferOffers.submit(career, catalog, str(players["pending"]),
		"transfer", null, null, null, true)
	if not bool(buyout.get("ok", false)):
		return {"ok": false, "error": str(buyout.get("error", ""))}
	return {
		"ok": true, "error": "",
		"ids": {
			"target": str((low.get("offer", {}) as Dictionary).get("offer_id", "")),
			"loan": str((loan.get("offer", {}) as Dictionary).get("offer_id", "")),
			"buyout": str((buyout.get("offer", {}) as Dictionary).get("offer_id", "")),
		},
	}


func _seed_incoming(career: Career) -> void:
	if career == null:
		return
	career.data["date"] = "2026-07-01"
	career.incoming_market_date = "2026-07-01"
	CareerIncomingOffers.process_days(career, catalog, "2026-07-01", "2026-07-07")
	career.data["date"] = "2026-07-14"
	CareerIncomingOffers.process_days(career, catalog, career.incoming_market_date,
		career.date)
