class_name CareerSeason
extends RefCounted
# Season calendar ported from server/career/season.py: squad strength, the
# Poisson score line, calendar advance, the season-end transition (promotion /
# relegation) and the next-season rollover.

static var last_error := ""


static func squad_strength(players: Array) -> float:
	var overalls: Array = []
	for player in players:
		overalls.append(float(player.get("overall", 0.0)))
	overalls.sort()
	overalls.reverse()
	var top := overalls.slice(0, mini(11, overalls.size()))
	if top.is_empty():
		return 55.0
	var total := 0.0
	for value in top:
		total += float(value)
	return total / top.size()


static func expected_goals(strength: float, opponent: float, home: bool) -> float:
	var ratio := maxf(0.45, strength) / maxf(0.45, opponent)
	var value := 1.28 * pow(ratio, 2.2) + (0.22 if home else 0.0)
	return clampf(value, 0.25, 4.4)


static func poisson(rng: RandomNumberGenerator, mean: float) -> int:
	var limit := exp(-mean)
	var goals := 0
	var product := 1.0
	while goals < 12:
		product *= rng.randf()
		if product <= limit:
			return goals
		goals += 1
	return goals


static func simulate(seed: int, fixture: Dictionary, strengths: Dictionary,
		neutral := false) -> Dictionary:
	var home_strength := float(strengths.get(str(fixture.get("home", "")), 55.0))
	var away_strength := float(strengths.get(str(fixture.get("away", "")), 55.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s" % [seed, str(fixture.get("id", ""))]).hash()
	var home_goals := poisson(rng, expected_goals(home_strength, away_strength,
		not neutral))
	var away_goals := poisson(rng, expected_goals(away_strength, home_strength, false))
	return {"home": home_goals, "away": away_goals}


static func add_days(iso_date: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(iso_date + "T00:00:00")
	return Time.get_datetime_string_from_unix_time(int(unix) + days * 86400, false).substr(0, 10)


static func days_between(start_date: String, end_date: String) -> int:
	if start_date.length() < 10 or end_date.length() < 10:
		return 0
	var start := Time.get_unix_time_from_datetime_string(start_date + "T00:00:00")
	var end := Time.get_unix_time_from_datetime_string(end_date + "T00:00:00")
	return int(round((end - start) / 86400.0))


static func next_fixture(career: Career) -> Dictionary:
	CareerFactory.ensure_stages(career)
	CareerCompetitions.ensure(career)
	CareerEurope.ensure_knockout(career)
	for fixture in career.schedule:
		var fixture_id := str(fixture.get("id", ""))
		if career.results.has(fixture_id):
			continue
		if career.club_id in [str(fixture.get("home", "")), str(fixture.get("away", ""))]:
			return fixture
	return {}


static func advance_to(career: Career, target: String, league_clubs: Array,
		strengths: Dictionary) -> bool:
	last_error = ""
	var club_ids: Array = []
	for club in league_clubs:
		club_ids.append(str(club.get("id", "")))
	if not club_ids.has(career.club_id):
		club_ids.append(career.club_id)
	CareerFactory.ensure_schedule(career, club_ids)

	var fixture := next_fixture(career)
	if fixture.is_empty():
		last_error = "season is complete"
		return false
	if not _is_iso_date(target):
		last_error = "date must be ISO YYYY-MM-DD"
		return false
	if target < career.date:
		last_error = "cannot move time backwards"
		return false
	if target > str(fixture.get("date", "")):
		last_error = "cannot pass the next match day"
		return false

	career.data["date"] = target
	if not (career.data.get("results") is Dictionary):
		career.data["results"] = {}
	var results: Dictionary = career.data["results"]
	# The round is simulated on arrival at its match day; the career club's own
	# fixture waits for the matchday screen. Already played fixtures are kept.
	for match in career.schedule:
		var fixture_id := str(match.get("id", ""))
		if results.has(fixture_id):
			continue
		if str(match.get("date", "")) > target:
			continue
		if career.club_id in [str(match.get("home", "")), str(match.get("away", ""))]:
			continue
		results[fixture_id] = simulate(career.seed, match, strengths)
	return true


static func next_season_start(career: Career) -> String:
	# The league regulation owns the calendar: the next season opens on the
	# next boundary, not on the window's first matchday.
	var parts := CareerSearch.date_parts(career.season_start)
	if not parts.is_empty():
		var next := LeagueRegulations.boundary(career.league_id, int(parts[0]) + 1)
		if not next.is_empty():
			return next
	# Fallback for a league without a regulation: shift the year (Feb 29 falls
	# back to the 28th), like the prototype.
	if parts.is_empty():
		return career.season_start
	var year := int(parts[0]) + 1
	var month := int(parts[1])
	var day := mini(int(parts[2]), CareerSearch.days_in_month(year, month))
	return "%04d-%02d-%02d" % [year, month, day]


static func season_end(career: Career) -> String:
	# The last day before the next season starts (June 30 for a July 1 start).
	return add_days(next_season_start(career), -1)


static func advance_days(career: Career, target: String) -> bool:
	# Off-season calendar step: no fixtures left, so only the date moves. The
	# hub then runs the normal daily tick for the span.
	last_error = ""
	if not _is_iso_date(target):
		last_error = "date must be ISO YYYY-MM-DD"
		return false
	if target < career.date:
		last_error = "cannot move time backwards"
		return false
	if target > season_end(career):
		last_error = "cannot pass the season end"
		return false
	career.data["date"] = target
	return true


static func transition(catalog: TeamCatalog, career: Career) -> Dictionary:
	# Port of season.py season_transition: rank the finished season and swap
	# the career league with the adjacent tiers (same country, tier_rank ±1/±2).
	last_error = ""
	if catalog == null or career == null:
		last_error = "career is missing"
		return {}
	if not next_fixture(career).is_empty():
		return {}
	var league := catalog.league_by_id(career.league_id)
	if league.is_empty():
		last_error = "career league is missing from the database"
		return {}
	var current_ids: Array = []
	for club_id in career.league_club_ids:
		current_ids.append(str(club_id))
	if current_ids.is_empty():
		for club in catalog.all_teams_for_league(career.league_id):
			current_ids.append(str(club.get("id", "")))
	if not current_ids.has(career.club_id):
		current_ids.append(career.club_id)
	var clubs := {}
	for club_id in current_ids:
		var club := catalog.career_club(int(club_id))
		if not club.is_empty():
			clubs[club_id] = club
	var table := CareerFactory.season_table(career, clubs)
	if table.is_empty():
		last_error = "the season table is empty"
		return {}
	var format = LeagueRegulations.record(career.league_id).get("format")
	if format is Dictionary and _no_format_movement(format):
		var stay_review := {
			"league": _league_ref(league),
			"standings": table,
			"promoted": [],
			"relegated": [],
			"promoted_to": null,
			"relegated_to": null,
			"movement": null,
			"next": {
				"league": _league_ref(league),
				"above": null,
				"below": null,
				"from_above": [],
				"from_below": [],
			},
		}
		return {
			"review": stay_review,
			"league_id": career.league_id,
			"league_club_ids": current_ids,
		}

	if format is Dictionary and _has_format_relegation(format):
		return _format_league_transition(catalog, career, league, current_ids,
			clubs, table, format)

	var rank := _rank_of(league)
	var same_country: Array = []
	for item in catalog.career_leagues():
		if int(item.get("country_id", 0)) == int(league.get("country_id", 0)) \
				and _rank_of(item) < 90:
			same_country.append(item)
	var above_league = _league_at(same_country, rank - 1)
	var below_league = _league_at(same_country, rank + 1)
	var above2_league = _league_at(same_country, rank - 2)
	var below2_league = _league_at(same_country, rank + 2)

	var current_set := {}
	for club_id in current_ids:
		current_set[club_id] = true
	# The movement is per league: the pyramid stores how many clubs really change
	# level through each boundary, and a league without that research keeps the
	# engine default.
	var promoted: Array = []
	if not above_league.is_empty():
		var up_places := mini(CareerPyramids.promotion_places(career.league_id),
			table.size())
		for row in table.slice(0, up_places):
			promoted.append(_row_ref(row))
	var relegated: Array = []
	if not below_league.is_empty():
		var down_places := mini(CareerPyramids.relegation_places(career.league_id),
			table.size())
		for row in table.slice(maxi(0, table.size() - down_places), table.size()):
			relegated.append(_row_ref(row))
	var promoted_ids := {}
	for row in promoted:
		promoted_ids[str(row.get("id", ""))] = true
	var relegated_ids := {}
	for row in relegated:
		relegated_ids[str(row.get("id", ""))] = true
	var movement = null
	if promoted_ids.has(career.club_id):
		movement = "up"
	elif relegated_ids.has(career.club_id):
		movement = "down"

	# Only the tiers the outcome actually needs are loaded. A stay needs the
	# two adjacent tiers; a promotion needs the target tier plus the one above
	# it (to know who leaves it); a relegation mirrors that below.
	var strengths := {}
	var above: Array = []
	var below: Array = []
	var above2: Array = []
	var below2: Array = []
	var above_clubs: Array = []
	var below_clubs: Array = []
	if movement == "up":
		above_clubs = _clubs_of(catalog, above_league, current_set)
		above = _ranked_clubs(above_clubs, catalog, career, strengths)
		above2 = _ranked_clubs(_clubs_of(catalog, above2_league, current_set),
			catalog, career, strengths)
	elif movement == "down":
		below_clubs = _clubs_of(catalog, below_league, current_set)
		below = _ranked_clubs(below_clubs, catalog, career, strengths)
		below2 = _ranked_clubs(_clubs_of(catalog, below2_league, current_set),
			catalog, career, strengths)
	else:
		above_clubs = _clubs_of(catalog, above_league, current_set)
		below_clubs = _clubs_of(catalog, below_league, current_set)
		above = _ranked_clubs(above_clubs, catalog, career, strengths)
		below = _ranked_clubs(below_clubs, catalog, career, strengths)

	var from_above: Array = []
	if movement != "down" and not above.is_empty():
		var above_down := mini(
			CareerPyramids.relegation_places(str(above_league.get("id", ""))),
			above.size())
		for club in above.slice(maxi(0, above.size() - above_down), above.size()):
			from_above.append(_club_ref(club))
	var from_below: Array = []
	if movement != "up" and not below.is_empty():
		var below_up := mini(
			CareerPyramids.promotion_places(str(below_league.get("id", ""))),
			below.size())
		for club in below.slice(0, below_up):
			from_below.append(_club_ref(club))
	var from_above_ids := {}
	for club in from_above:
		from_above_ids[str(club.get("id", ""))] = true
	var from_below_ids := {}
	for club in from_below:
		from_below_ids[str(club.get("id", ""))] = true

	var next_league := {}
	var next_above_league := {}
	var next_below_league := {}
	var next_above: Array = []
	var next_below: Array = []
	var next_ids: Array = []
	if movement == "up":
		next_league = above_league
		next_above_league = above2_league
		var above2_down := mini(
			CareerPyramids.relegation_places(str(above2_league.get("id", ""))),
			above2.size())
		for club in above2.slice(maxi(0, above2.size() - above2_down), above2.size()):
			next_above.append(_club_ref(club))
		next_below_league = league
		next_below = promoted
		for club in above_clubs:
			if not from_above_ids.has(str(club.get("id", ""))):
				next_ids.append(str(club.get("id", "")))
		for row in promoted:
			next_ids.append(str(row.get("id", "")))
	elif movement == "down":
		next_league = below_league
		next_above_league = league
		next_above = relegated
		next_below_league = below2_league
		var below2_up := mini(
			CareerPyramids.promotion_places(str(below2_league.get("id", ""))),
			below2.size())
		for club in below2.slice(0, below2_up):
			next_below.append(_club_ref(club))
		for club in below_clubs:
			if not from_below_ids.has(str(club.get("id", ""))):
				next_ids.append(str(club.get("id", "")))
		for row in relegated:
			next_ids.append(str(row.get("id", "")))
	else:
		next_league = league
		next_above_league = above_league
		next_above = from_above
		next_below_league = below_league
		next_below = from_below
		for club_id in current_ids:
			if not promoted_ids.has(club_id) and not relegated_ids.has(club_id):
				next_ids.append(club_id)
		for club in from_above:
			next_ids.append(str(club.get("id", "")))
		for club in from_below:
			next_ids.append(str(club.get("id", "")))

	next_ids = _unique_ids(next_ids)
	if not next_ids.has(career.club_id):
		next_ids.append(career.club_id)
	var next_above_ref = _league_ref(next_above_league)
	var next_below_ref = _league_ref(next_below_league)
	var from_above_rows: Array = []
	for club in next_above:
		from_above_rows.append({"club": club, "league": next_above_ref})
	var from_below_rows: Array = []
	for club in next_below:
		from_below_rows.append({"club": club, "league": next_below_ref})
	var review := {
		"league": _league_ref(league),
		"standings": table,
		"promoted": promoted,
		"relegated": relegated,
		"promoted_to": _league_ref(above_league) if not promoted.is_empty() else null,
		"relegated_to": _league_ref(below_league) if not relegated.is_empty() else null,
		"movement": movement,
		"next": {
			"league": _league_ref(next_league),
			"above": next_above_ref,
			"below": next_below_ref,
			"from_above": from_above_rows,
			"from_below": from_below_rows,
		},
	}
	return {
		"review": review,
		"league_id": str(next_league.get("id", career.league_id)),
		"league_club_ids": next_ids,
	}


static func next_season(career: Career, catalog: TeamCatalog, transition_data: Dictionary) -> bool:
	# Port of season.py next_season: archive the finished season, shift the year,
	# build the new schedule and roll the squad over. The off-season transfer
	# window is skipped deliberately: the hub reels the calendar to the new
	# season start without generating market activity for the gap.
	last_error = ""
	if catalog == null or career == null:
		last_error = "career is missing"
		return false
	if not next_fixture(career).is_empty():
		last_error = "season is not complete"
		return false
	if transition_data.is_empty() or not (transition_data.get("review") is Dictionary):
		last_error = "season transition is missing"
		return false
	var review: Dictionary = transition_data["review"]
	var table: Array = review.get("standings", [])
	var next_block: Dictionary = review.get("next", {})
	var old_continental: Dictionary = career.data.get("continental", {}).get(
		career.season_start, {})
	if not old_continental.is_empty():
		CareerContinental.finish(catalog, career, old_continental, career.seed)
	var champion := {}
	var own := {}
	if not table.is_empty():
		champion = table[0]
	for row in table:
		if str(row.get("club_id", "")) == career.club_id:
			own = row
			break
	_journal(career, "season.completed", {
		"season_start": career.season_start,
		"champion": str(champion.get("club_name", "")) if not champion.is_empty() else null,
		"position": int(own.get("position", 0)) if not own.is_empty() else null,
		"points": int(own.get("points", 0)) if not own.is_empty() else null,
		"movement": review.get("movement"),
		"league": next_block.get("league"),
	})

	var new_start := next_season_start(career)
	var next_ids: Array = []
	var stored_ids = transition_data.get("league_club_ids", [])
	if stored_ids is Array:
		for club_id in stored_ids:
			next_ids.append(str(club_id))
	if next_ids.is_empty():
		for club_id in career.league_club_ids:
			next_ids.append(str(club_id))
	career.data["season_start"] = new_start
	career.data["date"] = new_start
	career.data["league_id"] = str(transition_data.get("league_id", career.league_id))
	career.data["seasons_completed"] = int(career.data.get("seasons_completed", 0)) + 1
	var next_ids_unique := _unique_ids(next_ids)
	career.data["league_club_ids"] = next_ids_unique
	var history := {}
	history["league_id"] = str(review.get("league", {}).get("id", ""))
	var season_history = career.data.get("season_history")
	if season_history is Array and not (season_history as Array).is_empty():
		var last: Dictionary = (season_history as Array)[-1]
		history["league_rows"] = last.get("rows", [])
		history["season_start"] = str(last.get("season_start", career.season_start))
	if not (history.get("league_rows") is Array) or (history["league_rows"] as Array).is_empty():
		history["league_rows"] = table
		history["season_start"] = career.season_start
	var archive: Array = career.data.get("competition_history") \
		if career.data.get("competition_history") is Array else []
	for entry in career.data.get("competitions", []):
		if not (entry is Dictionary):
			continue
		if str(entry.get("kind", "")) not in ["cup", "super_cup"]:
			continue
		if str(entry.get("winner", "")).is_empty():
			continue
		var archived := false
		for item in archive:
			if str(item.get("season_start", "")) == career.season_start \
					and str(item.get("id", "")) == str(entry.get("id", "")):
				archived = true
				break
		if archived:
			continue
		archive.append({
			"season_start": career.season_start,
			"id": str(entry.get("id", "")),
			"winner": str(entry.get("winner", "")),
			"runner_up": str(entry.get("runner_up", "")),
		})
	career.data["competition_history"] = archive
	history["cups"] = archive
	var cups_by_label := {}
	for entry in career.data.get("competitions", []):
		if not (entry is Dictionary) or str(entry.get("kind", "")) != "cup":
			continue
		if str(entry.get("winner", "")).is_empty():
			continue
		cups_by_label[str(entry.get("label", ""))] = {
			"winner": str(entry.get("winner", "")),
			"runner_up": str(entry.get("runner_up", "")),
		}
	var world_seasons: Dictionary = career.data.get("world_seasons", {})
	if not world_seasons.has(career.season_start):
		world_seasons[career.season_start] = CareerWorld.world_season(catalog,
			career.season_start, career.seed, career.league_id)
		career.data["world_seasons"] = world_seasons
	var old_league_id := str(review.get("league", {}).get("id", career.league_id))
	var old_league := catalog.league_by_id(old_league_id)
	var country_id := int(old_league.get("country_id", 0))
	var country := str(catalog.country_by_id(country_id).get("name", ""))
	var top_league_id := ""
	for league in catalog.career_leagues():
		if int(league.get("country_id", 0)) == country_id \
				and int(league.get("tier", 0)) == 1:
			top_league_id = str(league.get("id", ""))
			break
	var berth_rows: Array = []
	if top_league_id == old_league_id:
		berth_rows = table
	else:
		berth_rows = world_seasons.get(career.season_start, {}).get(top_league_id, [])
	var world_cups: Dictionary = career.data.get("world_cups", {})
	if not world_cups.has(career.season_start):
		var simulated := CareerWorld.world_cups(catalog, career.season_start,
			career.seed)
		simulated[country] = cups_by_label
		world_cups[career.season_start] = simulated
		career.data["world_cups"] = world_cups
	var top_by_country := {}
	for league in catalog.career_leagues():
		if int(league.get("tier", 0)) != 1:
			continue
		var name := str(catalog.country_by_id(
			int(league.get("country_id", 0))).get("name", ""))
		if not name.is_empty() and not top_by_country.has(name):
			top_by_country[name] = str(league.get("id", ""))
	var association_berths := {}
	var countries := {}
	var access := CareerBerths.access()
	var uefa = access.get("uefa", {})
	if uefa is Dictionary:
		for row in uefa.get("coefficients", []):
			countries[str((row as Dictionary).get("association", ""))] = true
	for key in access:
		if str(key) == "uefa":
			continue
		var conf = access[key]
		if not (conf is Dictionary):
			continue
		for slot in conf.get("slots", []):
			countries[str((slot as Dictionary).get("country", ""))] = true
	var dynamic := str(career.data.get("country_coefficients_mode", "static")) == "dynamic"
	var dynamic_ranks := {}
	var dynamic_eps := {}
	if dynamic:
		var country_table = career.data.get("country_coefficients", {})
		if country_table is Dictionary and not (country_table as Dictionary).is_empty():
			var ranking := CareerCountryCoefficients.ranking(country_table)
			for index in range(ranking.size()):
				dynamic_ranks[CareerCountryCoefficients.access_name(
					str(ranking[index]))] = index + 1
			var scores: Array = []
			for association in ranking:
				var row = country_table[association]
				var last := 0.0
				if row is Array and not (row as Array).is_empty():
					last = float((row as Array)[-1])
				scores.append({"name": str(association), "score": last})
			scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if not is_equal_approx(float(a.get("score", 0.0)),
						float(b.get("score", 0.0))):
					return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
				return str(a.get("name", "")) < str(b.get("name", "")))
			for index in range(mini(2, scores.size())):
				dynamic_eps[CareerCountryCoefficients.access_name(
					str((scores[index] as Dictionary).get("name", "")))] = true
	var country_keys := countries.keys()
	country_keys.sort()
	for name in country_keys:
		if str(name).is_empty():
			continue
		var rows: Array = []
		if name == country:
			rows = berth_rows
		else:
			var top_id := str(top_by_country.get(name, ""))
			if not top_id.is_empty():
				rows = world_seasons.get(career.season_start, {}).get(top_id, [])
		var cup_map: Dictionary = {}
		if name == country:
			cup_map = cups_by_label
		else:
			var by_country = world_cups.get(career.season_start, {})
			if by_country is Dictionary:
				cup_map = by_country.get(name, {})
		var rank_override := int(dynamic_ranks.get(str(name), -1)) if dynamic else -1
		var eps_override = dynamic_eps.has(str(name)) if dynamic else null
		var block := CareerBerths.for_country(str(name), rows, cup_map,
			rank_override, eps_override)
		if not block.is_empty():
			association_berths[str(name)] = block
	if not association_berths.is_empty():
		var all_berths: Dictionary = career.data.get("berths", {})
		all_berths[new_start] = association_berths
		career.data["berths"] = all_berths
		var continental: Dictionary = career.data.get("continental", {})
		if not continental.has(new_start):
			var built_continental := CareerContinental.build(catalog,
				association_berths, career.seed,
				old_continental.get("champions", {}),
				career.data.get("europe_forced", {}), career.club_id)
			if not built_continental.is_empty():
				var focus_fixtures: Array = built_continental.get(
					"focus_fixtures", [])
				if not focus_fixtures.is_empty():
					built_continental["qualifying_pending"] = true
					built_continental["qualifying_focus"] = career.club_id
					built_continental["qualifying_competition"] = str(
						(focus_fixtures[0] as Dictionary).get("europe", ""))
				continental[new_start] = built_continental
				career.data["continental"] = continental
		var confederation_fields := _confederation_fields(association_berths,
			old_continental)
		if not confederation_fields.is_empty():
			var season_block: Dictionary = continental.get(new_start, {})
			season_block["confederations"] = season_block.get("confederations", {})
			for conf in confederation_fields:
				var built_conf := CareerConfederation.build(catalog, conf,
					confederation_fields[conf], new_start, career.club_id)
				if not built_conf.is_empty():
					season_block["confederations"][conf] = built_conf
			continental[new_start] = season_block
			career.data["continental"] = continental
	var new_block: Dictionary = career.data.get("continental", {}).get(new_start, {})
	var rankings = career.data.get("coefficients", {})
	if not new_block.is_empty() and rankings is Dictionary and not rankings.is_empty():
		new_block["coefficients"] = rankings
		for comp in new_block.get("competitions", {}):
			new_block["competitions"][comp]["coefficients"] = rankings
	var schedule_block: Dictionary = career.data.get("continental", {}).get(
		new_start, {})
	var pending := bool(schedule_block.get("qualifying_pending", false))
	if pending:
		schedule_block = {}
	var built := CareerCompetitions.build_season(catalog, career.league_id,
		next_ids_unique, new_start, history, schedule_block, career.club_id,
		career.seed)
	career.data["schedule"] = built.get("schedule", [])
	career.data["stages_generated"] = built.get("stages_generated", {})
	career.data["competitions"] = built.get("competitions", [])
	if pending:
		CareerEurope.qualifying_fixtures(career, catalog)
	else:
		CareerEurope.ensure_league_phase(career, catalog)
	career.data["schedule_version"] = CareerFactory.SCHEDULE_VERSION
	career.data["results"] = {}
	CareerSquad.rollover_values(career, CareerSquad.roster(
		catalog, career, int(career.club_id), false))
	CareerCondition.reset_season_state(career)
	# The gap between the last match and the new season start stays market-free.
	career.incoming_market_date = new_start
	career.world_market_date = new_start
	career.data["last_tick_date"] = new_start
	# Already-agreed deals complete on the new season date; the window itself is
	# not simulated (the hub only reels the calendar across the gap).
	CareerTransferContracts.execute_pending(career, catalog, new_start)
	CareerIncomingOffers.execute_pending_departures(career, catalog, new_start)
	_journal(career, "season.started", {
		"season_start": new_start,
		"league_id": career.league_id,
	})
	return true


const CHAMPION_BERTHS := {
	"CONMEBOL:CLI": ["CLI", "group_stage"],
	"CONMEBOL:CS": ["CLI", "group_stage"],
	"CONCACAF:CCL": ["CCL", "round_of_16"],
	"AFC:ACLE": ["ACLE", "league_stage"],
	"AFC:ACL2": ["ACLE", "playoff"],
	"AFC:AFCP": ["ACL2", "group_stage"],
}


static func _confederation_fields(berths: Dictionary,
		old_continental: Dictionary = {}) -> Dictionary:
	# Berth map -> {confederation: {competition: {club_id: entry round}}}. Only
	# the confederations with a modelled format are taken.
	var result := {}
	for country in berths:
		var block = berths[country]
		if not (block is Dictionary):
			continue
		var conf := str(block.get("confederation", "")).to_upper()
		if not CareerConfederation.supports(conf):
			continue
		for berth in block.get("berths", []):
			if not (berth is Dictionary):
				continue
			var competition := str(berth.get("competition", ""))
			if not CareerConfederation.has_format(conf, competition):
				continue
			var club_id := str(berth.get("club_id", ""))
			if club_id.is_empty():
				continue
			if not result.has(conf):
				result[conf] = {}
			if not (result[conf] as Dictionary).has(competition):
				result[conf][competition] = {}
			if not (result[conf][competition] as Dictionary).has(club_id):
				result[conf][competition][club_id] = str(berth.get("entry", ""))
	# Champions take their automatic berth in the next season, as in the rules.
	var old_block: Dictionary = old_continental.get("confederations", {})
	for conf in old_block:
		var competitions: Dictionary = old_block[conf].get("competitions", {})
		for competition in competitions:
			var rule = CHAMPION_BERTHS.get("%s:%s" % [conf, competition])
			if not (rule is Array):
				continue
			var champion := str(competitions[competition].get("champion", ""))
			if champion.is_empty():
				continue
			var target := str(rule[0])
			var stage := str(rule[1])
			if not result.has(conf):
				result[conf] = {}
			if not (result[conf] as Dictionary).has(target):
				result[conf][target] = {}
			if not (result[conf][target] as Dictionary).has(champion):
				result[conf][target][champion] = stage
	# Recopa Sudamericana: the two CONMEBOL champions of the previous season.
	var conmebol: Dictionary = old_block.get("CONMEBOL", {}).get("competitions", {})
	var libertadores := str(conmebol.get("CLI", {}).get("champion", ""))
	var sudamericana := str(conmebol.get("CS", {}).get("champion", ""))
	if not libertadores.is_empty() and not sudamericana.is_empty() \
			and libertadores != sudamericana:
		if not result.has("CONMEBOL"):
			result["CONMEBOL"] = {}
		result["CONMEBOL"]["RECO"] = {
			libertadores: "final", sudamericana: "final",
		}
	return result


static func _journal(career: Career, kind: String, payload: Dictionary) -> void:
	var journal: Array = career.data.get("journal", [])
	journal.append({"seq": journal.size() + 1, "type": kind, "payload": payload})
	career.data["journal"] = journal


static func _clubs_of(catalog: TeamCatalog, league: Dictionary,
		exclude: Dictionary = {}) -> Array:
	if league.is_empty():
		return []
	var result: Array = []
	for club in catalog.all_teams_for_league(str(league.get("id", ""))):
		if not exclude.has(str(club.get("id", ""))):
			result.append(club)
	return result


static func _league_at(leagues: Array, rank: int) -> Dictionary:
	for league in leagues:
		if _rank_of(league) == rank:
			return league
	return {}


static func _has_format_relegation(format: Dictionary) -> bool:
	var clauses = format.get("relegation")
	if not (clauses is Array):
		return false
	for clause in clauses:
		if str(clause.get("rule", "")) not in ["none", "unknown"]:
			return true
	return false


static func _format_league_transition(catalog: TeamCatalog, career: Career,
		league: Dictionary, current_ids: Array, clubs: Dictionary, table: Array,
		format: Dictionary) -> Dictionary:
	var completed := int(career.data.get("seasons_completed", 0))
	var promoted := _format_promoted(career, catalog, clubs, table, format)
	var relegated := _format_relegated(career, catalog, clubs, table, format, completed)
	var above := _above_league(catalog, league)
	var below := _below_league(catalog, league)
	var incoming: Array = []
	if not relegated.is_empty():
		incoming = _movement_in(catalog, career, below,
			maxi(1, relegated.size()))
	var above_relegated: Array = []
	if not promoted.is_empty():
		above_relegated = _movement_out(catalog, career, above,
			maxi(1, promoted.size()))
	var promoted_ids := {}
	for row in promoted:
		promoted_ids[str(row.get("club_id", row.get("id", "")))] = true
	var relegated_ids := {}
	for row in relegated:
		relegated_ids[str(row.get("club_id", row.get("id", "")))] = true
	var incoming_ids := {}
	for club in incoming:
		incoming_ids[str(club.get("id", ""))] = true
	var above_ids := {}
	for club in above_relegated:
		above_ids[str(club.get("id", ""))] = true

	var movement = null
	if promoted_ids.has(career.club_id):
		movement = "up"
	elif relegated_ids.has(career.club_id):
		movement = "down"

	var next_league := league
	var next_ids: Array = []
	var from_above: Array = []
	var from_below: Array = []
	if movement == "up" and not above.is_empty():
		next_league = above
		for club in _clubs_of(catalog, above):
			var club_id := str(club.get("id", ""))
			if not above_ids.has(club_id):
				next_ids.append(club_id)
		for row in promoted:
			var club_id := str(row.get("club_id", row.get("id", "")))
			if not next_ids.has(club_id):
				next_ids.append(club_id)
		for club in above_relegated:
			from_above.append({"club": _club_ref(club),
				"league": _league_ref(above)})
		for row in relegated:
			from_below.append({"club": _row_ref(row),
				"league": _league_ref(below)})
	elif movement == "down" and not below.is_empty():
		next_league = below
		for club in _clubs_of(catalog, below):
			var club_id := str(club.get("id", ""))
			if not incoming_ids.has(club_id):
				next_ids.append(club_id)
		for row in relegated:
			var club_id := str(row.get("club_id", row.get("id", "")))
			if not next_ids.has(club_id):
				next_ids.append(club_id)
		for club in incoming:
			from_below.append({"club": _club_ref(club),
				"league": _league_ref(below)})
	else:
		for club_id in current_ids:
			if not promoted_ids.has(str(club_id)) \
					and not relegated_ids.has(str(club_id)):
				next_ids.append(str(club_id))
		for club in above_relegated:
			var club_id := str(club.get("id", ""))
			if not next_ids.has(club_id):
				next_ids.append(club_id)
			from_above.append({"club": _club_ref(club),
				"league": _league_ref(above)})
		for club in incoming:
			var club_id := str(club.get("id", ""))
			if not next_ids.has(club_id):
				next_ids.append(club_id)
			from_below.append({"club": _club_ref(club),
				"league": _league_ref(below)})

	var history: Array = career.data.get("season_history") \
		if career.data.get("season_history") is Array else []
	history.append({"season_start": career.season_start, "rows": table})
	career.data["season_history"] = history
	var review: Dictionary = {
		"league": _league_ref(league),
		"standings": table,
		"promoted": promoted,
		"relegated": relegated,
		"promoted_to": _league_ref(above) if movement == "up" else null,
		"relegated_to": _league_ref(below) if movement == "down" else null,
		"movement": movement,
		"next": {
			"league": _league_ref(next_league),
			"above": _league_ref(league) if movement == "up" else null,
			"below": _league_ref(below) if movement == "down" else null,
			"from_above": from_above,
			"from_below": from_below,
		},
	}
	return {
		"review": review,
		"league_id": str(next_league.get("id", career.league_id)),
		"league_club_ids": next_ids,
	}


static func _format_promoted(career: Career, catalog: TeamCatalog,
		clubs: Dictionary, table: Array, format: Dictionary) -> Array:
	var result: Array = []
	var named := {}
	for clause in format.get("promotion", []):
		var rule := str(clause.get("rule", ""))
		var source := str(clause.get("from", ""))
		var slots := int(clause.get("slots", 1))
		if slots <= 0:
			continue
		if rule == "top":
			var rows := _source_rows(career, clubs, table, source)
			_take_top(rows, slots, int(clause.get("rank", 1)), named, result)
		elif rule == "winner" or rule.begins_with("losers"):
			var decided := CareerFactory.stage_decided(career, source)
			var key := "winner" if rule == "winner" else "loser"
			var club_id := str(decided.get(key, ""))
			if club_id.is_empty() or named.has(club_id):
				continue
			var club := catalog.career_club(int(club_id))
			result.append({
				"club_id": club_id,
				"club_name": str(club.get("name", club_id)),
				"club_logo": _club_logo(club),
			})
			named[club_id] = true
	return result


static func _source_rows(career: Career, clubs: Dictionary, table: Array,
		source: String) -> Array:
	if source.is_empty() or source == "aggregate":
		return table
	var rows := CareerFactory.stage_table(career, clubs, source)
	return rows if not rows.is_empty() else table


static func _movement_in(catalog: TeamCatalog, career: Career,
		below: Dictionary, slots: int) -> Array:
	if below.is_empty():
		return []
	var club_ids := CareerWorld.promoted_clubs(catalog, str(below.get("id", "")),
		career.season_start, career.seed + int(CareerSearch.date_parts(career.season_start)[0]))
	var clubs: Array = []
	for club_id in club_ids:
		var club := catalog.career_club(int(club_id))
		if not club.is_empty():
			clubs.append(club)
	if not clubs.is_empty():
		return clubs.slice(0, slots)
	return _rated_movement(catalog, career, below, slots, false)


static func _movement_out(catalog: TeamCatalog, career: Career,
		above: Dictionary, slots: int) -> Array:
	if above.is_empty():
		return []
	var club_ids := CareerWorld.relegated_clubs(catalog, str(above.get("id", "")),
		career.season_start, career.seed + int(CareerSearch.date_parts(career.season_start)[0]))
	var clubs: Array = []
	for club_id in club_ids:
		var club := catalog.career_club(int(club_id))
		if not club.is_empty():
			clubs.append(club)
	if not clubs.is_empty():
		return clubs.slice(0, slots)
	return _rated_movement(catalog, career, above, slots, true)


static func _rated_movement(catalog: TeamCatalog, career: Career,
		league: Dictionary, slots: int, from_bottom: bool) -> Array:
	# A league without a finished table of its own falls back to the rating
	# order, the same approximation the legacy pyramid transition uses.
	var ranked := _ranked_clubs(_clubs_of(catalog, league), catalog, career, {})
	if ranked.is_empty():
		return []
	if from_bottom:
		return ranked.slice(maxi(0, ranked.size() - slots), ranked.size())
	return ranked.slice(0, mini(slots, ranked.size()))


static func _above_league(catalog: TeamCatalog, league: Dictionary) -> Dictionary:
	var rank := _rank_of(league)
	for item in catalog.career_leagues():
		if int(item.get("country_id", 0)) == int(league.get("country_id", 0)) \
				and _rank_of(item) == rank - 1:
			return item
	return {}


static func _take_top(table: Array, slots: int, rank: int, named: Dictionary,
		result: Array) -> void:
	var index := rank - 1
	var added := 0
	while index < table.size() and added < slots:
		var row: Dictionary = table[index]
		var club_id := str(row.get("club_id", row.get("id", "")))
		if not named.has(club_id):
			result.append(row)
			named[club_id] = true
			added += 1
		index += 1


static func _format_relegated(career: Career, catalog: TeamCatalog,
		clubs: Dictionary, table: Array, format: Dictionary,
		completed: int) -> Array:
	var result: Array = []
	var named := {}
	for clause in format.get("relegation", []):
		var rule := str(clause.get("rule", ""))
		var slots := int(clause.get("slots", 0))
		var rank := int(clause.get("rank", 1))
		if slots <= 0:
			continue
		var rows := _source_rows(career, clubs, table, str(clause.get("from", "")))
		if rule == "average":
			if completed < 2:
				result.append_array(_take_bottom(rows, slots, 1, named))
			else:
				var order := _average_order(career, rows)
				result.append_array(_take_bottom(order, slots, 1, named))
		elif rule == "bottom":
			result.append_array(_take_bottom(rows, slots, rank, named))
	return result


static func _take_bottom(table: Array, slots: int, rank: int,
		named: Dictionary) -> Array:
	var result: Array = []
	var index := table.size() - rank
	while index >= 0 and result.size() < slots:
		var row: Dictionary = table[index]
		var club_id := str(row.get("club_id", row.get("id", "")))
		if not named.has(club_id):
			result.append(row)
			named[club_id] = true
		index -= 1
	return result


static func _average_order(career: Career, current: Array) -> Array:
	var stats := {}
	for row in current:
		stats[str(row.get("club_id", ""))] = {
			"points": 0, "played": 0,
			"club_name": str(row.get("club_name", "")),
			"club_logo": str(row.get("club_logo", "")),
		}
	var history: Array = career.data.get("season_history") \
		if career.data.get("season_history") is Array else []
	var tables: Array = [current]
	for entry in history:
		if entry.get("rows") is Array:
			tables.append(entry.get("rows"))
	for rows in tables:
		for row in rows:
			var club_id := str(row.get("club_id", ""))
			if not stats.has(club_id):
				continue
			stats[club_id]["points"] += int(row.get("points", 0))
			stats[club_id]["played"] += int(row.get("played", 0))
	var order: Array = []
	for club_id in stats:
		var row: Dictionary = stats[club_id]
		var played := maxi(1, int(row.get("played", 0)))
		order.append({
			"club_id": club_id,
			"club_name": row.get("club_name", club_id),
			"club_logo": row.get("club_logo", ""),
			"points": row.get("points", 0),
			"played": row.get("played", 0),
			"average": float(row.get("points", 0)) / float(played),
		})
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.average), float(b.average)):
			return float(a.average) < float(b.average)
		return str(a.club_id) < str(b.club_id))
	for index in range(order.size()):
		order[index]["position"] = index + 1
	return order


