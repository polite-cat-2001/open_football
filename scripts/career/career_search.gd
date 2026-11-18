class_name CareerSearch
extends RefCounted
# Transfer search and the shared player-finance helpers, ported from
# server/canon.py `search_players` (plus the app's transfer search endpoint)
# and server/career/squad.py (release clause, wage, contract expiry).
#
# The 121k-row players table is walked once per catalog and kept as compact
# rows; every search filters and sorts them exactly like the prototype's SQL
# (same filters, same sort keys, same null/tie-break order) and only the page
# is turned into full items.

const PAGE_SIZE := 40
const MIN_MARKET_VALUE := 50000
const MIN_WEEKLY_WAGE := 1000
const MAX_WEEKLY_WAGE := 2000000
const CONTRACT_MONTHS_MAX := 60
const GROUP_ROLES := {
	"GK": ["GK"],
	"DEF": ["CB", "LB", "RB"],
	"MID": ["DM", "CM", "LM", "RM", "AM"],
	"FWD": ["CF"],
}
const ROLE_ORDER := {
	"GK": 0, "CB": 1, "LB": 2, "RB": 3, "DM": 4, "CM": 5,
	"LM": 6, "RM": 7, "AM": 8, "CF": 9,
}
const POSITION_GROUP := {
	"Goalkeeper": "GK",
	"Sweeper": "DEF", "Defender": "DEF", "Centre-Back": "DEF",
	"Left-Back": "DEF", "Right-Back": "DEF",
	"Defensive Midfield": "MID", "Central Midfield": "MID",
	"Attacking Midfield": "MID", "Left Midfield": "MID",
	"Right Midfield": "MID", "Midfielder": "MID",
	"Left Winger": "MID", "Right Winger": "MID",
	"Striker": "FWD", "Centre-Forward": "FWD", "Second Striker": "FWD",
}
const SORTS := ["name", "age", "overall", "position", "value", "wage", "height"]
const STATUSES := ["transfer", "loan", "blocked"]
const FILTER_KEYS := [
	"name", "group", "position", "age_min", "age_max", "citizenship",
	"country", "league", "club", "foot", "height_min", "height_max",
	"status", "sort", "direction",
]

static var last_error := ""
const ROLE_EXPR := "CASE WHEN p.career_role IS NOT NULL AND p.career_role <> '' " \
	+ "THEN p.career_role ELSE p.role END"
const AGE_EXPR := "CAST((julianday(?) - julianday(p.birth_date)) / 365.2425 AS INTEGER)"
const HEIGHT_EXPR := "CASE WHEN p.height_cm > 0 THEN p.height_cm " \
	+ "ELSE CAST(ROUND(COALESCE(p.height, 1.8) * 100) AS INTEGER) END"
const ROW_COLUMNS := "p.id AS id, p.team_id AS team_id, p.name AS name, " \
	+ "p.birth_date AS birth_date, p.role AS role, p.career_role AS career_role, " \
	+ "p.position AS position, p.position_other AS position_other, p.height AS height, " \
	+ "p.height_cm AS height_cm, p.foot AS foot, p.citizenship AS citizenship, " \
	+ "p.market_value AS market_value, p.overall AS overall"


static func filters_default() -> Dictionary:
	return {
		"name": "",
		"group": "",
		"position": "",
		"age_min": null,
		"age_max": null,
		"citizenship": "",
		"country": "",
		"league": "",
		"club": "",
		"foot": "",
		"height_min": null,
		"height_max": null,
		"status": "",
		"sort": "name",
		"direction": "asc",
	}


