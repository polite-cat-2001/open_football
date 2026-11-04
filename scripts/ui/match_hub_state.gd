class_name MatchHubState
extends RefCounted
# Snapshot helpers shared by the local and network MatchHub adapters. They only
# turn MatchLineup/team data into the plain dictionaries the view consumes.

static func lineup_rows(lineup: MatchLineup) -> Array:
	var rows: Array = []
	if lineup == null:
		return rows
	var captain_slot := lineup.role_slot(MatchLineup.TEAM_ROLE_CAPTAIN)
	for slot in MatchLineup.SLOT_COUNT:
		var player_id := int(lineup.lineup[slot]) if slot < lineup.lineup.size() else 0
		var player := lineup.player_by_id(player_id)
		var entry: Dictionary = lineup.formation[slot] \
			if slot < lineup.formation.size() else {}
		rows.append({
			"slot": slot,
			"number": slot + 1,
			"name": display_name(player, lineup),
			"role": str(entry.get("role", "")),
			"captain": captain_slot == slot,
		})
	return rows


static func display_name(player: Dictionary, lineup: MatchLineup) -> String:
	var last := str(player.get("lastname", ""))
	var first := str(player.get("firstname", ""))
	if last.is_empty():
		return first if not first.is_empty() else "-"
	var duplicates := 0
	for other in lineup.players:
		if str(other.get("lastname", "")) == last:
			duplicates += 1
	if duplicates > 1 and not first.is_empty():
		return "%s. %s" % [first.substr(0, 1), last]
	return last


static func competition_name(catalog: TeamCatalog, home_team: Dictionary,
		away_team: Dictionary) -> String:
	var home_league := league_name(catalog, home_team)
	var away_league := league_name(catalog, away_team)
	if home_league == "National Teams" and away_league == "National Teams":
		return "INTERNATIONAL"
	if not home_league.is_empty() and home_league == away_league:
		return home_league.to_upper()
	return "FRIENDLY"


static func league_name(catalog: TeamCatalog, team: Dictionary) -> String:
	var league_id := int(team.get("league_id", 0))
	if league_id <= 0:
		return ""
	return str(catalog.league_by_id(league_id).get("name", ""))


static func kit_for_side(kit_catalog: KitCatalog, side: int, team: Dictionary) -> Dictionary:
	var selected := ShellState.kit_for(side)
	if not selected.is_empty():
		return selected
	if side == 1:
		var home_team: Dictionary = ShellState.home_team
		var home_kit := kit_for_side(kit_catalog, 0, home_team)
		return kit_catalog.default_away_kit(team, home_kit)
	return kit_catalog.default_kit(team, 0)
