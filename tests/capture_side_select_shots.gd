extends SceneTree
# Windowed screenshot book for the shared side-select view.
#
# Run:  godot --path . -s res://tests/capture_side_select_shots.gd
# Out:  .scratch/ui_shots/side_select_<state>_<WxH>.png

const VIEW_SCENE := preload("res://scenes/ui/side_select_view.tscn")
const FIXTURE := preload("res://tests/side_select_fixture.gd")
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football/.scratch/ui_shots"
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const STATES := [
	{
		"name": "1p",
		"rows": "rows_1p",
		"options": {
			"input_mode": "devices",
			"show_names": false,
			"back_label": "leave",
		},
	},
	{
		"name": "2p",
		"rows": "rows_2p",
		"options": {
			"input_mode": "devices",
			"show_names": false,
			"back_label": "leave",
		},
	},
	{
		"name": "ready",
		"rows": "rows_ready",
		"options": {
			"input_mode": "devices",
			"show_names": false,
			"back_label": "leave",
		},
	},
	{
		"name": "network",
		"rows": "rows_network",
		"options": {
			"input_mode": "local_player",
			"show_names": true,
			"back_label": "leave",
		},
	},
	{
		"name": "network_resume",
		"rows": "rows_network",
		"options": {
			"input_mode": "local_player",
			"show_names": true,
			"back_label": "back",
			"overlay": true,
			"status": "leaving side selection...",
		},
	},
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
	print("captured ", saved, " side-select screenshots into ", OUT_DIR)
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
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.13, 0.08)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view: SideSelectView = VIEW_SCENE.instantiate()
	host.add_child(view)
	await _frames(4)
	var rows: Array = []
	match String(state["rows"]):
		"rows_1p":
			rows = FIXTURE.rows_1p()
		"rows_2p":
			rows = FIXTURE.rows_2p()
		"rows_ready":
			rows = FIXTURE.rows_ready()
		_:
			rows = FIXTURE.rows_network()
	view.setup(rows, state["options"])
	await _frames(4)
	await RenderingServer.frame_post_draw
	var path := "%s/side_select_%s_%dx%d.png" % [
		OUT_DIR,
		String(state["name"]),
		size.x,
		size.y,
	]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_side_select_shots: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_side_select_shots: save failed %s (%d)" % [path, error])
		else:
			saved += 1
			print("  ", path)
	viewport.queue_free()
	await _frames(1)
