class_name GpfGamePlan
extends Control
# Godot port of GamePlanPage (GameplayFootball src/menu/gameplan.cpp): a pitch
# with player cards, a bench column, a per-side cursor and the original section
# bar (Tactics / Positions / Roles / Size). The same screen is embedded in the
# prematch hub ("Game plan" tab) and opened from the in-match pause menu.
#
# Data comes from one of two sources, never from the screen itself:
#   prematch: MatchLineup objects (swaps rewrite the lineup used by the package)
#   match:    GpfRuntimeNode.get_squad() and its substitution bridge
#
# Positions is the live section: pick a starter, then a substitute (or another
# starter in prematch) and the change is applied. Tactics/Roles/Size are present
# but stubbed for this ticket; the original's per-device section bar is kept.

signal close_requested
signal lineup_changed

const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const SECTION_NAMES := ["Tactics", "Positions", "Roles", "Size"]
const SECTION_DESCRIPTIONS := [
	"Choose a tactical scheme",
	"Change positions",
	"Captain and set-piece takers",
	"Player size",
]
const SECTION_TACTICS := 0
const SECTION_POSITIONS := 1
const SECTION_ROLES := 2
# User-facing role order from GamePlanPage::planRoleOrder.
const TEAM_ROLE_ROWS := [
	{"role": 0, "name": "Captain"},
	{"role": 3, "name": "Free kick far"},
	{"role": 2, "name": "Free kick near"},
	{"role": 1, "name": "Penalty taker"},
	{"role": 4, "name": "Left corner"},
	{"role": 5, "name": "Right corner"},
]
const DEFAULT_HINT := "Arrows/D-pad: move   Enter/A: select   Esc/B: back   Y/Tab: bench/pitch   X: cancel sub"
const DEFAULT_COLORS := {
	0: Color(0.16, 0.32, 0.95),
	1: Color(0.95, 0.16, 0.12),
}
const CARD_MIN_W := 30.0
const CARD_MAX_W := 78.0
const PHOTO_ASPECT := 0.80
const ROW_REPEAT_MS := 180


class GamePlanPitch extends Control:
	signal card_clicked(panel_index: int, entry_index: int)

	var panel_index := 0
	var team_color := Color(0.2, 0.4, 0.9)
	var cards: Array = []
	var cursor := -1
	var held := -1
	var editing := false

	func set_cards(value: Array) -> void:
		cards = value
		queue_redraw()

	func set_markers(new_cursor: int, new_held: int, is_editing: bool) -> void:
		cursor = new_cursor
		held = new_held
		editing = is_editing
		queue_redraw()

	func _draw() -> void:
		var area := get_size()
		if area.x <= 0.0 or area.y <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, area), Color(0.07, 0.26, 0.11), true)
		var line_color := Color(0.82, 0.90, 0.82, 0.70)
		draw_rect(Rect2(Vector2(2, 2), area - Vector2(4, 4)), line_color, false, 2.0)
		draw_line(Vector2(2, area.y * 0.5), Vector2(area.x - 2, area.y * 0.5), line_color, 1.5)
		draw_arc(Vector2(area.x * 0.5, area.y * 0.5), area.x * 0.13, 0.0, TAU, 32, line_color, 1.5)
		var box_w := area.x * 0.44
		var box_h := area.y * 0.12
		draw_rect(Rect2((area.x - box_w) * 0.5, 2, box_w, box_h), line_color, false, 1.5)
		draw_rect(Rect2((area.x - box_w) * 0.5, area.y - box_h - 2, box_w, box_h), line_color, false, 1.5)

		var font := ThemeDB.fallback_font
		for card in cards:
			var entry: Dictionary = card["entry"]
			var rect: Rect2 = card["rect"]
			var photo: Rect2 = card["photo"]
			var name_rect: Rect2 = card["name"]
			var role_rect: Rect2 = card["role"]
			var bar_rect: Rect2 = card["bar"]
			draw_rect(photo, team_color.darkened(0.15), true)
			draw_rect(photo, Color(0.95, 0.97, 0.95, 0.65), false, 1.0)
			draw_rect(name_rect, Color(0.03, 0.05, 0.08, 0.85), true)
			draw_rect(role_rect, Color(0.06, 0.09, 0.12, 0.9), true)
			draw_rect(bar_rect, Color(0.10, 0.10, 0.10, 1.0), true)
			var fatigue := clampi(int(entry.get("fatigue", 100)), 0, 100)
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * float(fatigue) / 100.0, bar_rect.size.y)),
				_fatigue_color(fatigue), true)

			var font_size := maxi(9, int(photo.size.y * 0.18))
			var role_text := "%s%s" % [str(card.get("display_role", entry.get("role", ""))),
				_rating_suffix(entry)]
			draw_string(font, Vector2(role_rect.position.x, role_rect.position.y + role_rect.size.y * 0.78),
				role_text, HORIZONTAL_ALIGNMENT_CENTER, role_rect.size.x, font_size,
				Color(0.92, 0.94, 0.88))
			draw_string(font, Vector2(name_rect.position.x, name_rect.position.y + name_rect.size.y * 0.82),
				_short_name(str(entry.get("name", ""))), HORIZONTAL_ALIGNMENT_CENTER,
				name_rect.size.x, font_size, Color(0.98, 0.98, 0.94))

			var selected := editing and (int(card["entry_index"]) == cursor or int(card["entry_index"]) == held)
			if bool(entry.get("pending_out", false)):
				draw_rect(rect.grow(1.0), Color(1.0, 0.35, 0.25, 0.95), false, 3.0)
			elif bool(entry.get("pending_in", false)):
				draw_rect(rect.grow(1.0), Color(0.35, 1.0, 0.45, 0.95), false, 3.0)
			elif selected:
				draw_rect(rect.grow(1.5), Color(1.0, 0.95, 0.35, 0.98), false, 3.0)
			elif bool(card.get("eligible", false)):
				draw_rect(rect.grow(0.5), Color(0.45, 1.0, 0.55, 0.95), false, 1.5)

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return
		for card in cards:
			if (card["rect"] as Rect2).has_point(mouse.position):
				card_clicked.emit(panel_index, int(card["entry_index"]))
				accept_event()
				return

	func _fatigue_color(percent: int) -> Color:
		if percent >= 90:
			return Color(0.35, 0.78, 1.0)
		if percent >= 70:
			return Color(0.31, 0.86, 0.35)
		if percent >= 50:
			return Color(0.92, 0.86, 0.24)
		if percent >= 30:
			return Color(0.94, 0.59, 0.18)
		return Color(0.88, 0.24, 0.22)

	func _rating_suffix(entry: Dictionary) -> String:
		var rating := int(entry.get("rating", -1))
		return "" if rating < 0 else " %d" % rating

	func _short_name(value: String) -> String:
		return value if value.length() <= 13 else value.substr(0, 12) + "."


var mode := "prematch" # "prematch" | "match" | "demo"
var runtime = null

var _lineups: Dictionary = {}
var _demo_teams: Dictionary = {}
var _team_names: Dictionary = {}
var _team_colors: Dictionary = {}
var _human_teams: Array = []
var _panels: Array = []
var _display_teams: Array = []

var _built := false
var _background: ColorRect
var _header: Label
var _hint: Label
var _status: Label
var _done_button: Button
var _panels_root: Control
var _status_until_ms := 0
var _move_ms := 0


func _ready() -> void:
	_build_chrome()


func setup_prematch(home_lineup: MatchLineup, away_lineup: MatchLineup, human_teams: Array = [0]) -> void:
	mode = "prematch"
	runtime = null
	_lineups = {0: home_lineup, 1: away_lineup}
	_human_teams = _unique_teams(human_teams)
	_resolve_teams()
	_rebuild()


func setup_match(runtime_node, human_teams: Array = [0]) -> void:
	mode = "match"
	runtime = runtime_node
	_human_teams = _unique_teams(human_teams)
	_resolve_teams()
	_rebuild()


func setup_demo(home: Dictionary, away: Dictionary, human_teams: Array = [0]) -> void:
	mode = "demo"
	runtime = null
	_demo_teams = {0: home, 1: away}
	_human_teams = _unique_teams(human_teams)
	_resolve_teams()
	_rebuild()


func is_open() -> bool:
	return _built and visible


func open_plan() -> void:
	if not _built:
		_build_chrome()
	visible = true
	move_to_front()
	_rebuild()
	_refresh_header()


