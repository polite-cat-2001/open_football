class_name KitPreview3D
extends Node3D
# Static broadcast-camera diorama for the kit-select middle column. It uses the
# same body model and the same kit atlas as the match, so changing a kit in the
# carousel changes what the players wear here too. The scene is deliberately
# small and static: pitch + 22 bodies + ball, no stadium, no simulation.

const BODY_SCENE := "res://assets/models/gpf_fullbody.glb"
const BALL_SCENE := "res://assets/models/gpf_ball.glb"
# The field is a high-resolution plane on top of a much larger grass plane. The
# pitch texture is 10 px per metre, so the 2 px lines stay crisp at the preview
# size; the surrounding grass keeps the camera from seeing the world edge.
const GROUND_SIZE := 800.0
const PITCH_SIZE := Vector2(68.0, 105.0)
const PITCH_TEXTURE_SIZE := Vector2i(680, 1050)
const PLAYER_SCALE := 1.3
const ACTOR_BASIS := Basis(
	Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 1.0, 0.0)
)

static var _pitch_texture_cache: ImageTexture
static var _grass_texture_cache: ImageTexture

# One captured idle/run pose from the C++ skeleton (14 bones, rotations only).
# Keeping it static is enough for the preview and avoids running a match just
# to fill the menu.
const POSE := {
	"left_ankle": [-0.195122, 0.027708, 0.058478, 0.978642],
	"left_elbow": [-0.177592, 0.0, 0.0, 0.984104],
	"left_knee": [0.311751, 0.0, 0.0, 0.950164],
	"left_shoulder": [0.066645, -0.107422, -0.280762, 0.951416],
	"left_thigh": [-0.147359, -0.088527, 0.044592, 0.984104],
	"middle": [-0.047107, 0.0, 0.0, 0.99889],
	"neck": [0.109734, 0.0, 0.0, 0.993961],
	"right_ankle": [-0.195122, -0.027708, -0.058478, 0.978642],
	"right_elbow": [-0.177592, 0.0, 0.0, 0.984104],
	"right_knee": [0.311752, 0.0, 0.0, 0.950164],
	"right_shoulder": [0.066645, 0.107422, 0.280761, 0.951416],
	"right_thigh": [-0.147359, 0.088527, -0.044592, 0.984104],
}

const HOME_FORMATION := [
	Vector2(0.0, -24.0),
	Vector2(-20.0, -18.0), Vector2(-7.0, -19.0), Vector2(7.0, -19.0),
	Vector2(20.0, -18.0),
	Vector2(-13.0, -10.0), Vector2(0.0, -11.0), Vector2(13.0, -10.0),
	Vector2(-15.0, -2.0), Vector2(0.0, -1.0), Vector2(15.0, -2.0),
]
const AWAY_FORMATION := [
	Vector2(0.0, 24.0),
	Vector2(-20.0, 18.0), Vector2(-7.0, 19.0), Vector2(7.0, 19.0),
	Vector2(20.0, 18.0),
	Vector2(-13.0, 10.0), Vector2(0.0, 11.0), Vector2(13.0, 10.0),
	Vector2(-15.0, 2.0), Vector2(0.0, 1.0), Vector2(15.0, 2.0),
]

var home_kit: Dictionary = {}
var away_kit: Dictionary = {}
var body_scene: PackedScene
var _actors: Node3D
var _players: Array = []
var _built := false


func _ready() -> void:
	_build()


func set_kits(home: Dictionary, away: Dictionary) -> void:
	home_kit = home.duplicate(true) if home is Dictionary else {}
	away_kit = away.duplicate(true) if away is Dictionary else {}
	if _built:
		_apply_kits()


func _build() -> void:
	if _built:
		return
	_built = true
	_build_environment()
	_build_pitch()
	_actors = Node3D.new()
	_actors.name = "Actors"
	_actors.transform = Transform3D(ACTOR_BASIS, Vector3.ZERO)
	add_child(_actors)
	_build_players()
	_build_ball()
	_apply_kits()


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.58, 0.66)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.42, 0.52, 0.62)
	environment.fog_density = 0.0035
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.25, 0.48)
	sky_material.sky_horizon_color = Color(0.58, 0.70, 0.82)
	sky_material.ground_horizon_color = Color(0.20, 0.28, 0.24)
	sky_material.sky_curve = 0.12
	sky.sky_material = sky_material
	environment.sky = sky
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-18.0, 142.0, 0.0)
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)

	# Low camera inside the near touchline, aimed down into the pitch. The far
	# side line is above the top of the frame, so the empty world beyond the
	# pitch is never visible and the players fill the lower part of the preview.
	var camera := Camera3D.new()
	camera.name = "BroadcastCamera"
	camera.position = Vector3(-26.0, 8.0, 0.0)
	camera.fov = 32.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(-7.7, 0.0, 0.0), Vector3.UP)


func _build_pitch() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Grass"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = _grass_texture()
	ground_material.uv1_scale = Vector3(8.0, 8.0, 1.0)
	ground_material.roughness = 1.0
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.material_override = ground_material
	ground.position = Vector3(0.0, -0.02, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var pitch := MeshInstance3D.new()
	pitch.name = "Pitch"
	var pitch_mesh := PlaneMesh.new()
	pitch_mesh.size = PITCH_SIZE
	pitch.mesh = pitch_mesh
	var pitch_material := StandardMaterial3D.new()
	pitch_material.albedo_texture = _pitch_texture()
	pitch_material.roughness = 0.95
	pitch_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	pitch.material_override = pitch_material
	pitch.position = Vector3(0.0, 0.0, 0.0)
	pitch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pitch)




