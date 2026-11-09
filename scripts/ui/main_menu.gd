extends UiScreen

# Main menu: shared stage + 1920x1080 design surface with the prototype's bento
# menu, driven by the shared UiNav router (keyboard, gamepad, mouse).

const CONTROLLER_SCENE := "res://scenes/controller_select.tscn"
const NETWORK_SCENE := "res://scenes/network_menu.tscn"

const PLAY_TAB := 0
const SETTINGS_TAB := 1

const SETTINGS_NOTES := {
	"GAMEPLAY": "Difficulty, assists and match length.",
	"CONTROLS": "Keyboard layout and gamepad functions.",
	"GRAPHICS": "Resolution, quality and effects.",
	"AUDIO": "Music, commentary and effects.",
}

enum Zone { GRID, TABS, PANEL }

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var tab_bar: UiTabBar = $Design/PanelWrap/TabBar
@onready var play_grid: BentoGrid = $Design/PanelWrap/PlayGrid
@onready var settings_grid: BentoGrid = $Design/PanelWrap/SettingsGrid
@onready var breadcrumb: UiBreadcrumb = $Design/PanelWrap/Breadcrumb
@onready var menu_panel: UiMenuPanel = $Design/PanelWrap/MenuPanel
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
@onready var brand: HBoxContainer = $Design/Brand
@onready var quick_tile: BentoTile = $Design/PanelWrap/PlayGrid/QuickMatchTile
@onready var continue_tile: BentoTile = $Design/PanelWrap/PlayGrid/ContinueCareerTile
@onready var career_tile: BentoTile = $Design/PanelWrap/PlayGrid/CareerTile
@onready var network_tile: BentoTile = $Design/PanelWrap/PlayGrid/NetworkTile
@onready var gameplay_tile: BentoTile = $Design/PanelWrap/SettingsGrid/GameplayTile
@onready var controls_tile: BentoTile = $Design/PanelWrap/SettingsGrid/ControlsTile
@onready var graphics_tile: BentoTile = $Design/PanelWrap/SettingsGrid/GraphicsTile
@onready var audio_tile: BentoTile = $Design/PanelWrap/SettingsGrid/AudioTile

var _zone := Zone.GRID
var _panel_open := false
var _panel_opener: BentoTile
var _last_tab := PLAY_TAB


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	SettingsStore.apply_graphics()
	SettingsStore.apply_audio()

	_setup_grids()
	tab_bar.setup(["PLAY", "SETTINGS"])
	tab_bar.tab_selected.connect(_on_tab_selected)
	tab_bar.bar_focused.connect(_on_bar_focused)
	hints.setup(_keyboard_hints())

	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_on_nav_cancelled)
	UiNav.tab_previous.connect(_on_nav_tab_previous)
	UiNav.tab_next.connect(_on_nav_tab_next)
	UiNav.device_changed.connect(_on_device_changed)

	quick_tile.pressed.connect(_open_scene.bind(CONTROLLER_SCENE))
	network_tile.pressed.connect(_open_scene.bind(NETWORK_SCENE))
	for tile in [gameplay_tile, controls_tile, graphics_tile, audio_tile]:
		tile.pressed.connect(_open_settings_panel.bind(tile))
	for tile in [quick_tile, continue_tile, career_tile, network_tile,
			gameplay_tile, controls_tile, graphics_tile, audio_tile]:
		tile.focus_entered.connect(_on_tile_focused)

	_layout()
	get_viewport().size_changed.connect(_layout)
	brand.resized.connect(_position_brand)
	call_deferred("_focus_initial")


func _setup_grids() -> void:
	play_grid.add_cell(quick_tile, 1, 1, 2, 2)
	play_grid.add_cell(continue_tile, 3, 1, 2, 1)
	play_grid.add_cell(career_tile, 3, 2, 1, 1)
	play_grid.add_cell(network_tile, 4, 2, 1, 1)

	settings_grid.add_cell(gameplay_tile, 1, 1, 2, 1)
	settings_grid.add_cell(controls_tile, 3, 1, 2, 1)
	settings_grid.add_cell(graphics_tile, 1, 2, 2, 1)
	settings_grid.add_cell(audio_tile, 3, 2, 2, 1)


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	_apply_view_state()
	_position_brand()


