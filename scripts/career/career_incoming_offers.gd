class_name CareerIncomingOffers
extends RefCounted
# Offers that AI clubs send for the manager's own players, ported from
# server/career/incoming_offers.py: generation on a dated cadence (1..2 a week
# inside a transfer window, one a fortnight outside it, a burst on the last
# window day), buyer selection by role need / overall / club tier, one counter
# per offer, 30-day expiry and departures deferred to the window. All random
# draws go through CareerRng, so a seed reproduces the prototype's offers.

const OFFER_LIFETIME_DAYS := 30
const DAILY_LIMIT := 2
const RESPONSE_DAYS := [2, 3, 4]
const FOREIGN_OVERALL_THRESHOLD := 75.0
const MIN_MARKET_VALUE := 50000
const MAX_OVERALL_GAP := 9.0
const MAX_FEE_SQUAD_SHARE := 0.30
const MIN_OFFER_VALUE_SHARE := 0.75
const TIER_LIMITS := [[82.0, 1], [75.0, 2], [68.0, 3], [60.0, 4]]
const ACTIVE_STATUSES := ["pending", "counter"]
const MIN_SQUAD_SIZE := 11

const ROLE_TARGETS := {
	"GK": 2, "CB": 3, "LB": 1, "RB": 1, "DM": 1, "CM": 2,
	"LM": 1, "RM": 1, "AM": 1, "CF": 2,
}

const PENDING_MESSAGE := "The club is waiting for your answer."
const COUNTER_PENDING_MESSAGE := "The club is considering the counter-offer."
const ACCEPTED_MESSAGE := "The offer has been accepted."
const REFUSED_MESSAGE := "You refused the offer."
const EXPIRED_MESSAGE := "The offer has expired."
const ACCEPTED_COUNTER_MESSAGE := "The club accepted the counter-offer."
const REFUSED_COUNTER_MESSAGE := "The club rejected the counter-offer."


static func process_days(career: Career, catalog: TeamCatalog, from_date, to_date) -> Array:
	# The hub's wrapper: read the world data, run the dated generation and keep
	# the marker so a repeated tick adds nothing.
	if career == null or catalog == null:
		return []
	var target := str(to_date).substr(0, 10)
	if target.is_empty():
		target = career.date
	var current := "" if from_date == null else str(from_date).substr(0, 10)
	if current.is_empty():
		current = career.incoming_market_date
	if current.is_empty():
		current = career.date
	# No new day means no generation, but an offer whose answer falls due today
	# must still resolve: the world data is only skipped, not the pass itself.
	var new_day := target > current
	var events := generate(career, current, target,
		catalog.career_players_by_ids(career.player_ids, false) if new_day else [],
		CareerWorldMarket.clubs(catalog) if new_day else [],
		CareerWorldMarket.club_role_stats(catalog) if new_day else {},
		CareerWorldMarket.club_market_stats(catalog) if new_day else {})
	career.incoming_market_date = target
	return events


static func generate(career: Career, from_date, to_date, players: Array, clubs: Array,
		roles: Dictionary, club_stats: Dictionary = {}) -> Array:
	# server/career/incoming_offers.py generate_incoming_offers: one pass per
	# day in (from, to], then resolve. Data is passed in so tests can drive a
	# synthetic world without the database.
	if career == null:
		return []
	var target := str(to_date).substr(0, 10)
	var current := "" if from_date == null else str(from_date).substr(0, 10)
	if CareerSearch.date_parts(target).is_empty() \
			or CareerSearch.date_parts(current).is_empty():
		return []
	if target < current:
		return []
	var events: Array = []
	var day := CareerSearch.add_days(current, 1)
	while day <= target:
		var pace := _pace(career, day)
		var created := _created_between(career, CareerSearch.add_days(day, -int(pace[1])), day)
		var daily := _created_on(career, day)
		while created < int(pace[0]):
			if not bool(pace[2]) and daily >= DAILY_LIMIT:
				break
			var offer := create_offer(career, day, players, clubs, roles, club_stats)
			if offer.is_empty():
				break
			events.append(_received_event(career, offer))
			created += 1
			daily += 1
		day = CareerSearch.add_days(day, 1)
	events.append_array(resolve(career))
	return events


