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
	runtime.set_button(1, true)
	runtime.set_button(14, true)
	var prev := {}
	var max_delta := 0.0
	var max_bone := ""
	for tick in range(220):
		runtime.step_fixed(1)
		var pose: Dictionary = runtime.get_player_pose(1)
		var pos: Vector3 = pose.get("pos", Vector3.ZERO)
		var line := "tick=%d geomPos=%s" % [tick, pos]
		var bones: Array = pose.get("bones", [])
		var max_here := 0.0
		var max_here_bone := ""
		for bone in bones:
			var name: String = bone.get("name", "")
			var bp: Vector3 = bone.get("pos", Vector3.ZERO)
			if prev.has(name):
				var delta: float = (bp - (prev[name] as Vector3)).length()
				if delta > max_here:
					max_here = delta
					max_here_bone = name
				if delta > max_delta:
					max_delta = delta
					max_bone = name
			prev[name] = bp
			if name == "body":
				line += " body=%s" % bp
		if max_here > 0.05:
			line += " MAX_BONE_DELTA=%.3f %s" % [max_here, max_here_bone]
		if tick < 20 or tick % 10 == 0 or max_here > 0.05:
			print(line)
	print("GLOBAL max bone delta=%.3f bone=%s" % [max_delta, max_bone])
	quit()
