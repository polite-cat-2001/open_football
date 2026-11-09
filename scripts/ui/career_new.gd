extends UiScreen
# New Career: country -> league -> club, then manager name + nationality.
# Layout and flow follow the prototype's NewCareer.svelte.

const START_SCENE := "res://scenes/career_start.tscn"
const HUB_SCENE := "res://scenes/career_hub.tscn"
const CLUB_STEP_HEIGHT := 820.0
const NAME_MAX := 48
const FIELD_ORDER := ["country", "team", "competition"]
const CLUB_INFO := preload("res://scripts/ui/career_club_info.gd")

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
@onready var osk: UiOnScreenKeyboard = $Design/Osk

var _catalog: TeamCatalog
var _store: CareerSaveStore

var _countries: Array = []
var _leagues: Array = []
var _clubs: Array = []
var _squad: Array = []
var _country_index := 0
var _league_index := 0
var _club_index := 0
var _nationality_index := 0
var _nationality_touched := false
var _manager_name := ""
var _step := "club"
var fixed_seed := -1

var _header_bg: Panel
var _tab_club: Label
var _tab_manager: Label
var _tab_mark: ColorRect
var _step_club: Control
var _step_manager: Control

var _panel: TeamPanel
var _info: Control
var _focus_field := "team"

var _name_row: UiFormRow
var _nat_row: CareerRow
var _nat_prev: Button
var _nat_next: Button
var _cta: BentoTile
var _step_animating := false
var _recap_panel: Panel
var _recap_crest: TextureRect
var _recap_name: Label
var _recap_meta: Label
var _recap_values: Array = []

var _rows: Array = []
var _focus_index := 0


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	_catalog = CareerSession.catalog if CareerSession.catalog != null else TeamCatalog.new()
	if not _catalog.is_loaded():
		_catalog.load_data_root()
	_store = CareerSession.store if CareerSession.store != null else CareerSaveStore.new()
	_build_header()
	_build_club_step()
	_build_manager_step()
	hints.setup(_keyboard_hints())
	osk.applied.connect(_on_name_applied)
	osk.closed.connect(_on_osk_closed)
	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_on_nav_cancelled)
	UiNav.device_changed.connect(_on_device_changed)
	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	_load_countries()
	call_deferred("_focus_initial")


func _build_header() -> void:
	var header := Control.new()
	header.name = "StepTabs"
	panel_wrap.add_child(header)
	_header_bg = Panel.new()
	_header_bg.name = "Bg"
	_header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	_header_bg.add_theme_stylebox_override(&"panel", box)
	header.add_child(_header_bg)
	_tab_club = _header_label("CLUB")
	_tab_manager = _header_label("MANAGER")
	header.add_child(_tab_club)
	header.add_child(_tab_manager)
	_tab_mark = ColorRect.new()
	_tab_mark.color = UiTokens.INK
	_tab_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_tab_mark)
	header.set_meta(&"role", "header")


func _header_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", UiTheme.barlow(700))
	label.add_theme_font_size_override(&"font_size", 22)
	return label


func _build_club_step() -> void:
	_step_club = Control.new()
	_step_club.name = "ClubStep"
	panel_wrap.add_child(_step_club)
	_panel = TeamPanel.new()
	_panel.name = "ClubPanel"
	_step_club.add_child(_panel)
	_info = CLUB_INFO.new()
	_info.name = "ClubInfo"
	_step_club.add_child(_info)


