class_name CareerCompetitions
extends RefCounted
# Non-league competitions in the career save. A cup is installed next to the
# primary league: its field is resolved once, the league and cup match days are
# planned together with a rest rule, and the bracket grows round by round.

const RECORDS_PATH := "res://assets/data/competitions.json"
const REST_DAYS := 3
const LEAGUE_PRIORITY := 3
const CUP_PRIORITY := 1
const SUPER_PRIORITY := 4
const EURO_PRIORITY := 5
const EURO_ROUNDS := 8

static var last_error := ""
static var _records: Dictionary = {}


static func records() -> Dictionary:
	if _records.is_empty():
		if not FileAccess.file_exists(RECORDS_PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
		if raw is Dictionary and raw.get("competitions") is Dictionary:
			_records = raw["competitions"]
	return _records


static func build_season(catalog: TeamCatalog, league_id: String, club_ids: Array,
		season_start: String, history: Dictionary = {},
		continental: Dictionary = {}, focus_club: String = "",
		seed: int = 0) -> Dictionary:
	# The league is planned first, cups after it; both obey the rest rule, so a
	# cup never lands next to a league round. A country without cup data keeps
	# the old league-only schedule untouched.
	last_error = ""
	var league := catalog.league_by_id(league_id)
	var country_name := str(catalog.country_by_id(
		int(league.get("country_id", 0))).get("name", ""))
	var entries: Array = [{
		"id": league_id, "kind": "league", "role": "primary",
		"label": str(league.get("name", league_id)),
	}]
	var requests: Array = []
	var format = LeagueRegulations.record(league_id).get("format")
	if format is Dictionary:
		var stages := CareerStages.stages(format)
		var window := LeagueRegulations.window_for_season(league_id, season_start)
		var windows := CareerFactory._stage_windows(format, season_start,
			str(window.get("start", season_start)), str(window.get("end", "")))
		for index in range(stages.size()):
			var stage: Dictionary = stages[index]
			if not _stage_all(stage):
				continue
			var stage_window: Dictionary = windows[index]
			requests.append({
				"id": str(stage.get("id", "")), "priority": LEAGUE_PRIORITY,
				"start": str(stage_window.get("start", season_start)),
				"end": str(stage_window.get("end", season_start)),
				"days": CareerFactory._match_days(stage),
			})
	else:
		var window := LeagueRegulations.window_for_season(league_id, season_start)
		# A club list with an odd size gets a bye slot, so the double
		# round-robin has 2 * n rounds, not 2 * (n - 1); planning fewer dates
		# left the last rounds without a day of their own.
		var slots: int = int(club_ids.size()) + int(club_ids.size()) % 2
		requests.append({
			"id": "league", "priority": LEAGUE_PRIORITY,
			"start": str(window.get("start", season_start)),
			"end": str(window.get("end", season_start)),
			"days": maxi(0, 2 * (slots - 1)),
		})

	var year := int(CareerSearch.date_parts(season_start)[0])
	for competition_id in records():
		var record: Dictionary = records()[competition_id]
		if str(record.get("country", "")) != country_name:
			continue
		var kind := str(record.get("kind", "cup"))
		if kind == "super_cup":
			var super_entry := _super_entry(record, competition_id, history, league)
			if super_entry.is_empty():
				continue
			entries.append(super_entry)
			var super_window := CareerCalendar.season_window(
				str(record.get("start_md", "")), str(record.get("end_md", "")),
				season_start)
			requests.append({
				"id": str(competition_id), "priority": SUPER_PRIORITY,
				"start": str(super_window[0]), "end": str(super_window[1]),
				"days": _total_days(super_entry.get("rounds", [])),
			})
			continue
		if kind != "cup":
			continue
		if not _tier_allowed(league, record.get("tiers", [])):
			continue
		var field := _field(catalog, league, record.get("tiers", []))
		if field.size() < 2:
			continue
		var rounds := _rounds(field.size(), record)
		var cup_window := CareerCalendar.season_window(
			str(record.get("start_md", "")), str(record.get("end_md", "")),
			season_start)
		var start := str(cup_window[0])
		var end := str(cup_window[1])
		var entry := {
			"id": str(competition_id), "kind": "cup",
			"label": str(record.get("label", competition_id)),
			"country": str(record.get("country", "")),
			"entrants": field, "rounds": rounds, "winner": null,
			"runner_up": null, "tiebreak": record.get("tiebreak", {}), "dates": [],
		}
		entries.append(entry)
		requests.append({
			"id": str(competition_id), "priority": CUP_PRIORITY,
			"start": start, "end": end, "days": _total_days(rounds),
		})

	var euro_comp := _focus_competition(continental, focus_club)
	if not euro_comp.is_empty():
		var window := _euro_window(season_start)
		var comp_block: Dictionary = continental.get("competitions", {}).get(
			euro_comp, {})
		requests.append({
			"id": "euro:" + euro_comp, "priority": EURO_PRIORITY,
			"start": str(window.get("start", season_start)),
			"end": str(window.get("end", season_start)),
			"days": _euro_rounds(comp_block, euro_comp),
		})
	var plan := {}
	if requests.size() > 1:
		plan = CareerCalendar.joint_plan(requests, IntlCalendar.rules(), "world",
			REST_DAYS)
	var built := CareerFactory.season_schedule(league_id, club_ids, season_start, plan)
	var schedule: Array = built.get("schedule", [])
	var base := _round_base(schedule, league_id)
	for entry in entries:
		if str(entry.get("kind", "")) == "league":
			continue
		entry["dates"] = plan.get(str(entry.get("id", "")), [])
		_append_round(schedule, entry, 0, entry.get("entrants", []), base)
	if not euro_comp.is_empty():
		var dates = plan.get("euro:" + euro_comp, [])
		var comp_block: Dictionary = continental.get("competitions", {}).get(
			euro_comp, {})
		schedule.append_array(_euro_fixtures(catalog, comp_block, euro_comp,
			dates, base, seed))
	_sort(schedule)
	return {
		"schedule": schedule,
		"stages_generated": built.get("stages_generated", {}),
		"competitions": entries,
	}


static func ensure(career: Career) -> void:
	var entries = career.data.get("competitions")
	if not (entries is Array):
		return
	var changed := false
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if str(entry.get("kind", "")) not in ["cup", "super_cup"]:
			continue
		if _ensure_cup(career, entry):
			changed = true
	if changed:
		_sort(career.schedule)


static func winner_of(career: Career, competition_id: String) -> String:
	var entries = career.data.get("competitions")
	if not (entries is Array):
		return ""
	for entry in entries:
		if str(entry.get("id", "")) == competition_id:
			return str(entry.get("winner", ""))
	return ""


static func simulate_cup(catalog: TeamCatalog, record: Dictionary, cup_id: String,
		seed: int) -> Dictionary:
	# A background cup: the same bracket and tie-break as a career cup, but all
	# rounds are played at once. Used to find every association's cup winner for
	# the European berths.
	var country_id := _country_id(catalog, str(record.get("country", "")))
	if country_id <= 0:
		return {}
	var field := _field_for_record(catalog, country_id, record)
	if field.size() < 2:
		return {}
	var rounds := _rounds(field.size(), record)
	var entrants := field
	var results := {}
	var stage := {"rounds": rounds}
	var runner := ""
	var strengths := {}
	for club_id in field:
		strengths[str(club_id)] = float(
			catalog.load_team_rating(int(club_id)).get("average", 55.0))
	for index in range(rounds.size()):
		var fixtures := CareerBrackets.round_fixtures(stage, index, entrants, [],
			"%s:" % cup_id)
		if fixtures.is_empty():
			break
		for fixture in fixtures:
			results[str(fixture.get("id", ""))] = \
				CareerSeason.simulate(seed, fixture, strengths)
		results = CareerBrackets.settle_ties(entrants, fixtures, results, seed,
			record.get("tiebreak", {}))
		var winners := CareerBrackets.round_winners(entrants, fixtures, results)
		if winners.size() <= 1:
			for club_id in entrants:
				if str(club_id) != str(winners[0]):
					runner = str(club_id)
					break
			entrants = winners
			break
		entrants = winners
	if entrants.is_empty():
		return {}
	return {"winner": str(entrants[0]), "runner_up": runner}


static func _country_id(catalog: TeamCatalog, country: String) -> int:
	for item in catalog.countries():
		if str(item.get("name", "")) == country:
			return int(item.get("id", 0))
	return 0


static func _field_for_record(catalog: TeamCatalog, country_id: int,
		record: Dictionary) -> Array:
	var allowed := {}
	for tier in record.get("tiers", []):
		allowed[int(tier)] = true
	var target := int(record.get("field_size", 0))
	var ids := {}
	var leagues: Array = []
	for item in catalog.career_leagues():
		if int(item.get("country_id", 0)) == country_id:
			leagues.append(item)
	leagues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("tier", 0)) < int(b.get("tier", 0)))
	for item in leagues:
		if not allowed.is_empty() and not allowed.has(int(item.get("tier", 0))):
			continue
		for team in catalog.all_teams_for_league(str(item.get("id", ""))):
			ids[str(team.get("id", ""))] = true
		if allowed.is_empty() and target > 0 and ids.size() >= target:
			break
	if ids.is_empty():
		# Liechtenstein's clubs play in the Swiss leagues; the team's own country
		# is the only way to find them.
		for club in catalog.career_clubs():
			if int(club.get("country_id", 0)) == country_id:
				ids[str(club.get("id", ""))] = true
	var field := ids.keys()
	field.sort()
	return field


