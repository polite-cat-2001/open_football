class_name CareerFactory
extends RefCounted
# Career creation and read models ported from server/career/{core,season,snapshot}.py.
# Only the data the career shell needs today is built; later tickets extend it.

const SCHEDULE_VERSION := 3
static var last_error := ""


static func create(
	catalog: TeamCatalog,
	club_id: int,
	manager_name: String,
	nationality_id: int,
	seed := -1,
	europe_mode := "none",
	country_mode := "static"
) -> Career:
	last_error = ""
	var manager := manager_name.strip_edges()
	if manager.is_empty():
		last_error = "Manager name must not be blank."
		return null
	var club := catalog.career_club(club_id)
	if club.is_empty():
		last_error = "Club not found."
		return null
	var nationality := catalog.country_by_id(nationality_id)
	if nationality.is_empty():
		last_error = "Manager nationality not found."
		return null
	var squad := catalog.career_squad(club_id)
	if squad.is_empty():
		last_error = "Selected club has no players in the database."
		return null

	var league_clubs := catalog.all_teams_for_league(str(club.get("league_id", "")))
	var league_ids: Array = []
	for team in league_clubs:
		league_ids.append(str(team.get("id", "")))
	if not league_ids.has(str(club_id)):
		league_ids.append(str(club_id))
	league_ids.sort()

	var player_ids: Array = []
	for player in squad:
		player_ids.append(str(player.get("id", "")))

	# The league calendar decides the season: the career opens on the boundary
	# nearest to the data snapshot, and the fixtures run inside the league's own
	# window. A club in an early cup or qualifier will widen this later with the
	# competition container.
	var league_id := str(club.get("league_id", ""))
	var season_start := LeagueRegulations.nearest_boundary(league_id, Career.START_DATE)
	if season_start.is_empty():
		season_start = Career.START_DATE
	var country_name := str(catalog.country_by_id(
		int(catalog.league_by_id(league_id).get("country_id", 0))).get("name", ""))
	var confederation := CareerConfederation.confederation_of(country_name)
	if not confederation.is_empty():
		# The club's continental cup may start before the league: open the season
		# early enough for it, like the European window does.
		var continental_start := CareerConfederation.earliest_start(confederation,
			season_start)
		if not continental_start.is_empty():
			var wished := CareerSeason.add_days(continental_start, -7)
			if wished < season_start:
				season_start = wished
	var continental := {}
	if europe_mode != "none":
		if CareerEurope.uefa_association(country_name):
			continental = CareerEurope.first_season(europe_mode, str(club_id))
			if not CareerEurope.last_error.is_empty():
				last_error = CareerEurope.last_error
				return null
		else:
			europe_mode = "none"
	var confederation_block := {}
	if not confederation.is_empty():
		confederation_block = CareerConfederation.build_first_season(catalog,
			confederation, season_start, str(club_id))
	var career_seed := seed if seed >= 0 else Career.random_seed()
	var built := CareerCompetitions.build_season(catalog, league_id, league_ids,
		season_start, {}, continental, str(club_id), career_seed)
	var schedule: Array = built.get("schedule", [])
	var stages_generated: Dictionary = built.get("stages_generated", {})
	var competitions: Array = built.get("competitions", [])

	var now := Career.utc_now()
	var continental_data := continental
	if not confederation_block.is_empty():
		if continental_data.is_empty():
			continental_data = {}
		continental_data["confederations"] = {confederation: confederation_block}
	var career := Career.new({
		"version": Career.SAVE_VERSION,
		"id": Career.random_id(),
		"seed": career_seed,
		"date": season_start,
		"season_start": season_start,
		"created_at": now,
		"updated_at": now,
		"manager": {
			"name": manager,
			"nationality_id": str(nationality_id),
			"nationality": str(nationality.get("name", "")),
		},
		"club_id": str(club_id),
		"player_ids": player_ids,
		"journal": [],
		"league_id": league_id,
		"league_club_ids": league_ids,
		"formation": Career.DEFAULT_FORMATION,
		"hub_tab": "centre",
		"schedule": schedule,
		"stages_generated": stages_generated,
		"competitions": competitions,
		"europe_mode": europe_mode,
		"country_coefficients_mode": country_mode,
		"coefficients": CareerCoefficients.table(),
		"country_coefficients": CareerCountryCoefficients.table(),
		"continental": {season_start: continental_data} if not continental_data.is_empty() else {},
		"seasons_completed": 0,
		"schedule_version": SCHEDULE_VERSION,
		"incoming_market_date": season_start,
		"last_tick_date": season_start,
	})
	CareerSquad.ensure_finances(career, squad)
	if not confederation_block.is_empty():
		CareerConfederation.ensure(career, catalog)
	return career


