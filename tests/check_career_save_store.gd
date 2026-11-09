extends SceneTree
# Headless checks for the career JSON store: prototype-save compatibility,
# version rejection, save round-trip and latest ordering.
#
# Run:  godot --headless --path . -s res://tests/check_career_save_store.gd

const PROTOTYPE_SAVE := "res://tests/fixtures/career_save_prototype.json"

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


func _finish() -> void:
	_cleanup()
	print("== check_career_save_store: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_store_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	var store := CareerSaveStore.new(_directory)
	_check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_directory)),
		"the test save directory exists")

	var text := FileAccess.get_file_as_string(PROTOTYPE_SAVE)
	var prototype = JSON.parse_string(text)
	_check(prototype is Dictionary, "the prototype fixture parses")
	if not (prototype is Dictionary):
		_finish()
		return
	var prototype_id := str(prototype["id"])
	_write(prototype_id, text)
	var loaded := store.load_career(prototype_id)
	_check(loaded != null, "a prototype save loads without conversion: " + store.last_error)
	if loaded != null:
		_check(loaded.version == 1, "the prototype version is accepted")
		_check(loaded.club_id == "11", "the prototype club id is preserved")
		_check(loaded.player_ids.size() == 29, "the prototype squad is preserved")
		_check(loaded.manager.name == "Алексей Смирнов", "the prototype manager is preserved")
		_check(loaded.data.has("journal"), "unknown prototype fields are preserved")
		_check(loaded.season_start == Career.START_DATE,
			"a missing season_start gets the prototype default")
		_check(store.save(loaded), "the loaded prototype save can be written back")
		var reloaded := store.load_career(prototype_id)
		_check(reloaded != null and reloaded.to_save() == loaded.to_save(),
			"the prototype save survives a save/load round-trip")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	var career := CareerFactory.create(catalog, 131, "Round Trip", 189, 7)
	_check(career != null, "a career is created for the round-trip test")
	if career != null:
		_check(store.save(career), "the career is saved: " + store.last_error)
		var fresh := CareerSaveStore.new(_directory)
		var read_back := fresh.load_career(career.id)
		_check(read_back != null, "a second store instance loads the saved career")
		if read_back != null:
			_check(read_back.to_save() == career.to_save(),
				"the saved JSON round-trips exactly")
			_check(read_back.seed == 7 and read_back.club_id == "131",
				"the seed and club survive the round-trip")
			_check(read_back.schedule.size() == 380, "the schedule survives the round-trip")

		var wrong_version := career.to_save()
		wrong_version["version"] = 2
		_write("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", JSON.stringify(wrong_version))
		var rejected := store.load_career("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
		_check(rejected == null, "a save with a different version is rejected")
		_check(store.last_error_kind == "version", "the rejection is reported as a version error")
		_check(store.last_error.contains("version 2"), "the error names the found version")

		var missing_version := career.to_save()
		missing_version.erase("version")
		_write("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", JSON.stringify(missing_version))
		_check(store.load_career("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") == null
			and store.last_error_kind == "version",
			"a save without a version is rejected")

		var malformed := FileAccess.open(
			_directory.path_join("cccccccccccccccccccccccccccccccc.json"), FileAccess.WRITE)
		malformed.store_string("{")
		malformed.close()
		_check(store.load_career("cccccccccccccccccccccccccccccccc") == null
			and store.last_error_kind == "format",
			"an unreadable save is rejected as malformed")

		var older := CareerFactory.create(catalog, 418, "Older", 189, 8)
		if older != null:
			older.data["updated_at"] = "2026-01-01T00:00:00.000000Z"
			career.data["updated_at"] = "2026-12-31T00:00:00.000000Z"
			store.save(older)
			store.save(career)
			var latest := store.latest()
			_check(latest != null and latest.id == career.id,
				"latest returns the most recently updated compatible career")
			var compatible := 0
			for entry in store.scan():
				if entry["career"] != null:
					compatible += 1
			_check(compatible == 3,
				"scan counts the prototype save and both generated careers as compatible")

	_finish()


func _write(career_id: String, text: String) -> void:
	var path := _directory.path_join(career_id + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


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
