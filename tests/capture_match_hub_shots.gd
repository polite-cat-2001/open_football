extends SceneTree
# Windowed screenshot book for the shared match hub.
#
# Run:  godot --path . -s res://tests/capture_match_hub_shots.gd
# Out:  .scratch/ui_shots/match_hub_<state>_<WxH>.png

const VIEW_SCENE := preload("res://scenes/ui/match_hub_view.tscn")
const FIXTURE := preload("res://tests/match_hub_fixture.gd")
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football/.scratch/ui_shots"
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const STATES := [
	{"name": "local_1p", "state": "state_1p"},
	{"name": "local_2p", "state": "state_2p"},
	{"name": "network_host", "state": "state_network_host"},
	{"name": "network_client", "state": "state_network_client"},
	{"name": "game_plan", "state": "state_1p", "overlay": "game_plan"},
	{"name": "options", "state": "state_1p", "overlay": "options"},
	{"name": "exit_selected", "state": "state_1p", "select": 3},
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
	print("captured ", saved, " match-hub screenshots into ", OUT_DIR)
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
	var view: MatchHubView = VIEW_SCENE.instantiate()
	host.add_child(view)
	await _frames(4)
	var data: Dictionary
	match String(state["state"]):
		"state_2p":
			data = FIXTURE.state_2p()
		"state_network_host":
			data = FIXTURE.state_network_host()
		"state_network_client":
			data = FIXTURE.state_network_client()
		_:
			data = FIXTURE.state_1p()
	view.setup(data, {"back_label": "back"})
	if state.has("overlay"):
		match String(state["overlay"]):
			"game_plan":
				view.setup_game_plan(FIXTURE.lineup_model(0), FIXTURE.lineup_model(1), [0])
				view.open_game_plan()
			"options":
				view.open_options()
	if state.has("select"):
		view.call("_set_command_index", int(state["select"]), true)
	await _frames(12)
	await RenderingServer.frame_post_draw
	var path := "%s/match_hub_%s_%dx%d.png" % [
		OUT_DIR,
		String(state["name"]),
		size.x,
		size.y,
	]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_match_hub_shots: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_match_hub_shots: save failed %s (%d)" % [path, error])
		else:
			saved += 1
			print("  ", path)
	viewport.queue_free()
	await _frames(1)