static func create_offer(career: Career, day: String, players: Array, clubs: Array,
		roles: Dictionary, club_stats: Dictionary) -> Dictionary:
	var rng := _rng(career, ["incoming-offer", day, str(career.incoming_offers.size())])
	for _attempt in range(24):
		var player = _choose_player(career, players, rng)
		if player == null:
			return {}
		var kind := _choose_kind(career, player, rng)
		var buyers := _buyer_candidates(career, player, clubs, roles, club_stats, kind)
		if (buyers[0] as Array).is_empty():
			continue
		var club = CareerWorldMarket.weighted_choice(rng, buyers[0], buyers[1])
		var player_id := str(player.get("id", ""))
		var club_id := str(club.get("id", ""))
		if not find_active(career, player_id, club_id).is_empty():
			continue
		var terms := _offer_terms(career, player, kind, day, club_id)
		var offer := {
			"id": _offer_id(career, player_id, club_id, day),
			"player_id": player_id,
			"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
			"club_id": club_id,
			"club_name": str(club.get("name", "")),
			"club_logo": str(club.get("logo", "")),
			"club_country_id": str(club.get("country_id", "")),
			"club_country_name": str(club.get("country_name", "")),
			"club_league_name": str(club.get("league_name", "")),
			"kind": kind,
			"amount": int(terms["amount"]),
			"loan_fee": int(terms["loan_fee"]),
			"wage_share": int(terms["wage_share"]),
			"status": "pending",
			"created_at": day,
			"expires_at": CareerSearch.add_days(day, OFFER_LIFETIME_DAYS),
			"due": null,
			"responded_at": null,
			"counter_offers": 0,
			"counter": null,
			"acknowledged": false,
			"message": PENDING_MESSAGE,
			"demand": (terms["demand"] as Dictionary).duplicate(),
			"execute_on": null,
		}
		career.incoming_offers.append(offer)
		_journal(career, "transfer.received", {
			"offer_id": str(offer["id"]),
			"player_id": player_id,
			"club_id": club_id,
			"kind": kind,
			"amount": int(terms["amount"]),
		})
		return offer
	return {}


static func find_offer(career: Career, offer_id) -> Dictionary:
	var key := str(offer_id)
	for offer in career.incoming_offers:
		if offer is Dictionary and str(offer.get("id", "")) == key:
			return offer
	return {}


static func find_active(career: Career, player_id: String, club_id: String) -> Dictionary:
	for offer in career.incoming_offers:
		if not (offer is Dictionary):
			continue
		if str(offer.get("player_id", "")) != player_id:
			continue
		if str(offer.get("club_id", "")) != club_id:
			continue
		if ACTIVE_STATUSES.has(str(offer.get("status", ""))):
			return offer
	return {}


static func received_rows(career: Career, catalog: TeamCatalog) -> Array:
	# Offers that still need an answer, newest first (the prototype's RECEIVED
	# list). Any status is reachable through detail() and the action results.
	var rows: Array = []
	var offers: Array = career.incoming_offers
	for index in range(offers.size() - 1, -1, -1):
		var offer = offers[index]
		if not (offer is Dictionary):
			continue
		if not ACTIVE_STATUSES.has(str(offer.get("status", ""))):
			continue
		rows.append(row(career, catalog, offer))
	return rows


