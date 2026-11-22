extends SceneTree
# Headless check for the European draws. The real 2026-27 draw is the official
# one: 144 UCL and UEL fixtures, 108 UECL fixtures (six matchdays), every club
# plays the right number of matches with an even home split, no club meets its own
# association and no club meets more than two from any association. The draw
# engine itself is checked on a synthetic field of 36 different associations:
# four pots, two opponents per pot, four home and four away.
#
# Run:  godot --headless --path . -s res://tests/check_career_draw.gd

const EXPECTED := {"ucl": [144, 8, 4], "uel": [144, 8, 4], "uecl": [108, 6, 3]}

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _pots(field: Array) -> Dictionary:
	var ranked := CareerCoefficients.sorted_clubs(field)
	var pots := {}
	for index in range(ranked.size()):
		pots[str(ranked[index])] = mini(index / 9, 3)
	return pots


func _pots6(field: Array) -> Dictionary:
	var ranked := CareerCoefficients.sorted_clubs(field)
	var pots := {}
	for index in range(ranked.size()):
		pots[str(ranked[index])] = mini(index / 6, 5)
	return pots


func _countries(catalog: TeamCatalog, field: Array) -> Dictionary:
	var result := {}
	for club_id in field:
		result[str(club_id)] = str(catalog.career_club(int(club_id)).get("country_name", ""))
	return result


func _verify(draw: Array, field: Array, rounds: int, home_split: int,
		countries: Dictionary, pots: Dictionary, label: String,
		per_pot_target: int = 2) -> void:
	var expected := 18 * rounds
	_check(draw.size() == expected, "%s: %d fixtures (%d)" % [label, expected, draw.size()])
	if draw.size() != expected:
		return
	var opponents: Dictionary = {}
	var home: Dictionary = {}
	var away: Dictionary = {}
	var bad: Array = []
	var pairs := {}
	for index in range(draw.size()):
		var fixture: Dictionary = draw[index]
		var home_id := str(fixture.get("home", ""))
		var away_id := str(fixture.get("away", ""))
		var key := home_id + "|" + away_id if home_id < away_id else away_id + "|" + home_id
		if pairs.has(key):
			bad.append("repeat:" + key)
		pairs[key] = true
		home[home_id] = int(home.get(home_id, 0)) + 1
		away[away_id] = int(away.get(away_id, 0)) + 1
		var played: Dictionary = opponents.get(home_id, {})
		played[away_id] = true
		opponents[home_id] = played
		var reverse: Dictionary = opponents.get(away_id, {})
		reverse[home_id] = true
		opponents[away_id] = reverse
		if not countries.is_empty() \
				and str(countries.get(home_id, "")) == str(countries.get(away_id, "")):
			bad.append("same:" + home_id)
	for club_id in field:
		var key := str(club_id)
		if int(opponents.get(key, {}).size()) != rounds:
			bad.append("opponents:" + key)
		if int(home.get(key, 0)) != home_split or int(away.get(key, 0)) != home_split:
			bad.append("home:" + key)
		if not pots.is_empty():
			var per_pot := {}
			for other in opponents.get(key, {}):
				var pot := int(pots.get(str(other), 0))
				per_pot[pot] = int(per_pot.get(pot, 0)) + 1
			var max_pot := 0
			for value in pots.values():
				max_pot = maxi(max_pot, int(value))
			var ok := per_pot.size() == max_pot + 1
			for value in per_pot.values():
				if int(value) != per_pot_target:
					ok = false
			if not ok:
				bad.append("pots:" + key)
		if not countries.is_empty():
			var per_country := {}
			for other in opponents.get(key, {}):
				var country := str(countries.get(str(other), ""))
				per_country[country] = int(per_country.get(country, 0)) + 1
				if int(per_country[country]) > 2:
					bad.append("country:" + key + "/" + country)
	_check(bad.is_empty(), "%s: opponents, home/away, associations: %s"
		% [label, str(bad.slice(0, 4))])


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var fields := CareerEurope.fields()
	for comp in ["ucl", "uel", "uecl"]:
		var field: Array = fields.get(comp, [])
		var expected: Array = EXPECTED[comp]
		_check(field.size() == 36, "%s field has 36 clubs" % comp)
		var draw := CareerEurope.draw(comp)
		var countries := _countries(catalog, field)
		_verify(draw, field, int(expected[1]), int(expected[2]), countries, {}, comp)
	var synthetic := _synthetic_field(catalog)
	if synthetic.size() == 36:
		var pots := _pots(synthetic)
		var unique := {}
		for club_id in synthetic:
			unique[str(countries_of(catalog, club_id))] = true
		var drawn := CareerDraw.league_phase(catalog, synthetic, 42)
		_check(CareerDraw.last_error.is_empty(),
			"the draw engine converges: " + CareerDraw.last_error)
		_verify(drawn, synthetic, 8, 4, {}, pots, "engine")
		var uecl := CareerDraw.league_phase(catalog, synthetic, 42, "uecl")
		_check(CareerDraw.last_error.is_empty(),
			"the UECL draw engine converges: " + CareerDraw.last_error)
		_verify(uecl, synthetic, 6, 3, {}, _pots6(synthetic), "uecl engine", 1)
		_check(unique.size() == 36, "the engine field has 36 associations")
	else:
		_check(false, "a synthetic 36-association field is built: %d" % synthetic.size())
	_finish()


func countries_of(catalog: TeamCatalog, club_id: String) -> String:
	return str(catalog.career_club(int(club_id)).get("country_name", ""))


func _synthetic_field(catalog: TeamCatalog) -> Array:
	var seen := {}
	var result: Array = []
	for league in catalog.career_leagues():
		var country := str(catalog.country_by_id(
			int(league.get("country_id", 0))).get("name", ""))
		if country.is_empty() or seen.has(country):
			continue
		for team in catalog.all_teams_for_league(str(league.get("id", ""))):
			var club_id := str(team.get("id", ""))
			if club_id.is_empty():
				continue
			seen[country] = true
			result.append(club_id)
			break
		if result.size() == 36:
			break
	return result


func _finish() -> void:
	print("== check_career_draw: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
