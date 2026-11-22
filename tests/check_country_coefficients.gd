extends SceneTree
# Headless check for the association coefficient snapshot: 55 associations, five
# season columns, England on top, San Marino at the bottom, and the roll drops the
# oldest season and adds the new country points. Also checks the club-code map.
#
# Run:  godot --headless --path . -s res://tests/check_country_coefficients.gd

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
	var table := CareerCountryCoefficients.table()
	_check(table.size() == 55, "the snapshot has 55 associations: %d" % table.size())
	_check(CareerCountryCoefficients.seasons().size() == 5,
		"the snapshot has five season columns")
	_check(is_equal_approx(CareerCountryCoefficients.coefficient(table, "England"),
		119.519), "England carries the published total")
	var ranking := CareerCountryCoefficients.ranking(table)
	_check(str(ranking[0]) == "England", "England is first")
	_check(str(ranking[-1]) == "San Marino", "San Marino is last")
	_check(CareerCountryCoefficients.association_for_code("Eng") == "England",
		"the club country code maps to England")
	_check(CareerCountryCoefficients.association_for_code("Cze") == "Czechia",
		"the club country code maps to Czechia")
	var rolled := CareerCountryCoefficients.roll(table, {"England": 30.0})
	var row: Array = rolled["England"]
	_check(row.size() == 5 and is_equal_approx(float(row[0]), 23.0)
		and is_equal_approx(float(row[4]), 30.0),
		"the roll drops 2021-22 and adds the new country points")
	_check(is_equal_approx(CareerCountryCoefficients.coefficient(rolled, "England"),
		128.519), "the rolled total is the sum of the five seasons")
	var fresh := CareerCountryCoefficients.roll({}, {"Wakanda": 4.5})
	_check((fresh["Wakanda"] as Array).size() == 5
		and is_equal_approx(float((fresh["Wakanda"] as Array)[4]), 4.5),
		"a new association starts with four empty seasons")
	print("== check_country_coefficients: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
