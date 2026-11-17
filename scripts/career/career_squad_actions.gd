class_name CareerSquadActions
extends RefCounted
# Ticket 06 player actions for the manager's own squad, ported from
# server/career/squad.py (renewal talks) and server/career/actions.py (shirt
# number, release): the player's demand, the offer/counter/accept/sign cycle
# with two counters max, the wage-fund check, number occupancy and the
# eleven-player floor. Read models are UI-ready state dictionaries.

const MAX_COUNTER_OFFERS := 2
const THINK_DAYS := [2, 3, 4]
const MAX_WEEKLY_WAGE := 2000000
const MAX_SHIRT_NUMBER := 99
const MIN_MARKET_VALUE := 50000
const MIN_SQUAD_SIZE := 11

const PENDING_MESSAGE := "The player is thinking about the offer."
const ACCEPTED_MESSAGE := "The player agrees. Confirm the signing."
const REFUSED_MESSAGE := "The player walked away from the talks."
const COUNTER_MESSAGES := {
	"wage": "The player asks for a higher wage.",
	"years": "The player insists on a longer contract.",
	"role": "The player is not ready to lose his squad role.",
	"clause_low": "The player wants a higher release clause.",
	"clause_high": "The release clause is too high; the player asks to lower it.",
}


static func negotiation_state(career: Career, catalog: TeamCatalog,
		player_id) -> Dictionary:
	var key := str(player_id)
	var player := _find(_squad(catalog, career), key)
	if player.is_empty():
		return {"error": "player is not in this squad", "player_id": key}
	var contract: Dictionary = career.player_contracts.get(key) \
		if career.player_contracts.get(key) is Dictionary else {}
	var negotiation: Dictionary = career.negotiations.get(key) \
		if career.negotiations.get(key) is Dictionary else {}
	var status := str(negotiation.get("status", ""))
	var current = negotiation.get("counter")
	if not (current is Dictionary):
		current = negotiation.get("offer")
	var weekly := 0
	if current is Dictionary:
		weekly = int(current.get("weekly_wage", 0))
	else:
		weekly = int(contract.get("weekly_wage", 0))
	return {
		"error": "",
		"player_id": key,
		"player_name": str(player.get("name", "")),
		"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
		"squad_role": str(contract.get("squad_role", CareerSquad.DEFAULT_ROLE)),
		"contract": {
			"years": int(contract.get("years", 1)),
			"weekly_wage": int(contract.get("weekly_wage", 0)),
			"release_clause": int(contract.get("release_clause", 0)),
		},
		"status": status,
		"offer": negotiation.get("offer"),
		"counter": negotiation.get("counter"),
		"terms": (current as Dictionary).duplicate(true) if current is Dictionary else null,
		"due": negotiation.get("due"),
		"rounds": int(negotiation.get("rounds", 0)),
		"counter_offers": int(negotiation.get("counter_offers", 0)),
		"message": str(negotiation.get("message", "")),
		"acknowledged": bool(negotiation.get("acknowledged", true)),
		"unread": not negotiation.is_empty() and status != "pending" \
			and not bool(negotiation.get("acknowledged", true)),
		"demand": negotiation.get("demand") if negotiation.get("demand") is Dictionary \
			else demand(catalog, career, player),
		"affordable": CareerSquad.wage_fund_ok(career, key, weekly),
		"can_submit": status != "pending" and status != "accepted",
		"can_accept_counter": status == "counter" and negotiation.get("counter") is Dictionary,
		"can_sign": status == "accepted",
	}


static func unread_count(career: Career) -> int:
	var total := 0
	for player_id in career.negotiations:
		var state = career.negotiations[player_id]
		if not (state is Dictionary):
			continue
		if str(state.get("status", "")) != "pending" \
				and not bool(state.get("acknowledged", true)):
			total += 1
	return total


