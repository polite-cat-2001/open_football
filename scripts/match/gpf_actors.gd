class_name GpfActors
extends Node3D
# Presentation of the match actors: one skinned body per C++ actor, the ball and the
# nameplates. Owns the raw-C++ -> world basis (the node transform in gpf_slice.tscn).
# Nothing here reads game state on its own: the orchestrator feeds snapshots/poses in.

const BODY_SCENE := "res://assets/models/gpf_fullbody.glb"
const BALL_SCENE := "res://assets/models/gpf_ball.glb"
const BALL_TEXTURE := "res://assets/gpf/media/objects/balls/ball.jpg"

const TEAM_COLORS := {
	0: Color(0.12, 0.28, 0.95),
	1: Color(0.95, 0.15, 0.12),
	-1: Color(0.95, 0.8, 0.15),
}
const NAMEPLATE_NORMAL_COLOR := Color(0.90, 0.94, 1.0)
const NAMEPLATE_CONTROLLED_COLOR := Color(1.0, 0.84, 0.18)
const NAMEPLATE_HEIGHT := 2.25

# Player look. The snapshot only has team + last name, so skin/hair/height are
# looked up in the package's squad rows under that key.
const SKIN_PATH := "res://assets/models/players/skin%02d.png"
const HAIR_PATH := "res://assets/models/players/hair/%s.png"
# Keepers and officials wear their own fullbody textures, authored for the same
# UV layout as the kit atlas (humanoidbase.cpp:109-133).
const ROLE_KIT_PATHS := {
	"goalkeeper": "res://assets/models/players/goalie_kit.png",
	"official": "res://assets/models/players/referee_kit.png",
}
const HAIR_STYLES := ["bald", "short01", "short02", "medium01", "medium02", "long01"]
const HAIR_COLORS := ["black", "blonde", "brown", "darkblonde", "red"]
# The original's base model is 1.92 m and it scales it by height / 1.92
# (humanoidbase.cpp:102,312-314).
const DEFAULT_HEIGHT := 1.92
const DEFAULT_APPEARANCE := {
	"skin_color": 1,
	"hair_style": "short01",
	"hair_color": "darkblonde",
	"height": 1.8,
}

# Referee card prop. The original draws media/objects/officials/{yellow,red}card.ase
# (a 0.1104 x 0.02 x 0.1539 m box, plain-coloured textures) at the elbow bone.
# The bridge relays that geometry's exact transform, so this is the same prop.
const REFEREE_CARD_SIZE := Vector3(0.1104, 0.02, 0.1539)
# Officials::Put() puts the card *centre* 0.25 m down the forearm; the hand
# then grips it near the middle and the card hangs at the wrist. Shift the prop
# one card length further along that axis so the hand holds its lower edge and
# the card is shown above the hand, as in the original broadcast view.
const REFEREE_CARD_GRIP := REFEREE_CARD_SIZE.z
const YELLOW_CARD_COLOR := Color(0.929, 0.929, 0.0)
const RED_CARD_COLOR := Color(0.753, 0.0, 0.0)

var body_scene: PackedScene
var ball_root: Node3D
var referee_card_root: Node3D
var yellow_card: MeshInstance3D
var red_card: MeshInstance3D
var skeletons: Dictionary = {}
var bone_indices: Dictionary = {}
var actors: Array = []
var actor_bodies: Dictionary = {}
var player_labels: Dictionary = {}

var controlled_id := -1
var controlled_ids: Dictionary = {}
var labels_visible := true
var team_kits: Dictionary = {}

var _appearance: Dictionary = {}
var _skin_materials: Dictionary = {}
var _hair_materials: Dictionary = {}
var _role_kits: Dictionary = {}
var _runtime: Node
var _reticle: MeshInstance3D


func setup(runtime: Node) -> void:
	_runtime = runtime
	body_scene = load(BODY_SCENE)
	_build_ball()
	_build_reticle()
	_build_referee_cards()


func set_match_kits(package: Dictionary) -> void:
	team_kits.clear()
	_appearance.clear()
	for side in 2:
		var team: Dictionary = package.get("home" if side == 0 else "away", {})
		var kit = team.get("kit", {})
		if kit is Dictionary and not (kit as Dictionary).is_empty():
			team_kits[side] = (kit as Dictionary).duplicate(true)
		for player in team.get("players", []):
			var style := String(player.get("hair_style", "short01"))
			# Same rule as the C++ package loader (gpf_runtime_node.cpp:138-141):
			# a height outside 1.4..2.3 m falls back to 1.8.
			var height := float(player.get("height", 1.8))
			if height < 1.4 or height > 2.3:
				height = 1.8
			# shortcut: two players with the same surname in one squad collide;
			# team + last name is enough today.
			_appearance["%d|%s" % [side, String(player.get("last_name", ""))]] = {
				"skin_color": int(player.get("skin_color", 1)),
				"hair_style": style if HAIR_STYLES.has(style) else "short01",
				"hair_color": String(player.get("hair_color", "darkblonde")),
				"height": height,
			}
	for entry in actors:
		var body: Node3D = actor_bodies.get(int(entry.get("id", -1)))
		if body != null and is_instance_valid(body):
			_apply_kit(body, entry)
			_apply_appearance(body, entry)


