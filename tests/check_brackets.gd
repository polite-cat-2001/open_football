extends SceneTree
# Headless check for the pure knockout bracket: seeding, byes, one- and two-leg
# ties, aggregate winners, penalties, and the higher seed on a drawn tie.
#
# Run:  godot --headless --path . -s res://tests/check_brackets.gd

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
	_check(CareerBrackets.bracket_size(1) == 2, "one entrant still needs a bracket of two")
	_check(CareerBrackets.bracket_size(6) == 8, "six entrants need a bracket of eight")
	_check(CareerBrackets.bracket_size(8) == 8, "eight entrants fill a bracket of eight")
	_check(CareerBrackets.bracket_size(16) == 16, "sixteen entrants fill a bracket of sixteen")

	var seeds: Array = ["a", "b", "c", "d", "e", "f", "g", "h"]
	var pairs := CareerBrackets.pairs(seeds, 8)
	_check(pairs.size() == 4, "eight entrants make four ties")
	_check(pairs[0] == ["a", "h"], "the top seed meets the bottom seed")
	_check(pairs[3] == ["d", "e"], "the middle seeds meet")

	var final_stage := {"rounds": [{"name": "final", "legs": 1}]}
	var one_fixture := CareerBrackets.round_fixtures(final_stage, 0, ["a", "b"],
		["2026-07-01"], "x:")
	_check(one_fixture.size() == 1, "a single-leg final is one fixture")
	_check(str(one_fixture[0].get("id", "")) == "x:final:00:0", "the fixture id names round and leg")
	_check(str(one_fixture[0].get("date", "")) == "2026-07-01", "the caller supplies the date")
	var one_results := {str(one_fixture[0].get("id", "")): {"home": 2, "away": 0}}
	var one_winners := CareerBrackets.round_winners(["a", "b"], one_fixture, one_results)
	_check(one_winners == ["a"], "the higher seed wins a one-leg tie")

	var first_round := {"rounds": [{"name": "semis", "legs": 2}]}
	var two_leg := CareerBrackets.round_fixtures(first_round, 0, ["a", "b", "c", "d"],
		["2026-07-01", "2026-07-05"], "")
	_check(two_leg.size() == 4, "two semi-finals with two legs make four fixtures")
	_check(str(two_leg[1].get("date", "")) == "2026-07-05",
		"the second leg gets its own date")
	_check(str(two_leg[0].get("home", "")) == "a" and str(two_leg[1].get("home", "")) == "d",
		"the second leg swaps home and away")
	var results := {
		"semis:00:0": {"home": 1, "away": 0},
		"semis:00:1": {"home": 0, "away": 3},
		"semis:01:0": {"home": 0, "away": 2},
		"semis:01:1": {"home": 0, "away": 0},
	}
	var winners := CareerBrackets.round_winners(["a", "b", "c", "d"], two_leg, results)
	_check(winners == ["a", "c"], "the two-leg tie is decided on aggregate")

	var pens_results := {
		"semis:00:0": {"home": 1, "away": 1},
		"semis:00:1": {"home": 5, "away": 3, "pens": {"home": 4, "away": 3}},
		"semis:01:0": {"home": 1, "away": 1},
		"semis:01:1": {"home": 1, "away": 1},
	}
	var pens_winners := CareerBrackets.round_winners(["a", "b", "c", "d"], two_leg,
		pens_results)
	_check(pens_winners == ["d", "b"],
		"a level aggregate falls to penalties, then to the higher seed")

	var six := CareerBrackets.round_fixtures(
		{"rounds": [{"name": "quarter", "legs": 1}]}, 0,
		["a", "b", "c", "d", "e", "f"], ["2026-07-01"], "")
	_check(six.size() == 2, "six entrants leave two ties and two byes")
	var six_winners := CareerBrackets.round_winners(["a", "b", "c", "d", "e", "f"], six,
		{"quarter:02:0": {"home": 1, "away": 0}, "quarter:03:0": {"home": 2, "away": 1}})
	_check(six_winners == ["a", "b", "c", "d"], "byes advance without a fixture")
	_check(CareerBrackets.round_winners([], [], {}) == [], "an empty bracket has no winners")

	print("== check_brackets: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
