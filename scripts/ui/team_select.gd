extends Control
# Godot port of TeamSelectPage (GameplayFootball src/menu/startmatch/teamselect.cpp):
# two side panels with Country / Competition / Team icon carousels and a Ready
# button, driven per side by its device. The database/catalog and the match
# package stay in the Godot shell; only the screen is the original one.

const CONTROLLER_SELECT_SCENE := "res://scenes/controller_select.tscn"
const PREMATCH_SCENE := "res://scenes/prematch.tscn"
const SQUAD_SCENE := "res://scenes/squad.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const CAROUSEL := preload("res://scripts/ui/icon_carousel.gd")
const UI_ASSETS := preload("res://scripts/data/ui_assets.gd")

const ROW_COUNTRY := 0
const ROW_COMPETITION := 1
const ROW_TEAM := 2
const ROW_READY := 3
const ROW_DELAY_MS := 250

@export var data_root := ""

var catalog := TeamCatalog.new()
var national_league_id := -1
var panels: Array = []
var cursor_row := [ROW_COUNTRY, ROW_COUNTRY]
var side_ready := [false, false]
var side_active := [false, false]
var side_device := [{}, {}]
var parallel := false
var active_side := 0
var human_side := 0

var help_label: Label
var credits_label: Label
var status_label: Label
var squad_hint: Label

var _repeat_ms := [0, 0]


func _ready() -> void:
	_build_ui()
	_load_catalog()
	_layout()
	get_viewport().size_changed.connect(_layout)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.035, 0.025)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	for s in 2:
		var panel := {
			"bg": ColorRect.new(),
			"caption": Label.new(),
			"rows": [],
			"ready": Button.new(),
		}
		var bg: ColorRect = panel["bg"]
		bg.color = Color(0.0, 0.0, 0.0, 0.62)
		add_child(bg)

		var caption: Label = panel["caption"]
		caption.text = "Player 1" if s == 0 else "Player 2"
		caption.add_theme_font_override("font", MENU_FONT)
		caption.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(caption)

		for row in 3:
			var carousel = CAROUSEL.new()
			carousel.title = ["Country select", "Competition select", "Team select"][row]
			carousel.gui_input.connect(_on_carousel_input.bind(s, row))
			add_child(carousel)
			panel["rows"].append(carousel)

		var ready: Button = panel["ready"]
		ready.text = "Ready"
		ready.toggle_mode = true
		ready.add_theme_font_override("font", MENU_FONT)
		ready.add_theme_font_size_override("font_size", 24)
		ready.pressed.connect(_on_ready_pressed.bind(s))
		add_child(ready)
		panels.append(panel)

	help_label = _caption("Up/Down: level    Left/Right: select    Ready button: confirm    Esc/B: back")
	credits_label = _caption("Team emblems by TureckiRumun, broxopios, balder, and NLP !")
	status_label = _caption("")
	squad_hint = _caption("V: view squad")


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.66))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _load_catalog() -> void:
	if not catalog.load_data_root(data_root):
		status_label.text = catalog.error
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		return
	national_league_id = catalog.national_league_id()
	var country_entries: Array = [
		{"id": "national", "caption": "National Teams", "texture": UI_ASSETS.national_icon()},
	]
	for country in catalog.countries:
		country_entries.append({
			"id": str(country.get("id", 0)),
			"caption": str(country.get("name", "")),
			"texture": UI_ASSETS.country_flag(country),
		})
	for s in 2:
		panels[s]["rows"][ROW_COUNTRY].set_entries(country_entries)
		_setup_competitions(s)

	# Returning from the pre-match hub restores the teams each side had.
	if ShellState.has_selection():
		_restore_team(0, int(ShellState.home_team.get("id", 0)))
		_restore_team(1, int(ShellState.away_team.get("id", 0)))

	_resolve_devices()
	_refresh_highlight()


