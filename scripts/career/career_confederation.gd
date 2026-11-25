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
	"CONCACAF:CCL": {
		"label": "CONCACAF Champions Cup",
		"rounds": [
			{"name": "round_one", "legs": 2, "window": ["02-03", "02-26"]},
			{"name": "round_of_16", "legs": 2, "window": ["03-10", "03-19"]},
			{"name": "quarter_final", "legs": 2, "window": ["04-07", "04-15"]},
			{"name": "semi_final", "legs": 2, "window": ["04-21", "04-29"]},
			{"name": "final", "legs": 1, "window": ["05-30", "05-30"]},
		],
	},
	"AFC:ACLE": {
		"label": "AFC Champions League Elite",
		"rounds": [
			{"name": "playoff", "legs": 1, "window": ["08-11", "08-12"],
				"region_bracket": true,
				"drop": {"to": "ACL2", "entry": "group_stage", "count": 4}},
			{"name": "league_stage", "legs": 0, "window": ["09-14", "05-01"],
				"groups": {"count": 2, "size": 16, "rounds": 8, "advance": 8},
				"regions": true},
			{"name": "round_of_16", "legs": 1, "window": ["02-10", "02-20"],
				"region_bracket": true},
			{"name": "quarter_final", "legs": 1, "window": ["03-03", "03-12"],
				"region_bracket": true},
			{"name": "semi_final", "legs": 1, "window": ["04-07", "04-16"],
				"region_bracket": true},
			{"name": "final", "legs": 1, "merge": true, "neutral": true,
				"window": ["05-01", "05-02"]},
		],
	},
	"AFC:ACL2": {
		"label": "AFC Champions League Two",
		"rounds": [
			{"name": "preliminary", "legs": 1, "window": ["08-12", "08-20"],
				"drop": {"to": "AFCP", "entry": "group_stage", "count": 3}},
			{"name": "group_stage", "legs": 0, "window": ["09-15", "05-15"],
				"wait_for": {"competition": "ACLE", "round": "playoff"},
				"groups": {"count": 2, "size": 16, "rounds": 6, "advance": 8},
				"regions": true},
			{"name": "round_of_16", "legs": 2, "window": ["02-01", "02-12"],
				"region_bracket": true},
			{"name": "quarter_final", "legs": 2, "window": ["03-01", "03-12"],
				"region_bracket": true},
			{"name": "semi_final", "legs": 2, "window": ["04-01", "04-15"],
				"region_bracket": true},
			{"name": "final", "legs": 1, "merge": true, "neutral": true,
				"window": ["05-15", "05-16"]},
		],
	},
	"AFC:AFCP": {
		"label": "AFC Challenge League",
		"rounds": [
			{"name": "preliminary", "legs": 1, "window": ["08-12", "08-20"],
				"region_bracket": true},
			{"name": "group_stage", "legs": 0, "window": ["10-01", "04-15"],
				"wait_for": {"competition": "ACL2", "round": "preliminary"},
				"groups": {"count": 2, "size": 14, "rounds": 6, "advance": 4},
				"regions": true},
			{"name": "quarter_final", "legs": 2, "window": ["02-15", "02-26"],
				"region_bracket": true},
			{"name": "semi_final", "legs": 2, "window": ["03-15", "03-26"],
				"region_bracket": true},
			{"name": "final", "legs": 1, "merge": true, "neutral": true,
				"window": ["05-10", "05-11"]},
		],
	},
	"CONMEBOL:CLI": {
		"label": "Copa Libertadores",
		"rounds": [
			{"name": "first_stage", "legs": 1, "window": ["02-03", "02-12"]},
			{"name": "second_stage", "legs": 2, "window": ["02-17", "02-26"]},
			{"name": "third_stage", "legs": 2, "window": ["03-03", "03-12"],
				"drop": {"to": "CS", "entry": "group_stage", "count": 4}},
			{"name": "group_stage", "legs": 0, "window": ["04-07", "05-28"],
				"groups": {"count": 8, "size": 4, "rounds": 6, "advance": 2},
				"drop": {"to": "CS", "entry": "playoff", "count": 8}},
			{"name": "round_of_16", "legs": 2, "window": ["08-11", "08-19"]},
			{"name": "quarter_final", "legs": 2, "window": ["09-15", "09-23"]},
			{"name": "semi_final", "legs": 2, "window": ["10-20", "10-28"]},
			{"name": "final", "legs": 1, "window": ["11-28", "11-28"]},
		],
	},
	"CONMEBOL:RECO": {
		"label": "Recopa Sudamericana",
		"rounds": [
			{"name": "final", "legs": 2, "window": ["02-10", "02-24"]},
		],
	},
	"CONMEBOL:CS": {
		"label": "Copa Sudamericana",
		"rounds": [
			{"name": "first_stage", "legs": 1, "window": ["03-03", "03-05"]},
			{"name": "group_stage", "legs": 0, "window": ["04-07", "05-28"],
				"groups": {"count": 8, "size": 4, "rounds": 6, "advance": 2},
				"wait_for": {"competition": "CLI", "round": "third_stage"}},
			{"name": "knockout_playoffs", "legs": 2, "window": ["07-21", "07-30"],
				"playoff": true,
				"wait_for": {"competition": "CLI", "round": "group_stage"}},
			{"name": "round_of_16", "legs": 2, "window": ["08-11", "08-19"]},
			{"name": "quarter_final", "legs": 2, "window": ["09-15", "09-17"]},
			{"name": "semi_final", "legs": 2, "window": ["10-13", "10-21"]},
			{"name": "final", "legs": 1, "window": ["11-21", "11-21"]},
		],
	},
}

