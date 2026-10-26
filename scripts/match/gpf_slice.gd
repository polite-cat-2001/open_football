extends Node3D

@onready var runtime := $GpfRuntime
@onready var pitch := $MatchNode
@onready var camera := $Camera3D

const BUTTONS := {
	KEY_UP: [0],
	KEY_RIGHT: [1],
	KEY_DOWN: [2],
	KEY_LEFT: [3],
	KEY_W: [4, 8],
	KEY_A: [5, 9],
	KEY_S: [6, 10],
	KEY_D: [7, 11],
	KEY_Q: [12],
	KEY_Z: [13],
	KEY_E: [14],
	KEY_C: [15],
	KEY_ENTER: [17],
}

const TEAM_COLORS := {
	0: Color(0.12, 0.28, 0.95),
	1: Color(0.95, 0.15, 0.12),
	-1: Color(0.95, 0.8, 0.15),
}

# Original C++ field geometry (gamedefines.hpp): playing field is 110 x 72,
# goal line at raw X = +-55, goal mouth 7.4 m wide, 2.5 m high, 2.55 m deep.
const GOAL_LINE_RAW := 55.0
const GOAL_HALF_WIDTH := 3.7
const GOAL_HEIGHT := 2.5
const GOAL_DEPTH := 2.55
const POST_RADIUS := 0.07

const PHASE_NAMES := [
	"PRE-MATCH",
	"1ST HALF",
	"2ND HALF",
	"EXTRA TIME 1",
	"EXTRA TIME 2",
	"PENALTIES",
]

const SET_PIECE_NAMES := [
	"",
	"KICKOFF",
	"GOAL KICK",
	"FREE KICK",
	"CORNER",
	"THROW-IN",
	"PENALTY",
]

var gpf_space: Node3D
var body_scene: PackedScene
var ball_root: Node3D
var skeletons: Dictionary = {}
var bone_indices: Dictionary = {}
var actors: Array = []
var actor_bodies: Dictionary = {}
var display_player_id := -1
var started := false
var frames := 0
var shot_path := OS.get_environment("GPF_SHOT")
var shot_frame := int(OS.get_environment("GPF_SHOT_FRAME")) if OS.get_environment("GPF_SHOT_FRAME") != "" else 120
var shot_taken := false
var demo := OS.get_environment("GPF_DEMO") != ""
var hud: Label
var score_hud: Label
var taker_hint: Label
var penalty_reticle: MeshInstance3D
var taker_menu_layer: CanvasLayer
var taker_menu_label: Label
var taker_menu_open := false
var taker_menu_candidates: Array = []
var taker_menu_index := 0
var phase_menu_layer: CanvasLayer
var phase_menu_title: Label
var phase_menu_subtitle: Label
var phase_menu_score: Label
var phase_menu_details: Label
var phase_menu_hint: Label
var phase_menu_continue: Button
var phase_menu_quit: Button
var phase_menu_open := false
var phase_menu_game_over := false
var goal_net_meshes: Array[MeshInstance3D] = []
var goal_net_edges: PackedInt32Array
var goal_net_material: Material

func _ready() -> void:
	gpf_space = Node3D.new()
	gpf_space.name = "GpfSpace"
	gpf_space.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	add_child(gpf_space)

	body_scene = load("res://assets/models/gpf_fullbody.glb")
	var ball_scene: PackedScene = load("res://assets/models/gpf_ball.glb")
	ball_root = ball_scene.instantiate()
	gpf_space.add_child(ball_root)

	_build_goals()
	_build_penalty_reticle()
	_build_hud()
	_build_taker_menu()
	_build_phase_menu()
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		push_error("GpfRuntime failed: " + str(runtime.get_last_error()))
		return
	_build_dynamic_goal_nets()

	var ids: Array = runtime.get_player_ids()
	for entry in ids:
		if int(entry.get("team", -1)) == 0 and int(entry.get("id", -1)) != 0 \
				and String(entry.get("role", "player")) != "goalkeeper":
			display_player_id = int(entry.get("id"))
			break
	if display_player_id >= 0:
		runtime.select_player(display_player_id)
		print("display_player_id=", display_player_id, " human_after_select=", runtime.get_human_player_id())
	_spawn_actors(ids)
	runtime.set("manual_step", false)
	started = true

