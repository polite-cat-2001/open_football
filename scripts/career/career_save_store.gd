class_name CareerSaveStore
extends RefCounted
# JSON career saves in the prototype's shape. Layout mirrors
# server/career/saves.py: <id>.json, version checked on load.

const DEFAULT_DIRECTORY := "user://career/saves"
const SAVE_ID_PATTERN := "^[0-9a-f]{32}$"

static var root_override := ""

var directory := ""
var last_error := ""
var last_error_kind := ""

var _regex := RegEx.new()


func _init(path := "") -> void:
	directory = path if not path.is_empty() else default_directory()
	_regex.compile(SAVE_ID_PATTERN)


static func default_directory() -> String:
	return root_override if not root_override.is_empty() else DEFAULT_DIRECTORY


func ensure_directory() -> bool:
	var global := ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(global)
	if error != OK:
		last_error = "Cannot create save directory: %s" % error
		return false
	return true


func path_for(career_id: String) -> String:
	if _regex.search(career_id) == null:
		return ""
	return directory.path_join(career_id + ".json")


func save(career: Career) -> bool:
	last_error = ""
	last_error_kind = ""
	var path := path_for(career.id)
	if path.is_empty():
		last_error = "Save id must be 32 lowercase hex characters."
		last_error_kind = "not_found"
		return false
	if not ensure_directory():
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Save %s is not writable." % career.id
		last_error_kind = "format"
		return false
	file.store_string(JSON.stringify(career.to_save(), "  ", false))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(path)
	)
	if error != OK:
		last_error = "Save %s is not writable." % career.id
		last_error_kind = "format"
		return false
	return true


func delete(career_id: String) -> bool:
	last_error = ""
	last_error_kind = ""
	var path := path_for(career_id)
	if path.is_empty() or not FileAccess.file_exists(path):
		last_error = "Save %s was not found." % career_id
		last_error_kind = "not_found"
		return false
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		last_error = "Save %s could not be deleted." % career_id
		last_error_kind = "format"
		return false
	return true


func load_career(career_id: String) -> Career:
	last_error = ""
	last_error_kind = ""
	var path := path_for(career_id)
	if path.is_empty() or not FileAccess.file_exists(path):
		last_error = "Save %s was not found." % career_id
		last_error_kind = "not_found"
		return null
	var text := FileAccess.get_file_as_string(path)
	var raw = _parse_json(text)
	if not (raw is Dictionary):
		last_error = "Save %s is unreadable." % career_id
		last_error_kind = "format"
		return null
	var found = raw.get("version")
	var parsed := -1
	if found != null and (found is int or found is float):
		parsed = int(found)
	elif found is String and found.is_valid_int():
		parsed = int(found)
	if parsed != Career.SAVE_VERSION:
		var label := "is missing" if found == null else "%s is not supported" % str(found)
		last_error = ("Save version %s; this build requires version %d. " + \
			"Migrations are not available: start a new career or use a matching build."
			) % [label, Career.SAVE_VERSION]
		last_error_kind = "version"
		return null
	var career := Career.from_save(raw)
	if career == null:
		last_error = "Save %s is malformed: %s" % [career_id, Career.last_error]
		last_error_kind = "format"
		return null
	return career


func scan() -> Array:
	last_error = ""
	last_error_kind = ""
	var entries: Array = []
	if not ensure_directory():
		return entries
	var dir := DirAccess.open(directory)
	if dir == null:
		return entries
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.ends_with(".json"):
			var career_id := name.get_basename()
			var entry := {"id": career_id, "career": null, "raw": null, "error": ""}
			var career := load_career(career_id)
			if career != null:
				entry["career"] = career
			else:
				entry["error"] = last_error
				var raw = _parse_json(
					FileAccess.get_file_as_string(directory.path_join(name)))
				entry["raw"] = raw if raw is Dictionary else null
			entries.append(entry)
		name = dir.get_next()
	dir.list_dir_end()
	return entries


func _parse_json(text: String):
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.get_data()


func list() -> Array:
	var careers: Array = []
	for entry in scan():
		if entry["career"] != null:
			careers.append(entry["career"])
	careers.sort_custom(func(a: Career, b: Career) -> bool:
		if a.updated_at != b.updated_at:
			return a.updated_at > b.updated_at
		return a.id > b.id)
	return careers


func latest() -> Career:
	var careers := list()
	return careers[0] if not careers.is_empty() else null