static func build_schedule(club_ids: Array, start_date := Career.START_DATE,
		end_date := "", rules: Array = [], scope := "world",
		dates: Array = []) -> Array:
	var teams: Array = []
	var seen := {}
	for club_id in club_ids:
		var value := str(club_id)
		if not seen.has(value):
			seen[value] = true
			teams.append(value)
	teams.sort()
	if teams.size() < 2:
		return []
	if teams.size() % 2 == 1:
		teams.append(null)

	var rotation := teams.duplicate()
	var rounds: Array = []
	for round_index in range(rotation.size() - 1):
		var pairs: Array = []
		for index in range(rotation.size() / 2):
			var home = rotation[index]
			var away = rotation[rotation.size() - 1 - index]
			if home == null or away == null:
				continue
			if (round_index + index) % 2 == 1:
				var swap = home
				home = away
				away = swap
			pairs.append([home, away])
		rounds.append(pairs)
		var next_rotation: Array = [rotation[0], rotation[-1]]
		next_rotation.append_array(rotation.slice(1, rotation.size() - 1))
		rotation = next_rotation

	var fixtures: Array = []
	var total_rounds: int = rounds.size() * 2
	var span := 0
	if not str(end_date).is_empty():
		span = CareerSeason.days_between(start_date, str(end_date))
	var planned := dates
	if planned.is_empty():
		planned = _round_dates(start_date, str(end_date), total_rounds, rules, scope)
	for half in [0, 1]:
		for round_index in range(rounds.size()):
			var round_no: int = int(half) * rounds.size() + round_index + 1
			var match_date := _round_date(start_date, span, round_no, total_rounds)
			if round_no <= planned.size():
				match_date = str(planned[round_no - 1])
			var pairs: Array = rounds[round_index]
			for match_index in range(pairs.size()):
				var home: String = str(pairs[match_index][0])
				var away: String = str(pairs[match_index][1])
				if half == 1:
					var swap := home
					home = away
					away = swap
				fixtures.append({
					"id": "r%02d-%02d" % [round_no, match_index],
					"round": round_no,
					"date": match_date,
					"home": home,
					"away": away,
				})
	return fixtures


static func _round_dates(start_date: String, end_date: String, total_rounds: int,
		rules: Array, scope: String) -> Array:
	return CareerCalendar.round_dates(start_date, end_date, total_rounds, rules,
		scope)


static func _round_date(start_date: String, span: int, round_no: int,
		total_rounds: int) -> String:
	# Rounds run evenly from the window start to its end, so every league
	# finishes inside its own calendar; without a window the old weekly pace
	# stays (one round every seven days).
	if span <= 0 or total_rounds < 2:
		return _add_days(start_date, 7 * round_no)
	var offset := int(round(float(round_no - 1) * float(span) / float(total_rounds - 1)))
	return _add_days(start_date, offset)


static func season_schedule(league_id: String, club_ids: Array,
		season_start: String, plan: Dictionary = {}) -> Dictionary:
	var window := LeagueRegulations.window_for_season(league_id, season_start)
	var schedule_start := str(window.get("start", season_start))
	var schedule_end := str(window.get("end", ""))
	var format = LeagueRegulations.record(league_id).get("format")
	var schedule: Array = []
	var generated := {}
	if format is Dictionary:
		var stages := CareerStages.stages(format)
		var windows := _stage_windows(format, season_start, schedule_start, schedule_end)
		var stage_offset := 0
		for index in range(stages.size()):
			var stage: Dictionary = stages[index]
			var clauses = stage.get("entrants", [])
			var is_all := clauses is Array and (clauses as Array).size() == 1 \
				and str((clauses as Array)[0].get("rule", "")) == "all"
			if not is_all:
				continue
			var stage_window: Dictionary = windows[index]
			var stage_dates = plan.get(str(stage.get("id", "")), [])
			var fixtures := CareerStages.build_stage(stage, club_ids,
				str(stage_window.get("start", schedule_start)),
				str(stage_window.get("end", schedule_end)),
				IntlCalendar.rules(), "world", {}, stage_dates)
			var max_round := 0
			for fixture in fixtures:
				var raw_round := int(fixture.get("round", 0))
				fixture["stage"] = str(stage.get("id", ""))
				fixture["stage_round"] = raw_round
				fixture["round"] = stage_offset + raw_round
				if not fixture.has("group"):
					fixture["group"] = -1
				max_round = maxi(max_round, raw_round)
				schedule.append(fixture)
			generated[str(stage.get("id", ""))] = "fixtures"
			stage_offset += max_round
	if schedule.is_empty():
		schedule = build_schedule(club_ids, schedule_start, schedule_end,
			IntlCalendar.rules(), "world", plan.get("league", []))
	return {"schedule": schedule, "stages_generated": generated}


