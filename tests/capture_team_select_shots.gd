extends SceneTree
# Windowed screenshot book for the shared team-select view.
#
# Run:  godot --path . -s res://tests/capture_team_select_shots.gd
# Out:  .scratch/ui_shots/team_select_<state>_<WxH>.png

const VIEW_SCENE := preload("res://scenes/ui/team_select_view.tscn")
const FIXTURE := preload("res://tests/team_select_fixture.gd")
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football/.scratch/ui_shots"
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const STATES := [
	{"name": "local_1p_home", "state": "state_1p"},
	{"name": "local_1p_away", "state": "state_away"},
	{"name": "local_2p", "state": "state_2p"},
	{"name": "network", "state": "state_network"},
	{"name": "network_ready", "state": "state_network_ready"},
	{"name": "error", "state": "state_error"},
]

var saved := 0


func _init() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await _frames(2)
	for size in SIZES:
		for state in STATES:
			await _capture(state, size)
		await _capture_real(size)
		await _capture_real(size, true)
		await _capture_real(size, true, "competition")
	print("captured ", saved, " team-select screenshots into ", OUT_DIR)
	quit(0)


func _capture(state: Dictionary, size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view: TeamSelectView = VIEW_SCENE.instantiate()
	host.add_child(view)
	await _frames(4)
	var data: Dictionary
	match String(state["state"]):
		"state_1p":
			data = FIXTURE.state_1p()
		"state_away":
			data = FIXTURE.state_away()
		"state_2p":
			data = FIXTURE.state_2p()
		"state_network":
			data = FIXTURE.state_network()
		"state_network_ready":
			data = FIXTURE.state_network_ready()
		_:
			data = FIXTURE.state_error()
	view.setup(data, {"back_label": "leave"})
	await _frames(4)
	await RenderingServer.frame_post_draw
	var path := "%s/team_select_%s_%dx%d.png" % [
		OUT_DIR,
		String(state["name"]),
		size.x,
		size.y,
	]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_team_select_shots: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_team_select_shots: save failed %s (%d)" % [path, error])
		else:
			saved += 1
			print("  ", path)
	viewport.queue_free()
	await _frames(1)


func _capture_real(size: Vector2i, club := false, focus := "") -> void:
	ShellState.clear()
	if club:
		var catalog := TeamCatalog.new()
		if catalog.load_data_root(""):
			ShellState.set_teams(catalog.team_by_id(4941), catalog.team_by_id(4035))
		catalog.close()
	var packed := load("res://scenes/team_select.tscn") as PackedScene
	if packed == null:
		push_error("capture_team_select_shots: team_select.tscn did not load")
		return
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: Control = packed.instantiate()
	viewport.add_child(screen)
	await _frames(12)
	if not focus.is_empty():
		var view: TeamSelectView = screen.get("view")
		if view != null:
			view.set_focus(0, focus)
			await _frames(2)
	await RenderingServer.frame_post_draw
	var suffix := "_club" if club else ""
	if not focus.is_empty():
		suffix += "_" + focus
	var path := "%s/team_select_real%s_%dx%d.png" % [OUT_DIR, suffix, size.x, size.y]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_team_select_shots: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_team_select_shots: save failed %s (%d)" % [path, error])
		else:
			saved += 1
			print("  ", path)
	viewport.queue_free()
	await _frames(1)