const FIRST_SEASON_PATH := "res://assets/data/continental_2026.json"

static var last_error := ""
static var _first_season: Dictionary = {}
static var _countries: Dictionary = {}


static func format_key(confederation: String, competition: String) -> String:
	return "%s:%s" % [confederation.to_upper(), competition]


static func has_format(confederation: String, competition: String) -> bool:
	return FORMATS.has(format_key(confederation, competition))


static func supports(confederation: String) -> bool:
	for key in FORMATS:
		if str(key).begins_with(confederation.to_upper() + ":"):
			return true
	return false


static func confederation_of(country: String) -> String:
	# The confederation a national association belongs to, from the access lists.
	if _countries.is_empty():
		for key in CareerBerths.access():
			var conf = CareerBerths.access()[key]
			if not (conf is Dictionary) or str(key).to_lower() == "uefa":
				continue
			for slot in conf.get("slots", []):
				var name := str((slot as Dictionary).get("country", ""))
				if not name.is_empty():
					_countries[name] = str(conf.get("id", key)).to_upper()
	return str(_countries.get(country, ""))


static func first_season(confederation: String, season_start: String) -> Dictionary:
	# The 2026 field of a calendar-year confederation, used by the first career
	# season. Clubs are already database ids; `missing` lists the real entrants
	# whose association has no league in the database.
	if _first_season.is_empty():
		if not FileAccess.file_exists(FIRST_SEASON_PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(FIRST_SEASON_PATH))
		if not (raw is Dictionary):
			return {}
		_first_season = raw
	var block = _first_season.get(confederation.to_upper(), {})
	if not (block is Dictionary) or block.is_empty():
		return {}
	var competitions := {}
	for competition in block.get("competitions", {}):
		var entry: Dictionary = block["competitions"][competition]
		competitions[competition] = {
			"entries": entry.get("entries", {}),
			"missing": entry.get("missing", []),
			"regions": entry.get("regions", {}),
			"label": str(entry.get("label", competition)),
		}
	return {
		"season": str(block.get("season", "")),
		"competitions": competitions,
		"first_season_of": season_start,
	}