func close_plan() -> void:
	visible = false
	_held_clear()


func handle_key(event: InputEventKey) -> bool:
	if not is_open() or not event.pressed or event.echo:
		return false
	var panel_index := _panel_for_keyboard()
	if panel_index < 0:
		return false
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_LEFT:
			direction = Vector2i(-1, 0)
		KEY_RIGHT:
			direction = Vector2i(1, 0)
		KEY_UP:
			direction = Vector2i(0, -1)
		KEY_DOWN:
			direction = Vector2i(0, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			return _handle_panel(panel_index, direction, true, false)
		KEY_ESCAPE:
			return _handle_panel(panel_index, direction, false, true)
		KEY_X:
			return _handle_panel(panel_index, direction, false, false, true)
		KEY_TAB:
			return _toggle_bench(panel_index)
		_:
			return false
	return _handle_panel(panel_index, direction, false, false)


func handle_joy_button(event: InputEventJoypadButton) -> bool:
	if not is_open() or not event.pressed:
		return false
	var panel_index := _panel_for_device(int(event.device))
	if panel_index < 0:
		return false
	match int(event.button_index):
		JOY_BUTTON_A:
			return _handle_panel(panel_index, Vector2i.ZERO, true, false)
		JOY_BUTTON_B:
			return _handle_panel(panel_index, Vector2i.ZERO, false, true)
		JOY_BUTTON_X:
			return _handle_panel(panel_index, Vector2i.ZERO, false, false, true)
		JOY_BUTTON_Y:
			return _toggle_bench(panel_index)
		JOY_BUTTON_DPAD_LEFT:
			return _handle_panel(panel_index, Vector2i(-1, 0), false, false)
		JOY_BUTTON_DPAD_RIGHT:
			return _handle_panel(panel_index, Vector2i(1, 0), false, false)
		JOY_BUTTON_DPAD_UP:
			return _handle_panel(panel_index, Vector2i(0, -1), false, false)
		JOY_BUTTON_DPAD_DOWN:
			return _handle_panel(panel_index, Vector2i(0, 1), false, false)
	return false


func handle_joy_motion(event: InputEventJoypadMotion) -> bool:
	if not is_open():
		return false
	var panel_index := _panel_for_device(int(event.device))
	if panel_index < 0:
		return false
	if absf(event.axis_value) <= 0.55:
		return false
	var now := Time.get_ticks_msec()
	if now - _move_ms < ROW_REPEAT_MS:
		return true
	var axis := int(event.axis)
	var direction := Vector2i.ZERO
	if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_RIGHT_X:
		direction = Vector2i(1 if event.axis_value > 0.0 else -1, 0)
	elif axis == JOY_AXIS_LEFT_Y or axis == JOY_AXIS_RIGHT_Y:
		direction = Vector2i(0, 1 if event.axis_value > 0.0 else -1)
	else:
		return false
	_move_ms = now
	return _handle_panel(panel_index, direction, false, false)


func handle_ui_action(action: String, device: int = -1) -> bool:
	# Shell screens route UiNav into the plan; the raw InputEvent handlers above
	# stay for the match pause menu and the existing tests.
	if not is_open():
		return false
	var panel_index := _panel_for_device(device) if device >= 0 else _panel_for_keyboard()
	if panel_index < 0:
		return false
	match action:
		"left":
			return _handle_panel(panel_index, Vector2i(-1, 0), false, false)
		"right":
			return _handle_panel(panel_index, Vector2i(1, 0), false, false)
		"up":
			return _handle_panel(panel_index, Vector2i(0, -1), false, false)
		"down":
			return _handle_panel(panel_index, Vector2i(0, 1), false, false)
		"confirm":
			return _handle_panel(panel_index, Vector2i.ZERO, true, false)
		"cancel":
			return _handle_panel(panel_index, Vector2i.ZERO, false, true)
		"cancel_sub":
			return _handle_panel(panel_index, Vector2i.ZERO, false, false, true)
		"bench":
			return _toggle_bench(panel_index)
	return false


func _build_chrome() -> void:
	if _built:
		return
	_built = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_background = ColorRect.new()
	_background.color = Color(0.015, 0.025, 0.02, 1.0)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_panels_root = Control.new()
	_panels_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panels_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panels_root)

	_header = _label("GAME PLAN", 28, Color(0.96, 0.93, 0.82))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _label("Back: sections, Enter: open    Esc: leave", 15, Color(0.72, 0.74, 0.68))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status = _label("", 17, Color(1.0, 0.78, 0.3))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_done_button = Button.new()
	_done_button.name = "GamePlanBack"
	_done_button.text = "Back"
	_done_button.add_theme_font_override("font", MENU_FONT)
	_done_button.add_theme_font_size_override("font_size", 18)
	_done_button.focus_mode = Control.FOCUS_ALL
	_done_button.pressed.connect(_on_done_pressed)
	add_child(_done_button)

	resized.connect(_layout_chrome)
	_layout_chrome()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _layout_chrome() -> void:
	if not _built:
		return
	var area := size
	if area.x < 2.0 or area.y < 2.0:
		return
	var title_size := maxi(12, int(area.y * 0.032))
	_header.add_theme_font_size_override("font_size", title_size)
	_header.position = Vector2(area.x * 0.18, area.y * 0.004)
	_header.size = Vector2(area.x * 0.64, area.y * 0.034)
	_hint.add_theme_font_size_override("font_size", maxi(10, int(area.y * 0.018)))
	_hint.position = Vector2(area.x * 0.18, area.y * 0.038)
	_hint.size = Vector2(area.x * 0.64, area.y * 0.024)
	_status.position = Vector2(area.x * 0.12, area.y * 0.968)
	_status.size = Vector2(area.x * 0.76, area.y * 0.03)
	_status.add_theme_font_size_override("font_size", maxi(10, int(area.y * 0.018)))
	_done_button.position = Vector2(area.x * 0.89, area.y * 0.012)
	_done_button.size = Vector2(area.x * 0.095, area.y * 0.046)
	_done_button.add_theme_font_size_override("font_size", maxi(11, int(area.y * 0.02)))
	_layout_panels()


func _resolve_teams() -> void:
	_team_names.clear()
	_team_colors.clear()
	for team_id in [0, 1]:
		_team_colors[team_id] = _shell_color(team_id)
	if mode == "demo":
		for team_id in [0, 1]:
			_team_names[team_id] = str(_demo_teams.get(team_id, {}).get("name", "TEAM %d" % (team_id + 1)))
			var color = _demo_teams.get(team_id, {}).get("color", null)
			if color is Color:
				_team_colors[team_id] = color
	else:
		for team_id in [0, 1]:
			var team: Dictionary = ShellState.home_team if team_id == 0 else ShellState.away_team
			_team_names[team_id] = str(team.get("name", "HOME" if team_id == 0 else "AWAY"))
	_display_teams = [0, 1]


func _shell_color(team_id: int) -> Color:
	var team: Dictionary = ShellState.home_team if team_id == 0 else ShellState.away_team
	var raw := str(team.get("color1", ""))
	if raw.is_empty():
		return DEFAULT_COLORS.get(team_id, Color(0.4, 0.4, 0.4))
	var parsed := Color.from_string(raw, DEFAULT_COLORS.get(team_id, Color(0.4, 0.4, 0.4)))
	return parsed