static func _ensure_cup(career: Career, entry: Dictionary) -> bool:
	var rounds: Array = entry.get("rounds", [])
	var competition_id := str(entry.get("id", ""))
	var index := 0
	while index < rounds.size():
		if _round_fixtures(career, competition_id, index + 1).is_empty():
			break
		index += 1
	if index >= rounds.size():
		_set_winner(career, entry)
		return false
	if index > 0:
		var previous := _round_fixtures(career, competition_id, index)
		if previous.is_empty() or not _all_played(career, previous):
			return false
	var entrants := _entrants(career, entry, index)
	if entrants.is_empty():
		return false
	_append_round(career.schedule, entry, index, entrants,
		_round_base(career.schedule, career.league_id))
	return true


static func _super_entry(record: Dictionary, competition_id: String,
		history: Dictionary, league: Dictionary) -> Dictionary:
	if int(league.get("tier", 0)) != int(record.get("league_tier", 1)):
		return {}
	if not str(history.get("league_id", "")).is_empty() \
			and str(history.get("league_id", "")) != str(league.get("id", "")):
		return {}
	var teams := int(record.get("teams", 2))
	var entrants := _super_entrants(record, history)
	if entrants.size() < teams:
		return {}
	var legs := maxi(1, int(record.get("final_legs", 1)))
	var rounds: Array = [{"name": "final", "legs": legs}]
	if teams >= 4:
		rounds = [{"name": "semi", "legs": 1}, {"name": "final", "legs": 1}]
	return {
		"id": str(competition_id), "kind": "super_cup",
		"label": str(record.get("label", competition_id)),
		"country": str(record.get("country", "")),
		"entrants": entrants, "rounds": rounds, "winner": null,
		"runner_up": null, "tiebreak": record.get("tiebreak", {}), "dates": [],
	}


