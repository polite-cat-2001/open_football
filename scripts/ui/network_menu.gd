extends UiScreen
# Network menu on the design system: two wide bento tiles (Host / Join), a
# PLAY > NETWORK breadcrumb and no Back button вЂ” Esc/B returns to the main menu.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const HOST_SCENE := "res://scenes/network_host.tscn"
const JOIN_SCENE := "res://scenes/network_join.tscn"

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var breadcrumb: UiBreadcrumb = $Design/PanelWrap/Breadcrumb
@onready var grid: BentoGrid = $Design/PanelWrap/Grid
@onready var host_tile: BentoTile = $Design/PanelWrap/Grid/HostTile
@onready var join_tile: BentoTile = $Design/PanelWrap/Grid/JoinTile
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints

var _tiles: Array = []


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	_tiles = [host_tile, join_tile]
	breadcrumb.set_items(["PLAY", "NETWORK"])
	grid.add_cell(host_tile, 1, 1, 2, 2)
	grid.add_cell(join_tile, 3, 1, 2, 2)
	host_tile.pressed.connect(_open_scene.bind(HOST_SCENE))
	join_tile.pressed.connect(_open_scene.bind(JOIN_SCENE))
	hints.setup(_keyboard_hints())
	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_on_nav_cancelled)
	UiNav.device_changed.connect(_on_device_changed)
	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_focus_initial")


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	var hints_height := hints.height()
	var tile_height := UiTokens.WIDE_TILE_H
	var total := UiTokens.TAB_H + UiTokens.GAP + tile_height + UiTokens.HINTS_GAP \
		+ hints_height

	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)
	breadcrumb.position = Vector2.ZERO
	grid.position = Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP)
	grid.size = Vector2(UiTokens.PANEL_W, tile_height)
	hints.position = Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP + tile_height + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)


func _focus_initial() -> void:
	host_tile.grab_focus()


func _on_nav_moved(direction: Vector2i) -> void:
	if UiNav.is_modal():
		return
	if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
		var focus := get_viewport().gui_get_focus_owner()
		var index := _tiles.find(focus)
		if index < 0:
			index = 0
		index = posmod(index + (-1 if direction == Vector2i.LEFT else 1), _tiles.size())
		_tiles[index].grab_focus()


func _on_nav_confirmed() -> void:
	if UiNav.is_modal():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()


func _on_nav_cancelled() -> void:
	_open_scene(MAIN_MENU_SCENE)


func _on_device_changed(_gamepad: bool) -> void:
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())


func _open_scene(path: String) -> void:
	UiTransition.change_scene(path)


func _keyboard_hints() -> Array:
	return [
		{"keys": ["в†ђ", "в†’"], "label": "select"},
		{"keys": ["ENTER"], "label": "open"},
		{"keys": ["ESC"], "label": "back"},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["D-PAD"], "label": "select"},
		{"keys": ["A"], "label": "open"},
		{"keys": ["B"], "label": "back"},
	]

