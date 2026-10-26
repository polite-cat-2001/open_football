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

# Original C++ field geometry (gamedefines.hpp): playing field is 110 x 72,
# goal line at raw X = +-55, goal mouth 7.4 m wide, 2.5 m high, 2.55 m deep.
const GOAL_LINE_RAW := 55.0
const GOAL_HALF_WIDTH := 3.7
const GOAL_HEIGHT := 2.5
const GOAL_DEPTH := 2.55
const POST_RADIUS := 0.07
const NET_GRID_STEP := 0.5

const PHASE_NAMES := [
	"PRE-MATCH",
	"1ST HALF",
	"2ND HALF",
	"EXTRA TIME 1",
	"EXTRA TIME 2",
	"PENALTIES",
]

const SET_PIECE_NAMES := [
	"",
	"KICKOFF",
	"GOAL KICK",
	"FREE KICK",
	"CORNER",
	"THROW-IN",
	"PENALTY",
]

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
var score_hud: Label
var penalty_reticle: MeshInstance3D

func _ready() -> void:
	gpf_space = Node3D.new()
	gpf_space.name = "GpfSpace"
	gpf_space.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	add_child(gpf_space)

	body_scene = load("res://assets/models/gpf_fullbody.glb")
	var ball_scene: PackedScene = load("res://assets/models/gpf_ball.glb")
	ball_root = ball_scene.instantiate()
	gpf_space.add_child(ball_root)

	_build_goals()
	_build_penalty_reticle()
	_build_hud()
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		push_error("GpfRuntime failed: " + str(runtime.get_last_error()))
		return

	var ids: Array = runtime.get_player_ids()
	for entry in ids:
		if int(entry.get("team", -1)) == 0 and int(entry.get("id", -1)) != 0 \
				and String(entry.get("role", "player")) != "goalkeeper":
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
	_update_penalty_reticle(snap)
	if hud != null:
		var status := _status_text(snap, player)
		if score_hud != null:
			var phase_text := _phase_name(int(snap.get("match_phase", 0)))
			if bool(snap.get("game_over", false)):
				phase_text = "FULL TIME"
			score_hud.text = "%d : %d    %s    %s" % [
				int(snap.get("score0", 0)),
				int(snap.get("score1", 0)),
				_format_clock(int(snap.get("match_time_ms", 0))),
				phase_text,
			]
		var match_minutes := 5 + int(round(20.0 * float(runtime.get("match_duration"))))
		hud.text = "GPF slice  %s  tick %d  ball %.1f, %.1f  actors %d\nArrows move   E sprint   S pass   D shot   W through   A high   C dribble   Q switch   match ~%d min\nD+C curl   D+Q chip   double-E knock-on   P pen   Alt+P keeper pen   F free kick   Y corner   G goal kick   K keeper" % [
			status,
			int(snap.get("tick", 0)),
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).x,
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).y,
			actors.size(),
			match_minutes,
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
	var human_team: int = runtime.get_human_team_id()
	if human_team < 0:
		human_team = 0
	var set_piece_keys := {
		KEY_P: 6,
		KEY_F: 3,
		KEY_Y: 4,
		KEY_G: 2,
	}
	if set_piece_keys.has(key_event.keycode):
		if key_event.pressed:
			var team := human_team
			if key_event.alt_pressed:
				team = 1 - human_team
			var set_piece_type: int = set_piece_keys[key_event.keycode]
			runtime.debug_force_set_piece(set_piece_type, team)
			if set_piece_type == 6 and team != human_team:
				runtime.select_goalkeeper(human_team)
		return
	if key_event.keycode == KEY_K:
		if key_event.pressed:
			runtime.select_goalkeeper(human_team)
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

func _status_text(snap: Dictionary, player: Dictionary) -> String:
	if bool(snap.get("game_over", false)):
		return "MATCH OVER"
	if bool(snap.get("paused", false)):
		return "PAUSED"
	if bool(snap.get("goal_scored", false)):
		return "GOAL вЂ” restart"
	var piece := int(snap.get("referee_set_piece", 0))
	var role := int(snap.get("set_piece_role", 0))
	if bool(snap.get("in_set_piece", false)):
		if role == 2:
			return "PENALTY - keeper: arrows to dive"
		var piece_name := _set_piece_name(piece)
		if piece_name == "":
			piece_name = _set_piece_name(int(snap.get("set_piece_type", 0)))
		if piece_name == "":
			piece_name = "SET PIECE"
		var taker := int(snap.get("referee_taker", -1))
		if taker < 0:
			taker = int(snap.get("set_piece_taker", -1))
		if role == 1:
			if piece == 6:
				return "PENALTY - arrows aim, D shot"
			if piece == 2 or piece == 3 or piece == 4:
				return "%s - arrows aim, S/D kick" % piece_name
		if taker == int(player.get("id", -1)):
			return "%s - S pass / D shot" % piece_name
		return "%s - waiting" % piece_name
	if bool(snap.get("referee_active", false)) and piece != 0:
		return "%s вЂ” setup" % _set_piece_name(piece)
	if bool(snap.get("in_play", false)):
		return "LIVE"
	return "PRE-MATCH"

func _format_clock(milliseconds: int) -> String:
	var total_seconds := int(maxf(0.0, float(milliseconds)) / 1000.0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _phase_name(phase: int) -> String:
	if phase >= 0 and phase < PHASE_NAMES.size():
		return PHASE_NAMES[phase]
	return "PHASE %d" % phase

func _set_piece_name(piece: int) -> String:
	if piece > 0 and piece < SET_PIECE_NAMES.size():
		return SET_PIECE_NAMES[piece]
	return ""

func _build_penalty_reticle() -> void:
	penalty_reticle = MeshInstance3D.new()
	penalty_reticle.name = "PenaltyReticle"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.32
	ring.rings = 24
	ring.ring_segments = 8
	penalty_reticle.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.15)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	penalty_reticle.material_override = material
	penalty_reticle.rotation = Vector3(0, 0, PI / 2.0)
	penalty_reticle.visible = false
	gpf_space.add_child(penalty_reticle)

