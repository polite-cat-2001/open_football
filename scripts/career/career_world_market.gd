class_name CareerWorldMarket
extends RefCounted
# AI-to-AI transfer market, ported from server/career/world_market.py: four
# dated batches per window, a deterministic sample of clubs, 0..3 buys and
# sells per club, squad bounds 18..30, a budget of 10% of the squad value, and
# free agents for no fee. Every random value comes from CareerRng, so the same
# seed reproduces the prototype's deals.
#
# The module also owns the world data both market modules read (club list,
# role/market aggregates and free agents). Aggregates come from SQLite once per
# catalog; squads are read per batch for the clubs actually trading, so the
# whole players table never sits in memory.

const SQUAD_MIN := 18
const SQUAD_MAX := 30
const MAX_BUYS := 3
const MAX_SELLS := 3
const BUDGET_SHARE := 0.10
const MIN_MARKET_VALUE := 50000
const DEFAULT_BATCH_CLUBS := 120
const FREE_AGENT_LIMIT := 2000

const WINDOW_BATCHES := ["opening", "middle", "last_week", "last_day"]

const ROLE_TARGETS := {
	"GK": 2, "CB": 3, "LB": 1, "RB": 1, "DM": 1, "CM": 2,
	"LM": 1, "RM": 1, "AM": 1, "CF": 2,
}

static var _catalog: TeamCatalog = null
static var _clubs: Array = []
static var _by_id: Dictionary = {}
static var _role_stats: Dictionary = {}
static var _market_stats: Dictionary = {}
static var _free_agents: Array = []


static func window_bounds(day) -> Array:
	var parts := CareerSearch.date_parts(str(day))
	if parts.is_empty():
		return []
	var year: int = parts[0]
	var month: int = parts[1]
	if month == 1:
		return ["%04d-01-01" % year, "%04d-01-31" % year]
	if month == 7 or month == 8:
		return ["%04d-07-01" % year, "%04d-08-31" % year]
	return []


static func batch_schedule(window_start, window_end) -> Array:
	var start := str(window_start).substr(0, 10)
	var end := str(window_end).substr(0, 10)
	if CareerSearch.date_parts(start).is_empty() or CareerSearch.date_parts(end).is_empty():
		return []
	if end < start:
		return []
	var span := CareerSearch.date_diff_days(start, end)
	var middle := CareerSearch.add_days(start, span / 2)
	var last_week := CareerSearch.add_days(end, -6)
	if last_week < start:
		last_week = start
	var dates := [start, middle, last_week, end]
	var period_starts := [start, middle, last_week, end]
	var period_ends := [
		CareerSearch.add_days(middle, -1),
		CareerSearch.add_days(last_week, -1),
		CareerSearch.add_days(end, -1),
		end,
	]
	var batches: Array = []
	for index in range(WINDOW_BATCHES.size()):
		batches.append({
			"key": "%s:%s" % [start, WINDOW_BATCHES[index]],
			"name": WINDOW_BATCHES[index],
			"date": dates[index],
			"period_start": period_starts[index],
			"period_end": period_ends[index],
			"window_start": start,
			"window_end": end,
		})
	return batches


static func batches_between(previous_date, target_date) -> Array:
	var target := str(target_date).substr(0, 10)
	if CareerSearch.date_parts(target).is_empty():
		return []
	var previous := ""
	if previous_date == null or str(previous_date).is_empty():
		var bounds := window_bounds(target)
		previous = CareerSearch.add_days(bounds[0], -1) if not bounds.is_empty() else target
	else:
		previous = str(previous_date).substr(0, 10)
	if target <= previous:
		return []
	var first_year := int(previous.substr(0, 4))
	var last_year := int(target.substr(0, 4))
	var batches: Array = []
	for year in range(first_year, last_year + 1):
		for month in [1, 7]:
			var bounds := window_bounds("%04d-%02d-01" % [year, month])
			if bounds.is_empty():
				continue
			if bounds[1] < previous or bounds[0] > target:
				continue
			for batch in batch_schedule(bounds[0], bounds[1]):
				var trigger := str(batch.get("date", ""))
				if previous < trigger and trigger <= target:
					batches.append(batch)
	batches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("date", "")) < str(b.get("date", "")))
	return batches


