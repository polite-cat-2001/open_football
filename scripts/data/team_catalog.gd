class_name TeamCatalog
extends RefCounted
# Godot-side catalog of leagues and teams, read straight from the game's SQLite
# database. The C++ catalog is no longer used to populate the shell: the match
# package (a later ticket) gets the chosen teams from here.
#
# Team rows intentionally keep only the selection fields; players and the big
# formation/tactics XML blobs are not loaded by the selection screen.

const DEFAULT_DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const DATABASE_RELATIVE_PATH := "databases/default/database.sqlite"
const MANIFEST_RELATIVE_PATH := "databases/default/manifest.json"
const NATIONAL_LEAGUE_NAME := "National Teams"
const SQUAD_PLAYER_COLUMNS := [
	"id", "team_id", "nationalteam_id", "firstname", "lastname", "role", "age",
	"base_stat", "profile_xml", "formationorder", "nationalteamformationorder",
]

var error := ""
var leagues: Array[Dictionary] = []
var teams: Array[Dictionary] = []

var _countries := {}
var _teams_by_league := {}
var _teams_by_id := {}


func load_data_root(root: String = "") -> bool:
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
	var loaded := _load_from_reader(reader)
	reader.close()
	if not loaded:
		return false
	if leagues.is_empty() or teams.is_empty():
		error = "Team database has no leagues or teams: %s." % database_path
		_reset()
		return false
	return true


func resolve_data_root(root: String = "") -> String:
	if not root.is_empty():
		return root
	var environment := OS.get_environment("GPF_DATA_ROOT")
	if not environment.is_empty():
		return environment
	return DEFAULT_DATA_ROOT


func database_path(root: String = "") -> String:
	return resolve_data_root(root).path_join(DATABASE_RELATIVE_PATH)


func teams_for_league(league_id: int) -> Array:
	return _teams_by_league.get(league_id, [])


func team_by_id(team_id: int) -> Dictionary:
	return _teams_by_id.get(team_id, {})


func league_by_id(league_id: int) -> Dictionary:
	for league in leagues:
		if int(league["id"]) == league_id:
			return league
	return {}


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
		error = "Unknown team id %d; load the catalog first." % team_id
		return {}

	var path := database_path()
	if not FileAccess.file_exists(path):
		error = "Team database not found at %s. Set GPF_DATA_ROOT to the GameplayFootball data folder." % path
		return {}
	var reader := SqliteReader.new()
	if not reader.open(path):
		error = "Team database could not be read: %s (%s)." % [path, reader.error]
		return {}

	var team_rows := reader.select_any("teams", [{"column": "id", "value": team_id}],
		PackedStringArray(["id", "name", "league_id", "shortname", "color1", "color2", "formation_xml"]))
	if not reader.error.is_empty() or team_rows.is_empty():
		error = "Team %d could not be read: %s." % [team_id, reader.error]
		reader.close()
		return {}
	var team_row: Dictionary = team_rows[0]
	var league := league_by_id(_int(team_row.get("league_id")))
	var national := str(league.get("name", "")) == NATIONAL_LEAGUE_NAME
	var formation := Formation.parse_and_normalize(str(team_row.get("formation_xml", "")))

	var club_rows := reader.select_indexed("players", "team_id", team_id,
		PackedStringArray(SQUAD_PLAYER_COLUMNS))
	if not reader.error.is_empty():
		error = "Players for team %d could not be read: %s." % [team_id, reader.error]
		reader.close()
		return {}
	var national_rows := reader.select_indexed("players", "nationalteam_id", team_id,
		PackedStringArray(SQUAD_PLAYER_COLUMNS))
	if not reader.error.is_empty():
		error = "Players for team %d could not be read: %s." % [team_id, reader.error]
		reader.close()
		return {}
	reader.close()

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
		var first_name := _text(row.get("firstname"))
		var last_name := _text(row.get("lastname"))
		var age := float(_int(row.get("age")))
		var base_stat := _float(row.get("base_stat"))
		var stats := PlayerStats.calculate_profile(_text(row.get("profile_xml")), base_stat, age)
		players.append({
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
		})

	return {
		"team": team_row,
		"league": league,
		"national": national,
		"formation": formation,
		"players": players,
		"lineup": players.slice(0, Formation.SLOT_COUNT),
	}


func _load_from_reader(reader: SqliteReader) -> bool:
	var country_rows := reader.select_all("countries", PackedStringArray(["id", "name"]))
	if not reader.error.is_empty():
		error = "Team database could not be read (countries): %s." % reader.error
		return false
	for country in country_rows:
		_countries[int(country["id"])] = _text(country.get("name"))

	var league_rows := reader.select_all("leagues",
		PackedStringArray(["id", "name", "country_id", "tier"]))
	if not reader.error.is_empty():
		error = "Team database could not be read (leagues): %s." % reader.error
		return false
	for row in league_rows:
		var country_id := _int(row.get("country_id"))
		leagues.append({
			"id": int(row["id"]),
			"name": _text(row.get("name")),
			"country_id": country_id,
			"country": _text(_countries.get(country_id, "")),
			"tier": _int(row.get("tier")),
		})
	leagues.sort_custom(_compare_leagues)

	var team_rows := reader.select_all("teams",
		PackedStringArray(["id", "league_id", "name", "shortname", "color1", "color2"]))
	if not reader.error.is_empty():
		error = "Team database could not be read (teams): %s." % reader.error
		return false
	for row in team_rows:
		var league_id := _int(row.get("league_id"))
		var team := {
			"id": int(row["id"]),
			"league_id": league_id,
			"name": _text(row.get("name")),
			"shortname": _text(row.get("shortname")),
			"color1": _text(row.get("color1")),
			"color2": _text(row.get("color2")),
		}
		teams.append(team)
		_teams_by_id[int(team["id"])] = team
		if not _teams_by_league.has(league_id):
			_teams_by_league[league_id] = []
		_teams_by_league[league_id].append(team)
	teams.sort_custom(_compare_teams)
	for league_id in _teams_by_league:
		_teams_by_league[league_id].sort_custom(_compare_teams)
	return true


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
	leagues.clear()
	teams.clear()
	_countries.clear()
	_teams_by_league.clear()
	_teams_by_id.clear()
