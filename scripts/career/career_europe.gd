class_name CareerEurope
extends RefCounted
# The real 2026-27 UEFA fields and the first-season Europe switch. Real mode
# plays the published league phase as it is; simulated mode starts from the same
# field and, when the career club is absent, puts it into the competition whose
# average club coefficient is closest and drops the weakest club there. Clubs are
# compared by coefficient everywhere; it is the same number that seeds the pots.

const PATH := "res://assets/data/europe_2026_27.json"
const MODES := ["real", "simulated", "none"]
const COMPETITIONS := ["CL", "EL", "UCOL"]
const ROUNDS := {"CL": 8, "EL": 8, "UCOL": 6}
const QUALIFYING_ORDER := ["q1", "q2", "q3", "playoff_round"]
const QUALIFYING_WINDOWS := {
	"CL": {"q1": ["07-07", "07-15"], "q2": ["07-21", "07-29"],
		"q3": ["08-04", "08-11"], "playoff_round": ["08-18", "08-26"]},
	"EL": {"q1": ["07-09", "07-16"], "q2": ["07-23", "07-30"],
		"q3": ["08-06", "08-13"], "playoff_round": ["08-20", "08-27"]},
	"UCOL": {"q1": ["07-09", "07-16"], "q2": ["07-23", "07-30"],
		"q3": ["08-06", "08-13"], "playoff_round": ["08-20", "08-27"]},
}