static func process_days(career: Career, catalog: TeamCatalog, from_date, to_date) -> Array:
	# The prototype's advance_world_market: run every batch whose trigger falls
	# inside (previous, target]. The date marker keeps a repeated tick empty.
	if career == null or catalog == null:
		return []
	var target := str(to_date).substr(0, 10)
	if target.is_empty():
		target = career.date
	var previous := "" if from_date == null else str(from_date).substr(0, 10)
	if previous.is_empty():
		previous = career.world_market_date
	var batches := batches_between(previous, target)
	career.world_market_date = target
	if batches.is_empty():
		return []
	var recorded: Array = []
	for batch in batches:
		recorded.append_array(run_batch(career, catalog, batch))
	return _transfer_events(catalog, recorded)


static func run_batch(career: Career, catalog: TeamCatalog, batch: Dictionary,
		batch_clubs := DEFAULT_BATCH_CLUBS) -> Array:
	var own_club_id := str(career.club_id)
	var ai_clubs: Array = []
	for club in clubs(catalog):
		if str(club.get("id", "")) != own_club_id:
			ai_clubs.append(club)
	if ai_clubs.is_empty():
		return []

	var rng := CareerRng.seeded("%d:world-market:%s" % [career.seed,
		str(batch.get("key", ""))])
	var sample: Array
	if ai_clubs.size() > batch_clubs:
		var ordered := ai_clubs.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("id", "")) < str(b.get("id", "")))
		sample = _sample(rng, ordered, batch_clubs)
	else:
		sample = ai_clubs.duplicate()
	var club_ids: Array = []
	for club in sample:
		club_ids.append(str(club.get("id", "")))
	var local_squads := _load_squads(career, catalog, club_ids)
	if local_squads.is_empty():
		return []

	var bought := _window_counts(career, batch, true)
	var sold := _window_counts(career, batch, false)
	var spent := _window_spend(career, batch)
	var acquired := {}
	for transfer in career.world_transfers:
		if not _in_window(transfer, batch):
			continue
		var buyer := str(transfer.get("to_club_id", ""))
		if buyer.is_empty():
			continue
		if not acquired.has(buyer):
			acquired[buyer] = {}
		(acquired[buyer] as Dictionary)[str(transfer.get("player_id", ""))] = true
	var free_pool := free_agents(catalog).duplicate()

	var sale_pool: Array = []
	for club in sample:
		var club_id := str(club.get("id", ""))
		var players: Array = local_squads.get(club_id, [])
		var available := MAX_SELLS - int(sold.get(club_id, 0))
		var room := players.size() - SQUAD_MIN
		var max_sells := maxi(0, mini(available, room))
		if max_sells <= 0:
			continue
		var excess := maxi(0, players.size() - SQUAD_MAX)
		var planned := maxi(rng.randint(0, max_sells), mini(excess, max_sells))
		for player in _select_sellers(players, planned, rng):
			_erase_player(players, str(player.get("id", "")))
			sale_pool.append({
				"player": player,
				"from_club_id": club_id,
				"value": _market_value(player),
			})

	var deals: Array = []
	for club in sample:
		var club_id := str(club.get("id", ""))
		var players: Array = local_squads.get(club_id, [])
		var available := MAX_BUYS - int(bought.get(club_id, 0))
		var room := SQUAD_MAX - players.size()
		var max_buys := maxi(0, mini(available, room))
		if max_buys <= 0:
			continue
		var shortage := maxi(0, SQUAD_MIN - players.size())
		var planned := maxi(rng.randint(0, max_buys), mini(shortage, max_buys))
		for _index in range(planned):
			if players.size() >= SQUAD_MAX:
				break
			var bought_ids: Dictionary = acquired.get(club_id, {})
			var budget_players: Array = []
			for player in players:
				if not bought_ids.has(str(player.get("id", ""))):
					budget_players.append(player)
			var budget_left := club_budget(budget_players) - int(spent.get(club_id, 0))
			var target = null
			if budget_left > 0:
				target = _pick_buyer_target(sale_pool, players, budget_left, rng, club_id)
			if target != null:
				var player: Dictionary = target["player"]
				var value := int(target["value"])
				var factor := 1.0 + rng.next_float() * 0.2
				var fee := _money(maxf(float(value), float(MIN_MARKET_VALUE)) * factor)
				if fee > budget_left:
					_erase_candidate(sale_pool, target)
					continue
				_erase_candidate(sale_pool, target)
				var source_id := str(target["from_club_id"])
				apply_delta(career, source_id, str(player.get("id", "")), false)
				apply_delta(career, club_id, str(player.get("id", "")), true)
				players.append(player)
				if not acquired.has(club_id):
					acquired[club_id] = {}
				(acquired[club_id] as Dictionary)[str(player.get("id", ""))] = true
				spent[club_id] = int(spent.get(club_id, 0)) + fee
				bought[club_id] = int(bought.get(club_id, 0)) + 1
				sold[source_id] = int(sold.get(source_id, 0)) + 1
				deals.append({
					"player": player,
					"from_club_id": source_id,
					"to_club_id": club_id,
					"fee": fee,
				})
				continue

			var free_agent = _pick_free_agent(free_pool, players, rng)
			if free_agent == null:
				break
			apply_delta(career, club_id, str(free_agent.get("id", "")), true)
			players.append(free_agent)
			_erase_player(free_pool, str(free_agent.get("id", "")))
			if not acquired.has(club_id):
				acquired[club_id] = {}
			(acquired[club_id] as Dictionary)[str(free_agent.get("id", ""))] = true
			bought[club_id] = int(bought.get(club_id, 0)) + 1
			deals.append({
				"player": free_agent,
				"from_club_id": null,
				"to_club_id": club_id,
				"fee": 0,
			})

	var dates := _deal_dates(batch, deals.size(), rng)
	var recorded: Array = []
	for index in range(deals.size()):
		var deal: Dictionary = deals[index]
		recorded.append(_record(career, deal["player"], deal["from_club_id"],
			str(deal["to_club_id"]), int(deal["fee"]), dates[index], rng))
	return recorded


