class_name TeamCatalog
extends RefCounted
# Godot-side catalog of leagues and teams, read straight from the game's SQLite
# database. The C++ catalog is no longer used to populate the shell: the match
# package gets the chosen teams from here.
#
# Loading is lazy, like the original TeamSelectPage queries: opening the catalog
# only validates the database, countries/leagues/teams are fetched per screen
# demand and cached, and squads/ratings only for the selected teams.

const DEFAULT_DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const DATABASE_RELATIVE_PATH := "databases/default/database.sqlite"
const MANIFEST_RELATIVE_PATH := "databases/default/manifest.json"
const NATIONAL_LEAGUE_NAME := "National Teams"
const MIN_MATCH_PLAYERS := 11
const SQUAD_PLAYER_COLUMNS := [
	"id", "team_id", "nationalteam_id", "firstname", "lastname", "role", "age",
	"base_stat", "profile_xml", "formationorder", "nationalteamformationorder",
	"skincolor", "hairstyle", "haircolor", "height", "strong_foot", "tm_id",
]
const COUNTRY_COLUMNS := ["id", "name", "tm_id"]
const LEAGUE_COLUMNS := ["id", "name", "country_id", "tier", "logo_url"]
const TEAM_COLUMNS := [
	"id", "league_id", "name", "shortname", "color1", "color2",
	"logo_url", "kit_url",
]

var error := ""

var _reader: SqliteReader
var _loaded := false
var _countries: Array = []
var _countries_loaded := false
var _country_rows := {}
var _leagues_by_country := {}
var _league_rows := {}
var _teams_by_league := {}
var _team_rows := {}
var _national_league_id := -1
var _national_league_loaded := false
var _ratings := {}


func load_data_root(root: String = "") -> bool:
	close()
	_reset()
	var data_root := resolve_data_root(root)
	var database_path := data_root.path_join(DATABASE_RELATIVE_PATH)
	if not FileAccess.file_exists(database_path):
		error = ("Team database not found at %s. " \
			+ "Set GPF_DATA_ROOT to the GameplayFootball data folder.") % database_path
		return false

	var reader := SqliteReader.new()
	if not reader.open(database_path):
		error = "Team database could not be read: %s (%s)." % [database_path, reader.error]
		return false
	for table_name in ["countries", "leagues", "teams", "players"]:
		if not reader.has_table(table_name):
			error = "Team database could not be read: %s (missing table %s)." % [
				database_path, table_name,
			]
			reader.close()
			return false
	var leagues := reader.select_all("leagues", PackedStringArray(["id"]))
	if not reader.error.is_empty():
		error = "Team database could not be read: %s (%s)." % [database_path, reader.error]
		reader.close()
		return false
	if leagues.is_empty():
		error = "Team database has no leagues or teams: %s." % database_path
		reader.close()
		return false

	_reader = reader
	_loaded = true
	return true


func is_loaded() -> bool:
	return _loaded


func close() -> void:
	if _reader != null:
		_reader.close()
		_reader = null
	_loaded = false


func resolve_data_root(root: String = "") -> String:
	if not root.is_empty():
		return root
	var environment := OS.get_environment("GPF_DATA_ROOT")
	if not environment.is_empty():
		return environment
	return DEFAULT_DATA_ROOT


func database_path(root: String = "") -> String:
	return resolve_data_root(root).path_join(DATABASE_RELATIVE_PATH)


func countries() -> Array:
	if _countries_loaded:
		return _countries
	var reader := _require_reader("countries")
	if reader == null:
		return []
	var country_rows := reader.select_all("countries", PackedStringArray(COUNTRY_COLUMNS))
	if not _query_ok("countries"):
		return []
	var league_rows := reader.select_all("leagues", PackedStringArray(["country_id"]))
	if not _query_ok("leagues"):
		return []
	var with_leagues := {}
	for row in league_rows:
		var country_id := _int(row.get("country_id"))
		if country_id > 0:
			with_leagues[country_id] = true
	for row in country_rows:
		var id := _int(row.get("id"))
		var entry := {"id": id, "name": _text(row.get("name")), "tm_id": _text(row.get("tm_id"))}
		_country_rows[id] = entry
		if with_leagues.has(id):
			_countries.append(entry)
	_countries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", "")))
	_countries_loaded = true
	return _countries


func leagues_for_country(country_id: int) -> Array:
	if _leagues_by_country.has(country_id):
		return _leagues_by_country[country_id]
	var reader := _require_reader("leagues")
	if reader == null:
		return []
	var rows := reader.select_indexed("leagues", "country_id", country_id,
		PackedStringArray(LEAGUE_COLUMNS))
	if not _query_ok("leagues"):
		return []
	var result: Array = []
	for row in rows:
		var league := _league_from_row(row)
		_league_rows[int(league["id"])] = league
		result.append(league)
	result.sort_custom(_compare_leagues)
	_leagues_by_country[country_id] = result
	return result


