extends UiScreen
# Career entry screen: Continue (latest compatible save), New Career, Load.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const NEW_SCENE := "res://scenes/career_new.tscn"
const LOAD_SCENE := "res://scenes/career_load.tscn"
const HUB_SCENE := "res://scenes/career_hub.tscn"

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var breadcrumb: UiBreadcrumb = $Design/PanelWrap/Breadcrumb
@onready var grid: BentoGrid = $Design/PanelWrap/Grid
@onready var continue_tile: BentoTile = $Design/PanelWrap/Grid/ContinueTile
@onready var new_tile: BentoTile = $Design/PanelWrap/Grid/NewCareerTile
@onready var load_tile: BentoTile = $Design/PanelWrap/Grid/LoadTile
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints

var _store: CareerSaveStore
var _catalog: TeamCatalog
var _latest: Career


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	breadcrumb.set_items(["GAMEPLAYFOOTBALL", "CAREER"])
	grid.add_cell(continue_tile, 1, 1, 2, 2)
	grid.add_cell(new_tile, 3, 1, 2, 1)
	grid.add_cell(load_tile, 3, 2, 2, 1)
	continue_tile.pressed.connect(_continue_latest)
	new_tile.pressed.connect(_open_scene.bind(NEW_SCENE))
	load_tile.pressed.connect(_open_scene.bind(LOAD_SCENE))
	hints.setup(_keyboard_hints())
	_refresh()
	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_open_scene.bind(MAIN_MENU_SCENE))
	UiNav.device_changed.connect(_on_device_changed)
	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_focus_initial")


func _refresh() -> void:
	_store = CareerSaveStore.new()
	_catalog = TeamCatalog.new()
	var loaded := _catalog.load_data_root()
	if not loaded:
		hints.set_status("Career database is unavailable.", true)
	if not _store.ensure_directory():
		hints.set_status(_store.last_error, true)
	var entries := _store.scan()
	_latest = null
	if loaded:
		for entry in entries:
			var career = entry.get("career")
			if career == null:
				continue
			if not _catalog.career_club(int(career.club_id)).is_empty():
				_latest = career
				break
	CareerSession.clear()
	CareerSession.store = _store
	CareerSession.catalog = _catalog

	if _latest != null:
		var club := _catalog.career_club(int(_latest.club_id))
		var team := _catalog.team_by_id(int(_latest.club_id))
		continue_tile.set_copy(
			"CONTINUE",
			"%s · %s" % [str(club.get("name", "")), _latest.manager.name],
			"LATEST SAVE · %s" % _timestamp(_latest.updated_at)
		)
		continue_tile.set_art(UiAssets.usable_texture(UiAssets.team_logo(team)))
		continue_tile.set_enabled(true)
	elif entries.is_empty():
		continue_tile.set_copy("CONTINUE", "Create a new career first", "NO SAVES")
		continue_tile.set_art(null)
		continue_tile.set_enabled(false)
	else:
		continue_tile.set_copy("CONTINUE", "No compatible saves", "CHECK LOAD")
		continue_tile.set_art(null)
		continue_tile.set_enabled(false)

	var count := entries.size()
	load_tile.set_copy(
		"LOAD",
		"No saves yet" if count == 0 else "%d %s" % [count, _career_word(count)],
		"CAREER LIST"
	)
	load_tile.set_enabled(count > 0)


func _focus_initial() -> void:
	if continue_tile.disabled:
		new_tile.grab_focus()
	else:
		continue_tile.grab_focus()


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	var hints_height := hints.height()
	var total := UiTokens.TAB_H + UiTokens.GAP + UiTokens.GRID_H + UiTokens.HINTS_GAP \
		+ hints_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)
	breadcrumb.position = Vector2.ZERO
	grid.position = Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP)
	grid.size = Vector2(UiTokens.PANEL_W, UiTokens.GRID_H)
	hints.position = Vector2(
		0.0, UiTokens.TAB_H + UiTokens.GAP + UiTokens.GRID_H + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)


func _on_nav_moved(direction: Vector2i) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus == continue_tile:
		if direction == Vector2i.RIGHT:
			new_tile.grab_focus()
		elif direction == Vector2i.DOWN:
			load_tile.grab_focus()
	elif focus == new_tile:
		if direction == Vector2i.LEFT:
			continue_tile.grab_focus()
		elif direction == Vector2i.DOWN:
			load_tile.grab_focus()
	elif focus == load_tile:
		if direction == Vector2i.LEFT:
			continue_tile.grab_focus()
		elif direction == Vector2i.UP:
			new_tile.grab_focus()
	else:
		_focus_initial()


func _on_nav_confirmed() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()


func _on_device_changed(_gamepad: bool) -> void:
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())


func _continue_latest() -> void:
	if _latest == null:
		return
	CareerSession.career = _latest
	UiTransition.change_scene(HUB_SCENE)


func _open_scene(path: String) -> void:
	UiTransition.change_scene(path)


func _keyboard_hints() -> Array:
	return [
		{"keys": ["ARROWS"], "label": "move"},
		{"keys": ["ENTER"], "label": "select"},
		{"keys": ["ESC"], "label": "back"},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["D-PAD"], "label": "move"},
		{"keys": ["A"], "label": "select"},
		{"keys": ["B"], "label": "back"},
	]


static func _timestamp(iso: String) -> String:
	return iso.substr(0, 16).replace("T", " ") if iso.length() >= 16 else iso


static func _career_word(count: int) -> String:
	return "career" if count == 1 else "careers"
