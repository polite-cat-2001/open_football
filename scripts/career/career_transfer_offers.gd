class_name CareerTransferOffers
extends RefCounted
# Offers to other clubs, ported from server/career/transfers.py: proposal
# defaults, validation, the club's response after its thinking days
# (accept / refuse / counter, two counters max) and the counters themselves.
# Every random value comes from CareerRng, so the amounts and dates match the
# prototype for the same seed.

const OFFER_KINDS := ["transfer", "loan"]
const ACTIVE_STATUSES := ["pending", "counter"]
const MAX_COUNTER_OFFERS := 2
const RESPONSE_DAYS := [2, 3, 4]
const RETRY_DAYS := 7
const MIN_MARKET_VALUE := 50000

const PENDING_MESSAGE := "The club is considering the offer."
const ACCEPTED_MESSAGE := "The club accepted the offer."
const REFUSED_MESSAGE := "The club rejected the offer."
const COUNTER_MESSAGE := "The club proposes new terms."
const WITHDRAWN_MESSAGE := "Negotiations have ended."


static func proposal(career: Career, catalog: TeamCatalog, player_id,
		kind := "transfer") -> Dictionary:
	# Defaults the prototype's offer screen starts from.
	var player := _player(catalog, career, player_id)
	if player.is_empty():
		return {"fee": 0, "loan_fee": 0, "wage_share": 0, "buyout": false,
			"buyout_allowed": false, "release_clause": 0, "market_value": 0,
			"balance": _balance(career), "can_submit": false,
			"reason": "player not found"}
	var clause := int(player.get("release_clause", 0))
	var market := int(player.get("market_value", 0))
	var value := market if market > 0 else (clause if clause > 0 else 1000000)
	var fee := clause if clause > 0 else value
	var loan_fee := maxi(10000, python_round(float(value) * 0.05 / 10000.0) * 10000)
	var can_submit := true
	var reason := ""
	if bool(career.player_ids.has(str(player_id))):
		can_submit = false
		reason = "you cannot make an offer for your own player"
	elif career.balance != null:
		var compared := loan_fee if str(kind) == "loan" else fee
		if compared > int(career.balance):
			can_submit = false
			reason = "loan fee is above the club balance" if str(kind) == "loan" \
				else "offer amount is above the club balance"
	return {
		"fee": fee,
		"loan_fee": loan_fee,
		"wage_share": 50,
		"buyout": false,
		"buyout_allowed": int(player.get("team_id", 0)) > 0 and clause > 0,
		"release_clause": clause,
		"market_value": market,
		"balance": _balance(career),
		"can_submit": can_submit,
		"reason": reason,
		"kind": str(kind),
		"player_id": str(player_id),
	}