static func build_first_season(catalog: TeamCatalog, confederation: String,
		season_start: String, focus_club: String) -> Dictionary:
	var source := first_season(confederation, season_start)
	if source.is_empty():
		return {}
	var entries := {}
	var missing := {}
	var regions := {}
	for competition in source["competitions"]:
		var entry: Dictionary = source["competitions"][competition]
		entries[competition] = entry.get("entries", {})
		missing[competition] = entry.get("missing", [])
		regions[competition] = entry.get("regions", {})
	var block := build(catalog, confederation, entries, season_start, focus_club,
		regions)
	if block.is_empty():
		return {}
	block["first_season"] = source.get("season", "")
	for competition in missing:
		if block["competitions"].has(competition):
			block["competitions"][competition]["missing"] = missing[competition]
	return block


static func earliest_start(confederation: String, season_start: String) -> String:
	# The first round of any of the confederation's cups, for the season window.
	var year := int(str(season_start).substr(0, 4))
	var best := ""
	for key in FORMATS:
		if not str(key).begins_with(confederation.to_upper() + ":"):
			continue
		var rounds: Array = FORMATS[key].get("rounds", [])
		if rounds.is_empty():
			continue
		var window = (rounds[0] as Dictionary).get("window", [])
		if not (window is Array) or (window as Array).size() < 2:
			continue
		var value := "%04d-%s" % [year, str(window[0])]
		if value < season_start:
			value = "%04d-%s" % [year + 1, str(window[0])]
		if best.is_empty() or value < best:
			best = value
	return best


