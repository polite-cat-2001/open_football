extends Node3D

@onready var runtime := $GpfRuntime
@onready var pitch := $MatchNode
@onready var camera := $Camera3D

const BUTTONS := {
	KEY_UP: [0],
	KEY_RIGHT: [1],
	KEY_DOWN: [2],
	KEY_LEFT: [3],
	KEY_W: [4, 8],
	KEY_A: [5, 9],
	KEY_S: [6, 10],
	KEY_D: [7, 11],
	KEY_Q: [12],
	KEY_Z: [13],
	KEY_E: [14],
	KEY_C: [15],
	KEY_F1: [16],
	KEY_ENTER: [17],
}

const TEAM_COLORS := {
	0: Color(0.12, 0.28, 0.95),
	1: Color(0.95, 0.15, 0.12),
	-1: Color(0.95, 0.8, 0.15),
}

var gpf_space: Node3D
var body_scene: PackedScene
var ball_root: Node3D
var skeletons: Dictionary = {}
var bone_indices: Dictionary = {}
var actors: Array = []
var display_player_id := -1
var started := false
var frames := 0
var shot_path := OS.get_environment("GPF_SHOT")
var shot_frame := int(OS.get_environment("GPF_SHOT_FRAME")) if OS.get_environment("GPF_SHOT_FRAME") != "" else 120
var shot_taken := false
var demo := OS.get_environment("GPF_DEMO") != ""
var hud: Label

func _ready() -> void:
	gpf_space = Node3D.new()
	gpf_space.name = "GpfSpace"
	gpf_space.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	add_child(gpf_space)

	body_scene = load("res://assets/models/gpf_fullbody.glb")
	var ball_scene: PackedScene = load("res://assets/models/gpf_ball.glb")
	ball_root = ball_scene.instantiate()
	gpf_space.add_child(ball_root)

	_build_hud()
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		push_error("GpfRuntime failed: " + str(runtime.get_last_error()))
		return

	var ids: Array = runtime.get_player_ids()
	for entry in ids:
		if int(entry.get("team", -1)) == 0 and int(entry.get("id", -1)) != 0:
			display_player_id = int(entry.get("id"))
			break
	if display_player_id >= 0:
		runtime.select_player(display_player_id)
		print("display_player_id=", display_player_id, " human_after_select=", runtime.get_human_player_id())
	_spawn_actors(ids)
	runtime.set("manual_step", false)
	started = true

func _spawn_actors(ids: Array) -> void:
	for entry in ids:
		var id := int(entry.get("id", -1))
		if id < 0:
			continue
		var body: Node3D = body_scene.instantiate()
		gpf_space.add_child(body)
		var found := body.find_children("*", "Skeleton3D", true, false)
		if found.is_empty():
			continue
		var skeleton := found[0] as Skeleton3D
		if bone_indices.is_empty():
			for i in skeleton.get_bone_count():
				bone_indices[skeleton.get_bone_name(i)] = i
		_apply_kit_color(body, int(entry.get("team", -1)))
		skeletons[id] = skeleton
		actors.append(entry)

func _apply_kit_color(body: Node3D, team: int) -> void:
	var color: Color = TEAM_COLORS.get(team, Color.WHITE)
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface)
			if material == null or material.resource_name != "gpf_kit":
				continue
			var tinted := material.duplicate() as StandardMaterial3D
			tinted.albedo_color = color
			mesh_instance.set_surface_override_material(surface, tinted)

func _process(_delta: float) -> void:
	if not started:
		return
	if demo:
		_run_demo()
	var current_id: int = runtime.get_human_player_id()
	if current_id > 0:
		display_player_id = current_id
	var snap: Dictionary = runtime.get_snapshot()
	if snap.is_empty():
		return
	var player: Dictionary = {}
	for entry in actors:
		var id := int(entry.get("id", -1))
		var pose: Dictionary = runtime.get_player_pose(id)
		if pose.is_empty():
			continue
		_apply_player(id, pose)
		if id == display_player_id:
			player = pose
	_update_camera(snap)
	if hud != null:
		var status := "PRE-MATCH"
		if bool(snap.get("in_set_piece", false)):
			status = "KICKOFF — S pass / D shot"
			if int(snap.get("set_piece_taker", -1)) != int(player.get("id", -1)):
				status = "KICKOFF — waiting"
		elif bool(snap.get("in_play", false)):
			status = "LIVE"
		hud.text = "GPF slice  %s  tick %d  ball %.1f, %.1f  actors %d\nArrows move   E sprint   S pass   D shot   Q switch" % [
			status,
			int(snap.get("tick", 0)),
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).x,
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).y,
			actors.size(),
		]
	frames += 1
	if shot_path != "" and not shot_taken and frames >= shot_frame:
		shot_taken = true
		_save_screenshot.call_deferred()
	if frames % 60 == 0:
		print("slice frame=", frames, " tick=", snap.get("tick"), " in_play=", snap.get("in_play"), " player=", player.get("id"), " pos=", player.get("pos"), " anim=", player.get("anim"), " ball=", snap.get("ball_pos"))

func _apply_player(id: int, player: Dictionary) -> void:
	var skeleton: Skeleton3D = skeletons.get(id)
	if skeleton == null:
		return
	var bones: Array = player.get("bones", [])
	for bone in bones:
		var name: String = bone.get("name", "")
		var idx: int = bone_indices.get(name, -1)
		if idx < 0:
			continue
		skeleton.set_bone_pose_position(idx, bone.get("pos", Vector3.ZERO))
		skeleton.set_bone_pose_rotation(idx, bone.get("rot", Quaternion.IDENTITY))

func _update_camera(snap: Dictionary) -> void:
	var raw_pos: Vector3 = snap.get("camera_pos", Vector3.ZERO)
	var raw_rot: Quaternion = snap.get("camera_rot", Quaternion.IDENTITY)
	var space: Basis = gpf_space.basis
	var cam_basis: Basis = space * Basis(raw_rot)
	camera.global_transform = Transform3D(cam_basis, gpf_space.transform * raw_pos)
	camera.fov = clamp(float(snap.get("camera_fov", 55.0)), 10.0, 120.0)
	camera.near = maxf(0.05, float(snap.get("camera_near", 1.0)))
	camera.far = maxf(camera.near + 1.0, float(snap.get("camera_far", 200.0)))

	if ball_root != null:
		ball_root.transform = Transform3D(
			Basis(snap.get("ball_rot", Quaternion.IDENTITY)),
			snap.get("ball_pos", Vector3.ZERO)
		)

func _input(event: InputEvent) -> void:
	if not started or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.echo:
		return
	var functions: Array = BUTTONS.get(key_event.keycode, [])
	for function in functions:
		runtime.set_button(int(function), key_event.pressed)

func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(shot_path)
	print("screenshot saved=", shot_path, " err=", err)
	get_tree().quit()

func _run_demo() -> void:
	if frames < 90:
		runtime.set_button(1, true)
		runtime.set_button(14, true)
	elif frames == 90:
		runtime.set_button(1, false)
		runtime.set_button(14, false)
		runtime.set_button(7, true)
	elif frames == 125:
		runtime.set_button(7, false)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	layer.add_child(hud)