func _build_manager_step() -> void:
	_step_manager = Control.new()
	_step_manager.name = "ManagerStep"
	_step_manager.visible = false
	panel_wrap.add_child(_step_manager)

	_name_row = UiFormRow.new()
	_name_row.name = "NameRow"
	_name_row.opaque = true
	_name_row.field_title = "MANAGER NAME"
	_name_row.field_value = ""
	_name_row.field_hint = "Press Enter to type"
	_name_row.custom_minimum_size.y = 96.0
	_name_row.pressed.connect(_open_name)
	_step_manager.add_child(_name_row)

	_nat_row = _make_row("Nationality")
	_nat_row.pressed.connect(func() -> void: pass)
	_step_manager.add_child(_nat_row)
	_nat_prev = _make_nat_arrow(-1)
	_nat_next = _make_nat_arrow(1)

	_cta = BentoTile.new()
	_cta.name = "StartTile"
	_cta.title = "START CAREER"
	_cta.subtitle = "Enter a name and pick a nationality"
	_cta.meta = ""
	_cta.glyph_name = "play"
	_cta.pressed.connect(_create_career)
	_step_manager.add_child(_cta)

	_recap_panel = Panel.new()
	_recap_panel.name = "Recap"
	_recap_panel.add_theme_stylebox_override(&"panel", _tile_box())
	_step_manager.add_child(_recap_panel)
	var recap := VBoxContainer.new()
	recap.add_theme_constant_override(&"separation", 8)
	recap.position = Vector2(16, 16)
	recap.size = Vector2(318, 300)
	_recap_panel.add_child(recap)
	var eyebrow := Label.new()
	eyebrow.text = "YOUR CLUB"
	eyebrow.add_theme_font_override(&"font", UiTheme.inter(600))
	eyebrow.add_theme_font_size_override(&"font_size", 15)
	eyebrow.add_theme_color_override(&"font_color", UiTokens.INK_2)
	recap.add_child(eyebrow)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	recap.add_child(head)
	_recap_crest = TextureRect.new()
	_recap_crest.custom_minimum_size = Vector2(72, 72)
	_recap_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_recap_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_recap_crest)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(identity)
	_recap_name = Label.new()
	_recap_name.add_theme_font_override(&"font", UiTheme.barlow(800))
	_recap_name.add_theme_font_size_override(&"font_size", 28)
	_recap_name.add_theme_color_override(&"font_color", UiTokens.INK)
	_recap_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(_recap_name)
	_recap_meta = Label.new()
	_recap_meta.add_theme_font_override(&"font", UiTheme.inter(500))
	_recap_meta.add_theme_font_size_override(&"font_size", 15)
	_recap_meta.add_theme_color_override(&"font_color", UiTokens.INK_2)
	identity.add_child(_recap_meta)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", 8)
	stats.add_theme_constant_override(&"v_separation", 8)
	recap.add_child(stats)
	for title in ["SQUAD", "AVERAGE OVR", "VALUE", "SEED"]:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(150, 64)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UiTokens.INK, 0.045)
		cell.add_theme_stylebox_override(&"panel", style)
		var inner := VBoxContainer.new()
		inner.position = Vector2(10, 6)
		inner.size = Vector2(130, 52)
		cell.add_child(inner)
		var label := Label.new()
		label.text = title
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 13)
		label.add_theme_color_override(&"font_color", UiTokens.INK_2)
		inner.add_child(label)
		var value := Label.new()
		value.add_theme_font_override(&"font", UiTheme.barlow(700))
		value.add_theme_font_size_override(&"font_size", 22)
		value.add_theme_color_override(&"font_color", UiTokens.INK)
		inner.add_child(value)
		_recap_values.append(value)
		stats.add_child(cell)


func _make_row(label: String) -> CareerRow:
	var row := CareerRow.new()
	row.name = label + "Row"
	row.title_size = 22
	row.custom_minimum_size.y = 64.0
	return row


func _make_nat_arrow(direction: int) -> Button:
	var button := Button.new()
	button.name = "Prev" if direction < 0 else "Next"
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var arrow := KitArrow.new()
	arrow.direction = direction
	arrow.active = true
	arrow.color = UiTokens.RAIL
	arrow.position = Vector2(9.0, 7.0)
	arrow.size = Vector2(18.0, 26.0)
	button.add_child(arrow)
	button.pressed.connect(_cycle_nationality.bind(direction))
	_nat_row.add_child(button)
	return button


func _cycle_nationality(delta: int) -> void:
	if _countries.size() < 2:
		return
	_nationality_touched = true
	_nationality_index = posmod(_nationality_index + delta, _countries.size())
	_refresh_nationality()