static func club_value(players: Array) -> int:
	var total := 0
	for player in players:
		total += int(player.get("market_value", 0))
	return total


static func club_budget(players: Array) -> int:
	return int(float(club_value(players)) * BUDGET_SHARE)


static func role_counts(players: Array) -> Dictionary:
	var counts := {}
	for player in players:
		var role := str(player.get("role", ""))
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


static func effective_players(career: Career, club_id, base_players: Array,
		lookup := Callable()) -> Array:
	# Read the stored map, not the `club_deltas` property: its getter creates an
	# empty key, and a read model must not change the save (a save/compare after
	# a read then differs from one without it).
	var deltas = career.data.get("club_deltas", {})
	var delta: Dictionary = deltas.get(str(club_id), {}) if deltas is Dictionary else {}
	var outgoing := {}
	for player_id in delta.get("out", []):
		outgoing[str(player_id)] = true
	var players: Array = []
	var seen := {}
	for player in base_players:
		var player_id := str(player.get("id", ""))
		if outgoing.has(player_id) or seen.has(player_id):
			continue
		seen[player_id] = true
		players.append(player)
	var added: Array = []
	for player_id in delta.get("in", []):
		var key := str(player_id)
		if outgoing.has(key) or seen.has(key):
			continue
		added.append(key)
	if not added.is_empty() and lookup.is_valid():
		for player in lookup.call(added):
			var player_id := str(player.get("id", ""))
			if seen.has(player_id):
				continue
			seen[player_id] = true
			players.append(player)
	return players


static func current_club_id(career: Career, player_id, fallback := "") -> String:
	var key := str(player_id)
	if career.player_ids.has(key):
		return career.club_id
	var deltas: Dictionary = career.club_deltas
	for club_id in deltas:
		var delta = deltas[club_id]
		if delta is Dictionary and (delta.get("in", []) as Array).has(key):
			return str(club_id)
	return str(fallback)


static func clubs(catalog: TeamCatalog) -> Array:
	if catalog == null:
		return []
	_ensure_cache(catalog)
	return _clubs


static func squad(catalog: TeamCatalog, club_id) -> Array:
	# One club's players, straight from SQLite: the market only ever needs the
	# clubs it trades with, never the whole table.
	if catalog == null:
		return []
	_ensure_cache(catalog)
	var players: Array = []
	for row in _rows_for_clubs(catalog, [club_id]):
		players.append(CareerSearch.normalized_row(row))
	return players


