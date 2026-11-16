extends SceneTree
# Headless golden check for transfer offers to clubs (ticket 07): proposal
# defaults, validation, the club's response (refuse / counter / accept), the
# retry window, withdrawal, loans, and the transfer-centre rows.
# The fixture comes from the prototype app (tmp/oracle_transfers.py).
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_offers.gd

const GOLDEN := "res://tests/fixtures/career_transfer_offers_golden.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	print("== check_career_transfer_offers: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _same(left, right) -> bool:
	if left == null or right == null:
		return (left == null) == (right == null)
	if left is Dictionary or right is Dictionary:
		if not (left is Dictionary) or not (right is Dictionary):
			return false
		if (left as Dictionary).size() != (right as Dictionary).size():
			return false
		for key in left:
			if not (right as Dictionary).has(key):
				return false
			if not _same(left[key], right[key]):
				return false
		return true
	if left is Array or right is Array:
		if not (left is Array) or not (right is Array):
			return false
		if (left as Array).size() != (right as Array).size():
			return false
		for index in range((left as Array).size()):
			if not _same(left[index], right[index]):
				return false
		return true
	if left is String or right is String:
		return str(left) == str(right)
	return is_equal_approx(float(left), float(right))


func _compare(label: String, actual: Dictionary, expected: Dictionary,
		skip: Array = []) -> void:
	for key in expected:
		if skip.has(key):
			continue
		var ok := _same(actual.get(key), expected[key])
		_check(ok, "%s: %s" % [label, key])
		if not ok:
			print("    expected: ", expected[key], " actual: ", actual.get(key))


