class_name CareerContinental
extends RefCounted
# UEFA qualifying and league-phase resolution. It takes the season's berth map,
# plays the qualifying rounds as two-legged ties, sends the losers down the
# access list's drop-down rules, and resolves the 36-club league phase of each
# competition. The field is rebalanced to 36 when the published title-holder
# slots are not filled in the first career season.

const ROUNDS := ["q1", "q2", "q3", "playoff_round"]
const COMPETITIONS := ["ucl", "uel", "uecl"]
const LEAGUE_SIZE := 36

static var last_error := ""


static func build(catalog: TeamCatalog, berths: Dictionary, seed: int,
		title_holders: Dictionary = {}) -> Dictionary:
	last_error = ""
	var access = CareerBerths.access()
	var uefa = access.get("uefa", {})
	if not (uefa is Dictionary) or uefa.is_empty():
		last_error = "the UEFA access list is missing"
		return {}
	var suspended := {}
	for country in uefa.get("suspended", []):
		suspended[str(country)] = true
	var state := {}
	for comp in COMPETITIONS:
		state[comp] = {
			"direct": {}, "league": [], "winners": {}, "losers": {},
			"entrants": {}, "paths": {}, "fixtures": {}, "clubs": {},
		}
	for country in berths:
		if suspended.has(str(country)):
			continue
		var block = berths[country]
		if not (block is Dictionary):
			continue
		for entry in block.get("berths", []):
			if not (entry is Dictionary):
				continue
			var comp := str(entry.get("competition", ""))
			if not state.has(comp):
				continue
			var club_id := str(entry.get("club_id", ""))
			var slot := str(entry.get("entry", ""))
			var path := str(entry.get("path", ""))
			if path.is_empty():
				path = "main"
			if club_id.is_empty():
				continue
			state[comp]["clubs"][club_id] = true
			state[comp]["paths"][club_id] = path
			if slot == "league_phase":
				state[comp]["league"].append(club_id)
			else:
				var bucket: Dictionary = state[comp]["direct"].get(slot, {})
				var list: Array = bucket.get(path, [])
				list.append(club_id)
				bucket[path] = list
				state[comp]["direct"][slot] = bucket
	_apply_title_holders(state, title_holders)
	var ratings := {}
	for comp in COMPETITIONS:
		for club_id in state[comp]["clubs"]:
			ratings[str(club_id)] = float(
				catalog.load_team_rating(int(club_id)).get("average", 55.0))
	for comp in COMPETITIONS:
		_build_competition(comp, state, uefa, seed, ratings)
	var rebalanced := _rebalance_all(state, ratings)
	var result := {"competitions": {}, "rebalanced": rebalanced}
	for comp in COMPETITIONS:
		result["competitions"][comp] = {
			"league_phase": _unique(state[comp]["league"]),
			"rounds": _rounds_report(state[comp]),
		}
	return result


static func _apply_title_holders(state: Dictionary, holders: Dictionary) -> void:
	if holders.is_empty():
		return
	var used := {}
	for comp in COMPETITIONS:
		for club_id in state[comp]["clubs"]:
			used[str(club_id)] = true
	var ucl := str(holders.get("ucl", ""))
	var uel := str(holders.get("uel", ""))
	var uecl := str(holders.get("uecl", ""))
	if not ucl.is_empty() and not used.has(ucl):
		_add_to_league(state, "ucl", ucl)
		used[ucl] = true
	if not uel.is_empty() and not used.has(uel):
		_add_to_league(state, "ucl", uel)
		used[uel] = true
	if not uecl.is_empty() and not used.has(uecl):
		_add_to_league(state, "uel", uecl)


static func _add_to_league(state: Dictionary, comp: String, club_id: String) -> void:
	state[comp]["clubs"][club_id] = true
	state[comp]["paths"][club_id] = "main"
	state[comp]["league"].append(club_id)


