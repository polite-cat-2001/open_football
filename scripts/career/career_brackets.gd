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


static func round_size(count: int) -> int:
	# A round pairs every entrant: even fields have no byes, an odd field gives
	# the middle seed a bye. `bracket_size` pads to a full power of two instead,
	# which is only right for a single-elimination bracket.
	return count if count % 2 == 0 else count + 1


static func _round_size(entrants: Array, size: int) -> int:
	if size >= entrants.size() and size > 0:
		return size
	return bracket_size(entrants.size())


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
		dates: Array, prefix := "", size := 0) -> Array:
	var rounds = stage.get("rounds", [])
	if round_index < 0 or round_index >= (rounds as Array).size():
		return []
	var spec: Dictionary = rounds[round_index]
	var legs := int(spec.get("legs", 1))
	var name := str(spec.get("name", "r%d" % (round_index + 1)))
	var resolved := _round_size(entrants, size)
	var ties := pairs(entrants, resolved)
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
		results: Dictionary, size := 0) -> Array:
	var winners: Array = []
	for row in tie_results(entrants, fixtures, results, size):
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
			var decided := str(last_result.get("decided_by", ""))
			if decided == "away_goals":
				winner = str(row.first) \
					if int(row.get("first_away", 0)) > int(row.get("second_away", 0)) \
					else str(row.second)
			else:
				var pens = last_result.get("pens")
				if pens is Dictionary:
					var home_pens := int(pens.get("home", 0))
					var away_pens := int(pens.get("away", 0))
					winner = str(row.last_home) if home_pens > away_pens else str(row.last_away)
		winners.append(winner)
	return winners


static func settle_ties(entrants: Array, fixtures: Array, results: Dictionary,
		seed: int, rules: Dictionary = {}, size := 0) -> Dictionary:
	# A level tie is decided by the competition's tie-break: away goals first
	# (two-legged ties only), then the extra-time method, then penalties. The
	# extra time and shootout are written into the last leg's result.
	var method := str(rules.get("method", "extra_time_pens"))
	var away_goals := bool(rules.get("away_goals", false))
	var away_extra := bool(rules.get("away_goals_extra_time", true))
	for row in tie_results(entrants, fixtures, results, size):
		if bool(row.get("bye", false)):
			continue
		if int(row.get("played", 0)) < (row.get("legs", []) as Array).size():
			continue
		if int(row.get("first_goals", 0)) != int(row.get("second_goals", 0)):
			continue
		var last_result: Dictionary = row.get("last_result", {})
		if not str(last_result.get("decided_by", "")).is_empty() \
				or last_result.get("pens") is Dictionary:
			continue
		var two_legged := (row.get("legs", []) as Array).size() >= 2
		if away_goals and two_legged:
			var first_away := int(row.get("first_away", 0))
			var second_away := int(row.get("second_away", 0))
			if first_away != second_away:
				last_result["decided_by"] = "away_goals"
				continue
		if method == "pens":
			last_result["pens"] = shootout(_seed(seed, "pens",
				str(row.get("last_id", ""))))
			last_result["decided_by"] = "pens"
			continue
		var extra := extra_time(_seed(seed, "et", str(row.get("last_id", ""))), method)
		var first_home := str(row.get("last_home", "")) == str(row.get("first", ""))
		var et_first := int(extra.get("home", 0)) if first_home else int(extra.get("away", 0))
		var et_second := int(extra.get("away", 0)) if first_home else int(extra.get("home", 0))
		last_result["home"] = int(last_result.get("home", 0)) + int(extra.get("home", 0))
		last_result["away"] = int(last_result.get("away", 0)) + int(extra.get("away", 0))
		last_result["et"] = extra
		if method == "golden_goal" and (et_first > 0 or et_second > 0):
			last_result["decided_by"] = "golden_goal"
			continue
		if int(row.get("first_goals", 0)) + et_first \
				!= int(row.get("second_goals", 0)) + et_second:
			last_result["decided_by"] = "extra_time"
			continue
		if away_goals and two_legged and away_extra:
			var first_extra_away := 0 if first_home else int(extra.get("away", 0))
			var second_extra_away := int(extra.get("away", 0)) if first_home else 0
			if int(row.get("first_away", 0)) + first_extra_away \
					!= int(row.get("second_away", 0)) + second_extra_away:
				last_result["decided_by"] = "away_goals"
				continue
		last_result["pens"] = shootout(_seed(seed, "pens",
			str(row.get("last_id", ""))))
		last_result["decided_by"] = "pens"
	return results


static func extra_time(seed: int, method := "extra_time_pens") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if method == "golden_goal":
		for minute in range(30):
			if rng.randf() < 0.5 / 30.0:
				return {"home": 1, "away": 0}
			if rng.randf() < 0.5 / 30.0:
				return {"home": 0, "away": 1}
		return {"home": 0, "away": 0}
	return {
		"home": CareerSeason.poisson(rng, 0.5),
		"away": CareerSeason.poisson(rng, 0.5),
	}


static func _seed(seed: int, kind: String, fixture_id: String) -> int:
	return ("%d:%s:%s" % [seed, kind, fixture_id]).hash()


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
		results: Dictionary, size := 0) -> Array:
	if entrants.is_empty():
		return []
	var resolved := _round_size(entrants, size)
	var ties := pairs(entrants, resolved)
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
		var first_away := 0
		var second_away := 0
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
				second_away += away_goals
			else:
				first_goals += away_goals
				second_goals += home_goals
				first_away += away_goals
		rows.append({
			"first": str(first), "second": str(second), "bye": false,
			"legs": legs, "played": played,
			"first_goals": first_goals, "second_goals": second_goals,
			"first_away": first_away, "second_away": second_away,
			"last_result": last_result, "last_home": last_home,
			"last_away": last_away, "last_id": last_id,
		})
	return rows