func _update_penalty_reticle(snap: Dictionary) -> void:
	if penalty_reticle == null:
		return
	var role := int(snap.get("set_piece_role", 0))
	var type := int(snap.get("presentation_type", 0))
	var aim: Vector3 = snap.get("set_piece_aim_point", Vector3.ZERO)
	var show := role == 1 and type == 6 and aim.length() > 0.01
	penalty_reticle.visible = show
	if show:
		penalty_reticle.position = aim

func _build_goals() -> void:
	var goals := Node3D.new()
	goals.name = "Goals"
	add_child(goals)

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.96, 0.96, 0.96)
	frame_material.roughness = 0.45
	frame_material.metallic = 0.15

	var net_material := StandardMaterial3D.new()
	net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net_material.albedo_color = Color(0.9, 0.94, 1.0, 0.38)
	net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for raw_side in [-1, 1]:
		_build_goal(goals, float(raw_side), frame_material, net_material)

func _build_goal(parent: Node3D, raw_side: float, frame_material: Material, net_material: Material) -> void:
	var front_x := -GOAL_LINE_RAW * raw_side
	var back_x := front_x - GOAL_DEPTH * raw_side
	for z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
		_add_goal_bar(parent, Vector3(front_x, 0.0, z), Vector3(front_x, GOAL_HEIGHT, z), frame_material)
		_add_goal_bar(parent, Vector3(back_x, 0.0, z), Vector3(back_x, GOAL_HEIGHT, z), frame_material)
		_add_goal_bar(parent, Vector3(front_x, 0.03, z), Vector3(back_x, 0.03, z), frame_material)
	_add_goal_bar(parent, Vector3(front_x, GOAL_HEIGHT, -GOAL_HALF_WIDTH), Vector3(front_x, GOAL_HEIGHT, GOAL_HALF_WIDTH), frame_material)
	_add_goal_bar(parent, Vector3(back_x, GOAL_HEIGHT, -GOAL_HALF_WIDTH), Vector3(back_x, GOAL_HEIGHT, GOAL_HALF_WIDTH), frame_material)
	for z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
		_add_goal_bar(parent, Vector3(front_x, GOAL_HEIGHT, z), Vector3(back_x, GOAL_HEIGHT, z), frame_material)
	_add_goal_bar(parent, Vector3(back_x, 0.03, -GOAL_HALF_WIDTH), Vector3(back_x, 0.03, GOAL_HALF_WIDTH), frame_material)
	_build_goal_net(parent, front_x, back_x, net_material)

func _build_goal_net(parent: Node3D, front_x: float, back_x: float, material: Material) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var width_steps := int(ceil((GOAL_HALF_WIDTH * 2.0) / NET_GRID_STEP))
	var height_steps := int(ceil(GOAL_HEIGHT / NET_GRID_STEP))
	var depth_steps := int(ceil(GOAL_DEPTH / NET_GRID_STEP))

	for i in range(width_steps + 1):
		var z := lerpf(-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH, float(i) / float(width_steps))
		_add_net_line(mesh, Vector3(back_x, 0.0, z), Vector3(back_x, GOAL_HEIGHT, z))
		_add_net_line(mesh, Vector3(front_x, GOAL_HEIGHT, z), Vector3(back_x, GOAL_HEIGHT, z))

	for i in range(height_steps + 1):
		var y := lerpf(0.0, GOAL_HEIGHT, float(i) / float(height_steps))
		_add_net_line(mesh, Vector3(back_x, y, -GOAL_HALF_WIDTH), Vector3(back_x, y, GOAL_HALF_WIDTH))

	for z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
		for i in range(depth_steps + 1):
			var x := lerpf(front_x, back_x, float(i) / float(depth_steps))
			_add_net_line(mesh, Vector3(x, 0.0, z), Vector3(x, GOAL_HEIGHT, z))
		for i in range(height_steps + 1):
			var y := lerpf(0.0, GOAL_HEIGHT, float(i) / float(height_steps))
			_add_net_line(mesh, Vector3(front_x, y, z), Vector3(back_x, y, z))

	mesh.surface_end()
	var net := MeshInstance3D.new()
	net.mesh = mesh
	net.material_override = material
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(net)

func _add_net_line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)

func _add_goal_bar(parent: Node3D, from: Vector3, to: Vector3, material: Material) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = POST_RADIUS
	cylinder.bottom_radius = POST_RADIUS
	cylinder.height = length
	cylinder.radial_segments = 12
	cylinder.rings = 1
	var bar := MeshInstance3D.new()
	bar.mesh = cylinder
	bar.material_override = material
	var direction := delta / length
	var basis := Basis.IDENTITY
	if absf(direction.dot(Vector3.UP)) < 0.9999:
		basis = Basis(Quaternion(Vector3.UP, direction))
	elif direction.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	bar.transform = Transform3D(basis, (from + to) * 0.5)
	parent.add_child(bar)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	score_hud = Label.new()
	score_hud.position = Vector2(24, 14)
	score_hud.add_theme_font_size_override("font_size", 34)
	score_hud.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	score_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	score_hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(score_hud)

	hud = Label.new()
	hud.position = Vector2(24, 64)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)