static var last_error := ""
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if not FileAccess.file_exists(PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data


static func season() -> String:
	return str(data().get("season", ""))


static func fields() -> Dictionary:
	var result := {}
	var competitions = data().get("competitions", {})
	if not (competitions is Dictionary):
		return result
	for comp in competitions:
		var field = competitions[comp]
		if field is Array:
			result[str(comp)] = _ids(field)
	return result


static func replacements() -> Dictionary:
	var result := {}
	var rows = data().get("replacements", {})
	if not (rows is Dictionary):
		return result
	for comp in rows:
		result[str(comp)] = rows[comp]
	return result


static func uefa_association(country: String) -> bool:
	if country.is_empty():
		return false
	var uefa = CareerBerths.access().get("uefa", {})
	for row in uefa.get("coefficients", []):
		if str((row as Dictionary).get("association", "")) == country:
			return true
	return false


static func block() -> Dictionary:
	var fields := fields()
	if fields.is_empty():
		return {}
	var competitions := {}
	for comp in COMPETITIONS:
		competitions[comp] = {
			"league_phase": fields.get(comp, []),
			"rounds": {},
			"draw": draw(comp),
			"round_count": int(ROUNDS.get(comp, 8)),
			"substitutions": {},
		}
	return {"competitions": competitions, "rebalanced": {},
		"source": "uefa_2026_27"}


static func draw(comp: String) -> Array:
	var result: Array = []
	var rows = data().get("draw", {})
	if not (rows is Dictionary):
		return result
	for row in rows.get(comp, []):
		if row is Array and row.size() == 2:
			result.append({"home": str(int(row[0])), "away": str(int(row[1]))})
	return result


static func simulate_due(career: Career, catalog: TeamCatalog, today: String) -> void:
	# Matches in the knockout that do not involve the career club are simulated as
	# soon as their date passes, so the bracket advances while the season is still
	# running even if the career club is already out. The player's own matches are
	# left for the match screen.
	var due: Array = []
	for fixture in career.schedule:
		if not str(fixture.get("stage", "")).begins_with("euro:"):
			continue
		if str(fixture.get("date", "")) > today:
			continue
		if career.results.has(str(fixture.get("id", ""))):
			continue
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		if home == career.club_id or away == career.club_id:
			continue
		due.append(fixture)
	if due.is_empty():
		return
	var cache := {}
	for fixture in due:
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		if not cache.has(home):
			cache[home] = float(
				catalog.load_team_rating(int(home)).get("average", 55.0))
		if not cache.has(away):
			cache[away] = float(
				catalog.load_team_rating(int(away)).get("average", 55.0))
		career.data["results"][str(fixture.get("id", ""))] = \
			CareerSeason.simulate(career.seed, fixture, cache)
	ensure_knockout(career)


static func qualifying_fixtures(career: Career, catalog: TeamCatalog) -> Array:
	# Add the next qualifying round of the career club to the schedule. One round
	# at a time: the next one waits for the current one to be played.
	var block := _season_block(career)
	if not bool(block.get("qualifying_pending", false)):
		return []
	var focus := str(block.get("qualifying_focus", career.club_id))
	var rows: Array = block.get("focus_fixtures", [])
	if rows.is_empty():
		return []
	var comp := str(block.get("qualifying_competition", ""))
	var by_round := {}
	for fixture in rows:
		var round := str((fixture as Dictionary).get("qualifying_round", ""))
		if round.is_empty():
			continue
		var list: Array = by_round.get(round, [])
		list.append(fixture)
		by_round[round] = list
		if comp.is_empty():
			comp = str((fixture as Dictionary).get("europe", ""))
	if comp.is_empty():
		return []
	for round in QUALIFYING_ORDER:
		if not by_round.has(round):
			continue
		var group: Array = by_round[round]
		var present := true
		var played := true
		for fixture in group:
			var key := str((fixture as Dictionary).get("id", ""))
			if not _has_fixture(career, key):
				present = false
			if not career.results.has(key):
				played = false
		if present:
			if played:
				continue
			return []
		var dates := _qualifying_dates(career, comp, round, group.size())
		var base := _max_round(career)
		var round_index := QUALIFYING_ORDER.find(round)
		for fixture in group:
			var copy: Dictionary = (fixture as Dictionary).duplicate()
			copy["competition"] = comp
			copy["stage"] = "euroq:" + comp
			copy["stage_round"] = round_index + 1
			copy["round"] = base + round_index * 2 + int(copy.get("leg", 0)) + 1
			copy["date"] = dates[mini(int(copy.get("leg", 0)), dates.size() - 1)]
			career.schedule.append(copy)
		_sort_schedule(career)
		return group
	return []


static func ensure_qualifying(career: Career, catalog: TeamCatalog) -> void:
	# Resolve the career club's qualifying round when both legs are played, store
	# the actual winner in the forced map, and rebuild the field around it. The
	# next round (or the league phase) is added here.
	var block := _season_block(career)
	if not bool(block.get("qualifying_pending", false)):
		return
	var comp := str(block.get("qualifying_competition", ""))
	if comp.is_empty():
		qualifying_fixtures(career, catalog)
		return
	var fixtures: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "euroq:" + comp:
			fixtures.append(fixture)
	if fixtures.is_empty():
		qualifying_fixtures(career, catalog)
		return
	var by_round := {}
	for fixture in fixtures:
		var round := int(fixture.get("stage_round", 0))
		var list: Array = by_round.get(round, [])
		list.append(fixture)
		by_round[round] = list
	for round_index in range(1, QUALIFYING_ORDER.size() + 1):
		if not by_round.has(round_index):
			qualifying_fixtures(career, catalog)
			return
		var group: Array = by_round[round_index]
		for fixture in group:
			if not career.results.has(str(fixture.get("id", ""))):
				return
		var focus := str(block.get("qualifying_focus", career.club_id))
		var own: Array = []
		var opponent := ""
		for fixture in group:
			var home := str(fixture.get("home", ""))
			var away := str(fixture.get("away", ""))
			if home == focus or away == focus:
				own.append(fixture)
				opponent = away if home == focus else home
		if own.is_empty():
			_rebuild(career, catalog, block, comp)
			return
		var pair := _pair_key(focus, opponent)
		var forced: Dictionary = career.data.get("europe_forced", {})
		if forced.has(pair):
			continue
		var entrants: Array = [focus, opponent]
		var settled := CareerBrackets.settle_ties(entrants, own, career.results,
			career.seed, {"method": "extra_time_pens", "away_goals": false})
		career.data["results"] = settled
		var winners := CareerBrackets.round_winners(entrants, own,
			career.results)
		if winners.is_empty():
			return
		forced[pair] = str(winners[0])
		career.data["europe_forced"] = forced
		_rebuild(career, catalog, block, comp)
		return
	qualifying_fixtures(career, catalog)


static func ensure_league_phase(career: Career, catalog: TeamCatalog) -> void:
	# Add the focus competition's league-phase fixtures once the field is final.
	var block := _season_block(career)
	if bool(block.get("qualifying_pending", false)):
		return
	var comp := CareerCompetitions._focus_competition(block, career.club_id)
	if comp.is_empty():
		return
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) == comp \
				and str(fixture.get("stage", "")) == comp:
			return
	var competition: Dictionary = block.get("competitions", {}).get(comp, {})
	var rounds := int(competition.get("round_count", ROUNDS.get(comp, 8)))
	var dates := _league_phase_dates(career, rounds)
	var base := _max_round(career)
	var fixtures := CareerCompetitions._euro_fixtures(catalog, competition, comp,
		dates, base, career.seed)
	if fixtures.is_empty():
		return
	career.schedule.append_array(fixtures)
	_sort_schedule(career)


