extends SceneTree
# Headless check for UEFA berths and the background world table. The synthetic
# league rows keep the allocation rules separate from the career: EPS, the cup
# cascade, and England's second cup as an alternative Conference League route.
# The world table check runs only two top leagues so the test stays fast.
#
# Run:  godot --headless --path . -s res://tests/check_career_berths.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _rows() -> Array:
	var rows: Array = []
	for index in range(1, 21):
		rows.append({"club_id": str(index), "position": index, "points": 60 - index})
	return rows


func _counts(berths: Dictionary) -> Dictionary:
	var counts := {}
	for entry in berths.get("berths", []):
		var key := str(entry.get("competition", ""))
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _clubs(berths: Dictionary, competition: String) -> Array:
	var ids: Array = []
	for entry in berths.get("berths", []):
		if str(entry.get("competition", "")) == competition:
			ids.append(str(entry.get("club_id", "")))
	return ids


func _run() -> void:
	var rows := _rows()
	var spain := CareerBerths.for_country("Spain", rows, {"Copa del Rey": "19"})
	_check(not spain.is_empty(), "Spain has a berth list")
	_check(bool(spain.get("eps", false)), "Spain gets the EPS Champions League place")
	var counts := _counts(spain)
	_check(int(counts.get("CL", 0)) == 5 and int(counts.get("EL", 0)) == 2
		and int(counts.get("UCOL", 0)) == 1,
		"Spain: five Champions League, two Europa, one Conference")
	_check(_clubs(spain, "CL") == ["1", "2", "3", "4", "5"],
		"the Champions League places are the top five")
	_check(_clubs(spain, "EL").has("6") and _clubs(spain, "EL").has("19"),
		"the sixth club and the cup winner enter the Europa League")
	_check(_clubs(spain, "UCOL") == ["7"],
		"the seventh club enters the Conference League")
	var all_ids := {}
	for entry in spain.get("berths", []):
		all_ids[str(entry.get("club_id", ""))] = true
	_check(all_ids.size() == 8, "no club gets two berths")

	var cascade := CareerBerths.for_country("Spain", rows, {"Copa del Rey": "3"})
	_check(_clubs(cascade, "EL") == ["6", "7"],
		"a cup winner already in the Champions League cascades the Europa place")
	_check(_clubs(cascade, "UCOL") == ["8"],
		"the Conference place cascades to the next club")

	var england := CareerBerths.for_country("England", rows,
		{"FA Cup": "19", "EFL Cup": "18"})
	_check(int(_counts(england).get("UCOL", 0)) == 1,
		"England's second cup does not add a berth")
	_check(_clubs(england, "UCOL") == ["18"],
		"the EFL Cup winner takes the Conference place")
	var england_qualified := CareerBerths.for_country("England", rows,
		{"FA Cup": "19", "EFL Cup": "3"})
	_check(_clubs(england_qualified, "UCOL") == ["7"],
		"an already-qualified EFL Cup winner cascades the Conference place")

	var bosnia := CareerBerths.for_country("Bosnia and Herzegovina", rows,
		{"Bosnia and Herzegovina Football Cup": "19"})
	_check(int(_counts(bosnia).get("CL", 0)) == 1
		and int(_counts(bosnia).get("UCOL", 0)) == 3,
		"Bosnia: one Champions League and three Conference places")
	_check(_clubs(bosnia, "UCOL").has("19"),
		"the Bosnian cup winner enters the Conference League")
	var liechtenstein := CareerBerths.for_country("Liechtenstein", [],
		{"Liechtenstein Cup": "7"})
	_check(liechtenstein.get("berths", []).size() == 1
		and _clubs(liechtenstein, "UCOL") == ["7"],
		"Liechtenstein sends only its cup winner to the Conference League")

	var brazil := CareerBerths.for_country("Brazil", rows,
		{"Copa do Brasil": {"winner": "19", "runner_up": "18"}})
	_check(int(_counts(brazil).get("CLI", 0)) == 7,
		"Brazil has seven Libertadores berths")
	_check(int(_counts(brazil).get("CS", 0)) == 6,
		"Brazil has six Sudamericana berths")
	_check(_clubs(brazil, "CLI").has("19"),
		"the Copa do Brasil winner enters the Libertadores")
	_check(not _clubs(brazil, "CS").has("1"),
		"a Libertadores club is not repeated in the Sudamericana")
	var egypt := CareerBerths.for_country("Egypt", rows,
		{"Egypt Cup": {"winner": "19", "runner_up": "18"}})
	_check(int(_counts(egypt).get("champions_league", 0)) == 2
		and int(_counts(egypt).get("confederation_cup", 0)) == 2,
		"Egypt has two Champions League and two Confederation Cup berths")
	_check(_clubs(egypt, "confederation_cup").has("18"),
		"the Egyptian cup runner-up enters the Confederation Cup")
	var zealand := CareerBerths.for_country("New Zealand", rows,
		{"Chatham Cup": "19"})
	_check(zealand.get("berths", []).size() == 1
		and _clubs(zealand, "champions_league") == ["1"],
		"OFC sends one league champion per association")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	for country in ["England", "Italy", "Spain", "Germany", "France"]:
		var block := CareerBerths.for_country(country, rows,
			{"FA Cup": "19", "EFL Cup": "18", "Coppa Italia": "19",
				"DFB-Pokal": "19", "Coupe de France": "19", "Copa del Rey": "19"})
		_check(not block.is_empty(), "%s has berths" % country)
		if country != "England" and country != "Spain":
			var simple := _counts(block)
			_check(int(simple.get("CL", 0)) == 4 and int(simple.get("EL", 0)) == 2
				and int(simple.get("UCOL", 0)) == 1,
				"%s: four Champions League, two Europa, one Conference" % country)
	if catalog.is_loaded():
		var world := CareerWorld.world_season(catalog, "2026-08-15", 42, "",
			["ES1", "GB1"])
		_check(world.size() == 2, "the world table has both requested leagues")
		for league_id in world:
			var table: Array = world[league_id]
			_check(table.size() == 20, "%s table has twenty clubs" % league_id)
			_check(int((table[0] as Dictionary).get("position", 0)) == 1,
				"%s table starts at position one" % league_id)

	print("== check_career_berths: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
