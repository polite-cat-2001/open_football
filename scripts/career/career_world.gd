class_name CareerWorld
extends RefCounted
# Background simulation of another league's season. The format drives it: the
# same stage engine builds every phase and bracket, the fixtures are simulated
# with one seed, and the promotion clauses pick the clubs that go up. The
# career transition uses it so a league keeps its size with real promoted clubs
# instead of guessing by rating.

static func league_season(catalog: TeamCatalog, league_id: String,
		season_start: String, seed: int) -> Dictionary:
	var format = LeagueRegulations.record(league_id).get("format")
	var ids: Array = []
	for team in catalog.all_teams_for_league(league_id):
		ids.append(str(team.get("id", "")))
	if ids.is_empty():
		return {}
	ids.sort()
	var clubs := {}
	for club_id in ids:
		clubs[str(club_id)] = {"id": str(club_id), "name": str(club_id)}
	var built := CareerFactory.season_schedule(league_id, ids, season_start)
	if not (built.get("schedule") is Array) or (built["schedule"] as Array).is_empty():
		return {}
	var world := Career.new({
		"seed": seed, "club_id": "", "league_id": league_id,
		"season_start": season_start, "league_club_ids": ids,
		"schedule": built["schedule"],
		"stages_generated": built.get("stages_generated", {}),
		"results": {},
	})
	for guard in range(64):
		CareerFactory.ensure_stages(world)
		var pending: Array = []
		for fixture in world.schedule:
			if not world.results.has(str(fixture.get("id", ""))):
				pending.append(fixture)
		if pending.is_empty():
			break
		for fixture in pending:
			world.data["results"][str(fixture.get("id", ""))] = \
				CareerSeason.simulate(seed, fixture, {})
	var stages := {}
	var decided := {}
	if format is Dictionary:
		for stage in CareerStages.stages(format):
			var stage_id := str(stage.get("id", ""))
			if str(stage.get("kind", "")) == "knockout":
				decided[stage_id] = CareerFactory.stage_decided(world, stage_id)
			else:
				stages[stage_id] = CareerFactory.stage_table(world, {}, stage_id)
	return {
		"table": CareerFactory.season_table(world, clubs),
		"stages": stages,
		"decided": decided,
	}


static func world_season(catalog: TeamCatalog, season_start: String, seed: int,
		skip_league := "", league_ids: Array = []) -> Dictionary:
	# One background table per top league. The career's own league is skipped:
	# its table is the one the career actually played. A league list is only for
	# tests; the real run walks every top tier.
	var wanted := {}
	for league_id in league_ids:
		wanted[str(league_id)] = true
	var tables := {}
	for league in catalog.career_leagues():
		if int(league.get("tier", 0)) != 1:
			continue
		var league_id := str(league.get("id", ""))
		if league_id.is_empty() or league_id == skip_league:
			continue
		if not wanted.is_empty() and not wanted.has(league_id):
			continue
		var season := league_season(catalog, league_id, season_start, seed)
		if season.is_empty():
			continue
		var rows: Array = []
		for row in season.get("table", []):
			rows.append({
				"club_id": str(row.get("club_id", row.get("id", ""))),
				"position": int(row.get("position", 0)),
				"points": int(row.get("points", 0)),
				"played": int(row.get("played", 0)),
			})
		if not rows.is_empty():
			tables[league_id] = rows
	return tables


static func promoted_clubs(catalog: TeamCatalog, league_id: String,
		season_start: String, seed: int) -> Array:
	var format = LeagueRegulations.record(league_id).get("format")
	if not (format is Dictionary):
		return []
	var season := league_season(catalog, league_id, season_start, seed)
	if season.is_empty():
		return []
	var promoted: Array = []
	for clause in format.get("promotion", []):
		var rule := str(clause.get("rule", ""))
		var source := str(clause.get("from", ""))
		var slots := maxi(1, int(clause.get("slots", 1)))
		if rule == "top":
			var table: Array = season.get("stages", {}).get(source, season.get("table", []))
			take_top(table, int(clause.get("rank", 1)), slots, promoted)
		elif rule == "winner" or rule.begins_with("losers"):
			var decided: Dictionary = season.get("decided", {}).get(source, {})
			var key := "winner" if rule == "winner" else "loser"
			var club_id := str(decided.get(key, ""))
			if not club_id.is_empty() and not promoted.has(club_id):
				promoted.append(club_id)
	return promoted


static func relegated_clubs(catalog: TeamCatalog, league_id: String,
		season_start: String, seed: int) -> Array:
	var format = LeagueRegulations.record(league_id).get("format")
	if not (format is Dictionary):
		return []
	var season := league_season(catalog, league_id, season_start, seed)
	if season.is_empty():
		return []
	var relegated: Array = []
	var named := {}
	for clause in format.get("relegation", []):
		var rule := str(clause.get("rule", ""))
		if rule in ["none", "unknown"]:
			continue
		var slots := maxi(1, int(clause.get("slots", 1)))
		var source := str(clause.get("from", ""))
		var table: Array = season.get("stages", {}).get(source, season.get("table", []))
		var index := table.size() - maxi(1, int(clause.get("rank", 1)))
		var added := 0
		while index >= 0 and added < slots:
			var club_id := str((table[index] as Dictionary).get("id", ""))
			if not named.has(club_id):
				relegated.append(club_id)
				named[club_id] = true
				added += 1
			index -= 1
	return relegated


static func take_top(table: Array, rank: int, count: int, into: Array) -> void:
	var index := rank - 1
	var added := 0
	while index < table.size() and added < count:
		var club_id := str((table[index] as Dictionary).get("id", ""))
		if not club_id.is_empty() and not into.has(club_id):
			into.append(club_id)
			added += 1
		index += 1
