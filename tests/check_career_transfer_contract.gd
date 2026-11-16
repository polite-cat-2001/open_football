extends SceneTree
# Headless check for CareerTransferContractScreen (prototype
# TransferContractScreen.svelte): a free agent's defaults, the prototype's
# steps (wage, length, role cycle, clause), the shared amount modal, submitting
# and the pending state, the club-offer path (fee from the accepted offer),
# accepting the player's counter, signing and the signals the host consumes.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_contract.gd

const TARGET := "342229"
const FREE_AGENT := "703304"

var failures: Array[String] = []
var _navigate: Array = []
var _changed := 0
var _closed := 0
var _screen: CareerTransferContractScreen
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
	print("== check_career_transfer_contract: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _career(catalog: TeamCatalog) -> Career:
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	career.data["date"] = "2026-07-01"
	return career


func _player(catalog: TeamCatalog, player_id: String) -> Dictionary:
	return catalog.career_player(int(player_id), false)


func _step_to(id: String) -> void:
	var ids: Array = _screen.call("_focus_ids")
	for index in ids.size():
		if str(ids[index]) == id:
			_screen.set("_focus", index)
			return


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := _career(catalog)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen = CareerTransferContractScreen.new()
	_screen.position = Vector2(220.0, 210.0)
	_screen.size = Vector2(1480.0, 626.0)
	host.add_child(_screen)
	_screen.navigate.connect(func(view: String, payload: Dictionary) -> void:
		_navigate.append({"view": view, "payload": payload}))
	_screen.changed.connect(func() -> void: _changed += 1)
	_screen.closed.connect(func() -> void: _closed += 1)
	_nav = root.get_node("UiNav")

	# Free agent: defaults, steps and the modal.
	_screen.open(career, catalog, {"player_id": FREE_AGENT, "kind": "free"})
	await _frames(2)
	var free_defaults := CareerTransferContracts.contract_defaults(catalog, career,
		_player(catalog, FREE_AGENT))
	_check(_screen.state().get("status") == "", "a fresh free agent starts without talks")
	_check(_screen.draft() == free_defaults, "the draft starts at the contract defaults")
	_check(str(_screen.draft().get("squad_role", "")) == "prospect", "the role is projected")
	_check(_screen.focused_id() == "weekly_wage", "the wage owns the first focus")
	_check(_screen.hints().size() == 3, "the hints describe adjust/select/back")

	_nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(int(_screen.draft()["weekly_wage"]) == 1000, "the wage clamps at the minimum")
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(int(_screen.draft()["weekly_wage"]) == 2000, "right adds the wage step")
	_nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(int(_screen.draft()["weekly_wage"]) == 1000, "left removes the wage step")

	_nav.moved.emit(Vector2i.DOWN)
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_screen.focused_id() == "years", "down reaches the length")
	_check(int(_screen.draft()["years"]) == int(free_defaults["years"]) + 1,
		"right adds a contract year")

	_nav.moved.emit(Vector2i.DOWN)
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_screen.focused_id() == "squad_role", "down reaches the role")
	_check(str(_screen.draft()["squad_role"]) == "key", "the role cycles past the last one")
	_nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(str(_screen.draft()["squad_role"]) == "prospect", "left cycles the role back")

	var clause_before := int(_screen.draft()["release_clause"])
	_nav.moved.emit(Vector2i.DOWN)
	_nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(_screen.focused_id() == "release_clause", "down reaches the release clause")
	_check(int(_screen.draft()["release_clause"]) > clause_before,
		"right raises the release clause")

	# Weekly wage through the shared amount modal.
	for index in 3:
		_nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(_screen.focused_id() == "weekly_wage", "up walks back to the wage")
	_nav.confirmed.emit()
	await _frames(1)
	var modal = _screen.get("_amount_modal")
	_check(modal != null and modal.is_open(), "confirm on the wage opens the amount modal")
	_check(int(modal.value()) == 1000, "the modal is prefilled with the wage")
	modal.set("_digits", PackedInt32Array([0, 0, 0, 0, 0, 5, 0, 0, 0]))
	_nav.confirmed.emit()
	await _frames(1)
	_check(not modal.is_open(), "the modal closes after applying")
	_check(int(_screen.draft()["weekly_wage"]) == 5000, "the typed wage lands in the draft")

	# Submit -> pending, then back.
	_step_to("submit")
	_nav.confirmed.emit()
	await _frames(1)
	_check(str(_screen.state().get("status", "")) == "pending",
		"submitting starts the player's thinking time")
	_check(_changed == 1 and _navigate.is_empty(), "a submit reports the change, no navigation")
	_check(str(_screen.focused_id()) == "back", "the pending screen only offers back")
	_check(_screen.hints().size() == 2, "the pending hints drop the adjust row")
	var due := str(_screen.state().get("due", ""))
	_nav.cancelled.emit()
	await _frames(1)
	_check(_closed == 1, "back closes the contract screen")

	career.data["date"] = due
	CareerTransferContracts.process_due(career, catalog, career.date)
	_screen.open(career, catalog, {"player_id": FREE_AGENT, "kind": "free"})
	await _frames(2)
	_check(str(_screen.state().get("status", "")) == "accepted",
		"the free agent accepts the offered terms")
	_check(bool(_screen.state().get("can_sign", false)), "the accepted deal can be signed")
	_check(_screen.focused_id() == "sign", "sign is the only action left")
	_nav.confirmed.emit()
	await _frames(1)
	_check(_changed == 2, "signing reports the change")
	_check(_navigate.size() == 1 and str(_navigate[0]["view"]) == "centre",
		"signing routes to the transfer centre")
	if _navigate.size() == 1:
		_check(str((_navigate[0]["payload"] as Dictionary).get("tab", "")) == "sent",
			"the centre opens on SENT")
	_check(career.player_ids.has(FREE_AGENT), "the free agent joins the squad")

	# A club offer that the club accepted: the fee comes from the offer, the
	# contract goes pending -> counter -> accepted -> signed.
	_navigate.clear()
	var other := _career(catalog)
	var bought := CareerTransferOffers.submit(other, catalog, TARGET, "transfer",
		null, null, null, true)
	_check(bool(bought.get("ok", false)), "the buyout offer is accepted by the club: "
		+ str(bought.get("error", "")))
	var offer: Dictionary = bought.get("offer", {})
	var offer_id := str(offer.get("offer_id", ""))
	other.data["date"] = str(offer.get("due", ""))
	CareerTransferOffers.process_due(other, catalog, other.date)
	var offer_fee := int((CareerTransferOffers.find_offer(other, offer_id) as Dictionary)
		.get("amount", 0))

	_screen.open(other, catalog, {"player_id": TARGET, "offer_id": offer_id,
		"kind": "transfer"})
	await _frames(2)
	var transfer_defaults := CareerTransferContracts.contract_defaults(catalog, other,
		_player(catalog, TARGET))
	_check(_screen.state().get("status") == "", "the accepted offer opens the contract step")
	_check(bool(_screen.state().get("offer_accepted", false)),
		"the state reports the accepted club offer")
	_check(_screen.draft() == transfer_defaults, "the draft starts at the club deal defaults")
	var fee_row: Dictionary = (_screen.get("_info_rows") as Array)[0]
	_check((fee_row["value"] as Label).text == CareerPlayerPane.money(offer_fee),
		"the agreed fee is shown from the accepted offer")
	var balance_row: Dictionary = (_screen.get("_info_rows") as Array)[1]
	_check((balance_row["value"] as Label).text
		== CareerPlayerPane.money(int(other.balance) - offer_fee),
		"the balance after the deal is shown")
	_check((_screen.call("_focus_ids") as Array).has("submit"),
		"an accepted offer unlocks the submit even for a long contract")

	_step_to("submit")
	_nav.confirmed.emit()
	await _frames(1)
	_check(str(_screen.state().get("status", "")) == "pending",
		"the terms are sent to the player")
	_check(_changed == 3, "the contract submit reports the change")

	other.data["date"] = str(_screen.state().get("due", ""))
	CareerTransferContracts.process_due(other, catalog, other.date)
	_screen.open(other, catalog, {"player_id": TARGET, "offer_id": offer_id,
		"kind": "transfer"})
	await _frames(2)
	_check(str(_screen.state().get("status", "")) == "counter",
		"the player answers with a counter")
	_check(bool((_screen.get("_reply") as Control).visible), "the counter block is shown")
	_check(bool((_screen.get("_reply_terms") as Control).visible), "the counter terms are shown")
	_check((_screen.call("_focus_ids") as Array).has("accept_counter"),
		"the counter can be accepted")
	_step_to("accept_counter")
	_nav.confirmed.emit()
	await _frames(1)
	_check(str(_screen.state().get("status", "")) == "accepted",
		"accepting the counter agrees the terms")
	_check(_changed == 4, "accepting the counter reports the change")
	_check(_screen.focused_id() == "sign", "sign takes over after the counter")

	_nav.confirmed.emit()
	await _frames(1)
	_check(_changed == 5, "signing the transfer reports the change")
	_check(_navigate.size() == 1 and str(_navigate[0]["view"]) == "centre",
		"the signed transfer routes to the centre")
	_check(other.player_ids.has(TARGET), "the player joins the squad")
	var history: Array = other.transfer_history
	_check(not history.is_empty() and str((history[-1] as Dictionary).get("status", ""))
		== "completed", "the transfer is written into the history")

	_finish()
