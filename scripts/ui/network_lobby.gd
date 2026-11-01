extends Control
# Godot port of NetworkLobbyPage (src/menu/network/networklobby.cpp): the Teams
# phase of the mirrored LAN lobby. Both sides' Country/Competition/Team
# carousels and Ready state come from the host-authoritative LobbyState; only
# the local chooser edits its own panel.

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"
const OPTIONS_SCENE := "res://scenes/network_match_options.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
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
var help_label: Label
var status_label: Label

var _cursor_row := [ROW_COUNTRY, ROW_COUNTRY]
var _default_sent := [false, false]
var _applying := false
var _last_revision := -1
var _active_side := 0
var _help_device := -1
var _repeat_ms := [0, 0]
var _leaving := false


func _ready() -> void:
	_build_ui()
	_load_catalog()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_poll_lobby()
	set_process(true)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.02)
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
		bg.color = Color(0.0, 0.0, 0.0, 0.66)
		add_child(bg)

		var caption: Label = panel["caption"]
		caption.text = "HOME" if s == 0 else "AWAY"
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

	help_label = _caption("Up/Down: level    Left/Right: select    Enter: ready    Esc/B: back")
	status_label = _caption("")


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.66))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0 or view.y <= 0:
		return
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

	for label in [help_label, status_label]:
		label.add_theme_font_size_override("font_size", maxi(11, int(view.y * 0.019)))
	_place(help_label, 0.5, 0.88, 0.80, 0.04)
	_place(status_label, 0.5, 0.81, 0.80, 0.04)


func _place(label: Label, center_x: float, top: float, width: float, height: float) -> void:
	var view := get_viewport_rect().size
	label.position = Vector2(view.x * center_x - view.x * width * 0.5, view.y * top)
	label.size = Vector2(view.x * width, view.y * height)


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
		panels[s]["rows"][ROW_COUNTRY].set_selected(0)
		_setup_competitions(s)
	_refresh_highlight()


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


func _select_by_id(row, id: int) -> bool:
	if id < 0:
		return false
	for i in row.entries.size():
		if str(row.entries[i].get("id", "")) == str(id):
			row.set_selected(i)
			return true
	return false


func _poll_lobby() -> void:
	if _leaving:
		return
	var info := NET_SHELL.lobby(get_tree())
	if info.is_empty() or not bool(info.get("active", false)):
		_leave_session()
		return
	if bool(info.get("is_client", false)) and int(info.get("connection", 0)) == 0:
		_leave_session()
		return

	var lobby: Dictionary = info.get("lobby", {})
	var phase := int(lobby.get("phase", -1))
	if phase == 0:
		get_tree().change_scene_to_file(SIDES_SCENE)
		return
	if phase == 2:
		_enter_options(lobby)
		return

	var revision := int(lobby.get("revision", -1))
	if revision != _last_revision:
		_last_revision = revision
		_apply_state(lobby)

	var chooser_sides := _chooser_sides(lobby, int(info.get("local_id", -1)))
	if not chooser_sides.is_empty() and not chooser_sides.has(_active_side):
		_active_side = int(chooser_sides[0])
	_update_selectable(chooser_sides)
	for side in chooser_sides:
		_seed_defaults(side)
	_update_help(chooser_sides)


func _chooser_sides(lobby: Dictionary, local_id: int) -> Array:
	var chooser: Array = lobby.get("chooser", [])
	var sides: Array = []
	for side in 2:
		if side < chooser.size() and int(chooser[side]) == local_id:
			sides.append(side)
	return sides


func _apply_state(lobby: Dictionary) -> void:
	_applying = true
	var countries: Array = lobby.get("country_ids", [])
	var leagues: Array = lobby.get("league_ids", [])
	var teams: Array = lobby.get("team_ids", [])
	var ready: Array = lobby.get("team_ready", [])
	for s in 2:
		var country_id := int(countries[s]) if s < countries.size() else -1
		var league_id := int(leagues[s]) if s < leagues.size() else -1
		var team_id := int(teams[s]) if s < teams.size() else -1
		if country_id >= 0:
			var country_row = panels[s]["rows"][ROW_COUNTRY]
			if country_id == 0:
				country_row.set_selected(0)
			else:
				_select_by_id(country_row, country_id)
			_setup_competitions(s)
			if league_id > 0:
				_select_by_id(panels[s]["rows"][ROW_COMPETITION], league_id)
				_setup_teams(s)
			if team_id > 0:
				_select_by_id(panels[s]["rows"][ROW_TEAM], team_id)
		var ready_button: Button = panels[s]["ready"]
		ready_button.button_pressed = bool(ready[s]) if s < ready.size() else false
	_applying = false
	_refresh_highlight()


