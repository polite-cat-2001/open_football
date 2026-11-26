class_name CareerStages
extends RefCounted
# Pure stage math for the career formats: build a table from a fixture list and
# results, cut it into groups, carry points/goals into the next stage, and pick
# the champion. No career, database or dates: callers pass the fixtures.

static func table(fixtures: Array, results: Dictionary, club_ids: Array,
		carried: Dictionary = {}) -> Array:
	var rows := {}
	for club_id in club_ids:
		var key := str(club_id)
		rows[key] = {
			"id": key, "played": 0, "won": 0, "drawn": 0, "lost": 0,
			"goals_for": 0, "goals_against": 0, "goal_difference": 0, "points": 0,
		}
	for club_id in carried:
		if not rows.has(str(club_id)):
			continue
		var source: Dictionary = carried[str(club_id)]
		var row: Dictionary = rows[str(club_id)]
		row["played"] = int(source.get("played", 0))
		row["goals_for"] = int(source.get("goals_for", 0))
		row["goals_against"] = int(source.get("goals_against", 0))
		row["points"] = int(source.get("points", 0))

	for fixture in fixtures:
		var result = results.get(str(fixture.get("id", "")))
		if not (result is Dictionary):
			continue
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		if not rows.has(home) or not rows.has(away):
			continue
		var home_goals := int(result.get("home", 0))
		var away_goals := int(result.get("away", 0))
		_add(rows[home], home_goals, away_goals)
		_add(rows[away], away_goals, home_goals)

	var table: Array = rows.values()
	table.sort_custom(_before)
	return table


static func split(table: Array, sizes: Array) -> Array:
	var groups: Array = []
	var index := 0
	for size in sizes:
		var count := int(size)
		groups.append(table.slice(index, index + count))
		index += count
	return groups


static func carry(table: Array, mode: Dictionary) -> Dictionary:
	var points_mode := str(mode.get("points", "none"))
	if points_mode == "none":
		return {}
	var goals_mode := str(mode.get("goals", "reset"))
	var rounding := str(mode.get("rounding", "down"))
	var carried := {}
	for row in table:
		var points := 0
		if points_mode == "full":
			points = int(row.points)
		elif points_mode == "half":
			var half := float(row.points) / 2.0
			points = int(ceil(half)) if rounding == "up" else int(floor(half))
		carried[str(row.id)] = {
			"points": points,
			"played": int(row.played),
			"goals_for": int(row.goals_for) if goals_mode == "carry" else 0,
			"goals_against": int(row.goals_against) if goals_mode == "carry" else 0,
		}
	return carried


static func champion(table: Array) -> Dictionary:
	return table[0] if not table.is_empty() else {}


static func stages(format: Dictionary) -> Array:
	var value = format.get("stages", [])
	return value if value is Array else []


static func resolve_entrants(stage: Dictionary, table: Array,
		taken: Dictionary = {}, groups: Array = [],
		sources: Dictionary = {}) -> Array:
	# `top` takes a rank range from the clause's source table; `rest` takes the
	# clubs not already named; `winner`/`losers` take the decided knockout tie.
	# With `per_group` the range is taken from every group of that source.
	var result: Array = []
	var named := taken.duplicate()
	for clause in stage.get("entrants", []):
		var rule := str(clause.get("rule", ""))
		var from_stage := str(clause.get("from", ""))
		var rows := table
		var clause_groups := groups
		var decided := {}
		if sources.has(from_stage):
			var source: Dictionary = sources[from_stage]
			rows = source.get("table", table)
			clause_groups = source.get("groups", [])
			decided = source.get("decided", {})
		if rule.begins_with("losers"):
			_append_one(str(decided.get("loser", "")), result, named)
		elif rule == "winner":
			_append_one(str(decided.get("winner", "")), result, named)
		elif rule == "all":
			for row in rows:
				var id := str(row.id)
				if not named.has(id):
					result.append(id)
					named[id] = true
		elif rule == "top":
			var count := int(clause.get("n", 0))
			var rank := int(clause.get("rank", 1))
			if bool(clause.get("per_group", false)) and not clause_groups.is_empty():
				for group in clause_groups:
					_take_top(group, count, rank, result, named)
			else:
				_take_top(rows, count, rank, result, named)
		elif rule == "rest":
			for row in rows:
				var id := str(row.id)
				if not named.has(id):
					result.append(id)
					named[id] = true
	return result


