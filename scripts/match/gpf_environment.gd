class_name GpfEnvironment
extends Node3D
# Presentation of the stadium world: procedural sky/fog, sun/fill lighting presets,
# the imported stadium and the merged pitch with its C++ generated texture.
# The node transform is the raw-asset -> world basis (set in gpf_slice.tscn).

const STADIUM_SCENE := "res://assets/models/gpf_stadium.glb"
const PITCH_SCENE := "res://assets/models/gpf_pitch.glb"
const PITCH_SHADER := "res://shaders/pitch.gdshader"
# The original generator's inputs (GameplayFootball data/media/textures/pitch).
const PITCH_GRASS_TEXTURE := "res://assets/gpf/media/textures/pitch/seamlessgrass08.png"
const PITCH_OVERLAY_TEXTURE := "res://assets/gpf/media/textures/pitch/overlay.png"
# 34 px/m, the original's macro-map density (the pitch is 120 x 80 m).
const PITCH_TEXTURE_WIDTH := 4096
const PITCH_TEXTURE_HEIGHT := 2731
# Detail layer: the grass tile repeated every 2 m in world space, because one
# macro map stretched over the whole plane has no micro-detail when the camera
# is low. The pitch shader fades it out once its texels go sub-pixel.
const PITCH_DETAIL_METERS := 2.0
const PITCH_DETAIL_SIZE := 1024
const PITCH_DETAIL_STRENGTH := 0.7
# Luminance slope to height scale for the detail normal (higher = flatter).
const PITCH_DETAIL_NORMAL_STRENGTH := 8.0
const PITCH_THEMES := {
	"dry": {"albedo": Color(1.0, 1.0, 1.0), "roughness": 0.95},
	"wet": {"albedo": Color(0.72, 0.82, 0.78), "roughness": 0.28},
	"damp": {"albedo": Color(0.86, 0.92, 0.86), "roughness": 0.62},
	"snow": {"albedo": Color(0.92, 0.95, 0.98), "roughness": 0.82},
}
# The four floodlight truss clusters in mat28_metal (raw space: Z up, Y across
# the pitch). Fixtures and their night cones hang just inside each cluster.
const FLOODLIGHT_CENTERS := [
	Vector3(33.0, 50.4, 37.2), Vector3(-33.0, 50.4, 37.2),
	Vector3(33.0, -50.4, 37.2), Vector3(-33.0, -50.4, 37.2),
]