func _seed_defaults(side: int) -> void:
	if _applying or bool(_default_sent[side]):
		return
	var country_row = panels[side]["rows"][ROW_COUNTRY]
	var team_row = panels[side]["rows"][ROW_TEAM]
	var country_entry: Dictionary = country_row.selected_entry()
	var team_entry: Dictionary = team_row.selected_entry()
	if country_entry.is_empty() or team_entry.is_empty():
		return
	_default_sent[side] = true
	var country_id := 0 if str(country_entry.get("id", "")) == "national" \
		else int(str(country_entry.get("id", "0")))
	NET_SHELL.action(get_tree(), "set_selection", side, 0, country_id)
	var team_id := int(str(team_entry.get("id", "0")))
	if team_id > 0:
		NET_SHELL.action(get_tree(), "set_selection", side, 2, team_id)


func _update_selectable(chooser_sides: Array) -> void:
	for s in 2:
		var can_choose := chooser_sides.has(s)
		var panel: Dictionary = panels[s]
		for row in 3:
			var carousel = panel["rows"][row]
			carousel.set_dimmed(not can_choose)
		var ready: Button = panel["ready"]
		ready.disabled = not can_choose
		ready.button_pressed = ready.button_pressed and can_choose
	_refresh_highlight(chooser_sides)


func _refresh_highlight(chooser_sides: Array = []) -> void:
	if chooser_sides.is_empty():
		var info := NET_SHELL.lobby(get_tree())
		if info.is_empty():
			return
		chooser_sides = _chooser_sides(info.get("lobby", {}), int(info.get("local_id", -1)))
	for s in 2:
		var active := chooser_sides.has(s) and s == _active_side
		for row in 3:
			var carousel = panels[s]["rows"][row]
			carousel.set_highlighted(active and int(_cursor_row[s]) == row)


func _update_help(chooser_sides: Array) -> void:
	var extra := "    Tab: panel" if chooser_sides.size() > 1 else ""
	if _help_device == 1:
		help_label.text = "Up/Down: level    Left/Right: select    A: ready    B: back" + extra
	else:
		help_label.text = "Up/Down: level    Left/Right: select    Enter: ready    Esc: back" + extra


func _on_ready_pressed(side: int) -> void:
	if _applying:
		return
	var info := NET_SHELL.lobby(get_tree())
	var lobby: Dictionary = info.get("lobby", {})
	if not _chooser_sides(lobby, int(info.get("local_id", -1))).has(side):
		return
	var ready: Array = lobby.get("team_ready", [])
	var current := bool(ready[side]) if side < ready.size() else false
	NET_SHELL.action(get_tree(), "set_team_ready", side, 0 if current else 1, 0)


func _on_carousel_input(event: InputEvent, side: int, row: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var info := NET_SHELL.lobby(get_tree())
	var lobby: Dictionary = info.get("lobby", {})
	if not _chooser_sides(lobby, int(info.get("local_id", -1))).has(side):
		return
	_active_side = side
	_cursor_row[side] = row
	_refresh_highlight([side])
	var carousel = panels[side]["rows"][row]
	var local_x := mouse.position.x / maxf(1.0, carousel.size.x)
	if local_x < 0.33:
		_move_selection(side, -1)
	elif local_x > 0.67:
		_move_selection(side, 1)


func _move_row(side: int, delta: int) -> void:
	if delta == 0:
		return
	var row := int(_cursor_row[side])
	for guard in 4:
		row += delta
		if row < ROW_COUNTRY:
			row = ROW_READY
		if row > ROW_READY:
			row = ROW_COUNTRY
		if row != ROW_COMPETITION or not _is_national(side):
			break
	_cursor_row[side] = row
	_refresh_highlight()


func _move_selection(side: int, delta: int) -> void:
	if delta == 0:
		return
	var row := int(_cursor_row[side])
	if row > ROW_TEAM:
		return
	var carousel = panels[side]["rows"][row]
	if not carousel.move_selection(delta):
		return
	if row == ROW_COUNTRY:
		_setup_competitions(side)
		_send_selection(side, ROW_COUNTRY)
	elif row == ROW_COMPETITION:
		_setup_teams(side)
		_send_selection(side, ROW_COMPETITION)
	else:
		_send_selection(side, ROW_TEAM)
	_refresh_highlight()


func _send_selection(side: int, row: int) -> void:
	if _applying:
		return
	var country_row = panels[side]["rows"][ROW_COUNTRY]
	var competition_row = panels[side]["rows"][ROW_COMPETITION]
	var team_row = panels[side]["rows"][ROW_TEAM]
	if row == ROW_COUNTRY:
		var country_entry: Dictionary = country_row.selected_entry()
		var country_id := 0 if str(country_entry.get("id", "")) == "national" \
			else int(str(country_entry.get("id", "0")))
		NET_SHELL.action(get_tree(), "set_selection", side, 0, country_id)
		if _is_national(side):
			var national_team := int(str(team_row.selected_entry().get("id", "0")))
			if national_team > 0:
				NET_SHELL.action(get_tree(), "set_selection", side, 2, national_team)
			return
		var league_id := int(str(competition_row.selected_entry().get("id", "0")))
		if league_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 1, league_id)
		var default_team := int(str(team_row.selected_entry().get("id", "0")))
		if default_team > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 2, default_team)
	elif row == ROW_COMPETITION:
		var league_id := int(str(competition_row.selected_entry().get("id", "0")))
		if league_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 1, league_id)
		var team_id := int(str(team_row.selected_entry().get("id", "0")))
		if team_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 2, team_id)
	elif row == ROW_TEAM:
		var team_id := int(str(team_row.selected_entry().get("id", "0")))
		if team_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 2, team_id)