static func _super_entrants(record: Dictionary, history: Dictionary) -> Array:
	var teams := int(record.get("teams", 2))
	var rows = history.get("league_rows", [])
	var cups = history.get("cups", [])
	var season_start := str(history.get("season_start", ""))
	var cup: Dictionary = {}
	if cups is Array:
		for item in cups:
			if not (item is Dictionary):
				continue
			if str(item.get("id", "")) != str(record.get("cup", "")):
				continue
			if not season_start.is_empty() \
					and str(item.get("season_start", "")) != season_start:
				continue
			cup = item
			break
	var result: Array = []
	if rows is Array and not rows.is_empty():
		_append_id(result, str((rows[0] as Dictionary).get("club_id", "")))
	if teams >= 4 and rows is Array and rows.size() >= 2:
		_append_id(result, str((rows[1] as Dictionary).get("club_id", "")))
	if not cup.is_empty():
		_append_id(result, str(cup.get("winner", "")))
		_append_id(result, str(cup.get("runner_up", "")))
	if rows is Array:
		for row in rows:
			if result.size() >= teams:
				break
			_append_id(result, str((row as Dictionary).get("club_id", "")))
	if result.size() < teams:
		return []
	return result.slice(0, teams)


static func _append_id(result: Array, club_id: String) -> void:
	if club_id.is_empty() or result.has(club_id):
		return
	result.append(club_id)