static func filter_reference(catalog: TeamCatalog, league_id := "") -> Dictionary:
	# Picker data for the filter tiles. Clubs are per league, like the
	# prototype (the club picker only opens once a league is chosen).
	last_error = ""
	if catalog == null:
		last_error = "transfer search is unavailable"
		return {"countries": [], "leagues": [], "clubs": []}
	var countries: Array = []
	for country in catalog.countries():
		countries.append({
			"id": str(country.get("id", "")),
			"name": str(country.get("name", "")),
			"flag": str(country.get("name", "")),
			"tm_id": str(country.get("tm_id", "")),
		})
	var leagues: Array = []
	for league in catalog.career_leagues():
		leagues.append({
			"id": str(league.get("id", "")),
			"name": str(league.get("name", "")),
			"country_id": str(league.get("country_id", "")),
			"tier": int(league.get("tier", 0)),
			"tier_rank": int(league.get("tier_rank", 0)),
			"logo": str(league.get("logo_url", "")),
		})
	var clubs: Array = []
	if not league_id.is_empty():
		for team in catalog.all_teams_for_league(league_id):
			clubs.append({
				"id": str(team.get("id", "")),
				"name": str(team.get("name", "")),
				"logo": club_logo(team),
			})
	return {"countries": countries, "leagues": leagues, "clubs": clubs}


static func search(catalog: TeamCatalog, career: Career, filters: Dictionary,
		limit := PAGE_SIZE, offset := 0) -> Dictionary:
	last_error = ""
	var empty := {"items": [], "total": 0, "has_more": false, "limit": limit,
		"offset": offset}
	if catalog == null or career == null:
		last_error = "transfer search is unavailable"
		return empty
	var db := catalog.sql_query()
	if db == null:
		last_error = catalog.error if not catalog.error.is_empty() \
			else "transfer search is unavailable"
		return empty
	var page_size := maxi(1, int(limit))
	var start := maxi(0, int(offset))
	var query := _build_query(career, filters)
	if query.is_empty():
		return empty
	if not _prepare_names(catalog, db):
		return empty
	var from := "FROM players p JOIN of_names n ON n.id = p.id"
	if bool(query["join"]):
		from += " LEFT JOIN teams t ON t.id = p.team_id"
	var where := str(query["where"])
	var where_params: Array = query["params"]
	var counted: Array = db.call("select",
		"SELECT COUNT(*) AS total %s WHERE %s" % [from, where], where_params)
	var total := 0
	if not counted.is_empty():
		total = int((counted[0] as Dictionary).get("total", 0))
	# Two steps: the ordered ids first (with the name sort this walks the temp
	# index and touches no player row), then only the page's rows. Selecting the
	# full rows inside the ordered query made the OFFSET pay a row lookup per
	# skipped entry.
	var order_params: Array = query["order_params"]
	var id_params: Array = where_params.duplicate()
	id_params.append_array(order_params)
	id_params.append(page_size)
	id_params.append(start)
	var id_rows: Array = db.call("select",
		"SELECT p.id AS id %s WHERE %s ORDER BY %s LIMIT ? OFFSET ?"
			% [from, where, str(query["order"])], id_params)
	var sql_error := str(db.call("last_error_message"))
	if not sql_error.is_empty():
		last_error = sql_error
		return empty
	var ids: Array = []
	for row in id_rows:
		ids.append(_int((row as Dictionary).get("id")))
	var items: Array = []
	if not ids.is_empty():
		var rows: Array = db.call("select", "SELECT %s FROM players p WHERE p.id IN (%s)"
			% [ROW_COLUMNS, _placeholders(ids.size())], ids)
		var page_error := str(db.call("last_error_message"))
		if not page_error.is_empty():
			last_error = page_error
			return empty
		var by_id := {}
		for row in rows:
			by_id[_int((row as Dictionary).get("id"))] = row
		var clubs: Dictionary = {}
		for player_id in ids:
			var row: Dictionary = by_id.get(player_id, {})
			if not row.is_empty():
				items.append(_item(catalog, career, normalized_row(row), clubs))
	return {
		"items": items,
		"total": total,
		"has_more": start + items.size() < total,
		"limit": page_size,
		"offset": start,
	}