func _enter_options(lobby: Dictionary) -> void:
	var ids: Array = lobby.get("team_ids", [])
	if ids.size() != 2 or int(ids[0]) <= 0 or int(ids[1]) <= 0:
		status_label.text = "Choose both teams."
		return
	var home := catalog.team_by_id(int(ids[0]))
	var away := catalog.team_by_id(int(ids[1]))
	if home.is_empty() or away.is_empty():
		status_label.text = "One of the chosen teams is missing from the database."
		return
	ShellState.set_teams(home, away)
	get_tree().change_scene_to_file(OPTIONS_SCENE)


func _leave_session() -> void:
	if _leaving:
		return
	_leaving = true
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	get_tree().change_scene_to_file(NETWORK_MENU_SCENE)


func _process(_delta: float) -> void:
	_poll_lobby()


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	var lobby_info := NET_SHELL.lobby(get_tree())
	var lobby: Dictionary = lobby_info.get("lobby", {})
	var chooser_sides := _chooser_sides(lobby, int(lobby_info.get("local_id", -1)))
	var side := int(_active_side)

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo or not key.pressed:
			return
		if _help_device != 0:
			_help_device = 0
			_update_help(chooser_sides)
		NET_SHELL.note_local_device(get_tree(), "keyboard", 0)
		if key.keycode == KEY_TAB:
			if chooser_sides.size() > 1:
				var index := chooser_sides.find(side)
				_active_side = int(chooser_sides[(index + 1) % chooser_sides.size()])
				_refresh_highlight(chooser_sides)
			return
		if not chooser_sides.has(side):
			if key.keycode == KEY_ESCAPE:
				_leave_session()
			return
		match key.keycode:
			KEY_UP:
				_move_row(side, -1)
			KEY_DOWN:
				_move_row(side, 1)
			KEY_LEFT:
				_move_selection(side, -1)
			KEY_RIGHT:
				_move_selection(side, 1)
			KEY_ENTER, KEY_KP_ENTER:
				_activate(side)
			KEY_ESCAPE:
				_step_back(side)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if not joy.pressed:
			return
		if _help_device != 1:
			_help_device = 1
			_update_help(chooser_sides)
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(joy.device))
		if not chooser_sides.has(side):
			if int(joy.button_index) == JOY_BUTTON_B:
				_leave_session()
			return
		match int(joy.button_index):
			JOY_BUTTON_DPAD_UP:
				_move_row(side, -1)
			JOY_BUTTON_DPAD_DOWN:
				_move_row(side, 1)
			JOY_BUTTON_DPAD_LEFT:
				_move_selection(side, -1)
			JOY_BUTTON_DPAD_RIGHT:
				_move_selection(side, 1)
			JOY_BUTTON_A:
				_activate(side)
			JOY_BUTTON_B:
				_step_back(side)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var axis := int(motion.axis)
		if axis != JOY_AXIS_LEFT_X and axis != JOY_AXIS_LEFT_Y:
			return
		if absf(motion.axis_value) < 0.5 or not chooser_sides.has(side):
			return
		var now := Time.get_ticks_msec()
		if now - int(_repeat_ms[side]) < ROW_DELAY_MS:
			return
		_repeat_ms[side] = now
		if _help_device != 1:
			_help_device = 1
			_update_help(chooser_sides)
		NET_SHELL.note_local_device(get_tree(), "gamepad", int(motion.device))
		if axis == JOY_AXIS_LEFT_X:
			_move_selection(side, -1 if motion.axis_value < 0.0 else 1)
		else:
			_move_row(side, -1 if motion.axis_value < 0.0 else 1)


func _activate(side: int) -> void:
	var row := int(_cursor_row[side])
	if row == ROW_READY:
		var info := NET_SHELL.lobby(get_tree())
		var lobby: Dictionary = info.get("lobby", {})
		var ready: Array = lobby.get("team_ready", [])
		var current := bool(ready[side]) if side < ready.size() else false
		NET_SHELL.action(get_tree(), "set_team_ready", side, 0 if current else 1, 0)
		return
	_cursor_row[side] = ROW_COUNTRY if row >= ROW_TEAM else row + 1
	if _cursor_row[side] == ROW_COMPETITION and _is_national(side):
		_cursor_row[side] = ROW_TEAM
	_refresh_highlight()


func _step_back(side: int) -> void:
	var row := int(_cursor_row[side])
	if row == ROW_READY:
		_cursor_row[side] = ROW_TEAM
	elif row == ROW_TEAM:
		_cursor_row[side] = ROW_COUNTRY if _is_national(side) else ROW_COMPETITION
	elif row == ROW_COMPETITION:
		_cursor_row[side] = ROW_COUNTRY
	else:
		_leave_session()
		return
	_refresh_highlight()
