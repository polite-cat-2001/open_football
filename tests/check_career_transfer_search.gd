extends SceneTree
# Headless golden check for the career transfer search (ticket 07): filters,
# sorting, paging, fog of war, the player profile and the filter reference.
# The fixture comes from the prototype app (tmp/oracle_transfers.py).
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_search.gd

const GOLDEN := "res://tests/fixtures/career_transfer_search_golden.json"

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
	print("== check_career_transfer_search: ", "PASS" if failures.is_empty() else "FAIL",
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


func _compare(label: String, actual: Dictionary, expected: Dictionary, skip: Array = []) -> void:
	for key in expected:
		if skip.has(key):
			continue
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
	_check(golden is Dictionary, "the search golden loads")
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
	career.data["date"] = str(header["date"])
	_check(career.balance == 318400000, "the starting balance matches the prototype")

	var reference := CareerSearch.filter_reference(catalog, str(golden["reference"]["es1"]["id"]))
	var expected_reference: Dictionary = golden["reference"]
	_check((reference.get("countries", []) as Array).size() == int(expected_reference["countries"]),
		"the country list has every country with leagues")
	_check((reference.get("leagues", []) as Array).size() == int(expected_reference["leagues"]),
		"the league list has every league")
	_check((reference.get("clubs", []) as Array).size() == int(expected_reference["clubs_in_es1"]),
		"the club list has every LaLiga club")
	var first_country: Dictionary = (reference.get("countries", []) as Array)[0]
	_check(_same(first_country.get("id"), expected_reference["first_country"]["id"])
		and _same(first_country.get("name"), expected_reference["first_country"]["name"]),
		"countries are ordered by name")
	var leagues: Array = reference.get("leagues", [])
	var es1: Dictionary = {}
	for league in leagues:
		if str(league.get("id", "")) == "ES1":
			es1 = league
	_check(_same(es1.get("name"), expected_reference["es1"]["name"])
		and _same(es1.get("country_id"), expected_reference["es1"]["country_id"]),
		"the leagues carry their country")

	var started := Time.get_ticks_msec()
	for case in golden["cases"]:
		var filters := _filters(case["filters"])
		var limit := int(case["limit"])
		var offset := int(case["offset"])
		var result := CareerSearch.search(catalog, career, filters, limit, offset)
		var label := str(case["label"])
		_check(int(result.get("total", -1)) == int(case["total"]),
			"%s: total %d" % [label, int(case["total"])])
		_check(bool(result.get("has_more", not bool(case["has_more"]))) == bool(case["has_more"]),
			"%s: has_more" % label)
		var items: Array = result.get("items", [])
		var expected_items: Array = case["items"]
		_check(items.size() == expected_items.size(),
			"%s: %d items" % [label, expected_items.size()])
		for index in range(mini(items.size(), expected_items.size())):
			_compare("%s item %d" % [label, index], items[index], expected_items[index])
	print("  search pass took ", Time.get_ticks_msec() - started, " ms")

	# A page past the first index window must still come out ordered (the old
	# full-list rebuild is gone; the page is a fresh ordered query).
	var deep := CareerSearch.search(catalog, career, CareerSearch.filters_default(),
		40, 4000)
	var deep_items: Array = deep.get("items", [])
	_check(deep_items.size() == 40, "a deep page still holds forty players")
	var deep_names: Array[String] = []
	for item in deep_items:
		deep_names.append(str((item as Dictionary).get("name", "")).to_lower())
	var sorted_names := deep_names.duplicate()
	sorted_names.sort()
	_check(deep_names == sorted_names, "a deep page keeps the sort order")

	var own: Dictionary = golden["profile"]["own_player"]
	var own_profile := CareerSearch.profile(catalog, career, str(own["player_id"]))
	_check(bool(own_profile.get("scouted", false)), "an own player is scouted")
	_compare("own profile", own_profile, own["item"])
	for key in ["first_name", "last_name", "birth_date", "role", "weight", "height"]:
		_check(_same(own_profile.get(key), own[key]), "own profile: " + key)
	for key in ["weak_foot", "skill_moves", "shirt_number"]:
		_check(_same(own_profile.get(key), own[key]), "own profile: " + key)
	_check(_same(own_profile.get("stats"), own["stats"]), "own profile: stats")

	var external: Dictionary = golden["profile"]["external_player"]
	var external_profile := CareerSearch.profile(catalog, career, str(external["player_id"]))
	_check(not bool(external_profile.get("scouted", false)),
		"an unscouted player stays hidden")
	_check(is_equal_approx(float(external_profile.get("overall", -1.0)), 0.0)
		and int(external_profile.get("market_value", -1)) == 0
		and str(external_profile.get("foot", "x")) == ""
		and (external_profile.get("stats", {"x": 1}) as Dictionary).is_empty(),
		"an unscouted card hides the fog-of-war fields")
	_check(int(external_profile.get("release_clause", 0)) > 0
		and not str(external_profile.get("contract_expires", "")).is_empty(),
		"release clause and contract expiry are always visible")
	_check(int(external_profile.get("height", 0)) == int(external["height"]),
		"height is always visible")
	_check(_same(external_profile.get("first_name"), external["first_name"]),
		"external profile: first_name")
	_check(_same(external_profile.get("weight"), external["weight"]),
		"external profile: weight")

	_check(CareerSearch.group_of("CB") == "DEF", "group_of maps a role")
	_check(CareerSearch.group_of("Centre-Forward") == "FWD", "group_of maps a position")
	_check(CareerSearch.group_of("Left Winger") == "MID", "group_of maps a winger")
	_check(CareerSearch.group_of("Goalkeeper") == "GK", "group_of maps a keeper")

	var free_item := CareerSearch.search(catalog, career,
		{"status": "free", "sort": "age", "direction": "asc"}, 1, 0)
	var free_first: Dictionary = (free_item.get("items", []) as Array)[0]
	_check(str(free_first.get("status", "")) == "free"
		and str(free_first.get("club_id", "x")).is_empty(), "a free agent has no club")

	# The cached result must follow status changes that keep the map size.
	var squad_ids: Array = career.player_ids.duplicate()
	if squad_ids.size() >= 2:
		var first_id := str(squad_ids[0])
		var second_id := str(squad_ids[1])
		CareerTransfers.set_status(career, catalog, first_id, "loan")
		CareerTransfers.set_status(career, catalog, second_id, "transfer")
		var transfer_filters := _filters({"status": "transfer"})
		var before := _status_ids(CareerSearch.search(catalog, career, transfer_filters, 40, 0))
		_check(before.has(second_id) and not before.has(first_id),
			"the transfer filter sees the first status")
		CareerTransfers.set_status(career, catalog, first_id, "transfer")
		CareerTransfers.set_status(career, catalog, second_id, "loan")
		var after := _status_ids(CareerSearch.search(catalog, career, transfer_filters, 40, 0))
		_check(after.has(first_id) and not after.has(second_id),
			"the cached search follows a status change with the same map size")

	_finish()


func _status_ids(result: Dictionary) -> Dictionary:
	var ids := {}
	for item in result.get("items", []):
		ids[str(item.get("player_id", ""))] = true
	return ids


func _filters(raw: Dictionary) -> Dictionary:
	# The fixture keeps the prototype's query names; JSON turns missing values
	# into null, which the search treats as "unset".
	var filters := CareerSearch.filters_default()
	for key in filters:
		if raw.has(key):
			filters[key] = raw[key]
	return filters
