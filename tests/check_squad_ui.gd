extends SceneTree
# Headless UI check for the squad screen: a valid team shows the eleven
# formation slots, the players in formation order and every final stat. The
# squad screen is opened from the new team-select screen with V (the original
# team-select page has no extra button), so the test seeds that preview team.
# A missing team shows a readable error instead of an empty screen.
#
# Run:  godot --headless --path . -s res://tests/check_squad_ui.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const TEAM_SELECT := "res://scenes/team_select.tscn"
const SQUAD := "res://scenes/squad.tscn"
const TEAM_ID := 4

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
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		_check(false, "the catalog loads")
		_finish()
		return
	var team := catalog.team_by_id(TEAM_ID)
	_check(not team.is_empty(), "the test team exists")

	ShellState.clear()
	ShellState.set_preview_team(team)
	change_scene_to_file(SQUAD)
	await _frames(10)
	var squad := current_scene
	_check(squad != null and squad.name == "Squad", "the squad screen opens")
	if squad == null or squad.name != "Squad":
		_finish()
		return
	_check(squad.team_label.text == str(team.get("name", "")),
		"the squad screen shows the selected team")
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
