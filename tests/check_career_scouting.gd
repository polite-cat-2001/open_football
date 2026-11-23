extends SceneTree
# Headless golden check for the career scouting port (ticket 09): the scout
# pool and hiring, player reports, region networks and their dated tick, the
# report feed actions and old-save lazy init. The fixture comes from the
# prototype app (tmp/oracle_scouting.py).
#
# Run:  godot --headless --path . -s res://tests/check_career_scouting.gd

const GOLDEN := "res://tests/fixtures/career_scouting_golden.json"

# The prototype names its regions in Russian; the port ships the English
# labels, so the fixture's names are mapped here instead of compared raw.
const REGION_NAMES := {
	"british-isles": "British Isles",
	"north-europe": "Northern Europe",
	"west-europe": "Western Europe",
	"south-europe": "Southern Europe",
	"east-europe": "Eastern Europe",
	"north-america": "North America",
	"latin-america": "Latin America",
	"africa": "Africa",
	"asia-pacific": "Asia and Oceania",
}

const SCOUT_SKIP := ["region_name"]

var failures: Array[String] = []
var golden: Dictionary = {}
var catalog: TeamCatalog
var header: Dictionary = {}
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
	print("== check_career_scouting: ", "PASS" if failures.is_empty() else "FAIL",
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


func _compare(label: String, actual, expected, skip: Array = []) -> void:
	if regen:
		if expected is Array and actual is Array:
			(expected as Array).clear()
			(expected as Array).append_array(actual)
		elif expected is Dictionary and actual is Dictionary:
			for key in actual:
				expected[key] = actual[key]
		return
	if expected is Array:
		var arrays_ok := _same(actual, expected)
		_check(arrays_ok, label)
		if not arrays_ok:
			print("    expected: ", expected, " actual: ", actual)
		return
	if not (expected is Dictionary) or not (actual is Dictionary):
		_check(_same(actual, expected), label)
		return
	for key in expected:
		if skip.has(key):
			continue
		var ok := _same(actual.get(key), expected[key])
		_check(ok, "%s: %s" % [label, key])
		if not ok:
			print("    expected: ", expected[key], " actual: ", actual.get(key))


func _run() -> void:
	catalog = TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(parsed is Dictionary, "the scouting golden loads")
	if not (parsed is Dictionary):
		_finish()
		return
	golden = parsed
	header = golden["initial"]["career"]
	_scenario_initial()
	_scenario_hire()
	_scenario_report()
	_scenario_network()
	_scenario_old_save()
	if regen:
		var fh := FileAccess.open(GOLDEN, FileAccess.WRITE)
		fh.store_string(JSON.stringify(golden, " ", false))
		fh.close()
	_finish()


func _career() -> Career:
	var career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		return null
	career.data["created_at"] = str(header["created_at"])
	career.data["date"] = str(header["date"])
	_check(career.balance == int(header["balance"]),
		"the starting balance matches the prototype")
	return career


func _advance(career: Career, days: int) -> Array:
	var from := career.date
	var to := CareerSearch.add_days(from, days)
	career.data["date"] = to
	return CareerScouting.process_days(career, catalog, from, to)


func _snapshot(career: Career) -> Dictionary:
	return CareerScouting.snapshot(career, catalog)


func _compare_scouts(label: String, scouts: Array, expected: Array) -> void:
	if regen:
		(expected as Array).clear()
		(expected as Array).append_array(scouts)
		return
	_check(scouts.size() == expected.size(), "%s: %d scouts" % [label, expected.size()])
	for index in range(mini(scouts.size(), expected.size())):
		var keys := ["id", "name", "nationality", "nationality_id", "experience",
			"judgement", "price"]
		for key in keys:
			_check(_same(scouts[index].get(key), expected[index].get(key)),
				"%s scout %d: %s" % [label, index, key])
		_compare_task("%s scout %d task" % [label, index], scouts[index].get("task"),
			expected[index].get("task"))
		if expected[index].get("report") == null:
			_check(scouts[index].get("report") == null, "%s scout %d: no report" % [label, index])
		else:
			_compare("%s scout %d report" % [label, index], scouts[index]["report"],
				expected[index]["report"], ["player_photo"])


func _compare_task(label: String, actual, expected) -> void:
	if regen:
		if expected is Dictionary and actual is Dictionary:
			for key in actual:
				expected[key] = actual[key]
		return
	if expected == null:
		_check(actual == null, label + " is empty")
		return
	_check(actual is Dictionary, label + " exists")
	if not (actual is Dictionary):
		return
	_compare(label, actual, expected, SCOUT_SKIP)


func _compare_entries(label: String, entries: Array, expected: Array) -> void:
	if regen:
		var rows: Array = []
		for entry in entries:
			var copy: Dictionary = (entry as Dictionary).duplicate(true)
			if not copy.has("player_id"):
				copy["player_id"] = (copy.get("player", {}) as Dictionary).get("player_id")
			rows.append(copy)
		(expected as Array).clear()
		(expected as Array).append_array(rows)
		return
	_check(entries.size() == expected.size(),
		"%s: %d entries" % [label, expected.size()])
	for index in range(mini(entries.size(), expected.size())):
		var ok := true
		for key in ["kind", "scout_id", "scout_name", "date", "acknowledged"]:
			if not _same(entries[index].get(key), expected[index].get(key)):
				ok = false
				print("    entry %d mismatch on %s: expected %s actual %s" % [
					index, key, str(expected[index].get(key)), str(entries[index].get(key))])
		_check(ok, "%s entry %d header" % [label, index])
		_compare("%s entry %d player" % [label, index], entries[index].get("player", {}),
			expected[index].get("player", {}), ["weekly_wage"])
		_check(_same(entries[index].get("player", {}).get("player_id"),
			expected[index].get("player_id")), "%s entry %d player id" % [label, index])


func _scenario_initial() -> void:
	print("initial")
	var expected: Dictionary = golden["initial"]
	var career := _career()
	if career == null:
		return
	var pool := CareerScouting.scout_pool(career)
	_check(pool.size() == 12, "the pool has twelve scouts")
	for index in range(mini(pool.size(), (expected["pool"] as Array).size())):
		_compare("pool %d" % index, pool[index], expected["pool"][index])
	_check(_same(CareerScouting.scout_pool(career), pool), "the pool is deterministic")

	var block := _snapshot(career)
	var initial: Dictionary = expected["initial"]
	_compare_scouts("initial", block["scouts"], initial["scouts"])
	_check((block["candidates"] as Array).size() == 5, "five candidates are offered")
	for index in range(mini((block["candidates"] as Array).size(),
			(initial["candidates"] as Array).size())):
		_compare("candidate %d" % index, block["candidates"][index], initial["candidates"][index])
	_check(_same(block["counts"].get("new"), 0) and _same(block["counts"].get("updates"), 0)
		and _same(block["counts"].get("total"), 0), "a new career has an empty feed")
	_check(_same(block["counts"].get("scouts"), 2), "the feed counts two scouts")
	_check(_same(block["max_scouts"], 6), "six scout slots")
	_check(_same(block["age_min"], 16) and _same(block["age_max"], 35)
		and _same(block["contract_min"], 0) and _same(block["contract_max"], 5),
		"the task ranges match the prototype")
	for index in range(mini((block["scouts"] as Array).size(),
			(initial["hired_at"] as Array).size())):
		_check(_same(block["scouts"][index].get("hired_at"), initial["hired_at"][index]),
			"scout %d is hired on the career date" % index)
	for scout in block["scouts"]:
		_check(_same(scout.get("free"), true) and _same(scout.get("busy"), false)
			and _same(scout.get("current_task"), ""),
			"%s starts free" % scout["name"])
		_check(not str(scout.get("flag", "")).is_empty(),
			"%s carries a flag key" % scout["name"])
	_check((CareerScouting.assignable_scouts(career) as Array).size() == 2,
		"both starting scouts are assignable")

	var regions: Array = block["regions"]
	_check(regions.size() == (expected["regions"] as Array).size(), "every region is listed")
	var country_names := {}
	for country in catalog.countries():
		country_names[str(country.get("name", ""))] = str(country.get("id", ""))
	for index in range(mini(regions.size(), (expected["regions"] as Array).size())):
		var region: Dictionary = regions[index]
		var prototype: Dictionary = expected["regions"][index]
		_check(_same(region["id"], prototype["id"]), "region %d id" % index)
		_check(_same(region.get("x"), prototype["x"]) and _same(region.get("y"), prototype["y"]),
			"region %d sits on the map" % index)
		_check(str(region.get("name")) == str(REGION_NAMES.get(str(region["id"]), "?")),
			"region %d has the English label" % index)
		var prototype_names: Array = prototype["countries"]
		var ok := true
		for country in region["countries"]:
			if not prototype_names.has(str(country["name"])):
				ok = false
			if str(country_names.get(str(country["name"]), "")) != str(country["id"]):
				ok = false
			if str(country.get("flag", "")) != str(country["name"]):
				ok = false
		_check(ok, "region %d lists real countries of the prototype region" % index)


func _scenario_hire() -> void:
	print("hire")
	var expected: Dictionary = golden["hire"]
	var career := _career()
	if career == null:
		return
	var block := _snapshot(career)
	var candidate: Dictionary = block["candidates"][0]
	var balance_before = career.balance
	var result := CareerScouting.hire(career, candidate["id"])
	_check(bool(result.get("ok", false)), "the first candidate is hired: " + str(result.get("error")))
	_check(_same(career.balance, expected["hire"]["balance_after"]),
		"hiring spends the candidate price")
	_check(_same(balance_before, expected["hire"]["balance_before"]),
		"the balance before hiring matches")
	block = _snapshot(career)
	_compare_scouts("hire", block["scouts"], expected["hire"]["scouts"])
	var candidate_ids: Array = []
	for item in block["candidates"]:
		candidate_ids.append(item["id"])
	_check(_same(candidate_ids, expected["hire"]["candidate_ids"]),
		"the hired scout leaves the candidate list")
	_check(_same(career.journal[-1].get("type"), expected["hire"]["journal_last"]),
		"hiring is journaled")

	var twice := CareerScouting.hire(career, candidate["id"])
	_compare("hire twice", {"status": 200 if twice.get("ok") else 422,
		"error": twice.get("error")}, expected["hire_twice"])

	for index in range(3):
		var next_candidate: Dictionary = _snapshot(career)["candidates"][0]
		var fill := CareerScouting.hire(career, next_candidate["id"])
		_check(bool(fill.get("ok", false)), "slot %d can be filled" % (index + 4))
	var cap := CareerScouting.hire(career, "scout-12")
	_check(not bool(cap.get("ok", true)) and str(cap.get("error")) == str(expected["hire_cap"]["error"]),
		"the seventh hire hits the slot cap")
	var full_ids: Array = []
	for scout in _snapshot(career)["scouts"]:
		full_ids.append(scout["id"])
	_check(_same(full_ids, expected["hire_cap"]["scout_ids"]), "six scouts are employed")

	var dismissed := CareerScouting.dismiss(career, candidate["id"])
	_check(bool(dismissed.get("ok", false)), "the scout can be dismissed")
	block = _snapshot(career)
	var scout_ids: Array = []
	for scout in block["scouts"]:
		scout_ids.append(scout["id"])
	_check(_same(scout_ids, expected["dismiss"]["scout_ids"]), "the slot is free again")
	var back_ids: Array = []
	for item in block["candidates"]:
		back_ids.append(item["id"])
	_check(_same(back_ids, expected["dismiss"]["candidate_ids"]),
		"the dismissed scout returns to the candidates")
	_check(_same(career.journal[-1].get("type"), expected["dismiss"]["journal_last"]),
		"dismissal is journaled")
	var unknown := CareerScouting.dismiss(career, "scout-999")
	_check(not bool(unknown.get("ok", true))
		and str(unknown.get("error")) == str(expected["dismiss_unknown"]["error"]),
		"an unknown scout cannot be dismissed")


func _scenario_report() -> void:
	print("report")
	var expected: Dictionary = golden["report"]
	var career := _career()
	if career == null:
		return
	var block := _snapshot(career)
	var scout: Dictionary = block["scouts"][0]
	var other: Dictionary = block["scouts"][1]
	var player_id := str(expected["report"]["player_id"])
	_check(not bool(CareerSearch.profile(catalog, career, player_id).get("scouted", true)),
		"the target starts hidden")

	var started := CareerScouting.assign(career, catalog, scout["id"], player_id)
	_check(bool(started.get("ok", false)), "the report is assigned: " + str(started.get("error")))
	var view: Dictionary = _snapshot(career)["scouts"][0]["report"]
	_compare("report started", view, expected["report"]["started"], ["player_photo"])
	_check(view.get("days_total") == 6 - int(scout["experience"]),
		"an experienced scout studies faster")
	_check((CareerScouting.assignable_scouts(career) as Array).size() == 1,
		"a studying scout is not assignable")

	var busy := CareerScouting.assign(career, catalog, scout["id"], "418560")
	_compare("assign busy", {"status": 200 if busy.get("ok") else 422, "error": busy.get("error")},
		expected["assign_busy"])
	var shared := CareerScouting.assign(career, catalog, other["id"], player_id)
	_compare("assign shared", {"status": 200 if shared.get("ok") else 422,
		"error": shared.get("error")}, expected["assign_shared"])
	_check(not bool(shared.get("ok", true))
		and str(shared.get("error", "")).contains("already being studied"),
		"no second scout can be sent to a player who is already watched")
	var own := CareerScouting.assign(career, catalog, other["id"], career.player_ids[0])
	_compare("assign own", {"status": 200 if own.get("ok") else 422, "error": own.get("error")},
		expected["assign_own"])
	var unknown := CareerScouting.assign(career, catalog, other["id"], "999999999")
	_compare("assign unknown", {"status": 200 if unknown.get("ok") else 422,
		"error": unknown.get("error")}, expected["assign_unknown"])

	_advance(career, 1)
	_compare("report progress", _snapshot(career)["scouts"][0]["report"],
		expected["report"]["progress"], ["player_photo"])
	_advance(career, int(view["days_total"]) - 1)
	block = _snapshot(career)
	_compare_scouts("report done", [block["scouts"][0]], [expected["report"]["scout_after"]])
	_compare_entries("report", block["reports"], expected["report"]["entries"])
	_compare("report counts", block["counts"], expected["report"]["counts"])
	_check((block["feed"] as Array).size() == 1 and block["feed"][0]["kind"] == "report",
		"the finished report reaches the feed")
	_check(int(block["reports"][0].get("duration", -1)) == 6 - int(scout["experience"]),
		"the report keeps its duration")

	var card := CareerSearch.profile(catalog, career, player_id)
	_check(bool(card.get("scouted", false)), "a completed report reveals the player")
	_compare("report card", card, expected["report"]["card"], ["weekly_wage"])
	_check(bool(expected["report"]["scouted_before"]) == false, "the fixture says it started hidden")
	var journal: Array = []
	for entry in career.journal:
		if str(entry.get("type", "")).begins_with("scouting."):
			journal.append(entry["type"])
	_check(_same(journal, expected["report"]["journal"]), "the report journal matches")
	_check(float(card.get("overall", 0.0)) > 80.0, "the revealed overall is real")


func _scenario_network() -> void:
	print("network")
	var expected: Dictionary = golden["network"]
	var career := _career()
	if career == null:
		return
	var block := _snapshot(career)
	var scout: Dictionary = block["scouts"][1]
	var network = expected["network"]

	var started := CareerScouting.network(career, catalog, scout["id"],
		str(network["region_id"]), str(network["country_id"]))
	_check(bool(started.get("ok", false)), "the network starts: " + str(started.get("error")))
	block = _snapshot(career)
	_compare_task("task start", block["scouts"][1]["task"], network["task_start"])
	_check(_same(block["scouts"][1]["current_task"], "network"), "the scout is on a network")
	_compare("network remembered", block["networks"][0], network["network"], SCOUT_SKIP)
	_check((block["tasks"] as Array).size() == 1, "the task tab lists the task")
	_check((CareerScouting.assignable_scouts(career) as Array).size() == 1,
		"a scouting scout is not free")

	var bad_region := CareerScouting.network(career, catalog, scout["id"], "nowhere",
		str(network["country_id"]))
	_compare("bad region", {"status": 200 if bad_region.get("ok") else 422,
		"error": bad_region.get("error")}, expected["bad_region"])
	var bad_country := CareerScouting.network(career, catalog, scout["id"],
		str(network["region_id"]), "189")
	_compare("bad country", {"status": 200 if bad_country.get("ok") else 422,
		"error": bad_country.get("error")}, expected["bad_country"])

	_advance(career, 1)
	block = _snapshot(career)
	var after_one: Dictionary = network["after_one"]
	_compare_task("after one day", block["scouts"][1]["task"], after_one["task"])
	_compare("found after one day", block["found"], after_one["found"])
	_compare_entries("recommendations", block["recommendations"], after_one["entries"])
	_check(_same(block["counts"]["new"], after_one["counts"]["new"]),
		"the recommendations are new")
	var first_found: Array = block["found"].duplicate()

	var again := CareerScouting.process_days(career, catalog,
		CareerSearch.add_days(career.date, -1), career.date)
	_check(again.is_empty(), "a repeated tick for the same date is a no-op")
	_check(_same(_snapshot(career)["found"], first_found),
		"the repeated tick finds nobody new")

	var edited := CareerScouting.set_task(career, scout["id"],
		{"role": "GK", "age_min": 20, "age_max": 30})
	_check(bool(edited.get("ok", false)), "the task criteria can be edited")
	_compare_task("task edit", _snapshot(career)["scouts"][1]["task"], network["task_edit"])
	var reset := CareerScouting.set_task(career, scout["id"],
		{"role": "", "age_min": null, "age_max": null})
	_check(bool(reset.get("ok", false)), "the task criteria can be reset")
	_compare_task("task reset", _snapshot(career)["scouts"][1]["task"], network["task_reset"])

	_advance(career, 3)
	block = _snapshot(career)
	var after_more: Dictionary = network["after_more"]
	_compare_task("after four days", block["scouts"][1]["task"], after_more["task"])
	_compare("found after four days", block["found"], after_more["found"])
	_check(_same(block["counts"]["found"], (after_more["found"] as Array).size()),
		"the found count matches")

	var study_id := str(expected["coexist"]["player_id"])
	var study := CareerScouting.assign(career, catalog, scout["id"], study_id)
	_check(bool(study.get("ok", false)), "a report runs beside the network")
	block = _snapshot(career)
	_compare("coexist report", block["scouts"][1]["report"], expected["coexist"]["report"],
		["player_photo"])
	_check(block["scouts"][1]["task"] != null, "the network task survives the report")
	_check(_same(block["scouts"][1]["current_task"], "report"),
		"the report is the scout's current task")
	var report_row := CareerScouting.report_for(career, study_id)
	_check(str(report_row.get("kind")) == "studying" and int(report_row.get("days_left", -1)) > 0,
		"report_for follows a running study")
	_check(CareerScouting.report_for(career, str(network["after_one"]["found"][0]))
		.get("kind") == "recommendation", "report_for finds a recommendation")

	var player_id := str(network["after_one"]["found"][0])
	CareerScouting.ack(career)
	block = _snapshot(career)
	_compare("ack counts", block["counts"], expected["ack"]["counts"])
	_compare_entries("ack entries", block["recommendations"], expected["ack"]["entries"])

	var removed := CareerScouting.remove(career, player_id)
	_check(bool(removed.get("ok", false)), "a recommendation can be removed")
	block = _snapshot(career)
	var remaining: Array = []
	for entry in block["recommendations"]:
		remaining.append(entry["player"]["player_id"])
	if regen:
		expected["remove"]["candidate_ids"] = remaining
	_check(_same(remaining, expected["remove"]["candidate_ids"]),
		"the removed player leaves the list newest first")
	_compare_task("task after remove", block["scouts"][1]["task"], expected["remove"]["task"])
	var counts_now := {}
	for key in expected["remove"]["counts"]:
		counts_now[key] = block["counts"].get(key)
	_check(_same(counts_now, expected["remove"]["counts"]),
		"the counts drop the removed player")
	_check(_same(career.journal[-1].get("type"), expected["remove"]["journal_last"]),
		"removal is journaled")
	_check(_same(CareerSearch.profile(catalog, career, player_id).get("scouted"),
		expected["remove"]["scouted"]), "a removed player is hidden again")
	var remove_again := CareerScouting.remove(career, player_id)
	_compare("remove again", {"status": 200 if remove_again.get("ok") else 422,
		"error": remove_again.get("error")}, expected["remove_again"])
	var remove_studying := CareerScouting.remove(career, study_id)
	_compare("remove studying", {"status": 200 if remove_studying.get("ok") else 422,
		"error": remove_studying.get("error")}, expected["remove_studying"])

	var recalled := CareerScouting.recall(career, scout["id"])
	_check(bool(recalled.get("ok", false)), "the scout can be recalled")
	block = _snapshot(career)
	_check(block["scouts"][1]["task"] == null, "recall drops the network task")
	_check(block["scouts"][1]["report"] == null, "recall drops the running report")
	_check(_same(career.journal[-1].get("type"), expected["recall"]["journal_last"]),
		"recall is journaled")
	_check((block["found"] as Array).size() > 0, "recall keeps the found players")
	var recall_again := CareerScouting.recall(career, scout["id"])
	_compare("recall again", {"status": 200 if recall_again.get("ok") else 422,
		"error": recall_again.get("error")}, expected["recall_again"])


func _scenario_old_save() -> void:
	print("old save")
	var expected: Dictionary = golden["old_save"]
	var career := _career()
	if career == null:
		return
	for key in ["scouts", "scout_assignments", "scout_tasks", "scout_reports",
			"scout_found", "scout_networks"]:
		career.data.erase(key)
	var block := _snapshot(career)
	var old_save: Dictionary = expected["old_save"]
	_compare_scouts("old save", block["scouts"], old_save["scouts"])
	var hired_at: Array = []
	for scout in block["scouts"]:
		hired_at.append(scout.get("hired_at"))
	_check(_same(hired_at, old_save["hired_at"]), "the lazy scouts are hired on the save date")
	var candidate_ids: Array = []
	for item in block["candidates"]:
		candidate_ids.append(item["id"])
	_check(_same(candidate_ids, old_save["candidate_ids"]),
		"the lazy save offers the same candidates")

	# the scouting keys survive a JSON round trip (ints come back as floats)
	var scout_id := str(block["scouts"][0]["id"])
	CareerScouting.network(career, catalog, scout_id, "british-isles", "189")
	CareerScouting.assign(career, catalog, scout_id, str(golden["report"]["report"]["player_id"]))
	var before := _snapshot(career)
	var reloaded := Career.from_save(JSON.parse_string(JSON.stringify(career.to_save())))
	_check(reloaded != null, "the career save round-trips: " + Career.last_error)
	if reloaded == null:
		return
	var after := _snapshot(reloaded)
	_check((after["scouts"] as Array).size() == (before["scouts"] as Array).size(),
		"the reloaded save keeps its scouts")
	_check(_same(after["scouts"][0]["task"]["criteria"], before["scouts"][0]["task"]["criteria"]),
		"the reloaded save keeps the task criteria")
	_check(str(after["scouts"][0]["report"]["player_id"])
		== str(before["scouts"][0]["report"]["player_id"]),
		"the reloaded save keeps the running report")

	# normalize_criteria follows the prototype's clamps and swaps
	var criteria := CareerScouting.normalize_criteria(
		{"role": "gk", "age_min": 40, "age_max": 10, "contract_min": "x"})
	_check(str(criteria["role"]) == "GK", "the role is normalised")
	_check(criteria["age_min"] == 16 and criteria["age_max"] == 35,
		"the age range is clamped and swapped")
	_check(criteria["contract_min"] == null, "a non-numeric bound is dropped")
	_check(CareerScouting.normalize_criteria({"role": "striker"})["role"] == "",
		"an unknown role group is dropped")
	_check(CareerScouting.report_days(1) == 5 and CareerScouting.report_days(9) == 1,
		"report days are clamped to 1..5")
