extends SceneTree
# Headless UI path check: Select Teams -> prematch (lineup edit, length,
# difficulty) -> match. The prematch builds the match package and stores it in
# ShellState; the match scene hands it to the C++ runtime.
#
# Run:  godot --headless --path . -s res://tests/check_prematch_ui.gd

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
	change_scene_to_file("res://scenes/team_select.tscn")
	await _frames(6)
	var select := current_scene
	if select == null or select.name != "TeamSelect":
		_check(false, "team select screen opens")
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
	_check(league_index >= 0, "a league with two teams exists")
	if league_index < 0:
		_finish()
		return

	select.league_list.select(league_index)
	select.call("_on_league_selected", league_index)
	select.team_list.select(0)
	select.set_home_button.pressed.emit()
	select.team_list.select(1)
	select.set_away_button.pressed.emit()
	select.start_button.pressed.emit()
	await _frames(6)

	var prematch := current_scene
	_check(prematch != null and prematch.name == "Prematch", "Continue opens the prematch screen")
	if prematch == null or prematch.name != "Prematch":
		_finish()
		return

	_check(prematch.home_label.text.begins_with(str(teams[0]["name"])),
		"prematch shows the home team")
	_check(prematch.away_label.text.begins_with(str(teams[1]["name"])),
		"prematch shows the away team")
	_check(prematch.duration_option.item_count == 3, "prematch offers three match lengths")
	_check(prematch.difficulty_option.item_count == 3, "prematch offers three difficulties")
	_check(not prematch.start_button.disabled, "Kick Off is enabled with a selection")
	_check(prematch.home_editor != null and prematch.away_editor != null,
		"prematch loads editable lineups for both teams")
	_check(prematch.editor_tabs.get_tab_count() == 2, "prematch offers home and away lineup tabs")

	var edited_slot := 5
	var promoted_id := int(prematch.home_editor.lineup.bench[0])
	prematch.home_editor.lineup.set_starter(edited_slot, promoted_id)
	prematch.home_editor.set_lineup(prematch.home_editor.lineup)
	prematch.call("_validate_lineups")
	_check(prematch.home_editor.validation_error().is_empty(),
		"swapping a starter keeps the lineup valid")

	var first_id := int(prematch.home_editor.lineup.lineup[6])
	var second_id := int(prematch.home_editor.lineup.lineup[8])
	prematch.home_editor.call("_handle_pick", first_id)
	prematch.home_editor.call("_handle_pick", second_id)
	_check(prematch.home_editor.lineup.lineup[6] == second_id
		and prematch.home_editor.lineup.lineup[8] == first_id,
		"two clicks swap two starters")
	prematch.call("_validate_lineups")

	prematch.duration_option.select(2)
	prematch.duration_option.item_selected.emit(2)
	prematch.difficulty_option.select(0)
	prematch.difficulty_option.item_selected.emit(0)
	_check(float(ShellState.match_options.get("duration", -1)) == 1.5,
		"the chosen length lands in the shell state")
	_check(float(ShellState.match_options.get("difficulty", -1)) == 0.6,
		"the chosen difficulty lands in the shell state")

	prematch.start_button.pressed.emit()
	await _frames(8)
	var match_scene := current_scene
	_check(match_scene != null and match_scene.name == "GpfSlice",
		"Kick Off opens the GPF match")
	_check(ShellState.has_package(), "the prematch built and stored the match package")
	var package := ShellState.match_package
	if not package.is_empty():
		_check(int(package["home"]["database_id"]) == int(teams[0]["id"]),
			"the package carries the chosen home team")
		_check(int(package["away"]["database_id"]) == int(teams[1]["id"]),
			"the package carries the chosen away team")
		_check(float(package["options"]["duration"]) == 1.5,
			"the package carries the chosen length")
		_check(float(package["options"]["difficulty"]) == 0.6,
			"the package carries the chosen difficulty")
		_check(int(package["home"]["players"][edited_slot]["database_id"]) == promoted_id,
			"the edited starter reaches the package")

	var runtime := get_first_node_in_group("gpf_runtime")
	_check(runtime != null and bool(runtime.has_match_package()),
		"the runtime received the package")
	if runtime != null:
		var snap: Dictionary = runtime.get_snapshot()
		_check(str(snap.get("team0_name", "")) == str(teams[0]["name"]),
			"the match uses the chosen home team")
		_check(str(snap.get("team1_name", "")) == str(teams[1]["name"]),
			"the match uses the chosen away team")
		var active_names: Array[String] = []
		for entry in runtime.get_player_ids():
			if int(entry.get("team", -2)) == 0:
				active_names.append(str(entry.get("name", "")))
		var promoted_name := str(package["home"]["players"][edited_slot].get("last_name", ""))
		_check(active_names.has(promoted_name), "the edited starter is on the pitch")

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: prematch UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