static func row(career: Career, catalog: TeamCatalog, offer: Dictionary) -> Dictionary:
	var status := str(offer.get("status", ""))
	var player_id := str(offer.get("player_id", ""))
	var player: Dictionary = {}
	if catalog != null:
		player = CareerSearch.profile(catalog, career, player_id)
	var counter := _term_view(offer.get("counter"))
	var demand := _term_view(offer.get("demand"))
	var can_accept := status == "pending" and career.player_ids.has(player_id) \
		and career.player_ids.size() > MIN_SQUAD_SIZE
	return {
		"offer_id": str(offer.get("id", "")),
		"player": player,
		"club_id": str(offer.get("club_id", "")),
		"club_name": str(offer.get("club_name", "")),
		"club_logo": str(offer.get("club_logo", "")),
		"kind": str(offer.get("kind", "transfer")),
		"kind_label": CareerTransfers.kind_label(str(offer.get("kind", "transfer"))),
		"amount": int(offer.get("amount", 0)),
		"loan_fee": int(offer.get("loan_fee", 0)),
		"wage_share": int(offer.get("wage_share", 0)),
		"demand": demand,
		"status": status,
		"created_at": offer.get("created_at"),
		"expires_at": offer.get("expires_at"),
		"due": offer.get("due"),
		"counter": null if counter.is_empty() else counter,
		"unread": not bool(offer.get("acknowledged", false)),
		"message": str(offer.get("message", "")),
		"can_accept": can_accept,
		"can_refuse": status == "pending",
		"can_counter": status == "pending" and int(offer.get("counter_offers", 0)) < 1,
		# Extras for the offer modal: who is bidding and what was already said.
		"overall": float(offer.get("overall", 0.0)),
		"club_country_id": str(offer.get("club_country_id", "")),
		"club_country_name": str(offer.get("club_country_name", "")),
		"club_league_name": str(offer.get("club_league_name", "")),
		"responded_at": offer.get("responded_at"),
		"counter_offers": int(offer.get("counter_offers", 0)),
		"execute_on": offer.get("execute_on"),
		"executed_at": offer.get("executed_at"),
	}


static func detail(career: Career, catalog: TeamCatalog, offer_id) -> Dictionary:
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return {"ok": false, "error": "offer not found", "row": {}}
	return {"ok": true, "error": "", "row": row(career, catalog, offer)}


static func unread_count(career: Career) -> int:
	# The badge counts what the RECEIVED list shows: an offer that already got
	# its answer (accepted / refused / expired) is resolved news, not an unread
	# offer, even though resolve() re-flags it for the journal.
	var total := 0
	for offer in career.incoming_offers:
		if not (offer is Dictionary):
			continue
		if not ACTIVE_STATUSES.has(str(offer.get("status", ""))):
			continue
		if not bool(offer.get("acknowledged", false)):
			total += 1
	return total


static func accept(career: Career, catalog: TeamCatalog, offer_id) -> Dictionary:
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return _fail("offer not found")
	if str(offer.get("status", "")) != "pending":
		return _fail("this offer cannot be accepted")
	var player_id := str(offer.get("player_id", ""))
	if not career.player_ids.has(player_id):
		return _fail("player is not in this squad")
	if career.player_ids.size() <= MIN_SQUAD_SIZE:
		return _fail("the squad cannot drop below 11 players")
	if _departing(career, player_id):
		return _fail("a transfer for this player is already agreed")
	offer["acknowledged"] = true
	_complete_accept(career, offer)
	_journal(career, "transfer.incoming.accepted", {
		"offer_id": str(offer.get("id", "")),
		"player_id": player_id,
		"club_id": str(offer.get("club_id", "")),
		"fee": int(offer.get("amount", 0)),
		"execute_on": offer.get("execute_on"),
	})
	return {"ok": true, "error": "", "row": row(career, catalog, offer)}


static func refuse(career: Career, catalog: TeamCatalog, offer_id) -> Dictionary:
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return _fail("offer not found")
	if str(offer.get("status", "")) != "pending":
		return _fail("this offer cannot be refused")
	offer["status"] = "refused"
	offer["acknowledged"] = true
	offer["responded_at"] = career.date
	offer["message"] = REFUSED_MESSAGE
	_journal(career, "transfer.incoming.refused", {
		"offer_id": str(offer.get("id", "")),
		"player_id": str(offer.get("player_id", "")),
	})
	return {"ok": true, "error": "", "row": row(career, catalog, offer)}


static func counter(career: Career, offer_id, amount, catalog: TeamCatalog = null) -> Dictionary:
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return _fail("offer not found")
	if str(offer.get("status", "")) != "pending":
		return _fail("this offer cannot be countered")
	if int(offer.get("counter_offers", 0)) >= 1:
		return _fail("only one counter-offer is allowed")
	var value := 0 if amount == null else int(amount)
	if value <= 0:
		return _fail("counter-offer amount must be positive")
	if value <= int(offer.get("amount", 0)):
		return _fail("counter-offer must be higher than the current offer")
	offer["status"] = "counter"
	offer["counter_offers"] = 1
	offer["counter"] = {
		"amount": value,
		"loan_fee": value if str(offer.get("kind", "")) == "loan" else 0,
		"wage_share": int(offer.get("wage_share", 0)),
	}
	offer["due"] = _counter_due(career, offer)
	offer["acknowledged"] = true
	offer["message"] = COUNTER_PENDING_MESSAGE
	_journal(career, "transfer.incoming.countered", {
		"offer_id": str(offer.get("id", "")),
		"player_id": str(offer.get("player_id", "")),
		"amount": value,
	})
	return {"ok": true, "error": "", "row": row(career, catalog, offer)}