func _spawn_actors(ids: Array) -> void:
	for entry in ids:
		var id := int(entry.get("id", -1))
		if id < 0:
			continue
		var body: Node3D = body_scene.instantiate()
		gpf_space.add_child(body)
		var found := body.find_children("*", "Skeleton3D", true, false)
		if found.is_empty():
			continue
		var skeleton := found[0] as Skeleton3D
		if bone_indices.is_empty():
			for i in skeleton.get_bone_count():
				bone_indices[skeleton.get_bone_name(i)] = i
		_apply_kit_color(body, int(entry.get("team", -1)))
		skeletons[id] = skeleton
		actor_bodies[id] = body
		actors.append(entry)

func _apply_kit_color(body: Node3D, team: int) -> void:
	var color: Color = TEAM_COLORS.get(team, Color.WHITE)
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface)
			if material == null or material.resource_name != "gpf_kit":
				continue
			var tinted := material.duplicate() as StandardMaterial3D
			tinted.albedo_color = color
			mesh_instance.set_surface_override_material(surface, tinted)

func _process(_delta: float) -> void:
	if not started:
		return
	if demo:
		_run_demo()
	var current_id: int = runtime.get_human_player_id()
	if current_id > 0:
		display_player_id = current_id
	var snap: Dictionary = runtime.get_snapshot()
	if snap.is_empty():
		return
	var player: Dictionary = {}
	for entry in actors:
		var id := int(entry.get("id", -1))
		var pose: Dictionary = runtime.get_player_pose(id)
		if pose.is_empty():
			continue
		_apply_player(id, pose)
		if id == display_player_id:
			player = pose
	_update_camera(snap)
	_update_penalty_reticle(snap)
	_update_goal_nets()
	_update_debug_park_visibility(snap)
	_sync_phase_menu(snap)
	_sync_taker_ui(snap)
	if hud != null:
		var status := _status_text(snap, player)
		if score_hud != null:
			var phase_text := _phase_name(int(snap.get("match_phase", 0)))
			if bool(snap.get("game_over", false)):
				phase_text = "FULL TIME"
			elif bool(snap.get("phase_break_pending", false)) or bool(snap.get("phase_break", false)):
				phase_text = "BREAK"
			score_hud.text = "%d : %d    %s    %s" % [
				int(snap.get("score0", 0)),
				int(snap.get("score1", 0)),
				_format_clock(int(snap.get("match_time_ms", 0))),
				phase_text,
			]
		var match_minutes := 5 + int(round(20.0 * float(runtime.get("match_duration"))))
		var park_text := "F2 unpark opponents" if bool(snap.get("debug_park_opponents", false)) \
			else "F2 park opponents"
		hud.text = "GPF slice  %s  tick %d  ball %.1f, %.1f  actors %d\nArrows move   E sprint   S pass   D shot   W through   A high   C dribble   Q switch   match ~%d min\nD+C curl   D+Q chip   double-E knock-on   P pen   Alt+P defend pen   F free kick   Y corner   G goal kick   O throw-in   Tab taker   %s" % [
			status,
			int(snap.get("tick", 0)),
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).x,
			(snap.get("ball_pos", Vector3.ZERO) as Vector3).y,
			actors.size(),
			match_minutes,
			park_text,
		]
	frames += 1
	if shot_path != "" and not shot_taken and frames >= shot_frame:
		shot_taken = true
		_save_screenshot.call_deferred()
	if frames % 60 == 0:
		print("slice frame=", frames, " tick=", snap.get("tick"), " in_play=", snap.get("in_play"), " player=", player.get("id"), " pos=", player.get("pos"), " anim=", player.get("anim"), " ball=", snap.get("ball_pos"))