static func _stage_windows(format: Dictionary, season_start: String,
		season_start_default: String, season_end: String) -> Array:
	# A stage's window is curated when the asset knows it. A missing end is
	# derived from the next stage (a week per match day), so a regular phase
	# cannot run through its own playoffs; a missing start follows the previous
	# stage. Nothing here names a league.
	var stages := CareerStages.stages(format)
	# The stages open with the league window, so a calendar-year league whose
	# boundary falls in December places them in the following year.
	var year := int(str(season_start_default).substr(0, 4))
	var format_start := str(format.get("start_md", ""))
	var starts: Array = []
	var ends: Array = []
	for stage in stages:
		starts.append(_stage_date(year, str(stage.get("start_md", "")), format_start))
		ends.append(_stage_date(year, str(stage.get("end_md", "")), format_start))
	for index in range(stages.size() - 1, -1, -1):
		if not ends[index].is_empty():
			continue
		if index + 1 < stages.size():
			var next_start := str(starts[index + 1])
			if next_start.is_empty() and not str(ends[index + 1]).is_empty():
				next_start = CareerSeason.add_days(str(ends[index + 1]),
					-7 * maxi(0, _match_days(stages[index + 1]) - 1))
			if not next_start.is_empty():
				ends[index] = CareerSeason.add_days(next_start, -1)
		if ends[index].is_empty():
			ends[index] = season_end
	for index in range(stages.size()):
		if index > 0 and not str(ends[index - 1]).is_empty():
			var previous_end := str(ends[index - 1])
			if starts[index].is_empty() or str(starts[index]) <= previous_end:
				starts[index] = CareerSeason.add_days(previous_end, 1)
		if starts[index].is_empty():
			starts[index] = season_start_default
	var windows: Array = []
	for index in range(stages.size()):
		windows.append({"start": starts[index], "end": ends[index]})
	return windows


static func _match_days(stage: Dictionary) -> int:
	if str(stage.get("kind", "")) == "knockout":
		var days := 0
		for spec in stage.get("rounds", []):
			days += maxi(1, int((spec as Dictionary).get("legs", 1)))
		return days
	return maxi(1, int(stage.get("rounds", 1)))


static func ensure_stages(career: Career) -> void:
	var format = LeagueRegulations.record(career.league_id).get("format")
	if not (format is Dictionary):
		return
	var stages := CareerStages.stages(format)
	if stages.is_empty():
		return
	var generated = career.data.get("stages_generated")
	if not (generated is Dictionary):
		generated = {}
		career.data["stages_generated"] = generated
	var window := LeagueRegulations.window_for_season(career.league_id, career.season_start)
	var taken_by_source := {}
	var windows := _stage_windows(format, career.season_start,
		str(window.get("start", career.season_start)), str(window.get("end", "")))
	for index in range(1, stages.size()):
		var stage: Dictionary = stages[index]
		var stage_id := str(stage.get("id", ""))
		if str(stage.get("kind", "")) == "knockout":
			_ensure_knockout(career, format, stages, index, windows, generated)
			continue
		var source := _stage_source(format, stage_id)
		if source.is_empty() or source == stage_id:
			continue
		if generated.has(stage_id):
			for fixture in _stage_fixtures(career, stage_id):
				var taken_rows: Dictionary = taken_by_source.get(source, {})
				taken_rows[str(fixture.get("home", ""))] = true
				taken_rows[str(fixture.get("away", ""))] = true
				taken_by_source[source] = taken_rows
			continue
		var source_fixtures := _stage_fixtures(career, source)
		if source_fixtures.is_empty():
			continue
		var source_complete := true
		for fixture in source_fixtures:
			if not career.results.has(str(fixture.get("id", ""))):
				source_complete = false
				break
		if not source_complete:
			continue
		var source_table := stage_table(career, {}, source)
		var taken: Dictionary = taken_by_source.get(source, {})
		var entrants := CareerStages.resolve_entrants(stage, source_table, taken,
			_source_group_tables(career, source), _entrant_sources(career, stage))
		if entrants.is_empty():
			continue
		for club_id in entrants:
			taken[str(club_id)] = true
		taken_by_source[source] = taken
		var round_offset := 0
		for fixture in source_fixtures:
			round_offset = maxi(round_offset, int(fixture.get("round", 0)))
		var stage_window: Dictionary = windows[index]
		var start := str(stage_window.get("start", career.season_start))
		var end := str(stage_window.get("end", ""))
		var fixtures := CareerStages.build_stage(stage, entrants, start, end,
			IntlCalendar.rules(), "world")
		for fixture in fixtures:
			var stage_round := int(fixture.get("round", 0))
			fixture["stage"] = stage_id
			fixture["stage_round"] = stage_round
			fixture["round"] = round_offset + stage_round
			if not fixture.has("group"):
				fixture["group"] = -1
			career.schedule.append(fixture)
		generated[stage_id] = "fixtures"
	career.schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := str(a.get("date", ""))
		var right := str(b.get("date", ""))
		if left != right:
			return left < right
		return str(a.get("id", "")) < str(b.get("id", "")))