static func _below_league(catalog: TeamCatalog, league: Dictionary) -> Dictionary:
	var rank := _rank_of(league)
	for item in catalog.career_leagues():
		if int(item.get("country_id", 0)) == int(league.get("country_id", 0)) \
				and _rank_of(item) == rank + 1:
			return item
	return {}


static func _no_format_movement(format: Dictionary) -> bool:
	for key in ["promotion", "relegation"]:
		var clauses = format.get(key)
		if not (clauses is Array) or (clauses as Array).is_empty():
			return false
		for clause in clauses:
			if str(clause.get("rule", "")) not in ["none", "unknown"]:
				return false
	return true


static func _rank_of(league: Dictionary) -> int:
	# The prototype's canon carries tier_rank; the unified database stores the
	# same order in `tier`. Prefer tier_rank when it is present.
	var rank := int(league.get("tier_rank", 0))
	return rank if rank > 0 else int(league.get("tier", 0))


static func _ranked_clubs(clubs: Array, catalog: TeamCatalog, career: Career,
		strengths: Dictionary) -> Array:
	var ranked: Array = clubs.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var id_a := str(a.get("id", ""))
		var id_b := str(b.get("id", ""))
		if not strengths.has(id_a):
			strengths[id_a] = squad_strength(CareerSquad.roster(catalog, career,
				int(id_a), false))
		if not strengths.has(id_b):
			strengths[id_b] = squad_strength(CareerSquad.roster(catalog, career,
				int(id_b), false))
		if not is_equal_approx(float(strengths[id_a]), float(strengths[id_b])):
			return float(strengths[id_a]) > float(strengths[id_b])
		return str(a.get("name", "")) < str(b.get("name", "")))
	return ranked