func _unique_teams(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var team_id := int(value)
		if team_id >= 0 and team_id <= 1 and not result.has(team_id):
			result.append(team_id)
	if result.is_empty():
		result = [0]
	result.sort()
	return result


func _is_editable(team_id: int) -> bool:
	return _human_teams.has(team_id)


func _rebuild() -> void:
	if not _built or not is_inside_tree():
		return
	_build_panels()
	_layout_panels()
	for index in _panels.size():
		_refresh_panel(_panels[index])
	_refresh_header()


func _build_panels() -> void:
	if not _panels.is_empty():
		return
	for team_id in _display_teams:
		var panel := _make_panel(team_id)
		_panels.append(panel)
	_layout_panels()


func _make_panel(team_id: int) -> Dictionary:
	var panel: Dictionary = {
		"team_id": team_id,
		"editable": _is_editable(team_id),
		"control": Control.new(),
		"pitch": GamePlanPitch.new(),
		"team_header": Label.new(),
		"bench_header": Label.new(),
		"bench_scroll": ScrollContainer.new(),
		"bench_box": VBoxContainer.new(),
		"scheme_scroll": ScrollContainer.new(),
		"scheme_box": VBoxContainer.new(),
		"scheme_buttons": [],
		"scheme_cursor": 0,
		"committed_scheme": -1,
		"role_scroll": ScrollContainer.new(),
		"role_box": VBoxContainer.new(),
		"role_buttons": [],
		"role_cursor": 0,
		"role_picking": false,
		"role_picking_index": 0,
		"pending": [],
		"bench_order": [],
		"section_bar": HBoxContainer.new(),
		"section_buttons": [],
		"section_caption": Label.new(),
		"entries": [],
		"cursor": -1,
		"held": -1,
		"bar_cursor": SECTION_POSITIONS,
		"bar_focused": true,
		"active_section": -1,
		"vote_ready": false,
		"focus_id": -1,
		"pitch_rect": Rect2(),
		"bench_rect": Rect2(),
		"section_center": 0.5,
	}
	var control: Control = panel["control"]
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panels_root.add_child(control)

	var team_header: Label = panel["team_header"]
	team_header.add_theme_font_override("font", MENU_FONT)
	team_header.add_theme_color_override("font_color", Color(0.9, 0.92, 0.85))
	team_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(team_header)

	var pitch: GamePlanPitch = panel["pitch"]
	pitch.panel_index = _panels.size()
	pitch.team_color = _team_colors.get(team_id, Color(0.3, 0.4, 0.8))
	pitch.mouse_filter = Control.MOUSE_FILTER_STOP
	pitch.card_clicked.connect(_on_card_clicked)
	control.add_child(pitch)

	var bench_header: Label = panel["bench_header"]
	bench_header.text = "Subs"
	bench_header.add_theme_font_override("font", MENU_FONT)
	bench_header.add_theme_color_override("font_color", Color(0.9, 0.92, 0.85))
	bench_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(bench_header)

	var scroll: ScrollContainer = panel["bench_scroll"]
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	control.add_child(scroll)
	var box: VBoxContainer = panel["bench_box"]
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	scroll.add_child(box)

	var scheme_scroll: ScrollContainer = panel["scheme_scroll"]
	scheme_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scheme_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	scheme_scroll.visible = false
	control.add_child(scheme_scroll)
	var scheme_box: VBoxContainer = panel["scheme_box"]
	scheme_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scheme_box.add_theme_constant_override("separation", 3)
	scheme_scroll.add_child(scheme_box)
	var scheme_buttons: Array = panel["scheme_buttons"]
	for scheme_index in TacticalSchemes.count():
		var scheme_button := Button.new()
		scheme_button.name = "Scheme%d" % scheme_index
		scheme_button.text = TacticalSchemes.scheme_name(scheme_index)
		scheme_button.toggle_mode = true
		scheme_button.focus_mode = Control.FOCUS_NONE
		scheme_button.mouse_filter = Control.MOUSE_FILTER_STOP
		scheme_button.pressed.connect(_on_scheme_pressed.bind(int(panel["team_id"]), scheme_index))
		scheme_box.add_child(scheme_button)
		scheme_buttons.append(scheme_button)

	var role_scroll: ScrollContainer = panel["role_scroll"]
	role_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	role_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	role_scroll.visible = false
	control.add_child(role_scroll)
	var role_box: VBoxContainer = panel["role_box"]
	role_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_box.add_theme_constant_override("separation", 3)
	role_scroll.add_child(role_box)
	var role_buttons: Array = panel["role_buttons"]
	for row_index in TEAM_ROLE_ROWS.size():
		var role_button := Button.new()
		role_button.name = "Role%d" % row_index
		role_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		role_button.toggle_mode = false
		role_button.focus_mode = Control.FOCUS_NONE
		role_button.mouse_filter = Control.MOUSE_FILTER_STOP
		role_button.pressed.connect(_on_role_pressed.bind(int(panel["team_id"]), row_index))
		role_box.add_child(role_button)
		role_buttons.append(role_button)

	var bar: HBoxContainer = panel["section_bar"]
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 4)
	control.add_child(bar)
	var buttons: Array = panel["section_buttons"]
	for section in SECTION_NAMES.size():
		var button := Button.new()
		button.name = "Section%d" % section
		button.text = String(SECTION_NAMES[section])
		button.add_theme_font_override("font", MENU_FONT)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_section_pressed.bind(int(panel["team_id"]), section))
		bar.add_child(button)
		buttons.append(button)

	var caption: Label = panel["section_caption"]
	caption.add_theme_font_override("font", MENU_FONT)
	caption.add_theme_color_override("font_color", Color(0.72, 0.74, 0.68))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(caption)
	return panel


func _layout_panels() -> void:
	if _panels.is_empty():
		return
	var area := size
	if area.x < 2.0 or area.y < 2.0:
		return
	var single := _human_teams.size() < 2
	var top := 0.10
	var height := 0.76
	for panel in _panels:
		var team_id := int(panel["team_id"])
		var pitch_rect := Rect2()
		var bench_rect := Rect2()
		var center := 0.5
		if single:
			var human: int = _human_teams[0] if not _human_teams.is_empty() else 0
			if team_id == human:
				if human == 0:
					pitch_rect = Rect2(0.015, top, 0.33, height)
					bench_rect = Rect2(0.355, top, 0.17, height)
					center = 0.23
				else:
					pitch_rect = Rect2(0.53, top, 0.29, height)
					bench_rect = Rect2(0.825, top, 0.17, height)
					center = 0.78
			else:
				pitch_rect = Rect2(0.015, top, 0.34, height) if team_id == 0 \
					else Rect2(0.61, top, 0.33, height)
				bench_rect = Rect2(0.0, 0.0, 0.0, 0.0)
				center = 0.18 if team_id == 0 else 0.775
		else:
			if team_id == 0:
				pitch_rect = Rect2(0.01, top, 0.25, height)
				bench_rect = Rect2(0.265, top, 0.145, height)
				center = 0.25
			else:
				pitch_rect = Rect2(0.52, top, 0.25, height)
				bench_rect = Rect2(0.775, top, 0.145, height)
				center = 0.75
		var control: Control = panel["control"]
		control.position = Vector2.ZERO
		control.size = area
		panel["pitch_rect"] = Rect2(Vector2(pitch_rect.position.x * area.x, pitch_rect.position.y * area.y),
			Vector2(pitch_rect.size.x * area.x, pitch_rect.size.y * area.y))
		panel["bench_rect"] = Rect2(Vector2(bench_rect.position.x * area.x, bench_rect.position.y * area.y),
			Vector2(bench_rect.size.x * area.x, bench_rect.size.y * area.y))
		panel["section_center"] = center

		var header: Label = panel["team_header"]
		header.position = Vector2(pitch_rect.position.x * area.x, (top - 0.035) * area.y)
		header.size = Vector2(pitch_rect.size.x * area.x, 0.03 * area.y)
		header.add_theme_font_size_override("font_size", maxi(11, int(area.y * 0.022)))
		header.text = str(_team_names.get(team_id, ""))

		var pitch: GamePlanPitch = panel["pitch"]
		pitch.position = (panel["pitch_rect"] as Rect2).position
		pitch.size = (panel["pitch_rect"] as Rect2).size
		# Window resizes change the card geometry: rebuild it in place, without
		# touching the cursor or the bench widgets.
		if not (panel["entries"] as Array).is_empty():
			pitch.set_cards(_build_cards(panel, panel["pitch_entries"]))

		var bench_header: Label = panel["bench_header"]
		bench_header.visible = bench_rect.size.x > 0.001
		bench_header.position = Vector2(bench_rect.position.x * area.x, (top - 0.035) * area.y)
		bench_header.size = Vector2(bench_rect.size.x * area.x, 0.03 * area.y)
		bench_header.add_theme_font_size_override("font_size", maxi(11, int(area.y * 0.022)))

		var scroll: ScrollContainer = panel["bench_scroll"]
		scroll.visible = bench_rect.size.x > 0.001
		scroll.position = (panel["bench_rect"] as Rect2).position
		scroll.size = (panel["bench_rect"] as Rect2).size
		for list_name in ["scheme_scroll", "role_scroll"]:
			var list: ScrollContainer = panel[list_name]
			list.position = (panel["bench_rect"] as Rect2).position
			list.size = (panel["bench_rect"] as Rect2).size
			if bench_rect.size.x <= 0.001:
				list.visible = false

		var bar: HBoxContainer = panel["section_bar"]
		var bar_w := minf(pitch_rect.size.x * area.x, 380.0)
		bar.position = Vector2(area.x * center - bar_w * 0.5, area.y * 0.875)
		bar.size = Vector2(bar_w, area.y * 0.045)
		bar.visible = bool(panel["editable"])
		var btn_w := int(bar_w / SECTION_NAMES.size()) - 4
		for button in panel["section_buttons"]:
			button.custom_minimum_size = Vector2(btn_w, bar.size.y)
			button.add_theme_font_size_override("font_size", maxi(10, int(area.y * 0.018)))

		var caption: Label = panel["section_caption"]
		caption.position = Vector2(area.x * center - bar_w * 0.5, area.y * (0.925 if panel["editable"] else 0.875))
		caption.size = Vector2(bar_w, area.y * 0.028)
		caption.add_theme_font_size_override("font_size", maxi(9, int(area.y * 0.016)))