static func _build_competition(comp: String, state: Dictionary, uefa: Dictionary,
		seed: int, ratings: Dictionary) -> void:
	for round in ROUNDS:
		var incoming := _drop_downs_into(comp, round, state, uefa)
		var direct: Dictionary = state[comp]["direct"].get(round, {})
		var paths := {}
		for path in direct:
			paths[str(path)] = true
		for path in incoming:
			paths[str(path)] = true
		var previous_round := _previous_round(round)
		if not previous_round.is_empty():
			for path in state[comp]["winners"].get(previous_round, {}):
				paths[str(path)] = true
		var winners_for_round := {}
		var losers_for_round := {}
		for path in paths:
			var entrants: Array = []
			for club_id in state[comp]["direct"].get(round, {}).get(path, []):
				entrants.append(str(club_id))
			if not previous_round.is_empty():
				for club_id in state[comp]["winners"].get(previous_round, {}).get(path, []):
					entrants.append(str(club_id))
			for club_id in incoming.get(path, []):
				entrants.append(str(club_id))
			for club_id in entrants:
				state[comp]["paths"][str(club_id)] = path
				state[comp]["clubs"][str(club_id)] = true
			if entrants.is_empty():
				continue
			state[comp]["entrants"][round] = state[comp]["entrants"].get(round, {})
			state[comp]["entrants"][round][path] = entrants
			var resolved := _play_tie(entrants, comp, round, path, seed, ratings)
			winners_for_round[path] = resolved.get("winners", [])
			losers_for_round[path] = resolved.get("losers", [])
			state[comp]["fixtures"]["%s:%s" % [round, path]] = resolved.get("fixtures", [])
		state[comp]["winners"][round] = winners_for_round
		state[comp]["losers"][round] = losers_for_round
	var league_incoming := _drop_downs_into(comp, "league_phase", state, uefa)
	for path in league_incoming:
		for club_id in league_incoming[path]:
			if not state[comp]["league"].has(str(club_id)):
				state[comp]["league"].append(str(club_id))
	var playoff_winners: Dictionary = state[comp]["winners"].get("playoff_round", {})
	for path in playoff_winners:
		for winner in playoff_winners[path]:
			if not state[comp]["league"].has(str(winner)):
				state[comp]["league"].append(str(winner))


static func _play_tie(entrants: Array, comp: String, round: String, path: String,
		seed: int, ratings: Dictionary) -> Dictionary:
	var stage := {"rounds": [{"name": "tie", "legs": 2}]}
	var prefix := "%s:%s:%s:" % [comp, round, path]
	var fixtures := CareerBrackets.round_fixtures(stage, 0, entrants, [], prefix)
	var results := {}
	for fixture in fixtures:
		results[str(fixture.get("id", ""))] = CareerSeason.simulate(seed, fixture,
			ratings)
	results = CareerBrackets.settle_ties(entrants, fixtures, results, seed)
	var winners := CareerBrackets.round_winners(entrants, fixtures, results)
	var losers: Array = []
	for row in CareerBrackets.tie_results(entrants, fixtures, results):
		if bool(row.get("bye", false)):
			continue
		var winner := _winner_of(row, results)
		if winner.is_empty():
			continue
		for club_id in [row.get("first", ""), row.get("second", "")]:
			if str(club_id) != winner and not str(club_id).is_empty():
				losers.append(str(club_id))
	return {"winners": winners, "losers": losers, "fixtures": fixtures}


static func _winner_of(row: Dictionary, results: Dictionary) -> String:
	var first := str(row.get("first", ""))
	var second := str(row.get("second", ""))
	if int(row.get("first_goals", 0)) > int(row.get("second_goals", 0)):
		return first
	if int(row.get("second_goals", 0)) > int(row.get("first_goals", 0)):
		return second
	var last_result: Dictionary = row.get("last_result", {})
	var decided := str(last_result.get("decided_by", ""))
	if decided == "away_goals":
		return first if int(row.get("first_away", 0)) > int(row.get("second_away", 0)) \
			else second
	var pens = last_result.get("pens")
	if pens is Dictionary:
		var home_pens := int(pens.get("home", 0))
		var away_pens := int(pens.get("away", 0))
		return str(row.get("last_home", "")) if home_pens > away_pens \
			else str(row.get("last_away", ""))
	return first