func _tile_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box


func _focus_initial() -> void:
	if _step == "club":
		_focus_field = "team"
		_refresh_panel_focus()


func select_country_by_id(country_id: int) -> bool:
	for index in range(_countries.size()):
		if int(_countries[index].get("id", 0)) == country_id:
			_select_country(index)
			return true
	return false


func select_league_by_id(league_id: String) -> bool:
	for index in range(_leagues.size()):
		if str(_leagues[index].get("id", "")) == league_id:
			_select_league(index)
			return true
	return false


func select_club_by_id(club_id: int) -> bool:
	for index in range(_clubs.size()):
		if int(_clubs[index].get("id", 0)) == club_id:
			_select_club(index)
			return true
	return false


func current_step() -> String:
	return _step


func _load_countries() -> void:
	_countries = _catalog.countries()
	if _countries.is_empty():
		hints.set_status("Career database has no countries.", true)
		return
	_country_index = 0
	_select_country(0)


func _select_country(index: int) -> void:
	if _countries.is_empty():
		return
	_country_index = posmod(index, _countries.size())
	var country: Dictionary = _countries[_country_index]
	_leagues = _catalog.leagues_for_country(int(country.get("id", 0)))
	_league_index = 0
	_clubs = []
	_squad = []
	_club_index = 0
	if not _leagues.is_empty():
		_select_league(0)
	else:
		_refresh_club_view()
	_refresh_step_tabs()


func _select_league(index: int) -> void:
	if _leagues.is_empty():
		return
	_league_index = posmod(index, _leagues.size())
	var league: Dictionary = _leagues[_league_index]
	_clubs = _catalog.all_teams_for_league(str(league.get("id", "")))
	_club_index = 0
	_squad = []
	if not _clubs.is_empty():
		_select_club(0)
	else:
		_refresh_club_view()


func _select_club(index: int) -> void:
	if _clubs.is_empty():
		return
	_club_index = posmod(index, _clubs.size())
	var club: Dictionary = _clubs[_club_index]
	_squad = _catalog.career_squad(int(club.get("id", 0)))
	if not _nationality_touched:
		_nationality_index = _country_index
	_refresh_club_view()


func _refresh_club_view() -> void:
	if _panel == null:
		return
	_panel.setup(_panel_state())
	_panel.set_focus(_focus_field)
	if _clubs.is_empty():
		_info.setup({}, [])
	else:
		_info.setup(_catalog.career_club(int(_clubs[_club_index].get("id", 0))), _squad)
	_refresh_recap()


func _refresh_panel_focus() -> void:
	if _panel != null:
		_panel.set_focus(_focus_field)


func _panel_state() -> Dictionary:
	var country: Dictionary = _countries[_country_index] if not _countries.is_empty() else {}
	var league: Dictionary = _leagues[_league_index] if not _leagues.is_empty() else {}
	var club: Dictionary = _clubs[_club_index] if not _clubs.is_empty() else {}
	var team := _catalog.team_by_id(int(club.get("id", 0))) if not club.is_empty() else {}
	var rating := _catalog.load_team_rating(int(club.get("id", 0))) if not club.is_empty() else {}
	var country_entry := country.duplicate()
	country_entry["texture"] = null
	if not country.is_empty():
		country_entry["texture"] = UiAssets.usable_texture(UiAssets.country_flag(country))
	var league_entry := league.duplicate()
	league_entry["texture"] = null
	if not league.is_empty():
		league_entry["texture"] = UiAssets.usable_texture(UiAssets.league_logo(league))
	var team_entry := team.duplicate()
	team_entry["texture"] = null
	if not team.is_empty():
		team_entry["texture"] = UiAssets.usable_texture(UiAssets.team_logo(team))
	return {
		"label": "",
		"owner": "",
		"ready": false,
		"live": true,
		"focus": _focus_field,
		"choices": {
			"country": _countries.size(),
			"competition": _leagues.size(),
			"team": _clubs.size(),
		},
		"country": country_entry,
		"competition": league_entry,
		"team": team_entry,
		"rating": rating,
	}


