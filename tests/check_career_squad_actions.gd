extends SceneTree
# Headless golden check for the ticket-06 squad actions: contract renewal
# (demand, offer, two counters, refusal, signing, the wage-fund rule), shirt
# number occupancy and the eleven-player release floor.
# Fixtures come from the prototype app (tmp/oracle_career_l2.py).
#
# Run:  godot --headless --path . -s res://tests/check_career_squad_actions.gd

const GOLDEN := "res://tests/fixtures/career_squad_actions_golden.json"

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
	print("== check_career_squad_actions: ", "PASS" if failures.is_empty() else "FAIL",
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


func _compare(label: String, actual, expected) -> void:
	for key in expected:
		var ok := _same(actual.get(key), expected[key])
		_check(ok, "%s: %s" % [label, key])
		if not ok:
			print("    expected: ", expected[key], " actual: ", actual.get(key))


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
	_check(golden is Dictionary, "the squad-actions golden loads")
	if not (golden is Dictionary):
		_finish()
		return
	var career := _career(catalog, golden["career"])
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var player_id := str(golden["player_id"])
	_check(_same(career.player_contracts[player_id], golden["contract"]),
		"the starting contract matches the prototype")
	_check(int(career.balance) == int(golden["balance"]), "the starting balance matches")
	var player := catalog.career_player(int(player_id), false)
	_check(_same(CareerSquadActions.demand(catalog, career, player), golden["demand"]),
		"the renewal demand matches the prototype")

	var state := CareerSquadActions.negotiation_state(career, catalog, player_id)
	_check(_same(state["contract"]["years"], golden["contract"]["years"])
		and _same(state["contract"]["weekly_wage"], golden["contract"]["weekly_wage"])
		and _same(state["contract"]["release_clause"],
		golden["contract"]["release_clause"]), "the state carries the contract")
	_check(str(state.get("error", "")) == "", "the state has no error")
	_check(bool(state.get("can_submit", false)), "a renewal can be offered")
	_check(state.get("unread") == false, "a fresh contract has no unread notice")

	# Two counters and then a refusal for a lowball offer.
	var lowball := {
		"years": 1,
		"weekly_wage": 1000,
		"squad_role": str(golden["contract"]["squad_role"]),
		"release_clause": 0,
	}
	var started := CareerSquadActions.start(career, catalog, player_id, lowball)
	_check(bool(started.get("ok", false)), "the lowball offer is sent: "
		+ str(started.get("error", "")))
	_compare("start", started.get("state", {}), golden["start"])
	_check(str(CareerSquadActions.start(career, catalog, player_id, lowball)
		.get("error", "")) == "the player is still thinking about the current offer",
		"a second offer waits for the answer")
	var current: Dictionary = career.negotiations[player_id]
	for expected in golden["rounds"]:
		_check(CareerSquadActions.process_due(career, catalog,
			CareerSearch.add_days(career.date, -1)).is_empty(),
			"the player is not rushed before the due date")
		career.data["date"] = str(current.get("due", career.date))
		var events := CareerSquadActions.process_due(career, catalog, career.date)
		_check(events.size() == 1, "the answer arrives on the due date")
		if events.size() == 1:
			_check(str(events[0].get("type", ""))
				== "contract.negotiation.%s" % str(current.get("status", "")),
				"the answer is announced as a hub notice")
			_check(str(events[0].get("message", ""))
				== str(expected["message"]), "the answer message matches")
		_compare("round", current, expected)
		var unread := CareerSquadActions.negotiation_state(career, catalog, player_id)
		_check(bool(unread.get("unread", false)) == (not bool(expected["acknowledged"])),
			"the unread badge follows the acknowledgement")
		if str(current.get("status", "")) == "refused":
			break
		_check(bool(CareerSquadActions.ack(career, catalog, player_id).get("ok", false)),
			"the answer can be acknowledged")
		_check(CareerSquadActions.unread_count(career) == 0, "the badge clears")
		var again := CareerSquadActions.start(career, catalog, player_id, lowball)
		_check(bool(again.get("ok", false)), "talks can be reopened after a counter")
		current = career.negotiations[player_id]
	_check(str(career.negotiations[player_id].get("status", "")) == "refused",
		"the player walks away after two counters")

	# A full-demand offer is accepted and signed.
	career.data["date"] = "2026-07-20"
	var demand := CareerSquadActions.demand(catalog, career, player)
	_check(bool(CareerSquadActions.sign(career, catalog, player_id).get("ok", true)) == false,
		"a contract cannot be signed before it is agreed")
	_check(str(CareerSquadActions.sign(career, catalog, player_id).get("error", ""))
		== "the contract is not agreed yet", "the signing error matches the prototype")
	var demand_start := CareerSquadActions.start(career, catalog, player_id, demand)
	_check(bool(demand_start.get("ok", false)), "the demand offer is sent")
	var demand_state: Dictionary = demand_start.get("state", {})
	_check(str(demand_state.get("due", "")) == str(golden["demand_start"]["due"]),
		"the player thinks for 2..4 days")
	career.data["date"] = str(demand_state["due"])
	CareerSquadActions.process_due(career, catalog, career.date)
	var answered := CareerSquadActions.negotiation_state(career, catalog, player_id)
	_compare("demand answer", answered, golden["demand_answer"])
	var signed := CareerSquadActions.sign(career, catalog, player_id)
	_check(bool(signed.get("ok", false)), "the agreed contract can be signed")
	_compare("signed", signed.get("contract", {}), golden["signed"]["contract"])
	_check(career.negotiations.is_empty(), "the talks close after signing")
	_check(str(career.journal[-1].get("type", "")) == str(golden["signed"]["journal_last"]),
		"the signing is journalled")
	var reloaded := Career.from_save(career.to_save())
	_check(_same(reloaded.player_contracts[player_id], golden["saved_contract"]),
		"the contract survives a save round-trip")

	# Accepting a counter signs immediately.
	var counter_player_id := str(career.player_ids[1])
	_check(counter_player_id == str(golden["counter_accepted_player_id"]),
		"the second player is the one the prototype's talks were held with")
	var counter_lowball := {
		"years": 1,
		"weekly_wage": 1000,
		"squad_role": str(career.player_contracts[counter_player_id]["squad_role"]),
		"release_clause": 0,
	}
	CareerSquadActions.start(career, catalog, counter_player_id, counter_lowball)
	career.data["date"] = str(career.negotiations[counter_player_id]["due"])
	CareerSquadActions.process_due(career, catalog, career.date)
	var counter_state := CareerSquadActions.negotiation_state(career, catalog,
		counter_player_id)
	_check(str(counter_state.get("status", "")) == str(golden["counter_accepted"]["status"]),
		"the player counters")
	_compare("counter terms", counter_state.get("counter", {}),
		golden["counter_accepted"]["counter"])
	var accepted := CareerSquadActions.accept_counter(career, catalog, counter_player_id)
	_check(bool(accepted.get("ok", false)), "the counter can be accepted")
	_compare("counter contract", accepted.get("contract", {}),
		golden["counter_accepted"]["contract"])
	_check(career.negotiations.is_empty(), "accepting a counter closes the talks")
	_check(str(career.journal[-1].get("type", ""))
		== str(golden["counter_accepted"]["journal_last"]), "the counter is journalled")

	# Validation errors keep the prototype's wording.
	_check(str(CareerSquadActions.start(career, catalog, player_id,
		{"years": 0, "weekly_wage": 10000, "squad_role": "rotation",
		"release_clause": 0}).get("error", ""))
		== "contract length must be between 1 and 5 years", "a zero-year deal is rejected")
	_check(str(CareerSquadActions.start(career, catalog, player_id,
		{"years": 2, "weekly_wage": 100, "squad_role": "rotation",
		"release_clause": 0}).get("error", "")) == "weekly wage is out of range",
		"a tiny wage is rejected")
	_check(str(CareerSquadActions.start(career, catalog, player_id,
		{"years": 2, "weekly_wage": 10000, "squad_role": "star",
		"release_clause": 0}).get("error", "")) == "unknown squad role",
		"an unknown role is rejected")
	_check(str(CareerSquadActions.start(career, catalog, player_id,
		{"years": 2, "weekly_wage": 10000, "squad_role": "rotation",
		"release_clause": -1}).get("error", "")) == "release clause cannot be negative",
		"a negative clause is rejected")
	_check(str(CareerSquadActions.start(career, catalog, "999999999", lowball).get("error", ""))
		== "player is not in this squad", "only own players can be renewed")

	# Shirt numbers: a free number can be taken, a used one cannot.
	var shirt: Dictionary = golden["shirt"]
	var owner_id := str(shirt["owner_id"])
	var other_id := str(shirt["other_id"])
	var free := int(shirt["free"])
	_check(CareerSquadActions.free_shirt_numbers(career, owner_id).has(free),
		"the fixture's free number is free")
	var assigned := CareerSquadActions.set_shirt_number(career, owner_id, free, catalog)
	_check(bool(assigned.get("ok", false)), "a free shirt number can be taken")
	_check(int(career.shirt_numbers[owner_id]) == free, "the number is stored")
	_check(str(CareerSquadActions.set_shirt_number(career, other_id, free, catalog)
		.get("error", "")) == "shirt number is already taken",
		"a used number cannot be taken")
	_check(str(CareerSquadActions.set_shirt_number(career, other_id, 0, catalog)
		.get("error", "")) == "shirt number must be between 1 and 99",
		"a number below one is rejected")
	_check(str(CareerSquadActions.set_shirt_number(career, other_id, 100, catalog)
		.get("error", "")) == "shirt number must be between 1 and 99",
		"a number above 99 is rejected")
	_check(str(CareerSquadActions.set_shirt_number(career, other_id, null, catalog)
		.get("error", "")) == "shirt number is required", "a missing number is rejected")
	_check(str(career.journal[-1].get("type", "")) == "player.shirt_number",
		"the number change is journalled")
	var rows := CareerSquadActions.shirt_number_rows(career, catalog)
	_check(rows.size() == career.player_ids.size(), "the shirt rows cover the squad")
	_check(_same(rows[0].get("number"), 1), "the rows are sorted by number from one")

	# Release: allowed above eleven players, blocked at eleven.
	var released := CareerSquadActions.release_player(career, catalog, other_id)
	_check(bool(released.get("ok", false)), "a squad player can be released")
	_check(not career.player_ids.has(other_id), "the released player leaves the squad")
	_check(career.player_ids.size() == int(golden["release"]["squad_size"]) - 1,
		"the squad shrinks by one")
	_check(not career.player_contracts.has(other_id) and not career.shirt_numbers.has(other_id),
		"the released player's records are gone")
	_check(not career.lineup.has(other_id) and not career.bench_order.has(other_id),
		"the released player leaves the lineup")
	_check(str(career.journal[-1].get("type", "")) == "player.released",
		"the release is journalled")
	var small := _career(catalog, golden["career"])
	small.data["player_ids"] = (small.player_ids as Array).slice(0, 11)
	var blocked := CareerSquadActions.release_player(small, catalog, str(small.player_ids[0]))
	_check(not bool(blocked.get("ok", true)), "eleven players cannot release another")
	_check(str(blocked.get("error", "")) == "the squad cannot drop below 11 players",
		"the eleven-player error matches the prototype")
	var preview := CareerSquadActions.release_preview(small, catalog,
		str(small.player_ids[0]))
	_check(preview.get("can_release") == false
		and str(preview.get("reason", "")) == "the squad cannot drop below 11 players",
		"the preview explains why the release is blocked")
	_check(CareerSquadActions.release_preview(career, catalog, player_id)
		.get("can_release") == true, "a big squad can release")
	_check(str(CareerSquadActions.release_player(career, catalog, "999999999")
		.get("error", "")) == "player is not in this squad", "unknown players cannot be released")

	# The wage fund rule: no balance, no signing.
	var poor := _career(catalog, golden["career"])
	var poor_id := str(poor.player_ids[0])
	var poor_player := catalog.career_player(int(poor_id), false)
	var poor_lowball := {
		"years": 1,
		"weekly_wage": 1000,
		"squad_role": str(poor.player_contracts[poor_id]["squad_role"]),
		"release_clause": 0,
	}
	CareerSquadActions.start(poor, catalog, poor_id, poor_lowball)
	poor.data["date"] = str(poor.negotiations[poor_id]["due"])
	CareerSquadActions.process_due(poor, catalog, poor.date)
	_check(str(poor.negotiations[poor_id].get("status", "")) == "counter",
		"the poor club still gets a counter")
	poor.balance = 0
	_check(CareerSquadActions.negotiation_state(poor, catalog, poor_id).get("affordable")
		== false, "a counter above the wage fund is not affordable")
	_check(str(CareerSquadActions.accept_counter(poor, catalog, poor_id).get("error", ""))
		== "not enough money to accept these terms", "the wage fund blocks the counter")
	_check(int(golden["affordable"]["demand_weekly"]) == int(
		poor.negotiations[poor_id]["counter"]["weekly_wage"]),
		"the fixture's counter wage is the same renewal")
	_finish()
