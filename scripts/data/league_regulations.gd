class_name LeagueRegulations
extends RefCounted
# Season regulation per league: window months, phases, tiebreak, relegation
# spots. Shipped with the game as JSON (assets/data/league_regulations.json)
# and keyed by the database league id. Months are MM-DD and recur every year,
# so a window crossing the new year is just `end_md` < `start_md`.

const PATH := "res://assets/data/league_regulations.json"
const AUTUMN := "autumn"
const CALENDAR := "calendar"
const SHORT_WINDOW_DAYS := 150

static var _data: Dictionary = {}
static var _error := ""


static func load_all() -> Dictionary:
	if not _data.is_empty():
		return _data
	_error = ""
	if not FileAccess.file_exists(PATH):
		_error = "league regulations missing: " + PATH
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_error = "cannot open " + PATH
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_error = "league regulations are not a JSON object"
		return {}
	_data = parsed
	return _data


static func last_error() -> String:
	return _error


static func record(league_id: String) -> Dictionary:
	var data := load_all()
	var leagues = data.get("leagues", {})
	if not (leagues is Dictionary):
		return {}
	var value = leagues.get(str(league_id), {})
	return value if value is Dictionary else {}


static func defaults() -> Dictionary:
	var data := load_all()
	var value = data.get("_defaults", {})
	return value if value is Dictionary else {}


static func window(league_id: String, year: int) -> Dictionary:
	# Real dates for one season: the end year follows the start when the
	# window crosses New Year (August -> May).
	var entry := record(league_id)
	if entry.is_empty():
		return {}
	var start_md := str(entry.get("start_md", ""))
	var end_md := str(entry.get("end_md", ""))
	if not _is_md(start_md) or not _is_md(end_md):
		return {}
	var end_year := year if end_md >= start_md else year + 1
	return {
		"start": "%04d-%s" % [year, start_md],
		"end": "%04d-%s" % [end_year, end_md],
	}


static func window_for_season(league_id: String, season_start: String) -> Dictionary:
	var parts := CareerSearch.date_parts(str(season_start))
	if parts.is_empty():
		return {}
	return window(league_id, int(parts[0]))


static func first_window_on_or_after(league_id: String, date: String) -> Dictionary:
	# A career starts with a fresh season: if this year's window already began
	# before the career date, the first season is next year's.
	var parts := CareerSearch.date_parts(str(date))
	if parts.is_empty():
		return {}
	var year := int(parts[0])
	var current := window(league_id, year)
	if current.is_empty():
		return {}
	if str(current["start"]) < str(date):
		return window(league_id, year + 1)
	return current


static func next_window_start(league_id: String, season_start: String) -> String:
	var entry := record(league_id)
	var start_md := str(entry.get("start_md", ""))
	var parts := CareerSearch.date_parts(str(season_start))
	if start_md.is_empty() or parts.is_empty():
		return str(season_start)
	return "%04d-%s" % [int(parts[0]) + 1, start_md]


static func season_end(league_id: String, season_start: String) -> String:
	# The season year ends the day before the next boundary, which is the
	# off-season the hub reels through before the review.
	var parts := CareerSearch.date_parts(str(season_start))
	if parts.is_empty():
		return str(season_start)
	var next_start := boundary(league_id, int(parts[0]) + 1)
	if next_start.is_empty():
		return str(season_start)
	return CareerSeason.add_days(next_start, -1)


static func boundary(league_id: String, year: int) -> String:
	# The boundary before the season that starts in `year`: the midpoint of the
	# gap between the previous season's last day and this season's first day.
	# Rounded down, so the career gets the earlier day of an odd gap.
	var current := window(league_id, year)
	var previous := window(league_id, year - 1)
	if current.is_empty() or previous.is_empty():
		return ""
	var prev_end := str(previous["end"])
	var start := str(current["start"])
	# A window shorter than five months is one phase of a longer championship,
	# not a season: taking the midpoint of its gap would put the boundary in the
	# middle of the other phase. Use the phase start until a format is known.
	var length := CareerSeason.days_between(start, str(current["end"]))
	if length < SHORT_WINDOW_DAYS:
		return start
	var gap := CareerSeason.days_between(prev_end, start)
	if gap <= 0:
		return ""
	return CareerSeason.add_days(prev_end, gap / 2)


static func nearest_boundary(league_id: String, date: String) -> String:
	# The career epoch: the boundary closest to a fixed date, in either
	# direction. A tie goes to the upcoming boundary.
	var parts := CareerSearch.date_parts(str(date))
	if parts.is_empty():
		return ""
	var year := int(parts[0])
	var best := ""
	var best_distance := -1
	for candidate in range(year - 1, year + 2):
		var value := boundary(league_id, candidate)
		if value.is_empty():
			continue
		var distance := absi(CareerSeason.days_between(value, date))
		if best_distance < 0 or distance < best_distance \
				or (distance == best_distance and value > best):
			best = value
			best_distance = distance
	return best


static func phase(league_id: String) -> String:
	return str(record(league_id).get("phases", "single"))


static func relegation_slots(league_id: String) -> int:
	var slots = record(league_id).get("relegation", {}).get("slots")
	return -1 if slots == null else int(slots)


static func tiebreak(league_id: String) -> Array:
	var value = record(league_id).get("tiebreak", [])
	return value if value is Array else []


static func _is_md(value: String) -> bool:
	if value.length() != 5 or value[2] != "-":
		return false
	var month := int(value.substr(0, 2))
	var day := int(value.substr(3, 2))
	return month >= 1 and month <= 12 and day >= 1 and day <= 31
