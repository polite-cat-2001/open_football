extends Node3D

@onready var runtime := $GpfRuntime
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
	KEY_ENTER: [17],
}

const TEAM_COLORS := {
	0: Color(0.12, 0.28, 0.95),
	1: Color(0.95, 0.15, 0.12),
	-1: Color(0.95, 0.8, 0.15),
}
const NAMEPLATE_NORMAL_COLOR := Color(0.90, 0.94, 1.0)
const NAMEPLATE_CONTROLLED_COLOR := Color(1.0, 0.84, 0.18)
const NAMEPLATE_HEIGHT := 2.25
const REPLAY_MAX_FRAMES := 300
const REPLAY_MIN_FRAMES := 30
const REPLAY_TAIL_FRAMES := 180
const REPLAY_PLAYBACK_FPS := 60.0

# Original C++ field geometry (gamedefines.hpp): playing field is 110 x 72,
# goal line at raw X = +-55, goal mouth 7.4 m wide, 2.5 m high, 2.55 m deep.
const GOALS_SCENE := "res://assets/models/gpf_goals.glb"

const STADIUM_SCENE := "res://assets/models/gpf_stadium.glb"
const PITCH_SCENE := "res://assets/models/gpf_pitch.glb"
const PITCH_TEXTURE_WIDTH := 3072
const PITCH_TEXTURE_HEIGHT := 2048
const PITCH_THEMES := {
	"dry": {"albedo": Color(1.0, 1.0, 1.0), "roughness": 0.95},
	"wet": {"albedo": Color(0.72, 0.82, 0.78), "roughness": 0.28},
	"damp": {"albedo": Color(0.86, 0.92, 0.86), "roughness": 0.62},
	"snow": {"albedo": Color(0.92, 0.95, 0.98), "roughness": 0.82},
}

# Derived from Match::SetRandomSunParams (match.cpp): the original picks a
# random sun direction and blends a cool noon colour with a warm dusk colour.
# The presets extend that idea into distinct debug moods.
const LIGHTING_PRESETS := [
	{
		"name": "Noon",
		"sun_pos": Vector3(-0.25, 0.20, 1.35),
		"sun_color": Color(0.88, 0.90, 1.0),
		"sun_energy": 0.80,
		"ambient": 0.45,
		"ambient_color": Color(0.62, 0.65, 0.72),
		"fill_energy": 0.15,
		"fill_color": Color(0.65, 0.78, 1.0),
		"exposure": 0.90,
		"sky_top": Color(0.10, 0.30, 0.62),
		"sky_horizon": Color(0.64, 0.80, 0.96),
		"ground_horizon": Color(0.32, 0.36, 0.38),
		"sky_energy": 0.95,
		"fog_color": Color(0.65, 0.78, 0.95),
		"fog_density": 0.0,
		"sun_disk": 1.0,
		"shadows": true,
	},
	{
		"name": "Afternoon",
		"sun_pos": Vector3(-0.90, 0.35, 1.05),
		"sun_color": Color(1.0, 0.84, 0.65),
		"sun_energy": 0.70,
		"ambient": 0.48,
		"ambient_color": Color(0.64, 0.64, 0.68),
		"fill_energy": 0.15,
		"fill_color": Color(0.95, 0.82, 0.70),
		"exposure": 0.90,
		"sky_top": Color(0.16, 0.36, 0.62),
		"sky_horizon": Color(0.92, 0.75, 0.58),
		"ground_horizon": Color(0.38, 0.34, 0.30),
		"sky_energy": 0.90,
		"fog_color": Color(0.85, 0.72, 0.58),
		"fog_density": 0.0001,
		"sun_disk": 1.5,
		"shadows": true,
	},
	{
		"name": "Sunset",
		"sun_pos": Vector3(-1.10, 0.85, 0.70),
		"sun_color": Color(1.0, 0.50, 0.28),
		"sun_energy": 0.80,
		"ambient": 0.75,
		"ambient_color": Color(0.72, 0.58, 0.52),
		"fill_energy": 0.55,
		"fill_color": Color(0.90, 0.65, 0.48),
		"exposure": 1.05,
		"sky_top": Color(0.16, 0.12, 0.30),
		"sky_horizon": Color(0.95, 0.55, 0.28),
		"ground_horizon": Color(0.35, 0.22, 0.20),
		"sky_energy": 0.80,
		"fog_color": Color(0.90, 0.50, 0.28),
		"fog_density": 0.00015,
		"sun_disk": 2.5,
		"shadows": true,
	},
]

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

# Penalty shootout (series). Mirrors e_ShootoutPhase / e_ShootoutOutcome in the C++ runtime.
const SHOOTOUT_PHASE_NONE := 0
const SHOOTOUT_PHASE_KICK_SETUP := 1
const SHOOTOUT_PHASE_KICK_AIM := 2
const SHOOTOUT_PHASE_KICK_OUTCOME := 3
const SHOOTOUT_PHASE_OUTCOME_HOLD := 4
const SHOOTOUT_PHASE_DECISIVE_CELEBRATION := 5
const SHOOTOUT_PHASE_FINISHED := 6
const SHOOTOUT_PHASE_TRANSITION := 7
const SHOOTOUT_OUTCOME_TEXT := {1: "GOAL", 2: "SAVE", 3: "MISS"}
const SHOOTOUT_CIRCLE_COLORS := {
	0: Color(0.30, 0.32, 0.36, 0.92),
	1: Color(0.20, 0.85, 0.35),
	2: Color(0.92, 0.22, 0.20),
}
const SHOOTOUT_CIRCLE_SIZE := 20.0
const SHOOTOUT_BANNER_TIME := 1.2
const SHOOTOUT_FADE_TIME := 0.3

