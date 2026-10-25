extends SceneTree
func _initialize():
	var m := BoxMesh.new()
	m.size = Vector3(105, 0.1, 68)
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	for i in range(v.size()):
		if v[i].y > 0.04:
			print(i, " v=", v[i], " uv=", uv[i])
	quit()