func _refresh_recap() -> void:
	if _clubs.is_empty():
		return
	var club := _catalog.career_club(int(_clubs[_club_index].get("id", 0)))
	var team := _catalog.team_by_id(int(club.get("id", 0)))
	_recap_crest.texture = UiAssets.usable_texture(UiAssets.team_logo(team))
	_recap_name.text = str(club.get("name", ""))
	_recap_meta.text = "%s · %s" % [str(club.get("league_name", "")),
		str(club.get("country_name", ""))]
	var overalls: Array = []
	var total_value := 0
	for player in _squad:
		overalls.append(float(player.get("overall", 0.0)))
		total_value += int(player.get("market_value", 0))
	var average := 0.0
	if not overalls.is_empty():
		average = round(_array_sum(overalls) / overalls.size() * 10.0) / 10.0
	_recap_values[0].text = str(_squad.size())
	_recap_values[1].text = "%.1f" % average
	_recap_values[2].text = _format_value(total_value)
	_recap_values[3].text = "RANDOM" if fixed_seed < 0 else str(fixed_seed)
	_refresh_nationality()


func _refresh_nationality() -> void:
	if _countries.is_empty():
		return
	_nationality_index = posmod(_nationality_index, _countries.size())
	var country: Dictionary = _countries[_nationality_index]
	_nat_row.set_content(str(country.get("name", "")), "MANAGER NATIONALITY", "", "", "")
	_nat_row.set_lead(UiAssets.country_flag(country))
	if _nat_prev != null:
		_nat_prev.visible = _countries.size() > 1
		_nat_next.visible = _countries.size() > 1
	_refresh_cta()


func _refresh_cta() -> void:
	var ready := _can_create()
	_cta.set_copy(
		"START CAREER",
		"Name and nationality set" if ready else "Enter a name and pick a nationality",
		"",
		""
	)
	_cta.set_enabled(ready)


func _can_create() -> bool:
	return not _manager_name.strip_edges().is_empty() and not _countries.is_empty() \
		and not _clubs.is_empty()


func _refresh_step_tabs() -> void:
	var club_active := _step == "club"
	_tab_club.add_theme_color_override(&"font_color",
		UiTokens.INK if club_active else UiTokens.INK_2)
	_tab_manager.add_theme_color_override(&"font_color",
		UiTokens.INK_2 if club_active else UiTokens.INK)
	_tab_club.add_theme_font_override(&"font", UiTheme.barlow(800 if club_active else 700))
	_tab_manager.add_theme_font_override(&"font",
		UiTheme.barlow(700 if club_active else 800))
	_tab_mark.position = Vector2(20.0 if club_active else 116.0, 38.0)
	_tab_mark.size = Vector2(76.0 if club_active else 112.0, 2.0)


func _show_manager_step() -> void:
	if _clubs.is_empty() or _step_animating:
		return
	_animate_step(_step_manager, func() -> void:
		_step = "manager"
		_rows = [_name_row, _nat_row, _cta]
		_focus_index = 0
		_refresh_step_tabs()
		hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())
		_refresh_recap()
		_name_row.grab_focus()
	)


func _show_club_step() -> void:
	if _step_animating:
		return
	_animate_step(_step_club, func() -> void:
		_step = "club"
		_rows = []
		_focus_field = "team"
		_refresh_step_tabs()
		hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())
		_refresh_panel_focus()
	)


