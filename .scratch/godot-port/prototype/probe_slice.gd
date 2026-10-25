extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var runtime: Node = scene.get_node("GpfRuntime")
	for frame in range(90):
		await process_frame
		if frame % 10 != 0:
			continue
		print("FRAME ", frame)
		var ids: Array = runtime.get_player_ids()
		for entry in ids:
			var id := int(entry.get("id", -1))
			var team := int(entry.get("team", -1))
			var pose: Dictionary = runtime.get_player_pose(id)
			print("  id=%d team=%d pos=%s anim=%s" % [id, team, pose.get("pos"), pose.get("anim")])
		print("  ball=", runtime.get_snapshot().get("ball_pos"))
	quit()
