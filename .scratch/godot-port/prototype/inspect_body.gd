extends SceneTree
func _initialize():
	var scene = load("res://assets/models/gpf_fullbody.glb").instantiate()
	root.add_child(scene)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		print("MESH ", node.name, " surfaces=", node.get_surface_override_material_count(), " mesh_surfaces=", node.mesh.get_surface_count() if node.mesh else -1)
		if node.mesh:
			for i in node.mesh.get_surface_count():
				var mat = node.mesh.surface_get_material(i)
				print("  surface ", i, " material=", mat.resource_name if mat else "<none>", " type=", mat.get_class() if mat else "")
	quit()
