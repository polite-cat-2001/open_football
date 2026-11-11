extends UiScreen
# Career hub: the prototype's tabbed shell (Centre / Squad / Transfers /
# Scouting) with the Centre dashboard, save and exit. Only the Centre tab is
# built; the other tabs show the shared "in progress" panel until their
# tickets land. Input goes through UiNav; the active tab is saved in the career.

const START_SCENE := "res://scenes/career_start.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

enum Zone { TABS, GRID }

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var body: Control = $Design/PanelWrap/Body
@onready var tab_bar: UiTabBar = $Design/PanelWrap/Body/TabBar
@onready var grid: BentoGrid = $Design/PanelWrap/Body/Grid
@onready var next_tile: CareerHubNextTile = $Design/PanelWrap/Body/Grid/NextTile
@onready var table_tile: CareerHubTableTile = $Design/PanelWrap/Body/Grid/TableTile
@onready var transfer_tile: BentoTile = $Design/PanelWrap/Body/Grid/TransferTile
@onready var news_tile: BentoTile = $Design/PanelWrap/Body/Grid/NewsTile
@onready var training_tile: BentoTile = $Design/PanelWrap/Body/Grid/TrainingTile
@onready var placeholder: UiMenuPanel = $Design/PanelWrap/Body/Placeholder
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
@onready var overlay: CareerHubOverlay = $Design/Overlay

var _snapshot: Dictionary = {}
var _career: Career
var _zone := Zone.GRID
var _tab := 0
var _busy := false


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	_career = CareerSession.career
	if _career == null or CareerSession.catalog == null:
		call_deferred("_leave", START_SCENE)
		return
	_snapshot = CareerFactory.snapshot(CareerSession.catalog, _career)
	if _snapshot.is_empty():
		call_deferred("_leave", START_SCENE)
		return

	overlay.z_index = 10
	hints.z_index = 20
	tab_bar.setup(CareerHubModel.TABS)
	tab_bar.tab_selected.connect(_on_tab_selected)
	tab_bar.bar_focused.connect(_on_bar_focused)
	grid.add_cell(next_tile, 1, 1, 2, 1)
	grid.add_cell(table_tile, 3, 1, 2, 1)
	grid.add_cell(transfer_tile, 1, 2)
	grid.add_cell(news_tile, 2, 2, 2, 1)
	grid.add_cell(training_tile, 4, 2)
	for tile in [transfer_tile, news_tile, training_tile]:
		tile.focus_mode = Control.FOCUS_NONE
	next_tile.pressed.connect(_on_next_pressed)
	table_tile.pressed.connect(_open_overlay)
	next_tile.focus_entered.connect(_on_tile_focused)
	table_tile.focus_entered.connect(_on_tile_focused)
	_apply_snapshot()

	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_on_nav_cancelled)
	UiNav.tab_previous.connect(_on_nav_tab_previous)
	UiNav.tab_next.connect(_on_nav_tab_next)
	UiNav.device_changed.connect(_on_device_changed)

	_tab = maxi(0, CareerHubModel.TAB_IDS.find(_career.hub_tab))
	tab_bar.select_tab(_tab, false)
	_apply_tab()
	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_focus_initial")


func _apply_snapshot() -> void:
	next_tile.setup(CareerHubModel.next_tile(_snapshot))
	table_tile.setup(CareerHubModel.table_tile(_snapshot))


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	var hints_height := hints.height()
	var total := UiTokens.TAB_H + UiTokens.GAP + UiTokens.GRID_H \
		+ UiTokens.HINTS_GAP + hints_height
	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)
	var content_top := UiTokens.TAB_H + UiTokens.GAP
	body.position = Vector2.ZERO
	body.size = Vector2(UiTokens.PANEL_W, content_top + UiTokens.GRID_H)
	tab_bar.position = Vector2.ZERO
	tab_bar.fit_width()
	grid.position = Vector2(0.0, content_top)
	grid.size = Vector2(UiTokens.PANEL_W, UiTokens.GRID_H)
	placeholder.position = grid.position
	placeholder.size = grid.size
	hints.position = Vector2(0.0, content_top + UiTokens.GRID_H + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)
	# The overlay is a full shell replacement: it covers the tabs too, like the
	# prototype hides the hub while a tournament/match screen is open.
	overlay.layout_overlay(Rect2(panel_wrap.position, body.size))


func _focus_initial() -> void:
	if _tab == 0:
		next_tile.grab_focus()
		_zone = Zone.GRID
	else:
		tab_bar.focus_tab(_tab)
		_zone = Zone.TABS


func _apply_tab() -> void:
	var centre := _tab == 0
	grid.visible = centre
	placeholder.visible = not centre
	if not centre:
		placeholder.setup("%s arrives in a later build." % CareerHubModel.TABS[_tab], [])
	_update_hints()


func _on_tab_selected(index: int) -> void:
	_tab = index
	if _career != null:
		_career.hub_tab = CareerHubModel.TAB_IDS[index]
	_apply_tab()
	if _zone == Zone.GRID:
		_focus_first_tile()


func _on_bar_focused() -> void:
	_zone = Zone.TABS


func _on_tile_focused() -> void:
	_zone = Zone.GRID


func _cycle_tab(delta: int) -> void:
	var next := posmod(_tab + delta, CareerHubModel.TABS.size())
	_tab = next
	if _career != null:
		_career.hub_tab = CareerHubModel.TAB_IDS[next]
	tab_bar.select_tab(next, false)
	_apply_tab()
	if _zone == Zone.GRID:
		_focus_first_tile()
	else:
		tab_bar.focus_tab(next)


func _focus_first_tile() -> void:
	if _tab == 0:
		next_tile.grab_focus()
		_zone = Zone.GRID
	else:
		tab_bar.focus_tab(_tab)
		_zone = Zone.TABS


