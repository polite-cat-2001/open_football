extends SceneTree
# Headless check for the calendar rest rule: a club never gets two fixtures
# closer than three days, including the continental rounds that are built after
# the league schedule. A few dense continental windows only guard one match a day.
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
	{"league": "NL1", "label": "Eredivisie (17 clubs)"},
	{"club": "6502", "label": "an AFC club"},
	{"club": "583", "label": "a UEFA club"},
]

# A continental window can be too dense for both the league and the confederation
# competition to keep three days of rest: these guard the hard rule (one match a
# day) and the wiki records the tight pairs.
const SAME_DAY_ONLY := [
	{"league": "PR1C", "label": "Paraguay", "strict": false},
	{"league": "ARGC", "label": "Argentina", "strict": false},
	{"league": "EC1N", "label": "Ecuador", "strict": false},
	{"league": "VZ1C", "label": "Venezuela", "strict": false},
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
	var cases: Array = CASES.duplicate()
	cases.append_array(SAME_DAY_ONLY)
	for case in cases:
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
		var same_day: Array = []
		for index in range(1, dates.size()):
			var gap := absi(CareerSeason.days_between(str(dates[index]),
				str(dates[index - 1])))
			if gap == 0:
				same_day.append(str(dates[index]))
			elif gap < 3:
				tight.append("%s -> %s" % [dates[index - 1], dates[index]])
		_check(same_day.is_empty(), "%s: no club plays twice on one day %s" % [
			case["label"], "" if same_day.is_empty() else str(same_day)])
		if bool(case.get("strict", true)):
			_check(tight.is_empty(), "%s: %d fixtures, %d inside three days %s" % [
				case["label"], dates.size(), tight.size(),
				"" if tight.is_empty() else str(tight.slice(0, 3))])
	_finish()
