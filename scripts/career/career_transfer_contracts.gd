class_name CareerTransferContracts
extends RefCounted
# Personal-contract talks with a transfer target, ported from
# server/career/transfer_contracts.py: the player's demand, the two-counter
# negotiation, the signing (fee debit, squad join inside an open window or a
# pending transfer outside it) and the transfer windows themselves.

const THINK_DAYS := [2, 3, 4]
const FREE_AGENT_MONTHS := 6
const MAX_COUNTER_OFFERS := 2
const MAX_WEEKLY_WAGE := 2000000

const PENDING_MESSAGE := "The player is thinking about the contract."
const ACCEPTED_MESSAGE := "The player agrees. Confirm the signing."
const REFUSED_MESSAGE := "The player walked away from the talks."
const COUNTER_MESSAGES := {
	"wage": "The player asks for a higher wage.",
	"years": "The player insists on a longer contract.",
	"role": "The player is not ready to lose his squad role.",
	"clause_low": "The player wants a higher release clause.",
	"clause_high": "The release clause is too high; the player asks to lower it.",
}


static func window_open(day) -> bool:
	var parts := CareerSearch.date_parts(str(day))
	if parts.is_empty():
		return false
	return parts[1] == 1 or parts[1] == 7 or parts[1] == 8


static func next_window(day) -> String:
	var parts := CareerSearch.date_parts(str(day))
	if parts.is_empty():
		return ""
	if parts[1] <= 6:
		return "%04d-07-01" % parts[0]
	return "%04d-01-01" % (parts[0] + 1)


static func execution_date(day) -> String:
	var value := str(day).substr(0, 10)
	if window_open(value):
		return value
	return next_window(value)


static func can_discuss(catalog: TeamCatalog, career: Career, player: Dictionary) -> bool:
	var player_id := str(player.get("id", player.get("player_id", "")))
	if career.player_ids.has(player_id):
		return false
	if has_pending(career, player_id):
		return false
	var club_id := str(player.get("club_id", ""))
	if club_id.is_empty() and int(player.get("team_id", 0)) <= 0:
		return true
	var expiry := CareerSearch.expiry_for(career, player, player_id)
	if expiry.is_empty():
		return true
	return CareerSearch.date_diff_days(career.date, expiry) <= FREE_AGENT_MONTHS * 31


static func has_pending(career: Career, player_id) -> bool:
	var key := str(player_id)
	for item in career.pending_transfers:
		if item is Dictionary and str(item.get("player_id", "")) == key:
			return true
	return false


static func demand(catalog: TeamCatalog, career: Career, player: Dictionary) -> Dictionary:
	var key := str(player.get("id", ""))
	var value := CareerSearch.market_value(career, player, key)
	var age := CareerSearch.player_age(player)
	var role_id := projected_role(player, _squad_players(catalog, career))
	var share := float(CareerSquad.SQUAD_ROLE_SHARE.get(role_id,
		CareerSquad.SQUAD_ROLE_SHARE[CareerSquad.DEFAULT_ROLE]))
	var premium := 1.0 + (share - 0.45) * 0.6
	var rng := CareerRng.seeded("%d:transfer-contract:%s:demand" % [career.seed, key])
	var base := float(CareerSearch.weekly_wage(career, player, key)) * premium \
		* rng.uniform(0.97, 1.09)
	var wage := CareerSearch.python_round(base / 100.0) * 100
	var years := 1
	if age <= 24:
		years = 4
	elif age <= 28:
		years = 3
	elif age <= 31:
		years = 2
	return {
		"years": years,
		"weekly_wage": mini(MAX_WEEKLY_WAGE, maxi(CareerSquad.MIN_WEEKLY_WAGE, wage)),
		"squad_role": role_id,
		"release_clause": clause_bounds(value)[0],
	}


static func contract_defaults(catalog: TeamCatalog, career: Career,
		player: Dictionary) -> Dictionary:
	var key := str(player.get("id", ""))
	var value := CareerSearch.market_value(career, player, key)
	var months := CareerSearch.contract_months(career, _with_club(player), key)
	var years := 3
	if months > 0:
		years = maxi(1, mini(5, CareerSearch.python_round(float(months) / 12.0)))
	return {
		"years": years,
		"weekly_wage": CareerSearch.weekly_wage(career, player, key),
		"squad_role": projected_role(player, _squad_players(catalog, career)),
		"release_clause": clause_bounds(value)[0],
	}


