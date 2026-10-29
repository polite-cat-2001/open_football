class_name GpfShootoutView
extends Node
# Presentation of the penalty shootout series: the two circle rows, outcome banners,
# the reposition fade and the end-of-match menu. The series itself lives in C++.

# Mirrors e_ShootoutPhase / e_ShootoutOutcome in the C++ runtime.
const PHASE_NONE := 0
const PHASE_KICK_SETUP := 1
const PHASE_KICK_AIM := 2
const PHASE_KICK_OUTCOME := 3
const PHASE_OUTCOME_HOLD := 4
const PHASE_DECISIVE_CELEBRATION := 5
const PHASE_FINISHED := 6
const PHASE_TRANSITION := 7
const OUTCOME_TEXT := {1: "GOAL", 2: "SAVE", 3: "MISS"}
const CIRCLE_COLORS := {
	0: Color(0.30, 0.32, 0.36, 0.92),
	1: Color(0.20, 0.85, 0.35),
	2: Color(0.92, 0.22, 0.20),
}
const CIRCLE_SIZE := 20.0
const BANNER_TIME := 1.2
const FADE_TIME := 0.3

var shootout_layer: CanvasLayer
var shootout_home_row: HBoxContainer
var shootout_away_row: HBoxContainer
var shootout_circles := {0: [], 1: []}
var shootout_banner: Label
var shootout_fade: ColorRect
var shootout_fade_tween: Tween
var shootout_outcome_counter := 0
var shootout_last_phase := -1
var shootout_banner_left := 0.0
var shootout_end_layer: CanvasLayer
var shootout_end_score: Label
var shootout_end_buttons: Array[Button] = []
var shootout_end_index := 0
var shootout_end_open := false


func setup() -> void:
	_build_ui()
	_build_end_menu()


func is_end_menu_open() -> bool:
	return shootout_end_open


func reset() -> void:
	shootout_end_open = false
	shootout_outcome_counter = 0
	shootout_last_phase = -1
	shootout_banner_left = 0.0
	if shootout_end_layer != null:
		shootout_end_layer.visible = false
	if shootout_layer != null:
		shootout_layer.visible = false
	if shootout_banner != null:
		shootout_banner.visible = false
	if shootout_fade_tween != null and shootout_fade_tween.is_valid():
		shootout_fade_tween.kill()
	if shootout_fade != null:
		shootout_fade.color.a = 0.0


func handle_end_menu_key(event: InputEventKey) -> void:
	if not event.pressed:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE:
			_continue()
		KEY_R:
			_restart()
		KEY_UP, KEY_LEFT:
			shootout_end_index = (shootout_end_index + shootout_end_buttons.size() - 1) % shootout_end_buttons.size()
			shootout_end_buttons[shootout_end_index].grab_focus()
		KEY_DOWN, KEY_RIGHT:
			shootout_end_index = (shootout_end_index + 1) % shootout_end_buttons.size()
			shootout_end_buttons[shootout_end_index].grab_focus()


func update(snap: Dictionary, delta: float) -> void:
	var active := bool(snap.get("shootout_active", false))
	shootout_layer.visible = active
	if not active:
		return

	var kicks0: Array = snap.get("shootout_kicks0", [])
	var kicks1: Array = snap.get("shootout_kicks1", [])
	var count := maxi(5, maxi(kicks0.size(), kicks1.size()))
	_ensure_circles(0, count)
	_ensure_circles(1, count)
	for team in [0, 1]:
		var results: Array = kicks0 if team == 0 else kicks1
		for i in shootout_circles[team].size():
			var value := int(results[i]) if i < results.size() else 0
			var panel: Panel = shootout_circles[team][i]
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style != null:
				style.bg_color = CIRCLE_COLORS.get(value, CIRCLE_COLORS[0])

	var counter := int(snap.get("shootout_outcome_counter", 0))
	if counter != shootout_outcome_counter:
		shootout_outcome_counter = counter
		var text: String = OUTCOME_TEXT.get(int(snap.get("shootout_outcome", 0)), "")
		if text != "":
			shootout_banner.text = text
			shootout_banner.visible = true
			shootout_banner_left = BANNER_TIME
	if shootout_banner_left > 0.0:
		shootout_banner_left -= delta
		if shootout_banner_left <= 0.0:
			shootout_banner.visible = false

	var phase := int(snap.get("shootout_phase", 0))
	if phase != shootout_last_phase:
		if phase == PHASE_TRANSITION:
			# The C++ side repositions everybody only after this fade is fully black.
			_fade_to(1.0)
		elif phase == PHASE_KICK_AIM:
			# Players are in place and the whistle has blown: fade the pitch back in.
			_fade_to(0.0)
		shootout_last_phase = phase

	if phase == PHASE_FINISHED and not shootout_end_open:
		# The decisive celebration has finished and the C++ frame is paused: show the end menu.
		_fade_to(0.0, 0.4)
		_open_end_menu(snap)


