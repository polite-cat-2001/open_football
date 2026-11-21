extends SceneTree
# Headless check for the encoded league formats. Validates the shape of every
# shipped `format`: the row window equals the format window, stage ids are
# unique, stage dates sit inside the season, and the promotion/relegation
# clauses are present. The first encoded league is the Austrian split, so its
# groups and carried points are pinned explicitly.
#
# Run:  godot --headless --path . -s res://tests/check_league_formats.gd

const KINDS := ["league", "group", "knockout", "fixture_list"]
const CHAMPIONS := ["aggregate", "none", "unknown"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _inside_season(date: String, start: String, end: String) -> bool:
	if start <= end:
		return date >= start and date <= end
	return date >= start or date <= end


func _slot_sum(format: Dictionary, key: String) -> int:
	var total := 0
	for clause in format.get(key, []):
		var rule := str(clause.get("rule", ""))
		if rule == "none" or rule == "unknown":
			continue
		total += int(clause.get("slots", 0))
	return total


func _playoff_slots(format: Dictionary, key: String) -> int:
	var total := 0
	for clause in format.get(key, []):
		if bool(clause.get("playoff", false)):
			total += int(clause.get("slots", 0))
	return total


func _run() -> void:
	var data := LeagueRegulations.load_all()
	_check(not data.is_empty(), "the regulations load")
	var leagues: Dictionary = data.get("leagues", {})
	var encoded := 0
	var with_groups := 0
	var with_carry := 0
	var bad: Array[String] = []
	for league_id in leagues:
		var row: Dictionary = leagues[league_id]
		var format = row.get("format")
		if not (format is Dictionary):
			continue
		encoded += 1
		if str(format.get("start_md", "")) != str(row.get("start_md", "")) \
				or str(format.get("end_md", "")) != str(row.get("end_md", "")):
			bad.append("%s: row window != format window" % league_id)
		var stages = format.get("stages")
		if not (stages is Array) or (stages as Array).is_empty():
			bad.append("%s: no stages" % league_id)
			continue
		var ids := {}
		var has_group := false
		for stage in stages:
			if not (stage is Dictionary):
				bad.append("%s: stage is not a dictionary" % league_id)
				continue
			var stage_id := str(stage.get("id", ""))
			if stage_id.is_empty() or ids.has(stage_id):
				bad.append("%s: stage id missing or duplicated: %s" % [league_id, stage_id])
			ids[stage_id] = true
			var kind := str(stage.get("kind", ""))
			if not KINDS.has(kind):
				bad.append("%s/%s: unknown stage kind %s" % [league_id, stage_id, kind])
			if kind == "group":
				has_group = true
				var groups = stage.get("groups")
				if not (groups is Dictionary) or not (groups.get("sizes") is Array):
					bad.append("%s/%s: group stage without sizes" % [league_id, stage_id])
			var start := str(stage.get("start_md", ""))
			var end := str(stage.get("end_md", ""))
			if start.is_empty() or end.is_empty():
				bad.append("%s/%s: no stage date" % [league_id, stage_id])
			elif not _inside_season(start, str(format.get("start_md", "")),
					str(format.get("end_md", ""))) \
					or not _inside_season(end, str(format.get("start_md", "")),
					str(format.get("end_md", ""))):
				bad.append("%s/%s: stage outside the season" % [league_id, stage_id])
		if has_group:
			with_groups += 1
		if format.get("carry") is Dictionary:
			with_carry += 1
		if not (format.get("promotion") is Array):
			bad.append("%s: promotion is not a list" % league_id)
		if not (format.get("relegation") is Array):
			bad.append("%s: relegation is not a list" % league_id)
		var champion := str(format.get("champion", ""))
		if not (CHAMPIONS.has(champion) or champion.begins_with("stage:")):
			bad.append("%s: champion is %s" % [league_id, champion])

	_check(encoded > 0, "at least one format is encoded")
	_check(with_groups > 0, "at least one group stage is encoded")
	_check(with_carry > 0, "at least one split carries points")
	_check(bad.is_empty(), "every format is well formed: " + str(bad))

	var pyramid = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/data/league_pyramids.json"))
	var levels: Dictionary = pyramid.get("leagues", {}) if pyramid is Dictionary else {}
	var by_key := {}
	for boundary in pyramid.get("boundaries", []) if pyramid is Dictionary else []:
		by_key["%s|%d" % [boundary.get("country", ""), int(boundary.get("upper", 0))]] = boundary
	var slot_bad: Array[String] = []
	for league_id in leagues:
		var format = leagues[league_id].get("format")
		if not (format is Dictionary):
			continue
		var info: Dictionary = levels.get(league_id, {})
		if info.is_empty():
			continue
		var country := str(info.get("country", ""))
		var level := int(info.get("level", 0))
		var expected_up := 0
		if not bool(info.get("closed_up", false)) and level > 1:
			expected_up = int(by_key.get("%s|%d" % [country, level - 1], {}).get("up", 0))
		var expected_down := 0
		if not bool(info.get("closed_down", false)):
			expected_down = int(by_key.get("%s|%d" % [country, level], {}).get("down", 0))
		var actual_up := _slot_sum(format, "promotion")
		var actual_down := _slot_sum(format, "relegation")
		if actual_up != expected_up:
			slot_bad.append("%s: promotion %d != boundary %d" % [league_id, actual_up, expected_up])
		if actual_down != expected_down:
			slot_bad.append("%s: relegation %d != boundary %d" % [league_id, actual_down, expected_down])
		var boundary_down: Dictionary = by_key.get("%s|%d" % [country, level], {})
		var expected_playoff := int(boundary_down.get("down_playoff", 0))
		var actual_playoff := _playoff_slots(format, "relegation")
		if actual_playoff != expected_playoff:
			slot_bad.append("%s: playoff slots %d != boundary %d" % [
				league_id, actual_playoff, expected_playoff])
	_check(slot_bad.is_empty(), "movement slots match the pyramid: " + str(slot_bad))

	var austria: Dictionary = LeagueRegulations.record("A1").get("format", {})
	_check(str(austria.get("champion", "")) == "stage:championship",
		"Austria's champion is the championship group")
	_check((austria.get("stages", []) as Array).size() == 3,
		"Austria has a regular stage and two groups")
	var sizes: Array = []
	for stage in austria.get("stages", []):
		if str(stage.get("kind", "")) == "group":
			sizes.append_array(stage.get("groups", {}).get("sizes", []))
	_check(sizes.size() == 2 and int(sizes[0]) == 6 and int(sizes[1]) == 6,
		"Austria splits 12 clubs into 6 and 6")
	_check(str(austria.get("carry", {}).get("points", "")) == "full",
		"Austria carries the full points into the split")

	print("== check_league_formats: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
