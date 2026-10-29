class_name GpfActors
extends Node3D
# Presentation of the match actors: one skinned body per C++ actor, the ball and the
# nameplates. Owns the raw-C++ -> world basis (the node transform in gpf_slice.tscn).
# Nothing here reads game state on its own: the orchestrator feeds snapshots/poses in.

const BODY_SCENE := "res://assets/models/gpf_fullbody.glb"
const BALL_SCENE := "res://assets/models/gpf_ball.glb"

const TEAM_COLORS := {
	0: Color(0.12, 0.28, 0.95),
	1: Color(0.95, 0.15, 0.12),
	-1: Color(0.95, 0.8, 0.15),
}
const NAMEPLATE_NORMAL_COLOR := Color(0.90, 0.94, 1.0)
const NAMEPLATE_CONTROLLED_COLOR := Color(1.0, 0.84, 0.18)
const NAMEPLATE_HEIGHT := 2.25

var body_scene: PackedScene
var ball_root: Node3D
var skeletons: Dictionary = {}
var bone_indices: Dictionary = {}
var actors: Array = []
var actor_bodies: Dictionary = {}
var player_labels: Dictionary = {}

var controlled_id := -1
var labels_visible := true

var _runtime: Node
var _reticle: MeshInstance3D


func setup(runtime: Node) -> void:
	_runtime = runtime
	body_scene = load(BODY_SCENE)
	_build_ball()
	_build_reticle()


func count() -> int:
	return actors.size()


func reset() -> void:
	for body in actor_bodies.values():
		if body != null and is_instance_valid(body):
			body.queue_free()
	skeletons.clear()
	bone_indices.clear()
	actors.clear()
	actor_bodies.clear()
	player_labels.clear()
	controlled_id = -1
	labels_visible = true
	if ball_root != null:
		ball_root.transform = Transform3D.IDENTITY


func get_controlled() -> int:
	return controlled_id


func set_controlled(id: int) -> void:
	controlled_id = id


func spawn(ids: Array) -> void:
	for entry in ids:
		var id := int(entry.get("id", -1))
		if id < 0:
			continue
		var body: Node3D = body_scene.instantiate()
		add_child(body)
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


func apply_runtime() -> Dictionary:
	var poses := {}
	for entry in actors:
		var id := int(entry.get("id", -1))
		var pose: Dictionary = _runtime.get_player_pose(id)
		if pose.is_empty():
			continue
		apply_pose(id, pose)
		poses[id] = pose
	return poses


func apply_pose(id: int, player: Dictionary) -> void:
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


func sync_ball(snap: Dictionary) -> void:
	if ball_root == null:
		return
	ball_root.transform = Transform3D(
		Basis(snap.get("ball_rot", Quaternion.IDENTITY)),
		snap.get("ball_pos", Vector3.ZERO)
	)


func capture_ball_transform() -> Transform3D:
	if ball_root == null:
		return Transform3D.IDENTITY
	return ball_root.transform


func apply_ball_transform(transform: Transform3D) -> void:
	if ball_root != null:
		ball_root.transform = transform


func set_labels_visible(value: bool) -> void:
	labels_visible = value
	refresh_labels()


func set_reticle_visible(value: bool) -> void:
	if _reticle != null:
		_reticle.visible = value


func update_reticle(snap: Dictionary) -> void:
	if _reticle == null:
		return
	var role := int(snap.get("set_piece_role", 0))
	var type := int(snap.get("presentation_type", 0))
	var aim: Vector3 = snap.get("set_piece_aim_point", Vector3.ZERO)
	var show := role == 1 and type == 6 and aim.length() > 0.01
	_reticle.visible = show
	if show:
		_reticle.position = aim


func apply_park_visibility(snap: Dictionary) -> void:
	var parked := bool(snap.get("debug_park_opponents", false))
	var human_team: int = _runtime.get_human_team_id()
	for entry in actors:
		var id := int(entry.get("id", -1))
		var body: Node3D = actor_bodies.get(id)
		if body == null:
			continue
		var hide: bool = parked and String(entry.get("role", "")) == "player" \
			and (human_team < 0 or int(entry.get("team", -1)) != human_team)
		body.visible = not hide


func refresh_labels() -> void:
	for id in player_labels:
		var label: Label3D = player_labels[id]
		if label == null:
			continue
		var body: Node3D = actor_bodies.get(id)
		label.visible = labels_visible and body != null and body.visible
		label.modulate = NAMEPLATE_CONTROLLED_COLOR if id == controlled_id \
			else NAMEPLATE_NORMAL_COLOR


func _build_ball() -> void:
	var ball_scene: PackedScene = load(BALL_SCENE)
	if ball_scene == null:
		push_warning("Could not load " + BALL_SCENE)
		return
	ball_root = ball_scene.instantiate()
	if ball_root is GeometryInstance3D:
		ball_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in ball_root.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ball_root)


func _build_reticle() -> void:
	_reticle = MeshInstance3D.new()
	_reticle.name = "PenaltyReticle"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.32
	ring.rings = 24
	ring.ring_segments = 8
	_reticle.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.15)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	_reticle.material_override = material
	_reticle.rotation = Vector3(0, 0, PI / 2.0)
	_reticle.visible = false
	add_child(_reticle)


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