func _focus_active_tab() -> void:
	tab_bar.focus_tab(_tab)
	_zone = Zone.TABS


func _on_nav_moved(direction: Vector2i) -> void:
	if _busy:
		return
	if overlay.is_open():
		if direction == Vector2i.UP or direction == Vector2i.DOWN:
			overlay.scroll_step(-1 if direction == Vector2i.UP else 1)
		return
	if _zone == Zone.TABS:
		if direction == Vector2i.LEFT:
			_cycle_tab(-1)
		elif direction == Vector2i.RIGHT:
			_cycle_tab(1)
		elif direction == Vector2i.DOWN:
			_focus_first_tile()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if direction == Vector2i.UP:
		_focus_active_tab()
	elif focus == next_tile and direction == Vector2i.RIGHT:
		table_tile.grab_focus()
	elif focus == table_tile and direction == Vector2i.LEFT:
		next_tile.grab_focus()


func _on_nav_confirmed() -> void:
	if _busy or overlay.is_open():
		return
	if _zone == Zone.TABS:
		_focus_first_tile()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()


func _on_nav_cancelled() -> void:
	if _busy:
		return
	if overlay.is_open():
		_close_overlay()
		return
	if UiNav.event_was_modal():
		return
	if _tab != 0:
		_cycle_tab(-_tab)
		return
	_exit()


func _on_nav_tab_previous() -> void:
	if _busy or overlay.is_open():
		return
	_cycle_tab(-1)


func _on_nav_tab_next() -> void:
	if _busy or overlay.is_open():
		return
	_cycle_tab(1)


func _on_device_changed(_gamepad: bool) -> void:
	if overlay.is_open():
		hints.setup(_overlay_hints())
		return
	_update_hints()


func _input(event: InputEvent) -> void:
	if _busy or overlay.is_open() or UiNav.is_modal():
		return
	var wants_save := false
	if event is InputEventKey:
		var key := event as InputEventKey
		wants_save = key.pressed and not key.echo and (
			key.keycode == KEY_S or key.physical_keycode == KEY_S)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		wants_save = button.pressed and button.button_index == JOY_BUTTON_START
	if wants_save:
		get_viewport().set_input_as_handled()
		_save()


func _on_next_pressed() -> void:
	var next = _snapshot.get("season", {}).get("next")
	if not (next is Dictionary):
		hints.set_status("The season is complete.")
		return
	if str(_snapshot.get("date", "")) >= str(next.get("date", "")):
		hints.set_status("Match day · the match screen arrives in the next build.")
		return
	hints.set_status("Next match · %s · round %d" % [
		CareerHubModel.short_date(str(next.get("date", ""))),
		int(next.get("round", 0)),
	])


func _open_overlay() -> void:
	if overlay.is_open() or _busy:
		return
	_busy = true
	overlay.setup(CareerHubModel.overlay(_snapshot))
	hints.setup(_overlay_hints())
	await _fade_out(body)
	body.visible = false
	overlay.open()
	await _fade_in(overlay.card())
	_busy = false


func _close_overlay() -> void:
	if not overlay.is_open() or _busy:
		return
	_busy = true
	overlay.close()
	await _fade_out(overlay.card())
	overlay.hide_card()
	body.visible = true
	await _fade_in(body)
	_update_hints()
	table_tile.grab_focus()
	_zone = Zone.GRID
	_busy = false


func _fade_out(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	if UiTransition.instant:
		node.modulate.a = 0.0
		node.scale = Vector2.ONE * UiTransition.SCALE_FROM
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, UiTransition.OUT_TIME)
	tween.tween_property(node, "scale", Vector2.ONE * UiTransition.SCALE_FROM,
		UiTransition.OUT_TIME)
	await tween.finished


func _fade_in(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	if UiTransition.instant:
		node.modulate.a = 1.0
		node.scale = Vector2.ONE
		return
	node.modulate.a = 0.0
	node.scale = Vector2.ONE * UiTransition.SCALE_FROM
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, UiTransition.IN_TIME)
	tween.tween_property(node, "scale", Vector2.ONE, UiTransition.IN_TIME)
	await tween.finished


func _save() -> bool:
	if _career == null:
		return false
	_career.touch()
	var store := CareerSession.store if CareerSession.store != null else CareerSaveStore.new()
	if not store.save(_career):
		hints.set_status(store.last_error, true)
		return false
	CareerSession.store = store
	hints.set_status("Career saved · %s" % _timestamp(_career.updated_at))
	return true


func _exit() -> void:
	if not _save():
		return
	CareerSession.clear()
	_leave(MAIN_MENU_SCENE)


func _leave(path: String) -> void:
	UiTransition.change_scene(path)


func _update_hints() -> void:
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())


func _keyboard_hints() -> Array:
	return [
		{"keys": ["Q", "E"], "label": "tabs"},
		{"keys": ["ENTER"], "label": "select"},
		{"keys": ["ESC"], "label": "menu"},
		{"keys": ["S"], "label": "save"},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["LB", "RB"], "label": "tabs"},
		{"keys": ["A"], "label": "select"},
		{"keys": ["B"], "label": "menu"},
		{"keys": ["START"], "label": "save"},
	]


func _overlay_hints() -> Array:
	if UiNav.using_gamepad():
		return [
			{"keys": ["L-STICK"], "label": "scroll"},
			{"keys": ["B"], "label": "back"},
		]
	return [
		{"keys": ["↑", "↓"], "label": "scroll"},
		{"keys": ["ESC"], "label": "back"},
	]


static func _timestamp(iso: String) -> String:
	return iso.substr(0, 16).replace("T", " ") if iso.length() >= 16 else iso
