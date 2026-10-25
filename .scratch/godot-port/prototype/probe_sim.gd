extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var runtime: Node = scene.get_node("GpfRuntime")
	runtime.set_manual_step(true)
	var ids: Array = runtime.get_player_ids()
	runtime.set_button(1, true)
	runtime.set_button(14, true)
	for tick in range(400):
		runtime.step_fixed(1)
		if tick % 10 == 0:
			var snap: Dictionary = runtime.get_snapshot()
			var ball: Vector3 = snap.get("ball_pos", Vector3.ZERO)
			print("TICK %d ball=%s" % [tick, ball])
			for entry in ids:
				var id := int(entry.get("id", -1))
				var pose: Dictionary = runtime.get_player_pose(id)
				var pos: Vector3 = pose.get("pos", Vector3.ZERO)
				var d := pos.distance_to(ball)
				if d < 4.0:
					print("  near id=%d team=%d d=%.2f pos=%s anim=%s" % [id, int(entry.get("team", -1)), d, pos, pose.get("anim")])
	runtime.set_button(1, false)
	runtime.set_button(14, false)
	quit()
