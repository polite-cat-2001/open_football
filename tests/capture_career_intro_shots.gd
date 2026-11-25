extends SceneTree
# Windowed screenshot book for the first-time tournament intro.
#
# Run:  godot --path . -s res://tests/capture_career_intro_shots.gd
# Out:  <data root>/.scratch/ui_shots/career_intro_<id>_1920x1080.png

const HUB_SCENE := "res://scenes/career_hub.tscn"
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football_career/.scratch/ui_shots"
const SIZE := Vector2i(1920, 1080)
const TOURNAMENTS := ["ES1", "CDR", "SUC", "CL"]


func _init() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root():
		push_error("capture_career_intro_shots: " + catalog.error)
		quit(1)
		return
	var career := CareerFactory.create(catalog, 131, "Intro Manager", 189, 42)
	if career == null:
		push_error("capture_career_intro_shots: " + CareerFactory.last_error)
		quit(1)
		return
	CareerSession.career = career
	CareerSession.catalog = catalog
	CareerSaveStore.root_override = "user://career_intro_capture_%d" % Time.get_ticks_usec()
	CareerSession.store = CareerSaveStore.new(CareerSaveStore.root_override)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await _frames(2)
	for competition_id in TOURNAMENTS:
		await _capture(career, catalog, str(competition_id))
	# A second-tier club, so the Championship card shows its own season shape.
	var segunda: Array = catalog.all_teams_for_league("ES2")
	if not segunda.is_empty():
		var spanish := CareerFactory.create(catalog,
			int(str((segunda[0] as Dictionary).get("id", "0"))), "Segunda", 189, 42)
		if spanish != null:
			CareerSession.career = spanish
			await _capture(spanish, catalog, "ES2")
			CareerSession.career = career
	var championship: Array = catalog.all_teams_for_league("GB2")
	if not championship.is_empty():
		var club_id := int((championship[0] as Dictionary).get("id", 0))
		var lower := CareerFactory.create(catalog, club_id, "Lower League", 189, 42)
		if lower != null:
			CareerSession.career = lower
			await _capture(lower, catalog, "GB2")
			CareerSession.career = career
	print("captured the tournament intro")
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	quit(0)


func _capture(career: Career, catalog: TeamCatalog, competition_id: String) -> void:
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
	hub.set("_intro_queue", [CareerIntro.facts(career, competition_id, catalog)])
	hub.call("_show_intro")
	await _frames(20)
	await RenderingServer.frame_post_draw
	var path := "%s/career_intro_%s_%dx%d.png" % [OUT_DIR, competition_id, SIZE.x, SIZE.y]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_career_intro_shots: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_career_intro_shots: save failed %s (%d)" % [path, error])
		else:
			print("  ", path)
	viewport.queue_free()