static func projected_role(player: Dictionary, squad_players: Array) -> String:
	if squad_players.is_empty():
		return CareerSquad.DEFAULT_ROLE
	var overall := float(player.get("overall", 0.0))
	var name := str(player.get("name", ""))
	var player_id := str(player.get("id", ""))
	var better := 0
	for other in squad_players:
		if not (other is Dictionary) or str(other.get("id", "")) == player_id:
			continue
		var other_overall := float(other.get("overall", 0.0))
		if other_overall > overall or (is_equal_approx(other_overall, overall) \
				and str(other.get("name", "")) < name):
			better += 1
	var position := float(better) / float(squad_players.size() + 1)
	for pair in CareerSquad.ROLE_THRESHOLDS:
		if position < float(pair[0]):
			return str(pair[1])
	return "prospect"


static func clause_bounds(value: int) -> Array:
	return [int(float(value) * 1.2), int(float(value) * 2.0)]


static func state(career: Career, catalog: TeamCatalog, key) -> Dictionary:
	# The contract screen payload. Accepts the player id (the prototype's key)
	# or an offer id (what the offer screen has in hand).
	var resolved := _resolve_key(career, key)
	if resolved.is_empty():
		return {"error": "player not found"}
	var player_id: String = resolved[0]
	var offer: Dictionary = resolved[1]
	var player: Dictionary = {} if catalog == null \
		else catalog.career_player(int(player_id), false)
	if player.is_empty():
		return {"error": "player not found"}
	var team_id := int(player.get("team_id", 0))
	player["club_id"] = str(team_id) if team_id > 0 else ""
	var view := transfer_contract_view(career, player_id)
	var status := str(view.get("status", ""))
	var discuss := can_discuss(catalog, career, _with_club(player))
	return {
		"error": "",
		"player_id": player_id,
		"player_name": str(player.get("name", "")),
		"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
		"offer_id": view.get("offer_id"),
		"kind": view.get("kind", "transfer"),
		"fee": view.get("fee", 0),
		"loan_fee": view.get("loan_fee", 0),
		"wage_share": view.get("wage_share", 100),
		"status": status,
		"offer": view.get("offer"),
		"counter": view.get("counter"),
		"agreed": view.get("agreed"),
		"terms": view.get("terms"),
		"due": view.get("due"),
		"counter_offers": view.get("counter_offers", 0),
		"message": view.get("message", ""),
		"demand": view.get("demand", {}),
		"affordable": view.get("affordable", true),
		"balance_after": view.get("balance_after"),
		"can_sign": view.get("can_sign", false),
		"can_accept_counter": status == "counter" and view.get("counter") != null,
		"can_submit": discuss and status not in ["pending", "accepted"],
		"can_discuss": discuss,
		"contract_defaults": contract_defaults(catalog, career, player),
		"latest_offer": CareerTransferOffers.latest(career, player_id),
		"offer_accepted": not offer.is_empty() \
			and str(offer.get("status", "")) == "accepted",
	}


static func state_for(career: Career, player_id) -> Dictionary:
	var raw = career.transfer_contracts.get(str(player_id))
	return raw if raw is Dictionary else {}


static func open(career: Career, catalog: TeamCatalog, player_id, terms: Dictionary,
		offer_id := "") -> Dictionary:
	var key := str(player_id)
	var player: Dictionary = {} if catalog == null \
		else catalog.career_player(int(key) if key.is_valid_int() else 0, false)
	if player.is_empty():
		return {"ok": false, "error": "player not found", "state": {}}
	var team_id := int(player.get("team_id", 0))
	player["club_id"] = str(team_id) if team_id > 0 else ""
	var offer: Dictionary = {}
	if not str(offer_id).is_empty():
		offer = CareerTransferOffers.find_offer(career, offer_id)
		if offer.is_empty():
			return {"ok": false, "error": "offer not found", "state": {}}
	var started := start(career, catalog, player, terms, offer)
	if not started.get("ok", false):
		return started
	return {"ok": true, "error": "", "state": state(career, catalog, key)}


static func submit(career: Career, catalog: TeamCatalog, player_id, terms: Dictionary,
		offer_id := "") -> Dictionary:
	# The prototype has a single entry point (start_transfer_contract); the
	# contract screen calls it "submit" when it sends new terms.
	return open(career, catalog, player_id, terms, offer_id)


