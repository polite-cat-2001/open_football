extends SceneTree
func _initialize():
	var m := PlaneMesh.new()
	m.size = Vector2(105, 68)
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	for i in range(v.size()): print(i, " v=", v[i], " uv=", uv[i])
	quit()
