extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	var runtime: Node = scene.get_node("GpfRuntime")
	var waited := 0
	while waited < 600:
		await process_frame
		waited += 1
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_play", false)):
			print("PLAY tick=", snap.get("tick"), " human=", runtime.get_human_player_id(), " taker=", snap.get("set_piece_taker"), " setpiece=", snap.get("in_set_piece"), " type=", snap.get("set_piece_type"), " ball=", snap.get("ball_pos"))
			break
	runtime.set_button(6, true)
	for i in range(45):
		await process_frame
	runtime.set_button(6, false)
	for i in range(160):
		await process_frame
	var snap2: Dictionary = runtime.get_snapshot()
	print("AFTER tick=", snap2.get("tick"), " in_play=", snap2.get("in_play"), " ball=", snap2.get("ball_pos"))
	quit()
