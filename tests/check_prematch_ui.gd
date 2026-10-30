extends SceneTree
# Headless UI check for the ported pre-match hub: header, seven PES-style tabs,
# kick-off lineups, options sliders, kit selectors, the lineup editor overlay,
# and the package/runtime handoff.
#
# Run:  godot --headless --path . -s res://tests/check_prematch_ui.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const HOME_ID := 4
const AWAY_ID := 5
const EDITED_SLOT := 5
const PREMATCH := "res://scenes/prematch.tscn"

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
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		_check(false, "the catalog loads")
		_finish()
		return
	var home := catalog.team_by_id(HOME_ID)
	var away := catalog.team_by_id(AWAY_ID)
	ShellState.set_teams(home, away)
	# The controller screen is a separate step; seed an away keyboard so the
	# runtime handoff is still covered here.
	ShellState.set_controllers([
		{"side": "away", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])

	change_scene_to_file(PREMATCH)
	await _frames(10)
	var screen := current_scene
	_check(screen != null and screen.name == "Prematch", "the pre-match hub opens")
	if screen == null or screen.name != "Prematch":
		_finish()
		return

	var header := screen.get("header_label") as Label
	_check(header != null and header.text.contains(str(home.get("name", "")))
		and header.text.contains(str(away.get("name", ""))),
		"the header shows both teams")
	var tabs: Array = screen.get("tab_buttons")
	_check(tabs.size() == 7, "the hub has the original seven tabs")
	_check(int(screen.get("active_tab")) == 2, "the hub starts on Kick-off")
	var home_names: Array = screen.get("home_name_labels")
	var away_names: Array = screen.get("away_name_labels")
	_check(home_names.size() == 11 and away_names.size() == 11,
		"the Kick-off tab lists eleven names per side")
	var start_button := screen.get("start_button") as Button
	_check(start_button != null and not start_button.disabled,
		"Start match is enabled with valid lineups")
	var tabs_container := screen.get("editor_tabs") as TabContainer
	_check(tabs_container != null and tabs_container.get_tab_count() == 2,
		"the lineup editor has Home and Away tabs")

	# Options tab: sliders land in the shell state.
	screen.call("_select_tab", 4)
	var duration: HSlider = screen.get("duration_slider")
	var difficulty: HSlider = screen.get("difficulty_slider")
	_check(duration != null and difficulty != null, "the Options tab has both sliders")
	if duration != null and difficulty != null:
		duration.value = 1.5
		difficulty.value = 0.6
		await _frames(2)
		_check(float(ShellState.match_options.get("duration", -1)) == 1.5,
			"the chosen duration lands in the shell state")
		_check(float(ShellState.match_options.get("difficulty", -1)) == 0.6,
			"the chosen difficulty lands in the shell state")

	# Kit tab: the selected kit lands in the shell state.
	screen.call("_select_tab", 0)
	var kits: Array = screen.get("kit_options")
	_check(kits.size() == 2 and kits[0].item_count >= 2,
		"the Kit tab offers a strip for each side")
	if kits.size() == 2 and kits[0].item_count >= 2:
		var kit_index: int = int(kits[0].item_count) - 1
		kits[0].select(kit_index)
		kits[0].item_selected.emit(kit_index)
		await _frames(1)
		var chosen := int(kits[0].get_item_metadata(kit_index))
		_check(int(ShellState.match_options.get("kit_home", -1)) == chosen,
			"the chosen home kit lands in the shell state")

	# Kick-off lineups: edit a starter through the overlay, then build the package.
	screen.call("_select_tab", 2)
	var edit_button := screen.get("edit_lineups_button") as Button
	_check(edit_button != null, "the Kick-off tab offers the lineups editor")
	if edit_button != null:
		edit_button.pressed.emit()
		await _frames(2)
		_check(bool(screen.get("lineup_overlay").visible), "the lineup overlay opens")

	var home_editor = screen.get("home_editor")
	var away_editor = screen.get("away_editor")
	_check(home_editor != null and away_editor != null, "both lineups load")
	if home_editor == null or away_editor == null:
		_finish()
		return
	var promoted := int(home_editor.lineup.bench[0])
	var promoted_name := str(home_editor.lineup.player_by_id(promoted).get("lastname", ""))
	home_editor.lineup.set_starter(EDITED_SLOT, promoted)
	home_editor.set_lineup(home_editor.lineup)
	screen.call("_on_lineups_changed")
	screen.call("_close_lineups")
	await _frames(2)
	_check(not bool(screen.get("lineup_overlay").visible), "the lineup overlay closes")
	_check((screen.get("home_name_labels")[EDITED_SLOT] as Label).text.contains(promoted_name),
		"the Kick-off list follows the edited lineup")

	var package: Dictionary = screen.call("build_package")
	_check(not package.is_empty(), "the hub builds a match package")
	if package.is_empty():
		_finish()
		return
	_check(int(package["home"]["database_id"]) == HOME_ID
		and int(package["away"]["database_id"]) == AWAY_ID,
		"the package carries the chosen teams")
	_check(float(package["options"]["duration"]) == 1.5,
		"the package carries the chosen duration")
	_check(float(package["options"]["difficulty"]) == 0.6,
		"the package carries the chosen difficulty")
	_check(int(package["home"]["players"][EDITED_SLOT]["database_id"]) == promoted,
		"the edited starter reaches the package")

	start_button.pressed.emit()
	await _frames(12)
	_check(current_scene != null and current_scene.name == "GpfSlice",
		"Start match opens the GPF match")
	_check(ShellState.has_package(), "the prematch stored the match package")

	var runtime := get_first_node_in_group("gpf_runtime")
	_check(runtime != null and bool(runtime.has_match_package()),
		"the runtime received the package")
	if runtime != null:
		var setup: Array = runtime.get_controller_setup()
		_check(setup.size() == 1 and int(setup[0].get("side", 0)) == 1
			and str(setup[0].get("kind", "")) == "keyboard",
			"the runtime received the away-side keyboard setup")
		var humans: Array = runtime.debug_human_state()
		_check(humans.size() == 2 and int(humans[0].get("gamers", -1)) == 0
			and int(humans[1].get("gamers", -1)) == 1,
			"the match binds the human gamer to the away side")
		var snap: Dictionary = runtime.get_snapshot()
		_check(str(snap.get("team0_name", "")) == str(home.get("name", "")),
			"the match uses the chosen home team")
		_check(str(snap.get("team1_name", "")) == str(away.get("name", "")),
			"the match uses the chosen away team")
		var active_names: Array[String] = []
		for entry in runtime.get_player_ids():
			if int(entry.get("team", -2)) == 0:
				active_names.append(str(entry.get("name", "")))
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