func _open_end_menu(snap: Dictionary) -> void:
	shootout_end_open = true
	shootout_end_index = 0
	var score0 := int(snap.get("shootout_score0", 0))
	var score1 := int(snap.get("shootout_score1", 0))
	shootout_end_score.text = "Победа: %d:%d" % [maxi(score0, score1), mini(score0, score1)]
	shootout_end_layer.visible = true
	shootout_banner.visible = false
	shootout_end_buttons[shootout_end_index].grab_focus()


func _continue() -> void:
	get_tree().quit()


func _restart() -> void:
	# The C++ match runtime is one-shot: restart the whole game process for a fresh match.
	OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	get_tree().quit()


func _ensure_circles(team: int, count: int) -> void:
	var row: HBoxContainer = shootout_home_row if team == 0 else shootout_away_row
	var circles: Array = shootout_circles[team]
	while circles.size() < count:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
		var style := StyleBoxFlat.new()
		style.bg_color = CIRCLE_COLORS[0]
		style.set_corner_radius_all(int(CIRCLE_SIZE * 0.5))
		style.set_border_width_all(2)
		style.border_color = Color(0, 0, 0, 0.7)
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		circles.append(panel)
	shootout_circles[team] = circles


func _fade_to(alpha: float, duration: float = FADE_TIME) -> void:
	if shootout_fade_tween != null and shootout_fade_tween.is_valid():
		shootout_fade_tween.kill()
	shootout_fade_tween = create_tween()
	shootout_fade_tween.tween_property(shootout_fade, "color:a", alpha, duration)


func _build_ui() -> void:
	shootout_layer = CanvasLayer.new()
	shootout_layer.layer = 4
	shootout_layer.visible = false
	add_child(shootout_layer)

	# Fade first: circles and banners stay above it.
	shootout_fade = ColorRect.new()
	shootout_fade.color = Color(0, 0, 0, 0)
	shootout_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shootout_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shootout_layer.add_child(shootout_fade)

	shootout_home_row = HBoxContainer.new()
	shootout_home_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shootout_home_row.add_theme_constant_override("separation", 10)
	shootout_home_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	shootout_home_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shootout_home_row.offset_top = 18
	shootout_layer.add_child(shootout_home_row)

	shootout_away_row = HBoxContainer.new()
	shootout_away_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shootout_away_row.add_theme_constant_override("separation", 10)
	shootout_away_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	shootout_away_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shootout_away_row.offset_bottom = -18
	shootout_layer.add_child(shootout_away_row)

	shootout_banner = Label.new()
	shootout_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shootout_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shootout_banner.offset_top = -120
	shootout_banner.add_theme_font_size_override("font_size", 44)
	shootout_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	shootout_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	shootout_banner.add_theme_constant_override("outline_size", 8)
	shootout_banner.visible = false
	shootout_layer.add_child(shootout_banner)


func _build_end_menu() -> void:
	shootout_end_layer = CanvasLayer.new()
	shootout_end_layer.layer = 5
	shootout_end_layer.visible = false
	add_child(shootout_end_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.06, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shootout_end_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shootout_end_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.85, 0.25, 0.9)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "КОНЕЦ МАТЧА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	box.add_child(title)

	shootout_end_score = Label.new()
	shootout_end_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shootout_end_score.add_theme_font_size_override("font_size", 28)
	shootout_end_score.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	box.add_child(shootout_end_score)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	var continue_button := Button.new()
	continue_button.text = "Продолжить"
	continue_button.custom_minimum_size = Vector2(180, 42)
	continue_button.pressed.connect(_continue)
	buttons.add_child(continue_button)
	shootout_end_buttons.append(continue_button)

	var restart_button := Button.new()
	restart_button.text = "Начать заново"
	restart_button.custom_minimum_size = Vector2(180, 42)
	restart_button.pressed.connect(_restart)
	buttons.add_child(restart_button)
	shootout_end_buttons.append(restart_button)

	var hint := Label.new()
	hint.text = "Enter — продолжить    R — начать заново"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(hint)