func _apply_view_state() -> void:
	var active_tab := tab_bar.get_active_tab()
	if _panel_open:
		tab_bar.visible = false
		play_grid.visible = false
		settings_grid.visible = false
		breadcrumb.visible = true
		menu_panel.visible = true
	else:
		tab_bar.visible = true
		play_grid.visible = active_tab == PLAY_TAB
		settings_grid.visible = active_tab == SETTINGS_TAB
		breadcrumb.visible = false
		menu_panel.visible = false

	var hints_height := hints.height()
	var panel_x := (UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5

	if _panel_open:
		var content_height := menu_panel.content_height()
		var block_height := UiTokens.TAB_H + UiTokens.GAP + content_height + UiTokens.HINTS_GAP + hints_height
		var panel_top := (UiTokens.DESIGN_SIZE.y - block_height) * 0.5
		panel_wrap.position = Vector2(panel_x, panel_top)
		panel_wrap.size = Vector2(UiTokens.PANEL_W, block_height)
		breadcrumb.position = Vector2.ZERO
		menu_panel.position = Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP)
		menu_panel.size = Vector2(UiTokens.PANEL_W, content_height)
		hints.position = Vector2(
			0.0,
			UiTokens.TAB_H + UiTokens.GAP + content_height + UiTokens.HINTS_GAP
		)

		hints.size = Vector2(UiTokens.PANEL_W, hints_height)
		_update_focus_chain()
		return

	var total_height := UiTokens.TAB_H + UiTokens.GAP + UiTokens.GRID_H + UiTokens.HINTS_GAP + hints_height
	var top := (UiTokens.DESIGN_SIZE.y - total_height) * 0.5
	panel_wrap.position = Vector2(panel_x, top)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total_height)

	tab_bar.position = Vector2.ZERO
	tab_bar.size = Vector2(UiTokens.PANEL_W, UiTokens.TAB_H)
	tab_bar.refresh_layout()

	var grid_position := Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP)
	var grid_size := Vector2(UiTokens.PANEL_W, UiTokens.GRID_H)
	play_grid.position = grid_position
	play_grid.size = grid_size
	settings_grid.position = grid_position
	settings_grid.size = grid_size

	breadcrumb.position = Vector2.ZERO
	menu_panel.position = grid_position
	menu_panel.size = grid_size

	hints.position = Vector2(0.0, grid_position.y + UiTokens.GRID_H + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)
	_update_focus_chain()


func _position_brand() -> void:
	brand.size = brand.get_combined_minimum_size()
	brand.position = Vector2(
		UiTokens.DESIGN_SIZE.x - UiTokens.SAFE - brand.size.x,
		UiTokens.DESIGN_SIZE.y - 18.0 - brand.size.y
	)


func _focus_initial() -> void:
	tab_bar.select_tab(PLAY_TAB, false)
	_apply_view_state()
	quick_tile.grab_focus()
	_zone = Zone.GRID


func _update_focus_chain() -> void:
	var tab_play := tab_bar.get_tab_button(PLAY_TAB)
	var tab_settings := tab_bar.get_tab_button(SETTINGS_TAB)
	if tab_play == null or tab_settings == null:
		return

	tab_play.focus_next = tab_play.get_path_to(tab_settings)
	tab_play.focus_neighbor_right = tab_play.get_path_to(tab_settings)
	tab_settings.focus_neighbor_left = tab_settings.get_path_to(tab_play)

	if tab_bar.get_active_tab() == PLAY_TAB:
		tab_settings.focus_next = tab_settings.get_path_to(quick_tile)
		tab_play.focus_neighbor_bottom = tab_play.get_path_to(quick_tile)
		tab_settings.focus_neighbor_bottom = tab_settings.get_path_to(quick_tile)
		quick_tile.focus_next = quick_tile.get_path_to(network_tile)
		quick_tile.focus_neighbor_right = quick_tile.get_path_to(network_tile)
		quick_tile.focus_neighbor_top = quick_tile.get_path_to(tab_play)
		network_tile.focus_next = network_tile.get_path_to(tab_play)
		network_tile.focus_neighbor_left = network_tile.get_path_to(quick_tile)
		network_tile.focus_neighbor_top = network_tile.get_path_to(tab_play)
	else:
		tab_settings.focus_next = tab_settings.get_path_to(gameplay_tile)
		tab_play.focus_neighbor_bottom = tab_play.get_path_to(gameplay_tile)
		tab_settings.focus_neighbor_bottom = tab_settings.get_path_to(gameplay_tile)
		gameplay_tile.focus_next = gameplay_tile.get_path_to(controls_tile)
		controls_tile.focus_next = controls_tile.get_path_to(graphics_tile)
		graphics_tile.focus_next = graphics_tile.get_path_to(audio_tile)
		audio_tile.focus_next = audio_tile.get_path_to(tab_play)
		gameplay_tile.focus_neighbor_right = gameplay_tile.get_path_to(controls_tile)
		controls_tile.focus_neighbor_left = controls_tile.get_path_to(gameplay_tile)
		graphics_tile.focus_neighbor_right = graphics_tile.get_path_to(audio_tile)
		audio_tile.focus_neighbor_left = audio_tile.get_path_to(graphics_tile)
		gameplay_tile.focus_neighbor_bottom = gameplay_tile.get_path_to(graphics_tile)
		graphics_tile.focus_neighbor_top = graphics_tile.get_path_to(gameplay_tile)
		controls_tile.focus_neighbor_bottom = controls_tile.get_path_to(audio_tile)
		audio_tile.focus_neighbor_top = audio_tile.get_path_to(controls_tile)
		gameplay_tile.focus_neighbor_top = gameplay_tile.get_path_to(tab_settings)
		controls_tile.focus_neighbor_top = controls_tile.get_path_to(tab_settings)
		graphics_tile.focus_neighbor_top = graphics_tile.get_path_to(gameplay_tile)
		audio_tile.focus_neighbor_top = audio_tile.get_path_to(controls_tile)


