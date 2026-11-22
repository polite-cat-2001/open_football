extends SceneTree
# Headless check for the club coefficient snapshot: the file loads, the known
# clubs carry the published totals, an unknown club is zero, and the sort is by
# coefficient descending.
#
# Run:  godot --headless --path . -s res://tests/check_club_coefficients.gd

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
	var data := CareerCoefficients.data()
	_check(not data.is_empty(), "the coefficient snapshot loads")
	_check(CareerCoefficients.season() == "2026-27",
		"the snapshot is for 2026-27")
	var clubs = data.get("clubs", {})
	_check(clubs is Dictionary and clubs.size() >= 300,
		"the snapshot has the club table: %d" % clubs.size())
	_check(is_equal_approx(CareerCoefficients.coefficient("2864"), 147.5),
		"Bayern Munich carries the published total")
	_check(is_equal_approx(CareerCoefficients.coefficient("1864"), 113.25),
		"Barcelona carries the published total")
	_check(is_equal_approx(CareerCoefficients.coefficient("999999999"), 0.0),
		"an unknown club starts at zero")
	var sorted := CareerCoefficients.sorted_clubs(["1864", "2864", "999999999"])
	_check(sorted == ["2864", "1864", "999999999"],
		"the sort puts the higher coefficient first")

	print("== check_club_coefficients: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
