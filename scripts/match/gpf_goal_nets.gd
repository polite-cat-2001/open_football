class_name GpfGoalNets
extends Node3D
# Goal presentation: the imported white frames (parented to the environment frame) and
# the live net lines rendered from the original C++ NetSim node positions.

const GOALS_SCENE := "res://assets/models/gpf_goals.glb"

var goal_net_meshes: Array[MeshInstance3D] = []
var goal_net_edges: PackedInt32Array
var goal_net_positions_cache: Array = []
var goal_net_material: Material

var _runtime: Node


func setup(runtime: Node, environment: Node3D) -> void:
	_runtime = runtime
	_build_material()
	_build_goal_frames(environment)


func build_dynamic() -> void:
	goal_net_edges = _runtime.get_goal_net_edges()
	if goal_net_edges.is_empty():
		push_warning("GpfRuntime returned no goal-net edges")
		return
	for goal in 2:
		var net := MeshInstance3D.new()
		net.name = "GoalNet%d" % goal
		net.mesh = ImmediateMesh.new()
		net.material_override = goal_net_material
		net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(net)
		goal_net_meshes.append(net)
		_redraw(goal)


func update() -> void:
	goal_net_positions_cache.clear()
	for goal in goal_net_meshes.size():
		var positions: PackedVector3Array = _runtime.get_goal_net_positions(goal)
		goal_net_positions_cache.append(positions)
		draw(goal, positions)


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


func _build_material() -> void:
	var net_material := StandardMaterial3D.new()
	net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net_material.albedo_color = Color(0.9, 0.94, 1.0, 0.5)
	net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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


func _redraw(goal: int) -> void:
	draw(goal, _runtime.get_goal_net_positions(goal))