static func _append_round(schedule: Array, entry: Dictionary, index: int,
		entrants: Array, base: int) -> void:
	var stage := {"rounds": entry.get("rounds", [])}
	var competition_id := str(entry.get("id", ""))
	var dates := _round_dates(entry, index)
	var fixtures := CareerBrackets.round_fixtures(stage, index, entrants, dates,
		"%s:" % competition_id)
	for fixture in fixtures:
		fixture["stage"] = competition_id
		fixture["stage_round"] = index + 1
		fixture["competition"] = competition_id
		fixture["round"] = base + index + 1
		schedule.append(fixture)


static func _round_base(schedule: Array, league_id: String) -> int:
	var base := 0
	for fixture in schedule:
		var competition := str(fixture.get("competition", ""))
		if not competition.is_empty() and competition != league_id:
			continue
		base = maxi(base, int(fixture.get("round", 0)))
	return base


static func _entrants(career: Career, entry: Dictionary, index: int) -> Array:
	if index == 0:
		var field = entry.get("entrants", [])
		return field if field is Array else []
	if not (career.data.get("results") is Dictionary):
		career.data["results"] = {}
	var previous := _entrants(career, entry, index - 1)
	var fixtures := _round_fixtures(career, str(entry.get("id", "")), index)
	career.data["results"] = CareerBrackets.settle_ties(previous, fixtures,
		career.results, career.seed, entry.get("tiebreak", {}))
	return CareerBrackets.round_winners(previous, fixtures, career.results)


static func _set_winner(career: Career, entry: Dictionary) -> void:
	var rounds: Array = entry.get("rounds", [])
	if rounds.is_empty():
		return
	var last := rounds.size() - 1
	var fixtures := _round_fixtures(career, str(entry.get("id", "")), last + 1)
	if fixtures.is_empty() or not _all_played(career, fixtures):
		return
	var entrants := _entrants(career, entry, last)
	career.data["results"] = CareerBrackets.settle_ties(entrants, fixtures,
		career.results, career.seed, entry.get("tiebreak", {}))
	var winners := CareerBrackets.round_winners(entrants, fixtures, career.results)
	if not winners.is_empty():
		entry["winner"] = str(winners[0])
		for club_id in entrants:
			if str(club_id) != str(winners[0]):
				entry["runner_up"] = str(club_id)
				break


static func _round_fixtures(career: Career, competition_id: String,
		stage_round: int) -> Array:
	var fixtures: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == competition_id \
				and int(fixture.get("stage_round", 0)) == stage_round:
			fixtures.append(fixture)
	return fixtures


static func _all_played(career: Career, fixtures: Array) -> bool:
	for fixture in fixtures:
		if not career.results.has(str(fixture.get("id", ""))):
			return false
	return true


static func _round_dates(entry: Dictionary, index: int) -> Array:
	var rounds: Array = entry.get("rounds", [])
	var all_dates = entry.get("dates", [])
	var offset := 0
	for round_index in range(index):
		offset += int((rounds[round_index] as Dictionary).get("legs", 1))
	var legs := int((rounds[index] as Dictionary).get("legs", 1))
	var dates: Array = []
	for leg in range(legs):
		if offset + leg < (all_dates as Array).size():
			dates.append(str(all_dates[offset + leg]))
	return dates


static func _rounds(count: int, record: Dictionary) -> Array:
	var size := CareerBrackets.bracket_size(count)
	var two_legged = record.get("two_legged", [])
	var rounds: Array = []
	while size >= 2:
		var name := "r%d" % size
		if size == 8:
			name = "qf"
		elif size == 4:
			name = "semi"
		elif size == 2:
			name = "final"
		var legs := 1
		if name == "final":
			legs = maxi(1, int(record.get("final_legs", 1)))
		elif two_legged is Array and two_legged.has(name):
			legs = 2
		rounds.append({"name": name, "legs": legs})
		size /= 2
	return rounds


