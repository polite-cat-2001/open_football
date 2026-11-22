extends SceneTree
# Headless golden check for transfer contract talks (ticket 07): the player's
# demand, counter rounds, signing inside the window, a free agent, and a
# transfer that waits for the next window before it is executed.
# The fixture comes from the prototype app (tmp/oracle_transfers.py).
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_contracts.gd

const GOLDEN := "res://tests/fixtures/career_transfer_contracts_golden.json"

var failures: Array[String] = []
var regen := OS.get_environment("REGEN") == "1"


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	print("== check_career_transfer_contracts: ", "PASS" if failures.is_empty() else "FAIL",
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
	if regen:
		for key in expected:
			if not skip.has(key):
				expected[key] = actual.get(key)
		return
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


func _pending_items(career: Career) -> Array:
	var items: Array = []
	for item in career.pending_transfers:
		var row := {}
		for key in ["player_id", "from_club_id", "offer_id", "kind", "fee", "loan_fee",
				"wage_share", "terms", "market_value", "age", "agreed_at", "execute_on"]:
			row[key] = item.get(key)
		items.append(row)
	return items


func _digest(career: Career, player_id: String) -> Dictionary:
	var history_last = null
	if not (career.transfer_history as Array).is_empty():
		var record: Dictionary = (career.transfer_history as Array)[-1]
		history_last = {}
		for key in ["player_id", "overall", "from_club_id", "to_club_id", "fee", "kind",
				"offer_id", "date", "status"]:
			history_last[key] = record.get(key)
	var offers: Array = []
	for offer in career.transfer_offers:
		offers.append({
			"offer_id": str(offer.get("id", "")),
			"status": offer.get("status"),
			"signed": bool(offer.get("signed", false)),
			"execute_on": offer.get("execute_on"),
			"contract_status": offer.get("contract_status"),
		})
	var journal_last := ""
	var journal_payload := {}
	if not (career.journal as Array).is_empty():
		var entry: Dictionary = (career.journal as Array)[-1]
		journal_last = str(entry.get("type", ""))
		journal_payload = entry.get("payload", {})
	return {
		"balance": career.balance,
		"squad_size": (career.player_ids as Array).size(),
		"joined": (career.player_ids as Array).has(player_id),
		"contract": career.player_contracts.get(player_id),
		"history_last": history_last,
		"pending": _pending_items(career),
		"offers": offers,
		"journal_last": journal_last,
		"journal_payload": journal_payload,
	}


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the contracts golden loads")
	if not (golden is Dictionary):
		_finish()
		return
	var header: Dictionary = golden["career"]
	var players: Dictionary = golden["players"]
	var steps: Dictionary = golden["steps"]
	var target := str(players["target"])
	var career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	career.data["created_at"] = str(header["created_at"])
	career.data["date"] = str(header["date"])

	# Window helpers.
	_check(CareerTransferContracts.window_open("2026-07-01"), "July is inside a window")
	_check(CareerTransferContracts.window_open("2026-08-31"), "August is inside a window")
	_check(CareerTransferContracts.window_open("2027-01-15"), "January is inside a window")
	_check(not CareerTransferContracts.window_open("2026-09-15"), "September is outside")
	_check(CareerTransferContracts.execution_date("2026-09-15") == "2027-01-01",
		"an out-of-window signing executes in January")
	_check(CareerTransferContracts.next_window("2026-03-01") == "2026-07-01",
		"the next window before June is July")

	var transfer: Dictionary = steps["transfer"]
	var sign_log := _negotiate(career, catalog, target, transfer)
	_compare("contract_defaults", sign_log["defaults"], transfer["contract_defaults"])
	_compare("contract_pending", sign_log["pending"], transfer["contract_pending"])
	_compare("contract_response", sign_log["response"], transfer["contract_response"])
	_compare("contract_accepted", sign_log["accepted"], transfer["contract_accepted"])
	_compare("transfer digest", _digest(career, target), transfer["digest"])
	_check(_same(sign_log["item"].get("terms"),
		(transfer["digest"]["journal_payload"] as Dictionary)["contract"]),
		"the signed contract is the agreed one")
	_check(sign_log["item"].get("fee") == int(transfer["digest"]["journal_payload"]["fee"]),
		"the signed fee is the agreed fee")
	_check(not bool(CareerTransferContracts.sign(career, catalog, target).get("ok", true)),
		"a signed transfer cannot be signed twice")
	_check(CareerTransferContracts.pending(career).is_empty(),
		"an in-window signing joins the squad immediately")
	var target_home := int(_player(catalog, target).get("team_id", 0))
	_check(_roster_has(career, catalog, int(career.club_id), target),
		"the signed player appears in the career roster")
	_check(target_home > 0 and not _roster_has(career, catalog, target_home, target),
		"the selling club no longer lists him")
	# The sign() door applies the same wage fund as a renewal.
	var wage_career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	wage_career.balance = 0
	wage_career.transfer_contracts = {target: {
		"player_id": target, "value": 1000, "status": "accepted", "fee": 0,
		"kind": "free",
		"agreed": {"years": 2, "weekly_wage": 2000000, "squad_role": "rotation",
			"release_clause": 0},
	}}
	var wage_refused := CareerTransferContracts.sign(wage_career, catalog, target)
	_check(str(wage_refused.get("error", ""))
		== "not enough money to fit this wage into the wage fund",
		"a signing whose wage overflows the fund is refused")
	_check(_sorted_ids(career.player_ids) == _roster_ids(career, catalog),
		"player_ids and the roster list the same squad after a signing")
	# A loan is judged by its shared wage, not the player's full wage.
	var loan_career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	var bill := 0
	for player_id in loan_career.player_ids:
		var contract = loan_career.player_contracts.get(str(player_id))
		if contract is Dictionary:
			bill += int(contract.get("weekly_wage", 0))
	loan_career.balance = (bill + 50000) * CareerSquad.WAGE_COVER_WEEKS
	loan_career.transfer_contracts = {target: {
		"player_id": target, "value": 1000, "status": "accepted", "fee": 0,
		"kind": "loan", "wage_share": 50,
		"agreed": {"years": 2, "weekly_wage": 100000, "squad_role": "rotation",
			"release_clause": 0},
	}}
	var loan_signed := CareerTransferContracts.sign(loan_career, catalog, target)
	_check(bool(loan_signed.get("ok", false)),
		"a loan fits when its shared wage fits: " + str(loan_signed.get("error", "")))
	_check(int((loan_career.player_contracts.get(target) as Dictionary)
		.get("weekly_wage", 0)) == 50000, "the loan stores the shared wage")

	# A free agent is signed without a fee and without an offer.
	var free_agent := str(players["free_agent"])
	career.data["date"] = "2026-08-01"
	var free_defaults := CareerTransferContracts.contract_defaults(catalog, career, _player(catalog, free_agent))
	var free: Dictionary = steps["free_agent"]
	_compare("free agent defaults", free_defaults, free["contract_defaults"])
	var invalid := CareerTransferContracts.open(career, catalog, free_agent,
		{"years": 9, "weekly_wage": 5000, "squad_role": "rotation", "release_clause": 0})
	_check(str(invalid.get("error", "")) == "contract length must be between 1 and 5 years",
		"the contract length is validated")
	var free_open := CareerTransferContracts.open(career, catalog, free_agent, free_defaults)
	_check(bool(free_open.get("ok", false)), "a free agent can be approached")
	_compare("free contract_pending", free_open.get("state", {}), free["contract_pending"])
	career.data["date"] = str(free["contract_pending"]["due"])
	CareerTransferContracts.process_due(career, catalog, career.date)
	var free_state := CareerTransferContracts.state(career, catalog, free_agent)
	_compare("free contract_response", free_state, free["contract_response"])
	if str(free_state.get("status", "")) == "counter":
		_check(bool(CareerTransferContracts.accept_counter(career, catalog, free_agent)
			.get("ok", false)), "the free agent counter can be accepted")
		_compare("free contract_accepted", CareerTransferContracts.state(career, catalog,
			free_agent), free["contract_accepted"])
	var free_signed := CareerTransferContracts.sign(career, catalog, free_agent)
	_check(bool(free_signed.get("ok", false)), "the free agent can be signed")
	_compare("free agent digest", _digest(career, free_agent), free["digest"])

	# Outside the window the signing waits for the next one.
	var pending_player := str(players["pending"])
	career.data["date"] = "2026-09-15"
	var pending: Dictionary = steps["pending"]
	var pending_log := _negotiate(career, catalog, pending_player, pending)
	_compare("pending contract_response", pending_log["response"], pending["contract_response"])
	_compare("pending digest", _digest(career, pending_player), pending["digest"])
	_check(pending_log["item"].get("executed_at") == null,
		"an out-of-window signing is not executed yet")
	_check(str(pending_log["item"].get("execute_on", "")) == "2027-01-01",
		"it is scheduled for the January window")

	career.data["date"] = "2027-01-02"
	var executed := CareerTransferContracts.execute_pending(career, catalog, career.date)
	_check(executed.size() == 1, "one pending transfer executes")
	_check(str(executed[0].get("type", "")) == "transfer.completed",
		"the execution is reported as an event")
	_compare("executed digest", _digest(career, pending_player), steps["executed"])
	_check(CareerTransferContracts.execute_pending(career, catalog, career.date).is_empty(),
		"the pending list is drained")

	# Errors keep the prototype's wording.
	var own := str(career.player_ids[0])
	var own_open := CareerTransferContracts.open(career, catalog, own,
		CareerTransferContracts.contract_defaults(catalog, career, _player(catalog, own)))
	_check(str(own_open.get("error", "")) == "the player is already in your squad",
		"own players cannot be re-signed through transfers")
	var blocked := CareerTransferContracts.open(career, catalog, target, {})
	_check(str(blocked.get("error", "")) == "the player is already in your squad",
		"a signed player is in the squad now")
	var expensive := _non_expiring(catalog, career)
	if not expensive.is_empty():
		var refused := CareerTransferContracts.open(career, catalog, expensive, {})
		_check(str(refused.get("error", "")) ==
			"contract talks are only available for free agents or expiring contracts",
			"a player under a long contract cannot discuss terms")

	# The whole transfer state has to survive the save round-trip, and a save
	# from before the transfer tickets has to keep loading.
	var directory := "user://career_transfer_contracts_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = directory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var store := CareerSaveStore.new(directory)
	_check(store.save(career), "the career saves: " + store.last_error)
	var reloaded := CareerSaveStore.new(directory).load_career(career.id)
	_check(reloaded != null, "the saved career loads again")
	if reloaded != null:
		_check(_same(reloaded.to_save(), career.to_save()), "the transfer state round-trips")
		_check(_same(_digest(reloaded, pending_player), _digest(career, pending_player)),
			"the reloaded career has the same transfers")
	var stripped: Dictionary = career.to_save()
	for key in ["transfer_offers", "transfer_contracts", "pending_transfers",
			"transfer_history", "shortlist", "pending_departures", "incoming_offers",
			"world_transfers", "club_deltas", "incoming_market_date", "world_market_date"]:
		stripped.erase(key)
	var old_save := Career.from_save(stripped)
	_check(old_save != null, "a save without transfer keys still loads")
	if old_save != null:
		# A read model must not write the missing keys back into the save.
		var untouched := old_save.data.duplicate(true)
		CareerTransfers.history_rows(old_save, catalog)
		_check(_same(old_save.data, untouched),
			"reading the history feed leaves the save alone")
		_check((old_save.transfer_offers as Array).is_empty()
			and (old_save.transfer_history as Array).is_empty()
			and (old_save.shortlist as Array).is_empty()
			and (old_save.transfer_contracts as Dictionary).is_empty()
			and (old_save.club_deltas as Dictionary).is_empty(),
			"the missing transfer keys read as empty")
		_check(old_save.balance == career.balance, "the rest of the save is untouched")
	CareerSaveStore.root_override = ""
	if regen:
		var fh := FileAccess.open(GOLDEN, FileAccess.WRITE)
		fh.store_string(JSON.stringify(golden, " ", false))
		fh.close()
	_finish()


func _negotiate(career: Career, catalog: TeamCatalog, player_id: String,
		expected: Dictionary) -> Dictionary:
	# Offer the club the fee it asked for, then negotiate the personal terms.
	var demand_fee := int((expected["demand"] as Dictionary)["fee"])
	var offered := CareerTransferOffers.submit(career, catalog, player_id, "transfer",
		demand_fee)
	_check(bool(offered.get("ok", false)), "%s: the offer is sent" % player_id)
	var offer_id := str((offered.get("offer", {}) as Dictionary).get("offer_id", ""))
	career.data["date"] = str(expected["accepted_offer"]["due"])
	CareerTransferOffers.process_due(career, catalog, career.date)
	_compare("%s accepted_offer" % player_id, _offer_view(career, offer_id),
		expected["accepted_offer"])
	var defaults := CareerTransferContracts.contract_defaults(catalog, career,
		_player(catalog, player_id))
	var opened := CareerTransferContracts.open(career, catalog, player_id, defaults, offer_id)
	_check(bool(opened.get("ok", false)), "%s: contract talks start" % player_id)
	career.data["date"] = str(expected["contract_pending"]["due"])
	CareerTransferContracts.process_due(career, catalog, career.date)
	var response := CareerTransferContracts.state(career, catalog, player_id)
	var accepted := response
	if str(response.get("status", "")) == "counter":
		_check(bool(CareerTransferContracts.accept_counter(career, catalog, player_id)
			.get("ok", false)), "%s: the counter can be accepted" % player_id)
		accepted = CareerTransferContracts.state(career, catalog, player_id)
	var signed := CareerTransferContracts.sign(career, catalog, player_id)
	_check(bool(signed.get("ok", false)), "%s: the contract is signed" % player_id)
	return {
		"defaults": defaults,
		"pending": opened.get("state", {}),
		"response": response,
		"accepted": accepted,
		"item": signed.get("item", {}),
	}


func _player(catalog: TeamCatalog, player_id: String) -> Dictionary:
	return catalog.career_player(int(player_id), false)


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


func _non_expiring(catalog: TeamCatalog, career: Career) -> String:
	# The first player on the list whose contract runs past the free-agent
	# window: talks must be refused for him.
	var rows := CareerSearch.search(catalog, career,
		{"sort": "overall", "direction": "desc"}, 20, 0)
	for item in rows.get("items", []):
		if bool(item.get("scouted", false)):
			continue
		if str(item.get("status", "")) == "contracted" \
				and CareerSearch.date_diff_days(career.date,
					str(item.get("contract_expires", career.date))) > 200:
			return str(item.get("player_id", ""))
	return ""
