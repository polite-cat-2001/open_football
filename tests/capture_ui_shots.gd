extends SceneTree
# Windowed screenshot book for the UI. Each screen is rendered into a
# SubViewport at the target resolution, so the window size does not matter.
#
# Run:  godot --path . -s res://tests/capture_ui_shots.gd
# Out:  .scratch/ui_shots/<screen>_<WxH>.png

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football/.scratch/ui_shots"
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const SCREENS := [
	{"path": "res://scenes/main_menu.tscn", "name": "main_menu"},
	{"path": "res://scenes/controller_select.tscn", "name": "controller_select"},
	{"path": "res://scenes/team_select.tscn", "name": "team_select"},
	{"path": "res://scenes/prematch.tscn", "name": "prematch"},
	{"path": "res://scenes/ui_lab.tscn", "name": "ui_lab", "states": 9},
]

var saved := 0


func _init() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _seed() -> void:
	ShellState.clear()
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		push_error("capture_ui_shots: catalog: " + str(catalog.error))
		return
	ShellState.set_teams(catalog.team_by_id(3), catalog.team_by_id(8))
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_seed()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await _frames(2)

	for size in SIZES:
		for spec in SCREENS:
			await _capture_screen(spec, size)
	print("captured ", saved, " screenshots into ", OUT_DIR)
	quit(0)


func _capture_screen(spec: Dictionary, size: Vector2i) -> void:
	var packed: PackedScene = load(String(spec["path"]))
	if packed == null:
		push_error("capture_ui_shots: cannot load " + String(spec["path"]))
		return
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: Node = packed.instantiate()
	viewport.add_child(screen)
	await _frames(3)
	if screen.has_method("set_caption_visible"):
		screen.call("set_caption_visible", false)
	await RenderingServer.frame_post_draw

	var state_count := int(spec.get("states", 1))
	if state_count <= 1:
		_save(viewport, String(spec["name"]), size)
	else:
		for i in state_count:
			screen.call("set_state", i)
			await create_timer(0.35).timeout
			await RenderingServer.frame_post_draw
			var state := String(screen.call("state_name"))
			var slug := state.to_lower().replace(" ", "_")
			_save(viewport, "%s_%s" % [String(spec["name"]), slug], size)

	viewport.queue_free()
	await _frames(1)


func _save(viewport: SubViewport, name: String, size: Vector2i) -> void:
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_ui_shots: no image for " + name)
		return
	var path := "%s/%s_%dx%d.png" % [OUT_DIR, name, size.x, size.y]
	var error := image.save_png(path)
	if error != OK:
		push_error("capture_ui_shots: save failed %s (%d)" % [path, error])
		return
	saved += 1
	print("  ", path)
