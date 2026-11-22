class_name CareerKnockout
extends RefCounted
# Knockout phase after a 36-club league phase. The top eight go straight to the
# round of 16; places 9-24 play a two-legged play-off, the higher-placed club
# hosting the second leg. The bracket is the standard seeded one: 1 plays the
# winner of 16/17, 2 the winner of 15/18, and so on. Every round is two legs
# except the final.

const PLAYOFF_CLUBS := 24
const ROUNDS := [
	{"name": "playoff", "legs": 2},
	{"name": "r16", "legs": 2},
	{"name": "qf", "legs": 2},
	{"name": "semi", "legs": 2},
	{"name": "final", "legs": 1},
]

static var last_error := ""


static func play(catalog: TeamCatalog, table: Array, seed: int,
		rules: Dictionary = {}) -> Dictionary:
	last_error = ""
	var entrants: Array = []
	for club_id in table:
		var key := str(club_id)
		if not entrants.has(key):
			entrants.append(key)
	if entrants.size() < PLAYOFF_CLUBS:
		last_error = "the league phase has fewer than 24 clubs"
		return {}
	var ratings := {}
	for club_id in entrants:
		ratings[club_id] = float(
			catalog.load_team_rating(int(club_id)).get("average", 55.0))
	var stage := {"rounds": ROUNDS}
	var played: Array = []
	var current := entrants.slice(0, PLAYOFF_CLUBS)
	for round_index in range(ROUNDS.size()):
		if round_index == 2 and current.size() == 8:
			# Official path: 1/8 winner vs 8/9 winner, 4/5 vs 5/12,
			# 3/6 vs 6/11, 2/7 vs 7/10.
			current = [current[0], current[3], current[2], current[1],
				current[6], current[5], current[4], current[7]]
		elif round_index == 3 and current.size() == 4:
			# The two semi-finals: 1/8 vs 4/5 and 3/6 vs 2/7.
			current = [current[0], current[2], current[3], current[1]]
		var fixtures := CareerBrackets.round_fixtures(stage, round_index, current,
			[], "ko:")
		if int((ROUNDS[round_index] as Dictionary).get("legs", 1)) == 2:
			_flip_legs(fixtures)
		var results := {}
		for fixture in fixtures:
			results[str(fixture.get("id", ""))] = CareerSeason.simulate(seed,
				fixture, ratings)
		results = CareerBrackets.settle_ties(current, fixtures, results, seed, rules)
		var winners := CareerBrackets.round_winners(current, fixtures, results)
		played.append({
			"name": str((ROUNDS[round_index] as Dictionary).get("name", "")),
			"entrants": current.duplicate(),
			"fixtures": fixtures,
			"results": results,
			"winners": winners,
		})
		current = winners
		if current.size() == 1:
			break
	if current.size() != 1:
		last_error = "the bracket did not resolve to one winner"
		return {}
	return {"winner": str(current[0]), "rounds": played}


static func _flip_legs(fixtures: Array) -> void:
	# The seeded club is `first`; it must host the second leg.
	for fixture in fixtures:
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		fixture["home"] = away
		fixture["away"] = home