var gpf_space: Node3D
var environment_space: Node3D
var body_scene: PackedScene
var ball_root: Node3D
var skeletons: Dictionary = {}
var bone_indices: Dictionary = {}
var actors: Array = []
var actor_bodies: Dictionary = {}
var player_labels: Dictionary = {}
var replay_history: Array = []
var replay_frames: Array = []
var pending_replay_frames: Array = []
var replay_tail: Array = []
var replay_tail_active := false
var replay_active := false
var replay_time := 0.0
var goal_replay_captured := false
var replay_layer: CanvasLayer
var replay_banner: Label
var replay_hint: Label
var display_player_id := -1
var started := false
var frames := 0
var shot_path := OS.get_environment("GPF_SHOT")
var shot_frame := int(OS.get_environment("GPF_SHOT_FRAME")) if OS.get_environment("GPF_SHOT_FRAME") != "" else 120
var shot_taken := false
var demo := OS.get_environment("GPF_DEMO") != ""
var hud: Label
var score_hud: Label
var taker_hint: Label
var penalty_reticle: MeshInstance3D
var taker_menu_layer: CanvasLayer
var taker_menu_label: Label
var taker_menu_open := false
var taker_menu_candidates: Array = []
var taker_menu_index := 0
var phase_menu_layer: CanvasLayer
var phase_menu_title: Label
var phase_menu_subtitle: Label
var phase_menu_score: Label
var phase_menu_details: Label
var phase_menu_hint: Label
var phase_menu_continue: Button
var phase_menu_quit: Button
var phase_menu_open := false
var phase_menu_game_over := false
var shootout_layer: CanvasLayer
var shootout_home_row: HBoxContainer
var shootout_away_row: HBoxContainer
var shootout_circles := {0: [], 1: []}
var shootout_banner: Label
var shootout_fade: ColorRect
var shootout_fade_tween: Tween
var shootout_outcome_counter := 0
var shootout_last_phase := -1
var shootout_banner_left := 0.0
var shootout_end_layer: CanvasLayer
var shootout_end_score: Label
var shootout_end_buttons: Array[Button] = []
var shootout_end_index := 0
var shootout_end_open := false
var goal_net_meshes: Array[MeshInstance3D] = []
var goal_net_edges: PackedInt32Array
var goal_net_positions_cache: Array = []
var goal_net_material: Material
var pitch_root: Node3D
var pitch_materials: Array[StandardMaterial3D] = []
var pitch_theme := "dry"
var stadium_camera := false
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var lighting_index := 1

func _ready() -> void:
	gpf_space = Node3D.new()
	gpf_space.name = "GpfSpace"
	gpf_space.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	add_child(gpf_space)

	environment_space = Node3D.new()
	environment_space.name = "Environment"
	environment_space.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	add_child(environment_space)
	_build_world_environment()
	_build_environment()
	body_scene = load("res://assets/models/gpf_fullbody.glb")
	var ball_scene: PackedScene = load("res://assets/models/gpf_ball.glb")
	ball_root = ball_scene.instantiate()
	if ball_root is GeometryInstance3D:
		ball_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in ball_root.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	gpf_space.add_child(ball_root)

	_build_goals()
	_build_penalty_reticle()
	_build_hud()
	_build_replay_ui()
	_build_taker_menu()
	_build_phase_menu()
	_build_shootout_ui()
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		push_error("GpfRuntime failed: " + str(runtime.get_last_error()))
		return
	_build_dynamic_goal_nets()

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
		actor_bodies[id] = body
		_build_nameplate(body, id, entry)
		actors.append(entry)

func _build_nameplate(body: Node3D, id: int, entry: Dictionary) -> void:
	if String(entry.get("role", "")) == "official":
		return
	var label := Label3D.new()
	label.name = "Nameplate%d" % id
	label.text = String(entry.get("name", ""))
	if label.text.is_empty():
		label.text = "#%d" % id
	label.position = Vector3(0.0, 0.0, NAMEPLATE_HEIGHT)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.004
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.modulate = NAMEPLATE_NORMAL_COLOR
	body.add_child(label)
	player_labels[id] = label

func _build_world_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_curve = 0.12
	sky_material.ground_curve = 0.08
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.66, 0.76)
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.002
	world.environment = environment
	world_environment = environment
	add_child(world)

	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		add_child(sun)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 170.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
	sun_light = sun

	var fill := get_node_or_null("FillLight") as DirectionalLight3D
	if fill == null:
		fill = DirectionalLight3D.new()
		fill.name = "FillLight"
		add_child(fill)
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.light_energy = 0.16
	fill.shadow_enabled = false
	fill_light = fill

	_apply_lighting()

func _apply_lighting() -> void:
	if sun_light == null or world_environment == null:
		return
	var preset: Dictionary = LIGHTING_PRESETS[lighting_index % LIGHTING_PRESETS.size()]
	var raw_position: Vector3 = preset["sun_pos"]
	var sun_position := Vector3(raw_position.x, raw_position.z, raw_position.y).normalized()
	sun_light.look_at_from_position(sun_position * 100.0, Vector3.ZERO, Vector3.UP)
	sun_light.light_color = preset["sun_color"]
	sun_light.light_energy = preset["sun_energy"]
	sun_light.shadow_enabled = preset["shadows"]
	world_environment.ambient_light_color = preset["ambient_color"]
	world_environment.ambient_light_energy = preset["ambient"]
	world_environment.tonemap_exposure = preset["exposure"]
	world_environment.fog_light_color = preset["fog_color"]
	world_environment.fog_density = preset["fog_density"]
	if sky_material != null:
		sky_material.sky_top_color = preset["sky_top"]
		sky_material.sky_horizon_color = preset["sky_horizon"]
		sky_material.ground_horizon_color = preset["ground_horizon"]
		sky_material.sky_energy_multiplier = preset["sky_energy"]
		sky_material.ground_energy_multiplier = preset["sky_energy"]
		sky_material.sun_angle_max = preset["sun_disk"]
	if fill_light != null:
		var fill_position := Vector3(-sun_position.x, 0.85, -sun_position.z).normalized()
		fill_light.look_at_from_position(fill_position * 100.0, Vector3.ZERO, Vector3.UP)
		fill_light.light_color = preset["fill_color"]
		fill_light.light_energy = preset["fill_energy"]
	_refresh_pitch_tint()

