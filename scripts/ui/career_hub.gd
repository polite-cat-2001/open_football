extends UiScreen
# Minimal career landing screen after create/load. Ticket 03 replaces this with
# the full Centre/Squad/Transfers/Scouting hub; until then it proves the loaded
# snapshot is real and gives the player a way back to the menu.

const START_SCENE := "res://scenes/career_start.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints

var _snapshot: Dictionary = {}
var _header: Panel
var _crest: TextureRect
var _name: Label
var _meta: Label
var _next_panel: Panel
var _next_title: Label
var _next_opponent: Label
var _next_meta: Label
var _squad_panel: Panel
var _squad_values: Array = []
var _exit_tile: BentoTile


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	var career := CareerSession.career
	if career == null or CareerSession.catalog == null:
		call_deferred("_leave", START_SCENE)
		return
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, career)
	if _snapshot.is_empty():
		call_deferred("_leave", START_SCENE)
		return
	_build()
	hints.setup(_keyboard_hints())
	UiNav.confirmed.connect(_on_confirmed)
	UiNav.cancelled.connect(_on_cancelled)
	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_focus_initial")


func _build() -> void:
	var club: Dictionary = _snapshot.get("club", {})
	var manager: Dictionary = _snapshot.get("manager", {})
	var season: Dictionary = _snapshot.get("season", {})

	_header = _panel()
	panel_wrap.add_child(_header)
	_crest = TextureRect.new()
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_header.add_child(_crest)
	var team := CareerSession.catalog.team_by_id(int(club.get("id", 0)))
	_crest.texture = UiAssets.usable_texture(UiAssets.team_logo(team))
	_name = _label(44, UiTheme.barlow(800), UiTokens.INK)
	_header.add_child(_name)
	_meta = _label(17, UiTheme.inter(500), UiTokens.INK_2)
	_header.add_child(_meta)

	_next_panel = _panel()
	panel_wrap.add_child(_next_panel)
	_next_title = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_next_panel.add_child(_next_title)
	_next_opponent = _label(34, UiTheme.barlow(800), UiTokens.INK)
	_next_panel.add_child(_next_opponent)
	_next_meta = _label(16, UiTheme.inter(500), UiTokens.INK_2)
	_next_panel.add_child(_next_meta)

	_squad_panel = _panel()
	panel_wrap.add_child(_squad_panel)
	var squad_title := _label(16, UiTheme.inter(600), UiTokens.INK_2)
	squad_title.text = "SQUAD"
	_squad_panel.add_child(squad_title)
	for index in range(4):
		var value := _label(30, UiTheme.barlow(700), UiTokens.INK)
		_squad_panel.add_child(value)
		_squad_values.append(value)

	_exit_tile = BentoTile.new()
	_exit_tile.name = "ExitTile"
	_exit_tile.title = "EXIT TO MENU"
	_exit_tile.subtitle = "Your career is saved"
	_exit_tile.meta = "ENTER · EXIT"
	_exit_tile.glyph_name = "exit"
	_exit_tile.wide = true
	_exit_tile.pressed.connect(_on_cancelled)
	panel_wrap.add_child(_exit_tile)

	_name.text = str(club.get("name", ""))
	_meta.text = "%s · %s · %s" % [
		str(manager.get("name", "")),
		str(club.get("league_name", "")),
		_date(str(_snapshot.get("date", ""))),
	]
	var next = season.get("next")
	if next is Dictionary:
		_next_title.text = "NEXT MATCH · ROUND %d" % int(next.get("round", 0))
		_next_opponent.text = str(next.get("opponent", {}).get("name", ""))
		_next_meta.text = "%s · %s" % [
			"HOME" if bool(next.get("home", false)) else "AWAY",
			_date(str(next.get("date", ""))),
		]
	else:
		_next_title.text = "NEXT MATCH"
		_next_opponent.text = "Season complete"
		_next_meta.text = ""
	var summary: Dictionary = _snapshot.get("squad", {}).get("summary", {})
	_squad_values[0].text = "SIZE %d" % int(summary.get("squad_size", 0))
	_squad_values[1].text = "OVR %.1f" % float(summary.get("average_overall", 0.0))
	_squad_values[2].text = "AGE %s" % str(summary.get("average_age", "-"))
	_squad_values[3].text = "VALUE €%.1fM" % (
		float(summary.get("total_market_value", 0)) / 1000000.0)
	hints.set_status("%s · SEASON %s" % [
		str(club.get("name", "")), _season_label(str(_snapshot.get("date", "")))])


func _panel() -> Panel:
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	panel.add_theme_stylebox_override(&"panel", box)
	return panel


func _label(size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	var hints_height := hints.height()
	var total := 170.0 + UiTokens.GAP + 240.0 + UiTokens.GAP + 160.0 + UiTokens.GAP \
		+ 112.0 + UiTokens.HINTS_GAP + hints_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)

	_header.position = Vector2.ZERO
	_header.size = Vector2(UiTokens.PANEL_W, 170.0)
	_crest.position = Vector2(24.0, 24.0)
	_crest.size = Vector2(120.0, 120.0)
	_name.position = Vector2(168.0, 28.0)
	_name.size = Vector2(UiTokens.PANEL_W - 200.0, 62.0)
	_meta.position = Vector2(168.0, 96.0)
	_meta.size = Vector2(UiTokens.PANEL_W - 200.0, 30.0)

	_next_panel.position = Vector2(0.0, 180.0)
	_next_panel.size = Vector2(735.0, 240.0)
	_next_title.position = Vector2(24.0, 22.0)
	_next_title.size = Vector2(687.0, 24.0)
	_next_opponent.position = Vector2(24.0, 58.0)
	_next_opponent.size = Vector2(687.0, 70.0)
	_next_meta.position = Vector2(24.0, 140.0)
	_next_meta.size = Vector2(687.0, 28.0)

	_squad_panel.position = Vector2(745.0, 180.0)
	_squad_panel.size = Vector2(735.0, 240.0)
	for index in range(_squad_values.size()):
		var label: Label = _squad_values[index]
		label.position = Vector2(24.0 + (index % 2) * 350.0, 26.0 + (index / 2) * 90.0)
		label.size = Vector2(320.0, 70.0)

	_exit_tile.set_base_rect(Rect2(Vector2(0.0, 430.0), Vector2(UiTokens.PANEL_W, 112.0)),
		Vector2.ZERO)
	hints.position = Vector2(0.0, 430.0 + 112.0 + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)


func _focus_initial() -> void:
	_exit_tile.grab_focus()


func _on_confirmed() -> void:
	_on_cancelled()


func _on_cancelled() -> void:
	_leave(MAIN_MENU_SCENE)


func _leave(path: String) -> void:
	UiTransition.change_scene(path)


func _keyboard_hints() -> Array:
	return [{"keys": ["ENTER"], "label": "exit"}, {"keys": ["ESC"], "label": "back"}]


func _season_label(date: String) -> String:
	if date.length() < 7:
		return date
	var year := int(date.substr(0, 4))
	var month := int(date.substr(5, 2))
	var start := year if month >= 7 else year - 1
	return "%d/%d" % [start, start + 1]


func _date(iso: String) -> String:
	return iso.substr(0, 10) if iso.length() >= 10 else iso
