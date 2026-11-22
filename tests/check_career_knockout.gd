extends SceneTree
# Headless check for the knockout phase: the top eight skip the play-off, places
# 9-24 play two legs with the higher-placed club at home in the second leg, and
# the bracket runs play-off -> round of 16 -> quarter-final -> semi-final -> final.
# The winner is one of the league-phase clubs and the same seed repeats it.
#
# Run:  godot --headless --path . -s res://tests/check_career_knockout.gd

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
	var table: Array = CareerEurope.fields().get("ucl", [])
	_check(table.size() == 36, "the league table has 36 clubs")
	if table.size() != 36:
		_finish()
		return
	var played := CareerKnockout.play(catalog, table, 42,
		{"method": "extra_time_pens", "away_goals": false})
	_check(CareerKnockout.last_error.is_empty(),
		"the bracket resolves: " + CareerKnockout.last_error)
	var rounds: Array = played.get("rounds", [])
	_check(rounds.size() == 5, "five knockout rounds: %d" % rounds.size())
	if rounds.size() != 5:
		_finish()
		return
	var sizes := [16, 16, 8, 4, 1]
	var names := ["playoff", "r16", "qf", "semi", "final"]
	var top_eight := {}
	for index in range(8):
		top_eight[str(table[index])] = true
	for index in range(rounds.size()):
		var round: Dictionary = rounds[index]
		_check(str(round.get("name", "")) == names[index],
			"%s is round %d" % [names[index], index])
		_check((round.get("fixtures", []) as Array).size() == sizes[index],
			"%s has %d fixtures" % [names[index], sizes[index]])
	var playoff: Dictionary = rounds[0]
	_check((playoff.get("entrants", []) as Array).size() == 24,
		"the bracket starts with 24 clubs")
	var playing := {}
	for fixture in playoff.get("fixtures", []):
		playing[str(fixture.get("home", ""))] = true
		playing[str(fixture.get("away", ""))] = true
	_check(playing.size() == 16, "the play-off has 16 clubs")
	var top_in_playoff: Array = []
	for club_id in playing:
		if top_eight.has(club_id):
			top_in_playoff.append(club_id)
	_check(top_in_playoff.is_empty(), "the top eight skip the play-off")
	var r16_winners: Array = rounds[1].get("winners", [])
	var expected_qf: Array = [
		r16_winners[0], r16_winners[3], r16_winners[2], r16_winners[1],
		r16_winners[6], r16_winners[5], r16_winners[4], r16_winners[7],
	]
	_check(rounds[2].get("entrants", []) == expected_qf,
		"the quarter-finals follow the official path")
	var qf_winners: Array = rounds[2].get("winners", [])
	_check(rounds[3].get("entrants", []) == [
		qf_winners[0], qf_winners[2], qf_winners[3], qf_winners[1]],
		"the semi-finals follow the official path")
	var seed_order := {}
	for index in range(table.size()):
		seed_order[str(table[index])] = index
	var bad_home: Array = []
	var by_tie := {}
	for fixture in playoff.get("fixtures", []):
		var tie := str(fixture.get("tie", ""))
		var list: Array = by_tie.get(tie, [])
		list.append(fixture)
		by_tie[tie] = list
	for tie in by_tie:
		var legs: Array = by_tie[tie]
		if legs.size() != 2:
			bad_home.append("legs:" + str(tie))
			continue
		var first_home := str((legs[0] as Dictionary).get("home", ""))
		var second_home := str((legs[1] as Dictionary).get("home", ""))
		if int(seed_order.get(first_home, 99)) < int(seed_order.get(second_home, 99)):
			bad_home.append("seed:" + str(tie))
	_check(bad_home.is_empty(), "the higher seed hosts the second leg: "
		+ str(bad_home.slice(0, 3)))
	var winner := str(played.get("winner", ""))
	_check(seed_order.has(winner), "the winner is a league-phase club")
	var again := CareerKnockout.play(catalog, table, 42,
		{"method": "extra_time_pens", "away_goals": false})
	_check(str(again.get("winner", "")) == winner, "the same seed repeats the winner")
	_finish()


func _finish() -> void:
	print("== check_career_knockout: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