# WHERE/ORDER for one filter set, built once for the page and its count. An
# empty dictionary means the filters can never match (an unknown group, or a
# status nobody in the career has).
static func _build_query(career: Career, filters: Dictionary) -> Dictionary:
	var clauses: Array[String] = []
	var params: Array = []
	var name := str(filters.get("name", "")).strip_edges().to_lower()
	if not name.is_empty():
		clauses.append("instr(n.low, ?) > 0")
		params.append(name)
	var group := str(filters.get("group", "")).strip_edges().to_upper()
	if not group.is_empty():
		var roles: Array = GROUP_ROLES.get(group, [])
		if roles.is_empty():
			return {}
		clauses.append("(%s) IN (%s)" % [ROLE_EXPR, _placeholders(roles.size())])
		params.append_array(roles)
	var position := str(filters.get("position", "")).strip_edges()
	if not position.is_empty():
		clauses.append("(p.position = ? OR instr(p.position_other, ?) > 0)")
		params.append(position)
		params.append("\"%s\"" % position)
	var citizenship := str(filters.get("citizenship", "")).strip_edges()
	if not citizenship.is_empty():
		clauses.append("instr(p.citizenship, ?) > 0")
		params.append("\"%s\"" % citizenship)
	var foot := str(filters.get("foot", "")).strip_edges()
	if not foot.is_empty():
		clauses.append("p.foot = ?")
		params.append(foot)
	var age_min := _as_int(filters.get("age_min", 0))
	if age_min > 0:
		clauses.append("COALESCE(%s, -1) >= ?" % AGE_EXPR)
		params.append(career.date)
		params.append(age_min)
	var age_max := _as_int(filters.get("age_max", 0))
	if age_max > 0:
		clauses.append("COALESCE(%s, -1) <= ?" % AGE_EXPR)
		params.append(career.date)
		params.append(age_max)
	var height_min := _as_int(filters.get("height_min", 0))
	if height_min > 0:
		clauses.append("%s >= ?" % HEIGHT_EXPR)
		params.append(height_min)
	var height_max := _as_int(filters.get("height_max", 0))
	if height_max > 0:
		clauses.append("%s <= ?" % HEIGHT_EXPR)
		params.append(height_max)
	var club := _as_int(_value_of(filters, "club", "club_id"))
	if club > 0:
		clauses.append("p.team_id = ?")
		params.append(club)
	var join_teams := false
	var country := _alias(filters, "country", "country_id")
	if not country.is_empty():
		join_teams = true
		clauses.append("t.country_id = ?")
		params.append(country)
	var league := _alias(filters, "league", "league_id")
	if not league.is_empty():
		join_teams = true
		clauses.append("t.league_id = ?")
		params.append(league)
	var status := str(filters.get("status", "")).strip_edges()
	if status == "free":
		clauses.append("COALESCE(p.team_id, 0) = 0")
	elif STATUSES.has(status):
		var ids: Array = []
		for player_id in career.player_transfers:
			if str(career.player_transfers[player_id]) == status:
				ids.append(int(str(player_id)))
		if ids.is_empty():
			return {}
		clauses.append("p.id IN (%s)" % _placeholders(ids.size()))
		params.append_array(ids)
	var sort_key := str(filters.get("sort", "name")).strip_edges()
	if not SORTS.has(sort_key):
		sort_key = "name"
	var direction := "DESC" if _descending(filters) else "ASC"
	if sort_key == "name":
		# `n.low` is indexed: the default page is an index walk, no sort.
		return {
			"where": " AND ".join(clauses) if not clauses.is_empty() else "1",
			"params": params,
			"order": "n.low %s, CAST(n.id AS TEXT) ASC" % direction,
			"order_params": [],
			"join": join_teams,
		}
	var order_expr := "p.overall"
	var order_params: Array = []
	match sort_key:
		"age":
			order_expr = "CASE WHEN p.birth_date IS NULL OR p.birth_date = '' " \
				+ "THEN NULL ELSE %s END" % AGE_EXPR
			order_params.append(career.date)
		"position":
			order_expr = role_order_expr()
		"height":
			order_expr = HEIGHT_EXPR
		"value":
			order_expr = "p.market_value"
		"wage":
			order_expr = ("CASE WHEN p.market_value IS NULL OR p.birth_date IS NULL " \
				+ "OR p.birth_date = '' THEN NULL ELSE p.market_value * (CASE " \
				+ "WHEN %s <= 23 THEN 1.1 WHEN %s <= 28 THEN 1.0 " \
				+ "WHEN %s <= 31 THEN 0.9 ELSE 0.8 END) END") % [AGE_EXPR, AGE_EXPR, AGE_EXPR]
			order_params.append_array([career.date, career.date, career.date])
	# Nulls sort last in both directions, then the lowercased name and the id
	# break ties (the engine compares ids as text, like the old comparator).
	return {
		"where": " AND ".join(clauses) if not clauses.is_empty() else "1",
		"params": params,
		"order": "(%s IS NULL) ASC, %s %s, n.low ASC, CAST(p.id AS TEXT) ASC"
			% [order_expr, order_expr, direction],
		"order_params": order_params + order_params,
		"join": join_teams,
	}