static func submit(career: Career, catalog: TeamCatalog, player_id, kind := "transfer",
		amount = null, loan_fee = null, wage_share = null, buyout := false) -> Dictionary:
	var player := _player(catalog, career, player_id)
	if player.is_empty():
		return {"ok": false, "error": "player not found", "offer": {}}
	var key := str(player.get("id", ""))
	var offer_kind := str(kind if not str(kind).is_empty() else "transfer")
	if not OFFER_KINDS.has(offer_kind):
		return _fail("unknown offer kind")
	var existing: Array = []
	for offer in career.transfer_offers:
		if offer is Dictionary and str(offer.get("player_id", "")) == key:
			existing.append(offer)
	var active := _active_offer(career, key)
	var blocked := block(career, key, offer_kind)
	if str(blocked.get("status", "")) == "pending":
		return _fail("there is already an active offer for this player")
	if str(blocked.get("status", "")) == "refused":
		return _fail("you can make another offer after %s"
			% str(blocked.get("retry_after", "")))
	if active.is_empty() and not existing.is_empty():
		var last: Dictionary = existing[-1]
		if str(last.get("status", "")) == "accepted":
			return _fail("the club has already accepted an offer for this player")

	var clean_fee := 0
	var clean_loan_fee := 0
	var clean_share := 0
	var clean_buyout := false
	if offer_kind == "transfer":
		var cleaned := _clean_transfer(career, player, amount, bool(buyout))
		if not cleaned.get("ok", false):
			return _fail(str(cleaned.get("error", "")))
		clean_fee = int(cleaned["amount"])
		clean_buyout = bool(cleaned["buyout"])
	else:
		if bool(buyout):
			return _fail("buyout is only available for a transfer")
		var loan := _clean_loan(career, player, amount, loan_fee, wage_share)
		if not loan.get("ok", false):
			return _fail(str(loan.get("error", "")))
		clean_loan_fee = int(loan["fee"])
		clean_share = int(loan["share"])
		clean_fee = clean_loan_fee
		clean_buyout = false

	if not active.is_empty():
		var kept: Array = []
		for offer in career.transfer_offers:
			if not is_same(offer, active):
				kept.append(offer)
		career.transfer_offers = kept
		active["kind"] = offer_kind
		active["amount"] = int(clean_fee)
		active["loan_fee"] = int(clean_loan_fee)
		active["wage_share"] = int(clean_share)
		active["buyout"] = clean_buyout
		active["status"] = "pending"
		active["counter"] = null
		active["responded_at"] = null
		active["overall"] = roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0
		active["due"] = _response_due(career, active)
		active["message"] = PENDING_MESSAGE
		career.transfer_offers.append(active)
		_journal(career, "transfer.offer.sent", {
			"offer_id": str(active.get("id", "")),
			"player_id": key,
			"kind": offer_kind,
			"amount": int(clean_fee),
		})
		return {"ok": true, "error": "", "offer": view(career, active)}

	var remaining: Array = []
	for offer in career.transfer_offers:
		if not (offer is Dictionary) or str(offer.get("player_id", "")) != key:
			remaining.append(offer)
	career.transfer_offers = remaining
	var offer_id := _offer_id(career, key, offer_kind)
	var created := {
		"id": offer_id,
		"player_id": key,
		"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
		"kind": offer_kind,
		"amount": int(clean_fee),
		"loan_fee": int(clean_loan_fee),
		"wage_share": int(clean_share),
		"buyout": clean_buyout,
		"status": "pending",
		"due": null,
		"created_at": career.date,
		"responded_at": null,
		"counter_offers": 0,
		"counter": null,
		"retry_after": null,
		"message": PENDING_MESSAGE,
		"demand": _demand(career, offer_id, player, offer_kind),
	}
	created["due"] = _response_due(career, created)
	career.transfer_offers.append(created)
	_journal(career, "transfer.offer.sent", {
		"offer_id": offer_id,
		"player_id": key,
		"kind": offer_kind,
		"amount": int(clean_fee),
	})
	return {"ok": true, "error": "", "offer": view(career, created)}


static func accept_counter(career: Career, catalog: TeamCatalog, offer_id) -> Dictionary:
	# Accepting the club's terms only settles the fee; the personal contract is
	# opened next from the contract screen (CareerTransferContracts.open).
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return _fail("offer not found")
	if str(offer.get("status", "")) != "counter" or offer.get("counter") is not Dictionary:
		return _fail("there is no counter-offer to accept")
	if not _counter_affordable(career, offer):
		return _fail("not enough money to accept these terms")
	var counter: Dictionary = offer["counter"]
	offer["amount"] = int(counter.get("amount", 0))
	if str(offer.get("kind", "")) == "loan":
		offer["loan_fee"] = int(counter.get("loan_fee", counter.get("amount", 0)))
		offer["wage_share"] = int(counter.get("wage_share", 0))
	offer["status"] = "accepted"
	offer["counter"] = null
	offer["message"] = ACCEPTED_MESSAGE
	offer["responded_at"] = career.date
	_journal(career, "transfer.offer.accepted", {
		"offer_id": str(offer.get("id", "")),
		"player_id": str(offer.get("player_id", "")),
	})
	return {"ok": true, "error": "", "offer": view(career, offer)}


static func withdraw(career: Career, catalog: TeamCatalog, offer_id) -> Dictionary:
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return _fail("offer not found")
	var status := str(offer.get("status", ""))
	var active := status in ["pending", "counter"] \
		or (status == "accepted" and not bool(offer.get("signed", false)))
	if not active:
		return _fail("this offer cannot be withdrawn")
	offer["status"] = "withdrawn"
	offer["counter"] = null
	offer["due"] = null
	offer["responded_at"] = career.date
	offer["message"] = WITHDRAWN_MESSAGE
	var talks: Dictionary = career.transfer_contracts
	talks.erase(str(offer.get("player_id", "")))
	career.transfer_contracts = talks
	var remaining: Array = []
	for item in career.transfer_offers:
		if not (item is Dictionary) or str(item.get("id", "")) != str(offer.get("id", "")):
			remaining.append(item)
	career.transfer_offers = remaining
	_journal(career, "transfer.offer.withdrawn", {
		"offer_id": str(offer.get("id", "")),
		"player_id": str(offer.get("player_id", "")),
	})
	var result := view(career, offer)
	return {"ok": true, "error": "", "offer": result}