func _refresh_header() -> void:
	if not _built:
		return
	var votes := 0
	for panel in _panels:
		if panel["vote_ready"]:
			votes += 1
	if _human_teams.size() >= 2:
		_header.text = "GAME PLAN" if votes == 0 else "READY TO LEAVE %d/%d" % [votes, _panels.size()]
	else:
		_header.text = "GAME PLAN"
	_hint.text = DEFAULT_HINT


func _refresh_panel(panel: Dictionary) -> void:
	var team_id := int(panel["team_id"])
	var old_focus := int(panel["focus_id"])
	if panel["cursor"] >= 0 and panel["cursor"] < (panel["entries"] as Array).size():
		old_focus = int((panel["entries"] as Array)[panel["cursor"]].get("id", -1))
	var old_held := -1
	if panel["held"] >= 0 and panel["held"] < (panel["entries"] as Array).size():
		old_held = int((panel["entries"] as Array)[panel["held"]].get("id", -1))

	var team_data := _team_data(team_id)
	var entries := _entries_for(team_data)
	panel["entries"] = entries
	panel["team_data"] = team_data
	panel["team_name"] = str(team_data.get("name", _team_names.get(team_id, "")))
	panel["editable"] = _is_editable(team_id)
	panel["pending"] = _pending_for_team(team_id)

	var header: Label = panel["team_header"]
	header.text = String(panel["team_name"])
	if mode == "match":
		header.text += "    subs %d/%d" % [
			int(team_data.get("substitutions", 0)),
			int(team_data.get("max_substitutions", 5)),
		]

	var pitch_entries: Array = []
	var bench_entries: Array = []
	for index in entries.size():
		if bool(entries[index].get("active", false)):
			pitch_entries.append(index)
		else:
			bench_entries.append(index)
	if not (panel["bench_order"] as Array).is_empty():
		var rank: Dictionary = {}
		var order: Array = panel["bench_order"]
		for position in order.size():
			rank[int(order[position])] = position
		bench_entries.sort_custom(func(a: int, b: int) -> bool:
			return int(rank.get(int(entries[a].get("id", -1)), 10000 + a)) \
				< int(rank.get(int(entries[b].get("id", -1)), 10000 + b)))
	panel["pitch_entries"] = pitch_entries
	panel["bench_entries"] = bench_entries

	panel["cursor"] = _find_by_id(entries, old_focus)
	if panel["cursor"] < 0 and not pitch_entries.is_empty():
		panel["cursor"] = int(pitch_entries[0])
	panel["held"] = _find_by_id(entries, old_held)
	panel["focus_id"] = -1

	var section := int(panel["active_section"])
	var detected := _detect_committed_scheme(entries)
	if detected >= 0:
		panel["committed_scheme"] = detected
	var preview: Dictionary = {}
	var tactics_preview := section == SECTION_TACTICS and not bool(panel["bar_focused"]) \
		and bool(panel["editable"])
	if tactics_preview:
		preview = _scheme_preview(panel, pitch_entries)

	var pitch: GamePlanPitch = panel["pitch"]
	pitch.team_color = _team_colors.get(team_id, Color(0.3, 0.4, 0.8))
	pitch.set_cards(_build_cards(panel, pitch_entries, preview))
	var editing: bool = section == SECTION_POSITIONS \
		or (section == SECTION_ROLES and bool(panel["role_picking"]))
	pitch.set_markers(int(panel["cursor"]), int(panel["held"]), editing)

	var bench_scroll: ScrollContainer = panel["bench_scroll"]
	var scheme_scroll: ScrollContainer = panel["scheme_scroll"]
	var role_scroll: ScrollContainer = panel["role_scroll"]
	var bench_visible := section == -1 or section == SECTION_POSITIONS
	bench_scroll.visible = bench_visible and (panel["bench_rect"] as Rect2).size.x > 0.001
	scheme_scroll.visible = section == SECTION_TACTICS \
		and (panel["bench_rect"] as Rect2).size.x > 0.001
	role_scroll.visible = section == SECTION_ROLES \
		and not bool(panel["role_picking"]) \
		and (panel["bench_rect"] as Rect2).size.x > 0.001
	var bench_header: Label = panel["bench_header"]
	bench_header.visible = (panel["bench_rect"] as Rect2).size.x > 0.001
	if section == SECTION_TACTICS:
		bench_header.text = "Scheme"
	elif section == SECTION_ROLES:
		bench_header.text = "Roles"
	else:
		bench_header.text = "Subs"

	if bench_visible:
		_rebuild_bench(panel, bench_entries)
	_refresh_scheme_list(panel)
	_refresh_role_list(panel)
	_refresh_section_bar(panel)
	_update_status()


func _detect_committed_scheme(entries: Array) -> int:
	var formation: Array = []
	for entry in entries:
		if not bool(entry.get("active", false)):
			continue
		formation.append({
			"role": str(entry.get("role", "CM")),
			"position": entry.get("position", Vector2.ZERO),
		})
	if formation.size() != Formation.SLOT_COUNT:
		return -1
	return TacticalSchemes.match_scheme(formation)


func _scheme_preview(panel: Dictionary, pitch_entries: Array) -> Dictionary:
	if pitch_entries.is_empty():
		return {}
	var entries: Array = panel["entries"]
	var scheme_cursor := int(panel["scheme_cursor"])
	var candidates: Array = []
	for index in pitch_entries:
		var entry: Dictionary = entries[index]
		candidates.append({
			"slot": index,
			"role": str(entry.get("role", "CM")),
			"position": entry.get("position", Vector2.ZERO),
		})
	var assignment := TacticalSchemes.assign(candidates, scheme_cursor)
	var preview: Dictionary = {}
	for offset in mini(assignment.size(), candidates.size()):
		var index := int(candidates[offset]["slot"])
		preview[index] = assignment[offset]
	return preview
func _find_by_id(entries: Array, player_id: int) -> int:
	if player_id < 0:
		return -1
	for index in entries.size():
		if int(entries[index].get("id", -1)) == player_id:
			return index
	return -1


func _build_cards(panel: Dictionary, pitch_entries: Array, preview: Dictionary = {}) -> Array:
	var pitch_rect: Rect2 = panel["pitch_rect"]
	var entries: Array = panel["entries"]
	if pitch_rect.size.x <= 2.0 or pitch_rect.size.y <= 2.0:
		return []
	var card_w := clampf(pitch_rect.size.x * 0.105, CARD_MIN_W, CARD_MAX_W)
	var photo_h := card_w * PHOTO_ASPECT
	var badge_h := maxf(10.0, card_w * 0.26)
	var name_h := maxf(11.0, card_w * 0.30)
	var bar_h := clampf(card_w * 0.08, 3.0, 7.0)
	var gap := 2.0
	var card_h := photo_h + badge_h + name_h + bar_h + gap * 3.0
	var held_index := int(panel["held"])
	var can_pick := int(panel["active_section"]) == SECTION_POSITIONS and held_index >= 0
	var cards: Array = []
	for index in pitch_entries:
		var entry: Dictionary = entries[index]
		var display: Dictionary = preview.get(index, {})
		var role := str(display.get("role", entry.get("role", "CM")))
		var position: Vector2 = display.get("database_position", entry.get("position", Vector2.ZERO))
		var shown := position
		if role != "GK":
			shown.x = shown.x * 0.8 + 0.1
			shown.y = clampf(shown.y, -0.75, 0.75)
		var depth := shown.x * 0.5 + 0.5
		var side := shown.y * 0.5 + 0.5
		var anchor := Vector2((1.0 - side) * pitch_rect.size.x, (1.0 - depth) * pitch_rect.size.y)
		var x := clampf(anchor.x - card_w * 0.5, 0.0, pitch_rect.size.x - card_w)
		var y := clampf(anchor.y - photo_h * 0.5, 0.0, pitch_rect.size.y - card_h)
		var rect := Rect2(Vector2(x, y), Vector2(card_w, card_h))
		var photo := Rect2(Vector2(x, y), Vector2(card_w, photo_h))
		var role_rect := Rect2(Vector2(x, y + photo_h + gap), Vector2(card_w, badge_h))
		var name_rect := Rect2(Vector2(x, role_rect.end.y + gap), Vector2(card_w, name_h))
		var bar_rect := Rect2(Vector2(x, name_rect.end.y + gap), Vector2(card_w, bar_h))
		var eligible: bool = can_pick and not bool(entry.get("left_pitch", false)) \
			and index != held_index
		cards.append({
			"entry_index": index,
			"entry": entry,
			"display_role": role,
			"eligible": eligible,
			"rect": rect,
			"photo": photo,
			"role": role_rect,
			"name": name_rect,
			"bar": bar_rect,
		})
	return cards
