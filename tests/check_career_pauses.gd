extends SceneTree
# Headless check for the FIFA blackouts in a real career: the fixtures of a
# season never fall inside an international window or a World Cup, while the
# season still starts and ends on the league's own window.
#
# Run:  godot --headless --path . -s res://tests/check_career_pauses.gd

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
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, 131, "Pause Manager", 189, 42)
	_check(career != null, "career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var rules := IntlCalendar.rules()
	_check(not rules.is_empty(), "the calendar asset is loaded")
	var blocked: Array = []
	var first := ""
	var last := ""
	for fixture in career.schedule:
		var date := str(fixture.get("date", ""))
		if first.is_empty() or date < first:
			first = date
		if last.is_empty() or date > last:
			last = date
		if IntlCalendar.is_blocked(rules, date, "world"):
			blocked.append("%s %s" % [fixture.get("id", ""), date])
	_check(blocked.is_empty(), "no fixture falls in a FIFA window: " + str(blocked))
	_check(first == "2026-08-15", "the first round is the window start")
	_check(last == "2027-05-30", "the last round is the window end")

	var club_dates := {}
	for fixture in career.schedule:
		var date := str(fixture.get("date", ""))
		for key in ["home", "away"]:
			var club_id := str(fixture.get(key, ""))
			club_dates[club_id] = club_dates.get(club_id, []) + [date]
	var too_close: Array = []
	for club_id in club_dates:
		var dates: Array = club_dates[club_id]
		dates.sort()
		for index in range(1, dates.size()):
			if CareerSeason.days_between(str(dates[index - 1]), str(dates[index])) < 3:
				too_close.append("%s %s..%s" % [club_id, dates[index - 1], dates[index]])
	_check(too_close.is_empty(), "no club plays twice within two days: " + str(too_close))

	career.data.erase("schedule")
	CareerFactory.ensure_schedule(career, career.league_club_ids)
	_check(not career.schedule.is_empty(), "the schedule is rebuilt when missing")
	var repaired: Array = []
	for fixture in career.schedule:
		if IntlCalendar.is_blocked(rules, str(fixture.get("date", "")), "world"):
			repaired.append(str(fixture.get("date", "")))
	_check(repaired.is_empty(), "the repaired schedule avoids the pauses: " + str(repaired))

	_finish()


func _finish() -> void:
	print("== check_career_pauses: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
