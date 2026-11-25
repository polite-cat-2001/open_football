extends SceneTree
# Headless check for the calendar rest rule: a club never gets two fixtures
# closer than three days, including the continental rounds that are built after
# the league schedule.
#
# Run:  godot --headless --path . -s res://tests/check_calendar_rest.gd

const CASES := [
	{"league": "GB1", "label": "England"},
	{"league": "GB2", "label": "Championship"},
	{"league": "ES2", "label": "LaLiga 2"},
	{"league": "BRA1", "label": "Brazil"},
	{"league": "JAP1", "label": "Japan"},
	{"league": "SA1", "label": "Saudi Arabia"},
	{"league": "MEXA", "label": "Liga MX Apertura"},
	{"league": "EGY1", "label": "Egypt"},
	{"club": "6502", "label": "an AFC club"},
	{"club": "583", "label": "a UEFA club"},
]

var failures: Array[String] = []
var _catalog: TeamCatalog


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	print("== check_calendar_rest: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _club_of(case: Dictionary) -> int:
	if case.has("club"):
		return int(case["club"])
	var teams: Array = _catalog.all_teams_for_league(str(case["league"]))
	if teams.is_empty():
		return 0
	return int(str((teams[0] as Dictionary).get("id", "0")))


func _run() -> void:
	_catalog = TeamCatalog.new()
	_check(_catalog.load_data_root(), "catalog opens the database: " + _catalog.error)
	if not _catalog.is_loaded():
		_finish()
		return
	for case in CASES:
		var club_id := _club_of(case)
		if club_id <= 0:
			_check(false, "%s: no club to test" % case["label"])
			continue
		var career := CareerFactory.create(_catalog, club_id, "Rest", 189, 31)
		if career == null:
			_check(false, "%s: %s" % [case["label"], CareerFactory.last_error])
			continue
		var dates: Array = []
		for fixture in career.schedule:
			if str(fixture.get("home", "")) != career.club_id \
					and str(fixture.get("away", "")) != career.club_id:
				continue
			dates.append(str(fixture.get("date", "")))
		dates.sort()
		var tight: Array = []
		for index in range(1, dates.size()):
			var gap := absi(CareerSeason.days_between(str(dates[index]),
				str(dates[index - 1])))
			if gap < 3:
				tight.append("%s -> %s" % [dates[index - 1], dates[index]])
		_check(tight.is_empty(), "%s: %d fixtures, %d inside three days %s" % [
			case["label"], dates.size(), tight.size(),
			"" if tight.is_empty() else str(tight.slice(0, 3))])
	_finish()
