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

	var home_squad := catalog.load_squad(HOME_ID)
	var away_squad := catalog.load_squad(AWAY_ID)
	_check(not home_squad.is_empty() and not away_squad.is_empty(), "both squads load")

	for side in ["home", "away"]:
		var team: Dictionary = package[side]
		var squad: Dictionary = home_squad if side == "home" else away_squad
		_check(str(team.get("name", "")) == str(squad["team"].get("name", "")),
			"%s name matches the catalog" % side)
		_check(str(team.get("logo_url", "")).begins_with("databases/default/"),
			"%s logo path matches the C++ loader" % side)
		_check(str(team.get("kit_url", "")).begins_with("databases/default/"),
			"%s kit path matches the C++ loader" % side)
		_check(str(team.get("tactics_xml", "")) != "", "%s tactics are carried" % side)
		var formation: Array = team.get("formation", [])
		_check(formation.size() == Formation.SLOT_COUNT,
			"%s has %d formation slots" % [side, formation.size()])
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