static func ack(career: Career, offer_id, catalog: TeamCatalog = null) -> Dictionary:
	var offer := find_offer(career, offer_id)
	if offer.is_empty():
		return _fail("offer not found")
	offer["acknowledged"] = true
	return {"ok": true, "error": "", "row": row(career, catalog, offer)}


static func resolve(career: Career) -> Array:
	# Expiry and the club's answer to our counter-offer, run on every tick.
	var events: Array = []
	for offer in career.incoming_offers:
		if not (offer is Dictionary):
			continue
		if not ACTIVE_STATUSES.has(str(offer.get("status", ""))):
			continue
		var expires_at = offer.get("expires_at")
		if expires_at != null and not str(expires_at).is_empty() \
				and career.date >= str(expires_at):
			offer["status"] = "expired"
			offer["acknowledged"] = false
			offer["responded_at"] = career.date
			offer["message"] = EXPIRED_MESSAGE
			events.append(_resolved_event(offer))
			continue
		if str(offer.get("status", "")) != "counter":
			continue
		var due = offer.get("due")
		if due == null or str(due).is_empty() or career.date < str(due):
			continue
		var counter_terms: Dictionary = offer.get("counter") \
			if offer.get("counter") is Dictionary else {}
		var demand: Dictionary = offer.get("demand") \
			if offer.get("demand") is Dictionary else {}
		var willing := int(demand.get("amount", 0))
		offer["acknowledged"] = false
		offer["responded_at"] = career.date
		if int(counter_terms.get("amount", 0)) <= willing \
				and career.player_ids.size() > MIN_SQUAD_SIZE \
				and not _departing(career, str(offer.get("player_id", ""))):
			offer["message"] = ACCEPTED_COUNTER_MESSAGE
			_complete_accept(career, offer)
		else:
			offer["status"] = "refused"
			offer["counter"] = null
			offer["message"] = REFUSED_COUNTER_MESSAGE
		_journal(career, "transfer.incoming.response", {
			"offer_id": str(offer.get("id", "")),
			"player_id": str(offer.get("player_id", "")),
			"status": str(offer.get("status", "")),
		})
		events.append(_resolved_event(offer))
	return events


static func execute_pending_departures(career: Career, catalog: TeamCatalog,
		today := "") -> Array:
	var reference := today if not str(today).is_empty() else career.date
	if career.pending_departures.is_empty():
		return []
	if not CareerTransferContracts.window_open(reference):
		return []
	var remaining: Array = []
	var events: Array = []
	for item in career.pending_departures:
		if not (item is Dictionary):
			continue
		if reference < str(item.get("execute_on", "")):
			remaining.append(item)
			continue
		var player_id := str(item.get("player_id", ""))
		_execute_departure(career, item)
		events.append({
			"type": "transfer.departure",
			"player_id": player_id,
			"player_name": _player_name(catalog, player_id),
			"club_id": str(item.get("club_id", "")),
			"fee": int(item.get("fee", 0)),
			"date": reference,
			"message": "%s completed his move." % _player_name(catalog, player_id),
		})
	career.pending_departures = remaining
	return events