func _rebuild_bench(panel: Dictionary, bench_entries: Array) -> void:
	var box: VBoxContainer = panel["bench_box"]
	for child in box.get_children():
		child.queue_free()
	var area := size
	var row_h := clampf(area.y * 0.038, 17.0, 34.0)
	var font_size := maxi(9, int(row_h * 0.48))
	var entries: Array = panel["entries"]
	var held_index := int(panel["held"])
	var can_pick := int(panel["active_section"]) == SECTION_POSITIONS and held_index >= 0
	for index in bench_entries:
		var entry: Dictionary = entries[index]
		var eligible: bool = can_pick and not bool(entry.get("left_pitch", false)) \
			and index != held_index
		var button := Button.new()
		button.name = "Bench%d" % index
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var prefix := "→ " if eligible else ""
		button.text = "%s%s  %s%s" % [
			prefix,
			str(entry.get("role", "")),
			_short_name(str(entry.get("name", ""))),
			_entry_suffix(entry),
		]
		button.custom_minimum_size = Vector2(0, row_h)
		button.add_theme_font_override("font", MENU_FONT)
		button.add_theme_font_size_override("font_size", font_size)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.disabled = not bool(panel["editable"]) or bool(entry.get("left_pitch", false))
		button.pressed.connect(_on_bench_pressed.bind(int(panel["team_id"]), index))
		box.add_child(button)
		if int(panel["active_section"]) == SECTION_POSITIONS and index == int(panel["cursor"]):
			button.modulate = Color(1.0, 0.90, 0.40)
		elif eligible:
			button.modulate = Color(0.70, 1.0, 0.70)
		# Keep the cursor's bench row visible when navigating with the pad.
		if index == int(panel["cursor"]):
			var scroll: ScrollContainer = panel["bench_scroll"]
			scroll.call_deferred("ensure_control_visible", button)

func _refresh_scheme_list(panel: Dictionary) -> void:
	var buttons: Array = panel["scheme_buttons"]
	if buttons.is_empty():
		return
	var area := size
	var row_h := clampf(area.y * 0.045, 22.0, 42.0)
	var font_size := maxi(10, int(row_h * 0.46))
	var committed := int(panel["committed_scheme"])
	var cursor := int(panel["scheme_cursor"])
	var focused := int(panel["active_section"]) == SECTION_TACTICS \
		and not bool(panel["bar_focused"])
	for index in buttons.size():
		var button := buttons[index] as Button
		button.custom_minimum_size = Vector2(0, row_h)
		button.add_theme_font_size_override("font_size", font_size)
		button.set_pressed_no_signal(index == committed)
		button.text = "%s%s" % [
			"→ " if focused and index == cursor else "",
			TacticalSchemes.scheme_name(index),
		]
		if focused and index == cursor:
			button.modulate = Color(1.0, 0.90, 0.40)
		elif index == committed:
			button.modulate = Color(0.75, 1.0, 0.75)
		else:
			button.modulate = Color(0.78, 0.80, 0.76)


func _refresh_role_list(panel: Dictionary) -> void:
	var buttons: Array = panel["role_buttons"]
	if buttons.is_empty():
		return
	var area := size
	var row_h := clampf(area.y * 0.045, 22.0, 42.0)
	var font_size := maxi(9, int(row_h * 0.40))
	var cursor := int(panel["role_cursor"])
	var focused := int(panel["active_section"]) == SECTION_ROLES \
		and not bool(panel["bar_focused"]) and not bool(panel["role_picking"])
	for row_index in buttons.size():
		var button := buttons[row_index] as Button
		var role := int(TEAM_ROLE_ROWS[row_index]["role"])
		button.custom_minimum_size = Vector2(0, row_h)
		button.add_theme_font_size_override("font_size", font_size)
		button.text = "%s%s   %s" % [
			"→ " if focused and row_index == cursor else "",
			str(TEAM_ROLE_ROWS[row_index]["name"]),
			_role_player_name(panel, role),
		]
		if focused and row_index == cursor:
			button.modulate = Color(1.0, 0.90, 0.40)
		else:
			button.modulate = Color(0.80, 0.82, 0.78)


func _role_player_name(panel: Dictionary, role: int) -> String:
	var team_id := int(panel["team_id"])
	var team_data: Dictionary = panel.get("team_data", {})
	if mode == "match":
		for entry in team_data.get("roles", []):
			if int(entry.get("role", -1)) == role:
				var name := str(entry.get("name", ""))
				return name if not name.is_empty() else "—"
	elif mode == "demo":
		var roles: Array = team_data.get("roles", [])
		if role >= 0 and role < roles.size():
			var slot := int(roles[role])
			var players: Array = team_data.get("players", [])
			if slot >= 0 and slot < players.size():
				return str(players[slot].get("name", "—"))
	else:
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup != null:
			var slot := lineup.role_slot(role)
			if slot >= 0 and slot < lineup.lineup.size():
				var player := lineup.player_by_id(lineup.lineup[slot])
				if not player.is_empty():
					return str(player.get("lastname", player.get("name", "—")))
	return "—"


func _role_player_id(panel: Dictionary, role: int) -> int:
	var team_id := int(panel["team_id"])
	var team_data: Dictionary = panel.get("team_data", {})
	if mode == "match":
		for entry in team_data.get("roles", []):
			if int(entry.get("role", -1)) == role:
				return int(entry.get("player_id", -1))
	elif mode == "demo":
		var roles: Array = team_data.get("roles", [])
		if role >= 0 and role < roles.size():
			var slot := int(roles[role])
			var players: Array = team_data.get("players", [])
			if slot >= 0 and slot < players.size():
				return int(players[slot].get("id", -1))
	else:
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup != null:
			var slot := lineup.role_slot(role)
			if slot >= 0 and slot < lineup.lineup.size():
				return int(lineup.lineup[slot])
	return -1


func _pending_for_team(team_id: int) -> Array:
	var result: Array = []
	if mode != "match" or runtime == null:
		return result
	if runtime.has_method("get_pending_substitutions"):
		for pair in runtime.get_pending_substitutions():
			if typeof(pair) == TYPE_DICTIONARY and int(pair.get("team", -1)) == team_id:
				result.append(pair)
	return result


func _toggle_bench(panel_index: int) -> bool:
	if panel_index < 0 or panel_index >= _panels.size():
		return false
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or int(panel["active_section"]) != SECTION_POSITIONS:
		return false
	var entries: Array = panel["entries"]
	if entries.is_empty():
		return false
	var cursor := int(panel["cursor"])
	var want_bench := cursor >= 0 and cursor < entries.size() \
		and bool(entries[cursor].get("active", false))
	var next := -1
	for index in entries.size():
		if bool(entries[index].get("left_pitch", false)):
			continue
		if bool(entries[index].get("active", false)) != want_bench:
			next = index
			break
	if next < 0:
		set_status("No %s available" % ("substitutes" if want_bench else "starters"))
		return true
	panel["cursor"] = next
	panel["bar_focused"] = false
	_refresh_panel(panel)
	set_status("On the %s" % ("bench" if want_bench else "pitch"), 2000)
	return true


