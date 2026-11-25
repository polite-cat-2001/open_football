class_name CareerIntro
extends RefCounted
# The tournament intro the hub shows the first time the club reaches a
# competition in this career. The rules text is a per-format sentence from the
# locale catalogue (UiText), the numbers come from the data the engine plays
# (LeagueRegulations, competitions.json, CareerConfederation.FORMATS), so neither
# the wording nor the figures are written twice.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
	"Oct", "Nov", "Dec"]
const UEFA_LABELS := {
	"CL": "UEFA Champions League", "EL": "UEFA Europa League",
	"UCOL": "UEFA Conference League",
}
# The league phase sends the best eight straight to the round of 16 and the next
# sixteen into a play-off round (career_europe.gd: table.slice(0, 24)).
const LEAGUE_PHASE_DIRECT := 8
const LEAGUE_PHASE_PLAYOFF := 16


static func _int(value, fallback: int) -> int:
	# Several records state a number as null ("not in the source"); int(null)
	# aborts the caller in GDScript, so every read goes through here.
	if value == null:
		return fallback
	if value is int or value is float or value is bool:
		return int(value)
	if value is String and (value as String).is_valid_int():
		return int(value)
	return fallback


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
		if kind == "cup":
			return {
				"competition": competition_id, "kind": kind,
				"format": "cup.knockout",
				"country": str(record.get("country", "")),
				"label": str(record.get("label", competition_id)),
				"lines": _cup_lines(record),
			}
		return {
			"competition": competition_id, "kind": kind,
			"format": _super_cup_format(record),
			"country": str(record.get("country", "")),
			"label": str(record.get("label", competition_id)),
			"lines": _super_cup_lines(record),
		}
	var league := LeagueRegulations.record(competition_id)
	if not league.is_empty():
		var label := competition_id
		var country := ""
		if catalog != null:
			var row: Dictionary = catalog.league_by_id(competition_id)
			label = str(row.get("name", label))
			country = str(catalog.country_by_id(_int(row.get("country_id"), 0))
				.get("name", ""))
		var format_key := _league_format_key(str(league.get("phases", "")))
		return {
			"competition": competition_id, "kind": "league", "format": format_key,
			"country": country, "label": label,
			"lines": _league_lines(career, competition_id, league, catalog, format_key),
		}
	return _continental(career, competition_id)


static func _league_format_key(phases: String) -> String:
	match phases:
		"split":
			return "league.split"
		"apertura_clausura":
			return "league.apertura"
		"other":
			return "league.zones"
		_:
			return "league.single"


static func _league_lines(career: Career, league_id: String,
		league: Dictionary, catalog, format_key: String) -> Array:
	var lines: Array = [UiText.t("tournament." + format_key)]
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
	# Movement across the nearest boundaries: the pyramid numbers when the league
	# is researched, the regulation record otherwise. A side with nothing to play
	# for (the top flight above, the pyramid floor below) is simply not printed.
	var up := 0
	var down := 0
	if CareerPyramids.has_record(league_id):
		var level := int(CareerPyramids.record(league_id).get("level", 1))
		if level > 1:
			up = CareerPyramids.promotion_places(league_id)
		down = CareerPyramids.relegation_places(league_id)
	else:
		var relegation = league.get("relegation", {})
		if relegation is Dictionary:
			down = _int(relegation.get("slots"), 0)
	if up > 0:
		lines.append(UiText.t("tournament.league.promotion", {"count": up}))
	if down > 0:
		lines.append(UiText.t("tournament.league.relegation", {"count": down}))
	# The European places belong to the association's top flight; a second-tier
	# club cannot take them, so the line would be a lie there.
	var tier := 1
	if catalog != null:
		tier = _int(catalog.league_by_id(league_id).get("tier"), 1)
	var europe := "" if tier > 1 else _europe_places(career, league_id, catalog)
	if not europe.is_empty():
		lines.append(europe)
	var window := _window(league.get("start_md", ""), league.get("end_md", ""))
	if not window.is_empty():
		lines.append(window)
	return lines


static func _europe_places(career: Career, league_id: String, catalog = null) -> String:
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
		return _europe_text(_band_counts(league_id, catalog))
	var counts := {}
	for berth in (block[country] as Dictionary).get("berths", []):
		var competition := str((berth as Dictionary).get("competition", ""))
		counts[competition] = int(counts.get(competition, 0)) + 1
	return _europe_text(counts)


static func _band_counts(league_id: String, catalog) -> Dictionary:
	# First season: the club's association only has its access band, not a full
	# berth list, so count the slots of that band the same way the season does.
	if catalog == null:
		return {}
	var row: Dictionary = catalog.league_by_id(league_id)
	var country := str(catalog.country_by_id(_int(row.get("country_id"), 0))
		.get("name", ""))
	if country.is_empty():
		return {}
	var uefa = CareerBerths.access().get("uefa", {})
	if not (uefa is Dictionary):
		return {}
	var rank := 0
	for coefficient in uefa.get("coefficients", []):
		if str((coefficient as Dictionary).get("association", "")) == country:
			rank = _int((coefficient as Dictionary).get("rank"), 0)
			break
	if rank <= 0:
		return {}
	for band in uefa.get("bands", []):
		if rank < _int(band.get("rank_from"), 0) or rank > _int(band.get("rank_to"), 0):
			continue
		var counts := {}
		for competition in ["CL", "EL", "UCOL"]:
			var slots: Array = band.get(competition, [])
			if not slots.is_empty():
				counts[competition] = slots.size()
		if (uefa.get("eps", []) as Array).has(country):
			counts["CL"] = int(counts.get("CL", 0)) + 1
		return counts
	return {}