func _build_players() -> void:
	body_scene = load(BODY_SCENE) as PackedScene
	if body_scene == null:
		push_warning("KitPreview3D: could not load " + BODY_SCENE)
		return
	for index in HOME_FORMATION.size():
		_spawn_body(0, HOME_FORMATION[index], PI)
		_spawn_body(1, AWAY_FORMATION[index], 0.0)
	_apply_kits()


func _spawn_body(team: int, raw_position: Vector2, yaw: float) -> void:
	var body := body_scene.instantiate() as Node3D
	if body == null:
		return
	_actors.add_child(body)
	body.position = Vector3(raw_position.x, raw_position.y, 0.0)
	body.rotation.z = yaw
	body.scale = Vector3.ONE * PLAYER_SCALE
	var skeletons := body.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		var skeleton := skeletons[0] as Skeleton3D
		for bone_name in POSE:
			var index := skeleton.find_bone(String(bone_name))
			if index < 0:
				continue
			var value: Array = POSE[bone_name]
			skeleton.set_bone_pose_rotation(index,
				Quaternion(value[0], value[1], value[2], value[3]))
	_players.append({"team": team, "body": body})


func _build_ball() -> void:
	var scene := load(BALL_SCENE) as PackedScene
	if scene == null:
		return
	var ball := scene.instantiate() as Node3D
	if ball == null:
		return
	ball.name = "Ball"
	ball.position = Vector3(0.0, 0.0, 0.11)
	_actors.add_child(ball)


func _apply_kits() -> void:
	for entry in _players:
		var body := entry["body"] as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var kit: Dictionary = home_kit if int(entry["team"]) == 0 else away_kit
		if kit.is_empty():
			KitTexture.apply_color_to_body(body, Color(0.86, 0.88, 0.92))
		else:
			KitTexture.apply_to_body(body, kit)


static func _pitch_texture() -> ImageTexture:
	if _pitch_texture_cache != null:
		return _pitch_texture_cache
	var width := PITCH_TEXTURE_SIZE.x
	var height := PITCH_TEXTURE_SIZE.y
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var stripe := Color(0.11, 0.43, 0.24)
	var stripe_light := Color(0.13, 0.49, 0.28)
	for index in 12:
		image.fill_rect(Rect2i(0, int(float(index) * height / 12.0), width,
			int(float(height) / 12.0) + 1),
			stripe if index % 2 == 0 else stripe_light)
	var line := Color(0.94, 0.97, 0.95, 0.95)
	var margin := 3
	var left := margin
	var right := width - margin - 1
	var top := margin
	var bottom := height - margin - 1
	var thickness := 2
	# Full field markings: the preview is a crop of this plane, so the side
	# lines and the centre line end where they should, not in empty grass.
	_fill_rect(image, left, top, right - left, thickness, line)
	_fill_rect(image, left, bottom - thickness, right - left, thickness, line)
	_fill_rect(image, left, top, thickness, bottom - top, line)
	_fill_rect(image, right - thickness, top, thickness, bottom - top, line)
	_fill_rect(image, left, (top + bottom) / 2, right - left, thickness, line)
	_draw_circle(image, (left + right) / 2, (top + bottom) / 2, 91, thickness, line)
	var box_width := 403
	var box_depth := 165
	var box_x := (left + right - box_width) / 2
	_draw_box(image, box_x, top, box_width, box_depth, thickness, line)
	_draw_box(image, box_x, bottom - box_depth, box_width, box_depth, thickness, line)
	var goal_width := 183
	var goal_depth := 55
	var goal_x := (left + right - goal_width) / 2
	_draw_box(image, goal_x, top, goal_width, goal_depth, thickness, line)
	_draw_box(image, goal_x, bottom - goal_depth, goal_width, goal_depth, thickness, line)
	image.generate_mipmaps()
	_pitch_texture_cache = ImageTexture.create_from_image(image)
	return _pitch_texture_cache


static func _grass_texture() -> ImageTexture:
	if _grass_texture_cache != null:
		return _grass_texture_cache
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var stripe := Color(0.10, 0.38, 0.21)
	var stripe_light := Color(0.12, 0.44, 0.25)
	for index in 8:
		image.fill_rect(Rect2i(0, index * 32, 256, 32),
			stripe if index % 2 == 0 else stripe_light)
	image.generate_mipmaps()
	_grass_texture_cache = ImageTexture.create_from_image(image)
	return _grass_texture_cache


static func _draw_box(image: Image, x: int, y: int, width: int, height: int,
		thickness: int, color: Color) -> void:
	_fill_rect(image, x, y, width, thickness, color)
	_fill_rect(image, x, y + height - thickness, width, thickness, color)
	_fill_rect(image, x, y, thickness, height, color)
	_fill_rect(image, x + width - thickness, y, thickness, height, color)


static func _fill_rect(image: Image, x: int, y: int, width: int, height: int,
		color: Color) -> void:
	image.fill_rect(Rect2i(x, y, maxi(1, width), maxi(1, height)), color)


static func _draw_circle(image: Image, center_x: int, center_y: int, radius: int,
		thickness: int, color: Color) -> void:
	var steps := maxi(32, radius * 4)
	for index in steps:
		var angle := TAU * float(index) / float(steps)
		var x := center_x + int(round(cos(angle) * float(radius)))
		var y := center_y + int(round(sin(angle) * float(radius)))
		for offset in thickness:
			image.set_pixel(clampi(x + offset, 0, image.get_width() - 1),
				clampi(y, 0, image.get_height() - 1), color)