static func demand(catalog: TeamCatalog, career: Career, player: Dictionary) -> Dictionary:
	# server/career/squad.py negotiation_demand: the renewal the player wants.
	var player_id := str(player.get("id", ""))
	var stored := int(career.player_values.get(player_id, 0))
	var value := maxi(stored if stored > 0 else int(player.get("market_value", 0)),
		MIN_MARKET_VALUE)
	var age := CareerSearch.player_age(player)
	var contract: Dictionary = career.player_contracts.get(player_id) \
		if career.player_contracts.get(player_id) is Dictionary else {}
	var role_id := str(contract.get("squad_role", CareerSquad.DEFAULT_ROLE))
	if not CareerSquad.SQUAD_ROLE_SHARE.has(role_id):
		role_id = CareerSquad.DEFAULT_ROLE
	var share := float(CareerSquad.SQUAD_ROLE_SHARE[role_id])
	var premium := 1.0 + (share - 0.45) * 0.6
	var rng := CareerRng.seeded("%d:contract:%s:renewal" % [career.seed, player_id])
	var base := float(_wage_from_value(career, player_id, value, age)) * premium \
		* rng.uniform(0.97, 1.09)
	var wage := maxi(int(contract.get("weekly_wage", 0)),
		CareerRng.python_round(base / 100.0) * 100)
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
		"release_clause": int(float(value) * 1.2),
	}


static func start(career: Career, catalog: TeamCatalog, player_id,
		terms: Dictionary) -> Dictionary:
	var key := str(player_id)
	var player := _find(_squad(catalog, career), key)
	if player.is_empty():
		return _fail("player is not in this squad")
	var clean := _clean_terms(terms)
	if not clean.get("ok", false):
		return _fail(str(clean.get("error", "")))
	var state_value := _state_for(career, key)
	if not state_value.is_empty() and str(state_value.get("status", "")) == "accepted":
		return _fail("the contract is already agreed, confirm it first")
	if not state_value.is_empty() and str(state_value.get("status", "")) == "pending":
		return _fail("the player is still thinking about the current offer")
	if state_value.is_empty() or str(state_value.get("status", "")) == "refused":
		state_value = {
			"demand": demand(catalog, career, player),
			"counter_offers": 0,
			"rounds": 0,
			"status": "pending",
			"offer": null,
			"counter": null,
			"due": null,
			"acknowledged": true,
			"message": "",
		}
		var talks: Dictionary = career.negotiations
		talks[key] = state_value
		career.negotiations = talks
	state_value["rounds"] = int(state_value.get("rounds", 0)) + 1
	var delay := _think_delay(career, key, int(state_value["rounds"]))
	state_value["due"] = CareerSearch.add_days(career.date, delay)
	state_value["offer"] = clean["terms"]
	state_value["counter"] = null
	state_value["status"] = "pending"
	state_value["acknowledged"] = true
	state_value["message"] = PENDING_MESSAGE
	_journal(career, "contract.negotiation", {
		"player_id": key,
		"terms": (clean["terms"] as Dictionary).duplicate(),
	})
	return {"ok": true, "error": "", "state": negotiation_state(career, catalog, key)}


static func submit(career: Career, catalog: TeamCatalog, player_id,
		terms: Dictionary) -> Dictionary:
	# The screen sends new terms through the same entry point as the prototype.
	return start(career, catalog, player_id, terms)


