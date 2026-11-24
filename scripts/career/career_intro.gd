class_name CareerIntro
extends RefCounted
# The tournament intro the hub shows the first time the club reaches a
# competition in this career. The text is assembled from the data the engine
# already plays (LeagueRegulations, competitions.json, CareerConfederation.FORMATS),
# so it cannot drift away from the format.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
	"Oct", "Nov", "Dec"]
const UEFA_LABELS := {
	"CL": "UEFA Champions League", "EL": "UEFA Europa League",
	"UCOL": "UEFA Conference League",
}


static func seen(career: Career) -> Array:
	var raw = career.data.get("seen_tournaments", [])
	return raw if raw is Array else []


static func mark_seen(career: Career, competition_id: String) -> void:
	var list := seen(career)
	if list.has(competition_id):
		return
	list.append(competition_id)
	career.data["seen_tournaments"] = list


static func pending(career: Career, date: String, catalog = null) -> Array:
	# Every competition the club plays on `date` for the first time in this career.
	var result: Array = []
	if career == null:
		return result
	var shown := {}
	for competition_id in seen(career):
		shown[str(competition_id)] = true
	for fixture in career.schedule:
		if str(fixture.get("date", "")) != date:
			continue
		if str(fixture.get("home", "")) != career.club_id \
				and str(fixture.get("away", "")) != career.club_id:
			continue
		var competition_id := str(fixture.get("competition", career.league_id))
		if shown.has(competition_id) or _first_fixture(career, competition_id) != fixture:
			continue
		var facts := facts(career, competition_id, catalog)
		if (facts.get("lines", []) as Array).is_empty():
			continue
		shown[competition_id] = true
		result.append(facts)
	return result


static func _first_fixture(career: Career, competition_id: String) -> Dictionary:
	var first := {}
	for fixture in career.schedule:
		var id := str(fixture.get("competition", career.league_id))
		if id != competition_id:
			continue
		if first.is_empty() or str(fixture.get("date", "")) < str(first.get("date", "")):
			first = fixture
	return first


static func facts(career: Career, competition_id: String,
		catalog = null) -> Dictionary:
	var records := CareerCompetitions.records()
	if records.has(competition_id):
		var record: Dictionary = records[competition_id]
		var kind := str(record.get("kind", "cup"))
		return {
			"competition": competition_id,
			"kind": kind,
			"label": str(record.get("label", competition_id)),
			"lines": _cup_lines(career, record) if kind == "cup" \
				else _super_cup_lines(record),
		}
	var league := LeagueRegulations.record(competition_id)
	if not league.is_empty():
		var label := competition_id
		if catalog != null:
			label = str(catalog.league_by_id(competition_id).get("name", label))
		return {
			"competition": competition_id,
			"kind": "league",
			"label": label,
			"lines": _league_lines(career, competition_id, league),
		}
	return _continental(career, competition_id)


static func _league_lines(career: Career, league_id: String,
		league: Dictionary) -> Array:
	var lines: Array = []
	var clubs := career.league_club_ids.size()
	var rounds := 0
	var seen_rounds := {}
	for fixture in career.schedule:
		if str(fixture.get("competition", league_id)) != league_id:
			continue
		seen_rounds[int(fixture.get("round", 0))] = true
	rounds = seen_rounds.size()
	var summary: Array = []
	if clubs > 0:
		summary.append("%d clubs" % clubs)
	if rounds > 0:
		summary.append("%d matchdays" % rounds)
	if not summary.is_empty():
		lines.append(" · ".join(summary))
	var phases := _phase_text(str(league.get("phases", "")))
	if not phases.is_empty():
		lines.append(phases)
	var relegation = league.get("relegation", {})
	if relegation is Dictionary:
		var slots := int(relegation.get("slots", 0))
		if slots > 0:
			lines.append("Relegation: %d%s" % [slots,
				" plus a play-off" if bool(relegation.get("playoff", false)) else ""])
	var europe := _europe_places(career)
	if not europe.is_empty():
		lines.append(europe)
	var window := _window(league.get("start_md", ""), league.get("end_md", ""))
	if not window.is_empty():
		lines.append(window)
	return lines


static func _phase_text(phases: String) -> String:
	match phases:
		"split":
			return "Split after the regular phase into championship and relegation groups"
		"apertura_clausura":
			return "Two championships: Apertura and Clausura"
		_:
			return ""