static func _ensure_knockout(career: Career, format: Dictionary, stages: Array,
		index: int, windows: Array, generated: Dictionary) -> void:
	# Rounds appear one at a time: the first from the source tables, every later
	# one from the previous round's winners. A round is created only when every
	# stage it draws from is fully played.
	var stage: Dictionary = stages[index]
	var stage_id := str(stage.get("id", ""))
	var rounds = stage.get("rounds", [])
	if not (rounds is Array) or (rounds as Array).is_empty():
		return
	var sources := _stage_sources(format, stage_id)
	if sources.is_empty():
		return
	var source_fixtures: Array = []
	for source in sources:
		source_fixtures.append_array(_stage_fixtures(career, str(source)))
	if source_fixtures.is_empty():
		return
	var stage_window: Dictionary = windows[index]
	var start := str(stage_window.get("start", career.season_start))
	var end := str(stage_window.get("end", ""))
	var match_days := _match_days(stage)
	var needed := CareerSeason.add_days(start, 7 * maxi(0, match_days - 1))
	if end.is_empty() or end < needed:
		end = needed
	var dates := CareerCalendar.round_dates(start, end, match_days,
		IntlCalendar.rules(), "world")
	var base := 0
	for fixture in source_fixtures:
		base = maxi(base, int(fixture.get("round", 0)))
	var offset := 0
	for round_index in range((rounds as Array).size()):
		var spec: Dictionary = rounds[round_index]
		var legs := maxi(1, int(spec.get("legs", 1)))
		var existing := _stage_round_fixtures(career, stage_id, round_index + 1)
		if not existing.is_empty():
			if not _all_played(career, existing):
				return
			offset += legs
			continue
		if round_index == 0 and not _all_played(career, source_fixtures):
			return
		if round_index > 0:
			var previous := _stage_round_fixtures(career, stage_id, round_index)
			if previous.is_empty() or not _all_played(career, previous):
				return
		var entrants := _knockout_entrants(career, format, stage, round_index)
		if entrants.is_empty():
			return
		var round_dates: Array = []
		for leg in range(legs):
			if offset + leg < dates.size():
				round_dates.append(dates[offset + leg])
		var fixtures := CareerBrackets.round_fixtures(stage, round_index, entrants,
			round_dates, "%s:" % stage_id)
		for fixture in fixtures:
			fixture["stage"] = stage_id
			fixture["stage_round"] = round_index + 1
			fixture["round"] = base + round_index + 1
			career.schedule.append(fixture)
		generated[stage_id] = "fixtures"
		offset += legs


static func _knockout_entrants(career: Career, format: Dictionary,
		stage: Dictionary, round_index: int) -> Array:
	if round_index == 0:
		var sources := _entrant_sources(career, stage)
		var fallback: Array = []
		for source in sources.values():
			fallback = source.get("table", [])
			break
		return CareerStages.resolve_entrants(stage, fallback, {}, [], sources)
	var previous := round_index - 1
	var entrants := _knockout_entrants(career, format, stage, previous)
	var fixtures := _stage_round_fixtures(career, str(stage.get("id", "")), previous + 1)
	if not (career.data.get("results") is Dictionary):
		career.data["results"] = {}
	career.data["results"] = CareerBrackets.settle_ties(entrants, fixtures,
		career.results, career.seed, CareerStages.tiebreak(stage, format))
	return CareerBrackets.round_winners(entrants, fixtures, career.results)


static func stage_decided(career: Career, stage_id: String) -> Dictionary:
	var format = LeagueRegulations.record(career.league_id).get("format")
	if not (format is Dictionary):
		return {}
	for stage in CareerStages.stages(format):
		if str(stage.get("id", "")) != stage_id:
			continue
		var rounds = stage.get("rounds", [])
		if str(stage.get("kind", "")) != "knockout" \
				or not (rounds is Array) or (rounds as Array).is_empty():
			return {}
		var last := (rounds as Array).size() - 1
		var entrants := _knockout_entrants(career, format, stage, last)
		var fixtures := _stage_round_fixtures(career, stage_id, last + 1)
		if not (career.data.get("results") is Dictionary):
			career.data["results"] = {}
		career.data["results"] = CareerBrackets.settle_ties(entrants, fixtures,
			career.results, career.seed, CareerStages.tiebreak(stage, format))
		var winners := CareerBrackets.round_winners(entrants, fixtures, career.results)
		if winners.is_empty():
			return {}
		var winner_id := str(winners[0])
		var loser_id := ""
		for fixture in fixtures:
			var home := str(fixture.get("home", ""))
			var away := str(fixture.get("away", ""))
			if home == winner_id or away == winner_id:
				loser_id = away if home == winner_id else home
				break
		return {"winner": winner_id, "loser": loser_id}
	return {}


static func _entrant_sources(career: Career, stage: Dictionary) -> Dictionary:
	var sources := {}
	for clause in stage.get("entrants", []):
		var source := str(clause.get("from", ""))
		if source.is_empty() or source == "aggregate" or sources.has(source):
			continue
		sources[source] = {
			"table": stage_table(career, {}, source),
			"groups": _source_group_tables(career, source),
			"decided": stage_decided(career, source),
		}
	return sources


