extends SceneTree

func _init() -> void:
	var packed := load("res://assets/models/gpf_fullbody.glb") as PackedScene
	if packed == null:
		print("FAIL load glb")
		quit(1)
		return
	var root := packed.instantiate()
	root.name = "ProbeRoot"
	get_root().add_child(root)
	print("root=", root, " children=", root.get_child_count())
	_dump(root, 0)

	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	print("meshes=", meshes.size())
	for mi in meshes:
		print("mesh ", mi.name, " surfaces=", mi.mesh.get_surface_count(), " skeleton=", mi.skeleton)
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			print("  surface ", s, " verts=", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), " bones=", (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size())
		print("  has bake=", mi.has_method("bake_mesh_from_current_skeleton_pose"), " has skinned_data=", mi.has_method("get_skinned_mesh_data"))

	var skels := root.find_children("*", "Skeleton3D", true, false)
	print("skeletons=", skels.size())
	for sk in skels:
		print("skeleton ", sk.name, " bones=", sk.get_bone_count())
		for i in sk.get_bone_count():
			print("  ", i, " ", sk.get_bone_name(i), " rest=", sk.get_bone_rest(i), " pos=", sk.get_bone_pose_position(i), " rot=", sk.get_bone_pose_rotation(i))

	quit(0)

func _dump(n: Node, depth: int) -> void:
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]")
	for c in n.get_children():
		_dump(c, depth + 1)