# Officials carry neither team nor a name and the snapshot has no appearance
# fields, so they fall back to DEFAULT_APPEARANCE.
func appearance_for(entry: Dictionary) -> Dictionary:
	var key := "%d|%s" % [int(entry.get("team", -1)), String(entry.get("name", ""))]
	return _appearance.get(key, DEFAULT_APPEARANCE)


func count() -> int:
	return actors.size()


func reset() -> void:
	for body in actor_bodies.values():
		if body != null and is_instance_valid(body):
			body.queue_free()
	skeletons.clear()
	bone_indices.clear()
	actors.clear()
	actor_bodies.clear()
	player_labels.clear()
	controlled_id = -1
	controlled_ids.clear()
	labels_visible = true
	if ball_root != null:
		ball_root.transform = Transform3D.IDENTITY
	update_referee_card({})


func get_controlled() -> int:
	return controlled_id


func set_controlled(id: int) -> void:
	set_controlled_ids([id] if id > 0 else [])


func set_controlled_ids(ids: Array) -> void:
	controlled_ids.clear()
	for raw_id in ids:
		var id := int(raw_id)
		if id > 0:
			controlled_ids[id] = true
	controlled_id = int(ids[0]) if not ids.is_empty() else -1


func spawn(ids: Array) -> void:
	for entry in ids:
		_spawn_entry(entry)


# Reconcile the presentation with the runtime's active player list. Used after a
# substitution: the player who left the pitch loses his body, the substitute
# gets a fresh one with his own nameplate and kit colour.
func sync_roster(ids: Array) -> void:
	var wanted: Dictionary = {}
	for entry in ids:
		wanted[int(entry.get("id", -1))] = entry

	for id in actor_bodies.keys():
		if wanted.has(int(id)):
			continue
		var body: Node3D = actor_bodies[int(id)]
		if body != null and is_instance_valid(body):
			body.queue_free()
		skeletons.erase(id)
		actor_bodies.erase(id)
		player_labels.erase(id)
		for index in range(actors.size() - 1, -1, -1):
			if int((actors[index] as Dictionary).get("id", -2)) == int(id):
				actors.remove_at(index)

	for entry in ids:
		var id := int(entry.get("id", -1))
		if id < 0 or actor_bodies.has(id):
			continue
		_spawn_entry(entry)
	refresh_labels()


func _spawn_entry(entry: Dictionary) -> void:
	var id := int(entry.get("id", -1))
	if id < 0:
		return
	var body: Node3D = body_scene.instantiate()
	add_child(body)
	var found := body.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		body.queue_free()
		return
	var skeleton := found[0] as Skeleton3D
	if bone_indices.is_empty():
		for i in skeleton.get_bone_count():
			bone_indices[skeleton.get_bone_name(i)] = i
	_apply_kit(body, entry)
	_apply_appearance(body, entry)
	skeletons[id] = skeleton
	actor_bodies[id] = body
	_build_nameplate(body, id, entry)
	actors.append(entry)


func apply_runtime() -> Dictionary:
	var poses := {}
	for entry in actors:
		var id := int(entry.get("id", -1))
		var pose: Dictionary = _runtime.get_player_pose(id)
		if pose.is_empty():
			continue
		apply_pose(id, pose)
		poses[id] = pose
	return poses


func apply_pose(id: int, player: Dictionary) -> void:
	var skeleton: Skeleton3D = skeletons.get(id)
	if skeleton == null:
		return
	var body: Node3D = actor_bodies.get(id)
	var model_scale: float = body.scale.x if body != null else 1.0
	var bones: Array = player.get("bones", [])
	for bone in bones:
		var name: String = bone.get("name", "")
		var idx: int = bone_indices.get(name, -1)
		if idx < 0:
			continue
		var position: Vector3 = bone.get("pos", Vector3.ZERO)
		# The root bone carries the world position; the body scale shrinks the
		# model only, exactly like the original scales vertices, not the actor
		# (humanoidbase.cpp:312-314,426).
		if name == "player" and not is_equal_approx(model_scale, 1.0):
			position /= model_scale
		skeleton.set_bone_pose_position(idx, position)
		skeleton.set_bone_pose_rotation(idx, bone.get("rot", Quaternion.IDENTITY))
	var label: Label3D = player_labels.get(id)
	if label != null:
		var pos: Vector3 = player.get("pos", Vector3.ZERO)
		label.position = Vector3(pos.x / model_scale, pos.y / model_scale, NAMEPLATE_HEIGHT)