static func _stage_sources(format: Dictionary, stage_id: String) -> Array:
	var sources: Array = []
	for stage in CareerStages.stages(format):
		if str(stage.get("id", "")) != stage_id:
			continue
		for clause in stage.get("entrants", []):
			var source := str(clause.get("from", ""))
			if source.is_empty() or source == "aggregate":
				continue
			if not sources.has(source):
				sources.append(source)
		break
	return sources


static func _all_played(career: Career, fixtures: Array) -> bool:
	for fixture in fixtures:
		if not career.results.has(str(fixture.get("id", ""))):
			return false
	return true


static func _stage_round_fixtures(career: Career, stage_id: String,
		stage_round: int) -> Array:
	var fixtures: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) == stage_id \
				and int(fixture.get("stage_round", 0)) == stage_round:
			fixtures.append(fixture)
	return fixtures


static func _source_group_tables(career: Career, stage_id: String) -> Array:
	var numbers := {}
	for fixture in _stage_fixtures(career, stage_id):
		var group := int(fixture.get("group", -1))
		if group >= 0:
			numbers[group] = true
	var keys := numbers.keys()
	keys.sort()
	var tables: Array = []
	for group in keys:
		tables.append(stage_table(career, {}, stage_id, int(group)))
	return tables


static func stage_table(career: Career, clubs: Dictionary, stage_id: String,
		group := -1) -> Array:
	var fixtures := _stage_fixtures(career, stage_id, group)
	if fixtures.is_empty():
		return []
	var ids := {}
	for fixture in fixtures:
		ids[str(fixture.get("home", ""))] = true
		ids[str(fixture.get("away", ""))] = true
	var club_ids := ids.keys()
	club_ids.sort()
	var carried := {}
	var format = LeagueRegulations.record(career.league_id).get("format")
	var stages := CareerStages.stages(format) if format is Dictionary else []
	if not stages.is_empty() and stage_id != str(stages[0].get("id", "")):
		var source := _stage_source(format, stage_id)
		if not source.is_empty() and source != stage_id:
			var source_rows := stage_table(career, clubs, source)
			var stage_carry: Dictionary = {}
			var carry_value = format.get("carry")
			if carry_value is Dictionary:
				stage_carry = carry_value
			for stage in stages:
				if str(stage.get("id", "")) == stage_id and stage.get("carry") is Dictionary:
					stage_carry = stage.get("carry")
			carried = CareerStages.carry(source_rows, stage_carry)
	var rows := CareerStages.table(fixtures, career.results, club_ids, carried)
	return _enrich_rows(rows, clubs)


static func season_table(career: Career, clubs: Dictionary) -> Array:
	var format = LeagueRegulations.record(career.league_id).get("format")
	if format is Dictionary:
		var champion := str(format.get("champion", ""))
		if champion.begins_with("stage:"):
			var stage_id := champion.substr(6)
			# The champion comes from a knockout (Peru's playoff, Venezuela's final
			# absoluta, Malta's title match) as often as from a league stage: a
			# bracket has no table, so the season is ranked by the aggregate of its
			# phases, or by the regular stage, instead of a two-club final.
			if str(_stage_kind(format, stage_id)) != "knockout":
				var table := stage_table(career, clubs, stage_id)
				if not table.is_empty():
					return table
		if format.get("aggregate") is Array:
			var aggregate := _aggregate_table(career, clubs, format)
			if not aggregate.is_empty():
				return aggregate
		for stage in CareerStages.stages(format):
			var stage_spec: Dictionary = stage
			if str(stage_spec.get("kind", "")) != "league":
				continue
			var regular := stage_table(career, clubs, str(stage_spec.get("id", "")))
			if not regular.is_empty():
				return regular
	return standings(career, clubs)


static func _stage_kind(format: Dictionary, stage_id: String) -> String:
	for stage in CareerStages.stages(format):
		if str(stage.get("id", "")) == stage_id:
			return str(stage.get("kind", ""))
	return ""


static func _aggregate_table(career: Career, clubs: Dictionary,
		format: Dictionary) -> Array:
	var fixtures: Array = []
	for stage_id in format.get("aggregate", []):
		fixtures.append_array(_stage_fixtures(career, str(stage_id)))
	if fixtures.is_empty():
		return standings(career, clubs)
	var ids := {}
	for fixture in fixtures:
		ids[str(fixture.get("home", ""))] = true
		ids[str(fixture.get("away", ""))] = true
	var club_ids := ids.keys()
	club_ids.sort()
	var rows := CareerStages.table(fixtures, career.results, club_ids)
	return _enrich_rows(rows, clubs)


static func _enrich_rows(rows: Array, clubs: Dictionary) -> Array:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		row["club_id"] = str(row.get("id", ""))
		var club: Dictionary = clubs.get(str(row.id), {})
		row["club_name"] = str(club.get("name", row.id))
		row["club_logo"] = _club_logo(club)
		row["position"] = index + 1
	return rows


