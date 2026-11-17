extends SceneTree
# Guards UI text against the CP1251 round-trip that once stored arrows and the
# middle dot as mojibake characters (a player saw them in the hint bar).
#
# Run:  godot --headless --path . -s res://tests/check_ui_text_encoding.gd

const ROOTS := ["res://scripts", "res://scenes"]
# The cp1251 round-trip turned each of these into a paragraph of junk.
const BROKEN := [
	"\u0432\u2020\u0452", # left arrow
	"\u0432\u2020\u2019", # right arrow
	"\u0432\u2020\u2018", # up arrow
	"\u0432\u2020\u201C", # down arrow
	"\u0412\u00B7",       # middle dot
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for root in ROOTS:
		_scan(root)
	print("== check_ui_text_encoding: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		var full := path.path_join(name)
		if dir.current_is_dir():
			_scan(full)
		elif name.ends_with(".gd") or name.ends_with(".tscn"):
			_check_file(full)
		name = dir.get_next()
	dir.list_dir_end()


func _check_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	for sequence in BROKEN:
		if text.contains(sequence):
			failures.append("%s stores broken text instead of a glyph" % path)
			return
