extends SceneTree
# Smoke test for the Godot-side in-match UI: the Tab taker menu, debug throw-ins and
# the half-time/full-time phase menu. Loads the real slice scene, forces the states
# through the bridge.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var scene: Node
var runtime: Node
var environment: Node
var actors: Node
var hud: Node
var replay: Node
var camera_rig: Node
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)

func _run() -> void:
	# gpf_slice only starts from a shell-built package (no built-in teams).
	var package := MatchPackageFixture.build(DATA_ROOT, 4, 5)
	if package.is_empty():
		_check(false, "match package could not be built")
		_finish()
		return
	ShellState.set_match_package(package)

	var packed: PackedScene = load("res://scenes/gpf_slice.tscn")
	scene = packed.instantiate()
	get_root().add_child(scene)
	await process_frame
	runtime = get_first_node_in_group("gpf_runtime")
	environment = scene.get_node("Environment")
	actors = scene.get_node("Actors")
	hud = scene.get_node("Hud")
	replay = scene.get_node("ReplayView")
	camera_rig = scene.get_node("CameraRig")
	runtime.set("manual_step", true)
	runtime.set("data_root", DATA_ROOT)
	for i in 4:
		await process_frame
	var net0 := scene.get_node_or_null("GoalNets/GoalNet0") as MeshInstance3D
	_check(net0 != null and net0.mesh != null and net0.mesh.get_surface_count() > 0,
		"dynamic goal net is built")
	var sun := scene.get_node_or_null("Sun") as DirectionalLight3D
	var fill := scene.get_node_or_null("FillLight") as DirectionalLight3D
	_check(sun != null and sun.light_energy > 0.0 and fill != null and fill.light_energy > 0.0,
		"sun and fill lights are present")
	var old_lighting: int = int(environment.get("lighting_index"))
	scene.call("_input", _key(KEY_F1))
	await process_frame
	_check(int(environment.get("lighting_index")) == old_lighting,
		"F1 no longer changes the lighting")
	scene.call("_input", _key(KEY_F8))
	await process_frame
	_check(int(environment.get("lighting_index")) != old_lighting, "F8 cycles the time of day")
	var preset_map: Dictionary = environment.get_script().get_script_constant_map()
	var presets: Array = preset_map.get("LIGHTING_PRESETS", [])
	var preset_names: Array = []
	for preset in presets:
		preset_names.append(String(preset.get("name", "")))
	_check(preset_names == ["Noon", "Afternoon", "Sunset", "Night"],
		"four presets: Noon, Afternoon, Sunset, Night")
	var stadium_node := environment.get_node_or_null("Stadium") as Node3D
	environment.call("set_lighting_by_name", "Night")
	await process_frame
	var floods: Node3D = null
	if stadium_node != null:
		floods = stadium_node.get_node_or_null("Floodlights") as Node3D
	var panels: Array = []
	if floods != null:
		panels = floods.find_children("*", "MeshInstance3D", true, false)
	_check(floods != null and floods.visible and panels.size() == 4,
		"Night shows four floodlight fixtures")
	var panel_material: Material = (panels[0] as MeshInstance3D).material_override if panels.size() > 0 else null
	_check(panel_material is StandardMaterial3D
		and (panel_material as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		and (panel_material as StandardMaterial3D).emission_enabled,
		"floodlight fixtures are unshaded emitters")
	var flood_lights: Array = environment.get("flood_lights")
	var lit_fills := 0
	var shadowed := 0
	for light in flood_lights:
		if light.visible:
			lit_fills += 1
		if light is SpotLight3D and (light as SpotLight3D).shadow_enabled:
			shadowed += 1
	_check(flood_lights.size() == 4 and lit_fills == 4 and shadowed == 0,
		"Night floodlights are fill; the sun casts the shadow")
	environment.call("set_lighting_by_name", "Afternoon")
	await process_frame
	lit_fills = 0
	for light in flood_lights:
		if light.visible:
			lit_fills += 1
	_check(not floods.visible and lit_fills == 0, "other presets hide the floodlights")
	var replay_banner := replay.get("replay_banner") as Label
	_check(replay_banner != null and not replay_banner.visible
		and runtime.has_method("set_replay_active"), "replay overlay and pause hook are ready")
	var ball_node := actors.get("ball_root") as Node3D
	var ball_shadow := false
	var ball_textured := false
	if ball_node != null:
		for mesh in ball_node.find_children("*", "MeshInstance3D", true, false):
			ball_shadow = ball_shadow or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ball_material := mesh.material_override as StandardMaterial3D
			ball_textured = ball_textured \
				or (ball_material != null and ball_material.albedo_texture != null)
	_check(ball_shadow, "ball casts a shadow")
	_check(ball_textured, "ball uses the original ball texture")
	var scoreboard := scene.get_node_or_null("Hud/HudOverlay/Scoreboard") as MatchScoreboard
	_check(scoreboard != null and scoreboard.home_crest != null
		and scoreboard.away_crest != null and scoreboard.clock_text.length() == 5,
		"the scoreboard reads the package crests and the snapshot clock")
	var nameplates: Dictionary = actors.get("player_labels")
	var controlled_id := int(actors.get("controlled_id"))
	var controlled_label := nameplates.get(controlled_id) as Label3D
	var other_label: Label3D = null
	for id in nameplates:
		if int(id) != controlled_id:
			other_label = nameplates[id] as Label3D
			break
	_check(nameplates.size() == 22 and controlled_label != null
		and not controlled_label.text.is_empty(), "nameplates carry player surnames")
	_check(controlled_label != null and other_label != null
		and controlled_label.modulate != other_label.modulate,
		"controlled player's nameplate is highlighted")

	# Pause menu navigation must not be double-stepped by Godot's GUI focus:
	# Up moves to the lineup card, Enter opens the game plan (keyboard path).
	var pause_menu := scene.get("pause_menu") as GpfPauseMenu
	var game_plan := scene.get("game_plan") as GpfGamePlan
	await _inject_key(KEY_ESCAPE)
	_check(pause_menu.is_open(), "Esc opens the pause menu")
	_check(pause_menu.buttons[0].has_focus(), "Continue owns focus on entry")
	await _inject_key(KEY_LEFT)
	var focus_owner := scene.get_viewport().gui_get_focus_owner()
	_check(focus_owner == pause_menu.screen.lineup_tile,
		"Left moves to the lineup card")
	await _inject_key(KEY_ENTER)
	_check(not pause_menu.is_open() and game_plan.is_open(),
		"Enter opens the game plan from the lineup card")
	await _inject_key(KEY_ESCAPE)
	await create_timer(0.7).timeout
	_check(pause_menu.is_open() and not game_plan.is_open(),
		"Back from the game plan returns to the pause menu")
	await _inject_key(KEY_ESCAPE)
	_check(not pause_menu.is_open(), "Esc resumes from the pause menu")

	# Gamepad path: D-pad left then A must hit the same lineup card.
	await _inject_key(KEY_ESCAPE)
	await _inject_joy(JOY_BUTTON_DPAD_LEFT)
	_check(scene.get_viewport().gui_get_focus_owner() == pause_menu.screen.lineup_tile,
		"the lineup card owns focus on the gamepad too")
	await _inject_joy(JOY_BUTTON_A)
	_check(game_plan.is_open(), "gamepad A opens the game plan")
	await _inject_joy(JOY_BUTTON_B)
	await create_timer(0.7).timeout
	_check(pause_menu.is_open() and not game_plan.is_open(),
		"gamepad B returns from the game plan to the pause menu")
	await _inject_joy(JOY_BUTTON_B)
	_check(not pause_menu.is_open(), "gamepad B resumes from the pause menu")

	var goal_frames := scene.get_node_or_null("Environment/GoalFrames") as Node3D
	var frame_count := 0
	var hidden_count := 0
	var frame_shadow := false
	if goal_frames != null:
		for node in goal_frames.find_children("*", "MeshInstance3D", true, false):
			if node.visible:
				frame_count += 1
				frame_shadow = frame_shadow \
					or (node as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				hidden_count += 1
	_check(goal_frames != null and frame_count == 1 and hidden_count == 1,
		"imported goal frame is visible and static net is hidden")
	_check(frame_shadow, "goal frame casts a shadow")

	var stadium := scene.get_node_or_null("Environment/Stadium") as Node3D
	_check(stadium != null and stadium.visible, "imported stadium is present")
	var stadium_meshes := stadium.find_children("*", "MeshInstance3D", true, false) if stadium else []
	var textured := 0
	for node in stadium_meshes:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_surface_override_material(surface)
			if material == null:
				material = mesh.mesh.surface_get_material(surface)
			if material is BaseMaterial3D and material.albedo_texture != null:
				textured += 1
	_check(stadium_meshes.size() >= 31 and textured >= 31,
		"stadium meshes carry baked textures (%d meshes, %d textured surfaces)" % [stadium_meshes.size(), textured])
	var crowd: StandardMaterial3D = null
	for node in stadium_meshes:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_surface_override_material(surface)
			if material == null:
				material = mesh.mesh.surface_get_material(surface)
			var standard := material as StandardMaterial3D
			if standard != null and GpfAssets.material_index(standard.resource_name) == 30:
				crowd = standard
	_check(crowd != null and crowd.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		and crowd.normal_enabled and crowd.normal_texture != null,
		"crowd material is alpha-cut with a normal map")
	var pitch_node := scene.get_node_or_null("Environment/Pitch") as Node3D
	var pitch_materials: Array = environment.get("pitch_materials")
	var pitch_surface: MeshInstance3D = null
	if pitch_node != null:
		pitch_surface = pitch_node.get_node_or_null("PitchSurface") as MeshInstance3D
	_check(pitch_node != null and pitch_node.visible and pitch_materials.size() == 1
		and pitch_surface != null and pitch_surface.mesh.get_surface_count() == 1,
		"imported pitch is merged into one themed surface")
	environment.call("set_pitch_theme", "wet")
	var wet_pitch := pitch_materials[0] as ShaderMaterial
	_check(wet_pitch != null and float(wet_pitch.get_shader_parameter("pitch_roughness")) < 0.5,
		"wet pitch theme changes roughness")
	_check(wet_pitch != null and wet_pitch.get_shader_parameter("albedo_map") != null
		and wet_pitch.get_shader_parameter("detail_albedo") != null
		and wet_pitch.get_shader_parameter("detail_normal") != null
		and float(wet_pitch.get_shader_parameter("detail_strength")) > 0.0,
		"pitch material carries the detail layer")
	environment.call("set_pitch_theme", "dry")
	scene.call("_input", _key(KEY_F6))
	await process_frame
	_check(bool(camera_rig.get("stadium")), "V switches to the stadium camera")
	scene.call("_input", _key(KEY_F6))
	await process_frame
	_check(not bool(camera_rig.get("stadium")), "V returns to the broadcast camera")

	var ids: Array = runtime.get_player_ids()
	var outfield := -1
	var opponent_outfield := -1
	for entry in ids:
		if String(entry.get("role", "")) != "player":
			continue
		if int(entry.get("team", -1)) == 0 and outfield < 0:
			outfield = int(entry.get("id", -1))
		elif int(entry.get("team", -1)) == 1 and opponent_outfield < 0:
			opponent_outfield = int(entry.get("id", -1))
	_check(outfield >= 0, "outfield exists")
	_check(opponent_outfield >= 0, "opponent outfield exists")
	if outfield < 0 or opponent_outfield < 0:
		_finish()
		return

	runtime.start_open_play(outfield)
	runtime.step_fixed(120)

	scene.call("_input", _key(KEY_F2))
	await process_frame
	_check(bool(runtime.get_snapshot().get("debug_park_opponents", false)),
		"F2 parks opponent outfielders")
	var bodies: Dictionary = actors.get("actor_bodies")
	var red_body: Node3D = bodies.get(opponent_outfield)
	_check(red_body != null and not red_body.visible, "parked opponent is hidden")
	scene.call("_input", _key(KEY_F2))
	await process_frame
	_check(not bool(runtime.get_snapshot().get("debug_park_opponents", false)),
		"F2 restores opponent outfielders")
	_check(red_body != null and red_body.visible, "opponent is visible again")

	runtime.debug_force_set_piece(3, 0)
	var snap: Dictionary = {}
	for i in 500:
		runtime.step_fixed(10)
		await process_frame
		snap = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) and int(snap.get("referee_set_piece", 0)) == 3:
			break
	_check(bool(snap.get("set_piece_local_taker", false)), "free kick has a local taker")
	var hint := hud.get("taker_hint") as Label
	_check(hint != null and hint.visible and hint.text == "Tab: change taker",
		"Tab hint is visible for the keyboard taker")
	scene.call("_input", _key(KEY_TAB))
	await process_frame
	_check(hud.is_taker_menu_open(), "Tab opens the taker menu")
	_check(bool(runtime.is_set_piece_taker_menu_open()), "bridge menu is open")
	var taker_menu: GpfSetPieceTakerMenu = hud.get("taker_menu")
	var title := taker_menu.get("title_label") as Label
	var taker_hint := taker_menu.get("hint_label") as Label
	var texts := taker_menu.button_texts()
	_check(title != null and title.text == "set-piece taker", "menu title matches the original")
	_check(taker_hint != null and taker_hint.text == "enter: apply   escape: close",
		"menu hint matches the original")
	_check(texts.size() == 11, "menu lists every active player")
	var keeper_marked := false
	var marked := 0
	for text in texts:
		keeper_marked = keeper_marked or "(GK)" in text
		if text.ends_with("*"):
			marked += 1
	_check(keeper_marked, "keeper is marked (GK)")
	_check(marked == 1, "exactly the current taker is marked *")
	_check(hud.accepts_taker_menu_keyboard(), "the taker's keyboard owns the menu")
	scene.call("_input", _key(KEY_ESCAPE))
	await process_frame
	_check(not hud.is_taker_menu_open(), "Escape closes the taker menu")
	_check(not bool(runtime.is_set_piece_taker_menu_open()), "bridge menu is closed")
	runtime.step_fixed(2)
	await process_frame
	var before_taker := int(runtime.get_snapshot().get("referee_taker", -1))
	var before_human_team := int(runtime.get_human_team_id())
	scene.call("_input", _key(KEY_TAB))
	scene.call("_input", _key(KEY_DOWN))
	scene.call("_input", _key(KEY_ENTER))
	await process_frame
	runtime.step_fixed(3)
	var after: Dictionary = runtime.get_snapshot()
	_check(not hud.is_taker_menu_open(), "Enter closes the taker menu")
	_check(int(after.get("referee_taker", -1)) != before_taker, "Enter applies another taker")
	_check(int(runtime.get_human_team_id()) == before_human_team,
		"control stays with the player who opened the menu")

	runtime.start_open_play(outfield)
	await process_frame
	runtime.step_fixed(20)
	scene.call("_input", _key(KEY_O))
	var throw_snap: Dictionary = await _wait_for_set_piece(5)
	_check(not throw_snap.is_empty(), "O forces a throw-in")
	_check(int(throw_snap.get("referee_team", -1)) == 0, "O gives the throw-in to the human team")

	runtime.start_open_play(outfield)
	await process_frame
	runtime.step_fixed(20)
	var alt_o := _key(KEY_O)
	alt_o.alt_pressed = true
	scene.call("_input", alt_o)
	throw_snap = await _wait_for_set_piece(5)
	_check(not throw_snap.is_empty(), "Alt+O forces a throw-in")
	_check(int(throw_snap.get("referee_team", -1)) == 1, "Alt+O gives the throw-in to the opponent")

	runtime.debug_force_phase_break(2)
	for i in 10:
		await process_frame
	_check(pause_menu.is_open() and pause_menu.is_break(),
		"phase break opens the pause screen")
	_check(pause_menu.screen.continue_tile.title == "BEGIN SECOND HALF",
		"half-time continue reads begin second half")
	_check(str(pause_menu.screen.get("_break_caption")) == "HALF TIME",
		"the scoreboard shows the half-time caption")
	_check(bool(runtime.get_snapshot().get("paused", false)), "phase break pauses the match")
	scene.call("_input", _key(KEY_ENTER))
	await process_frame
	_check(not pause_menu.is_open(), "Enter continues after the phase break")
	_check(not bool(runtime.get_snapshot().get("paused", false)), "continue unpauses the match")

	# A level score at 90:00 is the draw choice, not the period break.
	var snap90: Dictionary = runtime.get_snapshot()
	runtime.debug_force_phase_break(3)
	for i in 10:
		await process_frame
	var over = scene.get("match_over")
	_check(int(snap90.get("score0", -1)) == int(snap90.get("score1", 0)),
		"the 90:00 choice is tested on a level score")
	_check(over != null and over.is_choice(), "a level 90:00 opens the choice screen")
	_check(bool(runtime.get_snapshot().get("paused", false)),
		"the choice screen pauses the match")
	# DRAW accepts the draw and lands on the result screen.
	scene.call("_input", _key(KEY_DOWN))
	scene.call("_input", _key(KEY_RIGHT))
	scene.call("_input", _key(KEY_ENTER))
	for i in 10:
		await process_frame
	_check(over != null and over.is_open() and not over.is_choice(),
		"draw shows the result screen")
	_check(str(over.result.scoreboard.get("_clock")) == "FULL TIME",
		"the result header reads FULL TIME")
	_check(over.result.tiles().size() == 4
		and over.result.tiles()[0].title == "ADVANCE",
		"the result screen has the ADVANCE tile")
	_finish()

func _wait_for_set_piece(type: int) -> Dictionary:
	for i in 500:
		runtime.step_fixed(10)
		await process_frame
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_set_piece", false)) and int(snap.get("referee_set_piece", 0)) == type:
			return snap
	return {}

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _inject_key(code: int) -> void:
	Input.parse_input_event(_key(code))
	await process_frame
	await process_frame


func _inject_joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: slice UI")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