static func build(catalog: TeamCatalog, confederation: String, entries: Dictionary,
		season_start: String, focus_club: String,
		regions_by_competition: Dictionary = {}) -> Dictionary:
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
			"regions": _region_map(regions_by_competition.get(competition, {})),
			"round_index": 0,
			"entrants": {},
			"sizes": {},
			"fixtures": {},
			"incoming": [],
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
		"regions": regions_by_competition,
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
		var is_group := round.has("groups")
		var is_playoff := round.has("playoff")
		var is_region_group := is_group and bool(round.get("regions", false))
		var is_region_round := bool(round.get("region_bracket", false))
		var is_merge := bool(round.get("merge", false))
		if is_region_round:
			if state.get("region_entrants", {}).is_empty():
				var direct: Array = _entrants(state, index, name)
				if direct.size() < 2:
					state["round_index"] = index + 1
					continue
				state["entrants"][str(index)] = direct
				state["region_entrants"] = _split_regions(direct,
					state.get("regions", {}), state.get("ratings", {}))
			if not _region_round(career, confederation, competition, state, round,
					index, prefix, conf_block):
				return
			state["round_index"] = index + 1
			continue
		if is_merge:
			var merged: Array = []
			for region in state.get("region_entrants", {}):
				var list: Array = state["region_entrants"][region]
				if not list.is_empty():
					merged.append(str(list[0]))
			state["winners"] = merged
		var fixtures: Array = state.get("fixtures", {}).get(str(index), [])
		if fixtures.is_empty():
			if round.has("wait_for") and not _waiting_done(conf_block, round["wait_for"]):
				return
			var entrants: Array = _playoff_entrants(state) if is_playoff \
				else _entrants(state, index, name)
			if is_region_group:
				entrants = _order_by_region(entrants, state.get("regions", {}))
			if entrants.size() < 2:
				# A round without its direct entrants is skipped; a lone club
				# carries over to the next one.
				if entrants.size() == 1:
					state["carry"] = entrants
				state["round_index"] = index + 1
				continue
			state["entrants"][str(index)] = entrants
			if is_group:
				if is_region_group:
					fixtures = _group_fixtures(career, round, entrants, prefix,
						_region_sizes(entrants, state.get("regions", {})))
				else:
					entrants = _snake(entrants, state.get("ratings", {}),
						int(round["groups"].get("count", 1)))
					fixtures = _group_fixtures(career, round, entrants, prefix)
			else:
				var legs := maxi(1, int(round.get("legs", 1)))
				var size := CareerBrackets.round_size(entrants.size())
				state["sizes"][str(index)] = size
				fixtures = CareerBrackets.round_fixtures(
					{"rounds": [{"name": name, "legs": legs}]}, 0, entrants,
					_round_dates(career, round, legs), prefix, size)
			if bool(round.get("neutral", false)):
				for fixture in fixtures:
					fixture["neutral"] = true
			state["fixtures"][str(index)] = fixtures
			_register(career, confederation, competition, index, fixtures,
				state.get("ratings", {}))
		if not _all_played(career, fixtures):
			return
		var entrants_now: Array = state.get("entrants", {}).get(str(index), [])
		var next_entrants: Array = []
		if is_group:
			var resolved := _group_advancers(career, round, entrants_now,
				state["fixtures"][str(index)])
			state["tables"] = resolved.get("tables", {})
			if is_region_group:
				var by_region := {}
				var order := ["west", "east"]
				var groups: Array = resolved.get("groups", [])
				for group_index in range(mini(groups.size(), order.size())):
					by_region[order[group_index]] = groups[group_index]
				state["region_entrants"] = by_region
				next_entrants = []
			else:
				var following: Dictionary = rounds[index + 1] if index + 1 < rounds.size() else {}
				if following.has("playoff"):
					state["group_winners"] = resolved.get("winners", [])
					state["group_runners"] = resolved.get("runners", [])
					state["playoff_incoming"] = state.get("incoming", [])
					next_entrants = []
				else:
					next_entrants = resolved.get("draw", [])
		else:
			var size_now := int(state.get("sizes", {}).get(str(index),
				CareerBrackets.round_size(entrants_now.size())))
			career.data["results"] = CareerBrackets.settle_ties(entrants_now,
				fixtures, career.results, career.seed, {}, size_now)
			next_entrants = CareerBrackets.round_winners(entrants_now, fixtures,
				career.results, size_now)
			if is_playoff:
				state["carry"] = state.get("group_winners", [])
		state["winners"] = next_entrants
		_drop(career, conf_block, round, state, index)
		if index == rounds.size() - 1:
			state["done"] = true
			state["champion"] = str(next_entrants[0]) if not next_entrants.is_empty() else ""
			state["runner_up"] = _final_loser(entrants_now, fixtures,
				int(state.get("sizes", {}).get(str(index), 0)), state["champion"])
			return
		state["round_index"] = index + 1
	if int(state.get("round_index", 0)) >= rounds.size():
		state["done"] = true


static func _register(career: Career, confederation: String, competition: String,
		index: int, fixtures: Array, ratings: Dictionary) -> void:
	var results: Dictionary = career.results
	for fixture in fixtures:
		fixture["competition"] = competition
		fixture["stage"] = competition
		fixture["stage_round"] = index + 1
		fixture["confederation"] = confederation.to_upper()
		if _has_focus(career, fixture):
			career.schedule.append(fixture)
		else:
			results[str(fixture["id"])] = CareerSeason.simulate(career.seed,
				fixture, ratings)
	career.data["results"] = results
	CareerEurope._sort_schedule(career)


static func _snake(entrants: Array, ratings: Dictionary, count: int) -> Array:
	# Pot draw: the strongest clubs spread over the groups, the next band again
	# from group zero. The groups see a balanced field instead of one strong group.
	if count < 2:
		return entrants
	var ordered: Array = entrants.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		if not is_equal_approx(float(ratings.get(a, 55.0)),
				float(ratings.get(b, 55.0))):
			return float(ratings.get(a, 55.0)) > float(ratings.get(b, 55.0))
		return a < b)
	var groups: Array = []
	for group in range(count):
		groups.append([])
	for index in range(ordered.size()):
		(groups[index % count] as Array).append(ordered[index])
	var draw: Array = []
	for group in range(count):
		draw.append_array(groups[group])
	return draw