static func free_agents(catalog: TeamCatalog) -> Array:
	if catalog == null:
		return []
	_ensure_cache(catalog)
	return _free_agents


static func club_role_stats(catalog: TeamCatalog) -> Dictionary:
	if catalog == null:
		return {}
	_ensure_cache(catalog)
	return _role_stats


static func club_market_stats(catalog: TeamCatalog) -> Dictionary:
	if catalog == null:
		return {}
	_ensure_cache(catalog)
	return _market_stats


static func player_by_id(catalog: TeamCatalog, player_id) -> Dictionary:
	if catalog == null:
		return {}
	_ensure_cache(catalog)
	var key := str(player_id)
	if not key.is_valid_int():
		return {}
	var cached = _by_id.get(key)
	if cached is Dictionary:
		return cached
	var db := catalog.sql_query()
	if db == null:
		return {}
	var rows: Array = db.call("select",
		"SELECT %s FROM players p WHERE p.id = ?" % CareerSearch.ROW_COLUMNS, [int(key)])
	if rows.is_empty():
		return {}
	var row := CareerSearch.normalized_row(rows[0])
	_by_id[key] = row
	return row


static func _ensure_cache(catalog: TeamCatalog) -> void:
	if catalog == null or _catalog == catalog:
		return
	_catalog = catalog
	_clubs = []
	_by_id = {}
	_role_stats = {}
	_market_stats = {}
	_free_agents = []
	# The club list comes from the catalog's warmed club map (all teams except
	# the synthetic national-team competition), so the market never walks the
	# teams table itself.
	var leagues := {}
	for league in catalog.career_leagues():
		leagues[str(league.get("id", ""))] = league
	for entry in catalog.career_clubs():
		var club := catalog.career_club(int((entry as Dictionary).get("id", 0)))
		if club.is_empty():
			continue
		var league_id := str(club.get("league_id", ""))
		var league = leagues.get(league_id)
		if not (league is Dictionary):
			continue
		_clubs.append({
			"id": str(club.get("id", "")),
			"name": str(club.get("name", "")),
			"league_id": league_id,
			"league_name": str(league.get("name", "")),
			"tier_rank": int(league.get("tier_rank", 0)),
			"country_id": str(club.get("country_id", "")),
			"country_name": str(club.get("country_name", "")),
			"logo": CareerSearch.club_logo(club),
		})
	# canon.clubs order: country, league tier, league name, club name.
	_clubs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("country_name", "")) != str(b.get("country_name", "")):
			return str(a.get("country_name", "")) < str(b.get("country_name", ""))
		if int(a.get("tier_rank", 0)) != int(b.get("tier_rank", 0)):
			return int(a.get("tier_rank", 0)) < int(b.get("tier_rank", 0))
		if str(a.get("league_name", "")) != str(b.get("league_name", "")):
			return str(a.get("league_name", "")) < str(b.get("league_name", ""))
		return str(a.get("name", "")) < str(b.get("name", "")))

	var db := catalog.sql_query()
	if db == null:
		# Let a later call retry instead of caching the failed state, and drop the
		# club list: with clubs but no squads the market would treat every club as
		# empty and start buying.
		_catalog = null
		_clubs = []
		return
	# canon.free_agents: ORDER BY p.id (a TEXT column) LIMIT 2000.
	var free_rows: Array = db.call("select",
		"SELECT %s FROM players p WHERE COALESCE(p.team_id, 0) = 0 "
			% CareerSearch.ROW_COLUMNS + "ORDER BY CAST(p.id AS TEXT) LIMIT ?",
		[FREE_AGENT_LIMIT])
	for row in free_rows:
		_free_agents.append(CareerSearch.normalized_row(row))
	_load_stats(catalog)


