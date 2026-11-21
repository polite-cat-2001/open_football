class_name CareerFactory
extends RefCounted
# Career creation and read models ported from server/career/{core,season,snapshot}.py.
# Only the data the career shell needs today is built; later tickets extend it.

const SCHEDULE_VERSION := 3
const PROMOTION_PLACES := 3
const RELEGATION_PLACES := 3
static var last_error := ""


static func create(
	catalog: TeamCatalog,
	club_id: int,
	manager_name: String,
	nationality_id: int,
	seed := -1
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
	var built := season_schedule(league_id, league_ids, season_start)
	var schedule: Array = built.get("schedule", [])
	var stages_generated: Dictionary = built.get("stages_generated", {})

	var now := Career.utc_now()
	var career := Career.new({
		"version": Career.SAVE_VERSION,
		"id": Career.random_id(),
		"seed": seed if seed >= 0 else Career.random_seed(),
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
		"seasons_completed": 0,
		"schedule_version": SCHEDULE_VERSION,
		"incoming_market_date": season_start,
		"last_tick_date": season_start,
	})
	CareerSquad.ensure_finances(career, squad)
	return career


static func build_schedule(club_ids: Array, start_date := Career.START_DATE,
		end_date := "", rules: Array = [], scope := "world") -> Array:
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
	var dates := _round_dates(start_date, str(end_date), total_rounds, rules, scope)
	for half in [0, 1]:
		for round_index in range(rounds.size()):
			var round_no: int = int(half) * rounds.size() + round_index + 1
			var match_date := _round_date(start_date, span, round_no, total_rounds)
			if round_no <= dates.size():
				match_date = str(dates[round_no - 1])
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
	# A round is a date window, but one league round is one day. Pick the
	# evenly spaced free days so no round lands inside an international pause;
	# when the free days are too few, the old even spread is the fallback.
	if end_date.is_empty() or total_rounds <= 0:
		return []
	var span := CareerSeason.days_between(start_date, end_date)
	if span < 0:
		return []
	var free: Array = []
	for offset in range(span + 1):
		var date := _add_days(start_date, offset)
		if rules.is_empty() or not IntlCalendar.is_blocked(rules, date, scope):
			free.append(date)
	var dates: Array = []
	if free.size() >= total_rounds:
		for index in range(total_rounds):
			var position := 0
			if total_rounds > 1:
				position = int(round(float(index) * float(free.size() - 1) \
					/ float(total_rounds - 1)))
			dates.append(free[position])
		return dates
	for index in range(total_rounds):
		dates.append(_round_date(start_date, span, index + 1, total_rounds))
	return dates


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
		season_start: String) -> Dictionary:
	var window := LeagueRegulations.window_for_season(league_id, season_start)
	var schedule_start := str(window.get("start", season_start))
	var schedule_end := str(window.get("end", ""))
	var format = LeagueRegulations.record(league_id).get("format")
	var schedule: Array = []
	var generated := {}
	if format is Dictionary:
		var stages := CareerStages.stages(format)
		var year := int(CareerSearch.date_parts(season_start)[0])
		var format_start := str(format.get("start_md", ""))
		var stage_offset := 0
		for stage in stages:
			var clauses = stage.get("entrants", [])
			var is_all := clauses is Array and (clauses as Array).size() == 1 \
				and str((clauses as Array)[0].get("rule", "")) == "all"
			if not is_all:
				continue
			var stage_start := _stage_date(year, str(stage.get("start_md", "")), format_start)
			var stage_end := _stage_date(year, str(stage.get("end_md", "")), format_start)
			if stage_start.is_empty():
				stage_start = schedule_start
			if stage_end.is_empty():
				stage_end = schedule_end
			var fixtures := CareerStages.build_stage(stage, club_ids, stage_start, stage_end)
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
			IntlCalendar.rules(), "world")
	return {"schedule": schedule, "stages_generated": generated}


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
	var year := int(CareerSearch.date_parts(career.season_start)[0])
	var format_start := str(format.get("start_md", ""))
	var taken_by_source := {}
	for index in range(1, stages.size()):
		var stage: Dictionary = stages[index]
		var stage_id := str(stage.get("id", ""))
		if str(stage.get("kind", "")) == "knockout":
			# The bracket builder lands with the knockout slice; the regular
			# stages and the aggregate must not wait for it.
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
		var entrants := CareerStages.resolve_entrants(stage, source_table, taken)
		if entrants.is_empty():
			continue
		for club_id in entrants:
			taken[str(club_id)] = true
		taken_by_source[source] = taken
		var round_offset := 0
		for fixture in source_fixtures:
			round_offset = maxi(round_offset, int(fixture.get("round", 0)))
		var start := _stage_date(year, str(stage.get("start_md", "")), format_start)
		var end := _stage_date(year, str(stage.get("end_md", "")), format_start)
		if start.is_empty():
			var last_date := ""
			for fixture in source_fixtures:
				var fixture_date := str(fixture.get("date", ""))
				if fixture_date > last_date:
					last_date = fixture_date
			start = last_date if not last_date.is_empty() \
				else str(window.get("start", career.season_start))
		if end.is_empty():
			end = str(window.get("end", ""))
		var fixtures := CareerStages.build_stage(stage, entrants, start, end)
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
			return stage_table(career, clubs, champion.substr(6))
		if format.get("aggregate") is Array:
			return _aggregate_table(career, clubs, format)
	return standings(career, clubs)


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
	if md.length() != 5:
		return ""
	var stage_year := year
	if not reference_md.is_empty() and md < reference_md:
		stage_year += 1
	return "%04d-%s" % [stage_year, md]


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
		rounds_total = maxi(rounds_total, int(fixture.get("round", 0)))
	var next_match = null
	if not next_fixture.is_empty():
		var home := str(next_fixture.get("home", "")) == career.club_id
		var opponent_id := str(next_fixture.get("away", "")) if home \
			else str(next_fixture.get("home", ""))
		var opponent: Dictionary = clubs.get(opponent_id, {})
		next_match = {
			"fixture_id": str(next_fixture.get("id", "")),
			"date": str(next_fixture.get("date", "")),
			"round": int(next_fixture.get("round", 0)),
			"home": home,
			"competition": str(clubs.get(career.club_id, {}).get("league_name", "")),
			"competition_id": career.league_id,
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
		"promotion_places": PROMOTION_PLACES,
		"relegation_places": RELEGATION_PLACES,
	}


static func _played_fixtures(career: Career) -> Array:
	var played: Array = []
	for fixture in career.schedule:
		var fixture_id := str(fixture.get("id", ""))
		if not career.results.has(fixture_id):
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