static func _group_fixtures(career: Career, round: Dictionary, entrants: Array,
		prefix: String, sizes_override: Array = []) -> Array:
	var spec: Dictionary = round["groups"]
	var size := maxi(2, int(spec.get("size", 4)))
	var sizes := sizes_override if not sizes_override.is_empty() \
		else _group_layout(entrants.size(), size, int(spec.get("count", 1)))
	var window := _window(career, round)
	var stage := {
		"kind": "group", "id": prefix + str(round.get("name", "group_stage")),
		"rounds": int(spec.get("rounds", size - 1)),
		"groups": {"sizes": sizes},
	}
	var busy := CareerCalendar.busy_days(career.schedule)
	return CareerStages.build_stage(stage, entrants, str(window[0]),
		str(window[1]), [], "world", busy)


static func _group_layout(clubs: int, size: int, hint: int) -> Array:
	# Even groups, never larger than `size`: a short field loses a club per
	# extra group rather than a whole group.
	var count := clampi(clubs / size, 1, maxi(1, hint))
	if count * size < clubs:
		count = mini(maxi(1, hint), int(ceil(float(clubs) / float(size))))
	var sizes: Array = []
	var remaining := clubs
	for group in range(count):
		var take := mini(size, remaining - (count - group - 1))
		sizes.append(maxi(2, take))
		remaining -= take
	return sizes


static func _group_advancers(career: Career, round: Dictionary, entrants: Array,
		fixtures: Array) -> Dictionary:
	var spec: Dictionary = round["groups"]
	var size := maxi(2, int(spec.get("size", 4)))
	var advance := maxi(1, int(spec.get("advance", 2)))
	var sizes := _group_layout(entrants.size(), size,
		int(spec.get("count", 1)))
	var winners: Array = []
	var runners: Array = []
	var tables := {}
	var ordered_groups: Array = []
	var start := 0
	for group in range(sizes.size()):
		var count := int(sizes[group])
		var ids: Array = []
		var group_fixtures: Array = []
		for index in range(start, mini(entrants.size(), start + count)):
			ids.append(str(entrants[index]))
		for fixture in fixtures:
			if int(fixture.get("group", -1)) == group:
				group_fixtures.append(fixture)
		start += count
		var rows := CareerStages.table(group_fixtures, career.results, ids)
		tables[str(group)] = rows
		var advancers: Array = []
		for rank in range(mini(advance, rows.size())):
			advancers.append(str(rows[rank].get("id", "")))
		ordered_groups.append(advancers)
		if rows.is_empty():
			continue
		winners.append(str(rows[0].get("id", "")))
		if advance >= 2 and rows.size() > 1:
			runners.append(str(rows[1].get("id", "")))
	var draw: Array = winners.duplicate()
	if not winners.is_empty() and runners.size() == winners.size() and advance >= 2:
		# The bracket pairs first with last: winner i meets runner-up i+1.
		draw.resize(winners.size() * 2)
		for index in range(winners.size()):
			draw[index] = winners[index]
			draw[draw.size() - 1 - index] = runners[(index + 1) % runners.size()]
	return {"draw": draw, "winners": winners, "runners": runners, "tables": tables,
		"groups": ordered_groups}


static func _region_map(value) -> Dictionary:
	var map := {}
	if value is Dictionary:
		for region in value:
			var list = value[region]
			if list is Array:
				for club_id in list:
					map[str(club_id)] = str(region)
	return map


static func _order_by_region(entrants: Array, regions_map: Dictionary) -> Array:
	var west: Array = []
	var east: Array = []
	var rest: Array = []
	for club_id in entrants:
		var region := str(regions_map.get(str(club_id), ""))
		if region == "west":
			west.append(str(club_id))
		elif region == "east":
			east.append(str(club_id))
		else:
			rest.append(str(club_id))
	# Clubs without a region (drop-downs from another competition) join the West
	# block, which is where the AFC drop-downs come from.
	var ordered: Array = []
	ordered.append_array(west)
	ordered.append_array(rest)
	ordered.append_array(east)
	return ordered