func _build_environment() -> void:
	var stadium_scene := load(STADIUM_SCENE) as PackedScene
	if stadium_scene != null:
		var stadium := stadium_scene.instantiate() as Node3D
		stadium.name = "Stadium"
		environment_space.add_child(stadium)
		_fix_stadium_materials(stadium)

	var pitch_scene := load(PITCH_SCENE) as PackedScene
	if pitch_scene != null:
		pitch_root = pitch_scene.instantiate() as Node3D
		pitch_root.name = "Pitch"
		pitch_root.position = Vector3(0.0, 0.0, 0.01)
		environment_space.add_child(pitch_root)
		_apply_pitch_texture(pitch_root)

func _fix_stadium_materials(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var material_name := source.resource_name
			var material_index := _material_index(material_name)
			if material_index < 3 or material_index > 30:
				continue
			var material := source.duplicate() as StandardMaterial3D
			if material == null:
				continue
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if material_index >= 3 and material_index <= 25:
				material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
				material.uv1_offset = Vector3(1.0, 0.0, 0.0)
				# test.ase stores each ad panel as a coplanar front/back pair;
				# rendering both sides makes the pair z-fight.
				material.cull_mode = BaseMaterial3D.CULL_BACK
			var texture := material.albedo_texture
			if texture is ImageTexture:
				var image := (texture as ImageTexture).get_image()
				if image != null and not image.has_mipmaps():
					image.generate_mipmaps()
					material.albedo_texture = ImageTexture.create_from_image(image)
			if material_index == 30:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.12
			mesh_instance.set_surface_override_material(surface, material)

func _material_index(name: String) -> int:
	if not name.begins_with("mat"):
		return -1
	return int(name.substr(3))

func _apply_pitch_texture(root: Node3D) -> void:
	var image: Image = runtime.generate_pitch_texture(PITCH_TEXTURE_WIDTH, PITCH_TEXTURE_HEIGHT)
	if image == null or image.is_empty():
		push_warning("GpfRuntime returned no pitch texture")
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var xform := mesh_instance.transform
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var src_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var base := vertices.size()
			for i in src_vertices.size():
				var position: Vector3 = xform * src_vertices[i]
				vertices.append(position)
				var normal := Vector3.UP
				if i < src_normals.size():
					normal = (xform.basis * src_normals[i]).normalized()
				normals.append(normal)
				uvs.append(Vector2(
					clampf((position.x + 60.0) / 120.0, 0.0, 1.0),
					clampf((40.0 - position.y) / 80.0, 0.0, 1.0)
				))
			if src_indices.is_empty():
				for i in src_vertices.size():
					indices.append(base + i)
			else:
				for index in src_indices:
					indices.append(base + index)
		mesh_instance.visible = false

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var combined := ArrayMesh.new()
	combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	pitch_materials.append(material)
	var surface := MeshInstance3D.new()
	surface.name = "PitchSurface"
	surface.mesh = combined
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(surface)
	set_pitch_theme(pitch_theme)

func set_pitch_theme(theme: String) -> void:
	pitch_theme = theme
	_refresh_pitch_tint()

func _refresh_pitch_tint() -> void:
	var colors: Dictionary = PITCH_THEMES.get(pitch_theme, PITCH_THEMES["dry"])
	var preset: Dictionary = LIGHTING_PRESETS[lighting_index % LIGHTING_PRESETS.size()]
	var tint: Color = preset.get("pitch_tint", Color.WHITE)
	for material in pitch_materials:
		material.albedo_color = Color(
			colors["albedo"].r * tint.r,
			colors["albedo"].g * tint.g,
			colors["albedo"].b * tint.b,
			colors["albedo"].a
		)
		material.roughness = colors["roughness"]

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

func _process(delta: float) -> void:
	if not started:
		return
	if replay_active:
		_update_replay(delta)
		return
	if demo:
		_run_demo()
	var current_id: int = runtime.get_human_player_id()
	if current_id > 0:
		display_player_id = current_id
	var snap: Dictionary = runtime.get_snapshot()
	if snap.is_empty():
		return
	_update_shootout(snap, delta)
	var player: Dictionary = {}
	var frame_poses: Dictionary = {}
	for entry in actors:
		var id := int(entry.get("id", -1))
		var pose: Dictionary = runtime.get_player_pose(id)
		if pose.is_empty():
			continue
		_apply_player(id, pose)
		frame_poses[id] = pose
		if id == display_player_id:
			player = pose
	_update_camera(snap)
	_update_goal_nets()
	_record_replay_frame(frame_poses)
	_capture_goal_replay(snap)
	_update_replay_moment(snap)
	_update_penalty_reticle(snap)
	_update_debug_park_visibility(snap)
	_update_player_labels()
	_sync_phase_menu(snap)
	_sync_taker_ui(snap)
	if hud != null:
		var status := _status_text(snap, player)
		if score_hud != null:
			# The shootout HUD is the two circles rows; no match clock or score.
			score_hud.visible = not bool(snap.get("shootout_active", false))
			var phase_text := _phase_name(int(snap.get("match_phase", 0)))
			if bool(snap.get("game_over", false)):
				phase_text = "FULL TIME"
			elif bool(snap.get("phase_break_pending", false)) or bool(snap.get("phase_break", false)):
				phase_text = "BREAK"
			score_hud.text = "%d : %d    %s    %s" % [
				int(snap.get("score0", 0)),
				int(snap.get("score1", 0)),
				_format_clock(int(snap.get("match_time_ms", 0))),
				phase_text,
			]
		var match_minutes := 5 + int(round(20.0 * float(runtime.get("match_duration"))))
		var park_text := "F2 unpark opponents" if bool(snap.get("debug_park_opponents", false)) \
			else "F2 park opponents"
		var camera_text := "V broadcast cam" if stadium_camera else "V stadium cam"
		var lighting_name: String = LIGHTING_PRESETS[lighting_index % LIGHTING_PRESETS.size()]["name"]
		hud.text = "GPF slice  %s  tick %d  ball %.1f, %.1f  actors %d\nArrows move   E sprint   S pass   D shot   W through   A high   C dribble   Q switch   match ~%d min\nD+C curl   D+Q chip   double-E knock-on   P pen   Alt+P defend pen   F free kick   Y corner   G goal kick   O throw-in   Tab taker   %s   %s   F1 light: %s" % [
			status,
			int(snap.get("tick", 0)),
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).x,
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).y,
			actors.size(),
			match_minutes,
			park_text,
			camera_text,
			lighting_name,
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
	var label: Label3D = player_labels.get(id)
	if label != null:
		var pos: Vector3 = player.get("pos", Vector3.ZERO)
		label.position = Vector3(pos.x, pos.y, NAMEPLATE_HEIGHT)