func sync_ball(snap: Dictionary) -> void:
	if ball_root == null:
		return
	ball_root.transform = Transform3D(
		Basis(snap.get("ball_rot", Quaternion.IDENTITY)),
		snap.get("ball_pos", Vector3.ZERO)
	)


# The bridge relays the two card props the original Officials::Put() positions
# (host: GetCurrentCardState; thin client: relayed SetRemoteCardState). This is
# a pure renderer of those transforms: no text parsing, no host-only state.
func update_referee_card(snap: Dictionary) -> void:
	if yellow_card == null or red_card == null:
		return
	var cards: Dictionary = snap.get("referee_cards", {})
	_apply_referee_card(yellow_card, cards.get("yellow", {}))
	_apply_referee_card(red_card, cards.get("red", {}))


func _apply_referee_card(card: MeshInstance3D, state: Dictionary) -> void:
	# `raised` is the bridge's presentation hint: the original card is also
	# placed during the showcard clip's down frames; hide those so the card is
	# only seen in the raised-hand part of the animation.
	card.visible = bool(state.get("visible", false)) and bool(state.get("raised", true))
	if not card.visible:
		return
	var basis := Basis(state.get("rot", Quaternion.IDENTITY))
	var pos: Vector3 = state.get("pos", Vector3.ZERO)
	card.transform = Transform3D(
		basis,
		pos + basis * Vector3(0.0, 0.0, -REFEREE_CARD_GRIP)
	)


func capture_ball_transform() -> Transform3D:
	if ball_root == null:
		return Transform3D.IDENTITY
	return ball_root.transform


func apply_ball_transform(transform: Transform3D) -> void:
	if ball_root != null:
		ball_root.transform = transform


func set_labels_visible(value: bool) -> void:
	labels_visible = value
	refresh_labels()


func set_reticle_visible(value: bool) -> void:
	if _reticle != null:
		_reticle.visible = value


func update_reticle(snap: Dictionary) -> void:
	if _reticle == null:
		return
	var role := int(snap.get("set_piece_role", 0))
	var type := int(snap.get("presentation_type", 0))
	var aim: Vector3 = snap.get("set_piece_aim_point", Vector3.ZERO)
	var show := role == 1 and type == 6 and aim.length() > 0.01
	_reticle.visible = show
	if show:
		_reticle.position = aim


func apply_park_visibility(snap: Dictionary) -> void:
	var parked := bool(snap.get("debug_park_opponents", false))
	var human_team: int = _runtime.get_human_team_id()
	for entry in actors:
		var id := int(entry.get("id", -1))
		var body: Node3D = actor_bodies.get(id)
		if body == null:
			continue
		var hide: bool = parked and String(entry.get("role", "")) == "player" \
			and (human_team < 0 or int(entry.get("team", -1)) != human_team)
		body.visible = not hide


func refresh_labels() -> void:
	for id in player_labels:
		var label: Label3D = player_labels[id]
		if label == null:
			continue
		var body: Node3D = actor_bodies.get(id)
		label.visible = labels_visible and body != null and body.visible
		label.modulate = NAMEPLATE_CONTROLLED_COLOR if controlled_ids.has(id) \
			else NAMEPLATE_NORMAL_COLOR


func _build_ball() -> void:
	var ball_scene: PackedScene = load(BALL_SCENE)
	if ball_scene == null:
		push_warning("Could not load " + BALL_SCENE)
		return
	ball_root = ball_scene.instantiate()
	if ball_root is GeometryInstance3D:
		ball_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var texture := load(BALL_TEXTURE) as Texture2D
	var material: StandardMaterial3D
	if texture != null:
		material = StandardMaterial3D.new()
		material.albedo_texture = texture
		material.roughness = 0.35
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for mesh in ball_root.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if material != null:
			mesh.material_override = material
	add_child(ball_root)


func _build_referee_cards() -> void:
	referee_card_root = Node3D.new()
	referee_card_root.name = "RefereeCards"
	add_child(referee_card_root)
	yellow_card = _build_referee_card("YellowCard", YELLOW_CARD_COLOR)
	red_card = _build_referee_card("RedCard", RED_CARD_COLOR)


func _build_referee_card(card_name: String, color: Color) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	card.name = card_name
	var box := BoxMesh.new()
	box.size = REFEREE_CARD_SIZE
	card.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	card.visible = false
	referee_card_root.add_child(card)
	return card


