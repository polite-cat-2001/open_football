extends SceneTree
# Headless UI check for the ported TeamSelectPage: two side panels with
# Country/Competition/Team carousels and Ready, a single keyboard player picks
# the home then the CPU away side, and the chosen pair lands in ShellState.
#
# Run:  godot --headless --path . -s res://tests/check_team_select_ui.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const TEAM_SELECT := "res://scenes/team_select.tscn"
const HOME_ID := 4
const AWAY_ID := 5

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
	for i in count:
		await process_frame


func _run() -> void:
	ShellState.clear()
	change_scene_to_file(TEAM_SELECT)
	await _frames(10)
	var screen := current_scene
	_check(screen != null and screen.name == "TeamSelect", "the team selection screen opens")
	if screen == null or screen.name != "TeamSelect":
		_finish()
		return

	var panels: Array = screen.get("panels")
	_check(panels.size() == 2, "the screen has two side panels")
	var catalog: TeamCatalog = screen.get("catalog")
	_check(catalog != null and not catalog.leagues.is_empty(),
		"the catalog is loaded behind the carousels")
	_check(catalog != null and not catalog.countries.is_empty(),
		"the country carousel has entries")

	var home := catalog.team_by_id(HOME_ID) if catalog != null else {}
	var away := catalog.team_by_id(AWAY_ID) if catalog != null else {}
	_check(not home.is_empty() and not away.is_empty(), "the test teams exist")
	if home.is_empty() or away.is_empty():
		_finish()
		return

	# Carousel movement repopulates the dependent rows.
	var country_row = panels[0]["rows"][0]
	var before_country := int(country_row.get("selected"))
	screen.call("_move_selection", 0, 1)
	_check(int(country_row.get("selected")) != before_country,
		"Left/Right moves the country carousel")
	_check(not panels[0]["rows"][1].get("entries").is_empty(),
		"the competition/team rows follow the country")

	screen.call("_restore_team", 0, HOME_ID)
	screen.call("_restore_team", 1, AWAY_ID)
	var home_selected: Dictionary = panels[0]["rows"][2].selected_entry()
	var away_selected: Dictionary = panels[1]["rows"][2].selected_entry()
	_check(str(home_selected.get("id", "")) == str(HOME_ID),
		"the home team is restored in its carousel")
	_check(str(away_selected.get("id", "")) == str(AWAY_ID),
		"the away team is restored in its carousel")

	# A lone keyboard starts on the human's side; Ready reveals the CPU side,
	# whose Ready commits the pair and opens the hub.
	screen.call("_set_ready", 0, true)
	await _frames(1)
	_check(bool(screen.get("side_active")[1]), "Ready reveals the CPU away panel")
	screen.call("_set_ready", 1, true)
	await _frames(10)
	_check(current_scene != null and current_scene.name == "Prematch",
		"both sides ready opens the pre-match hub")
	_check(int(ShellState.home_team.get("id", 0)) == HOME_ID
		and int(ShellState.away_team.get("id", 0)) == AWAY_ID,
		"the chosen teams land in the shell state")

	# A missing database is a readable error, not an empty screen.
	ShellState.clear()
	var broken = load(TEAM_SELECT).instantiate()
	broken.data_root = "Z:/no-such-gpf-data"
	root.add_child(broken)
	await _frames(3)
	_check(broken.status_label.text.contains("not found"),
		"a missing database is reported: " + broken.status_label.text)
	broken.queue_free()

	ShellState.clear()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: team select UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