static func _club_ref(club: Dictionary) -> Dictionary:
	return {
		"id": str(club.get("id", "")),
		"name": str(club.get("name", "")),
		"logo": _club_logo(club),
	}


static func _row_ref(row: Dictionary) -> Dictionary:
	return {
		"id": str(row.get("club_id", "")),
		"name": str(row.get("club_name", "")),
		"logo": str(row.get("club_logo", "")),
		"position": int(row.get("position", 0)),
	}


static func _league_ref(league: Dictionary):
	if league.is_empty():
		return null
	return {"id": str(league.get("id", "")), "name": str(league.get("name", ""))}


static func _unique_ids(club_ids: Array) -> Array:
	var seen := {}
	var result: Array = []
	for club_id in club_ids:
		var key := str(club_id)
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		result.append(key)
	return result


static func play_next_match(career: Career, league_clubs: Array,
		strengths: Dictionary) -> Dictionary:
	last_error = ""
	var club_ids: Array = []
	for club in league_clubs:
		club_ids.append(str(club.get("id", "")))
	if not club_ids.has(career.club_id):
		club_ids.append(career.club_id)
	CareerFactory.ensure_schedule(career, club_ids)

	var fixture := next_fixture(career)
	if fixture.is_empty():
		last_error = "season is complete"
		return {}
	if career.date < str(fixture.get("date", "")):
		last_error = "advance to the match day first"
		return {}

	if not (career.data.get("results") is Dictionary):
		career.data["results"] = {}
	var results: Dictionary = career.data["results"]
	var round_no := int(fixture.get("round", 0))
	for match in career.schedule:
		var fixture_id := str(match.get("id", ""))
		if int(match.get("round", 0)) != round_no or results.has(fixture_id):
			continue
		results[fixture_id] = simulate(career.seed, match, strengths)

	career.data["date"] = add_days(str(fixture.get("date", "")), 1)
	var score: Dictionary = results.get(str(fixture.get("id", "")), {})
	var journal: Array = career.data.get("journal", [])
	journal.append({
		"seq": journal.size() + 1,
		"type": "match.played",
		"payload": {
			"fixture_id": str(fixture.get("id", "")),
			"round": round_no,
			"home": int(score.get("home", 0)),
			"away": int(score.get("away", 0)),
		},
	})
	career.data["journal"] = journal
	return fixture


