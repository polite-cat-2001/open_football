extends SceneTree
# Headless check for local 2P kickoff: the plan's READY overlay is the shared
# confirmation, so the hub starts on a single Start press (no start vote).

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/open_football_career/data"
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
	for count_index in count:
		await process_frame


func _run() -> void:
	ShellState.clear()
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		_check(false, "the catalog loads")
		_finish()
		return
	ShellState.set_teams(catalog.team_by_id(4941), catalog.team_by_id(4035))
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
		{"side": "away", "kind": "gamepad", "device": 1, "name": "Gamepad"},
	])
	change_scene_to_file(PREMATCH)
	await _frames(10)
	var screen := current_scene
	_check(screen != null and screen.name == "Prematch", "the hub opens")
	if screen == null or screen.name != "Prematch":
		_finish()
		return
	var view: MatchHubView = screen.get("view")
	_check(view != null, "the shared view is mounted")
	if view == null:
		_finish()
		return

	_check(view.command_cell(0).label_text() == "START MATCH",
		"local 2P shows a plain Start command")
	view.start_requested.emit({"kind": "keyboard", "device": 0})
	await _frames(12)
	_check(current_scene != null and current_scene.name == "GpfSlice",
		"a single Start press begins the match")
	_check(ShellState.has_package(), "the hub stored the package")

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: prematch start")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