static func _europe_text(counts: Dictionary) -> String:
	var parts: Array = []
	for competition in ["CL", "EL", "UCOL"]:
		if int(counts.get(competition, 0)) > 0:
			parts.append("%d %s" % [int(counts[competition]),
				_competition_name(competition)])
	if parts.is_empty():
		return ""
	return "Europe: " + " · ".join(parts)


static func _competition_name(competition: String) -> String:
	return str({
		"CL": "Champions League", "EL": "Europa League",
		"UCOL": "Conference League",
	}.get(competition, competition))


static func _cup_lines(record: Dictionary) -> Array:
	var lines: Array = [UiText.t("tournament.cup.knockout")]
	var two_legged: Array = record.get("two_legged", [])
	if not two_legged.is_empty():
		var names: Array = []
		for name in two_legged:
			names.append(_round_name(str(name)))
		lines.append(UiText.t("tournament.clause.two_legged_rounds",
			{"rounds": _join_names(names)}))
	if _int(record.get("final_legs"), 1) > 1:
		lines.append(UiText.t("tournament.clause.two_legged_final"))
	var field := _int(record.get("field_size"), 0)
	if field > 0:
		lines.append("%d clubs" % field)
	var window := _window(record.get("start_md", ""), record.get("end_md", ""))
	if not window.is_empty():
		lines.append(window)
	return lines


static func _join_names(names: Array) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return str(names[0])
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)),
		str(names[names.size() - 1])]


static func _round_name(name: String) -> String:
	# The records use both long and short spellings ("semi", "semi-final").
	var text := name.replace("_", " ").strip_edges().to_lower()
	match text:
		"semi", "semi-final", "semi-finals", "sf":
			return "semi-finals"
		"qf", "quarter-final", "quarter-finals":
			return "quarter-finals"
		"r16", "round of 16":
			return "round of 16"
		"r32", "round of 32":
			return "round of 32"
		"final":
			return "final"
	return text


static func _super_cup_format(record: Dictionary) -> String:
	return "super_cup.mini" if _int(record.get("teams"), 2) > 2 \
		else "super_cup.match"


static func _super_cup_lines(record: Dictionary) -> Array:
	var lines: Array = [UiText.t("tournament." + _super_cup_format(record))]
	if bool(record.get("neutral", false)):
		lines.append(UiText.t("tournament.clause.neutral_venue"))
	if int(record.get("final_legs", 1)) > 1:
		lines.append(UiText.t("tournament.clause.two_legged_final"))
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
	var format: Dictionary = CareerConfederation.FORMATS.get(
		"%s:%s" % [confederation, competition_id], {})
	if format.is_empty():
		return _uefa_continental(competition_id, label)
	label = str(format.get("label", competition_id))
	return _continental_format(competition_id, label, format)


static func _uefa_continental(competition_id: String, label: String) -> Dictionary:
	# The UEFA competitions live in the access lists, not in FORMATS.
	var lines: Array = []
	var format_key := ""
	var sizes: Dictionary = {}
	var uefa = CareerBerths.access().get("uefa", {})
	if uefa is Dictionary:
		sizes = uefa.get("entry_round_sizes", {})
	var entry: Dictionary = sizes.get(competition_id, {})
	if not entry.is_empty():
		format_key = "continental.league_phase"
		lines.append(UiText.t("tournament." + format_key, {
			"clubs": _int(entry.get("league_phase"), 36),
			"rounds": _int(CareerEurope.ROUNDS.get(competition_id), 8),
			"direct": LEAGUE_PHASE_DIRECT,
			"playoff": LEAGUE_PHASE_PLAYOFF,
		}))
		var window := _window(entry.get("start_md", "09-15"),
			entry.get("end_md", "05-30"))
		if not window.is_empty():
			lines.append(window)
	return {"competition": competition_id, "kind": "continental",
		"format": format_key, "label": label, "lines": lines}


static func _continental_format(competition_id: String, label: String,
		format: Dictionary) -> Dictionary:
	var rounds: Array = format.get("rounds", [])
	var groups: Dictionary = {}
	var neutral := false
	var final_legs := 0
	for spec in rounds:
		var round_spec: Dictionary = spec
		if round_spec.get("groups") is Dictionary:
			groups = round_spec["groups"]
		if str(round_spec.get("name", "")) == "final":
			final_legs = _int(round_spec.get("legs"), 1)
			neutral = bool(round_spec.get("neutral", false))
	var lines: Array = []
	var format_key := ""
	if not groups.is_empty():
		format_key = "continental.groups"
		lines.append(UiText.t("tournament." + format_key, {
			"groups": _int(groups.get("count"), 0),
			"size": _int(groups.get("size"), 0),
			"advance": _int(groups.get("advance"), 0),
		}))
	elif rounds.size() == 1 and final_legs > 1:
		# A single two-legged final, e.g. the Recopa Sudamericana.
		format_key = "cup.knockout"
		lines.append(UiText.t("tournament." + format_key))
		lines.append(UiText.t("tournament.clause.two_legged_final"))
	else:
		format_key = "continental.knockout"
		lines.append(UiText.t("tournament." + format_key))
	if neutral:
		lines.append(UiText.t("tournament.clause.neutral_venue"))
	var window := _window(_first_window(format, 0), _first_window(format, -1))
	if not window.is_empty():
		lines.append(window)
	return {"competition": competition_id, "kind": "continental",
		"format": format_key, "label": label, "lines": lines}


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