func _resolve_devices() -> void:
	var entries: Array = ShellState.controllers
	if entries.is_empty():
		entries = ShellState.DEFAULT_CONTROLLERS.duplicate(true)
	var present := {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var side := 1 if str(entry.get("side", "home")) == "away" else 0
		present[side] = {
			"kind": str(entry.get("kind", "keyboard")),
			"device": int(entry.get("device", 0)),
		}
	if present.is_empty():
		present[0] = {"kind": "keyboard", "device": 0}
	side_device[0] = present.get(0, {})
	side_device[1] = present.get(1, {})
	parallel = present.has(0) and present.has(1) \
		and not (str(side_device[0].get("kind", "")) == "keyboard"
			and str(side_device[1].get("kind", "")) == "keyboard") \
		and not (str(side_device[0].get("kind", "")) == "gamepad"
			and int(side_device[0].get("device", -1)) == int(side_device[1].get("device", -2)))
	if parallel:
		side_active = [true, true]
		active_side = 0
		human_side = 0
	else:
		active_side = 0 if present.has(0) else 1
		human_side = active_side
		side_active = [active_side == 0, active_side == 1]
		# The other side is the CPU opponent; it inherits the single device once
		# the human side is ready, like the original RevealAway.
		var other := 1 - active_side
		side_device[other] = side_device[active_side].duplicate(true)
	_update_panel_visibility()


func _layout() -> void:
	var view := get_viewport_rect().size
	var caption_size := maxi(14, int(view.y * 0.024))
	for s in 2:
		var gx := 0.19 if s == 0 else 0.51
		var panel: Dictionary = panels[s]
		var bg: ColorRect = panel["bg"]
		bg.position = Vector2(view.x * gx, view.y * 0.24)
		bg.size = Vector2(view.x * 0.30, view.y * 0.42)

		var caption: Label = panel["caption"]
		caption.add_theme_font_size_override("font_size", caption_size)
		caption.position = Vector2(view.x * gx, view.y * 0.195)
		caption.size = Vector2(view.x * 0.29, view.y * 0.035)

		for row in 3:
			var carousel = panel["rows"][row]
			carousel.position = Vector2(view.x * (gx + 0.005), view.y * (0.24 + row * 0.105))
			carousel.size = Vector2(view.x * 0.29, view.y * 0.10)
			carousel.queue_redraw()

		var ready: Button = panel["ready"]
		ready.position = Vector2(view.x * (gx + 0.005), view.y * 0.555)
		ready.size = Vector2(view.x * 0.29, view.y * 0.055)

	for label in [help_label, credits_label, status_label, squad_hint]:
		label.add_theme_font_size_override("font_size", maxi(11, int(view.y * 0.019)))
	_place(help_label, 0.5, 0.88, 0.8, 0.04)
	_place(credits_label, 0.5, 0.70, 0.6, 0.03)
	_place(status_label, 0.5, 0.79, 0.8, 0.035)
	_place(squad_hint, 0.5, 0.93, 0.4, 0.03)
	credits_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.6))


func _place(label: Label, center_x: float, top: float, width: float, height: float) -> void:
	var view := get_viewport_rect().size
	label.position = Vector2(view.x * center_x - view.x * width * 0.5, view.y * top)
	label.size = Vector2(view.x * width, view.y * height)


func _update_panel_visibility() -> void:
	for s in 2:
		var visible_side: bool = parallel or bool(side_active[s]) or bool(side_ready[s])
		var panel: Dictionary = panels[s]
		panel["bg"].visible = visible_side
		panel["caption"].visible = visible_side
		for carousel in panel["rows"]:
			carousel.visible = visible_side
		panel["ready"].visible = visible_side


func _refresh_highlight() -> void:
	for s in 2:
		var active: bool = bool(side_active[s]) and not bool(side_ready[s])
		var panel: Dictionary = panels[s]
		for row in 3:
			var carousel = panel["rows"][row]
			carousel.set_highlighted(active and cursor_row[s] == row)
			carousel.set_dimmed(not side_active[s] and not side_ready[s])
		var ready: Button = panel["ready"]
		ready.button_pressed = side_ready[s]
		ready.disabled = not side_active[s]
	_update_panel_visibility()


func _is_national(s: int) -> bool:
	var entry: Dictionary = panels[s]["rows"][ROW_COUNTRY].selected_entry()
	return str(entry.get("id", "")) == "national"


func _setup_competitions(s: int) -> void:
	var country = panels[s]["rows"][ROW_COUNTRY]
	var competition = panels[s]["rows"][ROW_COMPETITION]
	var team = panels[s]["rows"][ROW_TEAM]
	if _is_national(s):
		competition.set_entries([])
		competition.set_dimmed(true)
		_setup_teams(s, national_league_id)
		return
	competition.set_dimmed(false)
	var country_id := int(str(country.selected_entry().get("id", "0")))
	var entries: Array = []
	for league in catalog.leagues_for_country(country_id):
		entries.append({
			"id": str(league.get("id", 0)),
			"caption": str(league.get("name", "")),
			"texture": UI_ASSETS.league_logo(league),
		})
	competition.set_entries(entries)
	_setup_teams(s)