func _update_player_labels() -> void:
	for id in player_labels:
		var label: Label3D = player_labels[id]
		if label == null:
			continue
		var body: Node3D = actor_bodies.get(id)
		label.visible = not replay_active and not stadium_camera and body != null and body.visible
		label.modulate = NAMEPLATE_CONTROLLED_COLOR if id == display_player_id \
			else NAMEPLATE_NORMAL_COLOR

func _record_replay_frame(poses: Dictionary) -> void:
	if replay_active or not started:
		return
	var frame := {
		"poses": poses,
		"ball": ball_root.transform,
		"camera": camera.global_transform,
		"camera_fov": camera.fov,
		"camera_near": camera.near,
		"camera_far": camera.far,
		"net_positions": goal_net_positions_cache.duplicate(),
	}
	replay_history.append(frame)
	while replay_history.size() > REPLAY_MAX_FRAMES:
		replay_history.pop_front()
	if replay_tail_active:
		replay_tail.append(frame)
		if replay_tail.size() >= REPLAY_TAIL_FRAMES:
			replay_tail_active = false

func _capture_goal_replay(snap: Dictionary) -> void:
	if not bool(snap.get("goal_scored", false)):
		goal_replay_captured = false
		return
	if goal_replay_captured or replay_active:
		return
	goal_replay_captured = true
	pending_replay_frames = replay_history.duplicate()
	replay_tail.clear()
	replay_tail_active = true

func _update_replay_moment(snap: Dictionary) -> void:
	if replay_active or not bool(snap.get("replay_moment", false)):
		return
	if pending_replay_frames.size() >= REPLAY_MIN_FRAMES:
		_start_replay()
	else:
		runtime.set_replay_active(false)

func _start_replay() -> void:
	replay_frames = pending_replay_frames.duplicate()
	replay_frames.append_array(replay_tail)
	pending_replay_frames.clear()
	replay_tail.clear()
	replay_tail_active = false
	replay_history.clear()
	replay_time = 0.0
	replay_active = true
	runtime.set_replay_active(true)
	if replay_banner != null:
		replay_banner.visible = true
	if replay_hint != null:
		replay_hint.visible = true
	if hud != null:
		hud.visible = false
	if score_hud != null:
		score_hud.visible = false
	if penalty_reticle != null:
		penalty_reticle.visible = false
	_update_player_labels()

func _update_replay(delta: float) -> void:
	if replay_frames.is_empty():
		_finish_replay()
		return
	replay_time += delta
	var frame_index := int(replay_time * REPLAY_PLAYBACK_FPS)
	if frame_index >= replay_frames.size():
		_finish_replay()
		return
	_apply_replay_frame(replay_frames[frame_index])
	_update_player_labels()

func _apply_replay_frame(frame: Dictionary) -> void:
	var poses: Dictionary = frame.get("poses", {})
	for id in poses:
		_apply_player(int(id), poses[id])
	camera.global_transform = frame.get("camera", camera.global_transform)
	camera.fov = float(frame.get("camera_fov", camera.fov))
	camera.near = float(frame.get("camera_near", camera.near))
	camera.far = float(frame.get("camera_far", camera.far))
	if ball_root != null:
		ball_root.transform = frame.get("ball", ball_root.transform)
	var net_positions: Array = frame.get("net_positions", [])
	for goal in mini(goal_net_meshes.size(), net_positions.size()):
		_draw_goal_net(goal, net_positions[goal])

func _finish_replay() -> void:
	if not replay_active:
		return
	replay_active = false
	replay_frames.clear()
	pending_replay_frames.clear()
	replay_tail.clear()
	replay_tail_active = false
	replay_history.clear()
	goal_replay_captured = false
	replay_time = 0.0
	runtime.set_replay_active(false)
	if replay_banner != null:
		replay_banner.visible = false
	if replay_hint != null:
		replay_hint.visible = false
	if hud != null:
		hud.visible = true
	if score_hud != null:
		score_hud.visible = true
	_update_player_labels()