func _cancel_pending(panel: Dictionary) -> bool:
	if mode != "match" or runtime == null:
		return false
	var entries: Array = panel["entries"]
	var cursor := int(panel["cursor"])
	if cursor < 0 or cursor >= entries.size():
		return false
	var entry: Dictionary = entries[cursor]
	var pair: Dictionary = {}
	for candidate in panel["pending"]:
		if int(candidate.get("out_id", -2)) == int(entry.get("id", -1)) \
				or int(candidate.get("in_id", -2)) == int(entry.get("id", -1)):
			pair = candidate
			break
	if pair.is_empty():
		set_status("No queued substitution for this player", 2500)
		return true
	if runtime.cancel_substitution(int(panel["team_id"]), int(pair.get("out_slot", -1))):
		set_status("Substitution cancelled", 3000)
	else:
		set_status("Could not cancel the substitution")
	_refresh_panel(panel)
	return true


func _on_scheme_pressed(team_id: int, scheme_index: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]):
		return
	panel["scheme_cursor"] = scheme_index
	panel["bar_focused"] = false
	_commit_scheme(panel)


func _move_scheme_cursor(panel: Dictionary, delta: int) -> void:
	var count := TacticalSchemes.count()
	if count <= 0:
		return
	var next := clampi(int(panel["scheme_cursor"]) + delta, 0, count - 1)
	if next == int(panel["scheme_cursor"]):
		return
	panel["scheme_cursor"] = next
	_refresh_panel(panel)


func _commit_scheme(panel: Dictionary) -> void:
	var team_id := int(panel["team_id"])
	var scheme_index := int(panel["scheme_cursor"])
	if scheme_index < 0 or scheme_index >= TacticalSchemes.count():
		return
	if mode == "prematch":
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup == null or not lineup.apply_scheme(scheme_index):
			set_status("Could not apply the scheme")
			return
		lineup_changed.emit()
	elif mode == "match":
		if runtime == null:
			return
		runtime.apply_tactical_scheme(team_id, scheme_index)
	else:
		_apply_demo_scheme(team_id, scheme_index)
	panel["committed_scheme"] = scheme_index
	set_status("%s applied" % TacticalSchemes.scheme_name(scheme_index), 3000)
	_refresh_panel(panel)


func _apply_demo_scheme(team_id: int, scheme_index: int) -> void:
	var team_data: Dictionary = _demo_teams.get(team_id, {})
	var players: Array = team_data.get("players", [])
	var active: Array = []
	for index in players.size():
		if bool(players[index].get("active", false)):
			active.append(index)
	var candidates: Array = []
	for index in active:
		candidates.append({
			"slot": index,
			"role": str(players[index].get("role", "CM")),
			"position": players[index].get("position", Vector2.ZERO),
		})
	var assignment := TacticalSchemes.assign(candidates, scheme_index)
	for offset in mini(assignment.size(), candidates.size()):
		var index := int(candidates[offset]["slot"])
		players[index]["role"] = str(assignment[offset]["role"])
		players[index]["position"] = assignment[offset]["database_position"]