func teams_for_league(league_id: int) -> Array:
	if _teams_by_league.has(league_id):
		return _teams_by_league[league_id]
	var reader := _require_reader("teams")
	if reader == null:
		return []
	var rows := reader.select_indexed("teams", "league_id", league_id,
		PackedStringArray(TEAM_COLUMNS))
	if not _query_ok("teams"):
		return []
	# Listing does not filter by player count: probing the players index per team
	# took ~0.8 s for the 217 national teams and froze the screen. The check is
	# done once, for the two selected teams, when the panel is readied.
	var result: Array = []
	for row in rows:
		var team := _team_from_row(row)
		_team_rows[int(team["id"])] = team
		result.append(team)
	result.sort_custom(_compare_teams)
	_teams_by_league[league_id] = result
	return result


func country_by_id(country_id: int) -> Dictionary:
	if _country_rows.has(country_id):
		return _country_rows[country_id]
	var reader := _require_reader("countries")
	if reader == null:
		return {}
	var rows := reader.select_indexed("countries", "id", country_id,
		PackedStringArray(COUNTRY_COLUMNS))
	if not _query_ok("countries") or rows.is_empty():
		return {}
	var country := {
		"id": _int(rows[0].get("id")),
		"name": _text(rows[0].get("name")),
		"tm_id": _text(rows[0].get("tm_id")),
	}
	_country_rows[int(country["id"])] = country
	return country


func national_league_id() -> int:
	if _national_league_loaded:
		return _national_league_id
	var reader := _require_reader("leagues")
	if reader == null:
		return -1
	var rows := reader.select_any("leagues", [{"column": "name", "value": NATIONAL_LEAGUE_NAME}],
		PackedStringArray(["id"]))
	if not _query_ok("leagues") or rows.is_empty():
		_national_league_loaded = true
		_national_league_id = -1
		return _national_league_id
	_national_league_loaded = true
	_national_league_id = _int(rows[0].get("id"))
	return _national_league_id


func team_by_id(team_id: int) -> Dictionary:
	if _team_rows.has(team_id):
		return _team_rows[team_id]
	var reader := _require_reader("teams")
	if reader == null:
		return {}
	var rows := reader.select_indexed("teams", "id", team_id,
		PackedStringArray(TEAM_COLUMNS))
	if not _query_ok("teams") or rows.is_empty():
		return {}
	var team := _team_from_row(rows[0])
	_team_rows[team_id] = team
	return team


func league_by_id(league_id: int) -> Dictionary:
	if _league_rows.has(league_id):
		return _league_rows[league_id]
	var reader := _require_reader("leagues")
	if reader == null:
		return {}
	var rows := reader.select_indexed("leagues", "id", league_id,
		PackedStringArray(LEAGUE_COLUMNS))
	if not _query_ok("leagues") or rows.is_empty():
		return {}
	var league := _league_from_row(rows[0])
	_league_rows[league_id] = league
	return league


func read_manifest_coverage(root: String = "") -> Dictionary:
	var path := resolve_data_root(root).path_join(MANIFEST_RELATIVE_PATH)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var coverage = data.get("coverage", {})
	if typeof(coverage) != TYPE_DICTIONARY:
		return {}
	return coverage


func load_squad(team_id: int) -> Dictionary:
	error = ""
	var team := team_by_id(team_id)
	if team.is_empty():
		if error.is_empty():
			error = "Unknown team id %d; load the catalog first." % team_id
		return {}

	var reader := _require_reader("players")
	if reader == null:
		return {}
	var league := league_by_id(_int(team.get("league_id")))
	var national := str(league.get("name", "")) == NATIONAL_LEAGUE_NAME

	var team_rows := reader.select_indexed("teams", "id", team_id,
		PackedStringArray(["id", "name", "league_id", "shortname", "color1", "color2",
			"logo_url", "kit_url", "formation_xml", "formation_factory_xml",
			"tactics_xml", "tactics_factory_xml"]))
	if not _query_ok("teams") or team_rows.is_empty():
		return {}
	var team_row: Dictionary = team_rows[0]
	var formation := Formation.parse_and_normalize(str(team_row.get("formation_xml", "")))

	var club_rows := reader.select_indexed("players", "team_id", team_id,
		PackedStringArray(SQUAD_PLAYER_COLUMNS))
	if not _query_ok("players"):
		return {}
	var national_rows := reader.select_indexed("players", "nationalteam_id", team_id,
		PackedStringArray(SQUAD_PLAYER_COLUMNS))
	if not _query_ok("players"):
		return {}

	var player_rows: Array = []
	var seen := {}
	for row in club_rows + national_rows:
		var player_id := _int(row.get("id"))
		if seen.has(player_id):
			continue
		seen[player_id] = true
		player_rows.append(row)

	var order_column := "nationalteamformationorder" if national else "formationorder"
	player_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := _int(a.get(order_column))
		var order_b := _int(b.get(order_column))
		if order_a != order_b:
			return order_a < order_b
		return _int(a.get("id")) < _int(b.get("id")))

	var players: Array[Dictionary] = []
	for row in player_rows:
		players.append(_player_from_row(row, order_column))

	return {
		"team": team_row,
		"league": league,
		"national": national,
		"formation": formation,
		"players": players,
		"lineup": players.slice(0, Formation.SLOT_COUNT),
	}


