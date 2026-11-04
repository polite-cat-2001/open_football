extends SceneTree
# Headless check for the local 2P start vote: each device votes, a repeated
# press withdraws, and the match starts only when every local device agreed.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
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
	ShellState.set_teams(catalog.team_by_id(4), catalog.team_by_id(5))
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

	view.start_requested.emit({"kind": "keyboard", "device": 0})
	await _frames(3)
	_check(view.command_cell(0).label_text() == "START MATCH (1/2)",
		"the first device vote is shown")
	_check(current_scene != null and current_scene.name == "Prematch",
		"one vote does not start the match")
	_check(view.status_text() == "START 1/2", "the status shows the vote tally")

	view.start_requested.emit({"kind": "keyboard", "device": 0})
	await _frames(3)
	_check(view.command_cell(0).label_text() == "START MATCH (0/2)",
		"pressing Start again withdraws the vote")

	view.start_requested.emit({"kind": "keyboard", "device": 0})
	await _frames(2)
	view.start_requested.emit({"kind": "gamepad", "device": 1})
	await _frames(12)
	_check(current_scene != null and current_scene.name == "GpfSlice",
		"all local devices agreeing starts the match")
	_check(ShellState.has_package(), "the hub stored the package")

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: prematch vote")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
