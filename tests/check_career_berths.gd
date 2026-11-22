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
	_check(int(counts.get("ucl", 0)) == 5 and int(counts.get("uel", 0)) == 2
		and int(counts.get("uecl", 0)) == 1,
		"Spain: five Champions League, two Europa, one Conference")
	_check(_clubs(spain, "ucl") == ["1", "2", "3", "4", "5"],
		"the Champions League places are the top five")
	_check(_clubs(spain, "uel").has("6") and _clubs(spain, "uel").has("19"),
		"the sixth club and the cup winner enter the Europa League")
	_check(_clubs(spain, "uecl") == ["7"],
		"the seventh club enters the Conference League")
	var all_ids := {}
	for entry in spain.get("berths", []):
		all_ids[str(entry.get("club_id", ""))] = true
	_check(all_ids.size() == 8, "no club gets two berths")

	var cascade := CareerBerths.for_country("Spain", rows, {"Copa del Rey": "3"})
	_check(_clubs(cascade, "uel") == ["6", "7"],
		"a cup winner already in the Champions League cascades the Europa place")
	_check(_clubs(cascade, "uecl") == ["8"],
		"the Conference place cascades to the next club")

	var england := CareerBerths.for_country("England", rows,
		{"FA Cup": "19", "EFL Cup": "18"})
	_check(int(_counts(england).get("uecl", 0)) == 1,
		"England's second cup does not add a berth")
	_check(_clubs(england, "uecl") == ["18"],
		"the EFL Cup winner takes the Conference place")
	var england_qualified := CareerBerths.for_country("England", rows,
		{"FA Cup": "19", "EFL Cup": "3"})
	_check(_clubs(england_qualified, "uecl") == ["7"],
		"an already-qualified EFL Cup winner cascades the Conference place")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	for country in ["England", "Italy", "Spain", "Germany", "France"]:
		var block := CareerBerths.for_country(country, rows,
			{"FA Cup": "19", "EFL Cup": "18", "Coppa Italia": "19",
				"DFB-Pokal": "19", "Coupe de France": "19", "Copa del Rey": "19"})
		_check(not block.is_empty(), "%s has berths" % country)
		if country != "England" and country != "Spain":
			var simple := _counts(block)
			_check(int(simple.get("ucl", 0)) == 4 and int(simple.get("uel", 0)) == 2
				and int(simple.get("uecl", 0)) == 1,
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