func _animate_step(next: Control, setup: Callable) -> void:
	_step_animating = true
	var current := _step_club if _step == "club" else _step_manager
	current.pivot_offset = current.size * 0.5
	var out := create_tween().set_parallel(true)
	out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(current, "modulate:a", 0.0, 0.15)
	out.tween_property(current, "scale", Vector2(0.98, 0.98), 0.15)
	await out.finished
	current.visible = false
	current.modulate.a = 1.0
	current.scale = Vector2.ONE
	setup.call()
	_step_animating = false
	next.visible = true
	next.pivot_offset = next.size * 0.5
	next.modulate.a = 0.0
	next.scale = Vector2(0.96, 0.96)
	var enter := create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.tween_property(next, "modulate:a", 1.0, 0.24)
	enter.tween_property(next, "scale", Vector2.ONE, 0.24)
	await enter.finished


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	var hints_height := hints.height()
	var total := 40.0 + UiTokens.GAP + CLUB_STEP_HEIGHT + UiTokens.HINTS_GAP \
		+ hints_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)

	var header := panel_wrap.get_node_or_null("StepTabs") as Control
	header.position = Vector2.ZERO
	header.size = Vector2(UiTokens.PANEL_W, 40.0)
	_header_bg.position = Vector2.ZERO
	_header_bg.size = header.size
	_tab_club.position = Vector2(20.0, 0.0)
	_tab_club.size = Vector2(86.0, 40.0)
	_tab_manager.position = Vector2(116.0, 0.0)
	_tab_manager.size = Vector2(122.0, 40.0)

	_step_club.position = Vector2(0.0, 40.0 + UiTokens.GAP)
	_step_club.size = Vector2(UiTokens.PANEL_W, CLUB_STEP_HEIGHT)
	_layout_club_step()
	_step_manager.position = _step_club.position
	_step_manager.size = _step_club.size
	_layout_manager_step()
	hints.position = Vector2(0.0, 40.0 + UiTokens.GAP + CLUB_STEP_HEIGHT
		+ UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)


func _layout_club_step() -> void:
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(UiTokens.TEAM_PANEL_W, CLUB_STEP_HEIGHT)
	_info.position = Vector2(UiTokens.TEAM_PANEL_W + UiTokens.GAP, 0.0)
	_info.size = Vector2(
		UiTokens.PANEL_W - UiTokens.TEAM_PANEL_W - UiTokens.GAP,
		CLUB_STEP_HEIGHT
	)


func _layout_manager_step() -> void:
	var recap_width := 350.0
	var main_width := UiTokens.PANEL_W - recap_width - UiTokens.GAP
	_name_row.position = Vector2.ZERO
	_name_row.size = Vector2(main_width, 96.0)
	_nat_row.position = Vector2(0.0, 106.0)
	_nat_row.size = Vector2(main_width, 64.0)
	if _nat_prev != null:
		_nat_prev.position = Vector2(main_width - 100.0, 12.0)
		_nat_prev.size = Vector2(36.0, 40.0)
		_nat_next.position = Vector2(main_width - 54.0, 12.0)
		_nat_next.size = Vector2(36.0, 40.0)
	_cta.set_base_rect(Rect2(Vector2(0.0, 180.0), Vector2(main_width, 112.0)),
		Vector2.ZERO)
	_recap_panel.position = Vector2(main_width + UiTokens.GAP, 0.0)
	_recap_panel.size = Vector2(recap_width, 340.0)


func _on_nav_moved(direction: Vector2i) -> void:
	if UiNav.is_modal() or UiNav.event_was_modal() or osk.is_open() or _step_animating:
		return
	if _step == "club":
		if direction == Vector2i.UP or direction == Vector2i.DOWN:
			var index := FIELD_ORDER.find(_focus_field)
			index = clampi(index + (-1 if direction == Vector2i.UP else 1),
				0, FIELD_ORDER.size() - 1)
			_focus_field = FIELD_ORDER[index]
			_refresh_panel_focus()
			return
		var delta := 1 if direction == Vector2i.RIGHT else -1
		match _focus_field:
			"country":
				_select_country(_country_index + delta)
			"competition":
				_select_league(_league_index + delta)
			"team":
				_select_club(_club_index + delta)
		return
	if _rows.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := _rows.find(focused)
	if index < 0:
		index = _focus_index
	if direction == Vector2i.UP or direction == Vector2i.DOWN:
		var step := -1 if direction == Vector2i.UP else 1
		_focus_index = posmod(index + step, _rows.size())
		_rows[_focus_index].grab_focus()
		return
	if focused == _nat_row:
		_nationality_touched = true
		_nationality_index = posmod(
			_nationality_index + (1 if direction == Vector2i.RIGHT else -1),
			_countries.size()
		)
		_refresh_nationality()


