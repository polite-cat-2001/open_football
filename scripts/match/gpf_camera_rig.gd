class_name GpfCameraRig
extends Node
# Presents the camera: either the original C++ broadcast camera from the snapshot or a
# debug overview of the whole stadium. Owns only view state.

var camera: Camera3D
var space: Node3D
var stadium := false


func setup(camera_node: Camera3D, space_node: Node3D) -> void:
	camera = camera_node
	space = space_node


func toggle() -> void:
	stadium = not stadium


func update(snap: Dictionary) -> void:
	if camera == null:
		return
	if stadium:
		camera.global_position = Vector3(-145.0, 58.0, 95.0)
		camera.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
		camera.fov = 55.0
		camera.near = 0.1
		camera.far = 500.0
		return
	var raw_pos: Vector3 = snap.get("camera_pos", Vector3.ZERO)
	var raw_rot: Quaternion = snap.get("camera_rot", Quaternion.IDENTITY)
	var space_basis: Basis = space.basis if space != null else Basis.IDENTITY
	var cam_basis: Basis = space_basis * Basis(raw_rot)
	var origin: Vector3 = space.transform * raw_pos if space != null else raw_pos
	camera.global_transform = Transform3D(cam_basis, origin)
	camera.fov = clamp(float(snap.get("camera_fov", 55.0)), 10.0, 120.0)
	camera.near = maxf(0.05, float(snap.get("camera_near", 1.0)))
	camera.far = maxf(camera.near + 1.0, float(snap.get("camera_far", 200.0)))