# Derived from Match::SetRandomSunParams (match.cpp): the original picks a
# random sun direction and blends a cool noon colour with a warm dusk colour.
# The presets extend that idea into distinct debug moods.
const LIGHTING_PRESETS := [
	{
		"name": "Noon",
		"net_tint": Color(0.72, 0.75, 0.78, 0.45),
		"sun_pos": Vector3(-0.30, 0.60, 1.10),
		"sun_color": Color(1.00, 0.92, 0.80),
		"sun_energy": 1.00,
		"ambient": 0.42,
		"ambient_color": Color(0.68, 0.66, 0.62),
		"fill_energy": 0.15,
		"fill_color": Color(0.82, 0.82, 0.84),
		"exposure": 1.00,
		"sky_top": Color(0.22, 0.40, 0.62),
		"sky_horizon": Color(0.86, 0.87, 0.88),
		"ground_horizon": Color(0.38, 0.36, 0.33),
		"sky_energy": 1.00,
		"fog_color": Color(0.68, 0.80, 0.94),
		"fog_density": 0.0,
		"sun_disk": 1.0,
		"contrast": 1.02,
		"saturation": 1.0,
		"brightness": 1.0,
		"shadows": true,
	},
	{
		"name": "Afternoon",
		"net_tint": Color(0.62, 0.57, 0.52, 0.45),
		"sun_pos": Vector3(0.90, 0.60, 0.90),
		"sun_color": Color(1.0, 0.84, 0.65),
		"sun_energy": 0.70,
		"ambient": 0.38,
		"ambient_color": Color(0.57, 0.61, 0.72),
		"fill_energy": 0.28,
		"fill_color": Color(0.95, 0.82, 0.70),
		"exposure": 0.95,
		"sky_top": Color(0.16, 0.36, 0.62),
		"sky_horizon": Color(0.92, 0.75, 0.58),
		"ground_horizon": Color(0.38, 0.34, 0.30),
		"sky_energy": 0.90,
		"fog_color": Color(0.85, 0.72, 0.58),
		"fog_density": 0.0001,
		"sun_disk": 1.5,
		"contrast": 1.03,
		"saturation": 1.03,
		"brightness": 1.0,
		"shadows": true,
	},
	{
		"name": "Sunset",
		"net_tint": Color(0.6, 0.46, 0.4, 0.42),
		"sun_pos": Vector3(-1.10, 0.35, 0.80),
		"sun_color": Color(1.0, 0.58, 0.34),
		"sun_energy": 0.75,
		"ambient": 0.50,
		"ambient_color": Color(0.60, 0.50, 0.52),
		"fill_energy": 0.45,
		"fill_color": Color(0.92, 0.68, 0.50),
		"exposure": 1.0,
		"sky_top": Color(0.16, 0.13, 0.28),
		"sky_horizon": Color(0.90, 0.62, 0.42),
		"ground_horizon": Color(0.32, 0.24, 0.22),
		"sky_energy": 0.9,
		"fog_color": Color(0.82, 0.58, 0.44),
		"fog_density": 0.00008,
		"sun_disk": 2.0,
		"contrast": 1.03,
		"saturation": 1.0,
		"brightness": 1.0,
		# The warm low sun turns the shaded mow bands brown; green them back and
		# soften the stripe relief.
		"pitch_tint": Color(1.06, 1.16, 1.04),
		"pitch_normal_strength": 0.55,
		"shadows": true,
	},
	{
		"name": "Night",
		"net_tint": Color(0.35, 0.4, 0.5, 0.38),
		"sun_pos": Vector3(0.20, 1.20, 0.20),
		"sun_color": Color(0.85, 0.90, 1.00),
		"sun_energy": 0.65,
		# The roof blocks the key on the stands; a cool ambient/fill lift keeps the
		# bowl readable while the four cones keep the pitch and its shadows.
		"ambient": 0.34,
		"ambient_color": Color(0.20, 0.24, 0.34),
		"fill_energy": 0.22,
		"fill_color": Color(0.80, 0.88, 1.00),
		"exposure": 1.05,
		"sky_top": Color(0.015, 0.03, 0.08),
		"sky_horizon": Color(0.05, 0.09, 0.17),
		"ground_horizon": Color(0.02, 0.025, 0.04),
		"sky_energy": 0.90,
		"fog_color": Color(0.05, 0.08, 0.14),
		"fog_density": 0.00012,
		"sun_disk": 0.0,
		"contrast": 1.05,
		"saturation": 0.95,
		"brightness": 1.0,
		# Floodlit grass reads cool against the dark stands; soften the stripes.
		"pitch_tint": Color(0.86, 0.96, 1.10),
		"pitch_normal_strength": 1.0,
		"floodlights": true,
		"shadows": true,
	},
]

var pitch_root: Node3D
var pitch_materials: Array[ShaderMaterial] = []
var pitch_theme := "dry"
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var lighting_index := 1
var floodlights: Node3D
var flood_lights: Array[Light3D] = []
var goal_lights: Array[SpotLight3D] = []
var _seat_materials: Array[StandardMaterial3D] = []

var _runtime: Node
var _pitch_grass: Image
var _pitch_overlay: Image

static var _pitch_detail_cache := {}


func setup(runtime: Node, sun: DirectionalLight3D, fill: DirectionalLight3D) -> void:
	_runtime = runtime
	_build_world_environment(sun, fill)
	_build_environment()


func set_lighting(index: int) -> void:
	lighting_index = posmod(index, LIGHTING_PRESETS.size())
	_apply_lighting()


func set_lighting_by_name(name: String) -> void:
	for i in LIGHTING_PRESETS.size():
		if String(LIGHTING_PRESETS[i]["name"]).to_lower() == name.to_lower():
			set_lighting(i)
			return


func cycle_lighting() -> void:
	set_lighting(lighting_index + 1)


func lighting_name() -> String:
	return String(LIGHTING_PRESETS[lighting_index % LIGHTING_PRESETS.size()]["name"])