static func _rebuild(career: Career, catalog: TeamCatalog, block: Dictionary,
		current_comp: String) -> void:
	var berths = career.data.get("berths", {}).get(career.season_start, {})
	if not (berths is Dictionary) or (berths as Dictionary).is_empty():
		return
	var old := _season_block(career)
	var built := CareerContinental.build(catalog, berths, career.seed,
		old.get("champions", {}), career.data.get("europe_forced", {}),
		career.club_id)
	if built.is_empty():
		return
	built["coefficients"] = old.get("coefficients", {})
	built["qualifying_focus"] = career.club_id
	var new_focus: Array = built.get("focus_fixtures", [])
	if not new_focus.is_empty():
		built["qualifying_competition"] = str(
			(new_focus[0] as Dictionary).get("europe", current_comp))
	else:
		built["qualifying_competition"] = current_comp
	var focus_comp := CareerCompetitions._focus_competition(built, career.club_id)
	if focus_comp.is_empty():
		var pending := false
		for fixture in new_focus:
			var key := str((fixture as Dictionary).get("id", ""))
			if not _has_fixture(career, key) or not career.results.has(key):
				pending = true
				break
		built["qualifying_pending"] = pending
	else:
		built["qualifying_pending"] = false
		built["qualifying_competition"] = focus_comp
	career.data["continental"][career.season_start] = built
	if bool(built.get("qualifying_pending", false)):
		qualifying_fixtures(career, catalog)
	else:
		ensure_league_phase(career, catalog)


static func _season_block(career: Career) -> Dictionary:
	var blocks = career.data.get("continental", {})
	if not (blocks is Dictionary):
		return {}
	var block = blocks.get(career.season_start, {})
	return block if block is Dictionary else {}


static func _has_fixture(career: Career, fixture_id: String) -> bool:
	for fixture in career.schedule:
		if str(fixture.get("id", "")) == fixture_id:
			return true
	return false


static func _pair_key(first: String, second: String) -> String:
	return first + "|" + second if first < second else second + "|" + first


static func _max_round(career: Career) -> int:
	var value := 0
	for fixture in career.schedule:
		value = maxi(value, int(fixture.get("round", 0)))
	return value


static func _qualifying_dates(career: Career, comp: String, round: String,
		count: int) -> Array:
	var windows: Dictionary = QUALIFYING_WINDOWS.get(comp,
		QUALIFYING_WINDOWS["CL"])
	var window = windows.get(round, [])
	if not (window is Array) or (window as Array).size() < 2:
		return []
	var year := int(str(career.season_start).substr(0, 4))
	var start := "%04d-%s" % [year, str(window[0])]
	var end := "%04d-%s" % [year, str(window[1])]
	return _rest_dates(career, start, end, count)


static func _league_phase_dates(career: Career, count: int) -> Array:
	var year := int(str(career.season_start).substr(0, 4))
	var start := "%04d-09-15" % year
	var end := "%04d-01-31" % (year + 1)
	return _rest_dates(career, start, end, count)


static func _rest_dates(career: Career, start: String, end: String,
		count: int) -> Array:
	var busy := CareerCalendar.busy_days(career.schedule)
	var ideal := CareerCalendar.round_dates(start, end, count,
		IntlCalendar.rules(), "world", busy)
	var dates: Array = []
	for date in ideal:
		var chosen := str(date)
		for step in range(0, 29):
			var found := false
			for offset in ([0] if step == 0 else [step, -step]):
				var candidate := CareerSeason.add_days(str(date), offset)
				if candidate < start or candidate > end or busy.has(candidate):
					continue
				var ok := true
				for other in busy:
					if absi(CareerSeason.days_between(candidate, str(other))) < 3:
						ok = false
						break
				if ok:
					chosen = candidate
					found = true
					break
			if found:
				break
		dates.append(chosen)
		busy[chosen] = true
	return dates