func _offer_view(career: Career, offer_id: String) -> Dictionary:
	return CareerTransferOffers.view(career,
		CareerTransferOffers.find_offer(career, offer_id))


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the offers golden loads")
	if not (golden is Dictionary):
		_finish()
		return
	var header: Dictionary = golden["career"]
	var steps: Dictionary = golden["steps"]
	var players: Dictionary = golden["players"]
	var target := str(players["target"])
	var loan_player := str(players["loan"])
	var career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	career.data["created_at"] = str(header["created_at"])
	career.data["date"] = str(header["date"])

	var proposal := CareerTransferOffers.proposal(career, catalog, target, "transfer")
	_compare("proposal", proposal, steps["proposal"])

	var submitted := CareerTransferOffers.submit(career, catalog, target, "transfer", 1000)
	_check(bool(submitted.get("ok", false)), "a transfer offer can be sent")
	var offer_id := str((submitted.get("offer", {}) as Dictionary).get("offer_id", ""))
	_compare("submit_low", submitted.get("offer", {}), steps["submit_low"])
	if offer_id.is_empty():
		_finish()
		return

	career.data["date"] = str(steps["submit_low"]["due"])
	var events := CareerTransferOffers.process_due(career, catalog, career.date)
	_check(events.size() == 1, "one offer is resolved on its due date")
	if not events.is_empty():
		_check(str(events[0].get("type", "")) == "transfer.offer.refused",
			"the club refuses a low offer")
	_compare("refused", _offer_view(career, offer_id), steps["refused"])

	var early := CareerTransferOffers.submit(career, catalog, target, "transfer", 1000)
	_check(not bool(early.get("ok", true)), "a refused player cannot be approached again yet")
	_check(str(early.get("error", "")) == str(steps["retry_error"]["error"]),
		"the retry error names the date")

	career.data["date"] = str(steps["refused"]["retry_after"])
	var countered := CareerTransferOffers.submit(career, catalog, target, "transfer",
		int(steps["counter_submit"]["amount"]))
	_check(bool(countered.get("ok", false)), "the offer can be repeated after the retry date")
	offer_id = str((countered.get("offer", {}) as Dictionary).get("offer_id", ""))
	_compare("counter_submit", countered.get("offer", {}), steps["counter_submit"])

	career.data["date"] = str(steps["counter_submit"]["due"])
	var resolved := CareerTransferOffers.process_due(career, catalog, career.date)
	_check(resolved.size() == 1 and str(resolved[0].get("type", "")) == "transfer.offer.counter",
		"the club answers with a counter-offer")
	_compare("counter_response", _offer_view(career, offer_id), steps["counter_response"])
	_check(_same(_offer_view(career, offer_id).get("counter"),
		steps["counter_response"]["counter"]), "the counter terms match the prototype")

	var accepted := CareerTransferOffers.accept_counter(career, catalog, offer_id)
	_check(bool(accepted.get("ok", false)), "the counter-offer can be accepted")
	_compare("accepted", accepted.get("offer", {}), steps["accepted"])
	_check(CareerTransferOffers.active_for(career, target).is_empty(),
		"an accepted offer is no longer active")

	var rows := CareerTransfers.sent_offer_rows(career, catalog)
	_check(rows.size() == 1, "the sent-offers list has one row")
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		var expected: Dictionary = steps["sent_rows"][0]
		_check(str(row.get("offer_id", "")) == str(expected["offer_id"]),
			"sent row: offer_id")
		_check(_same((row.get("offer", {}) as Dictionary).get("status"), expected["status"]),
			"sent row: offer status")
		_check(_same((row.get("offer", {}) as Dictionary).get("amount"), expected["amount"]),
			"sent row: amount")
		_check(_same((row.get("offer", {}) as Dictionary).get("due"), expected["due"]),
			"sent row: due")
		_check(_same((row.get("offer", {}) as Dictionary).get("kind"), expected["kind"]),
			"sent row: kind")
		_check(_same(row.get("can_withdraw"), expected["can_withdraw"]),
			"sent row: can_withdraw")
		_check(_same(row.get("can_negotiate"), expected["can_negotiate"]),
			"sent row: can_negotiate")
		_check(_same((row.get("player", {}) as Dictionary).get("name"),
			expected["player_name"]), "sent row: player name")
		_check(str(row.get("status_label", "")) == "Accepted", "sent row: status label")
		_check(str(row.get("kind_label", "")) == "Transfer", "sent row: kind label")
		var detail := CareerTransferOffers.detail(career, catalog, offer_id)
		_check(bool(detail.get("ok", false))
			and str((detail.get("player", {}) as Dictionary).get("player_id", "")) == target,
			"the offer detail carries the player")

	var withdrawn := CareerTransferOffers.withdraw(career, catalog, offer_id)
	_check(bool(withdrawn.get("ok", false)), "the offer can be withdrawn")
	_check(CareerTransfers.sent_offer_rows(career, catalog).is_empty(),
		"the withdrawn offer leaves the sent list")
	_check(career.journal[-1].get("type") == str(steps["after_withdraw"]["journal_last"]),
		"the withdrawal is journalled")
	_check(CareerTransferOffers.withdraw(career, catalog, offer_id).get("ok", true) == false,
		"an unknown offer cannot be withdrawn")

	career.data["date"] = "2026-07-10"
	var loan_proposal := CareerTransferOffers.proposal(career, catalog, loan_player, "loan")
	_compare("loan_proposal", loan_proposal, steps["loan_proposal"])
	var loan_submit := CareerTransferOffers.submit(career, catalog, loan_player, "loan",
		int(steps["loan_submit"]["amount"]), int(steps["loan_submit"]["loan_fee"]),
		int(steps["loan_submit"]["wage_share"]))
	_check(bool(loan_submit.get("ok", false)), "a loan offer can be sent")
	var loan_id := str((loan_submit.get("offer", {}) as Dictionary).get("offer_id", ""))
	_compare("loan_submit", loan_submit.get("offer", {}), steps["loan_submit"])
	career.data["date"] = str(steps["loan_submit"]["due"])
	CareerTransferOffers.process_due(career, catalog, career.date)
	_compare("loan_response", _offer_view(career, loan_id), steps["loan_response"])
	if not (steps["loan_response"] as Dictionary).get("counter") == null:
		var loan_accepted := CareerTransferOffers.accept_counter(career, catalog, loan_id)
		_check(bool(loan_accepted.get("ok", false)), "the loan counter can be accepted")
		_compare("loan_accepted", loan_accepted.get("offer", {}), steps["loan_accepted"])

	# Shortlist and the club's own listing rules.
	var toggle := CareerTransfers.toggle_shortlist(career, catalog, target)
	_check(bool(toggle.get("ok", false)) and bool(toggle.get("shortlisted", false)),
		"shortlisting adds the player")
	_check((CareerTransfers.shortlist_rows(career, catalog) as Array).size() == 1,
		"the shortlist row is built")
	_check(not bool(CareerTransfers.toggle_shortlist(career, catalog, target)
		.get("shortlisted", true)), "shortlisting again removes the player")
	_check((career.shortlist as Array).is_empty(), "the shortlist is empty again")
	_check(not bool(CareerTransfers.toggle_shortlist(career, catalog, "999999999")
		.get("ok", true)), "an unknown player cannot be shortlisted")

	var own := str(career.player_ids[0])
	var listed := CareerTransfers.set_status(career, catalog, own, "transfer")
	_check(bool(listed.get("ok", false)) and str(listed.get("status", "")) == "transfer",
		"an own player can be listed for transfer")
	_check((CareerTransfers.listed_rows(career, catalog) as Array).size() == 1,
		"the listed rows show the player")
	_check(str(CareerTransfers.set_status(career, catalog, own, "transfer").get("status", "x")) == "",
		"the same status clears the listing")
	_check(CareerTransfers.set_status(career, catalog, own, "transfer").get("status", "") == "transfer",
		"the listing can be set again")
	_check(not bool(CareerTransfers.set_status(career, catalog, target, "transfer")
		.get("ok", true)), "only own players can be listed")
	_check(not bool(CareerTransfers.set_status(career, catalog, own, "sold").get("ok", true)),
		"an unknown status is rejected")
	_check(str(CareerTransfers.set_status(career, catalog, own, "loan").get("status", "")) == "loan",
		"a different status replaces the listing")
	CareerTransfers.set_status(career, catalog, own, "none")

	# Validation errors keep the prototype's wording.
	var own_offer := CareerTransferOffers.submit(career, catalog, own, "transfer", 1000)
	_check(str(own_offer.get("error", "")) == "you cannot make an offer for your own player",
		"your own player cannot be approached")
	var own_proposal := CareerTransferOffers.proposal(career, catalog, own, "transfer")
	_check(not bool(own_proposal.get("can_submit", true)),
		"the offer screen blocks your own player")
	_check(str(own_proposal.get("reason", "")) == "you cannot make an offer for your own player",
		"the offer screen explains why")
	var negative := CareerTransferOffers.submit(career, catalog, target, "transfer", -5)
	_check(str(negative.get("error", "")) == "offer amount cannot be negative",
		"a negative fee is rejected")
	var huge := CareerTransferOffers.submit(career, catalog, target, "transfer", 999999999)
	_check(str(huge.get("error", "")) == "offer amount is above the club balance",
		"an offer above the balance is rejected")
	var bad_share := CareerTransferOffers.submit(career, catalog, str(players["pending"]),
		"loan", 1000, 1000, 120)
	_check(str(bad_share.get("error", "")) == "wage share must be between 0 and 100",
		"an impossible wage share is rejected")
	var bad_kind := CareerTransferOffers.submit(career, catalog, target, "swap", 1000)
	_check(str(bad_kind.get("error", "")) == "unknown offer kind",
		"an unknown offer kind is rejected")
	var free_agent := str(players["free_agent"])
	var loan_buyout := CareerTransferOffers.submit(career, catalog, free_agent, "loan",
		1000, 1000, 50, true)
	_check(str(loan_buyout.get("error", "")) == "buyout is only available for a transfer",
		"a loan cannot be a buyout")
	var free_buyout := CareerTransferOffers.submit(career, catalog, free_agent, "transfer",
		null, null, null, true)
	_check(str(free_buyout.get("error", "")) == "release clause is not available for this player",
		"a free agent has no release clause")

	# A buyout pays the clause and is always accepted.
	career.data["date"] = str(steps["accepted"]["created_at"])
	var other := str(players["pending"])
	var buyout := CareerTransferOffers.submit(career, catalog, other, "transfer", null, null, null, true)
	_check(bool(buyout.get("ok", false)), "a buyout offer can be sent")
	var buyout_id := str((buyout.get("offer", {}) as Dictionary).get("offer_id", ""))
	career.data["date"] = str((buyout.get("offer", {}) as Dictionary).get("due", career.date))
	CareerTransferOffers.process_due(career, catalog, career.date)
	_check(str(_offer_view(career, buyout_id).get("status", "")) == "accepted",
		"a buyout is accepted without negotiation")
	_finish()