func load_team_rating(team_id: int) -> Dictionary:
	if _ratings.has(team_id):
		return _ratings[team_id]
	var team := team_by_id(team_id)
	if team.is_empty():
		return {}
	var league := league_by_id(_int(team.get("league_id")))
	var national := str(league.get("name", "")) == NATIONAL_LEAGUE_NAME
	var reader := _require_reader("players")
	if reader == null:
		return {}
	var column := "nationalteam_id" if national else "team_id"
	var rows := reader.select_indexed("players", column, team_id,
		PackedStringArray(["role", "base_stat"]))
	if not _query_ok("players"):
		return {}
	var players: Array[Dictionary] = []
	for row in rows:
		players.append({
			"role": _text(row.get("role")),
			"base_stat": _float(row.get("base_stat")),
		})
	var rating := TeamRatings.from_players(players)
	_ratings[team_id] = rating
	return rating


func can_field_eleven(team_id: int) -> bool:
	var team := team_by_id(team_id)
	if team.is_empty():
		return false
	var league := league_by_id(_int(team.get("league_id")))
	var national := str(league.get("name", "")) == NATIONAL_LEAGUE_NAME
	var reader := _require_reader("players")
	if reader == null:
		return false
	var column := "nationalteam_id" if national else "team_id"
	var count := reader.count_indexed("players", column, team_id)
	return count < 0 or count >= MIN_MATCH_PLAYERS


func _player_from_row(row: Dictionary, order_column: String) -> Dictionary:
	var first_name := _text(row.get("firstname"))
	var last_name := _text(row.get("lastname"))
	var age := float(_int(row.get("age")))
	var base_stat := _float(row.get("base_stat"))
	var stats := PlayerStats.calculate_profile(_text(row.get("profile_xml")), base_stat, age)
	return {
		"id": _int(row.get("id")),
		"firstname": first_name,
		"lastname": last_name,
		"name": ("%s %s" % [first_name, last_name]).strip_edges(),
		"role": _text(row.get("role")),
		"age": int(age),
		"base_stat": base_stat,
		"formation_order": _int(row.get(order_column)),
		"stats": stats,
		"average": PlayerStats.average(stats),
		"skin_color": _int(row.get("skincolor"), 1),
		"hair_style": _text(row.get("hairstyle")),
		"hair_color": _text(row.get("haircolor")),
		"height": _float(row.get("height"), 1.8),
		"strong_foot": _int(row.get("strong_foot"), 0),
		"tm_id": _int(row.get("tm_id"), 0),
	}


func _league_from_row(row: Dictionary) -> Dictionary:
	var country_id := _int(row.get("country_id"))
	return {
		"id": _int(row.get("id")),
		"name": _text(row.get("name")),
		"country_id": country_id,
		"country": _text(_country_rows.get(country_id, {}).get("name", "")),
		"tier": _int(row.get("tier")),
		"logo_url": _text(row.get("logo_url")),
	}


func _team_from_row(row: Dictionary) -> Dictionary:
	return {
		"id": _int(row.get("id")),
		"league_id": _int(row.get("league_id")),
		"name": _text(row.get("name")),
		"shortname": _text(row.get("shortname")),
		"color1": _text(row.get("color1")),
		"color2": _text(row.get("color2")),
		"logo_url": _text(row.get("logo_url")),
		"kit_url": _text(row.get("kit_url")),
	}


func _require_reader(context: String) -> SqliteReader:
	if _reader == null:
		if error.is_empty():
			error = "Team database is not loaded (needed for %s)." % context
		return null
	return _reader


func _query_ok(context: String) -> bool:
	if _reader == null:
		return false
	if _reader.error.is_empty():
		return true
	error = "Team database could not be read (%s): %s." % [context, _reader.error]
	return false


func _compare_leagues(a: Dictionary, b: Dictionary) -> bool:
	var country_a := str(a["country"])
	var country_b := str(b["country"])
	if country_a.is_empty() != country_b.is_empty():
		return country_b.is_empty()
	if country_a != country_b:
		return country_a < country_b
	if int(a["tier"]) != int(b["tier"]):
		return int(a["tier"]) < int(b["tier"])
	return str(a["name"]) < str(b["name"])


func _compare_teams(a: Dictionary, b: Dictionary) -> bool:
	return str(a["name"]) < str(b["name"])


func _text(value) -> String:
	if value == null:
		return ""
	return str(value)


func _int(value, fallback: int = 0) -> int:
	if value == null:
		return fallback
	return int(value)


func _float(value, fallback: float = 0.0) -> float:
	if value == null:
		return fallback
	return float(value)


func _reset() -> void:
	error = ""
	_countries.clear()
	_countries_loaded = false
	_country_rows.clear()
	_leagues_by_country.clear()
	_league_rows.clear()
	_teams_by_league.clear()
	_team_rows.clear()
	_national_league_id = -1
	_national_league_loaded = false
	_ratings.clear()
