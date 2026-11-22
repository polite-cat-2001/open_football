extends SceneTree
# Headless check for the season-end European resolution: every competition gets a
# champion from its league-phase table and the knockout bracket, the focus
# competition uses the results actually played in the career, and the other
# competitions are simulated from their fields. Also checks that the knockout
# stores five rounds and that the champion is one of the field clubs.
#
# Run:  godot --headless --path . -s res://tests/check_continental_knockout.gd

const CLUB := 583

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, CLUB, "Europe Finish", 189, 42, "real")
	_check(career != null, "a real-mode career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var block: Dictionary = career.data.get("continental", {}).get(
		career.season_start, {})
	_check(not block.is_empty(), "the season has a European block")
	if block.is_empty():
		_finish()
		return
	var ratings := {}
	for club_id in CareerEurope.fields().get("ucl", []):
		ratings[str(club_id)] = float(
			catalog.load_team_rating(int(club_id)).get("average", 55.0))
	var results := {}
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) == "ucl":
			results[str(fixture.get("id", ""))] = CareerSeason.simulate(
				career.seed, fixture, ratings)
	career.data["results"] = results
	var champions := CareerContinental.finish(catalog, career, block, career.seed)
	_check(champions.size() == 3, "three European champions: %d" % champions.size())
	var fields := CareerEurope.fields()
	for comp in ["ucl", "uel", "uecl"]:
		var champion := str(champions.get(comp, ""))
		_check(not champion.is_empty(), "%s has a champion" % comp)
		_check((fields.get(comp, []) as Array).has(champion),
			"%s champion is from its field" % comp)
		var knockout: Array = block.get("competitions", {}).get(comp, {}).get(
			"knockout", [])
		_check(knockout.size() == 5, "%s has five knockout rounds: %d"
			% [comp, knockout.size()])
	var state := {}
	for comp in ["ucl", "uel", "uecl"]:
		state[comp] = {"clubs": {}, "league": [], "paths": {}, "direct": {}}
	state["ucl"]["clubs"]["1"] = true
	CareerContinental._apply_title_holders(state, {
		"ucl": "1", "uel": "2", "uecl": "3"})
	_check(not (state["ucl"]["league"] as Array).has("1"),
		"an already qualified title holder gets no second place")
	_check((state["ucl"]["league"] as Array).has("2"),
		"the Europa League winner enters the Champions League")
	_check((state["uel"]["league"] as Array).has("3"),
		"the Conference League winner enters the Europa League")
	var coefficients: Dictionary = career.data.get("coefficients", {})
	_check(coefficients.size() >= 300, "the career coefficient table is loaded")
	var champion_row = coefficients.get(str(champions.get("ucl", "")), [])
	_check(champion_row is Array and (champion_row as Array).size() == 5
		and float((champion_row as Array)[4]) > 0.0,
		"the Champions League winner's season points rolled into the table")
	var static_country: Dictionary = career.data.get("country_coefficients", {})
	_check(is_equal_approx(CareerCountryCoefficients.coefficient(
		static_country, "England"), 119.519),
		"the static mode leaves the country ranking unchanged")
	var dynamic := CareerFactory.create(catalog, CLUB, "Dynamic Country", 189, 42,
		"real", "dynamic")
	_check(dynamic != null, "a dynamic-country career is created: "
		+ CareerFactory.last_error)
	if dynamic != null:
		var dynamic_block: Dictionary = dynamic.data.get("continental", {}).get(
			dynamic.season_start, {})
		var dynamic_results := {}
		for fixture in dynamic.schedule:
			if str(fixture.get("competition", "")) == "ucl":
				dynamic_results[str(fixture.get("id", ""))] = CareerSeason.simulate(
					dynamic.seed, fixture, ratings)
		dynamic.data["results"] = dynamic_results
		CareerContinental.finish(catalog, dynamic, dynamic_block, dynamic.seed)
		var dynamic_country: Dictionary = dynamic.data.get(
			"country_coefficients", {})
		var england: Array = dynamic_country.get("England", [])
		_check(england.size() == 5 and float(england[4]) > 0.0,
			"the dynamic mode adds the new country points")
		_check(not is_equal_approx(CareerCountryCoefficients.coefficient(
			dynamic_country, "England"), 119.519),
			"the dynamic country total rolled")
	_finish()


func _finish() -> void:
	print("== check_continental_knockout: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
