extends SceneTree
# Headless check for the career fixture allocator: a double round-robin that
# starts and ends inside the window, keeps every pair home and away, leaves a
# rest gap between rounds and never puts a fixture inside an international
# blackout.
#
# Run:  godot --headless --path . -s res://tests/check_career_schedule.gd

const CLUBS := ["1", "2", "3", "4"]
const START := "2026-08-01"
const END := "2026-09-30"
const PAUSE := [
	{
		"kind": "tournament", "label": "Test pause", "start_md": "08-20",
		"end_md": "08-30", "every_years": 1, "anchor_year": 2026,
		"applies_to": "world",
	},
]

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
	var schedule := CareerFactory.build_schedule(CLUBS, START, END, PAUSE, "uefa")
	_check(schedule.size() == 12, "four clubs play a double round-robin (12 fixtures)")

	var first := ""
	var last := ""
	var keys := {}
	var club_dates := {}
	for fixture in schedule:
		var date := str(fixture.get("date", ""))
		var home := str(fixture.get("home", ""))
		var away := str(fixture.get("away", ""))
		if first.is_empty() or date < first:
			first = date
		if last.is_empty() or date > last:
			last = date
		keys["%s>%s" % [home, away]] = true
		club_dates[home] = club_dates.get(home, []) + [date]
		club_dates[away] = club_dates.get(away, []) + [date]

	_check(first == START, "the first round is on the window start")
	_check(last == END, "the last round is on the window end")
	_check(keys.size() == 12, "every ordered pair appears once")
	_check(keys.has("1>2") and keys.has("2>1"), "each pair is played home and away")

	var in_pause: Array = []
	for fixture in schedule:
		var date := str(fixture.get("date", ""))
		if date >= "2026-08-20" and date <= "2026-08-30":
			in_pause.append(date)
	_check(in_pause.is_empty(), "no fixture falls inside the pause: " + str(in_pause))

	var too_close: Array = []
	for club_id in club_dates:
		var dates: Array = club_dates[club_id]
		dates.sort()
		for index in range(1, dates.size()):
			if CareerSeason.days_between(str(dates[index - 1]), str(dates[index])) < 3:
				too_close.append("%s %s..%s" % [club_id, dates[index - 1], dates[index]])
	_check(too_close.is_empty(), "a club never plays twice within two days: " + str(too_close))

	print("== check_career_schedule: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
