extends SceneTree
# Headless check for the first-season continental field: an MLS club opens a
# career with the real 2026 CONCACAF Champions Cup (22 round-one clubs, 5 byes,
# 5 entrants whose association has no league in the database) and plays it.
#
# Run:  godot --headless --path . -s res://tests/check_career_confederation_field.gd

const MIAMI := 69261
const GALAXY := 1061

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
	print("== check_career_confederation_field: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var catalog := TeamCatalog.new()
	catalog.load_data_root()
	_check(catalog.is_loaded(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, MIAMI, "Field Tester", 189, 7)
	_check(career != null, "the Miami career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var block: Dictionary = career.data.get("continental", {}).get(
		career.season_start, {})
	var confederations: Dictionary = block.get("confederations", {})
	_check(confederations.has("CONCACAF"), "the first season holds the CONCACAF block")
	var conf_block: Dictionary = confederations.get("CONCACAF", {})
	var state: Dictionary = conf_block.get("competitions", {}).get("champions_cup", {})
	_check(state.size() > 0, "the Champions Cup state exists")
	if state.is_empty():
		_finish()
		return
	_check((state["entries"] as Dictionary).size() == 22,
		"the field holds the 22 clubs with a league in the database")
	_check(str(conf_block.get("focus", "")) == "champions_cup",
		"the career club's competition is the focus")
	_check((state.get("missing", []) as Array).size() == 5,
		"the five entrants without a league are recorded")

	var focus_legs := 0
	for fixture in career.schedule:
		if str(fixture.get("confederation", "")) != "CONCACAF":
			continue
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		if home == career.club_id or away == career.club_id:
			focus_legs += 1
	_check(focus_legs == 2, "Miami enters the round of 16 with two scheduled legs")
	_check(career.schedule.size() >= focus_legs, "the cup joins the club's calendar")

	# Play every Miami tie 2-0 and let the cup run to the final.
	var guard := 0
	while not bool(state.get("done", false)) and guard < 12:
		guard += 1
		for fixture in career.schedule:
			if career.results.has(str(fixture.get("id", ""))):
				continue
			var home := str(fixture.get("home", ""))
			career.data["results"][str(fixture.get("id", ""))] = \
				{"home": 2, "away": 0} if home == career.club_id \
				else {"home": 0, "away": 2}
		CareerConfederation.ensure(career, catalog)
	_check(bool(state.get("done", false)), "the cup reaches its final")
	_check(not str(state.get("champion", "")).is_empty(), "a champion is stored")
	_check(str(state.get("champion", "")) == career.club_id,
		"Miami win every tie it plays")
	_check(not str(state.get("runner_up", "")).is_empty(), "a runner-up is stored")

	# The next season builds the field from the season's berths, not the asset.
	CareerFactory.create(catalog, GALAXY, "Other", 189, 7)
	_finish()