static func accept_counter(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	var state_value := _state_for(career, key)
	if state_value.is_empty() or str(state_value.get("status", "")) != "counter" \
			or not (state_value.get("counter") is Dictionary):
		return _fail("there is no counter-offer to accept")
	var clean := _clean_terms(state_value["counter"])
	if not clean.get("ok", false):
		return _fail(str(clean.get("error", "")))
	var terms: Dictionary = clean["terms"]
	if not CareerSquad.wage_fund_ok(career, key, int(terms.get("weekly_wage", 0))):
		return _fail("not enough money to accept these terms")
	var contract := _apply_contract(career, key, terms)
	career.negotiations = _without_key(career.negotiations, key)
	_journal(career, "contract.signed", {
		"player_id": key,
		"contract": contract.duplicate(),
	})
	return {"ok": true, "error": "", "contract": contract,
		"state": negotiation_state(career, catalog, key)}


static func ack(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	var state_value := _state_for(career, key)
	if state_value.is_empty():
		return _fail("there is no negotiation for this player")
	if str(state_value.get("status", "")) == "pending":
		return _fail("the player is still thinking about the current offer")
	state_value["acknowledged"] = true
	_journal(career, "contract.negotiation.acknowledged", {"player_id": key})
	return {"ok": true, "error": "", "state": negotiation_state(career, catalog, key)}


static func sign(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	var state_value := _state_for(career, key)
	if state_value.is_empty() or str(state_value.get("status", "")) != "accepted":
		return _fail("the contract is not agreed yet")
	var clean := _clean_terms(state_value.get("offer"))
	if not clean.get("ok", false):
		return _fail(str(clean.get("error", "")))
	var terms: Dictionary = clean["terms"]
	if not CareerSquad.wage_fund_ok(career, key, int(terms.get("weekly_wage", 0))):
		return _fail("not enough money to sign this contract")
	var contract := _apply_contract(career, key, terms)
	career.negotiations = _without_key(career.negotiations, key)
	_journal(career, "contract.signed", {
		"player_id": key,
		"contract": contract.duplicate(),
	})
	return {"ok": true, "error": "", "contract": contract,
		"state": negotiation_state(career, catalog, key)}


static func process_due(career: Career, catalog: TeamCatalog, today := "") -> Array:
	var reference := today if not str(today).is_empty() else career.date
	var events: Array = []
	for player_id in career.negotiations.keys():
		var state_value = career.negotiations[player_id]
		if not (state_value is Dictionary):
			continue
		if str(state_value.get("status", "")) != "pending":
			continue
		var due = state_value.get("due")
		if due == null or str(due).is_empty() or reference < str(due):
			continue
		_resolve_one(career, str(player_id), state_value)
		var player: Dictionary = {} if catalog == null \
			else catalog.career_player(int(player_id), false)
		events.append({
			"type": "contract.negotiation.%s" % str(state_value.get("status", "")),
			"player_id": str(player_id),
			"player_name": str(player.get("name", "")),
			"status": str(state_value.get("status", "")),
			"message": str(state_value.get("message", "")),
			"counter": state_value.get("counter"),
		})
	return events


static func set_shirt_number(career: Career, player_id, number,
		catalog: TeamCatalog = null) -> Dictionary:
	var key := str(player_id)
	if not career.player_ids.has(key):
		return _fail("player is not in this squad")
	if number == null:
		return _fail("shirt number is required")
	var value := int(number)
	if value < 1 or value > MAX_SHIRT_NUMBER:
		return _fail("shirt number must be between 1 and 99")
	if catalog != null:
		_ensure_numbers(career, catalog)
	var numbers: Dictionary = career.shirt_numbers
	for other_id in numbers:
		if str(other_id) != key and int(numbers[other_id]) == value:
			return _fail("shirt number is already taken")
	numbers[key] = value
	career.shirt_numbers = numbers
	_journal(career, "player.shirt_number", {"player_id": key, "number": value})
	return {"ok": true, "error": "", "player_id": key, "number": value}


static func shirt_number_rows(career: Career, catalog: TeamCatalog) -> Array:
	if catalog != null:
		_ensure_numbers(career, catalog)
	var rows: Array = []
	for player in _squad(catalog, career):
		var player_id := str(player.get("id", ""))
		var number = career.shirt_numbers.get(player_id)
		rows.append({
			"player_id": player_id,
			"player_name": str(player.get("name", "")),
			"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
			"number": null if number == null else int(number),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first = a.get("number")
		var second = b.get("number")
		if first == null:
			return false
		if second == null:
			return true
		if int(first) != int(second):
			return int(first) < int(second)
		return str(a.get("player_name", "")) < str(b.get("player_name", "")))
	return rows


static func free_shirt_numbers(career: Career, player_id) -> Array:
	# The client rule (state/squad.svelte.js freeShirtNumbers): 1..99 minus the
	# numbers the other squad players already wear.
	var key := str(player_id)
	var taken := {}
	for other_id in career.player_ids:
		if str(other_id) == key:
			continue
		var number = career.shirt_numbers.get(str(other_id))
		if number != null:
			taken[int(number)] = true
	var free: Array = []
	for number in range(1, MAX_SHIRT_NUMBER + 1):
		if not taken.has(number):
			free.append(number)
	return free


static func release_preview(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	var player := _find(_squad(catalog, career), key)
	if player.is_empty():
		return {"player_id": key, "player_name": "", "can_release": false,
			"reason": "player is not in this squad", "squad_size": career.player_ids.size()}
	var contract: Dictionary = career.player_contracts.get(key) \
		if career.player_contracts.get(key) is Dictionary else {}
	var can_release := career.player_ids.size() > MIN_SQUAD_SIZE
	return {
		"player_id": key,
		"player_name": str(player.get("name", "")),
		"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
		"market_value": CareerSearch.market_value(career, player, key),
		"weekly_wage": int(contract.get("weekly_wage", 0)),
		"years": int(contract.get("years", 1)),
		"squad_size": career.player_ids.size(),
		"can_release": can_release,
		"reason": "" if can_release else "the squad cannot drop below 11 players",
	}


static func release_player(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	if not career.player_ids.has(key):
		return _fail("player is not in this squad")
	if career.player_ids.size() <= MIN_SQUAD_SIZE:
		return _fail("the squad cannot drop below 11 players")
	var preview := release_preview(career, catalog, key)
	var ids: Array = career.player_ids
	ids.erase(key)
	career.data["player_ids"] = ids
	CareerWorldMarket.apply_delta(career, career.club_id, key, false)
	for field in ["lineup", "bench"]:
		var order = career.data.get(field)
		if order is Array and (order as Array).has(key):
			(order as Array).erase(key)
			career.data[field] = order
	for field in ["player_state", "player_contracts", "player_values", "player_ages",
			"shirt_numbers", "player_transfers", "negotiations", "transfer_contracts"]:
		var store = career.data.get(field)
		if store is Dictionary:
			(store as Dictionary).erase(key)
	var roles: Dictionary = career.role_assignments
	var kept := {}
	for role in roles:
		if str(roles[role]) != key:
			kept[str(role)] = str(roles[role])
	career.role_assignments = kept
	_journal(career, "player.released", {"player_id": key})
	return {"ok": true, "error": "", "player_id": key,
		"player_name": str(preview.get("player_name", ""))}


static func _resolve_one(career: Career, player_id: String, state_value: Dictionary) -> void:
	var value := maxi(int(career.player_values.get(player_id, 0)), MIN_MARKET_VALUE)
	var clean := _clean_terms(state_value.get("offer"))
	if not clean.get("ok", false):
		return
	var offer: Dictionary = clean["terms"]
	var demand_terms = state_value.get("demand")
	if not (demand_terms is Dictionary):
		return
	var shortfalls := _term_shortfalls(offer, demand_terms, value)
	if shortfalls.is_empty():
		state_value["status"] = "accepted"
		state_value["counter"] = null
		state_value["message"] = ACCEPTED_MESSAGE
	elif int(state_value.get("counter_offers", 0)) >= MAX_COUNTER_OFFERS:
		state_value["status"] = "refused"
		state_value["counter"] = null
		state_value["message"] = REFUSED_MESSAGE
	else:
		state_value["counter_offers"] = int(state_value.get("counter_offers", 0)) + 1
		state_value["status"] = "counter"
		state_value["counter"] = _counter_terms(offer, demand_terms, value, shortfalls)
		var messages: Array = []
		for key in shortfalls:
			if COUNTER_MESSAGES.has(key):
				messages.append(str(COUNTER_MESSAGES[key]))
		state_value["message"] = " ".join(PackedStringArray(messages))
	state_value["acknowledged"] = false


static func _term_shortfalls(offer: Dictionary, demand_terms: Dictionary, value: int) -> Array:
	var shortfalls: Array = []
	if int(offer.get("weekly_wage", 0)) < int(demand_terms.get("weekly_wage", 0)):
		shortfalls.append("wage")
	if int(offer.get("years", 0)) < int(demand_terms.get("years", 0)):
		shortfalls.append("years")
	if _share(offer.get("squad_role")) < _share(demand_terms.get("squad_role")):
		shortfalls.append("role")
	var minimum := int(float(value) * 1.2)
	var maximum := int(float(value) * 2.0)
	if int(offer.get("release_clause", 0)) < minimum:
		shortfalls.append("clause_low")
	elif int(offer.get("release_clause", 0)) > maximum:
		shortfalls.append("clause_high")
	return shortfalls


static func _counter_terms(offer: Dictionary, demand_terms: Dictionary, value: int,
		shortfalls: Array) -> Dictionary:
	var minimum := int(float(value) * 1.2)
	var maximum := int(float(value) * 2.0)
	var clause := int(offer.get("release_clause", 0))
	if shortfalls.has("clause_high"):
		clause = maximum
	else:
		clause = maxi(clause, minimum)
	return {
		"years": mini(5, maxi(int(offer.get("years", 0)), int(demand_terms.get("years", 0)))),
		"weekly_wage": maxi(int(offer.get("weekly_wage", 0)),
			int(demand_terms.get("weekly_wage", 0))),
		"squad_role": str(demand_terms.get("squad_role", "")) if shortfalls.has("role") \
			else str(offer.get("squad_role", "")),
		"release_clause": clause,
	}


static func _clean_terms(terms) -> Dictionary:
	if not (terms is Dictionary):
		return {"ok": false, "error": "contract length must be between 1 and 5 years"}
	var years := int(terms.get("years", 0))
	if years < 1 or years > 5:
		return {"ok": false, "error": "contract length must be between 1 and 5 years"}
	var wage := int(terms.get("weekly_wage", 0))
	if wage < CareerSquad.MIN_WEEKLY_WAGE or wage > MAX_WEEKLY_WAGE:
		return {"ok": false, "error": "weekly wage is out of range"}
	var role_id := str(terms.get("squad_role", ""))
	if not CareerSquad.SQUAD_ROLE_SHARE.has(role_id):
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


static func _apply_contract(career: Career, player_id: String,
		terms: Dictionary) -> Dictionary:
	var contracts: Dictionary = career.player_contracts
	var contract: Dictionary = contracts.get(player_id) \
		if contracts.get(player_id) is Dictionary else {}
	contract["years"] = int(terms.get("years", 1))
	contract["weekly_wage"] = int(terms.get("weekly_wage", 0))
	contract["squad_role"] = str(terms.get("squad_role", CareerSquad.DEFAULT_ROLE))
	contract["release_clause"] = int(terms.get("release_clause", 0))
	contracts[player_id] = contract
	career.player_contracts = contracts
	return contract


static func _think_delay(career: Career, player_id: String, rounds: int) -> int:
	var rng := CareerRng.seeded("%d:thinking:%s:%d" % [career.seed, player_id, rounds])
	return int(rng.choice(THINK_DAYS))


static func _wage_from_value(career: Career, player_id: String, value: int, age: int) -> int:
	# server/career/squad.py _wage_from_value, driven by career.player_values.
	var age_factor := 1.1
	if age > 31:
		age_factor = 0.8
	elif age > 28:
		age_factor = 0.9
	elif age > 23:
		age_factor = 1.0
	var rng := CareerRng.seeded("%d:contract:%s:wage" % [career.seed, player_id])
	var weekly := float(value) * 0.12 * age_factor * rng.uniform(0.9, 1.1) / 52.0
	return maxi(CareerSquad.MIN_WEEKLY_WAGE, CareerRng.python_round(weekly / 100.0) * 100)


static func _share(role_id) -> float:
	return float(CareerSquad.SQUAD_ROLE_SHARE.get(str(role_id),
		CareerSquad.SQUAD_ROLE_SHARE[CareerSquad.DEFAULT_ROLE]))


static func _state_for(career: Career, player_id: String) -> Dictionary:
	var state_value = career.negotiations.get(player_id)
	return state_value if state_value is Dictionary else {}


static func _squad(catalog: TeamCatalog, career: Career) -> Array:
	if catalog == null or career == null:
		return []
	var players := catalog.career_players_by_ids(career.player_ids, false)
	if not players.is_empty():
		CareerSquad.ensure_finances(career, players)
	return players


static func _ensure_numbers(career: Career, catalog: TeamCatalog) -> void:
	var players := catalog.career_players_by_ids(career.player_ids, false)
	if not players.is_empty():
		CareerSquad.ensure_shirt_numbers(career, players)


static func _find(players: Array, player_id: String) -> Dictionary:
	for player in players:
		if str((player as Dictionary).get("id", "")) == player_id:
			return player
	return {}


static func _without_key(source: Dictionary, key: String) -> Dictionary:
	# Property getters hand out the stored dictionary; write back through the setter.
	var copy: Dictionary = source
	copy.erase(key)
	return copy


static func _journal(career: Career, kind: String, payload: Dictionary) -> void:
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": kind,
		"payload": payload,
	})


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "state": {}, "contract": {}}