func _on_nav_confirmed() -> void:
	if UiNav.is_modal() or UiNav.event_was_modal() or osk.is_open() or _step_animating:
		return
	if _step == "club":
		_show_manager_step()
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == _name_row:
		_open_name()
	elif focused == _cta and not _cta.disabled:
		_create_career()


func _on_nav_cancelled() -> void:
	if UiNav.is_modal() or UiNav.event_was_modal() or osk.is_open() or _step_animating:
		return
	if _step == "manager":
		_show_club_step()
	else:
		UiTransition.change_scene(START_SCENE)


func _on_device_changed(_gamepad: bool) -> void:
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())
	if _step == "club":
		_refresh_club_view()


func _open_name() -> void:
	osk.apply_on_confirm = true
	osk.open("MANAGER NAME", _manager_name, NAME_MAX, NetworkValidation.NAME_CHARS,
		UiTokens.OSK_ROWS_CAREER)


func _on_name_applied(text: String) -> void:
	_manager_name = text.strip_edges()
	_name_row.set_value(_manager_name)
	_name_row.set_error("")
	_refresh_cta()
	_name_row.grab_focus()


func _on_osk_closed() -> void:
	_name_row.grab_focus()


func _create_career() -> void:
	if not _can_create():
		hints.set_status("Enter a manager name first.", true)
		return
	if _clubs.is_empty():
		hints.set_status("Pick a club first.", true)
		return
	hints.set_status("Creating career...", false)
	var club_id := int(_clubs[_club_index].get("id", 0))
	var nationality_id := int(_countries[_nationality_index].get("id", 0))
	var career := CareerFactory.create(
		_catalog, club_id, _manager_name, nationality_id, fixed_seed)
	if career == null:
		hints.set_status(CareerFactory.last_error, true)
		return
	var store := CareerSaveStore.new()
	if not store.save(career):
		hints.set_status(store.last_error, true)
		return
	CareerSession.career = career
	CareerSession.store = store
	CareerSession.catalog = _catalog
	UiTransition.change_scene(HUB_SCENE)


func _keyboard_hints() -> Array:
	if _step == "club":
		return [
			{"keys": ["UP", "DOWN"], "label": "move"},
			{"keys": ["LEFT", "RIGHT"], "label": "change"},
			{"keys": ["ENTER"], "label": "select club"},
			{"keys": ["ESC"], "label": "back"},
		]
	return [
		{"keys": ["UP", "DOWN"], "label": "move"},
		{"keys": ["LEFT", "RIGHT"], "label": "nationality"},
		{"keys": ["ENTER"], "label": "select"},
		{"keys": ["ESC"], "label": "back"},
	]


func _gamepad_hints() -> Array:
	if _step == "club":
		return [
			{"keys": ["D-PAD"], "label": "move"},
			{"keys": ["LEFT", "RIGHT"], "label": "change"},
			{"keys": ["A"], "label": "select club"},
			{"keys": ["B"], "label": "back"},
		]
	return [
		{"keys": ["D-PAD"], "label": "move"},
		{"keys": ["LEFT", "RIGHT"], "label": "nationality"},
		{"keys": ["A"], "label": "select"},
		{"keys": ["B"], "label": "back"},
	]


static func _format_value(value: int) -> String:
	if value >= 1000000000:
		return "€%.2fB" % (float(value) / 1000000000.0)
	if value >= 1000000:
		return "€%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "€%.0fK" % (float(value) / 1000.0)
	return "€%d" % value


static func _thousands(value: int) -> String:
	var text := str(value)
	var out := ""
	while text.length() > 3:
		out = " " + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out


static func _array_sum(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total