static func process_due(career: Career, catalog: TeamCatalog, today := "") -> Array:
	# The prototype resolves pending offers whenever a career is refreshed; the
	# hub calls this after advancing the calendar and shows the events.
	var reference := today if not str(today).is_empty() else career.date
	var events: Array = []
	for offer in career.transfer_offers:
		if not (offer is Dictionary) or str(offer.get("status", "")) != "pending":
			continue
		var due = offer.get("due")
		if due == null or reference < str(due):
			continue
		_resolve_one(career, offer)
		var player_id := str(offer.get("player_id", ""))
		var player: Dictionary = {} if catalog == null \
			else catalog.career_player(int(player_id), false)
		events.append({
			"type": "transfer.offer.%s" % str(offer.get("status", "")),
			"offer_id": str(offer.get("id", "")),
			"player_id": player_id,
			"player_name": str(player.get("name", "")),
			"kind": str(offer.get("kind", "transfer")),
			"status": str(offer.get("status", "")),
			"message": str(offer.get("message", "")),
			"counter": _counter_view(offer),
		})
	return events


static func view(career: Career, offer: Dictionary) -> Dictionary:
	var status := str(offer.get("status", ""))
	var counter_view := _counter_view(offer)
	var affordable := _counter_affordable(career, offer) if not counter_view.is_empty() else true
	var retry_after = offer.get("retry_after")
	var can_offer_again := false
	if status == "counter":
		can_offer_again = true
	elif status == "refused":
		can_offer_again = retry_after == null or career.date >= str(retry_after)
	elif status == "withdrawn":
		can_offer_again = true
	return {
		"offer_id": str(offer.get("id", "")),
		"player_id": str(offer.get("player_id", "")),
		"kind": str(offer.get("kind", "transfer")),
		"amount": int(offer.get("amount", 0)),
		"loan_fee": int(offer.get("loan_fee", 0)),
		"wage_share": int(offer.get("wage_share", 0)),
		"buyout": bool(offer.get("buyout", false)),
		"status": status,
		"due": offer.get("due"),
		"created_at": offer.get("created_at"),
		"responded_at": offer.get("responded_at"),
		"counter_offers": int(offer.get("counter_offers", 0)),
		"counter": null if counter_view.is_empty() else counter_view,
		"retry_after": retry_after,
		"message": str(offer.get("message", "")),
		"can_offer_again": can_offer_again,
		"can_accept_counter": status == "counter" and not counter_view.is_empty() and affordable,
		"can_withdraw": status in ["pending", "counter"] \
			or (status == "accepted" and not bool(offer.get("signed", false))),
		"affordable": affordable,
		"signed": bool(offer.get("signed", false)),
		"signed_at": offer.get("signed_at"),
		"execute_on": offer.get("execute_on"),
		"contract_status": offer.get("contract_status"),
		"can_negotiate": status == "accepted" and not bool(offer.get("signed", false)),
	}


static func find_offer(career: Career, offer_id) -> Dictionary:
	var key := str(offer_id)
	for offer in career.transfer_offers:
		if offer is Dictionary and str(offer.get("id", "")) == key:
			return offer
	return {}


static func active_for(career: Career, player_id) -> Dictionary:
	var active := _active_offer(career, str(player_id))
	return {} if active.is_empty() else view(career, active)


# Why no new offer of `kind` can be sent right now ("" kind = any):
# {"status": "pending"} while the club is thinking (or countering another kind),
# {"status": "refused", "retry_after": date} inside the refused cooldown, {} when
# the offer can be made. Mirrors submit()'s pre-checks, so the card cannot show
# a row that would fail.
static func block(career: Career, player_id, kind := "") -> Dictionary:
	var key := str(player_id)
	var active := _active_offer(career, key)
	if not active.is_empty():
		var same_kind := not str(kind).is_empty() \
			and str(active.get("kind", "")) == str(kind)
		if not same_kind or str(active.get("status", "")) == "pending":
			return {"status": "pending", "retry_after": ""}
	var retry := _retry_offer(career, key)
	if retry.is_empty():
		return {}
	var until := str(retry.get("retry_after", ""))
	if until <= career.date:
		return {}
	return {"status": "refused", "retry_after": until}