static func ensure_knockout(career: Career) -> void:
	# Add the knockout rounds of the career club's competition after its league
	# phase is complete. One round is added at a time; the next one waits for the
	# previous round's results. A competition already resolved at season end is
	# left alone.
	var blocks: Dictionary = career.data.get("continental", {})
	var block = blocks.get(career.season_start, {})
	if not (block is Dictionary) or block.is_empty():
		return
	var comp := CareerCompetitions._focus_competition(block, career.club_id)
	if comp.is_empty():
		return
	var competition: Dictionary = block.get("competitions", {}).get(comp, {})
	if competition.has("knockout"):
		return
	var league_fixtures: Array = []
	for fixture in career.schedule:
		if str(fixture.get("competition", "")) == comp \
				and str(fixture.get("stage", "")) == comp:
			league_fixtures.append(fixture)
	if league_fixtures.is_empty() or not _all_played(career, league_fixtures):
		return
	var table := CareerContinental.table(career, comp)
	if table.size() < 24:
		return
	var dates = competition.get("knockout_dates", [])
	if not (dates is Array) or (dates as Array).is_empty():
		dates = _knockout_dates(career)
		competition["knockout_dates"] = dates
	var entrants: Array = []
	for row in table.slice(0, 24):
		entrants.append(str(row.get("id", "")))
	var stored: Dictionary = competition.get("knockout_entrants", {})
	stored["0"] = entrants
	competition["knockout_entrants"] = stored
	var stage := {"rounds": CareerKnockout.ROUNDS}
	var base := 0
	for fixture in career.schedule:
		base = maxi(base, int(fixture.get("round", 0)))
	var offset := 0
	for round_index in range(CareerKnockout.ROUNDS.size()):
		var spec: Dictionary = CareerKnockout.ROUNDS[round_index]
		var legs := maxi(1, int(spec.get("legs", 1)))
		var existing := _round_fixtures(career, comp, round_index + 1)
		if not existing.is_empty():
			if not _all_played(career, existing):
				return
			if round_index == CareerKnockout.ROUNDS.size() - 1:
				_store_champion(career, competition,
					stored.get(str(round_index), []), existing)
			offset += legs
			continue
		if round_index > 0:
			var previous := _round_fixtures(career, comp, round_index)
			if previous.is_empty() or not _all_played(career, previous):
				return
			var previous_entrants: Array = stored.get(str(round_index - 1), [])
			career.data["results"] = CareerBrackets.settle_ties(
				previous_entrants, previous, career.results, career.seed,
				{"method": "extra_time_pens", "away_goals": false})
			entrants = CareerBrackets.round_winners(previous_entrants, previous,
				career.results)
			stored[str(round_index)] = entrants
			competition["knockout_entrants"] = stored
		if entrants.is_empty():
			return
		var round_dates: Array = []
		for leg in range(legs):
			if offset + leg < (dates as Array).size():
				round_dates.append(str(dates[offset + leg]))
		var fixtures := CareerBrackets.round_fixtures(stage, round_index, entrants,
			round_dates, "euro:%s:" % comp)
		if legs == 2:
			_flip_legs(fixtures)
		for fixture in fixtures:
			fixture["competition"] = comp
			fixture["stage"] = "euro:" + comp
			fixture["stage_round"] = round_index + 1
			fixture["round"] = base + offset + int(fixture.get("leg", 0)) + 1
			career.schedule.append(fixture)
		_sort_schedule(career)
		return


static func _round_fixtures(career: Career, comp: String, stage_round: int) -> Array:
	var rows: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == "euro:" + comp \
				and int(fixture.get("stage_round", 0)) == stage_round:
			rows.append(fixture)
	return rows


static func _all_played(career: Career, fixtures: Array) -> bool:
	for fixture in fixtures:
		if not career.results.has(str(fixture.get("id", ""))):
			return false
	return true


static func _store_champion(career: Career, competition: Dictionary,
		entrants: Array, fixtures: Array) -> void:
	if entrants.is_empty() or fixtures.is_empty():
		return
	career.data["results"] = CareerBrackets.settle_ties(entrants, fixtures,
		career.results, career.seed,
		{"method": "extra_time_pens", "away_goals": false})
	var winners := CareerBrackets.round_winners(entrants, fixtures, career.results)
	if winners.is_empty():
		return
	var winner := str(winners[0])
	var runner := ""
	for club_id in entrants:
		if str(club_id) != winner:
			runner = str(club_id)
	competition["champion"] = winner
	competition["runner_up"] = runner


static func _flip_legs(fixtures: Array) -> void:
	for fixture in fixtures:
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		fixture["home"] = away
		fixture["away"] = home


static func _sort_schedule(career: Career) -> void:
	career.schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := str(a.get("date", ""))
		var right := str(b.get("date", ""))
		if left != right:
			return left < right
		return str(a.get("id", "")) < str(b.get("id", "")))


