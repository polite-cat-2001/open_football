extends SceneTree
# Headless golden check for the single dated tick (CareerAdvance): the ordered
# incoming/world/contract/negotiation steps, the markers that make a repeated
# tick empty, and the hub notices it returns.
# Fixtures come from the prototype app (tmp/oracle_career_l2.py).
#
# Run:  godot --headless --path . -s res://tests/check_career_advance_tick.gd

const GOLDEN := "res://tests/fixtures/career_advance_tick_golden.json"

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
	print("== check_career_advance_tick: ", "PASS" if failures.is_empty() else "FAIL",
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


func _has_type(events: Array, kind: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == kind:
			return true
	return false


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the advance golden loads")
	if not (golden is Dictionary):
		_finish()
		return
	var header: Dictionary = golden["career"]
	var career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	career.data["created_at"] = str(header["created_at"])
	career.data["date"] = "2026-07-02"
	career.incoming_market_date = "2026-07-02"
	career.world_market_date = "2026-07-02"

	var ticked := CareerAdvance.tick(career, catalog, str(golden["tick_date"]))
	_check(bool(ticked.get("changed", false)), "a tick that grows the world reports a change")
	_check(str(career.date) == str(golden["tick_date"]), "the tick moves the clock")
	_check(str(career.incoming_market_date) == str(golden["incoming_market_date"]),
		"the incoming marker lands on the tick day")
	_check(str(career.world_market_date) == str(golden["world_market_date"]),
		"the world marker lands on the tick day")
	_check(career.world_transfers.size() == int(golden["world_transfers"]),
		"no world batch triggers in that week")
	var expected_offers: Array = golden["offers"]
	_check(career.incoming_offers.size() == expected_offers.size(),
		"the tick creates the prototype's incoming offers")
	for index in range(mini(expected_offers.size(), career.incoming_offers.size())):
		var offer: Dictionary = career.incoming_offers[index]
		var expected: Dictionary = expected_offers[index]
		for key in ["offer_id", "player_id", "club_id", "amount", "created_at"]:
			var actual_value = str(offer.get("id", "")) if key == "offer_id" \
				else offer.get(key)
			_check(_same(actual_value, expected[key]), "offer %d: %s" % [index, key])
	_check(_has_type(ticked["events"], "transfer.received"),
		"the new offer is one of the tick's notices")
	for event in ticked["events"]:
		_check(event is Dictionary and not str(event.get("type", "")).is_empty()
			and not str(event.get("message", "")).is_empty(),
			"every tick event is a hub notice")

	var offers_before := career.incoming_offers.size()
	var transfers_before := career.world_transfers.size()
	var repeated := CareerAdvance.tick(career, catalog, str(golden["tick_date"]))
	_check(repeated["events"].is_empty(), "a repeated tick for the same day is empty")
	_check(repeated["changed"] == false, "a repeated tick reports no change")
	_check(career.incoming_offers.size() == offers_before, "no duplicate incoming offers")
	_check(career.world_transfers.size() == transfers_before, "no duplicate world transfers")
	_check(career.incoming_offers.size() == int(golden["repeat"]["offers"]),
		"the repeat leaves the prototype's offer count")
	_check(career.world_transfers.size() == int(golden["repeat"]["world_transfers"]),
		"the repeat leaves the prototype's transfer count")

	var next := CareerAdvance.tick(career, catalog, "2026-08-01")
	_check(_has_type(next["events"], "world.transfer"),
		"the next window's tick reports the AI-to-AI deals")
	_check(_has_type(next["events"], "transfer.received"),
		"the next window's tick reports new incoming offers")
	_check(career.incoming_offers.size() == int(golden["next_window"]["offers"]),
		"the next window has the prototype's offer count")
	_check(career.world_transfers.size() == int(golden["next_window"]["world_transfers"]),
		"the next window runs the prototype's batch")
	_check(str(career.world_market_date) == str(golden["next_window"]["world_market_date"]),
		"the world marker follows the tick")

	# A tick without an explicit date uses career.date and changes nothing.
	var quiet := CareerAdvance.tick(career, catalog)
	_check(quiet["events"].is_empty() and quiet["changed"] == false,
		"a tick on the same day is a no-op")

	# An old save without the L2 keys loads and ticks without inventing state.
	var raw: Dictionary = career.to_save()
	for key in ["incoming_offers", "pending_departures", "incoming_market_date",
			"world_market_date", "world_transfers", "club_deltas", "negotiations"]:
		raw.erase(key)
	var old := Career.from_save(raw)
	_check(old != null, "an old save without the L2 keys loads")
	_check(CareerIncomingOffers.received_rows(old, catalog).is_empty(),
		"an old save has no incoming offers")
	_check((old.data.get("negotiations", {}) as Dictionary).is_empty(),
		"an old save has no renewal talks")
	old.data["date"] = "2026-09-05"
	var old_tick := CareerAdvance.tick(old, catalog)
	_check(old_tick["events"].is_empty(), "an old save tick does not invent events")
	_check(str(old.world_market_date) == "2026-09-05"
		and str(old.incoming_market_date) == "2026-09-05",
		"the missing markers are created on the first tick")
	_finish()
