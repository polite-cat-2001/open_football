extends SceneTree
# Full AFC season: the career club plays its fixtures and the three cups must
# resolve to a champion. Also the regression check for the ACL Two stall.
#
# Run:  godot --headless --path . -s res://tests/check_afc_season.gd

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
	print("== check_afc_season: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var catalog := TeamCatalog.new()
	catalog.load_data_root()
	_check(catalog.is_loaded(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, 6502, "AFC Season", 189, 21)
	_check(career != null, "the Jeonbuk career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var block: Dictionary = career.data.get("continental", {}).get(
		career.season_start, {}).get("confederations", {}).get("AFC", {})
	var comps: Dictionary = block.get("competitions", {})
	_check(comps.size() == 3, "the season holds the three AFC cups")
	var guard := 0
	while guard < 60:
		guard += 1
		var pending := false
		for comp in comps:
			if not bool(comps[comp].get("done", false)):
				pending = true
		if not pending:
			break
		for fixture in career.schedule:
			if career.results.has(str(fixture.get("id", ""))):
				continue
			var home := str(fixture.get("home", ""))
			career.data["results"][str(fixture.get("id", ""))] = \
				{"home": 2, "away": 0} if home == career.club_id \
				else {"home": 0, "away": 2}
		CareerConfederation.ensure(career, catalog)
	for comp in comps:
		var state: Dictionary = comps[comp]
		_check(bool(state.get("done", false)), comp + " reaches its champion")
		_check(not str(state.get("champion", "")).is_empty(),
			comp + " stores a champion")
		if not bool(state.get("done", false)):
			print("    ", comp, " round_index=", state.get("round_index"),
				" rounds=", (state.get("rounds", []) as Array).size(),
				" region_entrants=", _sizes(state.get("region_entrants", {})))
	var unplayed := 0
	for fixture in career.schedule:
		if str(fixture.get("confederation", "")) == "AFC" \
				and not career.results.has(str(fixture.get("id", ""))):
			unplayed += 1
	_check(unplayed == 0, "every scheduled AFC fixture has a result")
	_finish()


func _sizes(source: Dictionary) -> Dictionary:
	var out := {}
	for region in source:
		out[region] = (source[region] as Array).size()
	return out