static func _drop_downs_into(comp: String, round: String, state: Dictionary,
		uefa: Dictionary) -> Dictionary:
	var incoming := {}
	for rule in uefa.get("drop_downs", []):
		if str(rule.get("to", "")).to_lower() != comp:
			continue
		if str(rule.get("entry", "")) != round:
			continue
		var source := str(rule.get("from", "")).to_lower()
		if not state.has(source):
			continue
		var source_round := str(rule.get("round", ""))
		var path_from := str(rule.get("path_from", ""))
		var target_path := str(rule.get("path", ""))
		if target_path.is_empty():
			target_path = "main"
		var count := int(rule.get("count", 0))
		var taken := 0
		var losers: Dictionary = state[source]["losers"].get(source_round, {})
		for loser_path in losers:
			if not path_from.is_empty() and str(loser_path) != path_from:
				continue
			for club_id in losers[loser_path]:
				if count > 0 and taken >= count:
					break
				var list: Array = incoming.get(target_path, [])
				if not list.has(str(club_id)):
					list.append(str(club_id))
					incoming[target_path] = list
					taken += 1
			if count > 0 and taken >= count:
				break
	return incoming


static func _previous_round(round: String) -> String:
	var index := ROUNDS.find(round)
	if index <= 0:
		return ""
	return ROUNDS[index - 1]


static func _rebalance_all(state: Dictionary, ratings: Dictionary) -> Dictionary:
	var used := {}
	for comp in COMPETITIONS:
		for club_id in state[comp]["league"]:
			used[str(club_id)] = true
	var changed := {}
	for comp in COMPETITIONS:
		var league: Array = state[comp]["league"]
		var count := 0
		if league.size() > LEAGUE_SIZE:
			league.sort_custom(func(a: String, b: String) -> bool:
				return float(ratings.get(a, 55.0)) < float(ratings.get(b, 55.0)))
			while league.size() > LEAGUE_SIZE:
				var removed := str(league.pop_back())
				used.erase(removed)
				count += 1
		elif league.size() < LEAGUE_SIZE:
			var pool: Array = []
			for club_id in state[comp]["clubs"]:
				if not used.has(str(club_id)):
					pool.append(str(club_id))
			pool.sort_custom(func(a: String, b: String) -> bool:
				if not is_equal_approx(float(ratings.get(a, 55.0)),
						float(ratings.get(b, 55.0))):
					return float(ratings.get(a, 55.0)) > float(ratings.get(b, 55.0))
				return a < b)
			for club_id in pool:
				if league.size() >= LEAGUE_SIZE:
					break
				if used.has(club_id):
					continue
				league.append(club_id)
				used[club_id] = true
				count += 1
		state[comp]["league"] = league
		changed[comp] = count
	return changed


static func table(career: Career, competition: String) -> Array:
	var fixtures: Array = []
	var ids := {}
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) != competition \
				or str(fixture.get("stage", "")) != competition:
			continue
		fixtures.append(fixture)
		ids[str(fixture.get("home", ""))] = true
		ids[str(fixture.get("away", ""))] = true
	var club_ids := ids.keys()
	club_ids.sort()
	return CareerStages.table(fixtures, career.results, club_ids)