static func _split_regions(entrants: Array, regions_map: Dictionary,
		ratings: Dictionary) -> Dictionary:
	var split := {}
	for region in ["west", "east"]:
		var list: Array = []
		for club_id in entrants:
			if str(regions_map.get(str(club_id), "")) == region:
				list.append(str(club_id))
		if not list.is_empty():
			list.sort_custom(func(a: String, b: String) -> bool:
				if not is_equal_approx(float(ratings.get(a, 55.0)),
						float(ratings.get(b, 55.0))):
					return float(ratings.get(a, 55.0)) > float(ratings.get(b, 55.0))
				return a < b)
			split[region] = list
	if split.is_empty():
		for club_id in entrants:
			split["west"] = split.get("west", [])
			(split["west"] as Array).append(str(club_id))
	return split


static func _region_sizes(entrants: Array, regions_map: Dictionary) -> Array:
	var sizes: Array = []
	for region in ["west", "east"]:
		var count := 0
		for club_id in entrants:
			if str(regions_map.get(str(club_id), "")) == region:
				count += 1
		if count > 0:
			sizes.append(count)
	# Clubs without a region (drop-downs from another competition) are ordered
	# last, so they extend the last group.
	var assigned := 0
	for size in sizes:
		assigned += int(size)
	if assigned < entrants.size() and not sizes.is_empty():
		sizes[0] = int(sizes[0]) + entrants.size() - assigned
	return sizes


static func _region_round(career: Career, confederation: String, competition: String,
		state: Dictionary, round: Dictionary, index: int, prefix: String,
		conf_block: Dictionary) -> bool:
	# A knockout round played as two independent regional brackets.
	var legs := maxi(1, int(round.get("legs", 1)))
	var stored: Dictionary = state.get("fixtures", {}).get(str(index), {})
	if stored.is_empty():
		var source: Dictionary = state.get("region_entrants", {})
		if source.is_empty():
			return false
		var dates := _round_dates(career, round, legs)
		var created := {}
		for region in source:
			var entrants: Array = source[region]
			if entrants.size() < 2:
				continue
			var size := CareerBrackets.round_size(entrants.size())
			created[region] = CareerBrackets.round_fixtures(
				{"rounds": [{"name": "r", "legs": legs}]}, 0, entrants, dates,
				prefix + region + ":", size)
		state["fixtures"][str(index)] = created
		stored = created
		if stored.is_empty():
			return false
		for region in stored:
			_register(career, confederation, competition, index, stored[region],
				state.get("ratings", {}))
	for region in stored:
		if not _all_played(career, stored[region]):
			return false
	var next := {}
	for region in state.get("region_entrants", {}):
		var entrants: Array = state["region_entrants"][region]
		if entrants.size() == 1:
			# A lone club has no tie: it walks into the next round.
			next[region] = entrants
			continue
		var region_fixtures: Array = stored.get(region, [])
		var size := CareerBrackets.round_size(entrants.size())
		career.data["results"] = CareerBrackets.settle_ties(entrants,
			region_fixtures, career.results, career.seed, {}, size)
		next[region] = CareerBrackets.round_winners(entrants, region_fixtures,
			career.results, size)
	state["region_entrants"] = next
	var all: Array = []
	for region in next:
		all.append_array(next[region])
	state["winners"] = all
	return true


static func _playoff_entrants(state: Dictionary) -> Array:
	var entrants: Array = []
	entrants.append_array(state.get("playoff_incoming", []))
	entrants.append_array(state.get("group_runners", []))
	var ratings: Dictionary = state.get("ratings", {})
	entrants.sort_custom(func(a: String, b: String) -> bool:
		if not is_equal_approx(float(ratings.get(a, 55.0)),
				float(ratings.get(b, 55.0))):
			return float(ratings.get(a, 55.0)) > float(ratings.get(b, 55.0))
		return a < b)
	return entrants


