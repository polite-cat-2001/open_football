class_name CareerHubModel
extends RefCounted
# Read model for the career hub, ported from the prototype's Hub.svelte data
# (centre tiles, overview window, tournament overlay). Pure: takes the career
# snapshot and returns plain dictionaries, so headless tests can snapshot it.

const TABS: Array[String] = ["CENTRE", "SQUAD", "TRANSFERS", "SCOUTING"]
const TAB_IDS: Array[String] = ["centre", "squad", "transfers", "scouting"]
const OVERVIEW_SECTIONS: Array[String] = [
	"TABLE", "SCORERS", "FIXTURES", "TOP TRANSFERS", "NEW TRANSFERS",
]
const TABLE_WINDOW := 6
const WEEKDAYS := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


static func next_tile(snapshot: Dictionary) -> Dictionary:
	var club: Dictionary = snapshot.get("club", {})
	var season: Dictionary = snapshot.get("season", {})
	var today := str(snapshot.get("date", ""))
	var next = season.get("next")
	if not (next is Dictionary):
		var own := own_row(snapshot)
		var meta := "SEASON COMPLETE"
		if not own.is_empty():
			meta = "%d%s · %d PTS · %d PLAYED" % [
				int(own.get("position", 0)), _ordinal(int(own.get("position", 0))),
				int(own.get("points", 0)), int(own.get("played", 0)),
			]
		return {
			"match_day": false,
			"eyebrow": "SEASON",
			"title": "SEASON COMPLETE",
			"month": month_label(today),
			"home_name": "", "away_name": "",
			"home_logo": "", "away_logo": "",
			"meta": meta,
			"form": season.get("form", []),
			"days": [],
			"season_complete": true,
		}

	var match_date := str(next.get("date", today))
	var home := bool(next.get("home", true))
	var opponent: Dictionary = next.get("opponent", {})
	var club_name := str(club.get("name", ""))
	var opponent_name := str(opponent.get("name", ""))
	return {
		"match_day": today >= match_date,
		"eyebrow": "MATCH" if today >= match_date else "CALENDAR",
		"title": "MATCH DAY" if today >= match_date else "NEXT",
		"month": month_label(match_date),
		"home_name": club_name if home else opponent_name,
		"away_name": opponent_name if home else club_name,
		"home_logo": str(club.get("logo", "")) if home else str(opponent.get("logo", "")),
		"away_logo": str(opponent.get("logo", "")) if home else str(club.get("logo", "")),
		"meta": "%s · %s · ROUND %d · %s" % [
			season_label(today), str(club.get("league_name", "")).to_upper(),
			int(next.get("round", 0)), "HOME" if home else "AWAY",
		],
		"form": season.get("form", []),
		"days": week_strip(today, match_date),
		"season_complete": false,
	}


static func table_tile(snapshot: Dictionary) -> Dictionary:
	var club: Dictionary = snapshot.get("club", {})
	var season: Dictionary = snapshot.get("season", {})
	var standings: Array = season.get("standings", [])
	var rows := table_window(standings, str(club.get("id", "")), TABLE_WINDOW)
	for row in rows:
		row["own"] = str(row.get("club_id", "")) == str(club.get("id", ""))
	return {
		"title": OVERVIEW_SECTIONS[0],
		"competition": str(club.get("league_name", "")),
		"round": _int(season.get("played_round"), 0),
		"rows": rows,
		"sections": OVERVIEW_SECTIONS,
	}


static func overlay(snapshot: Dictionary) -> Dictionary:
	var club: Dictionary = snapshot.get("club", {})
	var season: Dictionary = snapshot.get("season", {})
	var standings: Array = season.get("standings", [])
	var rows: Array = []
	for row in standings:
		var copy: Dictionary = row.duplicate(true)
		copy["own"] = str(row.get("club_id", "")) == str(club.get("id", ""))
		rows.append(copy)
	return {
		"competition": str(club.get("league_name", "")),
		"round": _int(season.get("played_round"), 0),
		"standings": rows,
		"promotion_places": int(season.get("promotion_places", 0)),
		"relegation_places": int(season.get("relegation_places", 0)),
	}


static func own_row(snapshot: Dictionary) -> Dictionary:
	var club: Dictionary = snapshot.get("club", {})
	var season: Dictionary = snapshot.get("season", {})
	for row in season.get("standings", []):
		if str(row.get("club_id", "")) == str(club.get("id", "")):
			return row
	return {}


static func table_window(rows: Array, club_id: String, size := TABLE_WINDOW) -> Array:
	if rows.is_empty() or size <= 0:
		return []
	if rows.size() <= size:
		return rows.duplicate(true)
	var own_index := -1
	for index in range(rows.size()):
		if str(rows[index].get("club_id", "")) == club_id:
			own_index = index
			break
	if own_index < 0:
		return rows.slice(0, size).duplicate(true)
	var offset := int(size * 0.5)
	var start := clampi(own_index - offset, 0, rows.size() - size)
	return rows.slice(start, start + size).duplicate(true)


static func week_strip(today: String, match_date: String, count := 7) -> Array:
	var days: Array = []
	if today.length() < 10:
		return days
	var unix := Time.get_unix_time_from_datetime_string(today + "T00:00:00")
	for index in range(count):
		var key := Time.get_datetime_string_from_unix_time(
			int(unix) + index * 86400, false).substr(0, 10)
		days.append({
			"key": key,
			"weekday": weekday(key),
			"day": int(key.substr(8, 2)),
			"today": index == 0,
			"match": key == match_date,
		})
	return days


static func season_label(date: String) -> String:
	if date.length() < 7:
		return date
	var year := int(date.substr(0, 4))
	var month := int(date.substr(5, 2))
	var start := year if month >= 7 else year - 1
	return "%d/%02d" % [start, (start + 1) % 100]


static func month_label(date: String) -> String:
	if date.length() < 7:
		return date
	return "%s %s" % [MONTHS[int(date.substr(5, 2)) - 1], date.substr(0, 4)]


static func short_date(date: String) -> String:
	if date.length() < 10:
		return date
	return "%d %s" % [int(date.substr(8, 2)), MONTHS[int(date.substr(5, 2)) - 1]]


static func weekday(date: String) -> String:
	if date.length() < 10:
		return ""
	var unix := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	var parts := Time.get_datetime_dict_from_unix_time(int(unix))
	return WEEKDAYS[int(parts.get("weekday", 0))]


static func _int(value, fallback: int) -> int:
	return fallback if value == null else int(value)


static func _ordinal(value: int) -> String:
	if value % 100 >= 11 and value % 100 <= 13:
		return "TH"
	match value % 10:
		1: return "ST"
		2: return "ND"
		3: return "RD"
	return "TH"