static func start(career: Career, catalog: TeamCatalog, player: Dictionary,
		terms: Dictionary, offer: Dictionary = {}) -> Dictionary:
	var player_id := str(player.get("id", ""))
	if career.player_ids.has(player_id):
		return _fail("the player is already in your squad")
	if has_pending(career, player_id):
		return _fail("this transfer is already agreed and waiting for the window")
	if offer.is_empty() and not can_discuss(catalog, career, player):
		return _fail("contract talks are only available for free agents or expiring contracts")
	var context := _offer_terms(offer)
	if not context.get("ok", false):
		return _fail(str(context.get("error", "")))
	var clean := _clean_terms(terms)
	if not clean.get("ok", false):
		return _fail(str(clean.get("error", "")))
	var state_value := state_for(career, player_id)
	if not state_value.is_empty() and str(state_value.get("status", "")) == "accepted":
		return _fail("the contract is already agreed, confirm it first")
	if not state_value.is_empty() and str(state_value.get("status", "")) == "pending":
		return _fail("the player is still thinking about the current offer")
	if state_value.is_empty() or str(state_value.get("status", "")) == "refused":
		state_value = {
			"player_id": player_id,
			"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
			"value": CareerSearch.market_value(career, player, player_id),
			"demand": demand(catalog, career, player),
			"counter_offers": 0,
			"rounds": 0,
			"status": "pending",
			"offer": null,
			"counter": null,
			"agreed": null,
			"due": null,
			"message": "",
		}
		var talks: Dictionary = career.transfer_contracts
		talks[player_id] = state_value
		career.transfer_contracts = talks
	state_value["overall"] = roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0
	state_value["offer_id"] = context.get("offer_id", null)
	state_value["kind"] = str(context.get("kind", "transfer"))
	state_value["fee"] = int(context.get("fee", 0))
	state_value["loan_fee"] = int(context.get("loan_fee", 0))
	state_value["wage_share"] = int(context.get("wage_share", 100))
	state_value["rounds"] = int(state_value.get("rounds", 0)) + 1
	var delay := _think_delay(career, player_id, int(state_value["rounds"]))
	state_value["due"] = CareerSearch.add_days(career.date, delay)
	state_value["offer"] = clean["terms"]
	state_value["counter"] = null
	state_value["agreed"] = null
	state_value["status"] = "pending"
	state_value["message"] = PENDING_MESSAGE
	if not offer.is_empty():
		offer["contract_status"] = "pending"
	return {"ok": true, "error": "", "state": state_value}