static func _is_league_fixture(career: Career, fixture: Dictionary) -> bool:
	return str(fixture.get("competition", career.league_id)) == career.league_id


static func _competition_label(career: Career, competition_id: String) -> String:
	var entries = career.data.get("competitions")
	if entries is Array:
		for entry in entries:
			if str(entry.get("id", "")) == competition_id:
				return str(entry.get("label", competition_id))
	return competition_id


static func _stage_fixtures(career: Career, stage_id: String, group := -1) -> Array:
	var fixtures: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) != stage_id:
			continue
		if group >= 0 and int(fixture.get("group", -1)) != group:
			continue
		fixtures.append(fixture)
	return fixtures


static func _stage_source(format: Dictionary, stage_id: String) -> String:
	var stages := CareerStages.stages(format)
	for stage in stages:
		if str(stage.get("id", "")) != stage_id:
			continue
		for clause in stage.get("entrants", []):
			var source := str(clause.get("from", ""))
			if not source.is_empty() and source != "aggregate":
				return source
		break
	return str(stages[0].get("id", "")) if not stages.is_empty() else ""


static func _stage_date(year: int, md: String, reference_md: String) -> String:
	return CareerCalendar.stage_date(year, md, reference_md)


static func ensure_schedule(career: Career, league_club_ids: Array) -> void:
	var format = LeagueRegulations.record(career.league_id).get("format")
	if format is Dictionary:
		ensure_stages(career)
		return
	var club_ids: Array = []
	for club_id in league_club_ids:
		club_ids.append(str(club_id))
	if not club_ids.has(career.club_id):
		club_ids.append(career.club_id)
	var window := LeagueRegulations.window_for_season(career.league_id, career.season_start)
	var schedule_start := str(window.get("start", career.season_start))
	var schedule_end := str(window.get("end", ""))
	if not career.data.has("schedule") or career.data.get("schedule") == null:
		career.data["schedule"] = build_schedule(club_ids, schedule_start, schedule_end,
			IntlCalendar.rules(), "world")
		career.data["schedule_version"] = SCHEDULE_VERSION
		return
	if career.schedule_version >= SCHEDULE_VERSION:
		return
	var corrected := {}
	for fixture in build_schedule(club_ids, schedule_start, schedule_end,
			IntlCalendar.rules(), "world"):
		corrected[str(fixture["id"])] = fixture
	for fixture in career.schedule:
		if career.results.has(str(fixture.get("id", ""))):
			continue
		var fresh = corrected.get(str(fixture.get("id", "")))
		if fresh != null:
			fixture["home"] = fresh["home"]
			fixture["away"] = fresh["away"]
	career.data["schedule_version"] = SCHEDULE_VERSION


static func snapshot(catalog: TeamCatalog, career: Career) -> Dictionary:
	var club := catalog.career_club(int(career.club_id))
	if club.is_empty():
		return {}
	if career.league_id.is_empty():
		career.data["league_id"] = str(club.get("league_id", ""))
	var league := catalog.league_by_id(career.league_id)
	if not league.is_empty():
		# After promotion/relegation the club's database row still points at its
		# old league; the career's current league is the authoritative one.
		club = club.duplicate()
		club["league_id"] = career.league_id
		club["league_name"] = str(league.get("name", club.get("league_name", "")))
	var league_clubs := catalog.all_teams_for_league(str(club.get("league_id", "")))
	var league_ids: Array = []
	for team in league_clubs:
		league_ids.append(str(team.get("id", "")))
	if career.league_club_ids.is_empty():
		career.data["league_club_ids"] = league_ids.duplicate()
	ensure_schedule(career, league_ids)
	var squad_view := CareerSquad.snapshot(catalog, career)
	var clubs := _clubs_for_schedule(catalog, career)
	return {
		"version": career.version,
		"id": career.id,
		"seed": career.seed,
		"date": career.date,
		"created_at": career.created_at,
		"updated_at": career.updated_at,
		"manager": career.manager.to_save(),
		"club": club,
		"squad": squad_view,
		"season": _season_state(career, clubs),
	}


static func list_entries(store: CareerSaveStore, catalog: TeamCatalog) -> Array:
	var items: Array = []
	for entry in store.scan():
		var career = entry.get("career")
		if career != null:
			var club := catalog.career_club(int(career.club_id))
			if club.is_empty():
				items.append(_raw_entry(
					entry, catalog, "Club is missing from the database.", career))
				continue
			var team := catalog.team_by_id(int(career.club_id))
			var league := catalog.league_by_id(str(team.get("league_id", "")))
			items.append({
				"id": career.id,
				"version": career.version,
				"seed": career.seed,
				"date": career.date,
				"created_at": career.created_at,
				"updated_at": career.updated_at,
				"manager_name": career.manager.name,
				"club_id": career.club_id,
				"club_name": str(club.get("name", "")),
				"club_logo": str(club.get("logo", "")),
				"league_name": str(club.get("league_name", "")),
				"country_name": str(club.get("country_name", "")),
				"club": team,
				"league": league,
				"compatible": true,
				"problem": "",
			})
			continue
		items.append(_raw_entry(entry, catalog, str(entry.get("error", ""))))
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("updated_at", "")) != str(b.get("updated_at", "")):
			return str(a.get("updated_at", "")) > str(b.get("updated_at", ""))
		return str(a.get("id", "")) > str(b.get("id", "")))
	return items


