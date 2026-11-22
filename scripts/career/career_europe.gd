class_name CareerEurope
extends RefCounted
# The real 2026-27 UEFA fields and the first-season Europe switch. Real mode
# plays the published league phase as it is; simulated mode starts from the same
# field and, when the career club is absent, puts it into the competition whose
# average club coefficient is closest and drops the weakest club there. Clubs are
# compared by coefficient everywhere; it is the same number that seeds the pots.

const PATH := "res://assets/data/europe_2026_27.json"
const MODES := ["real", "simulated", "none"]
const COMPETITIONS := ["ucl", "uel", "uecl"]
const ROUNDS := {"ucl": 8, "uel": 8, "uecl": 6}

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
			result[str(comp).to_lower()] = _ids(field)
	return result


static func replacements() -> Dictionary:
	var result := {}
	var rows = data().get("replacements", {})
	if not (rows is Dictionary):
		return result
	for comp in rows:
		result[str(comp).to_lower()] = rows[comp]
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
	for row in rows.get(comp.to_upper(), []):
		if row is Array and row.size() == 2:
			result.append({"home": str(int(row[0])), "away": str(int(row[1]))})
	return result


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
	var busy := {}
	for fixture in career.schedule:
		busy[str(fixture.get("date", ""))] = true
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
