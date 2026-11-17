extends SceneTree
# Headless UI check for the ported TeamSelectPage on the design system: two
# always-visible HOME/AWAY cards, ready from any focused block, the 1P
# home -> CPU-away flow, and the lazy catalog.

const TEAM_SELECT := "res://scenes/team_select.tscn"
const HOME_ID := 4941
const AWAY_ID := 4035
const UI_ASSETS := preload("res://scripts/data/ui_assets.gd")

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


func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event


func _tap_key(code: int) -> void:
	Input.parse_input_event(_key(code, true))
	await _frames(2)
	Input.parse_input_event(_key(code, false))
	await _frames(1)


func _run() -> void:
	ShellState.clear()
	change_scene_to_file(TEAM_SELECT)
	await _frames(12)
	var screen := current_scene
	_check(screen != null and screen.name == "TeamSelect", "the team selection screen opens")
	if screen == null or screen.name != "TeamSelect":
		_finish()
		return

	var view: TeamSelectView = screen.get("view")
	var catalog: TeamCatalog = screen.get("catalog")
	_check(view != null, "the shared TeamSelectView is mounted")
	_check(catalog != null and catalog.is_loaded(), "the lazy catalog opened")
	_check(catalog != null and not catalog.countries().is_empty(),
		"countries are available on demand")
	var sides := view.sides()
	_check(sides.size() == 2, "the view has two side snapshots")
	_check(bool(sides[0].get("live", false)), "1P starts on the home side")
	_check(not bool(sides[1].get("live", false)), "the CPU away side is idle")
	_check(view.get_node("Design/PanelWrap/Teams/AwayPanel").modulate.a
		< 0.99, "the idle away panel is dimmed")
	_check(int(String(sides[0].get("team", {}).get("id", "0")))
		== ShellState.DEFAULT_HOME_TEAM_ID,
		"FC Barcelona is the default home team")
	_check(int(String(sides[1].get("team", {}).get("id", "0")))
		== ShellState.DEFAULT_AWAY_TEAM_ID,
		"Real Madrid is the default away team")

	# The picker must show the shipped emblem (`career_logo`), not the stale
	# id-keyed copy under databases/default/images_teams.
	var home_team: Dictionary = sides[0].get("team", {})
	var home_emblem := UI_ASSETS.load_texture(
		str(home_team.get("career_logo", "")).trim_prefix("/"))
	_check(home_emblem != null and UI_ASSETS.team_logo(home_team) == home_emblem,
		"the home club card shows its shipped emblem")

	# Focus is local to the view; Up/Down clamps inside the panel.
	_check(view.focus_for(0) == "team", "the club block is focused by default")
	await _tap_key(KEY_UP)
	_check(view.focus_for(0) == "country", "Up moves focus to the country block")
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_DOWN)
	_check(view.focus_for(0) == "competition", "Down reaches the competition block")
	await _tap_key(KEY_DOWN)
	_check(view.focus_for(0) == "competition", "Down clamps at the bottom block")

	# A known pair is restored deterministically, then both ready presses commit.
	screen.call("_restore_team", 0, HOME_ID)
	screen.call("_restore_team", 1, AWAY_ID)
	screen.call("_refresh")
	await _frames(3)
	sides = view.sides()
	_check(int(String(sides[0].get("team", {}).get("id", "0"))) == HOME_ID,
		"the home team is restored")
	_check(int(String(sides[1].get("team", {}).get("id", "0"))) == AWAY_ID,
		"the away team is restored")
	_check(String(sides[0].get("team", {}).get("name", "")) != "",
		"the home team has a name")
	_check(float(sides[0].get("rating", {}).get("stars", 0.0)) > 0.0,
		"the home team shows a rating")

	# National teams have no club emblem: the card must use their own logo file,
	# and a missing file must leave no crest (never another club's).
	var models: Array = screen.get("sides")
	models[0]["country_index"] = 0
	screen.call("_apply_country", models[0])
	screen.call("_refresh")
	await _frames(3)
	sides = view.sides()
	var national: Dictionary = sides[0].get("team", {})
	_check(str(national.get("league_id", "")) == "NAT",
		"the National Teams list is reachable")
	var national_logo := UI_ASSETS.load_texture(
		"databases/default/" + str(national.get("logo_url", "")))
	var shown_national := UI_ASSETS.usable_texture(UI_ASSETS.team_logo(national))
	_check(shown_national == national_logo,
		"a national team shows its own logo file or none, never another club's crest")
	screen.call("_restore_team", 0, HOME_ID)
	screen.call("_refresh")
	await _frames(3)

	await _tap_key(KEY_ENTER)
	await _frames(3)
	sides = view.sides()
	_check(bool(sides[0].get("ready", false)), "Enter marks the home panel ready")
	_check(bool(sides[1].get("live", false)), "Ready reveals the CPU away panel")
	_check((view.get_node("Design/PanelWrap/Teams/HomePanel") as TeamPanel).ready_marks_visible(),
		"the ready panel renders its dark ready state")
	await _tap_key(KEY_ENTER)
	await _frames(10)
	_check(current_scene != null and current_scene.name == "KitSelect",
		"both sides ready opens the kit selection")
	_check(int(ShellState.home_team.get("id", 0)) == HOME_ID
		and int(ShellState.away_team.get("id", 0)) == AWAY_ID,
		"the chosen teams land in the shell state")

	# A missing database is a readable error and Enter retries the load.
	ShellState.clear()
	var broken = load(TEAM_SELECT).instantiate()
	broken.data_root = "Z:/no-such-gpf-data"
	root.add_child(broken)
	await _frames(3)
	var broken_view: TeamSelectView = broken.get("view")
	_check(broken_view.status_text().contains("not found"),
		"a missing database is reported: " + broken_view.status_text())
	broken.data_root = ""
	broken.call("_reload")
	await _frames(6)
	_check(not broken_view.status_text().contains("not found"),
		"retry reloads the catalog after the path is fixed")
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
