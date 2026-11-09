extends SceneTree
# Headless check for the kit data path: imported specs resolve through tm_id,
# the fallback builds four kits, and the UV atlas is actually applied to the
# gpf_kit surface of a real body.

const BODY_SCENE := "res://assets/models/gpf_fullbody.glb"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var teams := TeamCatalog.new()
	_check(teams.load_data_root(""), "the team catalog loads")
	var barca := teams.team_by_id(131)
	_check(str(barca.get("tm_id", "")) == "131", "TeamCatalog carries tm_id")
	var kits_catalog := KitCatalog.new()
	_check(kits_catalog.load_data_root(""), "the kit catalog loads")
	_check(kits_catalog.available, "the imported kits.json is present")
	var kits := kits_catalog.kits_for(barca)
	_check(kits.size() == 4, "four kits are exposed")
	_check(str(kits[0].get("id", "")) == "main", "the first kit is main")
	_check(str(kits[0].get("pattern", "")) == "stripes", "the imported pattern survives")
	_check(str(kits[0].get("shirt", "")).to_upper() == "004C99", "the imported shirt colour survives")
	_check(str(kits[1].get("id", "")) == "white", "the away kit is white")

	var fallback_team := {"name": "Test FC", "color1": "#112233", "color2": "#445566"}
	var fallback := kits_catalog.kits_for(fallback_team)
	_check(fallback.size() == 4, "an unknown team gets four fallback kits")
	_check(str(fallback[0].get("shirt", "")).to_upper() == "112233",
		"fallback main uses color1")

	var texture := KitTexture.texture_for(kits[0])
	_check(texture != null, "the kit atlas is generated")
	_check(texture != null and texture.get_width() == 512 and texture.get_height() == 512,
		"the atlas keeps the body UV size")
	_check(KitTexture.texture_for(kits[0]) == texture, "the atlas is cached")

	var body := (load(BODY_SCENE) as PackedScene).instantiate()
	root.add_child(body)
	await _frames(1)
	var applied := KitTexture.apply_to_body(body, kits[0])
	_check(applied, "the kit is applied to a real gpf_fullbody")
	var textured := 0
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_surface_override_material(surface)
			if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
				textured += 1
	_check(textured > 0, "at least one gpf_kit surface got the kit shader")
	body.queue_free()

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: kit texture")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