static func _complete_accept(career: Career, offer: Dictionary) -> void:
	var when := career.date
	offer["status"] = "accepted"
	offer["counter"] = null
	offer["responded_at"] = when
	var execute_on := when \
		if CareerTransferContracts.window_open(when) \
		else CareerTransferContracts.next_window(when)
	offer["execute_on"] = execute_on
	career.transfer_history.append({
		"player_id": str(offer.get("player_id", "")),
		"overall": roundf(float(offer.get("overall", 0.0)) * 10.0) / 10.0,
		"from_club_id": str(career.club_id),
		"to_club_id": str(offer.get("club_id", "")),
		"fee": int(offer.get("amount", 0)),
		"kind": str(offer.get("kind", "transfer")),
		"offer_id": str(offer.get("id", "")),
		"date": when.substr(0, 10),
		"status": "completed" if execute_on == when.substr(0, 10) else "agreed",
	})
	if execute_on == when.substr(0, 10):
		offer["message"] = ACCEPTED_MESSAGE
		_execute_departure(career, {
			"player_id": str(offer.get("player_id", "")),
			"club_id": str(offer.get("club_id", "")),
			"offer_id": str(offer.get("id", "")),
			"fee": int(offer.get("amount", 0)),
		})
		offer["executed_at"] = when
		return
	offer["message"] = "The transfer is agreed and will go through on %s." % execute_on
	career.pending_departures.append({
		"player_id": str(offer.get("player_id", "")),
		"club_id": str(offer.get("club_id", "")),
		"offer_id": str(offer.get("id", "")),
		"kind": str(offer.get("kind", "transfer")),
		"fee": int(offer.get("amount", 0)),
		"execute_on": execute_on,
		"agreed_at": when,
	})


static func _execute_departure(career: Career, item: Dictionary) -> void:
	var player_id := str(item.get("player_id", ""))
	if not career.player_ids.has(player_id):
		return
	_remove_player(career, player_id)
	CareerWorldMarket.apply_delta(career, career.club_id, player_id, false)
	var club_id := str(item.get("club_id", ""))
	if not club_id.is_empty():
		CareerWorldMarket.apply_delta(career, club_id, player_id, true)
	var fee := int(item.get("fee", 0))
	if career.balance != null:
		career.balance = int(career.balance) + fee
	item["executed_at"] = career.date
	var offer := find_offer(career, item.get("offer_id"))
	if not offer.is_empty():
		offer["executed_at"] = career.date
	_journal(career, "transfer.departure", {
		"player_id": player_id,
		"club_id": item.get("club_id"),
		"offer_id": item.get("offer_id"),
		"fee": fee,
	})


static func _remove_player(career: Career, player_id: String) -> void:
	var ids: Array = career.player_ids
	ids.erase(player_id)
	career.data["player_ids"] = ids
	var lineup: Array = career.lineup
	if not lineup.is_empty():
		lineup.erase(player_id)
		career.lineup = lineup
	var bench: Array = career.bench_order
	if not bench.is_empty():
		bench.erase(player_id)
		career.bench_order = bench
	for key in ["player_state", "player_contracts", "player_values", "player_ages",
			"shirt_numbers", "player_transfers", "negotiations", "transfer_contracts"]:
		var store = career.data.get(key)
		if store is Dictionary:
			(store as Dictionary).erase(player_id)
	var shortlist: Array = career.shortlist
	if shortlist.has(player_id):
		shortlist.erase(player_id)
		career.shortlist = shortlist


static func _pace(career: Career, day: String) -> Array:
	var bounds := CareerWorldMarket.window_bounds(day)
	if not bounds.is_empty():
		var start: String = bounds[0]
		var end: String = bounds[1]
		var bucket := maxi(0, CareerSearch.date_diff_days(start, day) / 7)
		var rng := _rng(career, ["incoming-pace", start, str(bucket)])
		var target := int(rng.choice([1, 2]))
		var deadline := day == end
		if deadline:
			target = 3 + rng.randbelow(3)
		return [target, 6, deadline]
	return [1, 13, false]


static func _created_between(career: Career, start: String, end: String) -> int:
	var total := 0
	for offer in career.incoming_offers:
		if not (offer is Dictionary):
			continue
		var created := str(offer.get("created_at", "")).substr(0, 10)
		if created.is_empty():
			continue
		if start <= created and created <= end:
			total += 1
	return total


static func _created_on(career: Career, day: String) -> int:
	var total := 0
	for offer in career.incoming_offers:
		if not (offer is Dictionary):
			continue
		if str(offer.get("created_at", "")).substr(0, 10) == day:
			total += 1
	return total


static func _departing(career: Career, player_id: String) -> bool:
	for item in career.pending_departures:
		if item is Dictionary and str(item.get("player_id", "")) == player_id:
			return true
	return false


