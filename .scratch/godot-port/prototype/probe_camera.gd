extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for i in range(260):
		await process_frame
	var runtime: Node = scene.get_node("GpfRuntime")
	var snap: Dictionary = runtime.get_snapshot()
	for key in snap.keys():
		print(key, " = ", snap[key])
	print("camera_node_transform=", scene.get_node("Camera3D").global_transform)
	print("camera_fov=", scene.get_node("Camera3D").fov, " near=", scene.get_node("Camera3D").near, " far=", scene.get_node("Camera3D").far)
	quit()