# The live net is unshaded lines; tint it by hand so it reads with the preset.
func lighting_net_tint() -> Color:
	var preset: Dictionary = LIGHTING_PRESETS[lighting_index % LIGHTING_PRESETS.size()]
	return preset.get("net_tint", Color(1.0, 1.0, 1.0, 0.5))


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
	environment.ambient_light_color = Color(0.56, 0.64, 0.78)
	environment.ambient_light_energy = 0.40
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.adjustment_enabled = true
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
	sun_light.shadow_bias = 0.04
	sun_light.shadow_normal_bias = 1.2

	fill_light = fill
	if fill_light == null:
		fill_light = DirectionalLight3D.new()
		fill_light.name = "FillLight"
		add_child(fill_light)
	fill_light.light_color = Color(0.62, 0.74, 1.0)
	fill_light.light_energy = 0.16
	fill_light.shadow_enabled = false

	# Night's floodlight rig: four shadowless cones from the roof fixtures. One
	# shadowed key (Sun) plus these reads as a floodlit pitch; stands and the
	# outside slab stay night-dark instead of being flattened by extra fills.
	flood_lights.clear()
	for i in FLOODLIGHT_CENTERS.size():
		var raw: Vector3 = FLOODLIGHT_CENTERS[i]
		var spot := SpotLight3D.new()
		spot.name = "Floodlight%d" % i
		spot.light_color = Color(0.88, 0.93, 1.0)
		# Inverse-square at ~50 m: single-digit energy is invisible, four digits
		# blow the tonemap white. 45 per bank plus the key reads floodlit; the
		# shadows let the players ground instead of floating in flat light.
		spot.light_energy = 45.0
		spot.spot_range = 220.0
		spot.spot_angle = 55.0
		spot.spot_angle_attenuation = 1.0
		# One shadowed bank; four shadow directions read as four suns.
		spot.shadow_enabled = i == 0
		# The Environment basis mirrors raw space (det -1); the rig lives beside
		# it in world space, like the Sun and FillLight in the slice scene.
		get_parent().add_child(spot)
		spot.global_position = Vector3(raw.x, raw.z, raw.y)
		# Each bank lights its own quarter, so the centre is not quadruple-lit and
		# the corners/goals stay inside a cone.
		spot.look_at(Vector3(signf(raw.x) * 25.0, 0.0, signf(raw.y) * 18.0), Vector3.UP)
		spot.visible = false
		flood_lights.append(spot)

	# Two washes aimed at the end stands: the pitch cones leave the frames and
	# the lower end stands black, and a stadium never is. An omni was too weak
	# at stand distance, so aim a cone from above the goal at the end tier.
	for goal in 2:
		var wash := SpotLight3D.new()
		wash.name = "GoalWash%d" % goal
		wash.light_color = Color(0.85, 0.90, 1.0)
		wash.light_energy = 50.0
		wash.spot_range = 50.0
		wash.spot_angle = 70.0
		wash.spot_angle_attenuation = 1.0
		wash.shadow_enabled = false
		get_parent().add_child(wash)
		var end_sign := 1.0 if goal == 0 else -1.0
		# Sit above the goal and aim at the track behind it: the frame, the
		# crossbar, the run-off strip and the lower tier are all inside the cone.
		wash.global_position = Vector3(0.0, 8.0, end_sign * 50.0)
		wash.look_at(Vector3(0.0, 0.0, end_sign * 58.0), Vector3.UP)
		wash.visible = false
		goal_lights.append(wash)

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
	world_environment.adjustment_contrast = preset["contrast"]
	world_environment.adjustment_saturation = preset["saturation"]
	world_environment.adjustment_brightness = preset["brightness"]
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
	var floodlit := bool(preset.get("floodlights", false))
	if floodlights != null:
		floodlights.visible = floodlit
	for flood in flood_lights:
		flood.visible = floodlit
	for lamp in goal_lights:
		lamp.visible = floodlit
	# The crowd/seat texture is near-black; at night it reads as a void. Lift the
	# albedo instead of adding more lights (the fixtures are already lit).
	for seat in _seat_materials:
		seat.albedo_color = Color(1.2, 1.25, 1.35) if floodlit else Color.WHITE
	_refresh_pitch_tint()


