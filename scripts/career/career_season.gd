class_name CareerSeason
extends RefCounted
# Season calendar ported from server/career/season.py: squad strength, the
# Poisson score line and calendar advance. Pure: the caller supplies the club
# list and the club strengths, so no database reads happen here.

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
