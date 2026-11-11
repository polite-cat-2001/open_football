extends SceneTree
# Headless check for the career hub (ticket 03): the Centre read model against a
# golden snapshot, tab switching, the tournament overlay, saving with S and the
# exit back to the main menu. Mirrors the prototype's hub state.
#
# Run:  godot --headless --path . -s res://tests/check_career_hub.gd

const HUB := "res://scenes/career_hub.tscn"
const GOLDEN := "res://tests/fixtures/career_hub_golden.json"

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
	print("== check_career_hub: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_hub_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	CareerSession.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	var nav := root.get_node("UiNav")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var store := CareerSaveStore.new(_directory)
	_check(store.save(career), "the career saves")
	CareerSession.career = career
	CareerSession.store = store
	CareerSession.catalog = catalog

	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the golden fixture loads")
	if golden is Dictionary:
		var snapshot := CareerFactory.snapshot(catalog, career)
		var model := {
			"next": CareerHubModel.next_tile(snapshot),
			"table": CareerHubModel.table_tile(snapshot),
			"overlay": CareerHubModel.overlay(snapshot),
		}
		var normalized = JSON.parse_string(JSON.stringify(model))
		_check(JSON.stringify(normalized) == JSON.stringify(golden),
			"the hub read model matches the golden snapshot")

	change_scene_to_file(HUB)
	await _frames(12)
	var hub := current_scene
	_check(hub != null and hub.name == "CareerHub", "the career hub opens")
	if hub == null or hub.name != "CareerHub":
		_finish()
		return
	var tab_bar: UiTabBar = hub.get_node("Design/PanelWrap/Body/TabBar")
	var grid: BentoGrid = hub.get_node("Design/PanelWrap/Body/Grid")
	var placeholder: UiMenuPanel = hub.get_node("Design/PanelWrap/Body/Placeholder")
	var next_tile = hub.get_node("Design/PanelWrap/Body/Grid/NextTile")
	var table_tile = hub.get_node("Design/PanelWrap/Body/Grid/TableTile")
	var overlay = hub.get_node("Design/Overlay")

	_check(tab_bar.get_active_tab() == 0, "the Centre tab is active")
	var labels_ok := true
	for index in range(CareerHubModel.TABS.size()):
		labels_ok = labels_ok and tab_bar.get_tab_button(index) != null
	_check(labels_ok, "the hub shows four tabs")
	_check(grid.visible, "the centre dashboard is visible")
	_check(next_tile.has_focus(), "the next-match tile owns focus")
	_check((table_tile.get("_rows") as Array).size() == 7,
		"the overview shows a header and six table rows")

	nav.moved.emit(Vector2i.RIGHT)
	await _frames(3)
	_check(table_tile.has_focus(), "Right moves focus to the overview tile")
	nav.confirmed.emit()
	await _frames(4)
	_check(overlay.is_open(), "confirm opens the tournament overlay")
	_check((overlay.get("_rows") as Array).size() == 21,
		"the overlay lists a header and all twenty clubs")
	nav.cancelled.emit()
	await _frames(4)
	_check(not overlay.is_open(), "Back closes the overlay")
	_check(table_tile.has_focus(), "focus returns to the overview tile")

	nav.tab_next.emit()
	await _frames(4)
	_check(tab_bar.get_active_tab() == 1, "R1 switches to the next tab")
	_check(not grid.visible, "the centre dashboard hides on another tab")
	_check(placeholder.visible, "the other tab shows the shared placeholder")
	_check(career.hub_tab == "squad", "the active tab is stored on the career")
	nav.cancelled.emit()
	await _frames(4)
	_check(tab_bar.get_active_tab() == 0, "Back from another tab returns to Centre")

	nav.tab_next.emit()
	await _frames(3)
	var save_key := InputEventKey.new()
	save_key.keycode = KEY_S
	save_key.physical_keycode = KEY_S
	save_key.pressed = true
	Input.parse_input_event(save_key)
	await _frames(4)
	var reloaded := store.load_career(career.id)
	_check(reloaded != null and reloaded.hub_tab == "squad",
		"S saves the career with the active tab")

	nav.tab_previous.emit()
	await _frames(3)
	nav.cancelled.emit()
	await _frames(40)
	_check(current_scene != null and current_scene.name == "MainMenu",
		"Back from Centre saves and exits to the main menu")
	_check(store.load_career(career.id) != null, "the exit keeps the saved career")

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