func _build_environment() -> void:
	var stadium_scene := load(STADIUM_SCENE) as PackedScene
	if stadium_scene != null:
		var stadium := stadium_scene.instantiate() as Node3D
		stadium.name = "Stadium"
		add_child(stadium)
		_fix_stadium_materials(stadium)
		_build_floodlights(stadium)
		_apply_lighting()

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
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var material_index := GpfAssets.material_index(source.resource_name)
			if material_index == 0:
				# The flat run-off apron around the pitch: an athletics-track
				# surface instead of the dark green floor.
				var track := source.duplicate() as StandardMaterial3D
				if track != null:
					track.albedo_color = Color(0.62, 0.30, 0.14)
					track.roughness = 0.92
					mesh_instance.set_surface_override_material(surface, track)
				continue
			if material_index == 1:
				# The concrete bowl wall is one-sided in the .ase; from inside
				# the bowl its back faces were culled into a black band.
				var concrete := source.duplicate() as StandardMaterial3D
				if concrete != null:
					concrete.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_instance.set_surface_override_material(surface, concrete)
				continue
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
				_seat_materials.append(material)
			if material_index == 29:
				# The pitch barrier (hekje) is a one-sided wall in the .ase; from
				# inside the bowl its inner face was culled and read as a black void.
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				# The barrier reads as the athletics-track apron behind the ads.
				material.albedo_color = Color(0.72, 0.33, 0.16)
			mesh_instance.set_surface_override_material(surface, material)


# The floodlight truss (mat28_metal) runs along the roof rim in four clusters;
# the emissive panels sit just inside each cluster, facing the pitch. Children of
# the imported stadium, so they inherit its raw-space transform.
func _build_floodlights(stadium: Node3D) -> void:
	var group := Node3D.new()
	group.name = "Floodlights"
	stadium.add_child(group)
	var panel := BoxMesh.new()
	panel.size = Vector3(20.0, 0.4, 2.6)
	var material := StandardMaterial3D.new()
	material.resource_name = "FloodlightPanel"
	material.albedo_color = Color(1.0, 0.97, 0.88)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.95, 0.84)
	material.emission_energy_multiplier = 4.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in FLOODLIGHT_CENTERS.size():
		var fixture := MeshInstance3D.new()
		fixture.name = "Panel%d" % i
		fixture.mesh = panel
		fixture.material_override = material
		fixture.position = FLOODLIGHT_CENTERS[i]
		fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(fixture)
	group.visible = false
	floodlights = group


func _apply_pitch_texture(root: Node3D) -> void:
	var grass := _pitch_source_image(PITCH_GRASS_TEXTURE)
	var overlay := _pitch_source_image(PITCH_OVERLAY_TEXTURE)
	if grass == null or overlay == null:
		push_warning("GpfEnvironment: pitch source images are missing")
		return
	_pitch_grass = grass
	_pitch_overlay = overlay
	var maps: Dictionary = _runtime.generate_pitch_maps(
		PITCH_TEXTURE_WIDTH, PITCH_TEXTURE_HEIGHT, grass, overlay)
	var albedo := maps.get("albedo") as Image
	var normal := maps.get("normal") as Image
	var roughness := maps.get("roughness") as Image
	if albedo == null or albedo.is_empty() or normal == null or roughness == null:
		push_warning("GpfRuntime returned no pitch maps")
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
				var normal_vector := Vector3.UP
				if i < src_normals.size():
					normal_vector = (xform.basis * src_normals[i]).normalized()
				normals.append(normal_vector)
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
	# The merged chunk mesh ships without tangents; the normal map needs them.
	var tangent_tool := SurfaceTool.new()
	tangent_tool.create_from(combined, 0)
	tangent_tool.generate_tangents()
	combined = tangent_tool.commit()

	for image in [albedo, normal, roughness]:
		image.generate_mipmaps()
	var detail: Dictionary = pitch_detail_maps(grass)
	var material := ShaderMaterial.new()
	material.shader = load(PITCH_SHADER)
	material.set_shader_parameter("albedo_map", ImageTexture.create_from_image(albedo))
	material.set_shader_parameter("normal_map", ImageTexture.create_from_image(normal))
	material.set_shader_parameter("roughness_map", ImageTexture.create_from_image(roughness))
	material.set_shader_parameter("detail_albedo", ImageTexture.create_from_image(detail["albedo"]))
	material.set_shader_parameter("detail_normal", ImageTexture.create_from_image(detail["normal"]))
	material.set_shader_parameter("detail_meters", PITCH_DETAIL_METERS)
	material.set_shader_parameter("detail_strength", PITCH_DETAIL_STRENGTH)
	pitch_materials.append(material)
	var surface := MeshInstance3D.new()
	surface.name = "PitchSurface"
	surface.mesh = combined
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(surface)
	set_pitch_theme(pitch_theme)


