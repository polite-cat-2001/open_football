class_name GpfGoalNets
extends Node3D
# Goal presentation: the imported white frames (parented to the environment frame) and
# the live net rendered from the original C++ NetSim node positions as a lit,
# textured triangle mesh (the original game's goalnetting material).

const GOALS_SCENE := "res://assets/models/gpf_goals.glb"
const NET_SHADER := "res://shaders/goal_net.gdshader"

var goal_net_meshes: Array[MeshInstance3D] = []
var goal_net_positions_cache: Array = []
var goal_net_material: Material
var _frame_materials: Array[StandardMaterial3D] = []
var _net_uvs := PackedVector2Array()
var _net_indices := PackedInt32Array()
var _net_drawn: Array = []

var _runtime: Node


func setup(runtime: Node, environment: Node3D) -> void:
	_runtime = runtime
	_build_material()
	_build_goal_frames(environment)


func build_dynamic() -> void:
	var layout: Dictionary = _runtime.get_goal_net_layout()
	if layout.is_empty():
		push_warning("GpfRuntime returned no goal-net layout")
		return
	_build_topology(layout)
	for goal in 2:
		var net := MeshInstance3D.new()
		net.name = "GoalNet%d" % goal
		net.mesh = ArrayMesh.new()
		net.material_override = goal_net_material
		net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(net)
		goal_net_meshes.append(net)
		_net_drawn.append(null)
		_redraw(goal)


func update() -> void:
	goal_net_positions_cache.clear()
	for goal in goal_net_meshes.size():
		var positions: PackedVector3Array = _runtime.get_goal_net_positions(goal)
		goal_net_positions_cache.append(positions)
		draw(goal, positions)


# The imported frame is white but the floodlights leave its crossbar black from
# some angles; a slight night emission keeps the goal readable.
func set_frame_night(enabled: bool) -> void:
	for material in _frame_materials:
		material.emission_enabled = enabled
		material.emission = Color(0.55, 0.60, 0.70)
		material.emission_energy_multiplier = 0.6


func get_positions() -> Array:
	return goal_net_positions_cache.duplicate()


func apply_positions(positions: Array) -> void:
	for goal in mini(goal_net_meshes.size(), positions.size()):
		draw(goal, positions[goal])


func draw(goal: int, positions: PackedVector3Array) -> void:
	if goal < 0 or goal >= goal_net_meshes.size():
		return
	var net := goal_net_meshes[goal]
	if positions.is_empty():
		net.visible = false
		return
	net.visible = true
	# The cloth only moves while the ball presses it; skip the upload otherwise.
	if positions == _net_drawn[goal]:
		return
	if positions.size() != _net_uvs.size():
		push_warning("Goal-net node count does not match the NetSim layout")
		net.visible = false
		return
	_net_drawn[goal] = positions
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = _net_uvs
	arrays[Mesh.ARRAY_INDEX] = _net_indices
	var mesh := net.mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# Mirrors netsim::BuildBoxNet's panel order (back, top, left, right) and its
# node layout, one texture tile per cell as in the original goal net.
func _build_topology(layout: Dictionary) -> void:
	var panels: Array[Vector2i] = [
		Vector2i(layout["width"], layout["height"]),
		Vector2i(layout["width"], layout["depth"]),
		Vector2i(layout["depth"], layout["height"]),
		Vector2i(layout["depth"], layout["height"]),
	]
	var base := 0
	for panel in panels:
		var cols := panel.x + 1
		for j in panel.y + 1:
			for i in cols:
				_net_uvs.append(Vector2(i, j))
		for j in panel.y:
			for i in panel.x:
				var a := base + j * cols + i
				_net_indices.append(a)
				_net_indices.append(a + 1)
				_net_indices.append(a + cols + 1)
				_net_indices.append(a)
				_net_indices.append(a + cols + 1)
				_net_indices.append(a + cols)
		base += cols * (panel.y + 1)


func _build_material() -> void:
	var shader := load(NET_SHADER) as Shader
	if shader == null:
		push_warning("Could not load the goal-net shader")
		return
	var net_material := ShaderMaterial.new()
	net_material.shader = shader
	net_material.set_shader_parameter("net_tint", Color(0.96, 0.98, 1.0))
	goal_net_material = net_material


func _build_goal_frames(environment: Node3D) -> void:
	var goal_scene := load(GOALS_SCENE) as PackedScene
	if goal_scene == null:
		push_warning("Could not load " + GOALS_SCENE)
		return
	var frames := goal_scene.instantiate() as Node3D
	frames.name = "GoalFrames"
	environment.add_child(frames)
	for node in frames.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var is_frame := false
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source != null and GpfAssets.material_index(source.resource_name) == 0:
				is_frame = true
				break
		# gpf_goals.glb also contains the static net panels; the live net is
		# rendered from the C++ NetSim positions instead.
		mesh_instance.visible = is_frame
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if is_frame:
			for surface in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.mesh.surface_get_material(surface)
				if source == null:
					continue
				var frame_material := source.duplicate() as StandardMaterial3D
				if frame_material != null:
					mesh_instance.set_surface_override_material(surface, frame_material)
					_frame_materials.append(frame_material)


func _redraw(goal: int) -> void:
	draw(goal, _runtime.get_goal_net_positions(goal))
