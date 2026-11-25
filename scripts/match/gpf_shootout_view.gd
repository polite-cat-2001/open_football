class_name GpfShootoutView
extends Node
# Presentation of the penalty shootout series: the two circle rows, outcome
# banners and the reposition fade. The series and its result screen live
# elsewhere (C++ owns the series, GpfMatchOver owns the end screen).

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
const DOTS_POS := Vector2(24.0, 14.0 + MatchScoreboard.PLATE_H + 8.0)
const BANNER_TIME := 1.2
const FADE_TIME := 0.3

var shootout_layer: CanvasLayer
var shootout_dots: ShootoutDots
var scoreboard: MatchScoreboard
var shootout_banner: Label
var shootout_fade: ColorRect
var shootout_fade_tween: Tween
var shootout_outcome_counter := 0
var shootout_last_phase := -1
var shootout_banner_left := 0.0


func setup() -> void:
	_build_ui()


# Rows hang under their own team in the scoreboard; without a board (ui_lab)
# they keep the default left-aligned spot.
func set_scoreboard(board: MatchScoreboard) -> void:
	scoreboard = board


func reset() -> void:
	shootout_outcome_counter = 0
	shootout_last_phase = -1
	shootout_banner_left = 0.0
	if shootout_layer != null:
		shootout_layer.visible = false
	if shootout_banner != null:
		shootout_banner.visible = false
	if shootout_dots != null:
		shootout_dots.set_results([], [])
	if shootout_fade_tween != null and shootout_fade_tween.is_valid():
		shootout_fade_tween.kill()
	if shootout_fade != null:
		shootout_fade.color.a = 0.0


func update(snap: Dictionary, delta: float) -> void:
	var active := bool(snap.get("shootout_active", false)) \
		and not bool(snap.get("paused", false))
	shootout_layer.visible = active
	if not active:
		return

	var kicks0: Array = snap.get("shootout_kicks0", [])
	var kicks1: Array = snap.get("shootout_kicks1", [])
	if scoreboard != null:
		shootout_dots.position = scoreboard.position \
			+ Vector2(0.0, scoreboard.size.y + 8.0)
		shootout_dots.set_row_lefts(scoreboard.team_outer_edge_x(0),
			scoreboard.team_outer_edge_x(1) - ShootoutDots.WIDTH)
	shootout_dots.set_results(kicks0, kicks1)

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

	if phase == PHASE_FINISHED:
		# The decisive celebration has finished and the C++ frame is paused: fade
		# the circles out; GpfSlice opens the result screen from the snapshot.
		_fade_to(0.0, 0.4)


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

	shootout_dots = ShootoutDots.new()
	shootout_dots.position = DOTS_POS
	shootout_layer.add_child(shootout_dots)

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