static func _placeholders(count: int) -> String:
	var parts: Array[String] = []
	for index in count:
		parts.append("?")
	return ",".join(parts)


static func role_order_expr() -> String:
	# Shared by the search's position sort and the market's squad order.
	var cases: Array[String] = []
	for role in ROLE_ORDER:
		cases.append("WHEN '%s' THEN %d" % [str(role), int(ROLE_ORDER[role])])
	return "CASE (%s) %s ELSE 99 END" % [ROLE_EXPR, " ".join(cases)]


static func _prepare_names(catalog: TeamCatalog, db: RefCounted) -> bool:
	if catalog.prepare_sql_names():
		return true
	if last_error.is_empty():
		last_error = str(db.call("last_error_message"))
		if last_error.is_empty():
			last_error = "the player name index is unavailable"
	return false


static func _descending(filters: Dictionary) -> bool:
	return str(filters.get("direction", "asc")).strip_edges().to_lower() == "desc"


# SQL row -> the compact search row the item builder reads.
static func normalized_row(row: Dictionary) -> Dictionary:
	var career_role := _text(row.get("career_role"))
	var height_cm := int(row.get("height_cm", 0) if row.get("height_cm") != null else 0)
	var height := height_cm
	if height <= 0:
		height = int(round(_float(row.get("height"), 1.8) * 100.0))
	return {
		"id": str(_int(row.get("id"))),
		"team_id": _int(row.get("team_id")),
		"name": _text(row.get("name")),
		"birth_date": _text(row.get("birth_date")),
		"role": career_role if not career_role.is_empty() else _text(row.get("role")),
		"position": _text(row.get("position")),
		"position_other": _text(row.get("position_other")),
		"foot": _text(row.get("foot")),
		"height": height,
		"citizenship": _text(row.get("citizenship")),
		"market_value": _int(row.get("market_value")),
		"overall": _float(row.get("overall"), 0.0),
	}


static func _text(value) -> String:
	return "" if value == null else str(value)


static func _int(value, fallback := 0) -> int:
	return fallback if value == null else int(value)


static func _float(value, fallback := 0.0) -> float:
	return fallback if value == null else float(value)


static func profile(catalog: TeamCatalog, career: Career, player_id) -> Dictionary:
	last_error = ""
	var key := str(player_id)
	if catalog == null or career == null or not key.is_valid_int():
		last_error = "player not found"
		return {}
	var player := catalog.career_player(int(key), true)
	if player.is_empty():
		last_error = "player not found"
		return {}
	var item := _item(catalog, career, _row_from_player(player), {})
	var scouted := bool(item.get("scouted", false))
	item["first_name"] = str(player.get("firstname", ""))
	item["last_name"] = str(player.get("lastname", ""))
	item["birth_date"] = str(player.get("birth_date", ""))
	item["role"] = str(player.get("role", ""))
	item["weight"] = int(player.get("weight", 0))
	item["shirt_number"] = int(player.get("shirt_number", -1))
	item["height"] = int(player.get("height", 0))
	if scouted:
		item["stats"] = player.get("stats", {}) if player.get("stats") is Dictionary else {}
		item["overall"] = float(player.get("overall", 0.0))
		item["pot"] = float(player.get("pot", 0.0))
		item["market_value"] = int(player.get("market_value", 0))
		item["weekly_wage"] = weekly_wage(career, player, key)
		item["foot"] = str(player.get("foot", ""))
		item["weak_foot"] = int(player.get("weak_foot", 0))
		item["skill_moves"] = int(player.get("skill_moves", 0))
	else:
		item["stats"] = {}
		item["weak_foot"] = 0
		item["skill_moves"] = 0
	return item


