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


static func simulate(seed: int, fixture: Dictionary, strengths: Dictionary) -> Dictionary:
	var home_strength := float(strengths.get(str(fixture.get("home", "")), 55.0))
	var away_strength := float(strengths.get(str(fixture.get("away", "")), 55.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s" % [seed, str(fixture.get("id", ""))]).hash()
	var home_goals := poisson(rng, expected_goals(home_strength, away_strength, true))
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
	var table := CareerFactory.standings(career, clubs)
	if table.is_empty():
		last_error = "the season table is empty"
		return {}

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
	var promoted: Array = []
	if not above_league.is_empty():
		for row in table.slice(0, mini(CareerFactory.PROMOTION_PLACES, table.size())):
			promoted.append(_row_ref(row))
	var relegated: Array = []
	if not below_league.is_empty():
		for row in table.slice(maxi(0, table.size() - CareerFactory.RELEGATION_PLACES), table.size()):
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
		for club in above.slice(maxi(0, above.size() - CareerFactory.RELEGATION_PLACES), above.size()):
			from_above.append(_club_ref(club))
	var from_below: Array = []
	if movement != "up" and not below.is_empty():
		for club in below.slice(0, mini(CareerFactory.PROMOTION_PLACES, below.size())):
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
		for club in above2.slice(maxi(0, above2.size() - CareerFactory.RELEGATION_PLACES), above2.size()):
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
		for club in below2.slice(0, mini(CareerFactory.PROMOTION_PLACES, below2.size())):
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
	var next_ids_unique := _unique_ids(next_ids)
	career.data["league_club_ids"] = next_ids_unique
	var next_window := LeagueRegulations.window_for_season(career.league_id, new_start)
	var next_schedule_start := str(next_window.get("start", new_start))
	career.data["schedule"] = CareerFactory.build_schedule(next_ids_unique, next_schedule_start,
		str(next_window.get("end", "")), IntlCalendar.rules(), "world")
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
