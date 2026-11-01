class_name NetworkMatch
extends RefCounted
# LAN v1 same-data match setup: the host broadcasts only team ids, so both peers
# build the package locally from the same database (default lineups/formation).
# The kickoff options come from the host-authoritative lobby.

static var error := ""


static func build_package(team_ids: Array, options: Dictionary,
		data_root: String = "") -> Dictionary:
	error = ""
	if team_ids.size() != 2:
		error = "Network match needs two team ids."
		return {}
	var home_id := int(team_ids[0])
	var away_id := int(team_ids[1])
	if home_id <= 0 or away_id <= 0 or home_id == away_id:
		error = "Invalid network team ids: %s." % str(team_ids)
		return {}

	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(data_root):
		error = catalog.error
		return {}
	var home := catalog.team_by_id(home_id)
	var away := catalog.team_by_id(away_id)
	if home.is_empty() or away.is_empty():
		error = "Unknown network team ids: %s." % str(team_ids)
		return {}

	var builder := MatchPackage.new()
	var package := builder.build_from_ids(catalog, home_id, away_id, options)
	if package.is_empty():
		error = builder.error if not builder.error.is_empty() else "Network match package failed."
		return {}

	ShellState.set_teams(home, away)
	ShellState.set_match_package(package)
	return package


static func apply_setup(tree: SceneTree, runtime: Node, setup: Dictionary,
		options: Dictionary, data_root: String = "") -> Dictionary:
	var team_ids: Array = setup.get("team_ids", [])
	var package := build_package(team_ids, options, data_root)
	if package.is_empty():
		return {}
	if runtime != null and not bool(runtime.set_match_package(package)):
		error = runtime.get_last_error()
		return {}
	return package
