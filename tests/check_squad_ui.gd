extends SceneTree
# Headless UI check for the squad screen: team select -> View squad shows the
# eleven formation slots, the players in formation order, and every final stat.
# A missing team shows a readable error instead of an empty screen.
#
# Run:  godot --headless --path . -s res://tests/check_squad_ui.gd

const TEAM_SELECT := "res://scenes/team_select.tscn"
const SQUAD := "res://scenes/squad.tscn"

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
	change_scene_to_file(TEAM_SELECT)
	await _frames(10)
	var select := current_scene
	_check(select != null and select.name == "TeamSelect", "the team selection screen opens")
	if select == null or select.name != "TeamSelect":
		_finish()
		return

	var league_index := -1
	var teams: Array = []
	for i in select.league_list.item_count:
		var league_id := int(select.league_list.get_item_metadata(i))
		var candidates: Array = select.catalog.teams_for_league(league_id)
		if candidates.size() >= 2:
			league_index = i
			teams = candidates
			break
	_check(league_index >= 0, "a league with teams is available")
	if league_index < 0:
		_finish()
		return
	select.league_list.select(league_index)
	select.call("_on_league_selected", league_index)
	select.team_list.select(0)
	select.call("_on_team_selected", 0)
	_check(not select.view_squad_button.disabled, "View squad is enabled for a selected team")
	select.view_squad_button.pressed.emit()
	await _frames(10)

	var squad := current_scene
	_check(squad != null and squad.name == "Squad", "View squad opens the squad screen")
	if squad == null or squad.name != "Squad":
		_finish()
		return
	_check(squad.team_label.text == str(teams[0]["name"]), "the squad screen shows the selected team")
	_check(not squad.league_label.text.is_empty(), "the squad screen shows the league")
	_check((squad.pitch_view.entries as Array).size() == 11,
		"the pitch shows eleven formation slots")
	_check(squad.player_list.item_count >= 11,
		"the player list shows the squad (%d players)" % squad.player_list.item_count)
	_check(squad.stats_grid.get_child_count() == PlayerStats.STAT_NAMES.size() * 2,
		"the stats panel shows every final stat")
	var stat_text := ""
	for child in squad.stats_grid.get_children():
		stat_text += (child as Label).text + " "
	_check(stat_text.contains("physical_balance") and stat_text.contains("mental_vision"),
		"the stats panel lists the original stat names")
	_check(squad.player_info.text.contains("age") and squad.player_info.text.contains("base"),
		"the selected player shows age and base stat")

	squad.back_button.pressed.emit()
	await _frames(10)
	_check(current_scene != null and current_scene.name == "TeamSelect",
		"Back returns to the team selection screen")

	ShellState.clear()
	var broken = load(SQUAD).instantiate()
	broken.team_id = 999999
	root.add_child(broken)
	await _frames(3)
	_check(broken.status_label.text.contains("Unknown team id"),
		"an unknown team shows a readable error: " + broken.status_label.text)
	_check(broken.player_list.item_count == 0, "the broken squad shows no players")
	broken.queue_free()

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: squad UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