static func _append_one(club_id: String, result: Array, named: Dictionary) -> void:
	if club_id.is_empty() or named.has(club_id):
		return
	result.append(club_id)
	named[club_id] = true


static func _take_top(table: Array, count: int, rank: int, result: Array,
		named: Dictionary) -> void:
	var index := rank - 1
	var added := 0
	while index < table.size() and added < count:
		var id := str(table[index].id)
		if not named.has(id):
			result.append(id)
			named[id] = true
			added += 1
		index += 1


static func tiebreak(stage: Dictionary, format: Dictionary) -> Dictionary:
	# Competition default, stage override. Missing keys keep the classic rule:
	# extra time and penalties, away goals off, away goals counted in extra time.
	var rules := {
		"method": "extra_time_pens",
		"away_goals": false,
		"away_goals_extra_time": true,
	}
	_merge_tiebreak(rules, format.get("tiebreak"))
	_merge_tiebreak(rules, stage.get("tiebreak"))
	return rules


static func _merge_tiebreak(rules: Dictionary, value) -> void:
	if not (value is Dictionary):
		return
	for key in ["method", "away_goals", "away_goals_extra_time"]:
		if value.has(key):
			rules[key] = value[key]


static func build_stage(stage: Dictionary, entrants: Array, start_date: String,
		end_date := "", rules: Array = [], scope := "world",
		busy: Dictionary = {}, dates: Array = []) -> Array:
	var kind := str(stage.get("kind", ""))
	if kind == "league":
		return _schedule(entrants, start_date, end_date, stage, "", rules, scope,
			dates)
	if kind != "group":
		return []
	return _group_schedule(stage, entrants, start_date, end_date, rules, scope,
		busy, dates)


static func _group_schedule(stage: Dictionary, entrants: Array, start_date: String,
		end_date: String, rules: Array, scope: String, busy: Dictionary,
		dates: Array = []) -> Array:
	var sizes: Array = stage.get("groups", {}).get("sizes", [])
	var groups: Array = []
	var index := 0
	for size in sizes:
		var count := int(size)
		groups.append(entrants.slice(index, index + count))
		index += count
	if index < entrants.size():
		# The club pool can grow after the format was written: extra entrants join
		# the last group instead of disappearing from the season.
		if groups.is_empty():
			groups.append(entrants.slice(index))
		else:
			(groups[-1] as Array).append_array(entrants.slice(index))
	var rounds := int(stage.get("rounds", 0))
	var schedule = stage.get("schedule", {})
	var interzonal := 0
	if schedule is Dictionary:
		interzonal = int(schedule.get("interzonal", 0))
	var zone_rounds := rounds
	if interzonal > 0 and rounds > interzonal:
		zone_rounds = rounds - interzonal
	if dates.is_empty():
		dates = CareerCalendar.round_dates(start_date, end_date, rounds, rules,
			scope, busy)
	var stage_prefix := "%s:g" % str(stage.get("id", ""))
	var fixtures: Array = []
	for group_index in range(groups.size()):
		fixtures.append_array(_round_robin(groups[group_index], zone_rounds,
			dates, "%s%d:" % [stage_prefix, group_index], group_index))
	if interzonal > 0 and groups.size() >= 2:
		fixtures.append_array(_interzonal(groups[0], groups[1], interzonal,
			zone_rounds, dates, stage_prefix))
	return fixtures