func _apply_player(id: int, player: Dictionary) -> void:
	var skeleton: Skeleton3D = skeletons.get(id)
	if skeleton == null:
		return
	var bones: Array = player.get("bones", [])
	for bone in bones:
		var name: String = bone.get("name", "")
		var idx: int = bone_indices.get(name, -1)
		if idx < 0:
			continue
		skeleton.set_bone_pose_position(idx, bone.get("pos", Vector3.ZERO))
		skeleton.set_bone_pose_rotation(idx, bone.get("rot", Quaternion.IDENTITY))

func _update_camera(snap: Dictionary) -> void:
	var raw_pos: Vector3 = snap.get("camera_pos", Vector3.ZERO)
	var raw_rot: Quaternion = snap.get("camera_rot", Quaternion.IDENTITY)
	var space: Basis = gpf_space.basis
	var cam_basis: Basis = space * Basis(raw_rot)
	camera.global_transform = Transform3D(cam_basis, gpf_space.transform * raw_pos)
	camera.fov = clamp(float(snap.get("camera_fov", 55.0)), 10.0, 120.0)
	camera.near = maxf(0.05, float(snap.get("camera_near", 1.0)))
	camera.far = maxf(camera.near + 1.0, float(snap.get("camera_far", 200.0)))

	if ball_root != null:
		ball_root.transform = Transform3D(
			Basis(snap.get("ball_rot", Quaternion.IDENTITY)),
			snap.get("ball_pos", Vector3.ZERO)
		)

func _input(event: InputEvent) -> void:
	if not started or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.echo:
		return
	var human_team: int = runtime.get_human_team_id()
	if human_team < 0:
		human_team = 0
	if phase_menu_open:
		if key_event.pressed:
			if phase_menu_game_over:
				if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
					_quit_game()
			elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_continue_phase_break()
		return
	if key_event.keycode == KEY_F2:
		if key_event.pressed:
			runtime.toggle_debug_park_opponents()
		return
	if key_event.keycode == KEY_TAB:
		if key_event.pressed:
			_toggle_taker_menu()
		return
	if taker_menu_open:
		_handle_taker_menu_key(key_event)
		return
	var set_piece_keys := {
		KEY_P: 6,
		KEY_F: 3,
		KEY_Y: 4,
		KEY_G: 2,
		KEY_O: 5,
	}
	if set_piece_keys.has(key_event.keycode):
		if key_event.pressed:
			var team := human_team
			if key_event.alt_pressed:
				team = 1 - human_team
			var set_piece_type: int = set_piece_keys[key_event.keycode]
			runtime.debug_force_set_piece(set_piece_type, team)
		return
	var functions: Array = BUTTONS.get(key_event.keycode, [])
	for function in functions:
		runtime.set_button(int(function), key_event.pressed)

func _toggle_taker_menu() -> void:
	if taker_menu_open:
		_close_taker_menu(false)
		return
	if not runtime.is_set_piece_taker_menu_available():
		return
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_S) \
			or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A):
		return
	if not runtime.open_set_piece_taker_menu():
		return
	taker_menu_candidates = runtime.get_set_piece_taker_candidates()
	if taker_menu_candidates.is_empty():
		runtime.close_set_piece_taker_menu()
		return
	taker_menu_index = 0
	for i in taker_menu_candidates.size():
		if bool(taker_menu_candidates[i].get("current", false)):
			taker_menu_index = i
			break
	taker_menu_open = true
	taker_menu_layer.visible = true
	_refresh_taker_menu()

func _handle_taker_menu_key(event: InputEventKey) -> void:
	if not event.pressed:
		return
	match event.keycode:
		KEY_UP:
			_move_taker_menu(-1)
		KEY_DOWN:
			_move_taker_menu(1)
		KEY_ENTER, KEY_KP_ENTER:
			_close_taker_menu(true)
		KEY_ESCAPE:
			_close_taker_menu(false)
		KEY_D, KEY_S, KEY_W, KEY_A, KEY_Q, KEY_E, KEY_C:
			_close_taker_menu(false)