# Per-club numbers come from SQLite aggregates: the market never holds the
# whole players table, only the clubs it actually trades with.
static func _load_stats(catalog: TeamCatalog) -> void:
	var db := catalog.sql_query()
	if db == null:
		return
	var rows: Array = db.call("select",
		"SELECT COALESCE(p.team_id, 0) AS club, %s AS role, COUNT(*) AS count, "
			% CareerSearch.ROLE_EXPR
		+ "SUM(COALESCE(p.market_value, 0)) AS value, MAX(p.overall) AS best "
		+ "FROM players p WHERE COALESCE(p.team_id, 0) > 0 GROUP BY club, role")
	for row in rows:
		var entry: Dictionary = row
		var club := str(int(entry.get("club", 0)))
		var count := int(entry.get("count", 0))
		var best_raw = entry.get("best")
		var best := 0.0 if best_raw == null else float(best_raw)
		var stats: Dictionary = _market_stats.get(club,
			{"count": 0, "value": 0, "best": 0.0})
		stats["count"] = int(stats["count"]) + count
		stats["value"] = int(stats["value"]) + int(entry.get("value", 0))
		stats["best"] = maxf(float(stats["best"]), best)
		_market_stats[club] = stats
		var roles: Dictionary = _role_stats.get(club, {})
		roles[str(entry.get("role", ""))] = {"count": count, "best": best}
		_role_stats[club] = roles


static func _load_squads(career: Career, catalog: TeamCatalog, club_ids: Array) -> Dictionary:
	_ensure_cache(catalog)
	var lookup := func(player_ids: Array) -> Array:
		var players: Array = []
		for player_id in player_ids:
			var row := player_by_id(catalog, player_id)
			if not row.is_empty():
				players.append(row)
		return players
	var squads_out := {}
	if club_ids.is_empty():
		return squads_out
	var by_club := {}
	for row in _rows_for_clubs(catalog, club_ids):
		var entry: Dictionary = row
		var key := str(int(entry.get("team_id", 0)))
		if not by_club.has(key):
			by_club[key] = []
		(by_club[key] as Array).append(CareerSearch.normalized_row(entry))
	if by_club.is_empty():
		# Clubs exist but no player came back: the read failed, so the batch must
		# not run on "empty" squads.
		return {}
	for club_id in club_ids:
		var base: Array = by_club.get(str(club_id), [])
		squads_out[str(club_id)] = effective_players(career, club_id, base, lookup)
	return squads_out


static func _rows_for_clubs(catalog: TeamCatalog, club_ids: Array) -> Array:
	# One query for every club in the batch, already ordered like the prototype:
	# role, then the best player first, then the name.
	var db := catalog.sql_query()
	if db == null or club_ids.is_empty():
		return []
	var ids: Array = []
	var placeholders: Array[String] = []
	for club_id in club_ids:
		ids.append(int(str(club_id)))
		placeholders.append("?")
	return db.call("select",
		("SELECT %s FROM players p WHERE p.team_id IN (%s) "
			% [CareerSearch.ROW_COLUMNS, ",".join(placeholders)]
			+ "ORDER BY p.team_id, %s, p.overall DESC, p.name")
			% CareerSearch.role_order_expr(), ids)


static func _window_counts(career: Career, batch: Dictionary, buyers: bool) -> Dictionary:
	var counts := {}
	for transfer in career.world_transfers:
		if not _in_window(transfer, batch):
			continue
		var club_id := str(transfer.get("to_club_id" if buyers else "from_club_id", ""))
		if club_id.is_empty():
			continue
		counts[club_id] = int(counts.get(club_id, 0)) + 1
	return counts


static func _window_spend(career: Career, batch: Dictionary) -> Dictionary:
	var spent := {}
	for transfer in career.world_transfers:
		if not _in_window(transfer, batch):
			continue
		var buyer := str(transfer.get("to_club_id", ""))
		if buyer.is_empty():
			continue
		spent[buyer] = int(spent.get(buyer, 0)) + int(transfer.get("fee", 0))
	return spent


static func _in_window(transfer: Dictionary, batch: Dictionary) -> bool:
	var day := str(transfer.get("date", "")).substr(0, 10)
	return str(batch.get("window_start", "")) <= day \
		and day <= str(batch.get("window_end", ""))


