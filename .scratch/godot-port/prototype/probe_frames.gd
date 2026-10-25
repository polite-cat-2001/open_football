extends SceneTree

const OUT := "C:/Users/Egor/AppData/Local/Temp/opencode/gpf_walk"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: Node = load("res://scenes/gpf_slice.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var runtime: Node = scene.get_node("GpfRuntime")
	runtime.set_manual_step(true)
	runtime.set_button(1, true)
	runtime.set_button(14, true)
	for tick in range(161):
		runtime.step_fixed(1)
		await process_frame
		if tick % 10 == 0:
			await RenderingServer.frame_post_draw
			var image := root.get_viewport().get_texture().get_image()
			image.save_png("%s/walk_%03d.png" % [OUT, tick])
			print("saved ", tick)
	runtime.set_button(1, false)
	runtime.set_button(14, false)
	quit()