func _move_taker_menu(delta: int) -> void:
	var count := taker_menu_candidates.size()
	if count == 0:
		return
	taker_menu_index = (taker_menu_index + delta + count) % count
	_refresh_taker_menu()

func _refresh_taker_menu() -> void:
	var lines := PackedStringArray()
	for i in taker_menu_candidates.size():
		var entry: Dictionary = taker_menu_candidates[i]
		var prefix := "> " if i == taker_menu_index else "  "
		var name := String(entry.get("name", ""))
		var suffix := "  (GK)" if String(entry.get("role", "")) == "goalkeeper" else ""
		var current := "  *" if bool(entry.get("current", false)) else ""
		lines.append("%s%s%s%s" % [prefix, name, suffix, current])
	taker_menu_label.text = "\n".join(lines)

func _close_taker_menu(apply_choice: bool) -> void:
	if not taker_menu_open:
		return
	if apply_choice and taker_menu_index >= 0 and taker_menu_index < taker_menu_candidates.size():
		var chosen := int(taker_menu_candidates[taker_menu_index].get("id", -1))
		if chosen >= 0:
			runtime.request_set_piece_taker(chosen)
	runtime.close_set_piece_taker_menu()
	taker_menu_open = false
	taker_menu_layer.visible = false

func _update_debug_park_visibility(snap: Dictionary) -> void:
	var parked := bool(snap.get("debug_park_opponents", false))
	var human_team: int = runtime.get_human_team_id()
	for entry in actors:
		var id := int(entry.get("id", -1))
		var body: Node3D = actor_bodies.get(id)
		if body == null:
			continue
		var hide: bool = parked and String(entry.get("role", "")) == "player" \
			and (human_team < 0 or int(entry.get("team", -1)) != human_team)
		body.visible = not hide

func _sync_taker_ui(snap: Dictionary) -> void:
	if taker_menu_open and not bool(snap.get("set_piece_taker_menu_open", false)):
		_close_taker_menu(false)
	if taker_hint != null:
		taker_hint.visible = bool(snap.get("set_piece_local_taker", false)) \
			and not taker_menu_open and not phase_menu_open \
			and bool(snap.get("in_set_piece", false))

func _sync_phase_menu(snap: Dictionary) -> void:
	var game_over := bool(snap.get("game_over", false))
	var phase_break := bool(snap.get("phase_break_pending", false)) \
		or bool(snap.get("phase_break", false))
	if not game_over and not phase_break:
		if phase_menu_open:
			_close_phase_menu()
		return
	if not phase_menu_open:
		if not game_over and not bool(snap.get("phase_break", false)):
			runtime.begin_phase_break()
		_open_phase_menu(snap)
	else:
		_refresh_phase_menu(snap)

func _open_phase_menu(snap: Dictionary) -> void:
	if taker_menu_open:
		_close_taker_menu(false)
	phase_menu_open = true
	phase_menu_layer.visible = true
	_refresh_phase_menu(snap)
	if phase_menu_game_over:
		phase_menu_quit.grab_focus()
	else:
		phase_menu_continue.grab_focus()

func _refresh_phase_menu(snap: Dictionary) -> void:
	phase_menu_game_over = bool(snap.get("game_over", false))
	var game_over := phase_menu_game_over
	var next_phase := int(snap.get("phase_break_next_phase", 0))
	if game_over:
		var after_extra := int(snap.get("match_time_ms", 0)) >= 7200000 \
			or int(snap.get("match_phase", 0)) == 5
		phase_menu_title.text = "AFTER EXTRA TIME" if after_extra else "FULL TIME"
		phase_menu_subtitle.text = "Final score"
	else:
		phase_menu_title.text = _phase_break_title(next_phase)
		phase_menu_subtitle.text = _phase_break_subtitle(next_phase)
	var home := String(snap.get("team0_name", ""))
	if home == "":
		home = "HOME"
	var away := String(snap.get("team1_name", ""))
	if away == "":
		away = "AWAY"
	phase_menu_score.text = "%s   %d : %d   %s" % [
		home,
		int(snap.get("score0", 0)),
		int(snap.get("score1", 0)),
		away,
	]
	var possession0 := int(snap.get("possession0_ms", 0))
	var possession1 := int(snap.get("possession1_ms", 0))
	var possession_total := possession0 + possession1
	var possession_pct0 := 50
	if possession_total > 0:
		possession_pct0 = int(round(100.0 * float(possession0) / float(possession_total)))
	phase_menu_details.text = "Possession   %d%% - %d%%\nShots        %d - %d" % [
		possession_pct0,
		100 - possession_pct0,
		int(snap.get("shots0", 0)),
		int(snap.get("shots1", 0)),
	]
	phase_menu_continue.visible = not game_over
	if game_over:
		phase_menu_hint.text = "Enter / Esc: exit"
		phase_menu_quit.text = "Exit"
	else:
		phase_menu_hint.text = "Enter / Space: continue"
		phase_menu_quit.text = "Quit"

