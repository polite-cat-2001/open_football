extends SceneTree
# Headless check for player variety: the package's skin/hair/height reaches the
# actor bodies, an official falls back to defaults, and the glb ships all six
# hairstyles.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_appearance.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const BODY_SCENE := "res://assets/models/gpf_fullbody.glb"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []


class FakeRuntime:
	extends Node

	func get_player_pose(_player_id: int) -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8)
	if package.is_empty():
		_check(false, "match package could not be built")
		_finish()
		return

	var actors := GpfActors.new()
	get_root().add_child(actors)
	actors.setup(FakeRuntime.new())
	actors.set_match_kits(package)

	var player: Dictionary = package["home"]["players"][0]
	var entry := {"team": 0, "name": String(player["last_name"])}
	var look: Dictionary = actors.appearance_for(entry)
	_check(int(look["skin_color"]) == int(player["skin_color"]),
		"skin comes from the package row (%d)" % int(look["skin_color"]))
	_check(String(look["hair_style"]) == String(player["hair_style"]),
		"hair style comes from the package row (%s)" % look["hair_style"])
	_check(String(look["hair_color"]) == String(player["hair_color"]),
		"hair colour comes from the package row (%s)" % look["hair_color"])
	_check(is_equal_approx(float(look["height"]), float(player["height"])),
		"height comes from the package row (%.2f)" % float(look["height"]))

	var official: Dictionary = actors.appearance_for({"team": -1, "role": "official"})
	_check(int(official["skin_color"]) == 1 and String(official["hair_style"]) == "short01"
		and String(official["hair_color"]) == "darkblonde"
		and is_equal_approx(float(official["height"]), 1.8),
		"an unnamed official gets the default look")

	actors.spawn([{"id": 1, "team": 0, "role": "player", "name": String(player["last_name"])}])
	await process_frame
	var body: Node3D = actors.actor_bodies.get(1)
	_check(body != null and is_equal_approx(body.scale.x, float(player["height"]) / 1.92),
		"the body is scaled by height / 1.92")
	var skin_texture := load(GpfActors.SKIN_PATH % int(player["skin_color"])) as Texture2D
	var head: MeshInstance3D = body.find_child("part_head", true, false) as MeshInstance3D
	var head_material := head.get_surface_override_material(0) as StandardMaterial3D
	_check(head_material != null and head_material.albedo_texture == skin_texture,
		"the head surface gets the player's skin texture")
	var visible_hair: Array = []
	for mesh in body.find_children("part_hair_*", "MeshInstance3D", true, false):
		if mesh.visible:
			visible_hair.append(String(mesh.name))
	_check(visible_hair == ["part_hair_" + String(player["hair_style"])],
		"exactly the player's hairstyle is visible: " + str(visible_hair))

	# Role kits: keeper and officials wear their own textures, field players keep
	# the team kit shader.
	actors.spawn([
		{"id": 2, "team": 0, "role": "goalkeeper", "name": "Keeper"},
		{"id": 3, "team": -1, "role": "official"},
	])
	await process_frame
	var keeper_kit := _body_kit(actors, 2) as StandardMaterial3D
	_check(keeper_kit != null and keeper_kit.albedo_texture != null
		and keeper_kit.albedo_texture.resource_path
			== "res://assets/models/players/goalie_kit.png",
		"the goalkeeper wears goalie_kit.png")
	var referee_kit := _body_kit(actors, 3) as StandardMaterial3D
	_check(referee_kit != null and referee_kit.albedo_texture != null
		and referee_kit.albedo_texture.resource_path
			== "res://assets/models/players/referee_kit.png",
		"an official wears referee_kit.png")
	_check(_body_kit(actors, 1) is ShaderMaterial,
		"an outfield player still gets the team kit shader")

	var scene := load(BODY_SCENE) as PackedScene
	var model: Node3D = scene.instantiate() if scene != null else null
	_check(model != null, "the fullbody glb loads")
	if model != null:
		get_root().add_child(model)
		var styles: Array = []
		for hair in model.find_children("part_hair_*", "MeshInstance3D", true, false):
			styles.append(String(hair.name).trim_prefix("part_hair_"))
		styles.sort()
		_check(styles == ["bald", "long01", "medium01", "medium02", "short01", "short02"],
			"the glb ships all six hairstyles: " + str(styles))
		model.queue_free()

	actors.queue_free()
	_finish()


func _finish() -> void:
	print("== check_gpf_appearance: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _body_kit(actors: GpfActors, id: int) -> Material:
	var body: Node3D = actors.actor_bodies.get(id)
	if body == null:
		return null
	var mesh := body.find_child("part_body", true, false) as MeshInstance3D
	return mesh.get_surface_override_material(0) if mesh != null else null