static func latest(career: Career, player_id) -> Dictionary:
	# The prototype's latest_offer payload: the newest offer of any status.
	var key := str(player_id)
	var offers: Array = career.transfer_offers
	for index in range(offers.size() - 1, -1, -1):
		var offer = offers[index]
		if not (offer is Dictionary) or str(offer.get("player_id", "")) != key:
			continue
		var status := str(offer.get("status", ""))
		var signed := bool(offer.get("signed", false))
		return {
			"offer_id": str(offer.get("id", "")),
			"kind": str(offer.get("kind", "transfer")),
			"status": status,
			"signed": signed,
			"execute_on": offer.get("execute_on"),
			"can_negotiate": status == "accepted" and not signed,
		}
	return {}


static func detail(career: Career, catalog: TeamCatalog, offer_id) -> Dictionary:
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return {"ok": false, "error": "offer not found", "offer": {}, "player": {}}
	var player: Dictionary = {}
	if catalog != null:
		player = CareerSearch.profile(catalog, career, offer.get("player_id"))
	return {"ok": true, "error": "", "offer": view(career, offer), "player": player}


static func python_round(value: float) -> int:
	return CareerSearch.python_round(value)


static func _player(catalog: TeamCatalog, career: Career, player_id) -> Dictionary:
	var key := str(player_id)
	if catalog == null or not key.is_valid_int():
		return {}
	var player := catalog.career_player(int(key), false)
	if player.is_empty():
		return {}
	var team_id := int(player.get("team_id", 0))
	player["club_id"] = str(team_id) if team_id > 0 else ""
	player["release_clause"] = CareerSearch.release_clause(career, player, key)
	return player


static func _balance(career: Career) -> int:
	return 0 if career.balance == null else int(career.balance)


static func _player_value(player: Dictionary) -> int:
	return maxi(int(player.get("market_value", 0)), MIN_MARKET_VALUE)


static func _offer_rng(career: Career, offer_id: String, salt: String) -> CareerRng:
	return CareerRng.seeded("%d:offer:%s:%s" % [career.seed, offer_id, salt])


static func _offer_id(career: Career, player_id: String, kind: String) -> String:
	var raw := "%d:%s:%s:%s:%d:%d" % [
		career.seed, career.date, player_id, kind,
		career.transfer_offers.size(), career.journal.size(),
	]
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA1)
	hashing.update(raw.to_utf8_buffer())
	var digest := hashing.finish()
	var hex := ""
	for byte in digest:
		hex += "%02x" % int(byte)
	return hex.substr(0, 16)


static func _demand(career: Career, offer_id: String, player: Dictionary,
		kind: String) -> Dictionary:
	var value := _player_value(player)
	if kind == "transfer":
		var rng := _offer_rng(career, offer_id, "transfer-demand")
		return {"value": value, "fee": int(float(value) * rng.uniform(0.85, 1.05))}
	var loan_rng := _offer_rng(career, offer_id, "loan-demand")
	return {
		"value": value,
		"fee": maxi(1000, int(float(value) * loan_rng.uniform(0.04, 0.08))),
		"wage_share": int(loan_rng.choice([50, 60, 70, 80])),
	}


static func _response_due(career: Career, offer: Dictionary) -> String:
	var rounds := int(offer.get("counter_offers", 0))
	var rng := _offer_rng(career, str(offer.get("id", "")), "delay:%d" % rounds)
	var delay := int(rng.choice(RESPONSE_DAYS))
	return CareerSearch.add_days(career.date, delay)


static func _active_offer(career: Career, player_id: String) -> Dictionary:
	for offer in career.transfer_offers:
		if not (offer is Dictionary) or str(offer.get("player_id", "")) != player_id:
			continue
		if ACTIVE_STATUSES.has(str(offer.get("status", ""))):
			return offer
	return {}


static func _retry_offer(career: Career, player_id: String) -> Dictionary:
	var latest_refused: Dictionary = {}
	for offer in career.transfer_offers:
		if not (offer is Dictionary) or str(offer.get("player_id", "")) != player_id:
			continue
		if str(offer.get("status", "")) != "refused":
			continue
		var retry_after = offer.get("retry_after")
		if retry_after == null or str(retry_after).is_empty():
			continue
		if latest_refused.is_empty() \
				or str(retry_after) > str(latest_refused.get("retry_after", "")):
			latest_refused = offer
	return latest_refused


