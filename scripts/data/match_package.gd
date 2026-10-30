class_name MatchPackage
extends RefCounted
# Builds the self-contained match package the C++ runtime consumes: both teams,
# their full squads with final (age-adjusted) stats, the normalized formation and
# prematch options. C++ builds the Match from this package and does not read the
# database for the match.
#
# Schema (all keys are required by GpfRuntimeNode::set_match_package):
#   { version, options: {duration, difficulty}, home: team, away: team }
#   team: { database_id, name, short_name, logo_url, kit_url, colors,
#           formation_xml, formation_factory_xml, tactics_xml,
#           tactics_factory_xml, formation[11], players[] }
#   player: { database_id, first_name, last_name, role, skin_color, hair_style,
#             hair_color, height, strong_foot, tm_id, stats{} }

const VERSION := 1
const DEFAULT_OPTIONS := {
	"duration": 1.0,
	"difficulty": 0.8,
}

var error := ""


func build(catalog: TeamCatalog, home_team: Dictionary, away_team: Dictionary,
		options: Dictionary = {}) -> Dictionary:
	error = ""
	if home_team.is_empty() or away_team.is_empty():
		error = "Match package needs two selected teams."
		return {}
	if int(home_team.get("id", 0)) == int(away_team.get("id", 0)):
		error = "Home and away teams must be different."
		return {}

	var home_squad := catalog.load_squad(int(home_team["id"]))
	if not catalog.error.is_empty() or home_squad.is_empty():
		error = catalog.error if not catalog.error.is_empty() else "Home squad could not be loaded."
		return {}
	var away_squad := catalog.load_squad(int(away_team["id"]))
	if not catalog.error.is_empty() or away_squad.is_empty():
		error = catalog.error if not catalog.error.is_empty() else "Away squad could not be loaded."
		return {}

	var home := _team_package(home_squad)
	if not error.is_empty():
		return {}
	var away := _team_package(away_squad)
	if not error.is_empty():
		return {}

	return {
		"version": VERSION,
		"options": _options(options),
		"home": home,
		"away": away,
	}


func build_from_ids(catalog: TeamCatalog, home_id: int, away_id: int,
		options: Dictionary = {}) -> Dictionary:
	return build(catalog, catalog.team_by_id(home_id), catalog.team_by_id(away_id), options)


func _options(options: Dictionary) -> Dictionary:
	return {
		"duration": clampf(float(options.get("duration", DEFAULT_OPTIONS["duration"])), 0.0, 2.0),
		"difficulty": clampf(float(options.get("difficulty", DEFAULT_OPTIONS["difficulty"])), 0.0, 1.0),
	}


func _team_package(squad: Dictionary) -> Dictionary:
	var team: Dictionary = squad.get("team", {})
	var formation: Array = squad.get("formation", [])
	var players: Array = squad.get("players", [])
	var team_id := int(team.get("id", 0))
	if team_id <= 0:
		error = "A squad has no team row."
		return {}
	if formation.size() != Formation.SLOT_COUNT:
		error = "Team %d formation has %d slots, expected %d." \
			% [team_id, formation.size(), Formation.SLOT_COUNT]
		return {}
	if players.size() < Formation.SLOT_COUNT:
		error = "Team %d has %d players, expected at least %d." \
			% [team_id, players.size(), Formation.SLOT_COUNT]
		return {}

	var package_players: Array[Dictionary] = []
	for player in players:
		var stats: Dictionary = player.get("stats", {})
		if stats.is_empty():
			error = "Player %s has no stats." % str(player.get("name", "?"))
			return {}
		package_players.append({
			"database_id": int(player.get("id", 0)),
			"first_name": str(player.get("firstname", "")),
			"last_name": str(player.get("lastname", "")),
			"role": str(player.get("role", "")),
			"skin_color": int(player.get("skin_color", 1)),
			"hair_style": str(player.get("hair_style", "short01")),
			"hair_color": str(player.get("hair_color", "darkblonde")),
			"height": float(player.get("height", 1.8)),
			"strong_foot": int(player.get("strong_foot", 0)),
			"tm_id": int(player.get("tm_id", 0)),
			"stats": stats.duplicate(),
		})

	var package_formation: Array[Dictionary] = []
	for entry in formation:
		package_formation.append({
			"slot": int(entry.get("slot", 0)),
			"role": str(entry.get("role", "CM")),
			"database_position": entry.get("database_position", Vector2.ZERO),
			"position": entry.get("position", Vector2.ZERO),
		})

	return {
		"database_id": team_id,
		"name": str(team.get("name", "")),
		"short_name": str(team.get("shortname", "")),
		"logo_url": _asset_url(team.get("logo_url", "")),
		"kit_url": _asset_url(team.get("kit_url", "")),
		"color1": _color(team.get("color1", "")),
		"color2": _color(team.get("color2", "")),
		"formation_xml": str(team.get("formation_xml", "")),
		"formation_factory_xml": str(team.get("formation_factory_xml", "")),
		"tactics_xml": str(team.get("tactics_xml", "")),
		"tactics_factory_xml": str(team.get("tactics_factory_xml", "")),
		"formation": package_formation,
		"players": package_players,
	}


func _asset_url(value) -> String:
	# TeamData's database loader prefixes the asset directory; the package has to
	# carry the same paths because C++ no longer touches the teams table.
	return "databases/default/" + str(value)


func _color(value) -> Vector3:
	# Same rule as the original GetVectorFromString: comma-separated floats.
	var parts := str(value).split(",", false)
	var color := Vector3.ZERO
	if parts.size() > 0:
		color.x = parts[0].strip_edges().to_float()
	if parts.size() > 1:
		color.y = parts[1].strip_edges().to_float()
	if parts.size() > 2:
		color.z = parts[2].strip_edges().to_float()
	return color