static func contract_expiry(catalog: TeamCatalog, career: Career, player_id) -> String:
	# The player's contract date needs the club membership, so the player is
	# read from the database (the prototype's app endpoint has it in hand).
	var player := _load(catalog, player_id)
	if player.is_empty():
		return ""
	return expiry_for(career, player, str(player.get("id", "")))


static func expiry_for(career: Career, player: Dictionary, player_id := "") -> String:
	var key := player_id if not player_id.is_empty() else str(player.get("id", ""))
	var months := contract_months(career, player, key)
	if months <= 0:
		return ""
	var anchor := date_parts(_anchor_date(career))
	if anchor.is_empty():
		return ""
	var total: int = anchor[1] - 1 + months
	var year: int = anchor[0] + total / 12
	var month: int = total % 12 + 1
	var day: int = mini(anchor[2], _days_in_month(year, month))
	return "%04d-%02d-%02d" % [year, month, day]


static func contract_months(career: Career, player: Dictionary, player_id := "") -> int:
	var key := player_id if not player_id.is_empty() else str(player.get("id", ""))
	if int(player.get("team_id", 0)) <= 0 and str(player.get("club_id", "")).is_empty():
		return 0
	var contract: Dictionary = career.player_contracts.get(key) \
		if career.player_contracts.get(key) is Dictionary else {}
	if int(contract.get("years", 0)) > 0:
		return maxi(1, int(contract.get("years", 0)) * 12)
	var rng := CareerRng.seeded("%d:contract:%s:months" % [career.seed, key])
	return rng.randint(1, CONTRACT_MONTHS_MAX)


static func release_clause(career: Career, player: Dictionary, player_id := "") -> int:
	var key := player_id if not player_id.is_empty() else str(player.get("id", ""))
	var contract: Dictionary = career.player_contracts.get(key) \
		if career.player_contracts.get(key) is Dictionary else {}
	if int(contract.get("release_clause", 0)) > 0:
		return int(contract.get("release_clause", 0))
	return _rolled_release_clause(career, player, key)


static func weekly_wage(career: Career, player: Dictionary, player_id := "") -> int:
	var key := player_id if not player_id.is_empty() else str(player.get("id", ""))
	var value := maxi(int(player.get("market_value", 0)), MIN_MARKET_VALUE)
	return _wage_from_value(career, key, value, player_age(player))


static func market_value(career: Career, player: Dictionary, player_id := "") -> int:
	var key := player_id if not player_id.is_empty() else str(player.get("id", ""))
	var stored := int(career.player_values.get(key, 0))
	var value := stored if stored > 0 else int(player.get("market_value", 0))
	return maxi(value, MIN_MARKET_VALUE)


static func round_money(value: float) -> int:
	var step := 100
	if value >= 1000000.0:
		step = 100000
	elif value >= 100000.0:
		step = 10000
	elif value >= 10000.0:
		step = 1000
	return maxi(step, python_round(value / float(step)) * step)


static func python_round(value: float) -> int:
	# Python's round() is half-to-even; int(round(x)) shows up in the wage and
	# contract formulas, so the port must not use GDScript's half-away-from-zero.
	return CareerRng.python_round(value)


static func player_age(player: Dictionary) -> int:
	# Unknown birth dates arrive as 0; the prototype stores null and reads
	# `age or 25`, so an unknown age must fall back to the same 25 for wages.
	var age := int(player.get("age", 0))
	return age if age > 0 else 25