static func _choose_player(career: Career, players: Array, rng: CareerRng):
	var pool: Array = []
	var weights: Array = []
	for player in players:
		var player_id := str((player as Dictionary).get("id", ""))
		if not career.player_ids.has(player_id):
			continue
		if _departing(career, player_id):
			continue
		var weight := _player_weight(career, player)
		if weight <= 0.0:
			continue
		pool.append(player)
		weights.append(weight)
	if pool.is_empty():
		return null
	return CareerWorldMarket.weighted_choice(rng, pool, weights)


static func _choose_kind(career: Career, player: Dictionary, rng: CareerRng) -> String:
	var status := str(career.player_transfers.get(str(player.get("id", "")), ""))
	if status == "loan":
		return "loan"
	if status == "transfer":
		return "transfer"
	return "loan" if rng.next_float() < 0.15 else "transfer"


static func _club_need(club_id: String, role: String, player: Dictionary,
		roles: Dictionary) -> float:
	var club_roles: Dictionary = roles.get(club_id) \
		if roles.get(club_id) is Dictionary else {}
	var stats: Dictionary = club_roles.get(role) \
		if club_roles.get(role) is Dictionary else {}
	var count := int(stats.get("count", 0))
	var best := float(stats.get("best", 0.0))
	var target := int(ROLE_TARGETS.get(role, 1))
	var need := float(maxi(0, target - count))
	if float(player.get("overall", 0.0)) > best - 2.0:
		need += 1.0
	return need


static func _buyer_candidates(career: Career, player: Dictionary, clubs: Array,
		roles: Dictionary, club_stats: Dictionary, kind: String) -> Array:
	var own_club_id := str(career.club_id)
	var own_country := ""
	for club in clubs:
		if str((club as Dictionary).get("id", "")) == own_club_id:
			own_country = str(club.get("country_id", ""))
			break
	var overall := float(player.get("overall", 0.0))
	var foreign_allowed := overall >= FOREIGN_OVERALL_THRESHOLD
	var max_tier := _max_tier(overall)
	var value := _player_value(career, player)
	var role := str(player.get("role", ""))
	var candidates: Array = []
	var weights: Array = []
	for club in clubs:
		var club_id := str((club as Dictionary).get("id", ""))
		if club_id == own_club_id:
			continue
		var club_roles = roles.get(club_id)
		if not (club_roles is Dictionary) or (club_roles as Dictionary).is_empty():
			continue
		var foreign := str(club.get("country_id", "")) != own_country
		if foreign and not foreign_allowed:
			continue
		var tier := int(club.get("tier_rank", 99))
		if tier <= 0:
			tier = 99
		if tier > max_tier:
			continue
		var need := _club_need(club_id, role, player, roles)
		if need <= 0.0:
			continue
		var stats: Dictionary = club_stats.get(club_id) \
			if club_stats.get(club_id) is Dictionary else {}
		if not stats.is_empty():
			var best := float(stats.get("best", 0.0))
			if best > 0.0 and overall - best > MAX_OVERALL_GAP:
				continue
			var squad_value := int(stats.get("value", 0))
			if kind == "transfer" and squad_value > 0 \
					and float(value) * MIN_OFFER_VALUE_SHARE \
					> float(squad_value) * MAX_FEE_SQUAD_SHARE:
				continue
		var weight := need
		if not foreign:
			weight *= 1.6
		weight *= 1.0 if tier <= 1 else 0.8
		if not stats.is_empty():
			var best := float(stats.get("best", 0.0))
			if best > 0.0:
				weight *= 1.0 + maxf(0.0, best - overall + 5.0) / 10.0
		candidates.append(club)
		weights.append(weight)
	return [candidates, weights]