func _on_role_pressed(team_id: int, row_index: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or row_index < 0 or row_index >= TEAM_ROLE_ROWS.size():
		return
	panel["role_cursor"] = row_index
	_start_role_picking(panel)


func _move_role_cursor(panel: Dictionary, delta: int) -> void:
	var next := clampi(int(panel["role_cursor"]) + delta, 0, TEAM_ROLE_ROWS.size() - 1)
	if next == int(panel["role_cursor"]):
		return
	panel["role_cursor"] = next
	_refresh_panel(panel)


func _start_role_picking(panel: Dictionary) -> void:
	panel["role_picking"] = true
	panel["role_picking_index"] = int(panel["role_cursor"])
	panel["bar_focused"] = false
	var role := int(TEAM_ROLE_ROWS[int(panel["role_picking_index"])]["role"])
	var player_id := _role_player_id(panel, role)
	var target := _find_by_id(panel["entries"], player_id)
	if target < 0:
		var pitch_entries: Array = panel["pitch_entries"]
		target = int(pitch_entries[0]) if not pitch_entries.is_empty() else -1
	panel["cursor"] = target
	_refresh_panel(panel)
	set_status("Pick a player for %s — A: assign, B: cancel" % TEAM_ROLE_ROWS[int(panel["role_cursor"])]["name"])


func _stop_role_picking(panel: Dictionary) -> void:
	panel["role_picking"] = false
	_refresh_panel(panel)


func _confirm_role_pick(panel: Dictionary) -> void:
	if not bool(panel["role_picking"]):
		return
	var entries: Array = panel["entries"]
	var cursor := int(panel["cursor"])
	if cursor < 0 or cursor >= entries.size() or not bool(entries[cursor].get("active", false)):
		set_status("Pick a player on the pitch")
		return
	var role := int(TEAM_ROLE_ROWS[int(panel["role_picking_index"])]["role"])
	var entry: Dictionary = entries[cursor]
	var team_id := int(panel["team_id"])
	if mode == "prematch":
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup == null:
			return
		var slot := lineup.slot_for_player(int(entry.get("id", -1)))
		if slot < 0 or not lineup.set_role(role, slot):
			set_status("Could not assign the role")
			return
		lineup_changed.emit()
	elif mode == "match":
		if runtime == null or not runtime.set_team_role(team_id, role, int(entry.get("slot", -1))):
			set_status("Could not assign the role")
			return
	else:
		var team_data: Dictionary = _demo_teams.get(team_id, {})
		var roles: Array = team_data.get("roles", [])
		if role >= 0 and role < roles.size():
			roles[role] = int(entry.get("slot", 0))
	panel["role_picking"] = false
	set_status("%s: %s" % [TEAM_ROLE_ROWS[int(panel["role_picking_index"])]["name"],
		str(entry.get("name", ""))], 3500)
	_refresh_panel(panel)

func _refresh_section_bar(panel: Dictionary) -> void:
	var active := int(panel["active_section"])
	for section in (panel["section_buttons"] as Array).size():
		var button := (panel["section_buttons"] as Array)[section] as Button
		button.set_pressed_no_signal(section == active)
		if panel["bar_focused"] and section == int(panel["bar_cursor"]):
			button.modulate = Color(1.0, 0.88, 0.35)
		elif section == active:
			button.modulate = Color(1.0, 1.0, 1.0)
		else:
			button.modulate = Color(0.72, 0.74, 0.70)
	var caption: Label = panel["section_caption"]
	if panel["bar_focused"]:
		caption.text = "%s: %s" % [
			SECTION_NAMES[int(panel["bar_cursor"])],
			SECTION_DESCRIPTIONS[int(panel["bar_cursor"])],
		]
	elif active == SECTION_TACTICS:
		caption.text = "Scheme: %s — A: apply, B: back" \
			% TacticalSchemes.scheme_name(int(panel["scheme_cursor"]))
	elif active == SECTION_ROLES:
		if bool(panel["role_picking"]):
			caption.text = "Pick for %s — A: assign, B: cancel" \
				% TEAM_ROLE_ROWS[int(panel["role_picking_index"])]["name"]
		else:
			caption.text = "Roles: A: pick player, B: back"
	elif active >= 0:
		caption.text = String(SECTION_DESCRIPTIONS[active])
	else:
		caption.text = ""
	# The cursor row on the bar is shown by the section toggle state; the
	# keyboard device still owns the panel while the bar is focused.
	if not panel["editable"]:
		caption.text = "Read-only (opponent)"


func _update_status() -> void:
	if _status == null:
		return
	if Time.get_ticks_msec() > _status_until_ms and not _status.text.is_empty():
		_status.text = ""


func set_status(text: String, duration_ms: int = 4000) -> void:
	if _status == null:
		return
	_status.text = text
	_status_until_ms = Time.get_ticks_msec() + duration_ms


func _entry_suffix(entry: Dictionary) -> String:
	if bool(entry.get("left_pitch", false)):
		return "  (out)"
	if bool(entry.get("pending_out", false)):
		return "  -"
	if bool(entry.get("pending_in", false)):
		return "  +"
	return ""


func _short_name(value: String) -> String:
	if value.length() <= 15:
		return value
	return value.substr(0, 14) + "."


func _shell_lineup_team_data(team_id: int) -> Dictionary:
	var lineup: MatchLineup = _lineups.get(team_id)
	if lineup == null:
		return {"name": _team_names.get(team_id, ""), "players": []}
	var players: Array = []
	var formation: Array = lineup.formation
	for slot in mini(Formation.SLOT_COUNT, lineup.lineup.size()):
		var player_id := int(lineup.lineup[slot])
		var player := lineup.player_by_id(player_id)
		if player.is_empty():
			continue
		var role := "CM"
		var position := Vector2.ZERO
		if slot < formation.size():
			role = str(formation[slot].get("role", "CM"))
			position = formation[slot].get("database_position",
				formation[slot].get("position", Vector2.ZERO))
		players.append(_entry_from_player(player_id, slot, player, role, position, true))
	for index in lineup.bench.size():
		var player_id := int(lineup.bench[index])
		var player := lineup.player_by_id(player_id)
		if player.is_empty():
			continue
		players.append(_entry_from_player(player_id, index, player, _natural_role(player),
			Vector2.ZERO, false))
	return {"name": lineup.team_name, "players": players}


func _entry_from_player(player_id: int, slot: int, player: Dictionary, role: String,
		position: Vector2, active: bool) -> Dictionary:
	var rating := -1
	var base_stat := float(player.get("base_stat", 0.0))
	if base_stat > 0.0:
		rating = int(round(base_stat * 100.0))
	else:
		var average := float(player.get("average", 0.0))
		if average > 0.0:
			rating = int(round(average * 100.0))
	return {
		"id": player_id,
		"slot": slot,
		"name": str(player.get("lastname", player.get("name", "?"))),
		"role": role,
		"position": position,
		"active": active,
		"left_pitch": false,
		"pending_out": false,
		"pending_in": false,
		"rating": rating,
		"fatigue": 100,
	}


func _natural_role(player: Dictionary) -> String:
	var roles := str(player.get("role", "CM")).to_upper().replace(",", " ")
	for token in roles.split(" ", false):
		if Formation.VALID_ROLES.has(token):
			return token
	return "CM"


func _team_data(team_id: int) -> Dictionary:
	if mode == "match" and runtime != null:
		var data: Dictionary = runtime.get_squad(team_id)
		if data.is_empty():
			return {"name": _team_names.get(team_id, ""), "players": []}
		return data
	if mode == "demo":
		return _demo_teams.get(team_id, {"name": _team_names.get(team_id, ""), "players": []})
	return _shell_lineup_team_data(team_id)


func _entries_for(team_data: Dictionary) -> Array:
	var source: Array = team_data.get("players", [])
	var active: Array = []
	var bench: Array = []
	var left: Array = []
	for raw in source:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (raw as Dictionary).duplicate(true)
		if bool(entry.get("active", false)):
			active.append(entry)
		elif bool(entry.get("left_pitch", false)):
			left.append(entry)
		else:
			bench.append(entry)
	var result: Array = []
	result.append_array(active)
	result.append_array(bench)
	result.append_array(left)
	return result


func _panel_for_keyboard() -> int:
	for panel in _panels:
		var team_id := int(panel["team_id"])
		for controller in ShellState.controllers:
			if not (controller is Dictionary):
				continue
			if str(controller.get("kind", "keyboard")) == "keyboard" \
					and _side_team(controller) == team_id:
				return _panels.find(panel)
	if _human_teams.size() == 1:
		return _panel_index_for_team(int(_human_teams[0]))
	return -1


func _panel_for_device(device: int) -> int:
	for panel in _panels:
		var team_id := int(panel["team_id"])
		for controller in ShellState.controllers:
			if not (controller is Dictionary):
				continue
			if str(controller.get("kind", "")) == "gamepad" \
					and int(controller.get("device", -1)) == device \
					and _side_team(controller) == team_id:
				return _panels.find(panel)
	if _human_teams.size() == 1:
		return _panel_index_for_team(int(_human_teams[0]))
	return -1


func _side_team(controller: Dictionary) -> int:
	return 1 if str(controller.get("side", "home")) == "away" else 0


func _handle_panel(panel_index: int, direction: Vector2i, accept: bool, back: bool,
		cancel: bool = false) -> bool:
	if panel_index < 0 or panel_index >= _panels.size():
		return false
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]):
		return false
	if panel["vote_ready"] and (direction != Vector2i.ZERO or accept or back or cancel):
		panel["vote_ready"] = false
		_refresh_header()
		return true

	if panel["bar_focused"]:
		if back:
			_leave(panel)
			return true
		if accept:
			_set_section(panel, int(panel["bar_cursor"]))
			return true
		if direction.x != 0:
			panel["bar_cursor"] = wrapi(int(panel["bar_cursor"]) + direction.x, 0, SECTION_NAMES.size())
			_refresh_section_bar(panel)
			return true
		if direction.y > 0 and int(panel["active_section"]) >= 0:
			panel["bar_focused"] = false
			_refresh_panel(panel)
			return true
		return false

	var section := int(panel["active_section"])
	if section == SECTION_TACTICS:
		if back:
			panel["bar_focused"] = true
			_refresh_panel(panel)
			return true
		if accept:
			_commit_scheme(panel)
			return true
		if direction.y != 0:
			_move_scheme_cursor(panel, direction.y)
			return true
		return true

	if section == SECTION_ROLES:
		if bool(panel["role_picking"]):
			if back:
				_stop_role_picking(panel)
				return true
			if accept:
				_confirm_role_pick(panel)
				return true
			if direction != Vector2i.ZERO:
				var next := _find_next_entry(panel, int(panel["cursor"]), direction, true)
				if next >= 0:
					panel["cursor"] = next
					_refresh_panel(panel)
				return true
			return false
		if back:
			panel["bar_focused"] = true
			_refresh_panel(panel)
			return true
		if accept:
			_start_role_picking(panel)
			return true
		if direction.y != 0:
			_move_role_cursor(panel, direction.y)
			return true
		return true

	if section != SECTION_POSITIONS:
		if back or accept or direction.y < 0:
			panel["bar_focused"] = true
			_refresh_panel(panel)
			return true
		return false

	if cancel:
		return _cancel_pending(panel)

	if back:
		if int(panel["held"]) != -1:
			panel["held"] = -1
			set_status("Selection cleared", 1500)
		else:
			panel["bar_focused"] = true
		_refresh_panel(panel)
		return true

	if accept:
		if int(panel["cursor"]) >= 0:
			_press_entry(panel_index, int(panel["cursor"]))
		return true

	if direction != Vector2i.ZERO:
		var next := _find_next_entry(panel, int(panel["cursor"]), direction)
		if next >= 0:
			panel["cursor"] = next
			panel["focus_id"] = -1
			_refresh_panel(panel)
			return true
		if direction.y > 0:
			panel["bar_focused"] = true
			_refresh_panel(panel)
			return true
	return false

func _leave(panel: Dictionary) -> void:
	if _human_teams.size() >= 2:
		panel["vote_ready"] = true
		_refresh_header()
		var votes := 0
		for candidate in _panels:
			if candidate["vote_ready"]:
				votes += 1
		if votes >= _panels.size():
			close_requested.emit()
		return
	close_requested.emit()


func _set_section(panel: Dictionary, section: int) -> void:
	panel["active_section"] = section
	panel["bar_cursor"] = section
	panel["bar_focused"] = false
	panel["held"] = -1
	panel["role_picking"] = false
	if section == SECTION_TACTICS:
		var committed := int(panel["committed_scheme"])
		panel["scheme_cursor"] = committed if committed >= 0 else 0
		set_status("Choose a scheme — A: apply, B: back", 4000)
	elif section == SECTION_ROLES:
		panel["role_cursor"] = clampi(int(panel["role_cursor"]), 0, TEAM_ROLE_ROWS.size() - 1)
		set_status("Choose a role — A: pick player, B: back", 4000)
	elif section == 3:
		set_status("Player size: not ported yet", 2500)
	_refresh_panel(panel)