func _build_replay_ui() -> void:
	replay_layer = CanvasLayer.new()
	replay_layer.layer = 1
	add_child(replay_layer)
	replay_banner = Label.new()
	replay_banner.name = "ReplayBanner"
	replay_banner.text = "REPLAY"
	replay_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	replay_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	replay_banner.offset_top = 34
	replay_banner.add_theme_font_size_override("font_size", 34)
	replay_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	replay_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	replay_banner.add_theme_constant_override("outline_size", 6)
	replay_banner.visible = false
	replay_layer.add_child(replay_banner)
	replay_hint = Label.new()
	replay_hint.name = "ReplayHint"
	replay_hint.text = "SPACE / ESC — skip"
	replay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	replay_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	replay_hint.offset_top = 82
	replay_hint.add_theme_font_size_override("font_size", 16)
	replay_hint.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	replay_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	replay_hint.add_theme_constant_override("outline_size", 4)
	replay_hint.visible = false
	replay_layer.add_child(replay_hint)

func _update_camera(snap: Dictionary) -> void:
	if stadium_camera:
		camera.global_position = Vector3(-145.0, 58.0, 95.0)
		camera.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
		camera.fov = 55.0
		camera.near = 0.1
		camera.far = 500.0
	else:
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
	if replay_active:
		if key_event.pressed and key_event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			_finish_replay()
		return
	if shootout_end_open:
		if key_event.pressed:
			match key_event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE:
					_shootout_continue()
				KEY_R:
					_shootout_restart()
				KEY_UP, KEY_LEFT:
					shootout_end_index = (shootout_end_index + shootout_end_buttons.size() - 1) % shootout_end_buttons.size()
					shootout_end_buttons[shootout_end_index].grab_focus()
				KEY_DOWN, KEY_RIGHT:
					shootout_end_index = (shootout_end_index + 1) % shootout_end_buttons.size()
					shootout_end_buttons[shootout_end_index].grab_focus()
		return
	var human_team: int = runtime.get_human_team_id()
	if human_team < 0:
		human_team = 0
	if phase_menu_open:
		if key_event.pressed:
			if phase_menu_game_over:
				if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
					_quit_game()
			elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_continue_phase_break()
		return
	if key_event.keycode == KEY_V:
		if key_event.pressed:
			stadium_camera = not stadium_camera
		return
	if key_event.keycode == KEY_F1:
		if key_event.pressed and not key_event.echo:
			lighting_index = (lighting_index + 1) % LIGHTING_PRESETS.size()
			_apply_lighting()
		return
	var shootout_running := bool(runtime.get_snapshot().get("shootout_active", false))
	if key_event.keycode == KEY_F3:
		if key_event.pressed and not shootout_running:
			if taker_menu_open:
				_close_taker_menu(false)
			runtime.debug_force_shootout()
		return
	# The series owns the set pieces, the taker order and the parking: ignore the debug set-piece,
	# Tab and F2 keys while it runs. Movement/action buttons MUST keep flowing to the runtime below —
	# the series needs the aim stick, the shot button and the keeper's dive stick.
	if not shootout_running:
		if key_event.keycode == KEY_F2:
			if key_event.pressed:
				runtime.toggle_debug_park_opponents()
			return
		if key_event.keycode == KEY_TAB:
			if key_event.pressed:
				_toggle_taker_menu()
			return
		if taker_menu_open:
			_handle_taker_menu_key(key_event)
			return
		var set_piece_keys := {
			KEY_P: 6,
			KEY_F: 3,
			KEY_Y: 4,
			KEY_G: 2,
			KEY_O: 5,
		}
		if set_piece_keys.has(key_event.keycode):
			if key_event.pressed:
				var team := human_team
				if key_event.alt_pressed:
					team = 1 - human_team
				var set_piece_type: int = set_piece_keys[key_event.keycode]
				runtime.debug_force_set_piece(set_piece_type, team)
			return
	var functions: Array = BUTTONS.get(key_event.keycode, [])
	for function in functions:
		runtime.set_button(int(function), key_event.pressed)

func _toggle_taker_menu() -> void:
	if taker_menu_open:
		_close_taker_menu(false)
		return
	if not runtime.is_set_piece_taker_menu_available():
		return
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_S) \
			or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A):
		return
	if not runtime.open_set_piece_taker_menu():
		return
	taker_menu_candidates = runtime.get_set_piece_taker_candidates()
	if taker_menu_candidates.is_empty():
		runtime.close_set_piece_taker_menu()
		return
	taker_menu_index = 0
	for i in taker_menu_candidates.size():
		if bool(taker_menu_candidates[i].get("current", false)):
			taker_menu_index = i
			break
	taker_menu_open = true
	taker_menu_layer.visible = true
	_refresh_taker_menu()

func _handle_taker_menu_key(event: InputEventKey) -> void:
	if not event.pressed:
		return
	match event.keycode:
		KEY_UP:
			_move_taker_menu(-1)
		KEY_DOWN:
			_move_taker_menu(1)
		KEY_ENTER, KEY_KP_ENTER:
			_close_taker_menu(true)
		KEY_ESCAPE:
			_close_taker_menu(false)
		KEY_D, KEY_S, KEY_W, KEY_A, KEY_Q, KEY_E, KEY_C:
			_close_taker_menu(false)

func _move_taker_menu(delta: int) -> void:
	var count := taker_menu_candidates.size()
	if count == 0:
		return
	taker_menu_index = (taker_menu_index + delta + count) % count
	_refresh_taker_menu()

func _refresh_taker_menu() -> void:
	var lines := PackedStringArray()
	for i in taker_menu_candidates.size():
		var entry: Dictionary = taker_menu_candidates[i]
		var prefix := "> " if i == taker_menu_index else "  "
		var name := String(entry.get("name", ""))
		var suffix := "  (GK)" if String(entry.get("role", "")) == "goalkeeper" else ""
		var current := "  *" if bool(entry.get("current", false)) else ""
		lines.append("%s%s%s%s" % [prefix, name, suffix, current])
	taker_menu_label.text = "\n".join(lines)