func _phase_break_title(next_phase: int) -> String:
	match next_phase:
		2:
			return "HALF TIME"
		3:
			return "END OF 90"
		4:
			return "EXTRA TIME"
	return "BREAK"

func _phase_break_subtitle(next_phase: int) -> String:
	match next_phase:
		2:
			return "Begin second half"
		3:
			return "Begin extra time"
		4:
			return "Begin second extra time"
	return "Continue"

func _close_phase_menu() -> void:
	phase_menu_open = false
	phase_menu_layer.visible = false

func _continue_phase_break() -> void:
	if not phase_menu_open or phase_menu_game_over:
		return
	runtime.continue_after_phase_break()
	_close_phase_menu()

func _quit_game() -> void:
	get_tree().quit()

func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(shot_path)
	print("screenshot saved=", shot_path, " err=", err)
	get_tree().quit()

func _run_demo() -> void:
	if frames < 90:
		runtime.set_button(1, true)
		runtime.set_button(14, true)
	elif frames == 90:
		runtime.set_button(1, false)
		runtime.set_button(14, false)
		runtime.set_button(7, true)
	elif frames == 125:
		runtime.set_button(7, false)

func _status_text(snap: Dictionary, player: Dictionary) -> String:
	if bool(snap.get("game_over", false)):
		return "MATCH OVER"
	if bool(snap.get("paused", false)):
		return "PAUSED"
	if bool(snap.get("goal_scored", false)):
		return "GOAL вЂ” restart"
	var piece := int(snap.get("referee_set_piece", 0))
	var role := int(snap.get("set_piece_role", 0))
	if bool(snap.get("in_set_piece", false)):
		var human_team := int(runtime.get_human_team_id())
		if piece == 6 and human_team >= 0 and int(snap.get("referee_team", -1)) != human_team:
			return "PENALTY - keeper: arrows to dive"
		if role == 2:
			return "PENALTY - keeper: arrows to dive"
		var piece_name := _set_piece_name(piece)
		if piece_name == "":
			piece_name = _set_piece_name(int(snap.get("set_piece_type", 0)))
		if piece_name == "":
			piece_name = "SET PIECE"
		var taker := int(snap.get("referee_taker", -1))
		if taker < 0:
			taker = int(snap.get("set_piece_taker", -1))
		if role == 1:
			if piece == 6:
				return "PENALTY - arrows aim, D shot"
			if piece == 2 or piece == 3 or piece == 4:
				return "%s - arrows aim, S/D kick" % piece_name
		if taker == int(player.get("id", -1)):
			return "%s - S pass / D shot" % piece_name
		return "%s - waiting" % piece_name
	if bool(snap.get("referee_active", false)) and piece != 0:
		return "%s вЂ” setup" % _set_piece_name(piece)
	if bool(snap.get("in_play", false)):
		return "LIVE"
	return "PRE-MATCH"

