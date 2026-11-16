extends SceneTree
# Headless golden check for the AI-to-AI world market (ticket 08): the four
# window batches, the deterministic club sample, per-club buy/sell caps, the
# resulting transfers, club_deltas and the owned squad's own players staying put.
# Fixtures come from the prototype app (tmp/oracle_career_l2.py).
#
# Run:  godot --headless --path . -s res://tests/check_career_world_market.gd

const GOLDEN := "res://tests/fixtures/career_world_market_golden.json"

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
	print("== check_career_world_market: ", "PASS" if failures.is_empty() else "FAIL",
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


func _compare_transfer(label: String, actual: Dictionary, expected: Dictionary) -> void:
	for key in expected:
		var ok := _same(actual.get(key), expected[key])
		_check(ok, "%s: %s" % [label, key])
		if not ok:
			print("    expected: ", expected[key], " actual: ", actual.get(key))


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the world-market golden loads")
	if not (golden is Dictionary):
		_finish()
		return

	# Window calendar and the batch cadence.
	var batches := CareerWorldMarket.batch_schedule("2026-07-01", "2026-08-31")
	_check(batches.size() == 4, "a window has four batches")
	if batches.size() == 4:
		_check(str(batches[0]["name"]) == "opening" and str(batches[3]["name"]) == "last_day",
			"the batch names are the prototype's")
		_check(str(batches[0]["date"]) == "2026-07-01"
			and str(batches[3]["date"]) == "2026-08-31", "the batches sit on their dates")
		_check(str(batches[0]["period_start"]) == "2026-07-01"
			and str(batches[3]["period_start"]) == "2026-08-31", "periods start on the trigger")
		var ordered := true
		for index in range(1, batches.size()):
			if str(batches[index - 1]["period_end"]) >= str(batches[index]["period_start"]):
				ordered = false
		_check(ordered, "the batch periods do not overlap")
	_check(CareerWorldMarket.batches_between("2026-06-30", "2026-06-30").is_empty(),
		"the same day has no batch")
	var opening := CareerWorldMarket.batches_between("2026-06-30", "2026-07-01")
	_check(opening.size() == 1 and str(opening[0]["name"]) == "opening",
		"the window opening is one batch")
	var middle := CareerWorldMarket.batches_between("2026-07-01", "2026-08-01")
	_check(middle.size() == 1 and str(middle[0]["name"]) == "middle",
		"the middle batch triggers on the halved window")
	_check(CareerWorldMarket.batches_between("2026-09-01", "2026-12-31").is_empty(),
		"no batches outside the windows")

	# Aggregate helpers.
	var squad: Array = (CareerWorldMarket.squads(catalog) as Dictionary).get("131", [])
	_check(not squad.is_empty(), "the club squads are grouped from one table walk")
	var value := CareerWorldMarket.club_value(squad)
	_check(CareerWorldMarket.club_budget(squad) == int(float(value) * 0.10),
		"the budget is ten percent of the squad value")
	var counts := CareerWorldMarket.role_counts(squad)
	var total := 0
	for role in counts:
		total += int(counts[role])
	_check(total == squad.size(), "role counts cover the squad")
	_check((CareerWorldMarket.clubs(catalog) as Array).size() == 4406,
		"the club list holds every real club (national teams excluded)")

	var header: Dictionary = golden["career"]
	var career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	career.data["created_at"] = str(header["created_at"])
	career.data["date"] = str(header["date"])
	career.world_market_date = "2026-06-30"
	career.incoming_market_date = str(header["date"])
	var own_player_ids := career.player_ids.duplicate()

	var events := CareerWorldMarket.process_days(career, catalog, "2026-06-30", "2026-08-31")
	_check(events.size() == int(golden["recorded"]),
		"the window records the prototype's deals")
	_check(career.world_transfers.size() == int(golden["count"]),
		"the transfer history has the prototype's length")
	_check(str(career.world_market_date) == str(golden["world_market_date"]),
		"the world marker moves to the target day")

	var kinds := {}
	for transfer in career.world_transfers:
		var kind := str(transfer.get("kind", ""))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	_check(_same(kinds, golden["kinds"]), "the transfer kinds match")

	var per_batch := {}
	for batch in CareerWorldMarket.batch_schedule("2026-07-01", "2026-08-31"):
		var count := 0
		for transfer in career.world_transfers:
			var day := str(transfer.get("date", ""))
			if str(batch["period_start"]) <= day and day <= str(batch["period_end"]):
				count += 1
		per_batch[str(batch["name"])] = count
	_check(_same(per_batch, golden["dates"]), "every deal lands in its batch period")

	var expected: Array = golden["transfers"]
	var compared := mini(expected.size(), career.world_transfers.size())
	for index in range(compared):
		_compare_transfer("transfer %d" % index, career.world_transfers[index], expected[index])
	var tail: Array = golden["tail"]
	for index in range(tail.size()):
		var actual: Dictionary = career.world_transfers[
			career.world_transfers.size() - tail.size() + index]
		_compare_transfer("tail %d" % index, actual, tail[index])
	var ids := {}
	for transfer in career.world_transfers:
		ids[str(transfer.get("id", ""))] = true
	_check(ids.size() == career.world_transfers.size(), "the transfer ids are unique")

	var deltas: Dictionary = golden["deltas"]
	for club_id in deltas:
		var actual_delta: Dictionary = career.club_deltas.get(club_id, {})
		var expected_delta: Dictionary = deltas[club_id]
		_check(_same((actual_delta.get("in", []) as Array).slice(0, 10), expected_delta["in"]),
			"club %s delta in" % club_id)
		_check(_same((actual_delta.get("out", []) as Array).slice(0, 10),
			expected_delta["out"]), "club %s delta out" % club_id)
		_check((actual_delta.get("in", []) as Array).size() == int(expected_delta["in_count"]),
			"club %s delta in count" % club_id)
		_check((actual_delta.get("out", []) as Array).size() == int(expected_delta["out_count"]),
			"club %s delta out count" % club_id)

	# The owned squad is untouched and the deltas shape an effective squad.
	for player_id in own_player_ids:
		_check(str(CareerWorldMarket.current_club_id(career, player_id, ""))
			== str(career.club_id), "own players stay at the club")
		_check(not (career.club_deltas.get(str(career.club_id), {}) as Dictionary)
			.get("out", []).has(player_id), "own players are never sold")
	var lookup := func(player_ids: Array) -> Array:
		var players: Array = []
		for player_id in player_ids:
			players.append(CareerWorldMarket.player_by_id(catalog, player_id))
		return players
	var sample_club := str((deltas.keys() as Array)[0])
	var base: Array = (CareerWorldMarket.squads(catalog) as Dictionary).get(sample_club, [])
	var effective := CareerWorldMarket.effective_players(career, sample_club, base, lookup)
	var effective_ids := {}
	for player in effective:
		effective_ids[str(player.get("id", ""))] = true
	var outgoing: Array = (career.club_deltas.get(sample_club, {}) as Dictionary).get("out", [])
	for player_id in outgoing.slice(0, 5):
		_check(not effective_ids.has(str(player_id)), "a sold player leaves the effective squad")
	var incoming: Array = (career.club_deltas.get(sample_club, {}) as Dictionary).get("in", [])
	for player_id in incoming:
		_check(effective_ids.has(str(player_id)), "a bought player joins the effective squad")

	# A repeated run over the same window changes nothing.
	var repeat := CareerWorldMarket.process_days(career, catalog, career.world_market_date,
		career.date)
	_check(repeat.is_empty() and career.world_transfers.size() == int(golden["count"]),
		"a repeated tick does not repeat the window")
	for event in events:
		_check(str(event.get("type", "")) == "world.transfer"
			and not str(event.get("message", "")).is_empty(),
			"the world events are hub notices")
	_finish()