func _close_taker_menu(apply_choice: bool) -> void:
	if not taker_menu_open:
		return
	if apply_choice and taker_menu_index >= 0 and taker_menu_index < taker_menu_candidates.size():
		var chosen := int(taker_menu_candidates[taker_menu_index].get("id", -1))
		if chosen >= 0:
			runtime.request_set_piece_taker(chosen)
	runtime.close_set_piece_taker_menu()
	taker_menu_open = false
	taker_menu_layer.visible = false

func _update_debug_park_visibility(snap: Dictionary) -> void:
	var parked := bool(snap.get("debug_park_opponents", false))
	var human_team: int = runtime.get_human_team_id()
	for entry in actors:
		var id := int(entry.get("id", -1))
		var body: Node3D = actor_bodies.get(id)
		if body == null:
			continue
		var hide: bool = parked and String(entry.get("role", "")) == "player" \
			and (human_team < 0 or int(entry.get("team", -1)) != human_team)
		body.visible = not hide

func _sync_taker_ui(snap: Dictionary) -> void:
	if taker_menu_open and not bool(snap.get("set_piece_taker_menu_open", false)):
		_close_taker_menu(false)
	if taker_hint != null:
		taker_hint.visible = bool(snap.get("set_piece_local_taker", false)) \
			and not taker_menu_open and not phase_menu_open \
			and not bool(snap.get("shootout_active", false)) \
			and bool(snap.get("in_set_piece", false))

func _sync_phase_menu(snap: Dictionary) -> void:
	# The shootout presentation owns the end of the match: it shows its own winner banner and quits.
	if bool(snap.get("shootout_active", false)):
		if phase_menu_open:
			_close_phase_menu()
		return
	var game_over := bool(snap.get("game_over", false))
	var phase_break := bool(snap.get("phase_break_pending", false)) \
		or bool(snap.get("phase_break", false))
	if not game_over and not phase_break:
		if phase_menu_open:
			_close_phase_menu()
		return
	if not phase_menu_open:
		if not game_over and not bool(snap.get("phase_break", false)):
			runtime.begin_phase_break()
		_open_phase_menu(snap)
	else:
		_refresh_phase_menu(snap)

func _open_phase_menu(snap: Dictionary) -> void:
	if taker_menu_open:
		_close_taker_menu(false)
	phase_menu_open = true
	phase_menu_layer.visible = true
	_refresh_phase_menu(snap)
	if phase_menu_game_over:
		phase_menu_quit.grab_focus()
	else:
		phase_menu_continue.grab_focus()

func _refresh_phase_menu(snap: Dictionary) -> void:
	phase_menu_game_over = bool(snap.get("game_over", false))
	var game_over := phase_menu_game_over
	var next_phase := int(snap.get("phase_break_next_phase", 0))
	if game_over:
		var after_extra := int(snap.get("match_time_ms", 0)) >= 7200000 \
			or int(snap.get("match_phase", 0)) == 5
		phase_menu_title.text = "AFTER EXTRA TIME" if after_extra else "FULL TIME"
		phase_menu_subtitle.text = "Final score"
	else:
		phase_menu_title.text = _phase_break_title(next_phase)
		phase_menu_subtitle.text = _phase_break_subtitle(next_phase)
	var home := String(snap.get("team0_name", ""))
	if home == "":
		home = "HOME"
	var away := String(snap.get("team1_name", ""))
	if away == "":
		away = "AWAY"
	phase_menu_score.text = "%s   %d : %d   %s" % [
		home,
		int(snap.get("score0", 0)),
		int(snap.get("score1", 0)),
		away,
	]
	var possession0 := int(snap.get("possession0_ms", 0))
	var possession1 := int(snap.get("possession1_ms", 0))
	var possession_total := possession0 + possession1
	var possession_pct0 := 50
	if possession_total > 0:
		possession_pct0 = int(round(100.0 * float(possession0) / float(possession_total)))
	phase_menu_details.text = "Possession   %d%% - %d%%\nShots        %d - %d" % [
		possession_pct0,
		100 - possession_pct0,
		int(snap.get("shots0", 0)),
		int(snap.get("shots1", 0)),
	]
	phase_menu_continue.visible = not game_over
	if game_over:
		phase_menu_hint.text = "Enter / Esc: exit"
		phase_menu_quit.text = "Exit"
	else:
		phase_menu_hint.text = "Enter / Space: continue"
		phase_menu_quit.text = "Quit"

func _phase_break_title(next_phase: int) -> String:
	match next_phase:
		2:
			return "HALF TIME"
		3:
			return "END OF 90"
		4:
			return "EXTRA TIME"
	return "BREAK"

func _phase_break_subtitle(next_phase: int) -> String:
	match next_phase:
		2:
			return "Begin second half"
		3:
			return "Begin extra time"
		4:
			return "Begin second extra time"
	return "Continue"

func _close_phase_menu() -> void:
	phase_menu_open = false
	phase_menu_layer.visible = false

func _continue_phase_break() -> void:
	if not phase_menu_open or phase_menu_game_over:
		return
	runtime.continue_after_phase_break()
	_close_phase_menu()

func _quit_game() -> void:
	get_tree().quit()

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
		return "GOAL — restart"
	var piece := int(snap.get("referee_set_piece", 0))
	var role := int(snap.get("set_piece_role", 0))
	if bool(snap.get("in_set_piece", false)):
		var human_team := int(runtime.get_human_team_id())
		if piece == 6 and human_team >= 0 and int(snap.get("referee_team", -1)) != human_team:
			return "PENALTY - keeper: arrows to dive"
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
		return "%s — setup" % _set_piece_name(piece)
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

	var net_material := StandardMaterial3D.new()
	net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net_material.albedo_color = Color(0.9, 0.94, 1.0, 0.5)
	net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	goal_net_material = net_material

	_build_goal_frames()

