class_name CareerConfederation
extends RefCounted
# Non-UEFA continental cups. Every confederation plays a different ladder, so a
# competition is described by its FORMATS entry: the knockout rounds with their
# legs and calendar windows, and an optional group stage that feeds the final
# knockout. The career club's own ties go into the calendar; every other tie is
# simulated when its round starts.
#
# A season block lives in career.data["continental"][season]["confederations"]
# keyed by the confederation id (CONMEBOL, CONCACAF, AFC, ...).

const FORMATS := {
	"CONCACAF:champions_cup": {
		"label": "CONCACAF Champions Cup",
		"rounds": [
			{"name": "round_one", "legs": 2, "window": ["02-03", "02-26"]},
			{"name": "round_of_16", "legs": 2, "window": ["03-10", "03-19"]},
			{"name": "quarter_final", "legs": 2, "window": ["04-07", "04-15"]},
			{"name": "semi_final", "legs": 2, "window": ["04-21", "04-29"]},
			{"name": "final", "legs": 1, "window": ["05-30", "05-30"]},
		],
	},
}

static var last_error := ""


static func format_key(confederation: String, competition: String) -> String:
	return "%s:%s" % [confederation.to_upper(), competition]


static func has_format(confederation: String, competition: String) -> bool:
	return FORMATS.has(format_key(confederation, competition))


static func build(catalog: TeamCatalog, confederation: String, entries: Dictionary,
		season_start: String, focus_club: String) -> Dictionary:
	# `entries` maps competition id -> {club_id: entry round}. The caller resolves
	# the clubs (the real first-season field or the season's berth map).
	last_error = ""
	var competitions := {}
	for competition in entries:
		if not has_format(confederation, competition):
			continue
		var clubs: Dictionary = entries[competition]
		if clubs.is_empty():
			continue
		var ratings := {}
		for club_id in clubs:
			ratings[str(club_id)] = float(
				catalog.load_team_rating(int(club_id)).get("average", 55.0))
		competitions[competition] = {
			"label": str(FORMATS[format_key(confederation, competition)].get(
				"label", competition)),
			"rounds": FORMATS[format_key(confederation, competition)].get("rounds", []),
			"entries": clubs,
			"ratings": ratings,
			"round_index": 0,
			"entrants": {},
			"sizes": {},
			"fixtures": {},
			"winners": [],
			"champion": "",
			"runner_up": "",
			"done": false,
		}
	if competitions.is_empty():
		return {}
	var focus := ""
	for competition in competitions:
		if (competitions[competition]["entries"] as Dictionary).has(focus_club):
			focus = competition
			break
	return {
		"confederation": confederation.to_upper(),
		"season": season_start,
		"competitions": competitions,
		"focus": focus,
	}


static func ensure(career: Career, catalog: TeamCatalog) -> void:
	# Create the next unfinished round of every confederation cup: the career
	# club's ties go into the calendar, the rest are simulated at once.
	var blocks: Dictionary = career.data.get("continental", {})
	var block = blocks.get(career.season_start, {})
	if not (block is Dictionary):
		return
	for confederation in block.get("confederations", {}):
		var conf_block: Dictionary = block["confederations"][confederation]
		for competition in conf_block.get("competitions", {}):
			_advance(career, conf_block, confederation, competition)


