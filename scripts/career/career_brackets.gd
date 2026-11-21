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
		date: String, prefix := "") -> Array:
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
	if entrants.is_empty():
		return []
	var size := bracket_size(entrants.size())
	var ties := pairs(entrants, size)
	var winners: Array = []
	for tie_index in range(ties.size()):
		var first = ties[tie_index][0]
		var second = ties[tie_index][1]
		if first == null:
			continue
		if second == null:
			winners.append(str(first))
			continue
		var tie_id := ""
		var legs: Array = []
		for fixture in fixtures:
			if str(fixture.get("home", "")) == str(first) \
					or str(fixture.get("home", "")) == str(second):
				if str(fixture.get("away", "")) == str(first) \
						or str(fixture.get("away", "")) == str(second):
					legs.append(fixture)
		if legs.is_empty():
			continue
		tie_id = str(legs[0].get("tie", ""))
		if tie_id.is_empty():
			continue
		var first_goals := 0
		var second_goals := 0
		var last_result: Dictionary = {}
		var last_home := ""
		var last_away := ""
		for fixture in legs:
			var result = results.get(str(fixture.get("id", "")))
			if not (result is Dictionary):
				continue
			last_result = result
			last_home = str(fixture.get("home", ""))
			last_away = str(fixture.get("away", ""))
			var home_goals := int(result.get("home", 0))
			var away_goals := int(result.get("away", 0))
			if last_home == str(first):
				first_goals += home_goals
				second_goals += away_goals
			else:
				first_goals += away_goals
				second_goals += home_goals
		var winner := str(first)
		if second_goals > first_goals:
			winner = str(second)
		elif second_goals == first_goals:
			var pens = last_result.get("pens")
			if pens is Dictionary:
				var home_pens := int(pens.get("home", 0))
				var away_pens := int(pens.get("away", 0))
				winner = last_home if home_pens > away_pens else last_away
		winners.append(winner)
	return winners