func _build_goal_frames() -> void:
	var goal_scene := load(GOALS_SCENE) as PackedScene
	if goal_scene == null:
		push_warning("Could not load " + GOALS_SCENE)
		return
	var frames := goal_scene.instantiate() as Node3D
	frames.name = "GoalFrames"
	environment_space.add_child(frames)
	for node in frames.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var is_frame := false
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source != null and _material_index(source.resource_name) == 0:
				is_frame = true
				break
		# gpf_goals.glb also contains the static net panels; the live net is
		# rendered from the C++ NetSim positions instead.
		mesh_instance.visible = is_frame
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_dynamic_goal_nets() -> void:
	goal_net_edges = runtime.get_goal_net_edges()
	if goal_net_edges.is_empty():
		push_warning("GpfRuntime returned no goal-net edges")
		return
	var goals := get_node_or_null("Goals") as Node3D
	if goals == null:
		return
	for goal in 2:
		var net := MeshInstance3D.new()
		net.name = "GoalNet%d" % goal
		net.mesh = ImmediateMesh.new()
		net.material_override = goal_net_material
		net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		goals.add_child(net)
		goal_net_meshes.append(net)
		_redraw_goal_net(goal)

func _update_goal_nets() -> void:
	goal_net_positions_cache.clear()
	for goal in goal_net_meshes.size():
		var positions: PackedVector3Array = runtime.get_goal_net_positions(goal)
		goal_net_positions_cache.append(positions)
		_draw_goal_net(goal, positions)

func _redraw_goal_net(goal: int) -> void:
	var positions: PackedVector3Array = runtime.get_goal_net_positions(goal)
	_draw_goal_net(goal, positions)

func _draw_goal_net(goal: int, positions: PackedVector3Array) -> void:
	if goal < 0 or goal >= goal_net_meshes.size():
		return
	var net := goal_net_meshes[goal]
	if positions.is_empty():
		net.visible = false
		return
	net.visible = true
	var mesh := net.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var node_count := positions.size()
	for k in range(goal_net_edges.size() / 2):
		var a := goal_net_edges[k * 2]
		var b := goal_net_edges[k * 2 + 1]
		if a < 0 or b < 0 or a >= node_count or b >= node_count:
			continue
		mesh.surface_add_vertex(positions[a])
		mesh.surface_add_vertex(positions[b])
	mesh.surface_end()

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

	taker_hint = Label.new()
	taker_hint.position = Vector2(24, 150)
	taker_hint.add_theme_font_size_override("font_size", 18)
	taker_hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	taker_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	taker_hint.add_theme_constant_override("outline_size", 4)
	taker_hint.text = "Tab: change taker"
	taker_hint.visible = false
	layer.add_child(taker_hint)

func _build_taker_menu() -> void:
	taker_menu_layer = CanvasLayer.new()
	taker_menu_layer.layer = 2
	add_child(taker_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	taker_menu_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	taker_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.96)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SET-PIECE TAKER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(title)

	taker_menu_label = Label.new()
	taker_menu_label.add_theme_font_size_override("font_size", 20)
	taker_menu_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	box.add_child(taker_menu_label)

	var hint := Label.new()
	hint.text = "Up/Down select    Enter apply    Esc/Tab close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(hint)

	taker_menu_layer.visible = false