static func _advance(career: Career, conf_block: Dictionary,
		confederation: String, competition: String) -> void:
	var state: Dictionary = conf_block["competitions"][competition]
	if bool(state.get("done", false)):
		return
	var rounds: Array = state.get("rounds", [])
	var prefix := "conf:%s:%s:" % [confederation.to_lower(), competition]
	while int(state.get("round_index", 0)) < rounds.size():
		var index := int(state["round_index"])
		var round: Dictionary = rounds[index]
		var name := str(round.get("name", "r%d" % (index + 1)))
		var fixtures: Array = state.get("fixtures", {}).get(str(index), [])
		if fixtures.is_empty():
			var entrants: Array = _entrants(state, index, name)
			if entrants.size() < 2:
				state["done"] = true
				return
			var legs := maxi(1, int(round.get("legs", 1)))
			var size := CareerBrackets.round_size(entrants.size())
			var stage := {"rounds": [{"name": name, "legs": legs}]}
			var created := CareerBrackets.round_fixtures(stage, 0, entrants,
				_round_dates(career, round, legs), prefix, size)
			state["entrants"][str(index)] = entrants
			state["sizes"][str(index)] = size
			state["fixtures"][str(index)] = created
			var results: Dictionary = career.results
			for fixture in created:
				fixture["competition"] = competition
				fixture["stage"] = competition
				fixture["stage_round"] = index + 1
				fixture["confederation"] = confederation.to_upper()
				if _has_focus(career, fixture):
					career.schedule.append(fixture)
				else:
					results[str(fixture["id"])] = CareerSeason.simulate(career.seed,
						fixture, state.get("ratings", {}))
			career.data["results"] = results
			CareerEurope._sort_schedule(career)
			fixtures = created
		if not _all_played(career, fixtures):
			return
		var entrants_now: Array = state.get("entrants", {}).get(str(index), [])
		var size_now := int(state.get("sizes", {}).get(str(index),
			CareerBrackets.round_size(entrants_now.size())))
		career.data["results"] = CareerBrackets.settle_ties(entrants_now, fixtures,
			career.results, career.seed, {}, size_now)
		var winners := CareerBrackets.round_winners(entrants_now, fixtures,
			career.results, size_now)
		state["winners"] = winners
		if index == rounds.size() - 1:
			state["done"] = true
			state["champion"] = str(winners[0]) if not winners.is_empty() else ""
			state["runner_up"] = _final_loser(entrants_now, fixtures, size_now,
				state["champion"])
			return
		state["round_index"] = index + 1


static func _entrants(state: Dictionary, index: int, name: String) -> Array:
	var entries: Dictionary = state.get("entries", {})
	var entrants: Array = []
	if index > 0:
		entrants = (state.get("winners", []) as Array).duplicate()
	for club_id in entries:
		if str(entries[club_id]) == name:
			entrants.append(str(club_id))
	var ratings: Dictionary = state.get("ratings", {})
	entrants.sort_custom(func(a: String, b: String) -> bool:
		if not is_equal_approx(float(ratings.get(a, 55.0)),
				float(ratings.get(b, 55.0))):
			return float(ratings.get(a, 55.0)) > float(ratings.get(b, 55.0))
		return a < b)
	return entrants


static func _round_dates(career: Career, round: Dictionary, legs: int) -> Array:
	var window = round.get("window", [])
	if not (window is Array) or (window as Array).size() < 2:
		return []
	var year := int(str(career.season_start).substr(0, 4))
	var start := "%04d-%s" % [year, str(window[0])]
	# A winter round of a season that starts in December or July belongs to the
	# next calendar year.
	if start < career.season_start:
		start = "%04d-%s" % [year + 1, str(window[0])]
	var end_year := int(start.substr(0, 4))
	if str(window[1]) < str(window[0]):
		end_year += 1
	var end := "%04d-%s" % [end_year, str(window[1])]
	return CareerEurope._rest_dates(career, start, end, legs)


static func _round_fixtures(career: Career, competition: String,
		stage_round: int) -> Array:
	var rows: Array = []
	for fixture in career.schedule:
		if str(fixture.get("stage", "")) != competition:
			continue
		if int(fixture.get("stage_round", 0)) != stage_round:
			continue
		if not str(fixture.get("confederation", "")).is_empty():
			rows.append(fixture)
	return rows


static func _has_focus(career: Career, fixture: Dictionary) -> bool:
	var home := str(fixture.get("home", ""))
	var away := str(fixture.get("away", ""))
	return home == career.club_id or away == career.club_id


static func _all_played(career: Career, fixtures: Array) -> bool:
	for fixture in fixtures:
		if not career.results.has(str(fixture.get("id", ""))):
			return false
	return true


static func _final_loser(entrants: Array, fixtures: Array, size: int,
		champion: String) -> String:
	for row in CareerBrackets.tie_results(entrants, fixtures, {}, size):
		for key in ["first", "second"]:
			var club_id := str(row.get(key, ""))
			if not club_id.is_empty() and club_id != champion:
				return club_id
	return ""