static func _waiting_done(conf_block: Dictionary, spec: Dictionary) -> bool:
	var source = conf_block.get("competitions", {}).get(
		str(spec.get("competition", "")), {})
	if not (source is Dictionary) or (source as Dictionary).is_empty():
		return true
	if bool(source.get("done", false)):
		return true
	var wanted := str(spec.get("round", ""))
	var rounds: Array = source.get("rounds", [])
	for index in range(rounds.size()):
		if str((rounds[index] as Dictionary).get("name", "")) == wanted:
			return int(source.get("round_index", 0)) > index
	return true


static func _drop(career: Career, conf_block: Dictionary, round: Dictionary,
		state: Dictionary, index: int) -> void:
	if not round.has("drop"):
		return
	var rule: Dictionary = round["drop"]
	var dest = conf_block.get("competitions", {}).get(str(rule.get("to", "")), {})
	if not (dest is Dictionary) or (dest as Dictionary).is_empty() \
			or bool(dest.get("done", false)):
		return
	var entry := str(rule.get("entry", "group_stage"))
	var clubs: Array = []
	if entry == "playoff":
		# The third-placed team of every group goes down.
		for group in state.get("tables", {}):
			var rows: Array = state["tables"][group]
			if rows.size() >= 3:
				clubs.append(str(rows[2].get("id", "")))
	else:
		clubs = _round_losers(career, state, index)
	var count := int(rule.get("count", 0))
	if count > 0 and clubs.size() > count:
		clubs = clubs.slice(0, count)
	if entry == "playoff":
		var incoming: Array = dest.get("incoming", [])
		for club in clubs:
			if not incoming.has(club):
				incoming.append(club)
		dest["incoming"] = incoming
		return
	if not (dest as Dictionary).has("entries"):
		return
	for club in clubs:
		if not (dest["entries"] as Dictionary).has(club):
			dest["entries"][club] = entry


static func _round_losers(career: Career, state: Dictionary, index: int) -> Array:
	var entrants: Array = state.get("entrants", {}).get(str(index), [])
	var fixtures: Array = state.get("fixtures", {}).get(str(index), [])
	var size := int(state.get("sizes", {}).get(str(index),
		CareerBrackets.round_size(entrants.size())))
	var winners: Array = state.get("winners", [])
	var losers: Array = []
	var winner_index := 0
	for row in CareerBrackets.tie_results(entrants, fixtures, career.results, size):
		if bool(row.get("bye", false)):
			winner_index += 1
			continue
		var winner := str(winners[winner_index]) if winner_index < winners.size() else ""
		winner_index += 1
		for key in ["first", "second"]:
			var club := str(row.get(key, ""))
			if not club.is_empty() and club != winner:
				losers.append(club)
				break
	return losers


static func _window(career: Career, round: Dictionary) -> Array:
	var window = round.get("window", [])
	if not (window is Array) or (window as Array).size() < 2:
		return [str(career.season_start), str(career.season_start)]
	var year := int(str(career.season_start).substr(0, 4))
	var start := "%04d-%s" % [year, str(window[0])]
	if start < career.season_start:
		start = "%04d-%s" % [year + 1, str(window[0])]
	var end_year := int(start.substr(0, 4))
	if str(window[1]) < str(window[0]):
		end_year += 1
	return [start, "%04d-%s" % [end_year, str(window[1])]]


static func _entrants(state: Dictionary, index: int, name: String) -> Array:
	var entries: Dictionary = state.get("entries", {})
	var entrants: Array = []
	if index > 0:
		entrants = (state.get("winners", []) as Array).duplicate()
	var carry = state.get("carry", [])
	if carry is Array and not (carry as Array).is_empty():
		entrants.append_array(carry)
		state.erase("carry")
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
