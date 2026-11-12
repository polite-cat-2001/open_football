class_name GpfSquadKey
extends RefCounted
# One change signature for get_squad data. The pause screen and the Game Plan
# both rebuild only when the live squad (or its pending substitutions) differs.


static func build(runtime, team_ids: Array, include_pending := false) -> String:
	if runtime == null or not is_instance_valid(runtime) \
			or not runtime.has_method("get_squad"):
		return ""
	var parts: PackedStringArray = []
	for team_id in team_ids:
		var data: Dictionary = runtime.get_squad(int(team_id))
		for player in data.get("players", []):
			parts.append("%d:%d:%d:%d:%d:%s:%s" % [
				int(player.get("id", -1)),
				int(bool(player.get("active", false))),
				int(bool(player.get("left_pitch", false))),
				int(bool(player.get("pending_out", false))),
				int(bool(player.get("pending_in", false))),
				str(player.get("role", "")),
				str(player.get("position", Vector2.ZERO)),
			])
		for role in data.get("roles", []):
			parts.append("r%d:%d:%d" % [int(role.get("role", -1)),
				int(role.get("slot", -1)), int(role.get("player_id", -1))])
		parts.append("s%d" % int(data.get("substitutions", 0)))
	if include_pending and runtime.has_method("get_pending_substitutions"):
		for pair in runtime.get_pending_substitutions():
			if typeof(pair) != TYPE_DICTIONARY:
				continue
			if not team_ids.has(int(pair.get("team", -1))):
				continue
			parts.append("p%d>%d" % [int(pair.get("out_id", -1)),
				int(pair.get("in_id", -1))])
	return "|".join(parts)
