extends SceneTree
# Headless check for the real 2026-27 UEFA field and the first-season Europe
# switch. The asset has three 36-club league phases without duplicates; real mode
# keeps them untouched, simulated mode puts the career club into the competition
# whose average coefficient is closest and drops the weakest club, and a manual
# swap exchanges two clubs while keeping both fields at 36. A career created with
# real mode plays the league phase; "none" schedules no European fixtures.
#
# Run:  godot --headless --path . -s res://tests/check_career_europe.gd

const IN_FIELD := 583      # Paris Saint-Germain (UCL)
const OUT_FIELD := 621     # Athletic Bilbao (not in the published fields)

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _competition_of(fields: Dictionary, club_id: String) -> String:
	for comp in fields:
		var entry = fields[comp]
		var field: Array = entry.get("league_phase", []) if entry is Dictionary else entry
		if field is Array and field.has(club_id):
			return str(comp)
	return ""


func _average(field: Array) -> float:
	var total := 0.0
	for club_id in field:
		total += CareerCoefficients.coefficient(str(club_id))
	return total / field.size()


func _euro_fixtures(career: Career, comp: String, club_id: String) -> Array:
	var rows: Array = []
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) != comp:
			continue
		if str(fixture.get("home", "")) != club_id \
				and str(fixture.get("away", "")) != club_id:
			continue
		rows.append(fixture)
	return rows


func _run() -> void:
	_check(CareerEurope.season() == "2026-27", "the field asset is for 2026-27")
	var fields := CareerEurope.fields()
	_check(fields.size() == 3, "the asset has three competitions")
	var all := {}
	for comp in ["ucl", "uel", "uecl"]:
		var field: Array = fields.get(comp, [])
		_check(field.size() == 36, "%s has 36 clubs: %d" % [comp, field.size()])
		for club_id in field:
			all[str(club_id)] = true
	_check(all.size() == 108, "the three fields have no shared club: %d" % all.size())
	_check(CareerEurope.replacements().has("uecl"),
		"the missing Borac Banja Luka is recorded as a replacement")

	var real := CareerEurope.first_season("real", str(IN_FIELD))
	_check(not real.is_empty(), "real mode builds a block: " + CareerEurope.last_error)
	_check(_competition_of(real.get("competitions", {}), str(IN_FIELD)) == "ucl",
		"real mode leaves the career club in its published competition")
	var absent := CareerEurope.first_season("real", str(OUT_FIELD))
	_check(_competition_of(absent.get("competitions", {}), str(OUT_FIELD)).is_empty(),
		"real mode does not invent a place for a club outside the field")

	var before := CareerEurope.fields()
	var simulated := CareerEurope.first_season("simulated", str(OUT_FIELD))
	var placed := _competition_of(simulated.get("competitions", {}), str(OUT_FIELD))
	_check(not placed.is_empty(), "simulated mode places the club")
	if placed.is_empty():
		_finish()
		return
	var chosen := ""
	var chosen_diff := INF
	var coefficient := CareerCoefficients.coefficient(str(OUT_FIELD))
	for comp in ["ucl", "uel", "uecl"]:
		var diff := absf(_average(before[comp]) - coefficient)
		if diff < chosen_diff:
			chosen_diff = diff
			chosen = comp
	_check(placed == chosen, "the club goes to the closest average coefficient")
	var placed_field: Array = simulated["competitions"][placed]["league_phase"]
	var old_field: Array = before[placed]
	_check(placed_field.size() == 36, "the simulated field stays at 36")
	_check(_competition_of(before, str(OUT_FIELD)).is_empty(),
		"the placement changes the field")
	var removed := ""
	for club_id in old_field:
		if not placed_field.has(club_id):
			removed = str(club_id)
	var weakest := str(CareerCoefficients.sorted_clubs(old_field).back())
	_check(removed == weakest, "the weakest club by coefficient is replaced")

	var swapped := CareerEurope.block()
	var ucl: Array = swapped["competitions"]["ucl"]["league_phase"]
	var uel: Array = swapped["competitions"]["uel"]["league_phase"]
	var first := str(ucl[0])
	var second := str(uel[0])
	_check(CareerEurope.swap(swapped, "ucl", first, "uel", second),
		"two clubs from different competitions swap")
	_check(swapped["competitions"]["ucl"]["league_phase"].has(second)
		and not swapped["competitions"]["ucl"]["league_phase"].has(first),
		"the first club moves to the second competition")
	_check(swapped["competitions"]["uel"]["league_phase"].has(first)
		and not swapped["competitions"]["uel"]["league_phase"].has(second),
		"the second club moves to the first competition")
	_check(not CareerEurope.swap(swapped, "ucl", first, "ucl", second),
		"the same competition is rejected")
	_check(not CareerEurope.swap(swapped, "ucl", "999999999", "uel", second),
		"a club outside the field is rejected")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, IN_FIELD, "Europe Manager", 189, 42,
		"real")
	_check(career != null, "a real-mode career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var euro := _euro_fixtures(career, "ucl", str(IN_FIELD))
	_check(euro.size() == 8, "the career club has eight league-phase fixtures: %d" % euro.size())
	var home := 0
	var opponents := {}
	for fixture in euro:
		if str(fixture.get("home", "")) == str(IN_FIELD):
			home += 1
		opponents[str(fixture.get("home", ""))] = true
		opponents[str(fixture.get("away", ""))] = true
	_check(home == 4, "the career club has four home fixtures: %d" % home)
	_check(opponents.size() == 9, "eight different opponents: %d" % (opponents.size() - 1))

	var none := CareerFactory.create(catalog, IN_FIELD, "No Europe", 189, 42, "none")
	_check(none != null, "a no-Europe career is created: " + CareerFactory.last_error)
	if none != null:
		_check(_euro_fixtures(none, "ucl", str(IN_FIELD)).is_empty()
			and _euro_fixtures(none, "uel", str(IN_FIELD)).is_empty()
			and _euro_fixtures(none, "uecl", str(IN_FIELD)).is_empty(),
			"no European fixtures are scheduled")

	var sim_career := CareerFactory.create(catalog, OUT_FIELD, "Sim Europe", 189, 42,
		"simulated")
	_check(sim_career != null, "a simulated career is created: " + CareerFactory.last_error)
	if sim_career != null:
		var block: Dictionary = sim_career.data.get("continental", {}).get(
			sim_career.season_start, {})
		var comp := _competition_of(block.get("competitions", {}), str(OUT_FIELD))
		_check(not comp.is_empty(), "the simulated career club is in a field")
		var expected_rounds := int(CareerEurope.ROUNDS.get(comp, 8))
		_check(not comp.is_empty()
			and _euro_fixtures(sim_career, comp, str(OUT_FIELD)).size() == expected_rounds,
			"the simulated league phase is scheduled")

	_finish()


func _finish() -> void:
	print("== check_career_europe: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