static func age_from_birth_date(birth_date: String, reference: String) -> int:
	# Calendar age, like canon.age_from_birth_date (the search *filter* uses the
	# julianday formula below, which is not the same number on some birthdays).
	if birth_date.is_empty() or reference.is_empty():
		return 0
	var born := date_parts(birth_date)
	var ref := date_parts(reference)
	if born.is_empty() or ref.is_empty():
		return 0
	var age: int = ref[0] - born[0]
	if ref[1] < born[1] or (ref[1] == born[1] and ref[2] < born[2]):
		age -= 1
	return age


static func group_of(position: String) -> String:
	# Accepts a role ("CB") or a display position ("Centre-Back").
	var value := position.strip_edges()
	if GROUP_ROLES.has(value):
		return value
	if POSITION_GROUP.has(value):
		return str(POSITION_GROUP[value])
	for group in GROUP_ROLES:
		if (GROUP_ROLES[group] as Array).has(value):
			return group
	for pair in POSITION_GROUP:
		if str(pair).to_lower() == value.to_lower():
			return str(POSITION_GROUP[pair])
	return ""


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


static func is_scouted(career: Career, player_id) -> bool:
	var key := str(player_id)
	if career.player_ids.has(key):
		return true
	for field in ["scout_reports", "scout_found"]:
		var store = career.data.get(field)
		if store is Dictionary and (store as Dictionary).has(key):
			return true
	return false


static func club_logo(club: Dictionary) -> String:
	var career_logo := str(club.get("career_logo", ""))
	return career_logo if not career_logo.is_empty() else str(club.get("logo", ""))


static func club_ref(catalog: TeamCatalog, club_id, cache: Dictionary = {}) -> Dictionary:
	var key := str(club_id)
	if key.is_empty() or not key.is_valid_int():
		return {}
	if cache.has(key):
		return cache[key]
	var club := catalog.career_club(int(key))
	cache[key] = club
	return club


static func add_days(iso_date: String, days: int) -> String:
	var unix := int(Time.get_unix_time_from_datetime_string(iso_date.substr(0, 10) + "T00:00:00"))
	return Time.get_datetime_string_from_unix_time(unix + days * 86400, false).substr(0, 10)


static func date_diff_days(iso_date: String, other: String) -> int:
	var first := int(Time.get_unix_time_from_datetime_string(iso_date.substr(0, 10) + "T00:00:00"))
	var second := int(Time.get_unix_time_from_datetime_string(other.substr(0, 10) + "T00:00:00"))
	return (second - first) / 86400


static func _wage_from_value(career: Career, player_id: String, value: int,
		age: int) -> int:
	var age_factor := 1.1
	if age > 31:
		age_factor = 0.8
	elif age > 28:
		age_factor = 0.9
	elif age > 23:
		age_factor = 1.0
	var rng := CareerRng.seeded("%d:contract:%s:wage" % [career.seed, player_id])
	var jitter := rng.uniform(0.9, 1.1)
	var weekly := float(value) * 0.12 * age_factor * jitter / 52.0
	return maxi(MIN_WEEKLY_WAGE, python_round(weekly / 100.0) * 100)


static func _rolled_release_clause(career: Career, player: Dictionary,
		player_id: String) -> int:
	var value := maxi(int(player.get("market_value", 0)), MIN_MARKET_VALUE)
	var rng := CareerRng.seeded("%d:contract:%s:clause" % [career.seed, player_id])
	var multiplier := rng.uniform(1.2, 2.0)
	var rounded := round_money(float(value) * multiplier)
	return maxi(int(float(value) * 1.2), mini(int(float(value) * 2.0), rounded))


static func _anchor_date(career: Career) -> String:
	var created := career.created_at.substr(0, 10)
	if date_parts(created).is_empty():
		return career.date.substr(0, 10)
	return created


