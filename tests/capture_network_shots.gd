extends SceneTree
# Windowed screenshot book for the network screens and the shared OSK/dialog.
#
# Run:  godot --path . -s res://tests/capture_network_shots.gd
# Out:  .scratch/ui_shots/network_<state>_<WxH>.png

const MENU_SCENE := "res://scenes/network_menu.tscn"
const HOST_SCENE := "res://scenes/network_host.tscn"
const JOIN_SCENE := "res://scenes/network_join.tscn"
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football/.scratch/ui_shots"
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const STATES := [
	"menu",
	"host",
	"host_osk",
	"join",
	"join_osk",
	"join_connecting",
	"join_error",
	"back_dialog",
]

var saved := 0


func _init() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	NetworkSettings.config_path = "user://capture_network.cfg"
	NetworkSettings.reset()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await _frames(2)
	for size in SIZES:
		for state in STATES:
			await _capture(String(state), size)
	NetworkSettings.reset()
	NetworkSettings.config_path = NetworkSettings.CONFIG_PATH
	print("captured ", saved, " network screenshots into ", OUT_DIR)
	quit(0)



func _capture(state: String, size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(3)

	match state:
		"menu":
			host.add_child(load(MENU_SCENE).instantiate())
		"host":
			host.add_child(load(HOST_SCENE).instantiate())
			await _frames(4)
			_host_sample(host.get_child(0))
			host.get_child(0).call("_focus_initial")
		"host_osk":
			host.add_child(load(HOST_SCENE).instantiate())
			await _frames(4)
			_host_sample(host.get_child(0))
			host.get_child(0).call("_open_port")
		"join":
			host.add_child(load(JOIN_SCENE).instantiate())
			await _frames(4)
			_join_sample(host.get_child(0))
			host.get_child(0).call("_focus_initial")
		"join_osk":
			host.add_child(load(JOIN_SCENE).instantiate())
			await _frames(4)
			_join_sample(host.get_child(0))
			host.get_child(0).call("_open_address")
		"join_connecting":
			host.add_child(load(JOIN_SCENE).instantiate())
			await _frames(4)
			var join := host.get_child(0)
			_join_sample(join)
			join.call("_set_status", "CONNECTING TO 192.168.1.7:27015...", false)
		"join_error":
			host.add_child(load(JOIN_SCENE).instantiate())
			await _frames(4)
			var join := host.get_child(0)
			_join_sample(join)
			var address_row: UiFormRow = join.get("address_row")
			address_row.set_error("Connection refused")
			join.call("_set_status", "Connection refused", true)

		"back_dialog":
			host.add_child(load(MENU_SCENE).instantiate())
			await _frames(4)
			_add_back_dialog(host)
	await _frames(12)
	await RenderingServer.frame_post_draw
	var path := "%s/network_%s_%dx%d.png" % [OUT_DIR, state, size.x, size.y]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_network_shots: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_network_shots: save failed %s (%d)" % [path, error])
		else:
			saved += 1
			print("  ", path)
	viewport.queue_free()
	await _frames(1)


func _host_sample(screen: Node) -> void:
	var name_row: UiFormRow = screen.get("name_row")
	if name_row != null:
		name_row.set_value("Egor")


func _join_sample(screen: Node) -> void:
	var address_row: UiFormRow = screen.get("address_row")
	var name_row: UiFormRow = screen.get("name_row")
	if address_row != null:
		address_row.set_value("192.168.1.7")
	if name_row != null:
		name_row.set_value("Egor")


func _add_back_dialog(host: Control) -> void:
	var screen := host.get_child(0)
	var parent: Control = screen.get("design") if screen != null else null
	if parent == null:
		parent = host
	var state := {
		"active": true,
		"local_id": 0,
		"lobby": {
			"hub_vote": 0,
			"players": [
				{"id": 0, "name": "Host", "hub_vote": 0},
				{"id": 1, "name": "Guest", "hub_vote": NetworkBackVote.VOTE_BACK_TO_SIDES},
			],
		},
	}
	var vote := NetworkBackVote.new()
	vote.name = "BackVote"
	parent.add_child(vote)
	vote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vote.setup(NetworkBackVote.VOTE_BACK_TO_SIDES, {
		"provider": func() -> Dictionary: return state,
		"sender": func(_value: int) -> void: pass,
	})
	vote.call("_poll")


