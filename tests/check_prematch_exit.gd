extends SceneTree
# Regression check: the hub's EXIT command returns to the main menu.

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
	])
	change_scene_to_file(PREMATCH)
	await _frames(10)
	var screen := current_scene
	_check(screen != null and screen.name == "Prematch", "the hub opens")
	if screen == null or screen.name != "Prematch":
		_finish()
		return
	var view: MatchHubView = screen.get("view")
	_check(view != null and view.command_cell(3).label_text() == "EXIT",
		"the fourth command is EXIT")
	if view == null:
		_finish()
		return
	view.command_cell(3).pressed.emit()
	await _frames(10)
	_check(current_scene != null and current_scene.name == "MainMenu",
		"EXIT returns to the main menu")
	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: prematch exit")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