static func _load(catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	if catalog == null or not key.is_valid_int():
		return {}
	return catalog.career_player(int(key), true)


static func date_parts(iso_date: String) -> Array:
	var value := str(iso_date).substr(0, 10)
	var parts := value.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() \
			or not parts[2].is_valid_int():
		return []
	return [int(parts[0]), int(parts[1]), int(parts[2])]


static func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
			return 29 if leap else 28
	return 30


static func _item(catalog: TeamCatalog, career: Career, row: Dictionary,
		clubs: Dictionary) -> Dictionary:
	var player_id := str(row.get("id", ""))
	var db_club_id := int(row.get("team_id", 0))
	var club_id := current_club_id(career, player_id,
		str(db_club_id) if db_club_id > 0 else "")
	var club := club_ref(catalog, club_id, clubs)
	var status := str(career.player_transfers.get(player_id, ""))
	if status.is_empty():
		status = "free" if club_id.is_empty() else "contracted"
	var scouted := is_scouted(career, player_id)
	var item := {
		"player_id": player_id,
		"name": str(row.get("name", "")),
		"age": age_from_birth_date(str(row.get("birth_date", "")), career.date),
		"position": str(row.get("position", "")),
		"position_group": group_of(str(row.get("role", ""))),
		"club_id": club_id,
		"club_name": str(club.get("name", "")),
		"club_logo": club_logo(club),
		"league_id": str(club.get("league_id", "")),
		"league_name": str(club.get("league_name", "")),
		"country_id": str(club.get("country_id", "")),
		"country_name": str(club.get("country_name", "")),
		"citizenship": _json_array(str(row.get("citizenship", ""))),
		"status": status,
		"release_clause": release_clause(career, row, player_id),
		"contract_expires": expiry_for(career, {
			"id": player_id, "team_id": db_club_id,
		}, player_id),
		"scouted": scouted,
		"overall": 0.0,
		"pot": 0.0,
		"market_value": 0,
		"weekly_wage": 0,
		"foot": "",
		"height": int(row.get("height", 0)),
		"stats": {},
		"photo": int(player_id) if player_id.is_valid_int() else 0,
		"shortlisted": career.shortlist.has(player_id),
		"listed_for_transfer": status in ["transfer", "loan"],
	}
	if scouted:
		var player := catalog.career_player(int(player_id), true)
		item["overall"] = roundf(float(player.get("overall", 0.0)) * 10.0) / 10.0
		item["pot"] = roundf(float(player.get("pot", 0.0)) * 10.0) / 10.0
		item["market_value"] = int(player.get("market_value", 0))
		item["weekly_wage"] = weekly_wage(career, player, player_id)
		item["foot"] = str(player.get("foot", ""))
		item["stats"] = player.get("stats", {}) if player.get("stats") is Dictionary else {}
	return item


static func _row_from_player(player: Dictionary) -> Dictionary:
	var career_role := str(player.get("role", ""))
	var height := int(player.get("height", 0))
	if height <= 0:
		height = int(round(float(player.get("height_cm", 0))))
	return {
		"id": str(player.get("id", "")),
		"team_id": int(player.get("team_id", 0)),
		"name": str(player.get("name", "")),
		"birth_date": str(player.get("birth_date", "")),
		"role": career_role,
		"position": str(player.get("position", "")),
		"position_other": JSON.stringify(player.get("position_other", [])),
		"foot": str(player.get("foot", "")),
		"height": height,
		"citizenship": JSON.stringify(player.get("citizenship", [])),
		"market_value": int(player.get("market_value", 0)),
		"overall": float(player.get("overall", 0.0)),
	}


static func _json_array(value: String) -> Array:
	if value.is_empty():
		return []
	var parsed = JSON.parse_string(value)
	return parsed if parsed is Array else []


static func _value_of(filters: Dictionary, primary: String, alias: String):
	if filters.has(primary) and filters[primary] != null and str(filters[primary]) != "":
		return filters[primary]
	if filters.has(alias):
		return filters[alias]
	return filters.get(primary)


static func _alias(filters: Dictionary, primary: String, alias: String) -> String:
	var value = _value_of(filters, primary, alias)
	return "" if value == null else str(value).strip_edges()


static func _as_int(value) -> int:
	if value == null:
		return 0
	if value is int or value is float or value is bool:
		return int(value)
	if value is String and str(value).is_valid_int():
		return int(value)
	return 0