static func _select_sellers(players: Array, count: int, rng: CareerRng) -> Array:
	if count <= 0:
		return []
	var counts := role_counts(players)
	var surplus: Array = []
	for player in players:
		var role := str(player.get("role", ""))
		if int(counts.get(role, 0)) > int(ROLE_TARGETS.get(role, 1)):
			surplus.append(player)
	var pool: Array = []
	if not surplus.is_empty():
		pool = surplus
	else:
		pool = players.duplicate()
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var overall_a := float(a.get("overall", 0.0))
			var overall_b := float(b.get("overall", 0.0))
			if not is_equal_approx(overall_a, overall_b):
				return overall_a < overall_b
			return str(a.get("id", "")) < str(b.get("id", "")))
	var chosen: Array = []
	for _index in range(count):
		if pool.is_empty():
			break
		var player = rng.choice(pool)
		pool.erase(player)
		chosen.append(player)
	return chosen


static func _pick_buyer_target(sale_pool: Array, players: Array, budget: int,
		rng: CareerRng, club_id: String):
	var affordable: Array = []
	for candidate in sale_pool:
		if int(candidate.get("value", 0)) <= budget \
				and str(candidate.get("from_club_id", "")) != club_id:
			affordable.append(candidate)
	if affordable.is_empty():
		return null
	var counts := role_counts(players)
	var wanted: Array = []
	for candidate in affordable:
		if _need(counts, str((candidate["player"] as Dictionary).get("role", ""))) > 0:
			wanted.append(candidate)
	var pool := wanted if not wanted.is_empty() else affordable
	var weights: Array = []
	for candidate in pool:
		var need := _need(counts, str((candidate["player"] as Dictionary).get("role", "")))
		weights.append(1.0 + float(need) * 3.0)
	return weighted_choice(rng, pool, weights)


static func _pick_free_agent(free_agents_pool: Array, players: Array, rng: CareerRng):
	if free_agents_pool.is_empty():
		return null
	var counts := role_counts(players)
	var wanted: Array = []
	for player in free_agents_pool:
		if _need(counts, str(player.get("role", ""))) > 0:
			wanted.append(player)
	var pool := wanted if not wanted.is_empty() else free_agents_pool
	return rng.choice(pool)


static func _deal_dates(batch: Dictionary, count: int, rng: CareerRng) -> Array:
	if count <= 0:
		return []
	var start := str(batch.get("period_start", ""))
	var end := str(batch.get("period_end", ""))
	var span := maxi(0, CareerSearch.date_diff_days(start, end))
	var offsets: Array = []
	if count <= span + 1:
		offsets = _sample_range(rng, span + 1, count)
	else:
		for _index in range(count):
			offsets.append(rng.randbelow(span + 1))
	offsets.sort()
	var dates: Array = []
	for offset in offsets:
		dates.append(CareerSearch.add_days(start, int(offset)))
	return dates


static func _record(career: Career, player: Dictionary, from_club_id, to_club_id: String,
		fee: int, day: String, rng: CareerRng) -> Dictionary:
	var kind := "free_agent" if from_club_id == null else "transfer"
	# Python renders None inside an f-string as "None"; the id must match.
	var source := "None" if from_club_id == null else str(from_club_id)
	var raw := "%d:%s:%s:%s:%s:%d:%s" % [
		career.seed, day, source, to_club_id, str(player.get("id", "")),
		career.world_transfers.size(), _py_float(rng.next_float()),
	]
	var transfer := {
		"id": sha1_id(raw),
		"player_id": str(player.get("id", "")),
		"player_name": str(player.get("name", "")),
		"overall": roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0,
		"from_club_id": null if from_club_id == null else str(from_club_id),
		"to_club_id": str(to_club_id),
		"fee": int(fee),
		"kind": kind,
		"date": day,
	}
	career.world_transfers.append(transfer)
	return transfer


static func _transfer_events(catalog: TeamCatalog, recorded: Array) -> Array:
	var names := {}
	for club in clubs(catalog):
		names[str(club.get("id", ""))] = str(club.get("name", ""))
	var events: Array = []
	for transfer in recorded:
		var player_name := str(transfer.get("player_name", ""))
		var to_name := str(names.get(str(transfer.get("to_club_id", "")), ""))
		var message := ""
		if transfer.get("from_club_id") == null:
			message = "%s joins %s as a free agent." % [player_name, to_name]
		else:
			var from_name := str(names.get(str(transfer.get("from_club_id", "")), ""))
			message = "%s moves from %s to %s." % [player_name, from_name, to_name]
		events.append({
			"type": "world.transfer",
			"player_id": str(transfer.get("player_id", "")),
			"player_name": player_name,
			"from_club_id": transfer.get("from_club_id"),
			"to_club_id": str(transfer.get("to_club_id", "")),
			"fee": int(transfer.get("fee", 0)),
			"kind": str(transfer.get("kind", "transfer")),
			"date": str(transfer.get("date", "")),
			"message": message,
		})
	return events


