extends SceneTree
# Headless check for the Godot-side match package: two selected teams become a
# self-contained payload with squads, final stats, normalized positions and
# prematch options. The C++ side consumes exactly this shape.
#
# Run:  godot --headless --path . -s res://tests/check_match_package.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const HOME_ID := 4
const AWAY_ID := 5

var failures: Array[String] = []


func _init() -> void:
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		_fail("catalog did not load: " + catalog.error)
		_finish()
		return

	var builder := MatchPackage.new()
	var package := builder.build_from_ids(catalog, HOME_ID, AWAY_ID,
		{"duration": 0.5, "difficulty": 1.0})
	_check(not package.is_empty(), "the package is built: " + builder.error)
	if package.is_empty():
		_finish()
		return

	_check(int(package.get("version", 0)) == MatchPackage.VERSION, "the package has a version")
	_check(int(package.get("home", {}).get("database_id", 0)) == HOME_ID, "home id is carried")
	_check(int(package.get("away", {}).get("database_id", 0)) == AWAY_ID, "away id is carried")
	_check(float(package.get("options", {}).get("duration", -1)) == 0.5, "duration option is carried")
	_check(float(package.get("options", {}).get("difficulty", -1)) == 1.0, "difficulty option is carried")

	# Match length presets: every offered minute value round-trips onto the
	# runtime's duration factor (90 game minutes compressed into N real ones).
	for minutes in MatchPackage.LENGTH_PRESETS:
		var round_trip := MatchPackage.minutes_from_duration(
			MatchPackage.duration_from_minutes(float(minutes)))
		_check(absf(round_trip - float(minutes)) < 0.001,
			"match length %d min round-trips" % int(minutes))

	var home_squad := catalog.load_squad(HOME_ID)
	var away_squad := catalog.load_squad(AWAY_ID)
	_check(not home_squad.is_empty() and not away_squad.is_empty(), "both squads load")

	var kit_catalog := KitCatalog.new()
	kit_catalog.load_data_root(DATA_ROOT)
	var home_kit := kit_catalog.default_kit(catalog.team_by_id(HOME_ID), 0)
	var away_kit := kit_catalog.default_away_kit(catalog.team_by_id(AWAY_ID), home_kit)

	for side in ["home", "away"]:
		var team: Dictionary = package[side]
		var squad: Dictionary = home_squad if side == "home" else away_squad
		var expected_kit: Dictionary = home_kit if side == "home" else away_kit
		_check(str(team.get("name", "")) == str(squad["team"].get("name", "")),
			"%s name matches the catalog" % side)
		_check(str(team.get("league", "")) != "", "%s carries the competition name" % side)
		_check(str(team.get("logo_url", "")).begins_with("databases/default/"),
			"%s logo path matches the C++ loader" % side)
		_check(str(team.get("kit_url", "")).begins_with("databases/default/"),
			"%s kit path matches the C++ loader" % side)
		_check(str(team.get("kit", {}).get("id", "")) == str(expected_kit.get("id", "")),
			"%s has the expected default kit" % side)
		_check(str(team.get("tactics_xml", "")) != "", "%s tactics are carried" % side)
		var formation: Array = team.get("formation", [])
		_check(formation.size() == Formation.SLOT_COUNT,
			"%s has %d formation slots" % [side, formation.size()])
		var team_roles: Array = team.get("roles", [])
		_check(team_roles.size() == 6, "%s carries all six role slots" % side)
		var roles_ok := true
		for entry in formation:
			roles_ok = roles_ok and Formation.VALID_ROLES.has(str(entry.get("role", "")))
		_check(roles_ok, "%s roles are valid" % side)
		var players: Array = team.get("players", [])
		_check(players.size() >= Formation.SLOT_COUNT,
			"%s carries the whole squad (%d)" % [side, players.size()])
		var stats_ok := true
		for player in players:
			var stats: Dictionary = player.get("stats", {})
			stats_ok = stats_ok and stats.size() == PlayerStats.STAT_NAMES.size()
		_check(stats_ok, "%s players carry all %d final stats" % [side, PlayerStats.STAT_NAMES.size()])

		# Positions and stats are exactly what the squad screen computed.
		var squad_formation: Array = squad["formation"]
		var squad_players: Array = squad["players"]
		var match_ok := true
		for index in Formation.SLOT_COUNT:
			match_ok = match_ok and str(formation[index]["role"]) == str(squad_formation[index]["role"])
			match_ok = match_ok and formation[index]["position"] == squad_formation[index]["position"]
		for index in squad_players.size():
			match_ok = match_ok and players[index]["database_id"] == squad_players[index]["id"]
			match_ok = match_ok and players[index]["stats"] == squad_players[index]["stats"]
		_check(match_ok, "%s positions and stats match the catalog squad" % side)

	# Guard rails.
	var same := builder.build_from_ids(catalog, HOME_ID, HOME_ID)
	_check(same.is_empty() and not builder.error.is_empty(), "the same team twice is rejected")
	var unknown := builder.build_from_ids(catalog, 9999999, AWAY_ID)
	_check(unknown.is_empty() and not builder.error.is_empty(), "an unknown team is rejected")

	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	print("  FAIL: ", message)


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: match package")
		quit(0)
	else:
		print("CHECK FAIL: ", failures[0])
		quit(1)
