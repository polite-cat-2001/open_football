extends SceneTree
# Windowed screenshot book for the tournament-rules popup: the card a career club
# sees the first time it reaches a competition.
#
# Run:  godot --path . -s res://tests/capture_tournament_rules.gd -- RUP RU1 2DVB
#       add club:<id> to start the career at another club (default: the first RU1 club)
# Out:  <data root>/.scratch/ui_shots/tournament_rules_<id>_1920x1080.png

const HUB_SCENE := "res://scenes/career_hub.tscn"
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football_career/.scratch/ui_shots"
const SIZE := Vector2i(1920, 1080)
const DEFAULT_IDS := ["RUP", "RU1", "RUSS", "2DVB", "GB2", "CL"]


func _init() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _run() -> void:
	var ids: Array = []
	var club_override := 0
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("club:"):
			club_override = int(str(arg).substr(5))
		else:
			ids.append(str(arg))
	if ids.is_empty():
		ids = DEFAULT_IDS
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root():
		push_error("capture_tournament_rules: " + catalog.error)
		quit(1)
		return
	var club_id := club_override
	if club_id <= 0:
		var teams: Array = catalog.all_teams_for_league("RU1")
		if teams.is_empty():
			push_error("capture_tournament_rules: no Russian league")
			quit(1)
			return
		club_id = int(str((teams[0] as Dictionary).get("id", "0")))
	var career := CareerFactory.create(catalog, club_id, "Rules Manager", 189, 42)
	if career == null:
		push_error("capture_tournament_rules: " + CareerFactory.last_error)
		quit(1)
		return
	CareerSession.career = career
	CareerSession.catalog = catalog
	CareerSaveStore.root_override = "user://tournament_rules_capture_%d" % Time.get_ticks_usec()
	CareerSession.store = CareerSaveStore.new(CareerSaveStore.root_override)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await _frames(2)
	for competition_id in ids:
		var facts := CareerIntro.facts(career, str(competition_id), catalog)
		if (facts.get("lines", []) as Array).is_empty():
			print("  skip ", competition_id, " (no lines)")
			continue
		await _capture(facts, str(competition_id))
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	quit(0)


func _capture(facts: Dictionary, competition_id: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hub: Control = (load(HUB_SCENE) as PackedScene).instantiate()
	host.add_child(hub)
	await _frames(10)
	hub.set("_intro_queue", [facts])
	hub.call("_show_intro")
	await _frames(20)
	await RenderingServer.frame_post_draw
	var path := "%s/tournament_rules_%s_%dx%d.png" % [OUT_DIR, competition_id, SIZE.x, SIZE.y]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_tournament_rules: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_tournament_rules: save failed %s (%d)" % [path, error])
		else:
			print("  ", path)
	viewport.queue_free()