func _on_section_pressed(team_id: int, section: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not panel["editable"]:
		return
	_set_section(panel, section)


func _on_card_clicked(panel_index: int, entry_index: int) -> void:
	if panel_index < 0 or panel_index >= _panels.size():
		return
	var panel: Dictionary = _panels[panel_index]
	if not panel["editable"] or int(panel["active_section"]) != SECTION_POSITIONS:
		return
	panel["cursor"] = entry_index
	panel["bar_focused"] = false
	_press_entry(panel_index, entry_index)


func _on_bench_pressed(team_id: int, entry_index: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not panel["editable"] or int(panel["active_section"]) != SECTION_POSITIONS:
		return
	panel["cursor"] = entry_index
	panel["bar_focused"] = false
	_press_entry(panel_index, entry_index)


func _panel_index_for_team(team_id: int) -> int:
	for index in _panels.size():
		if int(_panels[index]["team_id"]) == team_id:
			return index
	return -1


func _press_entry(panel_index: int, entry_index: int) -> void:
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]):
		return
	var entries: Array = panel["entries"]
	if entry_index < 0 or entry_index >= entries.size():
		return
	var entry: Dictionary = entries[entry_index]
	if bool(entry.get("left_pitch", false)):
		set_status("%s has already left the pitch" % str(entry.get("name", "")))
		return
	if int(panel["held"]) == -1:
		panel["held"] = entry_index
		_refresh_panel(panel)
		set_status("Selected %s - choose another player (Y/Tab: bench/pitch) - B: cancel" \
			% str(entry.get("name", "")), 60000)
		return
	if int(panel["held"]) == entry_index:
		panel["held"] = -1
		_refresh_panel(panel)
		set_status("Selection cleared", 1500)
		return
	var first_index := int(panel["held"])
	var first: Dictionary = entries[first_index]
	panel["held"] = -1
	if mode == "match":
		if bool(first.get("active", false)) and bool(entry.get("active", false)):
			_match_position_swap(panel, first, entry)
		elif not bool(first.get("active", false)) and not bool(entry.get("active", false)):
			_swap_bench_order(panel, first, entry)
		else:
			_match_swap(panel, first, entry)
	else:
		_prematch_swap(panel, first, entry)



func _match_swap(panel: Dictionary, first: Dictionary, second: Dictionary) -> void:
	if runtime == null:
		return
	var out: Dictionary = first if bool(first.get("active", false)) else second
	var incoming: Dictionary = second if bool(first.get("active", false)) else first
	var team_id := int(panel["team_id"])
	if _is_pending_pair(panel, out, incoming):
		if runtime.cancel_substitution(team_id, int(out.get("slot", -1))):
			set_status("Substitution cancelled: %s stays" % str(out.get("name", "")))
		else:
			set_status("Could not cancel the substitution")
		panel["focus_id"] = int(out.get("id", -1))
		_refresh_panel(panel)
		return
	if runtime.queue_substitution(team_id, int(out.get("id", -1)), int(incoming.get("id", -1))):
		set_status("QUEUED: %s off, %s on - next restart (X: cancel)" % [
			str(out.get("name", "")), str(incoming.get("name", ""))], 60000)
		panel["focus_id"] = int(incoming.get("id", -1))
	else:
		set_status("Substitution refused: limit reached or player unavailable")
	_refresh_panel(panel)


func _match_position_swap(panel: Dictionary, first: Dictionary, second: Dictionary) -> void:
	if runtime == null:
		return
	var team_id := int(panel["team_id"])
	if runtime.swap_squad_players(team_id, int(first.get("id", -1)), int(second.get("id", -1))):
		set_status("Swapped positions: %s <-> %s" % [
			str(first.get("name", "")), str(second.get("name", ""))], 4000)
		panel["focus_id"] = int(second.get("id", -1))
	else:
		set_status("Could not swap those players")
	_refresh_panel(panel)


func _swap_bench_order(panel: Dictionary, first: Dictionary, second: Dictionary) -> void:
	var order: Array = panel["bench_order"]
	if order.is_empty():
		for index in panel["bench_entries"]:
			var entry: Dictionary = (panel["entries"] as Array)[index]
			order.append(int(entry.get("id", -1)))
	var first_position := order.find(int(first.get("id", -1)))
	var second_position := order.find(int(second.get("id", -1)))
	if first_position < 0 or second_position < 0:
		return
	var swap: int = int(order[first_position])
	order[first_position] = order[second_position]
	order[second_position] = swap
	panel["bench_order"] = order
	set_status("Bench order: %s <-> %s" % [
		str(first.get("name", "")), str(second.get("name", ""))], 4000)
	_refresh_panel(panel)


func _prematch_swap(panel: Dictionary, first: Dictionary, second: Dictionary) -> void:
	var team_id := int(panel["team_id"])
	var lineup: MatchLineup = _lineups.get(team_id)
	if lineup == null:
		return
	var first_id := int(first.get("id", -1))
	var second_id := int(second.get("id", -1))
	if lineup.swap_players(first_id, second_id):
		panel["focus_id"] = second_id
		lineup_changed.emit()
		_refresh_panel(panel)
		set_status("Lineup updated")
	else:
		set_status(lineup.error if not lineup.error.is_empty() else "Swap failed")
		_refresh_panel(panel)


func _is_pending_pair(panel: Dictionary, out: Dictionary, incoming: Dictionary) -> bool:
	for entry in panel["entries"]:
		if bool(entry.get("pending_out", false)) and int(entry.get("id", -1)) == int(out.get("id", -2)):
			for other in panel["entries"]:
				if bool(other.get("pending_in", false)) \
						and int(other.get("id", -1)) == int(incoming.get("id", -2)):
					return true
	return false


func _find_next_entry(panel: Dictionary, from_index: int, direction: Vector2i,
		pitch_only: bool = false) -> int:
	var entries: Array = panel["entries"]
	if from_index < 0 or from_index >= entries.size():
		return -1
	var from_active := bool(entries[from_index].get("active", false))
	var from_point := _entry_point(panel, from_index)
	var dir := Vector2(direction.x, direction.y)
	var best_same := -1
	var best_same_score := 1e9
	var best_any := -1
	var best_any_score := 1e9
	for index in entries.size():
		if index == from_index:
			continue
		var entry: Dictionary = entries[index]
		if bool(entry.get("left_pitch", false)):
			continue
		if pitch_only and not bool(entry.get("active", false)):
			continue
		var delta: Vector2 = _entry_point(panel, index) - from_point
		var along := delta.dot(dir)
		if along <= 1.0:
			continue
		var perp := absf(delta.x * -dir.y + delta.y * dir.x)
		if perp > along * 0.9 + 40.0:
			continue
		var score := along + perp * 0.75
		if score < best_any_score:
			best_any_score = score
			best_any = index
		if bool(entry.get("active", false)) == from_active and score < best_same_score:
			best_same_score = score
			best_same = index
	return best_same if best_same >= 0 else best_any


func _entry_point(panel: Dictionary, entry_index: int) -> Vector2:
	var entries: Array = panel["entries"]
	if entry_index < 0 or entry_index >= entries.size():
		return Vector2.ZERO
	if bool(entries[entry_index].get("active", false)):
		var pitch: GamePlanPitch = panel["pitch"]
		for card in pitch.cards:
			if int(card["entry_index"]) == entry_index:
				return (pitch.position + (card["rect"] as Rect2).get_center())
		return pitch.position + pitch.size * 0.5
	var bench_index := 0
	for index in (panel["bench_entries"] as Array):
		if int(index) == entry_index:
			break
		bench_index += 1
	var rect: Rect2 = panel["bench_rect"]
	var row_h := rect.size.y / maxf(1.0, float((panel["bench_entries"] as Array).size()))
	return rect.position + Vector2(rect.size.x * 0.5, row_h * (bench_index + 0.5))


func _on_done_pressed() -> void:
	var panel_index := _panel_for_keyboard()
	if panel_index < 0:
		panel_index = 0
	if panel_index < _panels.size():
		_leave(_panels[panel_index])


func _held_clear() -> void:
	for panel in _panels:
		panel["held"] = -1


# A fresh match resets the shell's local bench ordering.
func clear_local_orders() -> void:
	for panel in _panels:
		panel["bench_order"] = []



# Dev/test hook: what the per-side cursors point at right now.
func debug_state() -> Dictionary:
	var result: Array = []
	for panel in _panels:
		var entries: Array = panel["entries"]
		var cursor := int(panel["cursor"])
		var held := int(panel["held"])
		var cursor_id := int(entries[cursor].get("id", -1)) if cursor >= 0 and cursor < entries.size() else -1
		var held_id := int(entries[held].get("id", -1)) if held >= 0 and held < entries.size() else -1
		result.append({
			"team": int(panel["team_id"]),
			"editable": bool(panel["editable"]),
			"cursor": cursor,
			"cursor_id": cursor_id,
			"cursor_active": bool(entries[cursor].get("active", false)) if cursor >= 0 and cursor < entries.size() else false,
			"held": held,
			"held_id": held_id,
			"bar_focused": bool(panel["bar_focused"]),
			"section": int(panel["active_section"]),
			"bench_entries": (panel["bench_entries"] as Array).size(),
		})
	return {"open": is_open(), "panels": result}
