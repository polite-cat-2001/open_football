extends SceneTree
# Headless navigation check for career entry: Start (empty), New Career
# (country -> league -> club -> manager), creation into the hub, Load, and the
# main menu's Continue tile. All movement goes through UiNav.
#
# Run:  godot --headless --path . -s res://tests/check_career_ui.gd

const START := "res://scenes/career_start.tscn"
const NEW := "res://scenes/career_new.tscn"
const LOAD := "res://scenes/career_load.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"

var failures: Array[String] = []
var _directory := ""


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


func _finish() -> void:
	_cleanup()
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	print("== check_career_ui: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_ui_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	CareerSession.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	var nav := root.get_node("UiNav")

	change_scene_to_file(START)
	await _frames(8)
	var start := current_scene
	_check(start != null and start.name == "CareerStart", "the career start screen opens")
	if start == null:
		_finish()
		return
	var continue_tile: BentoTile = start.get_node("Design/PanelWrap/Grid/ContinueTile")
	var new_tile: BentoTile = start.get_node("Design/PanelWrap/Grid/NewCareerTile")
	var load_tile: BentoTile = start.get_node("Design/PanelWrap/Grid/LoadTile")
	_check(continue_tile.disabled, "Continue is disabled with no saves")
	_check(load_tile.disabled, "Load is disabled with no saves")
	_check(new_tile.has_focus(), "New Career owns focus in the empty state")
	nav.confirmed.emit()
	await _frames(8)
	_check(current_scene != null and current_scene.name == "CareerNew",
		"UiNav confirm opens New Career")

	var creation := current_scene
	var panel: TeamPanel = creation.get("_panel")
	var name_row: UiFormRow = creation.get("_name_row")
	var nat_row: CareerRow = creation.get("_nat_row")
	var cta: BentoTile = creation.get("_cta")
	var osk: UiOnScreenKeyboard = creation.get("osk")
	_check(creation.current_step() == "club", "New Career starts on the club step")
	_check(creation.select_country_by_id(189), "England is selectable")
	_check(creation.select_league_by_id("GB1"), "the Premier League is selectable")
	_check(creation.select_club_by_id(11), "Arsenal is selectable")
	await _frames(3)
	_check(panel.team_name_text() == "ARSENAL FC", "the club tile shows the club")
	_check(panel.competition_name_text() == "PREMIER LEAGUE",
		"the competition tile shows the league")
	var info = creation.get("_info")
	var info_values: Array = info.get("_row_values")
	_check(info_values[0].text == "Premier League", "the dossier shows the league")
	_check(info_values[1].text == "England", "the dossier shows the country")
	_check(info_values[2].text == "First Tier", "the dossier shows the tier")
	_check(info_values[4].text == "Emirates Stadium", "the dossier shows the stadium")
	var stat_labels: Array = info.get("_stat_labels")
	_check(stat_labels[3].text == "SQUAD VALUE", "the last stat is squad value")
	var kit_labels: Array = info.get("_kit_labels")
	_check(kit_labels.size() == 4, "four kits are laid out")
	_check(kit_labels[0].text == "HOME" and kit_labels[3].text == "FOURTH",
		"the kit labels match the kit-select vocabulary")
	_check(info.get("_kit_arts")[0].visible, "the first kit shirt is visible")
	_check(creation.get("_squad").size() >= 11, "the club squad is loaded")

	nav.confirmed.emit()
	await _frames(40)
	_check(creation.current_step() == "manager", "confirming the club opens the manager step")
	_check(name_row.has_focus(), "the manager name owns focus")
	_check(name_row.opaque, "the manager name row is opaque")
	_check(cta.meta == "", "the start tile has no overlapping meta line")
	nav.confirmed.emit()
	await _frames(3)
	_check(osk.is_open(), "confirm on the name opens the shared keyboard")
	_check(osk.key_button(3, 0) == null,
		"the career keyboard uses the three-row player-search layout")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await _frames(2)
	_check(not osk.is_open(), "Escape closes only the keyboard")
	_check(creation.current_step() == "manager", "Escape keeps the manager screen")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await _frames(3)
	_check(osk.is_open(), "the keyboard reopens from the name row")
	for character in "Golden Manager":
		osk.press_character(character)
	osk.press_apply()
	await _frames(3)
	_check(name_row.value_text() == "Golden Manager", "the typed manager name is applied")
	_check(not cta.disabled, "the start tile enables once the name is set")

	nav.moved.emit(Vector2i.DOWN)
	await _frames(2)
	_check(nat_row.has_focus(), "Down moves to the nationality row")
	var nat_prev: Button = creation.get("_nat_prev")
	_check(nat_prev.visible, "the nationality arrows are visible")
	var nationality_before = creation.get("_nationality_index")
	nat_prev.pressed.emit()
	await _frames(2)
	_check(creation.get("_nationality_index") != nationality_before,
		"clicking the left arrow cycles the manager nationality")
	nationality_before = creation.get("_nationality_index")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(2)
	_check(creation.get("_nationality_index") != nationality_before,
		"Right also cycles the manager nationality")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(2)
	_check(cta.has_focus(), "Down reaches the start career tile")
	nav.confirmed.emit()
	await _frames(40)
	_check(current_scene != null and current_scene.name == "CareerHub",
		"creating a career opens its hub")

	var store := CareerSaveStore.new(_directory)
	var saved := store.latest()
	_check(saved != null, "the created career is saved to disk")
	if saved != null:
		_check(saved.club_id == "11", "the saved career keeps the club")
		_check(saved.manager.name == "Golden Manager", "the saved career keeps the manager")
		_check(saved.seed >= 0, "the saved career keeps its seed")

	CareerSession.clear()
	change_scene_to_file(LOAD)
	await _frames(8)
	var load_screen := current_scene
	_check(load_screen != null and load_screen.name == "CareerLoad", "the load screen opens")
	if load_screen != null:
		var rows: Array = load_screen.get("_rows")
		_check(rows.size() == 1, "the load list shows one save")
		_check(rows[0].lead_texture != null, "the save row shows the club crest")
		_check(rows[0].league_texture != null, "the save row shows the league logo")
		_check(rows[0].has_focus(), "the first compatible save owns focus")
		nav.cancelled.emit()
		await _frames(6)
		_check(current_scene != null and current_scene.name == "CareerStart",
			"Back from Load returns to the career start")
		change_scene_to_file(LOAD)
		await _frames(6)
		nav.confirmed.emit()
		await _frames(8)
		_check(current_scene != null and current_scene.name == "CareerHub",
			"confirming a save opens it")

	CareerSession.clear()
	change_scene_to_file(START)
	await _frames(8)
	start = current_scene
	continue_tile = start.get_node("Design/PanelWrap/Grid/ContinueTile")
	_check(not continue_tile.disabled, "Continue is enabled when a save exists")
	_check(continue_tile.has_focus(), "Continue owns focus when a save exists")
	nav.confirmed.emit()
	await _frames(40)
	_check(current_scene != null and current_scene.name == "CareerHub",
		"Continue opens the latest compatible save")

	CareerSession.clear()
	change_scene_to_file(MAIN_MENU)
	await _frames(10)
	var menu := current_scene
	_check(menu != null and menu.name == "MainMenu", "the main menu opens")
	if menu != null:
		var menu_continue: BentoTile = menu.get_node(
			"Design/PanelWrap/PlayGrid/ContinueCareerTile")
		var menu_career: BentoTile = menu.get_node("Design/PanelWrap/PlayGrid/CareerTile")
		_check(not menu_continue.disabled, "the main menu Continue tile is enabled")
		_check(menu_continue.find_next_valid_focus() == menu_career
			or menu_continue.focus_mode == Control.FOCUS_ALL,
			"the main menu Continue tile is focusable")
		menu_continue.grab_focus()
		nav.confirmed.emit()
		await _frames(8)
		_check(current_scene != null and current_scene.name == "CareerHub",
			"the main menu Continue tile opens the latest save")

	if saved != null:
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(_directory.path_join(saved.id + ".json")))
		var bad_file := FileAccess.open(
			_directory.path_join("dddddddddddddddddddddddddddddddd.json"), FileAccess.WRITE)
		bad_file.store_string(JSON.stringify({
			"version": 2,
			"id": "dddddddddddddddddddddddddddddddd",
			"seed": 1,
			"date": "2026-07-01",
			"season_start": "2026-07-01",
			"created_at": "2026-07-01T00:00:00.000000Z",
			"updated_at": "2026-07-01T00:00:00.000000Z",
			"manager": {"name": "Old Build", "nationality_id": "189", "nationality": "England"},
			"club_id": "11",
			"player_ids": [],
			"journal": [],
		}))
		bad_file.close()

		CareerSession.clear()
		change_scene_to_file(START)
		await _frames(8)
		start = current_scene
		continue_tile = start.get_node("Design/PanelWrap/Grid/ContinueTile")
		load_tile = start.get_node("Design/PanelWrap/Grid/LoadTile")
		var continue_sub: Label = continue_tile.get("_sub_label")
		var load_sub: Label = load_tile.get("_sub_label")
		_check(continue_tile.disabled, "Continue stays disabled with only incompatible saves")
		_check(continue_sub.text == "No compatible saves",
			"Continue distinguishes no compatible saves from no saves")
		_check(not load_tile.disabled, "Load is enabled for incompatible saves")
		_check(load_sub.text.contains("1 career"), "Load counts incompatible saves")

		CareerSession.clear()
		change_scene_to_file(MAIN_MENU)
		await _frames(10)
		menu = current_scene
		var menu_continue: BentoTile = menu.get_node(
			"Design/PanelWrap/PlayGrid/ContinueCareerTile")
		var menu_continue_sub: Label = menu_continue.get("_sub_label")
		_check(menu_continue.disabled, "the main menu Continue tile rejects incompatible saves")
		_check(menu_continue_sub.text == "No compatible saves",
			"the main menu reports no compatible saves")

	_finish()


func _cleanup() -> void:
	if _directory.is_empty():
		return
	var dir := DirAccess.open(_directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_directory))
