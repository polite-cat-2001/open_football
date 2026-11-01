extends RefCounted
# Pure substitution-banner text for the thin LAN client. The original client
# applies Team::Substitute from its snapshot but keeps no notice book, so the
# shell derives the banner from the active-roster delta instead. No C++ change.


static func active_names(entries: Array) -> Dictionary:
	var names := {}
	for entry in entries:
		names[int(entry.get("id", -1))] = str(entry.get("name", ""))
	return names


static func changed_ids(previous: Dictionary, current: Dictionary) -> Dictionary:
	var out_ids: Array = []
	var in_ids: Array = []
	for id in previous:
		if not current.has(id):
			out_ids.append(id)
	for id in current:
		if not previous.has(id):
			in_ids.append(id)
	return {"out": out_ids, "in": in_ids}


static func build_lines(previous: Dictionary, current: Dictionary) -> Array:
	var changed := changed_ids(previous, current)
	var out_names: Array = []
	var in_names: Array = []
	for id in changed["out"]:
		out_names.append(str(previous[id]))
	for id in changed["in"]:
		in_names.append(str(current[id]))
	var lines: Array = []
	for i in mini(out_names.size(), in_names.size()):
		lines.append("%s off, %s on" % [out_names[i], in_names[i]])
	return lines