static func finish(catalog: TeamCatalog, career: Career, block: Dictionary,
		seed: int) -> Dictionary:
	# Resolve every European competition of a finished season: use the career's
	# own league-phase table where it was played, simulate the others from their
	# fields, then play the knockout. The winners and the season's coefficient
	# points are stored in the block; the five-season table rolls forward.
	if block.is_empty():
		return {}
	var focus := CareerCompetitions._focus_competition(block, career.club_id)
	var rules := {"method": "extra_time_pens", "away_goals": false}
	var champions := {}
	var runners_up := {}
	var season_points := {}
	for comp in COMPETITIONS:
		var competition: Dictionary = block.get("competitions", {}).get(comp, {})
		var field: Array = competition.get("league_phase", [])
		if field.size() != LEAGUE_SIZE:
			continue
		var table_rows: Array = []
		var league_fixtures: Array = []
		var league_results: Dictionary = career.results
		var knockout_rounds: Array = []
		var champion := str(competition.get("champion", ""))
		if comp == focus:
			table_rows = table(career, comp)
			league_fixtures = _career_stage(career, comp, comp)
			knockout_rounds = _career_rounds(career, comp)
			if champion.is_empty():
				var played := _play_knockout(catalog, table_rows, seed, rules)
				if played.is_empty():
					continue
				champion = str(played.get("winner", ""))
				knockout_rounds = played.get("rounds", [])
				competition["knockout"] = knockout_rounds
		else:
			var simulated := _simulated_table(catalog, competition, field, seed, comp)
			table_rows = simulated.get("table", [])
			league_fixtures = simulated.get("fixtures", [])
			league_results = simulated.get("results", {})
			var played := _play_knockout(catalog, table_rows, seed, rules)
			if played.is_empty():
				continue
			champion = str(played.get("winner", ""))
			knockout_rounds = played.get("rounds", [])
			competition["knockout"] = knockout_rounds
		if champion.is_empty():
			continue
		champions[comp] = champion
		runners_up[comp] = _runner_up(champion, knockout_rounds)
		_award_points(comp, table_rows, league_fixtures, league_results,
			knockout_rounds, season_points)
	block["champions"] = champions
	block["runners_up"] = runners_up
	if not season_points.is_empty():
		var table_data = career.data.get("coefficients", {})
		if not (table_data is Dictionary) or (table_data as Dictionary).is_empty():
			table_data = CareerCoefficients.table()
		career.data["coefficients"] = CareerCoefficients.roll(table_data,
			season_points)
		block["season_points"] = season_points
	return champions


static func _play_knockout(catalog: TeamCatalog, table_rows: Array, seed: int,
		rules: Dictionary) -> Dictionary:
	if table_rows.size() < 24:
		return {}
	var ordered: Array = []
	for row in table_rows:
		ordered.append(str(row.get("id", "")))
	return CareerKnockout.play(catalog, ordered, seed, rules)


static func _career_stage(career: Career, competition: String, stage: String) -> Array:
	var rows: Array = []
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) == competition \
				and str(fixture.get("stage", "")) == stage:
			rows.append(fixture)
	return rows


static func _career_rounds(career: Career, comp: String) -> Array:
	var names := {1: "playoff", 2: "r16", 3: "qf", 4: "semi", 5: "final"}
	var rounds: Array = []
	for stage_round in range(1, 6):
		var fixtures: Array = []
		for fixture in career.schedule:
			if str(fixture.get("stage", "")) == "euro:" + comp \
					and int(fixture.get("stage_round", 0)) == stage_round:
				fixtures.append(fixture)
		if fixtures.is_empty():
			continue
		rounds.append({
			"name": str(names[stage_round]),
			"fixtures": fixtures,
			"results": career.results,
		})
	return rounds


static func _runner_up(champion: String, knockout_rounds: Array) -> String:
	if knockout_rounds.is_empty():
		return ""
	var final_round: Dictionary = knockout_rounds[-1]
	var fixtures: Array = final_round.get("fixtures", [])
	if fixtures.is_empty():
		return ""
	var final: Dictionary = fixtures[0]
	var home := str(final.get("home", ""))
	var away := str(final.get("away", ""))
	if home == champion:
		return away
	if away == champion:
		return home
	return ""


