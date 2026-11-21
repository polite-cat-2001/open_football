extends SceneTree
# Headless check for the shared date allocator: rounds stay inside the window,
# skip an international pause and dates already taken by another competition,
# and the stage year rolls over when the month is before the season start.
#
# Run:  godot --headless --path . -s res://tests/check_career_calendar.gd

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
	var pause := [{
		"kind": "tournament", "label": "Test pause", "start_md": "08-20",
		"end_md": "08-30", "every_years": 1, "anchor_year": 2026,
		"applies_to": "world",
	}]
	var dates := CareerCalendar.round_dates("2026-08-01", "2026-09-30", 6,
		pause, "uefa", {"2026-09-10": true})
	_check(dates.size() == 6, "six rounds are allocated")
	var bad: Array = []
	var previous := ""
	for date in dates:
		if date >= "2026-08-20" and date <= "2026-08-30":
			bad.append(date)
		if date == "2026-09-10":
			bad.append(date)
		if previous != "" and date <= previous:
			bad.append("order:" + str(date))
		previous = date
	_check(bad.is_empty(), "no round in the pause or the busy date: " + str(bad))
	_check(str(dates[0]) == "2026-08-01", "the first round is the window start")
	_check(str(dates[-1]) == "2026-09-30", "the last round is the window end")

	_check(CareerCalendar.stage_date(2026, "08-01", "01-22") == "2026-08-01",
		"an August stage stays in the season year")
	_check(CareerCalendar.stage_date(2026, "01-22", "07-24") == "2027-01-22",
		"a January stage rolls to the next year")

	print("== check_career_calendar: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
