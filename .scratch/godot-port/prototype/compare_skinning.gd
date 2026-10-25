extends SceneTree

const CSV_PATH := "C:/Users/Egor/AppData/Local/Temp/opencode/skindump_400.csv"
const SOURCE_CSV := "C:/Users/Egor/AppData/Local/Temp/opencode/gpf-build/Release/skindsource.csv"
const GLB_PATH := "C:/Users/Egor/Desktop/projects/open_football/assets/models/gpf_fullbody.glb"

class Dump:
	var player: Dictionary = {}
	var bones: Dictionary = {}
	var vertices: Array[Vector3] = []

func _init() -> void:
	var dump := _load_dump(CSV_PATH)
	var src := _load_dump(SOURCE_CSV)
	print("dump player=", dump.player)
	print("dump bones=", dump.bones.size(), " vertices=", dump.vertices.size())

	var root := _load_glb(GLB_PATH)
	get_root().add_child(root)
	var skel := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var z: float = dump.player["height"] / 1.92
	_apply_pose(skel, dump)

	var rest := _rest_vertices(root, z)
	print("source vertices=", src.vertices.size(), " rest vertices=", rest.size())
	print("source aabb=", _aabb(src.vertices))
	print("rest aabb=", _aabb(rest))
	var rest_stats := _nearest_stats(src.vertices, rest)
	print("source->rest max=%.6f mean=%.6f" % [rest_stats[0], rest_stats[1]])

	_compare_bones(skel, dump)

	var skinned := _skin_all(root, skel, z)
	print("skinned vertices=", skinned.size())
	print("skinned aabb=", _aabb(skinned))
	print("dump aabb=", _aabb(dump.vertices))
	var stats := _nearest_stats(dump.vertices, skinned)
	print("dump->skinned max=%.6f mean=%.6f" % [stats[0], stats[1]])
	stats = _nearest_stats(skinned, dump.vertices)
	print("skinned->dump max=%.6f mean=%.6f" % [stats[0], stats[1]])
	quit(0)

func _load_dump(path: String) -> Dump:
	var out := Dump.new()
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		var f := line.split(",")
		if f.is_empty(): continue
		match f[0]:
			"PLAYER":
				out.player = {"id": int(f[1]), "team": int(f[2]), "height": float(f[3]),
					"pos": Vector3(float(f[4]), float(f[5]), float(f[6])),
					"movement": float(f[7]), "anim": f[8], "frames": int(f[9]),
					"frame": int(f[10]), "function": int(f[11])}
			"BONE":
				out.bones[f[1]] = {
					"local_pos": Vector3(float(f[2]), float(f[3]), float(f[4])),
					"local_rot": Quaternion(float(f[5]), float(f[6]), float(f[7]), float(f[8])),
					"derived_pos": Vector3(float(f[9]), float(f[10]), float(f[11])),
					"derived_rot": Quaternion(float(f[12]), float(f[13]), float(f[14]), float(f[15])),
				}
			"VERTEX":
				out.vertices.append(Vector3(float(f[3]), float(f[4]), float(f[5])))
	return out

func _load_glb(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		print("GLTF load failed ", err)
		quit(1)
	return doc.generate_scene(state)

func _apply_pose(skel: Skeleton3D, dump: Dump) -> void:
	var fullbody_offset := Vector3(dump.player["pos"].x, dump.player["pos"].y, 0.0)
	for name in dump.bones.keys():
		var idx := skel.find_bone(name)
		if idx < 0:
			print("missing bone ", name)
			continue
		var b: Dictionary = dump.bones[name]
		var pos: Vector3 = b["local_pos"]
		if name == "player":
			pos -= fullbody_offset
		skel.set_bone_pose_position(idx, pos)
		skel.set_bone_pose_rotation(idx, b["local_rot"])

func _rest_vertices(root: Node, z: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				out.append(v * z)
	return out

func _skin_all(root: Node, skel: Skeleton3D, z: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		var skin: Skin = mi.skin
		if skin == null:
			print("no skin on ", mi.name)
			continue
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			for i in verts.size():
				var v: Vector3 = verts[i]
				var result := Vector3.ZERO
				for k in 4:
					var bind_i := bones[i * 4 + k]
					var w := weights[i * 4 + k]
					if w <= 0.0: continue
					var bone_i := skin.get_bind_bone(bind_i)
					if bone_i < 0:
						bone_i = skel.find_bone(skin.get_bind_name(bind_i))
					var bone_pose := skel.get_bone_global_pose(bone_i)
					var bind_pose := skin.get_bind_pose(bind_i)
					result += (bone_pose * bind_pose * v) * w
				out.append(result * z)
	return out

func _compare_bones(skel: Skeleton3D, dump: Dump) -> void:
	var z: float = dump.player["height"] / 1.92
	var root_pos: Vector3 = dump.player["pos"]
	var fullbody_offset := Vector3(root_pos.x, root_pos.y, 0.0)
	var max_pos := 0.0
	var max_ang := 0.0
	for name in dump.bones.keys():
		var idx := skel.find_bone(name)
		if idx < 0: continue
		var b: Dictionary = dump.bones[name]
		var cpp_pos: Vector3 = ((b["derived_pos"] as Vector3) - fullbody_offset) * z
		var cpp_rot: Quaternion = b["derived_rot"]
		var godot_xf := skel.get_bone_global_pose(idx)
		var godot_pos := godot_xf.origin * z
		var godot_rot := godot_xf.basis.get_rotation_quaternion()
		var pe := cpp_pos.distance_to(godot_pos)
		var dot: float = abs(cpp_rot.dot(godot_rot))
		dot = clamp(dot, 0.0, 1.0)
		var ae := rad_to_deg(2.0 * acos(dot))
		max_pos = max(max_pos, pe)
		max_ang = max(max_ang, ae)
	print("BONE max pos_err=%.6f ang_err=%.4f" % [max_pos, max_ang])

func _nearest_stats(a: Array[Vector3], b: Array[Vector3]) -> Array[float]:
	var max_d := 0.0
	var sum_d := 0.0
	for v in a:
		var best := INF
		for w in b:
			var d := v.distance_squared_to(w)
			if d < best: best = d
		best = sqrt(best)
		max_d = max(max_d, best)
		sum_d += best
	return [max_d, sum_d / a.size()]

func _aabb(points: Array[Vector3]) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points: box = box.expand(p)
	return box