static func _offer_terms(career: Career, player: Dictionary, kind: String, day: String,
		club_id: String) -> Dictionary:
	var value := _player_value(career, player)
	var rng := _rng(career, ["incoming-terms", day, str(player.get("id", "")), club_id])
	if kind == "loan":
		var fee := _money(float(value) * rng.uniform(0.03, 0.08))
		var demand_fee := maxi(fee, _money(float(value) * rng.uniform(0.05, 0.12)))
		var share := int(rng.choice([50, 60, 70, 80]))
		var demand_share := mini(100, share + int(rng.choice([0, 10, 20])))
		return {
			"amount": fee,
			"loan_fee": fee,
			"wage_share": share,
			"demand": {
				"amount": demand_fee,
				"loan_fee": demand_fee,
				"wage_share": demand_share,
			},
		}
	var fee := _money(float(value) * rng.uniform(0.75, 1.1))
	var demand := maxi(fee, _money(float(value) * rng.uniform(1.0, 1.35)))
	return {
		"amount": fee,
		"loan_fee": 0,
		"wage_share": 0,
		"demand": {"amount": demand},
	}


static func _offer_id(career: Career, player_id: String, club_id: String,
		day: String) -> String:
	var raw := "%d:incoming:%s:%s:%s:%d:%d" % [
		career.seed, day, player_id, club_id,
		career.incoming_offers.size(), career.journal.size(),
	]
	return CareerWorldMarket.sha1_id(raw)


static func _counter_due(career: Career, offer: Dictionary) -> String:
	var rng := _rng(career, ["incoming-response", str(offer.get("id", ""))])
	return CareerSearch.add_days(career.date, int(rng.choice(RESPONSE_DAYS)))


static func _player_weight(career: Career, player: Dictionary) -> float:
	var player_id := str(player.get("id", ""))
	var status := str(career.player_transfers.get(player_id, ""))
	if status == "blocked":
		return 0.0
	var weight := 1.0
	if status == "transfer" or status == "loan":
		weight *= 5.0
	if CareerSearch.contract_months(career, player, player_id) <= 6:
		weight *= 3.0
	weight *= 1.0 + maxf(0.0, float(player.get("overall", 0.0)) - 65.0) / 12.0
	var state = career.player_state.get(player_id)
	var stats: Dictionary = state.get("stats", {}) \
		if state is Dictionary and state.get("stats") is Dictionary else {}
	var goal_points := int(stats.get("goals", 0)) + int(stats.get("assists", 0))
	weight *= 1.0 + minf(2.0, float(goal_points) / 12.0)
	return maxf(0.0, weight)


static func _player_value(career: Career, player: Dictionary) -> int:
	var stored := int(career.player_values.get(str(player.get("id", "")), 0))
	var value := stored if stored > 0 else int(player.get("market_value", 0))
	return maxi(value, MIN_MARKET_VALUE)


static func _max_tier(overall: float) -> int:
	for pair in TIER_LIMITS:
		if overall >= float(pair[0]):
			return int(pair[1])
	return 6


static func _money(value: float) -> int:
	return maxi(0, CareerRng.python_round(value / 10000.0) * 10000)


static func _received_event(career: Career, offer: Dictionary) -> Dictionary:
	return {
		"type": "transfer.received",
		"offer_id": str(offer.get("id", "")),
		"player_id": str(offer.get("player_id", "")),
		"club_id": str(offer.get("club_id", "")),
		"club_name": str(offer.get("club_name", "")),
		"kind": str(offer.get("kind", "transfer")),
		"amount": int(offer.get("amount", 0)),
		"message": "%s wants your player." % str(offer.get("club_name", "")),
	}


static func _resolved_event(offer: Dictionary) -> Dictionary:
	var status := str(offer.get("status", ""))
	return {
		"type": "transfer.incoming.%s" % status,
		"offer_id": str(offer.get("id", "")),
		"player_id": str(offer.get("player_id", "")),
		"club_id": str(offer.get("club_id", "")),
		"club_name": str(offer.get("club_name", "")),
		"status": status,
		"message": str(offer.get("message", "")),
	}


static func _term_view(value) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var view := {}
	for key in value:
		view[str(key)] = int(value[key])
	return view


static func _player_name(catalog: TeamCatalog, player_id) -> String:
	if catalog == null or not str(player_id).is_valid_int():
		return ""
	return str(catalog.career_player(int(player_id), false).get("name", ""))


static func _rng(career: Career, parts: Array) -> CareerRng:
	var text := str(career.seed)
	for part in parts:
		text += ":" + str(part)
	return CareerRng.seeded(text)


static func _journal(career: Career, kind: String, payload: Dictionary) -> void:
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": kind,
		"payload": payload,
	})


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "row": {}}
