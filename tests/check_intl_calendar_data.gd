extends SceneTree
# Headless check for the shipped international calendar: the asset loads, every
# rule is well formed, explicit editions and the recurring fallback block the
# right dates, and a release-only event never blocks a fixture.
#
# Run:  godot --headless --path . -s res://tests/check_intl_calendar_data.gd

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
	var data := IntlCalendar.load_all()
	_check(not data.is_empty(), "the calendar loads: " + IntlCalendar.last_error())
	var rules := IntlCalendar.rules()
	_check(rules.size() >= 20, "the asset has the researched rules: %d" % rules.size())

	var bad: Array[String] = []
	for rule in rules:
		if not (rule is Dictionary):
			bad.append("not a dictionary")
			continue
		if not rule.has("applies_to"):
			bad.append("%s: no applies_to" % rule.get("label", "?"))
		if not rule.has("pauses_club_football"):
			bad.append("%s: no pauses flag" % rule.get("label", "?"))
		var explicit: bool = rule.has("start") or rule.has("end")
		if explicit:
			if not (rule.has("start") and rule.has("end")):
				bad.append("%s: half an explicit edition" % rule.get("label", "?"))
		elif not (rule.has("start_md") and rule.has("end_md")
				and rule.has("every_years") and rule.has("anchor_year")):
			bad.append("%s: incomplete recurring rule" % rule.get("label", "?"))
	_check(bad.is_empty(), "every rule is well formed: " + str(bad))

	_check(IntlCalendar.is_blocked(rules, "2026-09-25", "world"),
		"the September-October window blocks a club fixture")
	_check(not IntlCalendar.is_blocked(rules, "2026-09-05", "world"),
		"a date between windows is free")
	_check(IntlCalendar.is_blocked(rules, "2027-03-25", "world"),
		"the 2027 March window is exact, not a 2026 copy")
	_check(IntlCalendar.is_blocked(rules, "2029-03-25", "world"),
		"the recurring fallback starts after the researched years")
	_check(IntlCalendar.is_blocked(rules, "2030-06-15", "world"),
		"the World Cup repeats every four years")
	_check(not IntlCalendar.is_blocked(rules, "2028-07-15", "world"),
		"a release-only event does not block a fixture")
	_check(IntlCalendar.is_blocked(rules, "2028-06-15", "UEFA"),
		"a continental rule applies to its confederation")
	_check(not IntlCalendar.is_blocked(rules, "2028-06-15", "world"),
		"a continental rule does not block the world scope")

	print("== check_intl_calendar_data: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
