extends SceneTree
# Headless check for the thin LAN client's substitution banner builder: the
# original client applies a snapshot substitution without keeping a notice
# book, so the shell derives "X off, Y on" from the active-roster delta.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_substitution_notices.gd

const SubNotices := preload("res://scripts/match/substitution_notices.gd")

var failures: Array[String] = []


func _init() -> void:
	var entries := [
		{"id": 10, "name": "Smith"},
		{"id": 11, "name": "Jones"},
		{"id": -1, "name": ""},
	]
	var names: Dictionary = SubNotices.active_names(entries)
	_check(names.get(10, "") == "Smith" and names.get(11, "") == "Jones",
		"active_names maps ids to the player names")
	_check(names.has(-1), "officials without names still get a key")

	var changed: Dictionary = SubNotices.changed_ids(
		{10: "Smith", 11: "Jones"}, {10: "Smith", 12: "Brown"})
	_check(changed.get("out", []) == [11], "changed_ids reports the outgoing id")
	_check(changed.get("in", []) == [12], "changed_ids reports the incoming id")

	var lines: Array = SubNotices.build_lines(
		{10: "Smith", 11: "Jones"}, {10: "Smith", 12: "Brown"})
	_check(lines == ["Jones off, Brown on"],
		"one swap builds the original banner text")

	_check(SubNotices.build_lines({10: "Smith"}, {10: "Smith"}).is_empty(),
		"an unchanged roster builds no banner")
	_check(SubNotices.build_lines({}, {10: "Smith"}).is_empty(),
		"an incoming player without an outgoing pair builds no banner")
	_check(SubNotices.build_lines({10: "Smith"}, {}).is_empty(),
		"an outgoing player without an incoming pair builds no banner")

	if failures.is_empty():
		print("== check_gpf_substitution_notices: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_gpf_substitution_notices: FAIL ==")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)