func _pitch_source_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


# Micro-detail for the pitch plane, built from the same seamless grass tile:
# the tile itself (the shader blends it in) plus a tangent-space normal from its
# luminance (central differences, wrapped so the normal tiles seamlessly too).
# Cached for the process; the source tile never changes.
static func pitch_detail_maps(grass: Image) -> Dictionary:
	if not _pitch_detail_cache.is_empty():
		return _pitch_detail_cache
	var size := PITCH_DETAIL_SIZE
	var tile := grass.duplicate() as Image
	tile.convert(Image.FORMAT_RGBA8)
	tile.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var texels := tile.get_data()
	var height := PackedFloat32Array()
	height.resize(size * size)
	for i in size * size:
		height[i] = texels[i * 4] * 0.299 + texels[i * 4 + 1] * 0.587 + texels[i * 4 + 2] * 0.114
	var normal_bytes := PackedByteArray()
	normal_bytes.resize(size * size * 4)
	var flat := 255.0 / PITCH_DETAIL_NORMAL_STRENGTH
	for y in size:
		var up := ((y + size - 1) % size) * size
		var down := ((y + 1) % size) * size
		var row := y * size
		for x in size:
			var left := (x + size - 1) % size
			var right := (x + 1) % size
			var n := Vector3(
				-(height[row + right] - height[row + left]) * 0.5,
				-(height[down + x] - height[up + x]) * 0.5,
				flat
			).normalized()
			var i := (row + x) * 4
			normal_bytes[i] = int((n.x * 0.5 + 0.5) * 255.0)
			normal_bytes[i + 1] = int((n.y * 0.5 + 0.5) * 255.0)
			normal_bytes[i + 2] = int((n.z * 0.5 + 0.5) * 255.0)
			normal_bytes[i + 3] = 255
	var detail_albedo := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, texels)
	var detail_normal := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, normal_bytes)
	for image in [detail_albedo, detail_normal]:
		image.generate_mipmaps()
	_pitch_detail_cache = {"albedo": detail_albedo, "normal": detail_normal}
	return _pitch_detail_cache


# Debug key F7: re-roll the mottling and the mow pattern without a new match.
# The generator takes ~0.6 s, so this is a deliberate one-frame hitch.
func regenerate_pitch() -> void:
	if _pitch_grass == null or _pitch_overlay == null or pitch_materials.is_empty():
		return
	var started := Time.get_ticks_msec()
	var maps: Dictionary = _runtime.generate_pitch_maps(
		PITCH_TEXTURE_WIDTH, PITCH_TEXTURE_HEIGHT, _pitch_grass, _pitch_overlay)
	var albedo := maps.get("albedo") as Image
	var normal := maps.get("normal") as Image
	var roughness := maps.get("roughness") as Image
	if albedo == null or normal == null or roughness == null:
		return
	for image in [albedo, normal, roughness]:
		image.generate_mipmaps()
	for material in pitch_materials:
		material.set_shader_parameter("albedo_map", ImageTexture.create_from_image(albedo))
		material.set_shader_parameter("normal_map", ImageTexture.create_from_image(normal))
		material.set_shader_parameter("roughness_map", ImageTexture.create_from_image(roughness))
	print("pitch regenerated in ", Time.get_ticks_msec() - started, " ms")


func _refresh_pitch_tint() -> void:
	var colors: Dictionary = PITCH_THEMES.get(pitch_theme, PITCH_THEMES["dry"])
	var preset: Dictionary = LIGHTING_PRESETS[lighting_index % LIGHTING_PRESETS.size()]
	var tint: Color = preset.get("pitch_tint", Color.WHITE)
	for material in pitch_materials:
		material.set_shader_parameter("pitch_tint", Color(
			colors["albedo"].r * tint.r,
			colors["albedo"].g * tint.g,
			colors["albedo"].b * tint.b,
			colors["albedo"].a
		))
		material.set_shader_parameter("pitch_roughness", colors["roughness"])
		material.set_shader_parameter("pitch_normal_strength",
			float(preset.get("pitch_normal_strength", 1.0)))