func _format_clock(milliseconds: int) -> String:
	var total_seconds := int(maxf(0.0, float(milliseconds)) / 1000.0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _phase_name(phase: int) -> String:
	if phase >= 0 and phase < PHASE_NAMES.size():
		return PHASE_NAMES[phase]
	return "PHASE %d" % phase

func _set_piece_name(piece: int) -> String:
	if piece > 0 and piece < SET_PIECE_NAMES.size():
		return SET_PIECE_NAMES[piece]
	return ""

func _build_penalty_reticle() -> void:
	penalty_reticle = MeshInstance3D.new()
	penalty_reticle.name = "PenaltyReticle"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.32
	ring.rings = 24
	ring.ring_segments = 8
	penalty_reticle.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.15)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	penalty_reticle.material_override = material
	penalty_reticle.rotation = Vector3(0, 0, PI / 2.0)
	penalty_reticle.visible = false
	gpf_space.add_child(penalty_reticle)

func _update_penalty_reticle(snap: Dictionary) -> void:
	if penalty_reticle == null:
		return
	var role := int(snap.get("set_piece_role", 0))
	var type := int(snap.get("presentation_type", 0))
	var aim: Vector3 = snap.get("set_piece_aim_point", Vector3.ZERO)
	var show := role == 1 and type == 6 and aim.length() > 0.01
	penalty_reticle.visible = show
	if show:
		penalty_reticle.position = aim

func _build_goals() -> void:
	var goals := Node3D.new()
	goals.name = "Goals"
	add_child(goals)

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.96, 0.96, 0.96)
	frame_material.roughness = 0.45
	frame_material.metallic = 0.15

	var net_material := StandardMaterial3D.new()
	net_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net_material.albedo_color = Color(0.9, 0.94, 1.0, 0.5)
	net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	goal_net_material = net_material

	for raw_side in [-1, 1]:
		_build_goal(goals, float(raw_side), frame_material)

func _build_goal(parent: Node3D, raw_side: float, frame_material: Material) -> void:
	var front_x := -GOAL_LINE_RAW * raw_side
	var back_x := front_x - GOAL_DEPTH * raw_side
	for z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
		_add_goal_bar(parent, Vector3(front_x, 0.0, z), Vector3(front_x, GOAL_HEIGHT, z), frame_material)
		_add_goal_bar(parent, Vector3(back_x, 0.0, z), Vector3(back_x, GOAL_HEIGHT, z), frame_material)
		_add_goal_bar(parent, Vector3(front_x, 0.03, z), Vector3(back_x, 0.03, z), frame_material)
	_add_goal_bar(parent, Vector3(front_x, GOAL_HEIGHT, -GOAL_HALF_WIDTH), Vector3(front_x, GOAL_HEIGHT, GOAL_HALF_WIDTH), frame_material)
	_add_goal_bar(parent, Vector3(back_x, GOAL_HEIGHT, -GOAL_HALF_WIDTH), Vector3(back_x, GOAL_HEIGHT, GOAL_HALF_WIDTH), frame_material)
	for z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
		_add_goal_bar(parent, Vector3(front_x, GOAL_HEIGHT, z), Vector3(back_x, GOAL_HEIGHT, z), frame_material)
	_add_goal_bar(parent, Vector3(back_x, 0.03, -GOAL_HALF_WIDTH), Vector3(back_x, 0.03, GOAL_HALF_WIDTH), frame_material)

func _build_dynamic_goal_nets() -> void:
	goal_net_edges = runtime.get_goal_net_edges()
	if goal_net_edges.is_empty():
		push_warning("GpfRuntime returned no goal-net edges")
		return
	var goals := get_node_or_null("Goals") as Node3D
	if goals == null:
		return
	for goal in 2:
		var net := MeshInstance3D.new()
		net.name = "GoalNet%d" % goal
		net.mesh = ImmediateMesh.new()
		net.material_override = goal_net_material
		net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		goals.add_child(net)
		goal_net_meshes.append(net)
		_redraw_goal_net(goal)

func _update_goal_nets() -> void:
	for goal in goal_net_meshes.size():
		_redraw_goal_net(goal)

