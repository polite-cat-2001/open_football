class_name CareerAdvance
extends RefCounted
# The single dated tick the career hub runs after it moves the calendar:
# incoming AI offers, the AI-to-AI world market, the club's answers to our
# offers and contracts, contract completion, renewal talks, deferred departures
# and the scouts — in that order, once per day. Every sub-step keeps its own date
# marker, so running the tick twice for the same day adds nothing.


static func tick(career: Career, catalog: TeamCatalog, today := "") -> Dictionary:
	if career == null or catalog == null:
		return {"events": [], "changed": false}
	var reference := str(today).substr(0, 10) if not str(today).is_empty() else career.date
	# The hub runs the tick every time it opens; a day that was already ticked
	# must cost nothing. Without this a career (or an older save, which has no
	# marker yet) pays for the whole world market on its first frame; the
	# prototype only advances on a new day.
	var marker := str(career.data.get("last_tick_date", "")).substr(0, 10)
	if marker.is_empty():
		marker = career.date
	if marker == reference:
		return {"events": [], "changed": false}
	var before := _signature(career)
	var events: Array = []

	# The tick is the calendar step, so every sub-step sees the same day.
	career.data["date"] = reference
	CareerEurope.simulate_due(career, catalog, reference)
	CareerEurope.ensure_qualifying(career, catalog)
	CareerConfederation.ensure(career, catalog)

	var previous_incoming := career.incoming_market_date
	if previous_incoming.is_empty():
		previous_incoming = reference
	events.append_array(CareerIncomingOffers.process_days(career, catalog,
		previous_incoming, reference))

	var previous_world := career.world_market_date
	events.append_array(CareerWorldMarket.process_days(career, catalog, previous_world,
		reference))

	events.append_array(CareerTransferOffers.process_due(career, catalog, reference))
	events.append_array(CareerTransferContracts.process_due(career, catalog, reference))
	events.append_array(CareerTransferContracts.execute_pending(career, catalog, reference))
	events.append_array(CareerSquadActions.process_due(career, catalog, reference))
	events.append_array(CareerIncomingOffers.execute_pending_departures(career, catalog,
		reference))
	events.append_array(CareerScouting.process_days(career, catalog, previous_incoming,
		reference))

	for event in events:
		if event is Dictionary and str(event.get("message", "")).is_empty():
			event["message"] = _fallback_message(event)
	career.data["last_tick_date"] = reference
	return {
		"events": events,
		"changed": before != _signature(career) or not events.is_empty(),
	}


static func _signature(career: Career) -> String:
	# Cheap change probe: sizes and the balance cover every list the tick grows.
	return "%d|%d|%d|%d|%d|%d|%d|%d|%s" % [
		career.incoming_offers.size(),
		career.world_transfers.size(),
		career.transfer_offers.size(),
		career.transfer_contracts.size(),
		career.pending_transfers.size(),
		career.pending_departures.size(),
		career.negotiations.size(),
		career.player_ids.size(),
		str(career.balance),
	]


static func _fallback_message(event: Dictionary) -> String:
	var player_name := str(event.get("player_name", ""))
	if not player_name.is_empty():
		return "%s: %s" % [str(event.get("type", "")), player_name]
	return str(event.get("type", ""))