static func _raw_entry(entry: Dictionary, catalog: TeamCatalog, problem: String,
		career: Career = null) -> Dictionary:
	var raw: Dictionary = entry.get("raw") if entry.get("raw") is Dictionary else {}
	var manager: Dictionary = raw.get("manager") if raw.get("manager") is Dictionary else {}
	var version := int(raw.get("version", 0))
	var seed_value := int(raw.get("seed", 0))
	var date := str(raw.get("date", ""))
	var created := str(raw.get("created_at", ""))
	var updated := str(raw.get("updated_at", ""))
	var manager_name := str(manager.get("name", "Unknown manager"))
	var club_id := str(raw.get("club_id", ""))
	if career != null:
		version = career.version
		seed_value = career.seed
		date = career.date
		created = career.created_at
		updated = career.updated_at
		manager_name = career.manager.name
		club_id = career.club_id
	var team: Dictionary = {}
	if club_id.is_valid_int():
		team = catalog.team_by_id(int(club_id))
	var club := catalog.career_club(int(club_id)) if club_id.is_valid_int() else {}
	var league: Dictionary = {}
	if not team.is_empty():
		league = catalog.league_by_id(str(team.get("league_id", "")))
	return {
		"id": str(entry.get("id", "")),
		"version": version,
		"seed": seed_value,
		"date": date,
		"created_at": created,
		"updated_at": updated,
		"manager_name": manager_name,
		"club_id": club_id,
		"club_name": str(club.get("name", "Unknown club")),
		"club_logo": str(club.get("logo", "")),
		"league_name": str(club.get("league_name", "")),
		"country_name": str(club.get("country_name", "")),
		"club": team,
		"league": league,
		"compatible": false,
		"problem": problem,
	}


static func _club_logo(club: Dictionary) -> String:
	var career_logo := str(club.get("career_logo", ""))
	return career_logo if not career_logo.is_empty() else str(club.get("logo", ""))


static func _clubs_for_schedule(catalog: TeamCatalog, career: Career) -> Dictionary:
	var clubs := {}
	for club_id in career.league_club_ids:
		var club := catalog.career_club(int(club_id))
		if not club.is_empty():
			clubs[str(club_id)] = club
	clubs[career.club_id] = catalog.career_club(int(career.club_id))
	return clubs


static func _season_state(career: Career, clubs: Dictionary) -> Dictionary:
	var fixtures := career.schedule
	var next_fixture: Dictionary = {}
	for fixture in fixtures:
		var fixture_id := str(fixture.get("id", ""))
		if career.results.has(fixture_id):
			continue
		if career.club_id in [str(fixture.get("home", "")), str(fixture.get("away", ""))]:
			next_fixture = fixture
			break
	var rounds_total := 0
	for fixture in fixtures:
		if not _is_league_fixture(career, fixture):
			continue
		rounds_total = maxi(rounds_total, int(fixture.get("round", 0)))
	var next_match = null
	if not next_fixture.is_empty():
		var home := str(next_fixture.get("home", "")) == career.club_id
		var opponent_id := str(next_fixture.get("away", "")) if home \
			else str(next_fixture.get("home", ""))
		var opponent: Dictionary = clubs.get(opponent_id, {})
		var competition_id := str(next_fixture.get("competition", career.league_id))
		var competition := _competition_label(career, competition_id)
		if competition_id == career.league_id:
			competition = str(clubs.get(career.club_id, {}).get("league_name", competition))
		next_match = {
			"fixture_id": str(next_fixture.get("id", "")),
			"date": str(next_fixture.get("date", "")),
			"round": int(next_fixture.get("round", 0)),
			"home": home,
			"competition": competition,
			"competition_id": competition_id,
			"opponent": {
				"id": opponent_id,
				"name": str(opponent.get("name", opponent_id)),
				"logo": _club_logo(opponent),
			},
		}
	return {
		"season_start": career.season_start,
		"season_end": CareerSeason.season_end(career),
		"round": int(next_fixture.get("round", rounds_total)) if not next_fixture.is_empty() else rounds_total,
		"played_round": last_played_round(career),
		"rounds_total": rounds_total,
		"complete": next_fixture.is_empty() and rounds_total > 0,
		"next": next_match,
		"last_result": _last_result(career, clubs),
		"form": _recent_form(career, clubs),
		"standings": season_table(career, clubs),
		"promotion_places": CareerPyramids.promotion_places(career.league_id),
		"relegation_places": CareerPyramids.relegation_places(career.league_id),
	}


