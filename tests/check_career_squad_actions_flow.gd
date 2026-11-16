extends SceneTree
# Headless check for the squad player-action row (ticket 06) hosted by the hub:
# centre row -> actions row -> contract talks screen -> back.
#
# Run:  godot --headless --path . -s res://tests/check_career_squad_actions_flow.gd

const HUB := "res://scenes/career_hub.tscn"

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
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	print("== check_career_squad_actions_flow: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_actions_flow_test_%d" % Time.get_ticks_usec()
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
	store.save(career)
	CareerSession.career = career
	CareerSession.catalog = catalog
	CareerSession.store = store
	career.hub_tab = "squad"

	var hub := (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	await _frames(4)

	var view = hub.get_node("Design/PanelWrap/Body/SquadView")
	var breadcrumb: UiBreadcrumb = hub.get_node("Design/PanelWrap/Body/Breadcrumb")
	_check(view.visible, "the Squad tab shows the squad view")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	view.handle_moved(Vector2i.RIGHT)
	view.handle_confirmed()
	await _frames(3)
	_check(view.current_view() == "centre", "the Squad Centre opens")
	_check(view.focused_id().begins_with("centre-row:"), "a player row owns the focus")
	var player_id: String = str(view.focused_id()).replace("centre-row:", "")
	view.handle_confirmed()
	await _frames(2)
	var row = view.get("_actions_row")
	_check(row != null, "A on a player row slides in the actions row")
	_check(row.action_ids().size() > 0, "the actions row has columns and actions")
	row.action_requested.emit("renew", player_id)
	await _frames(4)
	var screen = hub.get("_squad_screen")
	_check(screen != null, "RENEW CONTRACT opens the contract talks screen")
	_check(breadcrumb.visible, "the contract talks screen shows a breadcrumb")
	_check((breadcrumb.get_child(2) as Label).text == "CONTRACT TALKS",
		"the breadcrumb names the screen")
	_check(not (hub.get_node("Design/PanelWrap/Body/TabBar") as Control).visible,
		"the tabs stay hidden under the screen")
	screen.closed.emit()
	await _frames(4)
	_check(hub.get("_squad_screen") == null, "Back closes the contract talks screen")
	_check(view.visible, "the squad centre returns")
	_check(not breadcrumb.visible, "the breadcrumb hides with the screen")
	_check(view.focused_id().begins_with("centre-row:"),
		"focus returns to the player row")
	_finish()