func _setup_teams(s: int, forced_league: int = -1) -> void:
	var competition = panels[s]["rows"][ROW_COMPETITION]
	var team = panels[s]["rows"][ROW_TEAM]
	var league_id := forced_league
	if league_id < 0:
		league_id = int(str(competition.selected_entry().get("id", "0")))
	var entries: Array = []
	for team_data in catalog.teams_for_league(league_id):
		entries.append({
			"id": str(team_data.get("id", 0)),
			"caption": str(team_data.get("name", "")),
			"texture": UI_ASSETS.team_logo(team_data),
		})
	team.set_entries(entries)


func _restore_team(s: int, team_id: int) -> void:
	var team := catalog.team_by_id(team_id)
	if team.is_empty():
		return
	var league := catalog.league_by_id(int(team.get("league_id", 0)))
	if league.is_empty():
		return
	var national := str(league.get("name", "")) == TeamCatalog.NATIONAL_LEAGUE_NAME
	var country_id := int(league.get("country_id", 0))
	var country_row = panels[s]["rows"][ROW_COUNTRY]
	var country_index := 0
	if not national:
		for i in country_row.entries.size():
			if str(country_row.entries[i].get("id", "")) == str(country_id):
				country_index = i
				break
	country_row.set_selected(country_index)
	_setup_competitions(s)
	if not national:
		var competition = panels[s]["rows"][ROW_COMPETITION]
		for i in competition.entries.size():
			if str(competition.entries[i].get("id", "")) == str(league.get("id", 0)):
				competition.set_selected(i)
				break
		_setup_teams(s)
	var team_row = panels[s]["rows"][ROW_TEAM]
	for i in team_row.entries.size():
		if str(team_row.entries[i].get("id", "")) == str(team_id):
			team_row.set_selected(i)
			break


func _input(event: InputEvent) -> void:
	if status_label.text != "" and not status_label.text.begins_with("Choose"):
		return
	if event is InputEventKey:
		_handle_key(event as InputEventKey)
	elif event is InputEventJoypadButton:
		_handle_joy_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_handle_joy_motion(event as InputEventJoypadMotion)


func _input_side_for_keyboard() -> int:
	if parallel:
		for s in 2:
			if str(side_device[s].get("kind", "")) == "keyboard":
				return s
		return -1
	return active_side


func _input_side_for_gamepad(device: int) -> int:
	if parallel:
		for s in 2:
			if str(side_device[s].get("kind", "")) == "gamepad" \
					and int(side_device[s].get("device", -1)) == device:
				return s
		return -1
	return active_side


func _handle_key(event: InputEventKey) -> void:
	if event.echo or not event.pressed:
		return
	var s := _input_side_for_keyboard()
	if s < 0:
		return
	match event.keycode:
		KEY_UP:
			_move_row(s, -1)
		KEY_DOWN:
			_move_row(s, 1)
		KEY_LEFT:
			_move_selection(s, -1)
		KEY_RIGHT:
			_move_selection(s, 1)
		KEY_ENTER, KEY_KP_ENTER:
			_activate(s)
		KEY_ESCAPE:
			_cancel(s)
		KEY_V:
			_view_squad(s)


func _handle_joy_button(event: InputEventJoypadButton) -> void:
	if not event.pressed:
		return
	var s := _input_side_for_gamepad(int(event.device))
	if s < 0:
		return
	match int(event.button_index):
		JOY_BUTTON_DPAD_UP:
			_move_row(s, -1)
		JOY_BUTTON_DPAD_DOWN:
			_move_row(s, 1)
		JOY_BUTTON_DPAD_LEFT:
			_move_selection(s, -1)
		JOY_BUTTON_DPAD_RIGHT:
			_move_selection(s, 1)
		JOY_BUTTON_A:
			_activate(s)
		JOY_BUTTON_B:
			_cancel(s)


func _handle_joy_motion(event: InputEventJoypadMotion) -> void:
	var axis := int(event.axis)
	if axis != JOY_AXIS_LEFT_X and axis != JOY_AXIS_LEFT_Y:
		return
	if absf(event.axis_value) < 0.5:
		return
	var s := _input_side_for_gamepad(int(event.device))
	if s < 0:
		return
	var now := Time.get_ticks_msec()
	if now - int(_repeat_ms[s]) < ROW_DELAY_MS:
		return
	_repeat_ms[s] = now
	if axis == JOY_AXIS_LEFT_X:
		_move_selection(s, -1 if event.axis_value < 0.0 else 1)
	else:
		_move_row(s, -1 if event.axis_value < 0.0 else 1)


