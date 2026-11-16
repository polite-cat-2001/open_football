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
	var transfer_tile = hub.get_node("Design/PanelWrap/Body/Grid/TransferTile")
	var overlay = hub.get_node("Design/Overlay")

	_check(tab_bar.get_active_tab() == 0, "the Centre tab is active")
	var labels_ok := true
	for index in range(CareerHubModel.TABS.size()):
		labels_ok = labels_ok and tab_bar.get_tab_button(index) != null
	_check(labels_ok, "the hub shows every section tab")
	_check(grid.visible, "the centre dashboard is visible")
	_check(tab_bar.get_tab_button(0).has_focus(),
		"the active tab owns focus when the hub opens")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	_check(next_tile.has_focus(), "Down enters the page at the first tile")
	_check((table_tile.get("_rows") as Array).size() == 7,
		"the overview shows a header and six table rows")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	_check(transfer_tile.has_focus(),
		"Down from the next-match tile reaches Transfer Centre")
	transfer_tile.set_badge("2 NEW")
	var badge: Control = transfer_tile.get("_badge")
	var tile_rect: Rect2 = transfer_tile.get_global_rect()
	var badge_rect: Rect2 = badge.get_global_rect()
	_check(badge.visible and badge_rect.get_center().x < tile_rect.get_center().x
		and badge_rect.get_center().y > tile_rect.get_center().y,
		"the update badge sits in the bottom-left corner")
	transfer_tile.set_badge("")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(next_tile.has_focus(),
		"Up from Transfer Centre returns to the next-match tile")

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

	# A sideways push from the edge tile pages to the next section.
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(3)
	_check(tab_bar.get_active_tab() == 1, "Right from the last tile opens the next section")
	nav.cancelled.emit()
	await _frames(3)
	_check(tab_bar.get_active_tab() == 0, "Back returns to Centre")

	# Section entrances fade the tiles in. A focus move during that fade must
	# not freeze a tile half-transparent (the selection tween owns it then).
	var centre_tiles: Array = []
	for child in grid.get_children():
		if child is BentoTile:
			centre_tiles.append(child)
	grid.play_entrance(1)
	await _frames(1)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	await create_timer(0.7).timeout
	var opaque := true
	for tile in centre_tiles:
		opaque = opaque and (tile as BentoTile).modulate.a > 0.99
	_check(opaque, "a focus move during the entrance leaves every tile opaque")

	nav.tab_next.emit()
	await _frames(4)
	_check(tab_bar.get_active_tab() == 1, "R1 switches to the next tab")
	_check(not grid.visible, "the centre dashboard hides on another tab")
	var squad_view = hub.get_node("Design/PanelWrap/Body/SquadView")
	_check(squad_view.visible, "the Squad tab shows the squad view")
	_check(not placeholder.visible, "the built Squad tab no longer shows the placeholder")
	_check(career.hub_tab == "squad", "the active tab is stored on the career")
	_check(squad_view.focused_id() == "team",
		"a tab switch from a tile lands on the top-left tile")
	_check(not tab_bar.is_focused(), "the strip does not keep the focus")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(tab_bar.get_tab_button(1).has_focus(),
		"Up from the club tile reaches the active tab")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	_check(squad_view.focused_id() == "team", "Down returns to the top-left tile")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(tab_bar.get_tab_button(1).has_focus(),
		"Up from the club tile reaches the active tab")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	squad_view.handle_moved(Vector2i.RIGHT)
	await _frames(2)
	_check(squad_view.focused_id() == "tile:centre", "Right reaches the Squad Centre tile")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(squad_view.focused_id() == "tile:club",
		"Up from a lower tile walks to the tile above, not the strip")
	_check(not tab_bar.get_tab_button(1).has_focus(),
		"the strip keeps no focus while the page is navigated")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(tab_bar.get_tab_button(1).has_focus(),
		"Up from the top row focuses the active tab")
	_check(squad_view.focused_id() == "", "the page drops its own focus")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(3)
	_check(tab_bar.get_active_tab() == 0, "Left pages the strip to Centre")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(3)
	_check(tab_bar.get_active_tab() == 1, "Right on the strip returns to Squad")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	_check(squad_view.focused_id() == "team", "Down re-enters at the top-left tile")
	squad_view.call("_set_focus", "tile:centre")
	squad_view.handle_confirmed()
	await _frames(3)
	_check(squad_view.current_view() == "centre", "the centre tile opens the squad centre")
	squad_view.call("_set_focus", "centre-tab:0")
	await _frames(2)
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(squad_view.current_view() == "overview",
		"Up from the centre's tab strip returns to the squad overview")
	nav.cancelled.emit()
	await _frames(4)
	_check(tab_bar.get_active_tab() == 0, "Back from another tab returns to Centre")

	# Q/E page the tabs too; from a tile the new page lands on its first tile.
	var e_key := InputEventKey.new()
	e_key.keycode = KEY_E
	e_key.physical_keycode = KEY_E
	e_key.pressed = true
	hub._input(e_key)
	await _frames(3)
	_check(tab_bar.get_active_tab() == 1 and squad_view.focused_id() == "team",
		"E pages tabs from the keyboard and lands on the first tile")
	nav.tab_previous.emit()
	await _frames(3)
	_check(tab_bar.get_active_tab() == 0, "Back to Centre for the transfers checks")

	# Transfers section: the card grid pushes out to the sections and the tabs.
	nav.tab_next.emit()
	nav.tab_next.emit()
	await _frames(6)
	_check(tab_bar.get_active_tab() == 2, "R1 reaches the Transfers tab")
	var transfers_view = hub.get_node("Design/PanelWrap/Body/TransfersView")
	var transfer_hub = transfers_view.get_node_or_null("Hub")
	_check(transfer_hub != null and transfer_hub.visible, "the transfers hub is shown")
	_check(transfer_hub.focused_index() == 0,
		"a tab switch from a tile lands on the reports card")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(tab_bar.get_tab_button(2).has_focus(),
		"Up from the reports card reaches the active tab")
	# Q/E used to be dead on the Transfers landing; from the strip they page.
	hub._input(e_key)
	await _frames(4)
	_check(tab_bar.get_active_tab() == 3 and placeholder.visible,
		"E on the transfers strip pages to Academy")
	var q_key := InputEventKey.new()
	q_key.keycode = KEY_Q
	q_key.physical_keycode = KEY_Q
	q_key.pressed = true
	hub._input(q_key)
	await _frames(4)
	_check(tab_bar.get_active_tab() == 2 and tab_bar.get_tab_button(2).has_focus(),
		"Q returns to the transfers strip")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	_check(transfer_hub.focused_index() == 0,
		"Down enters the transfers landing at the reports card")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(2)
	_check(transfer_hub.focused_index() == 1,
		"Right from the scouting widget reaches the first card")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(tab_bar.get_tab_button(2).has_focus(),
		"Up from SEARCH PLAYERS reaches the active tab")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	_check(transfer_hub.focused_index() == 0, "Down re-enters at the reports card")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(2)
	_check(transfer_hub.focused_index() == 3, "Down from the reports card reaches the lower row")
	nav.moved.emit(Vector2i.UP)
	await _frames(2)
	_check(transfer_hub.focused_index() == 1, "Up from the lower row reaches the card above")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(tab_bar.get_tab_button(2).has_focus(),
		"Up from the top row focuses the active tab")
	nav.moved.emit(Vector2i.UP)
	await _frames(3)
	_check(tab_bar.get_tab_button(2).has_focus() and transfer_hub.focused_index() == 1,
		"Up on the strip leaves the landing focus alone")
	nav.confirmed.emit()
	await _frames(3)
	_check(transfers_view.current_view() == "hub" and transfer_hub.focused_index() == 0,
		"Enter on the strip enters the landing without opening a card")
	transfer_hub.focus_index(4)
	await _frames(2)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(5)
	_check(tab_bar.get_active_tab() == 3,
		"Right from the last transfers card opens the next section")
	_check(placeholder.visible, "ACADEMY shows the placeholder section")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(5)
	_check(tab_bar.get_active_tab() == 4 and placeholder.visible,
		"OFFICE is the last placeholder section")
	for step in CareerHubModel.TABS.size():
		if tab_bar.get_active_tab() == 0:
			break
		nav.tab_previous.emit()
		await _frames(3)
	_check(tab_bar.get_active_tab() == 0, "the tab strip cycles back to Centre")

	# A tab/A edge entry into Transfers must stop on the reports card; the same
	# move must not also walk the landing.
	nav.tab_next.emit()
	await _frames(3)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	squad_view.handle_moved(Vector2i.RIGHT)
	await _frames(2)
	squad_view.handle_moved(Vector2i.UP)
	await _frames(2)
	_check(squad_view.focused_id() == "tile:club", "the right-column tile has the focus")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(5)
	_check(tab_bar.get_active_tab() == 2 and transfer_hub.focused_index() == 0,
		"a Right edge into Transfers stops on the reports card")
	nav.cancelled.emit()
	await _frames(4)
	_check(tab_bar.get_active_tab() == 0, "Back to Centre after the edge entry")

	# The tile's badge counts unread offers: pressing it lands on them directly
	# instead of the transfers landing.
	career.incoming_offers.append({
		"id": "test-offer",
		"player_id": str((catalog.career_squad(131)[0] as Dictionary).get("id", "")),
		"club_id": "11", "status": "pending", "acknowledged": false,
	})
	hub.call("_apply_snapshot")
	transfer_tile.pressed.emit()
	await _frames(4)
	_check(tab_bar.get_active_tab() == 2 and transfers_view.current_view() == "centre",
		"pressing the tile with unread news opens Transfer Centre")
	career.incoming_offers.clear()
	hub.call("_apply_snapshot")
	nav.cancelled.emit()
	await _frames(4)
	nav.cancelled.emit()
	await _frames(4)
	_check(tab_bar.get_active_tab() == 0, "Back from Transfer Centre returns to Centre")

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