static func _round_robin(ids: Array, rounds: int, dates: Array, prefix: String,
		group_index: int) -> Array:
	if ids.size() < 2 or rounds <= 0:
		return []
	var teams: Array = []
	for club_id in ids:
		teams.append(str(club_id))
	if teams.size() % 2 == 1:
		teams.append("")
	var rotation := teams.duplicate()
	var base: Array = []
	for base_index in range(rotation.size() - 1):
		var pairs: Array = []
		for index in range(rotation.size() / 2):
			var home = rotation[index]
			var away = rotation[rotation.size() - 1 - index]
			if home == "" or away == "":
				continue
			pairs.append([home, away])
		base.append(pairs)
		var next_rotation: Array = [rotation[0], rotation[-1]]
		next_rotation.append_array(rotation.slice(1, rotation.size() - 1))
		rotation = next_rotation
	var fixtures: Array = []
	for round_index in range(rounds):
		var base_index := round_index % base.size()
		var cycle := round_index / base.size()
		var date := str(dates[round_index]) if round_index < dates.size() else ""
		var pairs: Array = base[base_index]
		for match_index in range(pairs.size()):
			var home := str(pairs[match_index][0])
			var away := str(pairs[match_index][1])
			if cycle % 2 == 1:
				var swap = home
				home = away
				away = swap
			fixtures.append({
				"id": "%sr%02d-%02d" % [prefix, round_index + 1, match_index],
				"round": round_index + 1, "date": date,
				"home": home, "away": away, "group": group_index,
			})
	return fixtures


static func _interzonal(group_a: Array, group_b: Array, rounds: int,
		zone_rounds: int, dates: Array, prefix: String) -> Array:
	var first: Array = []
	var second: Array = []
	for club_id in group_a:
		first.append(str(club_id))
	for club_id in group_b:
		second.append(str(club_id))
	if first.is_empty() or second.is_empty():
		return []
	var fixtures: Array = []
	for cross in range(rounds):
		var round_no := zone_rounds + cross + 1
		var date := str(dates[round_no - 1]) if round_no - 1 < dates.size() else ""
		for index in range(mini(first.size(), second.size())):
			var home: String = str(first[index])
			var away: String = str(second[(index + cross) % second.size()])
			if cross % 2 == 1:
				var swap = home
				home = away
				away = swap
			fixtures.append({
				"id": "%sx%02d-%02d" % [prefix, round_no, index],
				"round": round_no, "date": date,
				"home": home, "away": away, "group": -1,
			})
	return fixtures


static func _schedule(ids: Array, start_date: String, end_date: String,
		stage: Dictionary, prefix: String, rules: Array, scope: String,
		dates: Array = []) -> Array:
	var rounds = stage.get("rounds")
	if dates.is_empty() and (rounds is int or rounds is float) and int(rounds) > 0:
		# A split season plays 17 rounds of the 34 a double round-robin holds, so
		# the dates are spread over its own rounds: otherwise half a season is
		# squeezed into twice as many match days and every club plays every other
		# day.
		dates = CareerCalendar.round_dates(start_date, end_date, int(rounds),
			rules, scope)
	var fixtures := CareerFactory.build_schedule(ids, start_date, end_date, rules,
		scope, dates)
	if rounds is int or rounds is float:
		var limit := int(rounds)
		var filtered: Array = []
		for fixture in fixtures:
			if int(fixture.get("round", 0)) <= limit:
				fixture["id"] = prefix + str(fixture.get("id", ""))
				filtered.append(fixture)
		return filtered
	for fixture in fixtures:
		fixture["id"] = prefix + str(fixture.get("id", ""))
	return fixtures


static func _add(row: Dictionary, goals_for: int, goals_against: int) -> void:
	row["played"] = int(row.played) + 1
	row["goals_for"] = int(row.goals_for) + goals_for
	row["goals_against"] = int(row.goals_against) + goals_against
	row["goal_difference"] = int(row.goals_for) - int(row.goals_against)
	if goals_for > goals_against:
		row["won"] = int(row.won) + 1
		row["points"] = int(row.points) + 3
	elif goals_for == goals_against:
		row["drawn"] = int(row.drawn) + 1
		row["points"] = int(row.points) + 1
	else:
		row["lost"] = int(row.lost) + 1


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.points) != int(b.points):
		return int(a.points) > int(b.points)
	if int(a.goal_difference) != int(b.goal_difference):
		return int(a.goal_difference) > int(b.goal_difference)
	if int(a.goals_for) != int(b.goals_for):
		return int(a.goals_for) > int(b.goals_for)
	return str(a.id) < str(b.id)
