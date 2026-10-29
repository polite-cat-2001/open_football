class_name GpfEnvironment
extends Node3D
# Presentation of the stadium world: procedural sky/fog, sun/fill lighting presets,
# the imported stadium and the merged pitch with its C++ generated texture.
# The node transform is the raw-asset -> world basis (set in gpf_slice.tscn).

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

var pitch_root: Node3D
var pitch_materials: Array[StandardMaterial3D] = []
var pitch_theme := "dry"
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var lighting_index := 1

var _runtime: Node


func setup(runtime: Node, sun: DirectionalLight3D, fill: DirectionalLight3D) -> void:
	_runtime = runtime
	_build_world_environment(sun, fill)
	_build_environment()


func cycle_lighting() -> void:
	lighting_index = (lighting_index + 1) % LIGHTING_PRESETS.size()
	_apply_lighting()


func lighting_name() -> String:
	return String(LIGHTING_PRESETS[lighting_index % LIGHTING_PRESETS.size()]["name"])


func set_pitch_theme(theme: String) -> void:
	pitch_theme = theme
	_refresh_pitch_tint()


func _build_world_environment(sun: DirectionalLight3D, fill: DirectionalLight3D) -> void:
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

	sun_light = sun
	if sun_light == null:
		sun_light = DirectionalLight3D.new()
		sun_light.name = "Sun"
		add_child(sun_light)
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_max_distance = 170.0
	sun_light.shadow_bias = 0.05
	sun_light.shadow_normal_bias = 1.5

	fill_light = fill
	if fill_light == null:
		fill_light = DirectionalLight3D.new()
		fill_light.name = "FillLight"
		add_child(fill_light)
	fill_light.light_color = Color(0.62, 0.74, 1.0)
	fill_light.light_energy = 0.16
	fill_light.shadow_enabled = false

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
		add_child(stadium)
		_fix_stadium_materials(stadium)

	var pitch_scene := load(PITCH_SCENE) as PackedScene
	if pitch_scene != null:
		pitch_root = pitch_scene.instantiate() as Node3D
		pitch_root.name = "Pitch"
		pitch_root.position = Vector3(0.0, 0.0, 0.01)
		add_child(pitch_root)
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
			var material_index := GpfAssets.material_index(source.resource_name)
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


func _apply_pitch_texture(root: Node3D) -> void:
	var image: Image = _runtime.generate_pitch_texture(PITCH_TEXTURE_WIDTH, PITCH_TEXTURE_HEIGHT)
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