func _redraw_goal_net(goal: int) -> void:
	if goal < 0 or goal >= goal_net_meshes.size():
		return
	var net := goal_net_meshes[goal]
	var positions: PackedVector3Array = runtime.get_goal_net_positions(goal)
	if positions.is_empty():
		net.visible = false
		return
	net.visible = true
	var mesh := net.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var node_count := positions.size()
	for k in range(goal_net_edges.size() / 2):
		var a := goal_net_edges[k * 2]
		var b := goal_net_edges[k * 2 + 1]
		if a < 0 or b < 0 or a >= node_count or b >= node_count:
			continue
		mesh.surface_add_vertex(positions[a])
		mesh.surface_add_vertex(positions[b])
	mesh.surface_end()

func _add_goal_bar(parent: Node3D, from: Vector3, to: Vector3, material: Material) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = POST_RADIUS
	cylinder.bottom_radius = POST_RADIUS
	cylinder.height = length
	cylinder.radial_segments = 12
	cylinder.rings = 1
	var bar := MeshInstance3D.new()
	bar.mesh = cylinder
	bar.material_override = material
	var direction := delta / length
	var basis := Basis.IDENTITY
	if absf(direction.dot(Vector3.UP)) < 0.9999:
		basis = Basis(Quaternion(Vector3.UP, direction))
	elif direction.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	bar.transform = Transform3D(basis, (from + to) * 0.5)
	parent.add_child(bar)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	score_hud = Label.new()
	score_hud.position = Vector2(24, 14)
	score_hud.add_theme_font_size_override("font_size", 34)
	score_hud.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	score_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	score_hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(score_hud)

	hud = Label.new()
	hud.position = Vector2(24, 64)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)

	taker_hint = Label.new()
	taker_hint.position = Vector2(24, 150)
	taker_hint.add_theme_font_size_override("font_size", 18)
	taker_hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	taker_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	taker_hint.add_theme_constant_override("outline_size", 4)
	taker_hint.text = "Tab: change taker"
	taker_hint.visible = false
	layer.add_child(taker_hint)

func _build_taker_menu() -> void:
	taker_menu_layer = CanvasLayer.new()
	taker_menu_layer.layer = 2
	add_child(taker_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	taker_menu_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	taker_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.96)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SET-PIECE TAKER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(title)

	taker_menu_label = Label.new()
	taker_menu_label.add_theme_font_size_override("font_size", 20)
	taker_menu_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	box.add_child(taker_menu_label)

	var hint := Label.new()
	hint.text = "Up/Down select    Enter apply    Esc/Tab close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(hint)

	taker_menu_layer.visible = false

func _build_phase_menu() -> void:
	phase_menu_layer = CanvasLayer.new()
	phase_menu_layer.layer = 3
	add_child(phase_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_menu_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	phase_menu_title = Label.new()
	phase_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_title.add_theme_font_size_override("font_size", 32)
	phase_menu_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(phase_menu_title)

	phase_menu_subtitle = Label.new()
	phase_menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_subtitle.add_theme_font_size_override("font_size", 18)
	phase_menu_subtitle.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
	box.add_child(phase_menu_subtitle)

	phase_menu_score = Label.new()
	phase_menu_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_score.add_theme_font_size_override("font_size", 28)
	phase_menu_score.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	box.add_child(phase_menu_score)

	phase_menu_details = Label.new()
	phase_menu_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_details.add_theme_font_size_override("font_size", 18)
	phase_menu_details.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	box.add_child(phase_menu_details)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	phase_menu_continue = Button.new()
	phase_menu_continue.text = "Continue"
	phase_menu_continue.custom_minimum_size = Vector2(160, 40)
	buttons.add_child(phase_menu_continue)
	phase_menu_continue.pressed.connect(_continue_phase_break)

	phase_menu_quit = Button.new()
	phase_menu_quit.text = "Quit"
	phase_menu_quit.custom_minimum_size = Vector2(160, 40)
	buttons.add_child(phase_menu_quit)
	phase_menu_quit.pressed.connect(_quit_game)

	phase_menu_hint = Label.new()
	phase_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_menu_hint.add_theme_font_size_override("font_size", 14)
	phase_menu_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(phase_menu_hint)

	phase_menu_layer.visible = false
