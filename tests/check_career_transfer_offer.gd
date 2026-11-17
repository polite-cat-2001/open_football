extends SceneTree
# Headless check for CareerTransferOffer (prototype TransferOfferScreen.svelte):
# proposal defaults, the transfer/loan field sets, the prototype's step sizes,
# the buyout switch, the shared amount modal, submit success and the club-side
# error line, the preset re-offer, the disabled own-player case and the signals
# the transfers host consumes.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_offer.gd

const TARGET := "342229"
const LOAN := "1001305"

var failures: Array[String] = []
var _changed := 0
var _closed := 0


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
	print("== check_career_transfer_offer: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _career(catalog: TeamCatalog) -> Career:
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	career.data["date"] = "2026-07-01"
	return career


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := _career(catalog)
	_check(career != null, "the career is created: " + CareerFactory.last_error)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen := CareerTransferOffer.new()
	screen.position = Vector2(220.0, 210.0)
	screen.size = Vector2(1480.0, 626.0)
	host.add_child(screen)
	screen.changed.connect(func() -> void: _changed += 1)
	screen.closed.connect(func() -> void: _closed += 1)
	var nav := root.get_node("UiNav")

	# Transfer defaults.
	screen.open(career, catalog, {"player_id": TARGET, "kind": "transfer"})
	await _frames(2)
	var proposal := CareerTransferOffers.proposal(career, catalog, TARGET, "transfer")
	var offer := screen.offer()
	_check(screen.focused_id() == "amount", "the fee owns the first focus")
	_check(int(offer["amount"]) == int(proposal["fee"]), "the fee starts at the proposal")
	_check(int(offer["loan_fee"]) == int(proposal["loan_fee"]),
		"the loan fee starts at the proposal")
	_check(int(offer["wage_share"]) == 50, "the wage share starts at 50%")
	_check(not bool(offer["buyout"]), "the buyout starts off")
	_check(screen.can_submit(), "the proposal is submittable")
	_check(screen.hints().size() == 3, "the hints describe adjust/select/back")

	# Step: 5% of the release clause, rounded to 100k.
	var clause := int(proposal["release_clause"])
	var step := maxi(100000, roundi(float(clause) * 0.05 / 100000.0) * 100000)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(int(screen.offer()["amount"]) == int(proposal["fee"]) + step,
		"right steps the fee by the prototype step")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(int(screen.offer()["amount"]) == int(proposal["fee"]),
		"left steps the fee back")

	# The amount modal opens prefilled and applies.
	nav.confirmed.emit()
	await _frames(1)
	var modal = screen.get("_amount_modal")
	_check(modal != null and modal.is_open(), "confirm opens the shared amount modal")
	_check(int(modal.value()) == int(proposal["fee"]), "the modal is prefilled with the fee")
	modal.set("_digits", PackedInt32Array([9, 9, 9, 9, 9, 9, 9, 9, 9]))
	nav.confirmed.emit()
	await _frames(1)
	_check(not modal.is_open(), "the modal closes after applying")
	_check(int(screen.offer()["amount"]) == 999999999, "the typed amount lands in the field")

	# Submitting above the balance shows the club-side error, no navigation.
	nav.moved.emit(Vector2i.DOWN)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.focused_id() == "submit", "down reaches the submit action")
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.status() == "offer amount is above the club balance",
		"an unaffordable offer reports the English error")
	_check(screen.status_error(), "the error is flagged to the host")
	_check(_changed == 0 and _closed == 0, "a failed submit changes nothing")

	# The buyout switch: confirm and arrows toggle it.
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(screen.focused_id() == "buyout", "the buyout row is focusable")
	nav.confirmed.emit()
	await _frames(1)
	_check(bool(screen.offer()["buyout"]), "confirm turns the buyout on")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(not bool(screen.offer()["buyout"]), "right toggles the buyout off")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(bool(screen.offer()["buyout"]), "left toggles the buyout on")

	# Submit a buyout: accepted, the career changes and the offer screen stands
	# down to the search results (the centre is not forced on the manager).
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.status() == "", "the buyout submit succeeds")
	_check(_changed == 1, "a successful submit reports the career change")
	_check(_closed == 1, "a successful submit closes the offer screen")
	var stored: Dictionary = career.transfer_offers[0] if not career.transfer_offers.is_empty() \
		else {}
	_check(bool(stored.get("buyout", false)), "the stored offer is a buyout")
	_check(int(stored.get("amount", 0)) == clause, "the buyout stores the release clause")

	# Loan fields: loan fee plus wage share, 5% steps on the share.
	screen.open(career, catalog, {"player_id": LOAN, "kind": "loan"})
	await _frames(2)
	var loan_proposal := CareerTransferOffers.proposal(career, catalog, LOAN, "loan")
	_check(str(screen.offer()["kind"]) == "loan", "the loan kind is kept")
	_check(screen.focused_id() == "loan_fee", "a loan starts on the loan fee")
	_check(int(screen.offer()["loan_fee"]) == int(loan_proposal["loan_fee"]),
		"the loan fee starts at the proposal")
	var loan_base := maxi(maxi(int(loan_proposal["release_clause"]),
		int(loan_proposal["market_value"])), 1000000)
	var loan_step := maxi(10000, roundi(float(loan_base) * 0.005 / 10000.0) * 10000)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(int(screen.offer()["loan_fee"]) == int(loan_proposal["loan_fee"]) + loan_step,
		"right steps the loan fee")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.focused_id() == "wage_share", "down reaches the wage share")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(int(screen.offer()["wage_share"]) == 55, "the wage share steps by 5%")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.focused_id() == "submit", "the loan submit is the third row")
	nav.confirmed.emit()
	await _frames(1)
	_check(_changed == 2 and _closed == 2,
		"the loan offer is sent and the screen stands down")
	var loan_offer: Dictionary = {}
	for item in career.transfer_offers:
		if str(item.get("player_id", "")) == LOAN:
			loan_offer = item
	_check(str(loan_offer.get("kind", "")) == "loan", "the stored offer is a loan")
	_check(int(loan_offer.get("loan_fee", 0)) == int(loan_proposal["loan_fee"]) + loan_step,
		"the loan fee is stored")
	_check(int(loan_offer.get("wage_share", 0)) == 55, "the wage share is stored")

	# A preset (the club's counter) wins over the defaults.
	screen.open(career, catalog, {"player_id": TARGET, "kind": "transfer",
		"preset": {"amount": 12345678}})
	await _frames(2)
	_check(int(screen.offer()["amount"]) == 12345678, "the preset amount replaces the default")

	# Own player: submit is refused by the proposal.
	var own := str(career.player_ids[0])
	screen.open(career, catalog, {"player_id": own, "kind": "transfer"})
	await _frames(2)
	_check(not screen.can_submit(), "own players cannot be offered for")
	nav.moved.emit(Vector2i.DOWN)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	nav.confirmed.emit()
	await _frames(1)
	_check(screen.status() == "you cannot make an offer for your own player",
		"the own-player refusal is shown inline")
	_check(_changed == 2 and _closed == 2, "the refusal changes nothing")

	# Back.
	nav.cancelled.emit()
	await _frames(1)
	_check(_closed == 3, "back closes the screen")

	print("== check_career_transfer_offer: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