func _move_row(s: int, delta: int) -> void:
	if side_ready[s] or delta == 0:
		return
	var row := int(cursor_row[s])
	for guard in 4:
		row += delta
		if row < ROW_COUNTRY:
			row = ROW_READY
		if row > ROW_READY:
			row = ROW_COUNTRY
		if row != ROW_COMPETITION or not _is_national(s):
			break
	cursor_row[s] = row
	_refresh_highlight()


func _move_selection(s: int, delta: int) -> void:
	if side_ready[s] or delta == 0:
		return
	var row := int(cursor_row[s])
	if row > ROW_TEAM:
		return
	var carousel = panels[s]["rows"][row]
	if not carousel.move_selection(delta):
		return
	if row == ROW_COUNTRY:
		_setup_competitions(s)
	elif row == ROW_COMPETITION:
		_setup_teams(s)
	_refresh_highlight()


func _activate(s: int) -> void:
	if side_ready[s]:
		return
	var row := int(cursor_row[s])
	if row == ROW_COUNTRY:
		cursor_row[s] = ROW_TEAM if _is_national(s) else ROW_COMPETITION
	elif row == ROW_COMPETITION:
		cursor_row[s] = ROW_TEAM
	elif row == ROW_TEAM:
		cursor_row[s] = ROW_READY
	elif row == ROW_READY:
		_set_ready(s, true)
		return
	_refresh_highlight()


func _cancel(s: int) -> void:
	if side_ready[s]:
		_set_ready(s, false)
		return
	var row := int(cursor_row[s])
	if row == ROW_READY:
		cursor_row[s] = ROW_TEAM
	elif row == ROW_TEAM:
		cursor_row[s] = ROW_COUNTRY if _is_national(s) else ROW_COMPETITION
	elif row == ROW_COMPETITION:
		cursor_row[s] = ROW_COUNTRY
	else:
		_leave()
		return
	_refresh_highlight()


func _on_ready_pressed(s: int) -> void:
	if not side_active[s]:
		return
	if side_ready[s]:
		_set_ready(s, false)
	else:
		_set_ready(s, true)


func _set_ready(s: int, ready: bool) -> void:
	if ready == side_ready[s]:
		return
	side_ready[s] = ready
	var panel: Dictionary = panels[s]
	var ready_button: Button = panel["ready"]
	ready_button.button_pressed = ready
	if not ready:
		cursor_row[s] = ROW_READY
		_refresh_highlight()
		return
	if parallel:
		if side_ready[0] and side_ready[1]:
			_go_prematch()
			return
	else:
		if s == human_side:
			var other := 1 - human_side
			side_active[human_side] = false
			side_active[other] = true
			side_device[other] = side_device[human_side].duplicate(true)
			active_side = other
			cursor_row[other] = ROW_COUNTRY
		else:
			_go_prematch()
			return
	_refresh_highlight()


func _view_squad(s: int) -> void:
	var team_row = panels[s]["rows"][ROW_TEAM]
	var team_id := int(str(team_row.selected_entry().get("id", "0")))
	var team := catalog.team_by_id(team_id)
	if team.is_empty():
		return
	ShellState.set_preview_team(team)
	get_tree().change_scene_to_file(SQUAD_SCENE)


func _go_prematch() -> void:
	var home_id := int(str(panels[0]["rows"][ROW_TEAM].selected_entry().get("id", "0")))
	var away_id := int(str(panels[1]["rows"][ROW_TEAM].selected_entry().get("id", "0")))
	var home := catalog.team_by_id(home_id)
	var away := catalog.team_by_id(away_id)
	if home.is_empty() or away.is_empty():
		status_label.text = "Choose both teams."
		return
	ShellState.set_teams(home, away)
	get_tree().change_scene_to_file(PREMATCH_SCENE)


func _leave() -> void:
	get_tree().change_scene_to_file(CONTROLLER_SELECT_SCENE)


func _on_carousel_input(event: InputEvent, s: int, row: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not side_active[s] or side_ready[s]:
		return
	cursor_row[s] = row
	_refresh_highlight()
	var carousel = panels[s]["rows"][row]
	var local_x := mouse.position.x / maxf(1.0, carousel.size.x)
	if local_x < 0.33:
		_move_selection(s, -1)
	elif local_x > 0.67:
		_move_selection(s, 1)