static func _europe_places(career: Career) -> String:
	var seasons: Dictionary = career.data.get("berths", {})
	var block: Dictionary = seasons.get(career.season_start, {})
	var country := ""
	for name in block:
		for berth in (block[name] as Dictionary).get("berths", []):
			if str((berth as Dictionary).get("club_id", "")) == career.club_id:
				country = str(name)
				break
		if not country.is_empty():
			break
	if country.is_empty():
		return ""
	var counts := {}
	for berth in (block[country] as Dictionary).get("berths", []):
		var competition := str((berth as Dictionary).get("competition", ""))
		counts[competition] = int(counts.get(competition, 0)) + 1
	var parts: Array = []
	for competition in ["CL", "EL", "UCOL"]:
		if int(counts.get(competition, 0)) > 0:
			parts.append("%d %s" % [int(counts[competition]), competition])
	if parts.is_empty():
		return ""
	return "Europe: " + " · ".join(parts)


static func _cup_lines(career: Career, record: Dictionary) -> Array:
	var lines: Array = []
	var summary: Array = []
	var field := int(record.get("field_size", 0))
	if field > 0:
		summary.append("%d clubs" % field)
	summary.append("knockout")
	lines.append(" · ".join(summary))
	var two_legged: Array = record.get("two_legged", [])
	if not two_legged.is_empty():
		var names: Array = []
		for name in two_legged:
			names.append(str(name))
		lines.append("Two legs: " + ", ".join(names))
	if int(record.get("final_legs", 1)) > 1:
		lines.append("The final is played over two legs")
	var window := _window(record.get("start_md", ""), record.get("end_md", ""))
	if not window.is_empty():
		lines.append(window)
	return lines


static func _super_cup_lines(record: Dictionary) -> Array:
	var teams := int(record.get("teams", 2))
	var lines: Array = []
	lines.append("%d clubs · %s" % [teams,
		"mini-tournament" if teams > 2 else "one match"])
	if bool(record.get("neutral", false)):
		lines.append("Played at a neutral venue")
	var window := _window(record.get("start_md", ""), record.get("end_md", ""))
	if not window.is_empty():
		lines.append(window)
	return lines


static func _continental(career: Career, competition_id: String) -> Dictionary:
	var confederation := ""
	for key in CareerConfederation.FORMATS:
		if str(key).ends_with(":" + competition_id):
			confederation = str(key).get_slice(":", 0)
	var label := str(UEFA_LABELS.get(competition_id, competition_id))
	var lines: Array = []
	var format: Dictionary = CareerConfederation.FORMATS.get(
		"%s:%s" % [confederation, competition_id], {})
	if format.is_empty():
		# The UEFA competitions live in the access lists, not in FORMATS.
		var sizes: Dictionary = {}
		var uefa = CareerBerths.access().get("uefa", {})
		if uefa is Dictionary:
			sizes = uefa.get("entry_round_sizes", {})
		var entry: Dictionary = sizes.get(competition_id, {})
		if entry.is_empty():
			return {"competition": competition_id, "kind": "continental",
				"label": label, "lines": lines}
		var rounds := int(CareerEurope.ROUNDS.get(competition_id, 8))
		var size := int(entry.get("league_phase", 36))
		lines.append("%d clubs · %d league-phase rounds" % [size, rounds])
		lines.append("Knockout from the round of 16")
		var window := _window(entry.get("start_md", "09-15"),
			entry.get("end_md", "05-30"))
		if not window.is_empty():
			lines.append(window)
		return {"competition": competition_id, "kind": "continental",
			"label": label, "lines": lines}
	label = str(format.get("label", competition_id))
	for spec in format.get("rounds", []):
		var round_spec: Dictionary = spec
		var groups = round_spec.get("groups")
		if groups is Dictionary:
			var group: Dictionary = groups
			lines.append("%d groups of %d · %d rounds" % [
				int(group.get("count", 0)), int(group.get("size", 0)),
				int(group.get("rounds", 0))])
	for spec in format.get("rounds", []):
		var round_spec: Dictionary = spec
		if round_spec.get("groups") is Dictionary:
			continue
		if str(round_spec.get("name", "")) == "final":
			lines.append("Single final")
	var window := _window(_first_window(format, 0), _first_window(format, -1))
	if not window.is_empty():
		lines.append(window)
	return {"competition": competition_id, "kind": "continental", "label": label,
		"lines": lines}


static func _first_window(format: Dictionary, index: int) -> String:
	var rounds: Array = format.get("rounds", [])
	if rounds.is_empty():
		return ""
	var spec: Dictionary = rounds[index % rounds.size()]
	var window = spec.get("window", [])
	if window is Array and not window.is_empty():
		return str(window[0] if index == 0 else window[window.size() - 1])
	return ""


static func _window(start_md: String, end_md: String) -> String:
	if start_md.length() < 5 or end_md.length() < 5:
		return ""
	return "%s – %s" % [_day(start_md), _day(end_md)]


static func _day(md: String) -> String:
	var parts := md.split("-")
	if parts.size() < 2:
		return md
	var month := int(parts[0])
	var day := int(parts[1])
	if month < 1 or month > MONTHS.size():
		return md
	return "%d %s" % [day, MONTHS[month - 1]]
