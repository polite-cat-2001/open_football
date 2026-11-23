extends SceneTree
# Headless check for incoming AI offers (ticket 08): the window and
# out-of-window cadence, the deadline burst, accept inside/outside the window,
# the deferred departure, the single counter and its 2..4 day answer, refusal
# and expiry. The offers themselves are generated against the current database;
# the fixture only supplies the career seeds and the prototype's burst shape.
#
# Run:  godot --headless --path . -s res://tests/check_career_incoming_offers.gd

const GOLDEN := "res://tests/fixtures/career_incoming_offers_golden.json"

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
	print("== check_career_incoming_offers: ", "PASS" if failures.is_empty() else "FAIL",
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


func _career(catalog: TeamCatalog, header: Dictionary) -> Career:
	var career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	if career == null:
		return null
	career.data["created_at"] = str(header["created_at"])
	career.data["date"] = str(header["date"])
	return career


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the incoming golden loads")
	if not (golden is Dictionary):
		_finish()
		return

	# A week of the summer window: one or two offers a week.
	var career := _career(catalog, golden["career"])
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	_check(int(career.balance) == 318400000, "the starting balance matches the prototype")
	career.incoming_market_date = "2026-07-01"
	var events := CareerIncomingOffers.process_days(career, catalog, "2026-07-01", "2026-07-07")
	_check(career.incoming_offers.size() >= 1, "the window week creates offers")
	_check(str(career.incoming_market_date) == "2026-07-07", "the incoming marker moves")
	_check(events.size() == career.incoming_offers.size(),
		"every new offer is announced")
	if not events.is_empty():
		_check(str(events[0].get("type", "")) == "transfer.received"
			and not str(events[0].get("message", "")).is_empty(),
			"the offer event is a hub notice")
	var rows := CareerIncomingOffers.received_rows(career, catalog)
	_check(rows.size() == career.incoming_offers.size(),
		"the received list shows the offers")
	for row in rows:
		_check(not str((row as Dictionary).get("offer_id", "")).is_empty()
			and not str(((row as Dictionary).get("player", {}) as Dictionary)
				.get("player_id", "")).is_empty(), "an offer row is complete")
	_check(CareerIncomingOffers.unread_count(career) == career.incoming_offers.size(),
		"every new offer is unread")
	var first_id := str((career.incoming_offers[0] as Dictionary).get("id", ""))
	_check(not CareerIncomingOffers.ack(career, first_id).get("row", {}).is_empty(),
		"an offer can be acknowledged")
	_check(CareerIncomingOffers.unread_count(career)
		== career.incoming_offers.size() - 1,
		"acknowledging clears the badge entry")
	_check(str(career.journal[-1].get("type", "")) == "transfer.received",
		"an offer is journalled like the prototype")

	# Week two: the cadence adds the next batch and keeps the first.
	var ids_before: Array = []
	for offer in career.incoming_offers:
		ids_before.append(str(offer.get("id", "")))
	career.data["date"] = "2026-07-14"
	CareerIncomingOffers.process_days(career, catalog, career.incoming_market_date,
		career.date)
	var ids: Array = []
	for offer in career.incoming_offers:
		ids.append(str(offer.get("id", "")))
	_check(ids.size() >= ids_before.size(), "week two keeps the earlier offers")
	for kept in ids_before:
		_check(ids.has(kept), "week two keeps offer " + kept)

	# Outside the window: one offer a fortnight.
	var outside := _career(catalog, golden["outside_window"]["career"])
	outside.incoming_market_date = "2026-09-01"
	CareerIncomingOffers.process_days(outside, catalog, "2026-09-01", "2026-09-14")
	_check(outside.incoming_offers.size() >= 1,
		"a fortnight outside the window sends an offer")
	if not outside.incoming_offers.is_empty():
		var outside_row: Dictionary = CareerIncomingOffers.received_rows(outside,
			catalog)[0]
		_check(not str(outside_row.get("offer_id", "")).is_empty()
			and not str((outside_row.get("player", {}) as Dictionary)
				.get("player_id", "")).is_empty(), "the outside offer is complete")

	# Accept inside the window: the player leaves at once and the fee is paid.
	var inside: Dictionary = golden["accept_inside"]
	var accepted := _career(catalog, inside["career"])
	accepted.incoming_market_date = "2026-07-01"
	CareerIncomingOffers.process_days(accepted, catalog, "2026-07-01", "2026-07-07")
	_check(not accepted.incoming_offers.is_empty(), "the window creates an offer")
	if accepted.incoming_offers.is_empty():
		_finish()
		return
	var accepted_offer: Dictionary = accepted.incoming_offers[0]
	var offer_id := str(accepted_offer.get("id", ""))
	var accepted_player := str(accepted_offer.get("player_id", ""))
	var accepted_amount := int(accepted_offer.get("amount", 0))
	var accepted_club := str(accepted_offer.get("club_id", ""))
	var before := int(accepted.balance)
	var result := CareerIncomingOffers.accept(accepted, catalog, offer_id)
	_check(bool(result.get("ok", false)), "the offer can be accepted: "
		+ str(result.get("error", "")))
	_check(accepted.balance == before + accepted_amount, "the fee is credited")
	_check(not accepted.player_ids.has(accepted_player), "the player leaves the squad")
	_check(accepted.pending_departures.is_empty(), "no departure is pending inside the window")
	_check(str(accepted.journal[-1].get("type", "")) == "transfer.incoming.accepted",
		"the acceptance is journalled")
	_check(str((accepted.transfer_history[-1] as Dictionary).get("status", "")) == "completed",
		"the history entry is completed")
	var delta: Dictionary = accepted.club_deltas.get(accepted_club, {})
	_check((delta.get("in", []) as Array).has(accepted_player),
		"the buyer club receives the player in club_deltas")

	# The squad cannot be sold below eleven players.
	var thin := _career(catalog, inside["career"])
	thin.incoming_market_date = "2026-07-01"
	CareerIncomingOffers.process_days(thin, catalog, "2026-07-01", "2026-07-07")
	var thin_ids: Array = [accepted_player]
	for player_id in thin.player_ids:
		if thin_ids.size() >= 11:
			break
		if not thin_ids.has(str(player_id)):
			thin_ids.append(str(player_id))
	thin.data["player_ids"] = thin_ids
	var blocked := CareerIncomingOffers.accept(thin, catalog, offer_id)
	_check(str(blocked.get("error", "")) == "the squad cannot drop below 11 players",
		"an eleven-player squad cannot sell")
	_check(bool(blocked.get("ok", true)) == false, "the blocked accept changes nothing")

	# Accept outside the window: agreed now, executed on the window's first day.
	var outside_accept: Dictionary = golden["accept_outside"]
	var agreed := _career(catalog, outside_accept["career"])
	agreed.data["date"] = "2026-07-07"
	agreed.incoming_market_date = "2026-07-01"
	CareerIncomingOffers.process_days(agreed, catalog, "2026-07-01", "2026-07-07")
	agreed.data["date"] = "2026-09-15"
	_check(not agreed.incoming_offers.is_empty(), "the window creates an outside offer")
	if agreed.incoming_offers.is_empty():
		_finish()
		return
	var agreed_offer: Dictionary = agreed.incoming_offers[0]
	var agreed_id := str(agreed_offer.get("id", ""))
	var agreed_player := str(agreed_offer.get("player_id", ""))
	var agreed_amount := int(agreed_offer.get("amount", 0))
	var agreed_balance := int(agreed.balance)
	var agreed_result := CareerIncomingOffers.accept(agreed, catalog, agreed_id)
	_check(bool(agreed_result.get("ok", false)), "the offer can be agreed outside the window")
	_check(agreed.player_ids.has(agreed_player),
		"the player stays until the window opens")
	_check(agreed.pending_departures.size() == 1, "one departure is pending")
	_check(_roster_has(agreed, catalog, int(agreed.club_id), agreed_player),
		"the roster still lists a player whose move waits for the window")
	# A second club cannot buy the same player: the deal is already agreed.
	var duplicate: Dictionary = CareerIncomingOffers.find_offer(agreed, agreed_id).duplicate(true)
	duplicate["id"] = "second-buyer"
	duplicate["club_id"] = "999"
	duplicate["status"] = "pending"
	duplicate["counter"] = null
	duplicate["execute_on"] = null
	agreed.incoming_offers.append(duplicate)
	var second_buyer := CareerIncomingOffers.accept(agreed, catalog, "second-buyer")
	_check(not bool(second_buyer.get("ok", true))
		and str(second_buyer.get("error", "")).contains("already agreed"),
		"a second club cannot buy a player whose departure is agreed")
	_check(agreed.pending_departures.size() == 1, "the refused accept adds no departure")
	agreed.incoming_offers.erase(duplicate)
	var execute_on := ""
	if agreed.pending_departures.size() == 1:
		var pending: Dictionary = agreed.pending_departures[0]
		execute_on = str(pending.get("execute_on", ""))
		_check(not execute_on.is_empty(), "the pending departure has an execution date")
	_check(str(agreed.transfer_history[-1].get("status", "")) == "agreed",
		"the history entry waits for the window")
	_check(str(detail_message(agreed, agreed_id)).begins_with("The transfer is agreed"),
		"the offer states the execution date")
	_check(not execute_on.is_empty(), "the execution date is set")
	agreed.data["date"] = execute_on
	var departures := CareerIncomingOffers.execute_pending_departures(agreed, catalog,
		execute_on)
	_check(departures.size() == 1, "the pending departure executes on the window day")
	if departures.size() == 1:
		_check(str(departures[0].get("type", "")) == "transfer.departure",
			"the departure is a hub notice")
	_check(not agreed.player_ids.has(agreed_player),
		"the player leaves on the execution day")
	_check(not _roster_has(agreed, catalog, int(agreed.club_id), agreed_player),
		"the career roster drops a sold player the database still lists")
	_check(_sorted_ids(agreed.player_ids) == _roster_ids(agreed, catalog),
		"player_ids and the roster list the same squad after a sale")
	_check(int(agreed.balance) == agreed_balance + agreed_amount,
		"the fee is credited on execution")
	_check(agreed.pending_departures.is_empty(), "the queue is empty after execution")
	_check(str(agreed.journal[-1].get("type", "")) == "transfer.departure",
		"the departure is journalled")
	_check(CareerIncomingOffers.execute_pending_departures(agreed, catalog, execute_on)
		.is_empty(), "a repeated execution does nothing")

	# One counter-offer, answered in two to four days.
	var counter_case: Dictionary = golden["counter"]
	var countered := _career(catalog, counter_case["career"])
	countered.incoming_market_date = "2026-07-01"
	CareerIncomingOffers.process_days(countered, catalog, "2026-07-01", "2026-07-07")
	_check(not countered.incoming_offers.is_empty(), "the window creates a countered offer")
	if countered.incoming_offers.is_empty():
		_finish()
		return
	var counter_id := str((countered.incoming_offers[0] as Dictionary).get("id", ""))
	var current_amount := int(CareerIncomingOffers.find_offer(countered, counter_id)
		.get("amount", 0))
	_check(str(CareerIncomingOffers.counter(countered, counter_id, 0, catalog)
		.get("error", "")) == "counter-offer amount must be positive",
		"a counter must be a positive amount")
	_check(str(CareerIncomingOffers.counter(countered, counter_id, current_amount, catalog)
		.get("error", "")) == "counter-offer must be higher than the current offer",
		"a counter must beat the current offer")
	var counter_amount := current_amount + int(counter_case["counter_amount"])
	var demand: Dictionary = countered.incoming_offers[0].get("demand") \
		if countered.incoming_offers[0].get("demand") is Dictionary else {}
	if int(demand.get("amount", 0)) > current_amount:
		counter_amount = int(demand["amount"])
	var counter_result := CareerIncomingOffers.counter(countered, counter_id,
		counter_amount, catalog)
	_check(bool(counter_result.get("ok", false)), "the offer can be countered: "
		+ str(counter_result.get("error", "")))
	var delayed := CareerIncomingOffers.find_offer(countered, counter_id)
	var delay_days := CareerSearch.date_diff_days(countered.date,
		str(delayed.get("due", "")))
	_check(delay_days >= 2 and delay_days <= 4, "the club answers in 2..4 days")
	var counter_row: Dictionary = counter_result.get("row", {})
	var counter_terms: Dictionary = counter_row.get("counter") \
		if counter_row.get("counter") is Dictionary else {}
	_check(str(counter_row.get("offer_id", "")) == counter_id
		and int(counter_terms.get("amount", 0)) == counter_amount,
		"the counter row shows the higher amount")
	var second := CareerIncomingOffers.counter(countered, counter_id,
		counter_amount + 1000, catalog)
	_check(str(second.get("error", "")) == "this offer cannot be countered",
		"a countered offer cannot be countered again")
	countered.data["date"] = str(delayed.get("due", ""))
	var resolved := CareerIncomingOffers.process_days(countered, catalog, countered.date,
		countered.date)
	_check(resolved.size() == 1, "the counter answers on its due date")
	var answered: Dictionary = CareerIncomingOffers.detail(countered, catalog,
		counter_id).get("row", {})
	_check(str(answered.get("status", "")) == "accepted",
		"a counter at the demand is accepted")

	# Refusal drops the offer from the received list.
	var refused := _career(catalog, counter_case["career"])
	refused.incoming_market_date = "2026-07-01"
	CareerIncomingOffers.process_days(refused, catalog, "2026-07-01", "2026-07-07")
	_check(not refused.incoming_offers.is_empty(), "the window creates a refused offer")
	if refused.incoming_offers.is_empty():
		_finish()
		return
	var refused_id := str((refused.incoming_offers[0] as Dictionary).get("id", ""))
	var received_before := CareerIncomingOffers.received_rows(refused, catalog).size()
	var refused_result := CareerIncomingOffers.refuse(refused, catalog, refused_id)
	_check(bool(refused_result.get("ok", false)), "the offer can be refused")
	var pending_ids: Array = []
	for row in CareerIncomingOffers.received_rows(refused, catalog):
		pending_ids.append(str(row.get("offer_id", "")))
	_check(not pending_ids.has(refused_id)
		and pending_ids.size() == received_before - 1,
		"the refused offer leaves the received list")
	_check(str(CareerIncomingOffers.detail(refused, catalog, refused_id).get("row", {})
		.get("status", "")) == "refused",
		"the refused offer is marked refused")

	# The last window day has no daily limit, and an offer expires after 30 days.
	var burst: Dictionary = golden["burst"]
	var synthetic := _synthetic_career()
	var synthetic_players: Array = []
	for index in range(12):
		synthetic_players.append({
			"id": "p%d" % index, "name": "Player %d" % index, "role": "CF",
			"overall": 80.0, "market_value": 10000000, "age": 25, "club_id": "11",
		})
	var synthetic_clubs := [
		{"id": "11", "name": "Arsenal", "country_id": "189", "country_name": "England",
			"league_name": "Premier League", "tier_rank": 1},
		{"id": "domestic", "name": "Domestic FC", "country_id": "189",
			"country_name": "England", "league_name": "Championship", "tier_rank": 2},
	]
	var synthetic_roles := {
		"11": {"CF": {"count": 3, "best": 80.0}},
		"domestic": {"CF": {"count": 1, "best": 55.0}},
	}
	CareerIncomingOffers.generate(synthetic, "2026-08-30", "2026-08-31",
		synthetic_players, synthetic_clubs, synthetic_roles)
	_check(synthetic.incoming_offers.size() == int(burst["count"]),
		"the deadline day is a burst: %d offers" % int(burst["count"]))
	var created: Array = []
	var clubs_used: Array = []
	for offer in synthetic.incoming_offers:
		if not created.has(str(offer.get("created_at", ""))):
			created.append(str(offer.get("created_at", "")))
		clubs_used.append(str(offer.get("club_id", "")))
	_check(_same(created, burst["created"]), "every burst offer is created on the last day")
	_check(_same(clubs_used, burst["clubs"]), "the burst buyers are the prototype's clubs")
	var expiring: Dictionary = synthetic.incoming_offers[0]
	_check(CareerSearch.date_diff_days(str(expiring.get("created_at", "")),
		str(expiring.get("expires_at", ""))) == 30, "an offer lives 30 days")
	synthetic.data["date"] = str(expiring.get("expires_at", ""))
	CareerIncomingOffers.resolve(synthetic)
	_check(str(expiring.get("status", "")) == str(burst["expired_status"]),
		"the offer expires on its last day")
	_finish()


func detail_message(career: Career, offer_id: String) -> String:
	return str(CareerIncomingOffers.find_offer(career, offer_id).get("message", ""))


func _synthetic_career() -> Career:
	var ids: Array = []
	for index in range(12):
		ids.append("p%d" % index)
	return Career.new({
		"version": Career.SAVE_VERSION,
		"id": "f".repeat(32),
		"seed": 7,
		"date": "2026-08-31",
		"created_at": "2026-07-01T00:00:00.000000Z",
		"updated_at": "2026-07-01T00:00:00.000000Z",
		"manager": {"name": "Synthetic", "nationality_id": "189", "nationality": "England"},
		"club_id": "11",
		"player_ids": ids,
		"journal": [],
		"balance": 0,
	})


func _roster_has(career: Career, catalog: TeamCatalog, club_id: int,
		player_id: String) -> bool:
	for player in CareerSquad.roster(catalog, career, club_id, false):
		if str(player.get("id", "")) == player_id:
			return true
	return false


func _roster_ids(career: Career, catalog: TeamCatalog) -> Array:
	var ids: Array = []
	for player in CareerSquad.roster(catalog, career, int(career.club_id)):
		ids.append(str(player.get("id", "")))
	ids.sort()
	return ids


func _sorted_ids(source: Array) -> Array:
	var ids: Array = []
	for item in source:
		ids.append(str(item))
	ids.sort()
	return ids