static func _knockout_dates(career: Career) -> Array:
	var year := int(str(career.season_start).substr(0, 4)) + 1
	var start := "%04d-02-15" % year
	var end := "%04d-05-31" % year
	var busy := CareerCalendar.busy_days(career.schedule)
	var ideal := CareerCalendar.round_dates(start, end, 9,
		IntlCalendar.rules(), "world", busy)
	var dates: Array = []
	for date in ideal:
		var chosen := str(date)
		for step in range(0, 29):
			var found := false
			for offset in ([0] if step == 0 else [step, -step]):
				var candidate := CareerSeason.add_days(str(date), offset)
				if candidate < start or candidate > end or busy.has(candidate):
					continue
				var ok := true
				for other in busy:
					if absi(CareerSeason.days_between(candidate, str(other))) < 3:
						ok = false
						break
				if ok:
					chosen = candidate
					found = true
					break
			if found:
				break
		dates.append(chosen)
		busy[chosen] = true
	return dates


static func first_season(mode: String, focus_club: String) -> Dictionary:
	last_error = ""
	if not MODES.has(mode):
		last_error = "unknown Europe mode: " + mode
		return {}
	if mode == "none":
		return {}
	var built := block()
	if built.is_empty():
		last_error = "the 2026-27 UEFA field is missing"
		return {}
	if mode == "real" or focus_club.is_empty():
		return built
	if _competition_of(built, focus_club).is_empty():
		_place_club(built, focus_club)
	return built


static func swap(block_data: Dictionary, from_comp: String, from_club: String,
		to_comp: String, to_club: String) -> bool:
	last_error = ""
	var competitions: Dictionary = block_data.get("competitions", {})
	if from_comp == to_comp:
		last_error = "pick clubs from two different competitions"
		return false
	if not competitions.has(from_comp) or not competitions.has(to_comp):
		last_error = "unknown competition"
		return false
	var from_field: Array = competitions[from_comp].get("league_phase", [])
	var to_field: Array = competitions[to_comp].get("league_phase", [])
	var from_index := from_field.find(from_club)
	var to_index := to_field.find(to_club)
	if from_index < 0:
		last_error = "the club is not in the first competition"
		return false
	if to_index < 0:
		last_error = "the club is not in the second competition"
		return false
	from_field[from_index] = to_club
	to_field[to_index] = from_club
	if from_field.size() != 36 or to_field.size() != 36 \
			or _duplicates(from_field) or _duplicates(to_field):
		from_field[from_index] = from_club
		to_field[to_index] = to_club
		last_error = "the swap would break the 36-club field"
		return false
	return true


static func _place_club(block_data: Dictionary, club_id: String) -> String:
	var competitions: Dictionary = block_data.get("competitions", {})
	var target := ""
	var target_diff := INF
	var coefficient := CareerCoefficients.coefficient(club_id)
	for comp in COMPETITIONS:
		var field: Array = competitions.get(comp, {}).get("league_phase", [])
		if field.is_empty():
			continue
		var diff := absf(_average(field) - coefficient)
		if diff < target_diff:
			target_diff = diff
			target = comp
	if target.is_empty():
		last_error = "no league phase to place the club into"
		return ""
	var field: Array = competitions[target]["league_phase"]
	var weakest := _weakest(field)
	field[field.find(weakest)] = club_id
	var substitutions: Dictionary = competitions[target].get("substitutions", {})
	substitutions[weakest] = club_id
	competitions[target]["substitutions"] = substitutions
	return target


static func _competition_of(block_data: Dictionary, club_id: String) -> String:
	var competitions: Dictionary = block_data.get("competitions", {})
	for comp in COMPETITIONS:
		var field: Array = competitions.get(comp, {}).get("league_phase", [])
		if field.has(club_id):
			return comp
	return ""


static func _weakest(field: Array) -> String:
	var sorted := CareerCoefficients.sorted_clubs(field)
	return sorted[sorted.size() - 1] if not sorted.is_empty() else ""


static func _average(field: Array) -> float:
	if field.is_empty():
		return 0.0
	var total := 0.0
	for club_id in field:
		total += CareerCoefficients.coefficient(str(club_id))
	return total / field.size()


static func _duplicates(field: Array) -> bool:
	var seen := {}
	for club_id in field:
		if seen.has(str(club_id)):
			return true
		seen[str(club_id)] = true
	return false


static func _ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(str(int(value)))
	return result