static func matchday_state(career: Career, clubs: Dictionary,
		competition_name := "") -> Dictionary:
	var round_no = CareerFactory.last_played_round(career)
	if round_no == null:
		return {}
	var fixtures: Array = []
	for fixture in career.schedule:
		if int(fixture.get("round", 0)) == int(round_no):
			fixtures.append(fixture)
	if fixtures.is_empty():
		return {}

	var before := CareerFactory.standings(career, clubs, int(round_no))
	var after := CareerFactory.standings(career, clubs)
	for row in after:
		row["own"] = str(row.get("club_id", "")) == str(career.club_id)
	var previous := {}
	for row in before:
		previous[str(row.get("club_id", ""))] = int(row.get("position", 0))
	for row in after:
		var previous_position = previous.get(str(row.get("club_id", "")))
		row["previous_position"] = previous_position
		row["delta"] = int(previous_position) - int(row.get("position", 0)) \
			if int(round_no) > 1 and previous_position != null else 0

	var results: Array = []
	for fixture in fixtures:
		var score = career.results.get(str(fixture.get("id", "")))
		if not (score is Dictionary):
			continue
		var home: Dictionary = clubs.get(str(fixture.get("home", "")), {})
		var away: Dictionary = clubs.get(str(fixture.get("away", "")), {})
		results.append({
			"fixture_id": str(fixture.get("id", "")),
			"home": {
				"id": str(fixture.get("home", "")),
				"name": str(home.get("name", fixture.get("home", ""))),
				"logo": _club_logo(home),
			},
			"away": {
				"id": str(fixture.get("away", "")),
				"name": str(away.get("name", fixture.get("away", ""))),
				"logo": _club_logo(away),
			},
			"score": {"home": int(score.get("home", 0)), "away": int(score.get("away", 0))},
			"own": career.club_id in [
				str(fixture.get("home", "")), str(fixture.get("away", "")),
			],
		})
	var own_fixture := {}
	for fixture in fixtures:
		if career.club_id in [
				str(fixture.get("home", "")), str(fixture.get("away", ""))]:
			own_fixture = fixture
			break
	return {
		"round": int(round_no),
		"date": str(own_fixture.get("date", fixtures[0].get("date", ""))),
		"competition": competition_name,
		"results": results,
		"standings": after,
	}


static func _club_logo(club: Dictionary) -> String:
	var career_logo := str(club.get("career_logo", ""))
	return career_logo if not career_logo.is_empty() else str(club.get("logo", ""))


static func _is_iso_date(value: String) -> bool:
	if value.length() != 10 or value[4] != "-" or value[7] != "-":
		return false
	var month := int(value.substr(5, 2))
	var day := int(value.substr(8, 2))
	if month < 1 or month > 12 or day < 1 or day > 31:
		return false
	var unix := Time.get_unix_time_from_datetime_string(value + "T00:00:00")
	return Time.get_datetime_string_from_unix_time(int(unix), false).substr(0, 10) == value