static func _total_days(rounds: Array) -> int:
	var days := 0
	for spec in rounds:
		days += int((spec as Dictionary).get("legs", 1))
	return days


static func _stage_all(stage: Dictionary) -> bool:
	var clauses = stage.get("entrants", [])
	return clauses is Array and (clauses as Array).size() == 1 \
		and str((clauses as Array)[0].get("rule", "")) == "all"


static func _field(catalog: TeamCatalog, league: Dictionary, tiers: Array) -> Array:
	var allowed := {}
	for tier in tiers:
		allowed[int(tier)] = true
	var clubs := {}
	for item in catalog.career_leagues():
		if int(item.get("country_id", 0)) != int(league.get("country_id", 0)):
			continue
		if not allowed.is_empty() and not allowed.has(int(item.get("tier", 0))):
			continue
		for team in catalog.all_teams_for_league(str(item.get("id", ""))):
			var team_id := str(team.get("id", ""))
			clubs[team_id] = {
				"id": team_id, "tier": int(item.get("tier", 0)),
				"rating": float(catalog.load_team_rating(int(team_id)).get("average", 0.0)),
			}
	var rows: Array = clubs.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tier) != int(b.tier):
			return int(a.tier) < int(b.tier)
		if not is_equal_approx(float(a.rating), float(b.rating)):
			return float(a.rating) > float(b.rating)
		return str(a.id) < str(b.id))
	var field: Array = []
	for row in rows:
		field.append(str(row.id))
	return field


static func _tier_allowed(league: Dictionary, tiers: Array) -> bool:
	if tiers.is_empty():
		return true
	for tier in tiers:
		if int(tier) == int(league.get("tier", 0)):
			return true
	return false


static func _focus_competition(continental: Dictionary, club_id: String) -> String:
	if club_id.is_empty():
		return ""
	var competitions: Dictionary = continental.get("competitions", {})
	for comp in ["CL", "EL", "UCOL"]:
		var block: Dictionary = competitions.get(comp, {})
		if (block.get("league_phase", []) as Array).has(club_id):
			return comp
	return ""


static func _euro_window(season_start: String) -> Dictionary:
	var uefa = CareerBerths.access().get("uefa", {})
	var windows = uefa.get("windows", {})
	var league = windows.get("league_phase", {})
	var year := int(CareerSearch.date_parts(season_start)[0])
	var reference := str(season_start).substr(5)
	return {
		"start": CareerCalendar.stage_date(year,
			str(league.get("start_md", "09-15")), reference),
		"end": CareerCalendar.stage_date(year,
			str(league.get("end_md", "01-31")), reference),
	}


static func _euro_rounds(block: Dictionary, comp: String) -> int:
	var count := int(block.get("round_count", 0))
	if count > 0:
		return count
	return 6 if comp == "UCOL" else EURO_ROUNDS