func _build_phase_menu() -> void:
	phase_menu_layer = CanvasLayer.new()
	phase_menu_layer.layer = 3
	add_child(phase_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_menu_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	phase_menu_title = Label.new()
	phase_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_title.add_theme_font_size_override("font_size", 32)
	phase_menu_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(phase_menu_title)

	phase_menu_subtitle = Label.new()
	phase_menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_subtitle.add_theme_font_size_override("font_size", 18)
	phase_menu_subtitle.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
	box.add_child(phase_menu_subtitle)

	phase_menu_score = Label.new()
	phase_menu_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_score.add_theme_font_size_override("font_size", 28)
	phase_menu_score.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	box.add_child(phase_menu_score)

	phase_menu_details = Label.new()
	phase_menu_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_details.add_theme_font_size_override("font_size", 18)
	phase_menu_details.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	box.add_child(phase_menu_details)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	phase_menu_continue = Button.new()
	phase_menu_continue.text = "Continue"
	phase_menu_continue.custom_minimum_size = Vector2(160, 40)
	buttons.add_child(phase_menu_continue)
	phase_menu_continue.pressed.connect(_continue_phase_break)

	phase_menu_quit = Button.new()
	phase_menu_quit.text = "Quit"
	phase_menu_quit.custom_minimum_size = Vector2(160, 40)
	buttons.add_child(phase_menu_quit)
	phase_menu_quit.pressed.connect(_quit_game)

	phase_menu_hint = Label.new()
	phase_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_hint.add_theme_font_size_override("font_size", 14)
	phase_menu_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(phase_menu_hint)

	phase_menu_layer.visible = false

func _build_shootout_ui() -> void:
	shootout_layer = CanvasLayer.new()
	shootout_layer.layer = 4
	shootout_layer.visible = false
	add_child(shootout_layer)

	# Fade first: circles and banners stay above it.
	shootout_fade = ColorRect.new()
	shootout_fade.color = Color(0, 0, 0, 0)
	shootout_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shootout_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shootout_layer.add_child(shootout_fade)

	shootout_home_row = HBoxContainer.new()
	shootout_home_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shootout_home_row.add_theme_constant_override("separation", 10)
	shootout_home_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	shootout_home_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shootout_home_row.offset_top = 18
	shootout_layer.add_child(shootout_home_row)

	shootout_away_row = HBoxContainer.new()
	shootout_away_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shootout_away_row.add_theme_constant_override("separation", 10)
	shootout_away_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	shootout_away_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shootout_away_row.offset_bottom = -18
	shootout_layer.add_child(shootout_away_row)

	shootout_banner = Label.new()
	shootout_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shootout_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shootout_banner.offset_top = -120
	shootout_banner.add_theme_font_size_override("font_size", 44)
	shootout_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	shootout_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	shootout_banner.add_theme_constant_override("outline_size", 8)
	shootout_banner.visible = false
	shootout_layer.add_child(shootout_banner)

	_build_shootout_end_menu()

func _build_shootout_end_menu() -> void:
	shootout_end_layer = CanvasLayer.new()
	shootout_end_layer.layer = 5
	shootout_end_layer.visible = false
	add_child(shootout_end_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shootout_end_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shootout_end_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "КОНЕЦ МАТЧА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(title)

	shootout_end_score = Label.new()
	shootout_end_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shootout_end_score.add_theme_font_size_override("font_size", 28)
	shootout_end_score.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	box.add_child(shootout_end_score)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	var continue_button := Button.new()
	continue_button.text = "Продолжить"
	continue_button.custom_minimum_size = Vector2(180, 42)
	continue_button.pressed.connect(_shootout_continue)
	buttons.add_child(continue_button)
	shootout_end_buttons.append(continue_button)

	var restart_button := Button.new()
	restart_button.text = "Начать заново"
	restart_button.custom_minimum_size = Vector2(180, 42)
	restart_button.pressed.connect(_shootout_restart)
	buttons.add_child(restart_button)
	shootout_end_buttons.append(restart_button)

	var hint := Label.new()
	hint.text = "Enter — продолжить    R — начать заново"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(hint)

func _shootout_open_end_menu(snap: Dictionary) -> void:
	shootout_end_open = true
	shootout_end_index = 0
	var score0 := int(snap.get("shootout_score0", 0))
	var score1 := int(snap.get("shootout_score1", 0))
	shootout_end_score.text = "Победа: %d:%d" % [maxi(score0, score1), mini(score0, score1)]
	shootout_end_layer.visible = true
	shootout_banner.visible = false
	shootout_end_buttons[shootout_end_index].grab_focus()

func _shootout_continue() -> void:
	get_tree().quit()

func _shootout_restart() -> void:
	# The C++ match runtime is one-shot: restart the whole game process for a fresh match.
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()

func _update_shootout(snap: Dictionary, delta: float) -> void:
	var active := bool(snap.get("shootout_active", false))
	shootout_layer.visible = active
	if not active:
		return

	var kicks0: Array = snap.get("shootout_kicks0", [])
	var kicks1: Array = snap.get("shootout_kicks1", [])
	var count := maxi(5, maxi(kicks0.size(), kicks1.size()))
	_shootout_ensure_circles(0, count)
	_shootout_ensure_circles(1, count)
	for team in [0, 1]:
		var results: Array = kicks0 if team == 0 else kicks1
		for i in shootout_circles[team].size():
			var value := int(results[i]) if i < results.size() else 0
			var panel: Panel = shootout_circles[team][i]
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style != null:
				style.bg_color = SHOOTOUT_CIRCLE_COLORS.get(value, SHOOTOUT_CIRCLE_COLORS[0])

	var counter := int(snap.get("shootout_outcome_counter", 0))
	if counter != shootout_outcome_counter:
		shootout_outcome_counter = counter
		var text: String = SHOOTOUT_OUTCOME_TEXT.get(int(snap.get("shootout_outcome", 0)), "")
		if text != "":
			shootout_banner.text = text
			shootout_banner.visible = true
			shootout_banner_left = SHOOTOUT_BANNER_TIME
	if shootout_banner_left > 0.0:
		shootout_banner_left -= delta
		if shootout_banner_left <= 0.0:
			shootout_banner.visible = false

	var phase := int(snap.get("shootout_phase", 0))
	if phase != shootout_last_phase:
		if phase == SHOOTOUT_PHASE_TRANSITION:
			# The C++ side repositions everybody only after this fade is fully black.
			_shootout_fade_to(1.0)
		elif phase == SHOOTOUT_PHASE_KICK_AIM:
			# Players are in place and the whistle has blown: fade the pitch back in.
			_shootout_fade_to(0.0)
		shootout_last_phase = phase

	if phase == SHOOTOUT_PHASE_FINISHED and not shootout_end_open:
		# The decisive celebration has finished and the C++ frame is paused: show the end menu.
		_shootout_fade_to(0.0, 0.4)
		_shootout_open_end_menu(snap)

func _shootout_ensure_circles(team: int, count: int) -> void:
	var row: HBoxContainer = shootout_home_row if team == 0 else shootout_away_row
	var circles: Array = shootout_circles[team]
	while circles.size() < count:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(SHOOTOUT_CIRCLE_SIZE, SHOOTOUT_CIRCLE_SIZE)
		var style := StyleBoxFlat.new()
		style.bg_color = SHOOTOUT_CIRCLE_COLORS[0]
		style.set_corner_radius_all(int(SHOOTOUT_CIRCLE_SIZE * 0.5))
		style.set_border_width_all(2)
		style.border_color = Color(0, 0, 0, 0.7)
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		circles.append(panel)
	shootout_circles[team] = circles

func _shootout_fade_to(alpha: float, duration: float = SHOOTOUT_FADE_TIME) -> void:
	if shootout_fade_tween != null and shootout_fade_tween.is_valid():
		shootout_fade_tween.kill()
	shootout_fade_tween = create_tween()
	shootout_fade_tween.tween_property(shootout_fade, "color:a", alpha, duration)
