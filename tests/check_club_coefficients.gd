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
	_check(is_equal_approx(CareerCoefficients.coefficient("27"), 147.5),
		"Bayern Munich carries the published total")
	_check(is_equal_approx(CareerCoefficients.coefficient("131"), 113.25),
		"Barcelona carries the published total")
	_check(is_equal_approx(CareerCoefficients.coefficient("999999999"), 0.0),
		"an unknown club starts at zero")
	var sorted := CareerCoefficients.sorted_clubs(["131", "27", "999999999"])
	_check(sorted == ["27", "131", "999999999"],
		"the sort puts the higher coefficient first")
	_check(CareerCoefficients.seasons().size() == 5,
		"the snapshot carries five season columns")
	var bayern := CareerCoefficients.points("27")
	_check(bayern.size() == 5 and is_equal_approx(float(bayern[0]), 26.0)
		and is_equal_approx(float(bayern[4]), 39.25),
		"Bayern's per-season points are stored")
	var rolled := CareerCoefficients.roll({"27": [1.0, 2.0, 3.0, 4.0, 5.0]},
		{"27": 6.0, "999": 7.0})
	var row: Array = rolled["27"]
	_check(row.size() == 5 and is_equal_approx(float(row[0]), 2.0)
		and is_equal_approx(float(row[4]), 6.0),
		"the roll drops the oldest season and adds the new one")
	_check((rolled["999"] as Array).size() == 5
		and is_equal_approx(float((rolled["999"] as Array)[4]), 7.0),
		"a new club starts with four empty seasons")
	_check(is_equal_approx(CareerCoefficients.total(rolled, "27"), 20.0),
		"the total is the sum of the five seasons")

	print("== check_club_coefficients: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