static func _euro_fixtures(catalog: TeamCatalog, block: Dictionary, comp: String,
		dates: Array, base: int, seed: int = 0) -> Array:
	var clubs: Array = block.get("league_phase", [])
	var real: Array = block.get("draw", [])
	var rounds := _euro_rounds(block, comp)
	if not real.is_empty():
		var substitutions: Dictionary = block.get("substitutions", {})
		var per_round := maxi(1, real.size() / rounds)
		var drawn: Array = []
		for index in range(real.size()):
			var row: Dictionary = real[index]
			var home := str(substitutions.get(str(row.get("home", "")),
				str(row.get("home", ""))))
			var away := str(substitutions.get(str(row.get("away", "")),
				str(row.get("away", ""))))
			var round_index := mini(index / per_round, rounds - 1)
			drawn.append({
				"id": "%s:l%02d-%02d" % [comp, round_index + 1, index % per_round],
				"round": base + round_index + 1, "stage_round": round_index + 1,
				"date": str(dates[round_index]) if round_index < dates.size() else "",
				"home": home, "away": away,
				"stage": comp, "competition": comp, "group": -1,
			})
		return drawn
	var teams: Array = []
	var seen := {}
	for club_id in clubs:
		var key := str(club_id)
		if not seen.has(key):
			seen[key] = true
			teams.append(key)
	if teams.size() < 2:
		return []
	if teams.size() == 36:
		var drawn := CareerDraw.league_phase(catalog, teams, seed, comp,
			block.get("coefficients", {}))
		if drawn.size() == 18 * rounds:
			var fixtures: Array = []
			for index in range(drawn.size()):
				var round_index := index / 18
				var date := str(dates[round_index]) if round_index < dates.size() else ""
				var fixture: Dictionary = drawn[index]
				fixtures.append({
					"id": "%s:l%02d-%02d" % [comp, round_index + 1, index % 18],
					"round": base + round_index + 1, "stage_round": round_index + 1,
					"date": date, "home": str(fixture.get("home", "")),
					"away": str(fixture.get("away", "")),
					"stage": comp, "competition": comp, "group": -1,
				})
			return fixtures
	teams.sort_custom(func(a: String, b: String) -> bool:
		var left := float(catalog.load_team_rating(int(a)).get("average", 55.0))
		var right := float(catalog.load_team_rating(int(b)).get("average", 55.0))
		if not is_equal_approx(left, right):
			return left > right
		return a < b)
	if teams.size() % 2 == 1:
		teams.append("")
	var rotation := teams.duplicate()
	var home_count := {}
	for club_id in teams:
		home_count[club_id] = 0
	var fixtures: Array = []
	var target_home := rounds / 2
	for round in range(rounds):
		var date := str(dates[round]) if round < dates.size() else ""
		for index in range(rotation.size() / 2):
			var first := str(rotation[index])
			var second := str(rotation[rotation.size() - 1 - index])
			if first.is_empty() or second.is_empty():
				continue
			var home := first
			if int(home_count.get(first, 0)) > int(home_count.get(second, 0)):
				home = second
			var away := second if home == first else first
			home_count[home] = int(home_count.get(home, 0)) + 1
			fixtures.append({
				"id": "%s:l%02d-%02d" % [comp, round + 1, index],
				"round": base + round + 1, "stage_round": round + 1,
				"date": date, "home": home, "away": away,
				"stage": comp, "competition": comp, "group": -1,
			})
		var next: Array = [rotation[0], rotation[-1]]
		next.append_array(rotation.slice(1, rotation.size() - 1))
		rotation = next
	# The circle gives every club the right number of opponents; the orientation
	# is repaired so every club has an even home split.
	for guard in range(200):
		var over := ""
		var under := ""
		for club_id in teams:
			if not club_id.is_empty() and int(home_count.get(club_id, 0)) > target_home:
				over = club_id
				break
		for club_id in teams:
			if not club_id.is_empty() and int(home_count.get(club_id, 0)) < target_home:
				under = club_id
				break
		if over.is_empty() or under.is_empty():
			break
		var home_map := {}
		for fixture in fixtures:
			var home := str(fixture.get("home", ""))
			var list: Array = home_map.get(home, [])
			list.append(fixture)
			home_map[home] = list
		var path := _flip_path(over, under, home_map)
		if path.is_empty():
			break
		for fixture in path:
			var home := str(fixture.get("home", ""))
			var away := str(fixture.get("away", ""))
			fixture["home"] = away
			fixture["away"] = home
			home_count[home] = int(home_count[home]) - 1
			home_count[away] = int(home_count[away]) + 1
	return fixtures


static func _flip_path(start: String, goal: String, home_map: Dictionary) -> Array:
	var stack: Array = [{"team": start, "path": []}]
	var visited := {start: true}
	while not stack.is_empty():
		var item: Dictionary = stack.pop_back()
		var team := str(item.get("team", ""))
		var path: Array = item.get("path", [])
		for fixture in home_map.get(team, []):
			var away := str(fixture.get("away", ""))
			if away == goal:
				var result := path.duplicate()
				result.append(fixture)
				return result
			if visited.has(away):
				continue
			visited[away] = true
			var next_path := path.duplicate()
			next_path.append(fixture)
			stack.append({"team": away, "path": next_path})
	return []


static func _sort(schedule: Array) -> void:
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := str(a.get("date", ""))
		var right := str(b.get("date", ""))
		if left != right:
			return left < right
		return str(a.get("id", "")) < str(b.get("id", "")))