static func accept_counter(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	var state_value := state_for(career, key)
	if state_value.is_empty() or str(state_value.get("status", "")) != "counter" \
			or not (state_value.get("counter") is Dictionary):
		return _fail("there is no counter-offer to accept")
	var clean := _clean_terms(state_value["counter"])
	if not clean.get("ok", false):
		return _fail(str(clean.get("error", "")))
	state_value["status"] = "accepted"
	state_value["agreed"] = clean["terms"]
	state_value["counter"] = null
	state_value["message"] = ACCEPTED_MESSAGE
	if state_value.get("offer_id") != null:
		var offer := CareerTransferOffers.find_offer(career, state_value.get("offer_id"))
		if not offer.is_empty():
			offer["contract_status"] = "accepted"
	return {"ok": true, "error": "", "state": state(career, catalog, key)}


static func sign(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	var state_value := state_for(career, key)
	if state_value.is_empty() or str(state_value.get("status", "")) != "accepted":
		return {"ok": false, "error": "the contract is not agreed yet", "item": {}}
	var player: Dictionary = {} if catalog == null \
		else catalog.career_player(int(key) if key.is_valid_int() else 0, false)
	if player.is_empty():
		return {"ok": false, "error": "player not found", "item": {}}
	var team_id := int(player.get("team_id", 0))
	player["club_id"] = str(team_id) if team_id > 0 else ""
	var terms_source = state_value.get("agreed")
	if not (terms_source is Dictionary):
		terms_source = state_value.get("offer")
	var clean := _clean_terms(terms_source if terms_source is Dictionary else {})
	if not clean.get("ok", false):
		return {"ok": false, "error": str(clean.get("error", "")), "item": {}}
	var terms: Dictionary = clean["terms"]
	var fee := int(state_value.get("fee", 0))
	if not _affordable(career, fee):
		return {"ok": false, "error": "not enough money to complete this transfer", "item": {}}
	var execute_on := execution_date(career.date)
	var item := {
		"player_id": key,
		"from_club_id": CareerSearch.current_club_id(career, key,
			str(player.get("club_id", ""))),
		"offer_id": state_value.get("offer_id"),
		"kind": str(state_value.get("kind", "transfer")),
		"fee": fee,
		"loan_fee": int(state_value.get("loan_fee", 0)),
		"wage_share": int(state_value.get("wage_share", 100)),
		"terms": terms.duplicate(true),
		"market_value": CareerSearch.market_value(career, player, key),
		"age": CareerSearch.player_age(player),
		"agreed_at": career.date,
		"execute_on": execute_on,
	}
	if career.balance != null:
		career.balance = int(career.balance) - fee
	if execute_on == str(career.date).substr(0, 10):
		_join_squad(career, catalog, key, terms, item)
		item["executed_at"] = career.date
		_remove_offer(career, state_value.get("offer_id"))
	else:
		career.pending_transfers.append(item)
		if state_value.get("offer_id") != null:
			var offer := CareerTransferOffers.find_offer(career, state_value.get("offer_id"))
			if not offer.is_empty():
				offer["signed"] = true
				offer["signed_at"] = career.date
				offer["execute_on"] = execute_on
				offer["contract_status"] = "signed"
	career.transfer_history.append({
		"player_id": key,
		"overall": roundf(float(state_value.get("overall",
			player.get("overall", 0.0))) * 10.0) / 10.0,
		"from_club_id": null if str(player.get("club_id", "")).is_empty() \
			else str(player.get("club_id", "")),
		"to_club_id": str(career.club_id),
		"fee": fee,
		"kind": str(state_value.get("kind", "transfer")),
		"offer_id": state_value.get("offer_id"),
		"date": str(career.date).substr(0, 10),
		"status": "completed" if execute_on == str(career.date).substr(0, 10) else "signed",
	})
	career.transfer_contracts = _without_key(career.transfer_contracts, key)
	_journal(career, "transfer.signed", {
		"player_id": key,
		"offer_id": state_value.get("offer_id"),
		"fee": fee,
		"contract": terms.duplicate(true),
		"execute_on": execute_on,
	})
	return {"ok": true, "error": "", "item": item}


static func process_due(career: Career, catalog: TeamCatalog, today := "") -> Array:
	var reference := today if not str(today).is_empty() else career.date
	var events: Array = []
	for player_id in career.transfer_contracts.keys():
		var state_value = career.transfer_contracts[player_id]
		if not (state_value is Dictionary):
			continue
		if str(state_value.get("status", "")) != "pending":
			continue
		var due = state_value.get("due")
		if due == null or reference < str(due):
			continue
		_resolve_one(career, str(player_id), state_value)
		if state_value.get("offer_id") != null:
			var offer := CareerTransferOffers.find_offer(career, state_value.get("offer_id"))
			if not offer.is_empty():
				offer["contract_status"] = state_value.get("status")
		var player: Dictionary = {} if catalog == null \
			else catalog.career_player(int(player_id), false)
		events.append({
			"type": "transfer.contract.%s" % str(state_value.get("status", "")),
			"player_id": str(player_id),
			"player_name": str(player.get("name", "")),
			"status": str(state_value.get("status", "")),
			"message": str(state_value.get("message", "")),
			"counter": state_value.get("counter"),
		})
	return events


static func pending(career: Career, catalog: TeamCatalog = null) -> Array:
	var items: Array = []
	for item in career.pending_transfers:
		if not (item is Dictionary):
			continue
		var copy: Dictionary = item.duplicate(true)
		if catalog != null:
			var player := catalog.career_player(int(str(copy.get("player_id", "0"))), false)
			copy["player_name"] = str(player.get("name", ""))
			copy["photo"] = int(str(copy.get("player_id", "0"))) \
				if str(copy.get("player_id", "")).is_valid_int() else 0
			var from_id := str(copy.get("from_club_id", ""))
			if not from_id.is_empty() and from_id.is_valid_int():
				copy["from_club_name"] = str(catalog.career_club(int(from_id)).get("name", ""))
			copy["to_club_name"] = str(catalog.career_club(int(career.club_id)).get("name", ""))
		items.append(copy)
	return items


static func execute_pending(career: Career, catalog: TeamCatalog, today := "") -> Array:
	var reference := today if not str(today).is_empty() else career.date
	if career.pending_transfers.is_empty():
		return []
	if not window_open(reference):
		return []
	var remaining: Array = []
	var executed: Array = []
	for item in career.pending_transfers:
		if not (item is Dictionary):
			continue
		if reference >= str(item.get("execute_on", "")):
			var player_id := str(item.get("player_id", ""))
			var terms = item.get("terms")
			_join_squad(career, catalog, player_id,
				terms if terms is Dictionary else {}, item)
			item["executed_at"] = reference
			executed.append({
				"type": "transfer.completed",
				"player_id": player_id,
				"player_name": _player_name(catalog, player_id),
				"date": reference,
			})
			_journal(career, "transfer.completed", {
				"player_id": player_id,
				"offer_id": item.get("offer_id"),
			})
			_remove_offer(career, item.get("offer_id"))
		else:
			remaining.append(item)
	career.pending_transfers = remaining
	return executed


static func transfer_contract_view(career: Career, player_id) -> Dictionary:
	var state_value := state_for(career, player_id)
	if state_value.is_empty():
		return {"demand": {}, "offer": null, "counter": null, "agreed": null,
			"terms": null, "status": "", "fee": 0, "loan_fee": 0,
			"wage_share": 100, "offer_id": null, "kind": "transfer", "due": null,
			"counter_offers": 0, "message": "", "affordable": true,
			"balance_after": null, "can_sign": false}
	var fee := int(state_value.get("fee", 0))
	var status := str(state_value.get("status", "pending"))
	var terms = state_value.get("agreed")
	if not (terms is Dictionary):
		terms = state_value.get("offer")
	var demand = state_value.get("demand")
	return {
		"player_id": str(state_value.get("player_id", player_id)),
		"offer_id": state_value.get("offer_id"),
		"kind": str(state_value.get("kind", "transfer")),
		"fee": fee,
		"loan_fee": int(state_value.get("loan_fee", 0)),
		"wage_share": int(state_value.get("wage_share", 100)),
		"status": status,
		"offer": state_value.get("offer"),
		"counter": state_value.get("counter"),
		"agreed": state_value.get("agreed"),
		"terms": (terms as Dictionary).duplicate(true) if terms is Dictionary else null,
		"demand": (demand as Dictionary).duplicate(true) if demand is Dictionary else {},
		"due": state_value.get("due"),
		"counter_offers": int(state_value.get("counter_offers", 0)),
		"message": str(state_value.get("message", "")),
		"affordable": _affordable(career, fee),
		"balance_after": null if career.balance == null else int(career.balance) - fee,
		"can_sign": status == "accepted" and _affordable(career, fee),
	}


static func _resolve_key(career: Career, key) -> Array:
	var value := str(key)
	if career.transfer_contracts.has(value):
		return [value, {}]
	var offer := CareerTransferOffers.find_offer(career, value)
	if not offer.is_empty():
		return [str(offer.get("player_id", "")), offer]
	if value.is_valid_int():
		return [value, {}]
	return []


static func _offer_terms(offer: Dictionary) -> Dictionary:
	if offer.is_empty():
		return {"ok": true, "kind": "free", "fee": 0, "loan_fee": 0,
			"wage_share": 100, "offer_id": null, "offer": {}}
	var status := str(offer.get("status", ""))
	if status != "accepted":
		return {"ok": false, "error": "the club has not accepted an offer for this player"}
	if bool(offer.get("signed", false)):
		return {"ok": false, "error": "this transfer has already been completed"}
	if str(offer.get("kind", "transfer")) == "loan":
		var fee := int(offer.get("loan_fee", 0))
		return {"ok": true, "kind": "loan", "fee": fee, "loan_fee": fee,
			"wage_share": int(offer.get("wage_share", 100)),
			"offer_id": str(offer.get("id", "")), "offer": offer}
	return {"ok": true, "kind": "transfer", "fee": int(offer.get("amount", 0)),
		"loan_fee": 0, "wage_share": 100, "offer_id": str(offer.get("id", "")),
		"offer": offer}


static func _clean_terms(terms: Dictionary) -> Dictionary:
	var years := int(terms.get("years", 0))
	if years < 1 or years > 5:
		return {"ok": false, "error": "contract length must be between 1 and 5 years"}
	var wage := int(terms.get("weekly_wage", 0))
	if wage < CareerSquad.MIN_WEEKLY_WAGE or wage > MAX_WEEKLY_WAGE:
		return {"ok": false, "error": "weekly wage is out of range"}
	var role_id := str(terms.get("squad_role", ""))
	if not CareerSquad.SQUAD_ROLE_IDS.has(role_id):
		return {"ok": false, "error": "unknown squad role"}
	var clause := int(terms.get("release_clause", 0))
	if clause < 0:
		return {"ok": false, "error": "release clause cannot be negative"}
	return {"ok": true, "error": "", "terms": {
		"years": years,
		"weekly_wage": wage,
		"squad_role": role_id,
		"release_clause": clause,
	}}


static func _term_shortfalls(offer: Dictionary, demand_terms: Dictionary,
		value: int) -> Array:
	var shortfalls: Array = []
	if int(offer.get("weekly_wage", 0)) < int(demand_terms.get("weekly_wage", 0)):
		shortfalls.append("wage")
	if int(offer.get("years", 0)) < int(demand_terms.get("years", 0)):
		shortfalls.append("years")
	if _share(offer.get("squad_role")) < _share(demand_terms.get("squad_role")):
		shortfalls.append("role")
	var bounds := clause_bounds(value)
	if int(offer.get("release_clause", 0)) < int(bounds[0]):
		shortfalls.append("clause_low")
	elif int(offer.get("release_clause", 0)) > int(bounds[1]):
		shortfalls.append("clause_high")
	return shortfalls


static func _counter_terms(offer: Dictionary, demand_terms: Dictionary, value: int,
		shortfalls: Array) -> Dictionary:
	var bounds := clause_bounds(value)
	var clause := int(offer.get("release_clause", 0))
	if shortfalls.has("clause_high"):
		clause = int(bounds[1])
	else:
		clause = maxi(clause, int(bounds[0]))
	return {
		"years": mini(5, maxi(int(offer.get("years", 0)), int(demand_terms.get("years", 0)))),
		"weekly_wage": maxi(int(offer.get("weekly_wage", 0)),
			int(demand_terms.get("weekly_wage", 0))),
		"squad_role": str(demand_terms.get("squad_role", "")) if shortfalls.has("role") \
			else str(offer.get("squad_role", "")),
		"release_clause": clause,
	}


static func _resolve_one(career: Career, player_id: String, state_value: Dictionary) -> void:
	var player_value := maxi(int(state_value.get("value", 0)), CareerSearch.MIN_MARKET_VALUE)
	var offer_terms = state_value.get("offer")
	var clean := _clean_terms(offer_terms if offer_terms is Dictionary else {})
	if not clean.get("ok", false):
		return
	var offer: Dictionary = clean["terms"]
	var demand_terms = state_value.get("demand")
	if not (demand_terms is Dictionary):
		return
	var shortfalls := _term_shortfalls(offer, demand_terms, player_value)
	if shortfalls.is_empty():
		state_value["status"] = "accepted"
		state_value["counter"] = null
		state_value["agreed"] = offer.duplicate(true)
		state_value["message"] = ACCEPTED_MESSAGE
	elif int(state_value.get("counter_offers", 0)) >= MAX_COUNTER_OFFERS:
		state_value["status"] = "refused"
		state_value["counter"] = null
		state_value["agreed"] = null
		state_value["message"] = REFUSED_MESSAGE
	else:
		state_value["counter_offers"] = int(state_value.get("counter_offers", 0)) + 1
		state_value["status"] = "counter"
		state_value["counter"] = _counter_terms(offer, demand_terms, player_value,
			shortfalls)
		state_value["agreed"] = null
		var messages: Array = []
		for key in shortfalls:
			if COUNTER_MESSAGES.has(key):
				messages.append(str(COUNTER_MESSAGES[key]))
		state_value["message"] = " ".join(PackedStringArray(messages))


static func _join_squad(career: Career, catalog: TeamCatalog, player_id: String,
		terms: Dictionary, item: Dictionary) -> void:
	var from_club_id := str(item.get("from_club_id", ""))
	if not from_club_id.is_empty() and from_club_id != str(career.club_id):
		_detach(career, from_club_id, player_id)
	_attach(career, career.club_id, player_id)
	forget_scouting(career, player_id)
	if not career.player_ids.has(player_id):
		career.player_ids.append(player_id)
	var contract: Dictionary = terms.duplicate(true)
	if str(item.get("kind", "transfer")) == "loan" \
			and int(item.get("wage_share", 100)) < 100:
		var share := clampi(int(item.get("wage_share", 100)), 0, 100)
		var wage := int(terms.get("weekly_wage", 0))
		contract["weekly_wage"] = maxi(CareerSquad.MIN_WEEKLY_WAGE,
			CareerSearch.python_round(float(wage) * float(share) / 100.0 / 100.0) * 100)
	career.player_contracts[player_id] = contract
	var values: Dictionary = career.player_values
	if not values.has(player_id):
		values[player_id] = maxi(int(item.get("market_value", 0)), CareerSearch.MIN_MARKET_VALUE)
	career.player_values = values
	var ages: Dictionary = career.player_ages
	if not ages.has(player_id):
		ages[player_id] = int(item.get("age", 25))
	career.player_ages = ages
	career.player_transfers = _without_key(career.player_transfers, player_id)
	if career.data.get("negotiations") is Dictionary:
		(career.data["negotiations"] as Dictionary).erase(player_id)
	if catalog != null:
		var squad := catalog.career_squad(int(career.club_id))
		var player := catalog.career_player(int(player_id), false)
		if not player.is_empty():
			squad.append(player)
		CareerSquad.ensure_shirt_numbers(career, squad)


static func forget_scouting(career: Career, player_id: String) -> void:
	# The prototype's forget_player removes the report, the found entry and every
	# assignment/task reference; CareerScouting owns that whole shape.
	CareerScouting.forget_player(career, player_id)


static func _attach(career: Career, club_id: String, player_id: String) -> void:
	var delta := _delta(career, club_id)
	(delta["out"] as Array).erase(player_id)
	if not (delta["in"] as Array).has(player_id):
		(delta["in"] as Array).append(player_id)


static func _detach(career: Career, club_id: String, player_id: String) -> void:
	var delta := _delta(career, club_id)
	(delta["in"] as Array).erase(player_id)
	if not (delta["out"] as Array).has(player_id):
		(delta["out"] as Array).append(player_id)


static func _delta(career: Career, club_id: String) -> Dictionary:
	var deltas: Dictionary = career.club_deltas
	var delta = deltas.get(club_id)
	if not (delta is Dictionary):
		delta = {"in": [], "out": []}
		deltas[club_id] = delta
		career.club_deltas = deltas
	if not (delta.get("in") is Array):
		delta["in"] = []
	if not (delta.get("out") is Array):
		delta["out"] = []
	return delta


static func _affordable(career: Career, fee: int) -> bool:
	if career.balance == null:
		return true
	return fee <= int(career.balance)


static func _remove_offer(career: Career, offer_id) -> void:
	if offer_id == null or str(offer_id).is_empty():
		return
	var remaining: Array = []
	for offer in career.transfer_offers:
		if not (offer is Dictionary) or str(offer.get("id", "")) != str(offer_id):
			remaining.append(offer)
	career.transfer_offers = remaining


static func _share(role_id) -> float:
	return float(CareerSquad.SQUAD_ROLE_SHARE.get(str(role_id),
		CareerSquad.SQUAD_ROLE_SHARE[CareerSquad.DEFAULT_ROLE]))


static func _think_delay(career: Career, player_id: String, rounds: int) -> int:
	var rng := CareerRng.seeded("%d:transfer-thinking:%s:%d" % [career.seed, player_id, rounds])
	return int(rng.choice(THINK_DAYS))


static func _player_name(catalog: TeamCatalog, player_id) -> String:
	if catalog == null or not str(player_id).is_valid_int():
		return ""
	return str(catalog.career_player(int(player_id), false).get("name", ""))


static func _without_key(source: Dictionary, key: String) -> Dictionary:
	# Property getters hand out the stored dictionary; a mutation only sticks if
	# it is written back through the setter.
	var copy: Dictionary = source
	copy.erase(key)
	return copy


static func _squad_players(catalog: TeamCatalog, career: Career) -> Array:
	if catalog == null:
		return []
	return catalog.career_players_by_ids(career.player_ids, false)


static func _with_club(player: Dictionary) -> Dictionary:
	var copy := player.duplicate()
	var team_id := int(player.get("team_id", 0))
	copy["club_id"] = str(team_id) if team_id > 0 else str(player.get("club_id", ""))
	return copy


static func _journal(career: Career, kind: String, payload: Dictionary) -> void:
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": kind,
		"payload": payload,
	})


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "state": {}}
