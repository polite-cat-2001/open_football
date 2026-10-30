extends SceneTree
# Headless UI check for the team selection screen: leagues and teams come from the
# database, picking two teams enables Start Match, the choice lands in the shell
# state, and a missing database shows a readable error instead of an empty screen.
#
# Run:  godot --headless --path . -s res://tests/check_team_select_ui.gd

const TEAM_SELECT := "res://scenes/team_select.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	ShellState.clear()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(3)
	var menu := current_scene
	var select_button := menu.get_node_or_null("SelectTeamsBtn") as Button
	_check(select_button != null, "the main menu offers team selection")
	if select_button == null:
		_finish()
		return
	select_button.pressed.emit()
	await _frames(10)
	var screen := current_scene
	_check(screen != null and screen.name == "TeamSelect", "Select Teams opens the team selection screen")
	if screen == null or screen.name != "TeamSelect":
		_finish()
		return

	_check(screen.catalog.leagues.size() > 0, "the screen loads leagues from the database")
	_check(screen.league_list.item_count == screen.catalog.leagues.size(),
		"the league list shows every league (%d)" % screen.league_list.item_count)
	_check(screen.catalog.teams.size() > 0, "the screen loads teams from the database")
	_check(screen.start_button.disabled, "Start Match is disabled until both teams are picked")

	var league_index := -1
	var teams: Array = []
	for i in screen.league_list.item_count:
		var league_id := int(screen.league_list.get_item_metadata(i))
		var candidates: Array = screen.catalog.teams_for_league(league_id)
		if candidates.size() >= 2:
			league_index = i
			teams = candidates
			break
	_check(league_index >= 0, "the database has a league with at least two teams")
	if league_index < 0:
		_finish()
		return

	screen.league_list.select(league_index)
	screen.call("_on_league_selected", league_index)
	_check(screen.team_list.item_count == teams.size(),
		"the team list shows the selected league's teams (%d)" % screen.team_list.item_count)

	screen.team_list.select(0)
	screen.set_home_button.pressed.emit()
	screen.team_list.select(1)
	screen.set_away_button.pressed.emit()
	_check(not screen.start_button.disabled, "Start Match is enabled once both teams are picked")
	_check(screen.home_label.text.begins_with(str(teams[0]["name"])),
		"the home slot shows the chosen team")
	_check(screen.away_label.text.begins_with(str(teams[1]["name"])),
		"the away slot shows the chosen team")
	_check(screen.save_selection(), "the selection is saved")
	_check(ShellState.has_selection(), "the shell state holds the selection")
	_check(int(ShellState.home_team.get("id", -1)) == int(teams[0]["id"]),
		"the shell state keeps the home team id")
	_check(int(ShellState.away_team.get("id", -1)) == int(teams[1]["id"]),
		"the shell state keeps the away team id")

	var broken = load(TEAM_SELECT).instantiate()
	broken.data_root = "user://__team_select_missing"
	root.add_child(broken)
	await _frames(2)
	_check(broken.start_button.disabled, "a missing database disables Start Match")
	_check(broken.status_label.text.contains("not found"),
		"a missing database shows a readable message: " + broken.status_label.text)
	broken.queue_free()

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: team select UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