func _on_nav_moved(direction: Vector2i) -> void:
	if _panel_open:
		menu_panel.move_focus(direction)
		return

	if _zone == Zone.TABS:
		if direction == Vector2i.LEFT:
			_switch_tab(-1)
		elif direction == Vector2i.RIGHT:
			_switch_tab(1)
		elif direction == Vector2i.DOWN:
			_focus_first_tile()
		return

	_move_in_grid(direction)


func _focus_active_tab() -> void:
	tab_bar.focus_tab(tab_bar.get_active_tab())
	_zone = Zone.TABS


func _move_in_grid(direction: Vector2i) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if tab_bar.get_active_tab() == PLAY_TAB:
		if focus == quick_tile:
			if direction == Vector2i.UP:
				_focus_active_tab()
			elif direction == Vector2i.RIGHT or direction == Vector2i.DOWN:
				network_tile.grab_focus()
		elif focus == network_tile:
			if direction == Vector2i.UP or direction == Vector2i.LEFT:
				quick_tile.grab_focus()
		else:
			quick_tile.grab_focus()
	else:
		var order := [gameplay_tile, controls_tile, graphics_tile, audio_tile]
		var index := order.find(focus)
		if index == -1:
			order[0].grab_focus()
			return
		var target := index
		if direction == Vector2i.LEFT and index in [1, 3]:
			target = index - 1
		elif direction == Vector2i.RIGHT and index in [0, 2]:
			target = index + 1
		elif direction == Vector2i.UP and index in [2, 3]:
			target = index - 2
		elif direction == Vector2i.UP:
			_focus_active_tab()
			return
		elif direction == Vector2i.DOWN and index in [0, 1]:
			target = index + 2
		if target != index:
			order[target].grab_focus()


func _on_nav_confirmed() -> void:
	if _panel_open:
		menu_panel.activate_focused()
		return
	if _zone == Zone.TABS:
		_focus_first_tile()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()


func _on_nav_cancelled() -> void:
	if _panel_open:
		_close_panel()


func _on_nav_tab_previous() -> void:
	if not _panel_open:
		_switch_tab(-1)


func _on_nav_tab_next() -> void:
	if not _panel_open:
		_switch_tab(1)


func _switch_tab(delta: int) -> void:
	var count := 2
	var next := posmod(tab_bar.get_active_tab() + delta, count)
	tab_bar.select_tab(next)
	if _zone == Zone.TABS:
		tab_bar.focus_tab(next)
	else:
		_focus_first_tile()


func _focus_first_tile() -> void:
	if tab_bar.get_active_tab() == PLAY_TAB:
		quick_tile.grab_focus()
	else:
		gameplay_tile.grab_focus()
	_zone = Zone.GRID


func _on_tab_selected(index: int) -> void:
	var direction := signi(index - _last_tab)
	_last_tab = index
	_apply_view_state()
	if _zone == Zone.GRID:
		_focus_first_tile()
	if direction != 0:
		var grid := play_grid if index == PLAY_TAB else settings_grid
		grid.play_entrance(direction)


func _on_bar_focused() -> void:
	_zone = Zone.TABS


func _on_tile_focused() -> void:
	_zone = Zone.GRID


func _open_settings_panel(tile: BentoTile) -> void:
	if _panel_open:
		return
	UiTransition.change_content(panel_wrap, _apply_open_panel.bind(tile))


func _apply_open_panel(tile: BentoTile) -> void:
	_panel_open = true
	_panel_opener = tile
	breadcrumb.set_items(["PLAY", "SETTINGS", tile.title])
	menu_panel.setup(String(SETTINGS_NOTES.get(tile.title, "")), [])
	_apply_view_state()
	_zone = Zone.PANEL
	if menu_panel.has_rows():
		menu_panel.focus_first()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null:
			focus.release_focus()


func _close_panel() -> void:
	if not _panel_open:
		return
	UiTransition.change_content(panel_wrap, _apply_close_panel)


func _apply_close_panel() -> void:
	_panel_open = false
	_apply_view_state()
	if _panel_opener != null:
		_panel_opener.grab_focus()
		_panel_opener = null
	_zone = Zone.GRID


func _on_device_changed(gamepad: bool) -> void:
	hints.setup(_gamepad_hints() if gamepad else _keyboard_hints())
	_apply_view_state()


func _keyboard_hints() -> Array:
	return [
		{"keys": ["←", "↑", "↓", "→"], "label": "move"},
		{"keys": ["ENTER"], "label": "select"},
		{"keys": ["ESC"], "label": "back"},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["D-PAD"], "label": "move"},
		{"keys": ["A"], "label": "select"},
		{"keys": ["B"], "label": "back"},
		{"keys": ["LB/RB"], "label": "tabs"},
	]


func _open_scene(path: String) -> void:
	UiTransition.change_scene(path)