static func _need(counts: Dictionary, role: String) -> int:
	return maxi(0, int(ROLE_TARGETS.get(role, 1)) - int(counts.get(role, 0)))


static func _market_value(player: Dictionary) -> int:
	return maxi(int(player.get("market_value", 0)), MIN_MARKET_VALUE)


static func _money(value: float) -> int:
	return maxi(0, CareerRng.python_round(value / 10000.0) * 10000)


static func apply_delta(career: Career, club_id: String, player_id: String,
		attach: bool) -> void:
	var deltas: Dictionary = career.club_deltas
	var delta = deltas.get(club_id)
	if not (delta is Dictionary):
		delta = {"in": [], "out": []}
		deltas[club_id] = delta
	if not (delta.get("in") is Array):
		delta["in"] = []
	if not (delta.get("out") is Array):
		delta["out"] = []
	if attach:
		(delta["out"] as Array).erase(player_id)
		if not (delta["in"] as Array).has(player_id):
			(delta["in"] as Array).append(player_id)
	else:
		(delta["in"] as Array).erase(player_id)
		if not (delta["out"] as Array).has(player_id):
			(delta["out"] as Array).append(player_id)


static func _erase_player(players: Array, player_id: String) -> void:
	for index in range(players.size()):
		if str((players[index] as Dictionary).get("id", "")) == player_id:
			players.remove_at(index)
			return


static func _erase_candidate(sale_pool: Array, target: Dictionary) -> void:
	var player_id := str((target["player"] as Dictionary).get("id", ""))
	for index in range(sale_pool.size()):
		var candidate: Dictionary = sale_pool[index]
		if str(candidate.get("from_club_id", "")) == str(target.get("from_club_id", "")) \
				and str((candidate["player"] as Dictionary).get("id", "")) == player_id:
			sale_pool.remove_at(index)
			return


static func weighted_choice(rng: CareerRng, items: Array, weights: Array):
	# random.choices(population, weights, k=1): bisect over cumulative weights.
	if items.is_empty():
		return null
	if items.size() == 1:
		rng.next_float()
		return items[0]
	var cumulative: Array = []
	var total := 0.0
	for weight in weights:
		total += float(weight)
		cumulative.append(total)
	if total <= 0.0:
		return items[0]
	var point := rng.next_float() * total
	var low := 0
	var high := items.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if point < float(cumulative[middle]):
			high = middle
		else:
			low = middle + 1
	return items[low]


static func _sample(rng: CareerRng, population: Array, count: int) -> Array:
	# random.sample: the pool branch for short runs, the set branch for long ones.
	var size := population.size()
	if count > size:
		count = size
	var result: Array = []
	if count <= 0:
		return result
	var setsize := 21
	if count > 5:
		setsize += int(pow(4.0, ceil(log(float(count) * 3.0) / log(4.0))))
	if size <= setsize:
		var pool := population.duplicate()
		for index in range(count):
			var pick := rng.randbelow(size - index)
			result.append(pool[pick])
			pool[pick] = pool[size - index - 1]
		return result
	var selected := {}
	for _index in range(count):
		var pick := rng.randbelow(size)
		while selected.has(pick):
			pick = rng.randbelow(size)
		selected[pick] = true
		result.append(population[pick])
	return result


static func _sample_range(rng: CareerRng, size: int, count: int) -> Array:
	var population: Array = []
	for index in range(size):
		population.append(index)
	return _sample(rng, population, count)


static func _py_float(value: float) -> String:
	# String.num_scientific gives the shortest round-trip text, like Python's repr.
	var text := String.num_scientific(value)
	if not text.contains(".") and not text.contains("e"):
		text += ".0"
	return text


static func sha1_id(raw: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA1)
	hashing.update(raw.to_utf8_buffer())
	var digest := hashing.finish()
	var hex := ""
	for byte in digest:
		hex += "%02x" % int(byte)
	return hex.substr(0, 16)