func _build_reticle() -> void:
	_reticle = MeshInstance3D.new()
	_reticle.name = "PenaltyReticle"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.32
	ring.rings = 24
	ring.ring_segments = 8
	_reticle.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.15)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	_reticle.material_override = material
	_reticle.rotation = Vector3(0, 0, PI / 2.0)
	_reticle.visible = false
	add_child(_reticle)


func _build_nameplate(body: Node3D, id: int, entry: Dictionary) -> void:
	if String(entry.get("role", "")) == "official":
		return
	var label := Label3D.new()
	label.name = "Nameplate%d" % id
	label.text = String(entry.get("name", ""))
	if label.text.is_empty():
		label.text = "#%d" % id
	label.position = Vector3(0.0, 0.0, NAMEPLATE_HEIGHT)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# World-space billboards, but small: at the close set-piece camera the old
	# 64 x 0.004 labels covered half the screen.
	label.font_size = 56
	label.pixel_size = 0.0035
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.modulate = NAMEPLATE_NORMAL_COLOR
	body.add_child(label)
	player_labels[id] = label


# The kit is picked by role first: the original gives every keeper and official
# their own fullbody texture, and only field players wear the team kit.
func _apply_kit(body: Node3D, entry: Dictionary) -> void:
	var role := String(entry.get("role", ""))
	if ROLE_KIT_PATHS.has(role):
		_apply_role_kit(body, role)
		return
	var team := int(entry.get("team", -1))
	var kit = team_kits.get(team, {})
	if kit is Dictionary and not (kit as Dictionary).is_empty():
		if KitTexture.apply_to_body(body, kit):
			return
	KitTexture.apply_color_to_body(body, TEAM_COLORS.get(team, Color.WHITE))


func _apply_role_kit(body: Node3D, role: String) -> void:
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.mesh.surface_get_material(surface)
			if source == null or source.resource_name != "gpf_kit":
				continue
			mesh_instance.set_surface_override_material(surface,
				_role_kit_material(role, source))


# Cache one material per role, like the skin/hair overrides: duplicate the shipped
# gpf_kit material (double-sided, filtering) and swap only the texture.
func _role_kit_material(role: String, source: Material) -> Material:
	if not _role_kits.has(role):
		var material := source.duplicate() as StandardMaterial3D
		if material == null:
			return source
		var texture := load(ROLE_KIT_PATHS[role]) as Texture2D
		if texture != null:
			material.albedo_texture = texture
		_role_kits[role] = material
	return _role_kits[role]


# Skin and hair are recoloured by swapping the glb material's albedo texture, the
# same way the original does it, and all six hairstyles ship in one glb where the
# player wears exactly one.
func _apply_appearance(body: Node3D, entry: Dictionary) -> void:
	var look := appearance_for(entry)
	body.scale = Vector3.ONE * (float(look["height"]) / DEFAULT_HEIGHT)
	var hair_node := "part_hair_" + String(look["hair_style"])
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var node_name := String(mesh_instance.name)
		if node_name.begins_with("part_hair_"):
			mesh_instance.visible = node_name == hair_node
			if not mesh_instance.visible:
				continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			match source.resource_name:
				"gpf_skin", "gpf_arm", "gpf_knee":
					mesh_instance.set_surface_override_material(surface,
						_skin_material(int(look["skin_color"]), source))
				"gpf_hair":
					mesh_instance.set_surface_override_material(surface,
						_hair_material(String(look["hair_color"]), source))


# The override keeps every property of the shipped glb material (double-sided,
# filtering, flags) and swaps only the albedo texture, like the original swaps
# the diffuse resource. Cached per skin index / hair colour, not per player.
func _skin_material(index: int, source: Material) -> Material:
	index = clampi(index, 1, 4)
	if not _skin_materials.has(index):
		var material := source.duplicate() as StandardMaterial3D
		if material == null:
			return source
		material.albedo_texture = load(SKIN_PATH % index) as Texture2D
		_skin_materials[index] = material
	return _skin_materials[index]


func _hair_material(color_name: String, source: Material) -> Material:
	if not HAIR_COLORS.has(color_name):
		color_name = String(DEFAULT_APPEARANCE["hair_color"])
	if not _hair_materials.has(color_name):
		var material := source.duplicate() as StandardMaterial3D
		if material == null:
			return source
		material.albedo_texture = load(HAIR_PATH % color_name) as Texture2D
		# Hair is a thin open shell: a single-sided source must not hide its
		# inner faces, while an already double-sided source is left as shipped.
		if material.cull_mode == BaseMaterial3D.CULL_BACK:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_hair_materials[color_name] = material
	return _hair_materials[color_name]
