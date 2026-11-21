class_name CareerWorld
extends RefCounted
# Background simulation of another league's season. The first user is ARG2:
# two zones, a zone-winners final and the 15-club Torneo Reducido. It returns
# the two promoted clubs, so the career league's transition can replace its
# relegated clubs with real ones.

static func arg2_promoted(catalog: TeamCatalog, seed: int) -> Array:
	var teams := catalog.all_teams_for_league("ARG2")
	var ids: Array = []
	for team in teams:
		ids.append(str(team.get("id", "")))
	if ids.size() < 16:
		return []
	ids.sort()
	var format = LeagueRegulations.record("ARG2").get("format")
	var stages := CareerStages.stages(format)
	if stages.is_empty():
		return []
	var regular := CareerStages.build_stage(stages[0], ids, "2026-02-13", "2026-11-08")
	var results := {}
	for fixture in regular:
		results[str(fixture.get("id", ""))] = CareerSeason.simulate(
			seed, fixture, {})
	var zones: Array = []
	for group in [0, 1]:
		var group_fixtures: Array = []
		for fixture in regular:
			if int(fixture.get("group", -1)) == group:
				group_fixtures.append(fixture)
		var group_ids := _ids(group_fixtures)
		zones.append(CareerStages.table(group_fixtures, results, group_ids))
	if zones[0].is_empty() or zones[1].is_empty():
		return []
	var zone_a: Array = zones[0]
	var zone_b: Array = zones[1]

	var first := str(zone_a[0].id)
	var second := str(zone_b[0].id)
	var final := _match(seed + 1, first, second)
	var champion := first if int(final.get("home", 0)) > int(final.get("away", 0)) else second
	var runner_up := second if champion == first else first

	var winners: Array = []
	var pairs := [[1, 7], [1, 7], [2, 6], [2, 6], [3, 5], [3, 5], [4, 4]]
	for index in range(pairs.size()):
		var a_index := int(pairs[index][0])
		var b_index := int(pairs[index][1])
		var home := str(zone_a[a_index].id) if index % 2 == 0 else str(zone_b[a_index].id)
		var away := str(zone_b[b_index].id) if index % 2 == 0 else str(zone_a[b_index].id)
		var result := _match(seed + 10 + index, home, away)
		var home_won := int(result.get("home", 0)) > int(result.get("away", 0))
		var draw := int(result.get("home", 0)) == int(result.get("away", 0))
		var winner := home
		if not home_won and not draw:
			winner = away
		elif draw:
			winner = home if a_index < b_index else away
		winners.append({"id": winner, "rank": a_index if winner == home else b_index})

	winners.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if int(x.rank) != int(y.rank):
			return int(x.rank) < int(y.rank)
		return str(x.id) < str(y.id))
	var seeds: Array = [runner_up]
	for winner in winners:
		seeds.append(str(winner.id))
	if seeds.size() < 8:
		return [champion, str(seeds[0]) if seeds.size() > 0 else champion]

	var quarter: Array = []
	for index in range(4):
		var high := str(seeds[index])
		var low := str(seeds[7 - index])
		quarter.append(_two_legs(seed + 30 + index, high, low, high))
	var semi: Array = [
		_two_legs(seed + 40, str(quarter[0]), str(quarter[3]), str(quarter[0])),
		_two_legs(seed + 41, str(quarter[1]), str(quarter[2]), str(quarter[1])),
	]
	var reducido := _two_legs(seed + 50, str(semi[0]), str(semi[1]), str(semi[0]))
	return [champion, reducido]


static func _match(seed: int, home: String, away: String) -> Dictionary:
	return CareerSeason.simulate(seed, {
		"id": "world:%s:%s" % [home, away], "home": home, "away": away,
	}, {})


static func _two_legs(seed: int, first: String, second: String,
		better: String) -> String:
	var leg_one := _match(seed, first, second)
	var leg_two := _match(seed + 1, second, first)
	var first_goals := int(leg_one.get("home", 0)) + int(leg_two.get("away", 0))
	var second_goals := int(leg_one.get("away", 0)) + int(leg_two.get("home", 0))
	if first_goals > second_goals:
		return first
	if second_goals > first_goals:
		return second
	return better


static func _ids(fixtures: Array) -> Array:
	var ids := {}
	for fixture in fixtures:
		ids[str(fixture.get("home", ""))] = true
		ids[str(fixture.get("away", ""))] = true
	var result := ids.keys()
	result.sort()
	return result