static func _clean_transfer(career: Career, player: Dictionary, amount,
		buyout: bool) -> Dictionary:
	var player_id := str(player.get("id", ""))
	if career.player_ids.has(player_id):
		return {"ok": false, "error": "you cannot make an offer for your own player"}
	var value := 0 if amount == null else int(amount)
	if value < 0:
		return {"ok": false, "error": "offer amount cannot be negative"}
	var release_clause := int(player.get("release_clause", 0))
	if buyout:
		if str(player.get("club_id", "")).is_empty() or release_clause <= 0:
			return {"ok": false, "error": "release clause is not available for this player"}
		value = release_clause
	if career.balance != null and value > int(career.balance):
		return {"ok": false, "error": "offer amount is above the club balance"}
	return {"ok": true, "error": "", "amount": value, "buyout": buyout}


static func _clean_loan(career: Career, player: Dictionary, amount, loan_fee,
		wage_share) -> Dictionary:
	var player_id := str(player.get("id", ""))
	if career.player_ids.has(player_id):
		return {"ok": false, "error": "you cannot make an offer for your own player"}
	var fee := 0
	if loan_fee != null:
		fee = int(loan_fee)
	elif amount != null and int(amount) > 0:
		fee = int(amount)
	if fee < 0:
		return {"ok": false, "error": "loan fee cannot be negative"}
	if career.balance != null and fee > int(career.balance):
		return {"ok": false, "error": "loan fee is above the club balance"}
	var share := 0 if wage_share == null else int(wage_share)
	if share < 0 or share > 100:
		return {"ok": false, "error": "wage share must be between 0 and 100"}
	return {"ok": true, "error": "", "fee": fee, "share": share}


static func _counter_affordable(career: Career, offer: Dictionary) -> bool:
	if not (offer.get("counter") is Dictionary):
		return true
	if career.balance == null:
		return true
	var counter: Dictionary = offer["counter"]
	return int(counter.get("amount", 0)) <= int(career.balance)


static func _counter_view(offer: Dictionary) -> Dictionary:
	if not (offer.get("counter") is Dictionary):
		return {}
	var view := {}
	var counter: Dictionary = offer["counter"]
	for key in counter:
		view[str(key)] = int(counter[key])
	return view


static func _resolve_one(career: Career, offer: Dictionary) -> void:
	var when := career.date
	if bool(offer.get("buyout", false)):
		_accept(offer, when)
		return
	var demand: Dictionary = offer.get("demand") \
		if offer.get("demand") is Dictionary else {}
	var rounds := int(offer.get("counter_offers", 0))
	if str(offer.get("kind", "")) == "loan":
		var fee := int(offer.get("loan_fee", 0))
		var share := int(offer.get("wage_share", 0))
		var fee_demand := int(demand.get("fee", 0))
		var share_demand := int(demand.get("wage_share", 0))
		if fee >= fee_demand and share >= share_demand:
			_accept(offer, when)
		elif rounds >= MAX_COUNTER_OFFERS:
			_refuse(offer, when)
		elif fee * 100 >= fee_demand * 50 or share + 20 >= share_demand:
			var counter_fee := maxi(fee, fee_demand)
			_counter(career, offer, {
				"amount": counter_fee,
				"loan_fee": counter_fee,
				"wage_share": maxi(share, share_demand),
			}, when)
		else:
			_refuse(offer, when)
		return
	var amount := int(offer.get("amount", 0))
	var demand_fee := int(demand.get("fee", 0))
	if amount >= demand_fee:
		_accept(offer, when)
	elif rounds >= MAX_COUNTER_OFFERS:
		_refuse(offer, when)
	elif amount * 100 >= demand_fee * 65:
		_counter(career, offer, {"amount": demand_fee}, when)
	else:
		_refuse(offer, when)


static func _accept(offer: Dictionary, when: String) -> void:
	offer["status"] = "accepted"
	offer["counter"] = null
	offer["message"] = ACCEPTED_MESSAGE
	offer["responded_at"] = when


static func _refuse(offer: Dictionary, when: String) -> void:
	offer["status"] = "refused"
	offer["counter"] = null
	offer["message"] = REFUSED_MESSAGE
	offer["responded_at"] = when
	offer["retry_after"] = CareerSearch.add_days(when, RETRY_DAYS)


static func _counter(career: Career, offer: Dictionary, terms: Dictionary,
		when: String) -> void:
	offer["counter_offers"] = int(offer.get("counter_offers", 0)) + 1
	offer["status"] = "counter"
	var view := {}
	for key in terms:
		view[str(key)] = int(terms[key])
	offer["counter"] = view
	offer["message"] = COUNTER_MESSAGE
	offer["responded_at"] = when


static func _journal(career: Career, kind: String, payload: Dictionary) -> void:
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": kind,
		"payload": payload,
	})


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "offer": {}}