static func _award_points(comp: String, table_rows: Array, league_fixtures: Array,
		league_results: Dictionary, knockout_rounds: Array,
		season_points: Dictionary) -> void:
	var ranks := {}
	for index in range(table_rows.size()):
		ranks[str((table_rows[index] as Dictionary).get("id", ""))] = index + 1
	var stats := {}
	for fixture in league_fixtures:
		_add_result(stats, fixture, league_results)
	for round in knockout_rounds:
		var name := str((round as Dictionary).get("name", ""))
		if name == "playoff":
			continue
		var round_results: Dictionary = (round as Dictionary).get("results", {})
		for fixture in (round as Dictionary).get("fixtures", []):
			_add_result(stats, fixture, round_results)
			for club_id in [str(fixture.get("home", "")), str(fixture.get("away", ""))]:
				var row: Dictionary = stats.get(club_id, {"wins": 0, "draws": 0,
					"reached": {}})
				(row["reached"] as Dictionary)[name] = true
				stats[club_id] = row
	for club_id in ranks:
		var row: Dictionary = stats.get(club_id, {"wins": 0, "draws": 0,
			"reached": {}})
		var points := CareerCoefficients.season_points(comp, int(ranks[club_id]),
			int(row.get("wins", 0)), int(row.get("draws", 0)),
			row.get("reached", {}))
		season_points[club_id] = float(season_points.get(club_id, 0.0)) + points


static func _add_result(stats: Dictionary, fixture: Dictionary,
		results: Dictionary) -> void:
	var result = results.get(str(fixture.get("id", "")))
	if not (result is Dictionary):
		return
	var home := str(fixture.get("home", ""))
	var away := str(fixture.get("away", ""))
	var home_goals := int(result.get("home", 0))
	var away_goals := int(result.get("away", 0))
	var home_row: Dictionary = stats.get(home, {"wins": 0, "draws": 0, "reached": {}})
	var away_row: Dictionary = stats.get(away, {"wins": 0, "draws": 0, "reached": {}})
	if home_goals > away_goals:
		home_row["wins"] = int(home_row.get("wins", 0)) + 1
	elif home_goals < away_goals:
		away_row["wins"] = int(away_row.get("wins", 0)) + 1
	else:
		home_row["draws"] = int(home_row.get("draws", 0)) + 1
		away_row["draws"] = int(away_row.get("draws", 0)) + 1
	stats[home] = home_row
	stats[away] = away_row


static func _simulated_table(catalog: TeamCatalog, competition: Dictionary,
		field: Array, seed: int, comp: String) -> Dictionary:
	var fixtures: Array = []
	var draw: Array = competition.get("draw", [])
	var rounds := int(competition.get("round_count", 8))
	if not draw.is_empty():
		var per_round := maxi(1, draw.size() / rounds)
		for index in range(draw.size()):
			var row: Dictionary = draw[index]
			fixtures.append({
				"id": "sim:%s:%02d-%02d" % [comp, index / per_round, index % per_round],
				"home": str(row.get("home", "")),
				"away": str(row.get("away", "")),
				"round": index / per_round + 1, "stage_round": index / per_round + 1,
			})
	else:
		var drawn := CareerDraw.league_phase(catalog, field, seed, comp,
			competition.get("coefficients", {}))
		for index in range(drawn.size()):
			var row: Dictionary = drawn[index]
			fixtures.append({
				"id": "sim:%s:%03d" % [comp, index],
				"home": str(row.get("home", "")),
				"away": str(row.get("away", "")),
				"round": index / 18 + 1, "stage_round": index / 18 + 1,
			})
	var ratings := {}
	for club_id in field:
		ratings[str(club_id)] = float(
			catalog.load_team_rating(int(club_id)).get("average", 55.0))
	var results := {}
	for fixture in fixtures:
		results[str(fixture.get("id", ""))] = CareerSeason.simulate(seed, fixture, ratings)
	return {
		"table": CareerStages.table(fixtures, results, field),
		"fixtures": fixtures,
		"results": results,
	}


static func _rounds_report(state: Dictionary) -> Dictionary:
	var report := {}
	for round in state.get("entrants", {}):
		report[str(round)] = {}
		for path in state["entrants"][round]:
			report[str(round)][str(path)] = {
				"entrants": state["entrants"][round][path],
				"winners": state.get("winners", {}).get(round, {}).get(path, []),
				"losers": state.get("losers", {}).get(round, {}).get(path, []),
			}
	return report


static func _unique(values: Array) -> Array:
	var seen := {}
	var result: Array = []
	for value in values:
		var key := str(value)
		if seen.has(key):
			continue
		seen[key] = true
		result.append(key)
	return result
