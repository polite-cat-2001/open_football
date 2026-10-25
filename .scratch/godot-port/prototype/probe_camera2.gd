extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	var runtime: Node = scene.get_node("GpfRuntime")
	while runtime.get_tick() < 220:
		await process_frame
	var snap: Dictionary = runtime.get_snapshot()
	print("tick=", snap.get("tick"))
	print("cam_pos=", snap.get("camera_pos"), " cam_rot=", snap.get("camera_rot"), " fov=", snap.get("camera_fov"), " near=", snap.get("camera_near"), " far=", snap.get("camera_far"))
	print("cam_xform=", scene.get_node("Camera3D").global_transform)
	print("ball=", snap.get("ball_pos"))
	quit()
