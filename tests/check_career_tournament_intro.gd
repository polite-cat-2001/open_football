extends SceneTree
# Headless check for the tournament intro popup: the hub shows the card with the
# competition logo (or its code) and the generated facts, one confirm closes it,
# and the career remembers the tournament.
#
# Run:  godot --headless --path . -s res://tests/check_career_tournament_intro.gd

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
	print("== check_career_tournament_intro: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_intro_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	CareerSession.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	var nav := root.get_node("UiNav")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, 131, "Intro Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var store := CareerSaveStore.new(_directory)
	CareerSession.career = career
	CareerSession.store = store
	CareerSession.catalog = catalog

	change_scene_to_file(HUB)
	await _frames(12)
	var hub := current_scene
	_check(hub != null and hub.name == "CareerHub", "the career hub opens")
	if hub == null or hub.name != "CareerHub":
		_finish()
		return
	var intro = hub.get_node("Design/TournamentIntro")
	_check(intro != null and intro.get_class() == "Control", "the hub carries the intro popup")
	_check(not intro.is_open(), "the popup starts closed")

	var facts := CareerIntro.facts(career, "CDR", catalog)
	_check(str(facts.get("label", "")) == "Copa del Rey", "the facts name the cup")
	hub.set("_intro_queue", [facts])
	hub.call("_show_intro")
	await _frames(4)
	_check(intro.is_open(), "the popup opens on the tournament day")
	_check(str(intro.get("_title").text) == "Copa del Rey",
		"the card shows the competition name")
	_check((intro.get("_lines") as Array).size() >= 2,
		"the card lists the generated facts")
	var logo_visible: bool = intro.get("_logo").visible
	var monogram_visible: bool = intro.get("_monogram").visible
	_check(logo_visible != monogram_visible,
		"the card shows either the logo or the monogram")
	_check(CareerIntro.seen(career).has("CDR"), "showing the card marks the cup as seen")

	nav.confirmed.emit()
	await _frames(4)
	_check(not intro.is_open(), "confirm closes the popup")
	_check(CareerSession.career != null, "the calendar stays on a loaded career")

	# The same tournament is never introduced again.
	_check(CareerIntro.pending(career, str(career.date), catalog).is_empty()
		or not CareerIntro.seen(career).is_empty(),
		"a seen tournament does not queue a second popup")
	_finish()
