extends SceneTree
# Headless check for the shipped league regulations: every league record is
# well formed, the recurring window months become real dates (including the
# windows that cross New Year), and the career helpers pick the right season.
#
# Run:  godot --headless --path . -s res://tests/check_league_regulations.gd

const PHASES := ["single", "split", "apertura_clausura", "other"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	var data := LeagueRegulations.load_all()
	_check(not data.is_empty(), "the regulations load: " + LeagueRegulations.last_error())
	var leagues: Dictionary = data.get("leagues", {})
	_check(leagues.size() >= 106, "every country has a league record")
	_check(LeagueRegulations.record("GB1").get("start_md") == "08-21", "England starts on 21 August")
	_check(LeagueRegulations.record("BRA1").get("start_md") == "01-28", "Brazil starts on 28 January")
	_check(LeagueRegulations.record("GB1").get("phases") == "single", "England has no split")
	_check(LeagueRegulations.record("MEXA").get("phases") == "apertura_clausura", "Mexico has two phases")
	_check(LeagueRegulations.relegation_slots("GB1") == 3, "England relegates three")
	_check(LeagueRegulations.relegation_slots("MLS1") == 0, "MLS relegates nobody")
	_check(LeagueRegulations.relegation_slots("GI1") == -1, "Gibraltar keeps the count unknown")
	_check(LeagueRegulations.tiebreak("GB1").has("goal_difference"), "England breaks ties on goal difference")
	_check(LeagueRegulations.record("GB1").get("transfer_windows", []).size() == 2,
		"England has two transfer windows")
	_check(LeagueRegulations.record("JPL1").get("filled") == "start+end",
		"a league without dates is filled from the class default")

	var england := LeagueRegulations.window("GB1", 2026)
	_check(england.get("start") == "2026-08-21" and england.get("end") == "2027-05-30",
		"an autumn window crosses the new year")
	var brazil := LeagueRegulations.window("BRA1", 2026)
	_check(brazil.get("start") == "2026-01-28" and brazil.get("end") == "2026-12-02",
		"a calendar window stays in one year")

	var fresh_england := LeagueRegulations.first_window_on_or_after("GB1", "2026-07-01")
	_check(fresh_england.get("start") == "2026-08-21", "a July career starts with this autumn's window")
	var fresh_brazil := LeagueRegulations.first_window_on_or_after("BRA1", "2026-07-01")
	_check(fresh_brazil.get("start") == "2027-01-28",
		"a July career in Brazil starts with next year's window")
	_check(LeagueRegulations.next_window_start("GB1", "2026-08-21") == "2027-08-21",
		"the next season keeps the day and month")
	_check(LeagueRegulations.season_end("GB1", "2026-08-21") == "2027-08-20",
		"the season year ends the day before the next window")

	var bad_phase: Array = []
	var bad_months: Array = []
	var empty_source: Array = []
	var unknown_fill: Array = []
	for league_id in leagues:
		var entry: Dictionary = leagues[league_id]
		if not PHASES.has(str(entry.get("phases", ""))):
			bad_phase.append(league_id)
		var start_md := str(entry.get("start_md", ""))
		var end_md := str(entry.get("end_md", ""))
		if not _is_md(start_md):
			bad_months.append("%s:start" % league_id)
		if not _is_md(end_md) or end_md == start_md:
			bad_months.append("%s:end" % league_id)
		if not str(entry.get("source", "")).begins_with("http"):
			empty_source.append(league_id)
		if not str(entry.get("filled", "")).is_empty() \
				and str(entry.get("filled", "")) not in ["start", "end", "start+end"]:
			unknown_fill.append(league_id)
	_check(bad_phase.is_empty(), "every phase is known: " + str(bad_phase))
	_check(bad_months.is_empty(), "every window has valid months: " + str(bad_months))
	_check(empty_source.is_empty(), "every record cites a source: " + str(empty_source))
	_check(unknown_fill.is_empty(), "fallback marks are known: " + str(unknown_fill))

	var splits := 0
	for league_id in leagues:
		if str(leagues[league_id].get("phases", "")) == "split":
			splits += 1
	_check(splits >= 20, "the split leagues made it into the data: %d" % splits)

	var empty := LeagueRegulations.window("XXX9", 2026)
	_check(empty.is_empty(), "an unknown league has no window")

	print("== check_league_regulations: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _is_md(value: String) -> bool:
	if value.length() != 5 or value[2] != "-":
		return false
	var month := int(value.substr(0, 2))
	var day := int(value.substr(3, 2))
	return month >= 1 and month <= 12 and day >= 1 and day <= 31