static func _played_fixtures(career: Career) -> Array:
	var played: Array = []
	for fixture in career.schedule:
		var fixture_id := str(fixture.get("id", ""))
		if not career.results.has(fixture_id):
			continue
		if not _is_league_fixture(career, fixture):
			continue
		if career.club_id not in [str(fixture.get("home", "")), str(fixture.get("away", ""))]:
			continue
		played.append(fixture)
	played.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("round", 0)) != int(b.get("round", 0)):
			return int(a.get("round", 0)) < int(b.get("round", 0))
		return str(a.get("date", "")) < str(b.get("date", "")))
	return played


static func _match_summary(career: Career, fixture: Dictionary, clubs: Dictionary) -> Dictionary:
	var score = career.results.get(str(fixture.get("id", "")))
	if not (score is Dictionary):
		return {}
	var home := str(fixture.get("home", "")) == career.club_id
	var opponent_id := str(fixture.get("away", "")) if home else str(fixture.get("home", ""))
	var opponent: Dictionary = clubs.get(opponent_id, {})
	var goals_for := int(score.get("home", 0)) if home else int(score.get("away", 0))
	var goals_against := int(score.get("away", 0)) if home else int(score.get("home", 0))
	var outcome := "W" if goals_for > goals_against else ("D" if goals_for == goals_against else "L")
	return {
		"fixture_id": str(fixture.get("id", "")),
		"date": str(fixture.get("date", "")),
		"round": int(fixture.get("round", 0)),
		"home": home,
		"goals_for": goals_for,
		"goals_against": goals_against,
		"outcome": outcome,
		"opponent": {
			"id": opponent_id,
			"name": str(opponent.get("name", opponent_id)),
			"logo": _club_logo(opponent),
		},
	}


static func _last_result(career: Career, clubs: Dictionary):
	var played := _played_fixtures(career)
	if played.is_empty():
		return null
	var summary := _match_summary(career, played[-1], clubs)
	return summary if not summary.is_empty() else null


static func _recent_form(career: Career, clubs: Dictionary, limit := 5) -> Array:
	var played := _played_fixtures(career)
	var form: Array = []
	for fixture in played.slice(maxi(0, played.size() - limit)):
		var summary := _match_summary(career, fixture, clubs)
		if not summary.is_empty():
			form.append(summary)
	return form


static func last_played_round(career: Career):
	var played := _played_fixtures(career)
	return int(played[-1].get("round", 0)) if not played.is_empty() else null


static func standings(career: Career, clubs: Dictionary, exclude_round := -1) -> Array:
	var table := {}
	for club_id in clubs:
		var club: Dictionary = clubs[club_id]
		table[club_id] = {
			"club_id": club_id,
			"club_name": str(club.get("name", club_id)),
			"club_logo": _club_logo(club),
			"played": 0, "won": 0, "drawn": 0, "lost": 0,
			"goals_for": 0, "goals_against": 0, "goal_difference": 0, "points": 0,
		}
	for fixture in career.schedule:
		if not _is_league_fixture(career, fixture):
			continue
		if exclude_round >= 0 and int(fixture.get("round", 0)) == exclude_round:
			continue
		var score = career.results.get(str(fixture.get("id", "")))
		if not (score is Dictionary):
			continue
		var home: Dictionary = table.get(str(fixture.get("home", "")), {})
		var away: Dictionary = table.get(str(fixture.get("away", "")), {})
		if home.is_empty() or away.is_empty():
			continue
		var home_goals := int(score.get("home", 0))
		var away_goals := int(score.get("away", 0))
		home["played"] += 1
		away["played"] += 1
		home["goals_for"] += home_goals
		home["goals_against"] += away_goals
		away["goals_for"] += away_goals
		away["goals_against"] += home_goals
		if home_goals > away_goals:
			home["won"] += 1
			away["lost"] += 1
			home["points"] += 3
		elif home_goals < away_goals:
			away["won"] += 1
			home["lost"] += 1
			away["points"] += 3
		else:
			home["drawn"] += 1
			away["drawn"] += 1
			home["points"] += 1
			away["points"] += 1
	var rows: Array = []
	for row in table.values():
		row["goal_difference"] = row["goals_for"] - row["goals_against"]
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) != int(b["points"]):
			return int(a["points"]) > int(b["points"])
		if int(a["goal_difference"]) != int(b["goal_difference"]):
			return int(a["goal_difference"]) > int(b["goal_difference"])
		if int(a["goals_for"]) != int(b["goals_for"]):
			return int(a["goals_for"]) > int(b["goals_for"])
		return str(a["club_name"]) < str(b["club_name"]))
	for index in range(rows.size()):
		rows[index]["position"] = index + 1
	return rows


static func _add_days(iso_date: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(iso_date + "T00:00:00")
	return Time.get_datetime_string_from_unix_time(int(unix) + days * 86400, false).substr(0, 10)


