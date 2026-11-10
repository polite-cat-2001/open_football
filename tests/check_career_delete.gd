extends SceneTree
# Delete-save modal: Del/X opens it, Cancel keeps the file, Delete removes it,
# and Escape only closes the modal (never the Load screen).

const LOAD := "res://scenes/career_load.tscn"

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


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)


func _finish() -> void:
	_cleanup()
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	print("== check_career_delete: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_delete_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	CareerSession.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens")
	var career := CareerFactory.create(catalog, 11, "Delete Me", 189, 42)
	_check(career != null, "career fixture is created")
	if career == null:
		_finish()
		return
	var store := CareerSaveStore.new()
	_check(store.save(career), "career fixture is saved")

	change_scene_to_file(LOAD)
	await _frames(10)
	var load_screen := current_scene
	_check(load_screen != null and load_screen.name == "CareerLoad", "Load opens")
	if load_screen == null:
		_finish()
		return
	var modal = load_screen.get("_delete_modal")
	var rows: Array = load_screen.get("_rows")
	_check(rows.size() == 1, "the save row is listed")
	_check(modal != null and not modal.is_open(), "the delete modal starts closed")

	_key(KEY_DELETE)
	await _frames(3)
	_check(modal.is_open(), "Del opens the delete modal")
	modal._rows[1].pressed.emit()
	await _frames(3)
	_check(not modal.is_open(), "Cancel closes the modal")
	_check(store.load_career(career.id) != null, "Cancel keeps the save")

	_key(KEY_DELETE)
	await _frames(3)
	_check(modal.is_open(), "Del reopens the delete modal")
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(not modal.is_open(), "Escape closes the modal")
	_check(current_scene != null and current_scene.name == "CareerLoad",
		"Escape keeps the Load screen")
	_check(store.load_career(career.id) != null, "Escape keeps the save")

	_key(KEY_DELETE)
	await _frames(3)
	_check(modal.is_open(), "Del opens the delete modal again")
	var nav := root.get_node("UiNav")
	nav.confirmed.emit()
	await _frames(5)
	_check(not modal.is_open(), "Delete closes the modal")
	_check(store.load_career(career.id) == null, "Delete removes the save file")
	rows = load_screen.get("_rows")
	_check(rows.is_empty(), "the deleted row disappears")
	var empty: Control = load_screen.get_node("Design/PanelWrap/Body/Empty")
	_check(empty.visible, "the empty state is shown")

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
