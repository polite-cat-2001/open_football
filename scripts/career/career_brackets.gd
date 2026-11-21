class_name CareerBrackets
extends RefCounted
# Pure knockout bracket: seeded pairs, byes for the top seeds, one- or two-leg
# ties, and the winners of a round. The stage's `rounds` list names the rounds
# and their legs; callers supply the date and the fixture prefix.

static func bracket_size(count: int) -> int:
	var size := 2
	while size < count:
		size *= 2
	return size


static func pairs(entrants: Array, size: int) -> Array:
	var result: Array = []
	for index in range(size / 2):
		var first = str(entrants[index]) if index < entrants.size() else null
		var second_index := size - 1 - index
		var second = str(entrants[second_index]) if second_index < entrants.size() else null
		if first != null and first == "":
			first = null
		if second != null and second == "":
			second = null
		result.append([first, second])
	return result


static func round_fixtures(stage: Dictionary, round_index: int, entrants: Array,
		dates: Array, prefix := "") -> Array:
	var rounds = stage.get("rounds", [])
	if round_index < 0 or round_index >= (rounds as Array).size():
		return []
	var spec: Dictionary = rounds[round_index]
	var legs := int(spec.get("legs", 1))
	var name := str(spec.get("name", "r%d" % (round_index + 1)))
	var size := bracket_size(entrants.size())
	var ties := pairs(entrants, size)
	var fixtures: Array = []
	for tie_index in range(ties.size()):
		var first = ties[tie_index][0]
		var second = ties[tie_index][1]
		if first == null or second == null:
			continue
		for leg in range(legs):
			var home := str(first) if leg % 2 == 0 else str(second)
			var away := str(second) if leg % 2 == 0 else str(first)
			var date := ""
			if leg < dates.size():
				date = str(dates[leg])
			elif not dates.is_empty():
				date = str(dates[-1])
			fixtures.append({
				"id": "%s%s:%02d:%d" % [prefix, name, tie_index, leg],
				"round": round_index + 1, "date": date,
				"home": home, "away": away,
				"tie": "%s:%02d" % [name, tie_index], "leg": leg,
				"group": -1,
			})
	return fixtures


static func round_winners(entrants: Array, fixtures: Array,
		results: Dictionary) -> Array:
	var winners: Array = []
	for row in tie_results(entrants, fixtures, results):
		if bool(row.get("bye", false)):
			winners.append(str(row.first))
			continue
		var first_goals := int(row.get("first_goals", 0))
		var second_goals := int(row.get("second_goals", 0))
		var winner := str(row.first)
		if second_goals > first_goals:
			winner = str(row.second)
		elif second_goals == first_goals:
			var last_result: Dictionary = row.get("last_result", {})
			var pens = last_result.get("pens")
			if pens is Dictionary:
				var home_pens := int(pens.get("home", 0))
				var away_pens := int(pens.get("away", 0))
				winner = str(row.last_home) if home_pens > away_pens else str(row.last_away)
		winners.append(winner)
	return winners


static func settle_ties(entrants: Array, fixtures: Array, results: Dictionary,
		seed: int) -> Dictionary:
	# A level tie after its last leg is decided by a shootout. Single-leg cup
	# ties and level two-leg aggregates both end here, so the higher seed never
	# advances on a draw. The pens are written into the last leg's result.
	for row in tie_results(entrants, fixtures, results):
		if bool(row.get("bye", false)):
			continue
		if int(row.get("played", 0)) < (row.get("legs", []) as Array).size():
			continue
		if int(row.get("first_goals", 0)) != int(row.get("second_goals", 0)):
			continue
		var last_result: Dictionary = row.get("last_result", {})
		if last_result.get("pens") is Dictionary:
			continue
		last_result["pens"] = shootout(("%d:%s" % [seed, str(row.get("last_id", ""))]).hash())
	return results


static func shootout(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var home := 0
	var away := 0
	for kick in range(5):
		if rng.randf() < 0.75:
			home += 1
		if rng.randf() < 0.75:
			away += 1
	while home == away:
		var home_scored := rng.randf() < 0.75
		var away_scored := rng.randf() < 0.75
		if home_scored and not away_scored:
			home += 1
		elif away_scored and not home_scored:
			away += 1
	return {"home": home, "away": away}


static func tie_results(entrants: Array, fixtures: Array,
		results: Dictionary) -> Array:
	if entrants.is_empty():
		return []
	var size := bracket_size(entrants.size())
	var ties := pairs(entrants, size)
	var rows: Array = []
	for tie_index in range(ties.size()):
		var first = ties[tie_index][0]
		var second = ties[tie_index][1]
		if first == null:
			continue
		if second == null:
			rows.append({"first": str(first), "second": null, "bye": true})
			continue
		var legs: Array = []
		for fixture in fixtures:
			var home := str(fixture.get("home", ""))
			var away := str(fixture.get("away", ""))
			if (home == str(first) and away == str(second)) \
					or (home == str(second) and away == str(first)):
				legs.append(fixture)
		if legs.is_empty():
			continue
		var first_goals := 0
		var second_goals := 0
		var played := 0
		var last_result: Dictionary = {}
		var last_home := ""
		var last_away := ""
		var last_id := ""
		for fixture in legs:
			var result = results.get(str(fixture.get("id", "")))
			if not (result is Dictionary):
				continue
			played += 1
			last_result = result
			last_home = str(fixture.get("home", ""))
			last_away = str(fixture.get("away", ""))
			last_id = str(fixture.get("id", ""))
			var home_goals := int(result.get("home", 0))
			var away_goals := int(result.get("away", 0))
			if last_home == str(first):
				first_goals += home_goals
				second_goals += away_goals
			else:
				first_goals += away_goals
				second_goals += home_goals
		rows.append({
			"first": str(first), "second": str(second), "bye": false,
			"legs": legs, "played": played,
			"first_goals": first_goals, "second_goals": second_goals,
			"last_result": last_result, "last_home": last_home,
			"last_away": last_away, "last_id": last_id,
		})
	return rows
