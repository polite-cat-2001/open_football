class_name CareerFactory
extends RefCounted
# Career creation and read models ported from server/career/{core,season,snapshot}.py.
# Only the data the career shell needs today is built; later tickets extend it.

const SCHEDULE_VERSION := 2
const PROMOTION_PLACES := 3
const RELEGATION_PLACES := 3
const ROLE_ORDER := {
	"GK": 0, "CB": 1, "LB": 2, "RB": 3, "DM": 4, "CM": 5,
	"LM": 6, "RM": 7, "AM": 8, "CF": 9,
}

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

	var now := Career.utc_now()
	var career := Career.new({
		"version": Career.SAVE_VERSION,
		"id": Career.random_id(),
		"seed": seed if seed >= 0 else Career.random_seed(),
		"date": Career.START_DATE,
		"season_start": Career.START_DATE,
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
		"league_id": str(club.get("league_id", "")),
		"league_club_ids": league_ids,
		"formation": Career.DEFAULT_FORMATION,
		"hub_tab": "centre",
		"schedule": build_schedule(league_ids, Career.START_DATE),
		"schedule_version": SCHEDULE_VERSION,
		"incoming_market_date": Career.START_DATE,
	})
	return career


static func build_schedule(club_ids: Array, start_date := Career.START_DATE) -> Array:
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
	for half in [0, 1]:
		for round_index in range(rounds.size()):
			var round_no: int = int(half) * rounds.size() + round_index + 1
			var match_date := _add_days(start_date, 7 * round_no)
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


static func ensure_schedule(career: Career, league_club_ids: Array) -> void:
	var club_ids: Array = []
	for club_id in league_club_ids:
		club_ids.append(str(club_id))
	if not club_ids.has(career.club_id):
		club_ids.append(career.club_id)
	if not career.data.has("schedule") or career.data.get("schedule") == null:
		career.data["schedule"] = build_schedule(club_ids, career.season_start)
		career.data["schedule_version"] = SCHEDULE_VERSION
		return
	if career.schedule_version >= SCHEDULE_VERSION:
		return
	var corrected := {}
	for fixture in build_schedule(club_ids, career.season_start):
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
	var league_clubs := catalog.all_teams_for_league(str(club.get("league_id", "")))
	var league_ids: Array = []
	for team in league_clubs:
		league_ids.append(str(team.get("id", "")))
	if career.league_club_ids.is_empty():
		career.data["league_club_ids"] = league_ids.duplicate()
	ensure_schedule(career, league_ids)
	var squad := catalog.career_squad(int(career.club_id))
	var sorted_squad := _sort_players(squad)
	var summary := _summary(sorted_squad)
	var groups := _groups(sorted_squad)
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
		"squad": {
			"summary": summary,
			"groups": groups,
			"players": sorted_squad,
			"lineup": sorted_squad.slice(0, mini(11, sorted_squad.size())),
			"bench": sorted_squad.slice(mini(11, sorted_squad.size())),
		},
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


static func _summary(players: Array) -> Dictionary:
	var total_value := 0
	var overalls: Array = []
	var ages: Array = []
	for player in players:
		total_value += int(player.get("market_value", 0))
		overalls.append(float(player.get("overall", 0.0)))
		var age := int(player.get("age", 0))
		if age > 0:
			ages.append(age)
	return {
		"squad_size": players.size(),
		"average_overall": _round1(_array_sum(overalls) / overalls.size()) if not overalls.is_empty() else 0.0,
		"average_age": _round1(float(_array_sum(ages)) / ages.size()) if not ages.is_empty() else null,
		"total_market_value": total_value,
	}


static func _groups(players: Array) -> Array:
	var grouped := {}
	for player in players:
		var role := str(player.get("role", ""))
		if not grouped.has(role):
			grouped[role] = []
		grouped[role].append(player)
	var ordered: Array = []
	for role in ROLE_ORDER:
		if grouped.has(role):
			ordered.append({"role": role, "players": grouped[role]})
	for role in grouped:
		if not ROLE_ORDER.has(role):
			ordered.append({"role": role, "players": grouped[role]})
	return ordered


static func _sort_players(players: Array) -> Array:
	var copy := players.duplicate()
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var role_a := int(ROLE_ORDER.get(str(a.get("role", "")), 99))
		var role_b := int(ROLE_ORDER.get(str(b.get("role", "")), 99))
		if role_a != role_b:
			return role_a < role_b
		if not is_equal_approx(float(a.get("overall", 0.0)),
				float(b.get("overall", 0.0))):
			return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
		return str(a.get("name", "")) < str(b.get("name", "")))
	return copy


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
		"round": int(next_fixture.get("round", rounds_total)) if not next_fixture.is_empty() else rounds_total,
		"played_round": last_played_round(career),
		"rounds_total": rounds_total,
		"complete": next_fixture.is_empty() and rounds_total > 0,
		"next": next_match,
		"last_result": _last_result(career, clubs),
		"form": _recent_form(career, clubs),
		"standings": standings(career, clubs),
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


static func _round1(value: float) -> float:
	return round(value * 10.0) / 10.0


static func _array_sum(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total

