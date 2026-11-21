extends SceneTree
# Headless check for the international calendar rules: annual FIFA windows,
# multi-year tournaments and the scope they apply to. Rules are passed in, so
# the recurrence math is tested without the shipped asset.
#
# Run:  godot --headless --path . -s res://tests/check_intl_calendar.gd

var failures: Array[String] = []

const RULES := [
	{
		"kind": "window", "label": "March", "start_md": "03-23", "end_md": "03-31",
		"every_years": 1, "anchor_year": 2026, "applies_to": "world",
	},
	{
		"kind": "tournament", "label": "World Cup 2026", "start_md": "06-11",
		"end_md": "07-19", "every_years": 4, "anchor_year": 2026,
		"applies_to": "world",
	},
	{
		"kind": "tournament", "label": "Euro 2028", "start_md": "06-09",
		"end_md": "07-09", "every_years": 4, "anchor_year": 2028,
		"applies_to": "uefa",
	},
]


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	_check(IntlCalendar.is_blocked(RULES, "2026-06-15", "uefa"),
		"the 2026 World Cup blocks a UEFA league")
	_check(not IntlCalendar.is_blocked(RULES, "2026-07-20", "uefa"),
		"the day after the final is free")
	_check(IntlCalendar.is_blocked(RULES, "2027-03-25", "caf"),
		"the March window repeats every year")
	_check(not IntlCalendar.is_blocked(RULES, "2027-06-15", "uefa"),
		"the World Cup is quadrennial, not annual")
	_check(IntlCalendar.is_blocked(RULES, "2028-06-15", "uefa"),
		"Euro blocks its confederation")
	_check(not IntlCalendar.is_blocked(RULES, "2028-06-15", "caf"),
		"Euro does not block another confederation")

	print("== check_intl_calendar: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
