extends UiScreen
# Load screen: the prototype's save list (club, manager, date, season).

const START_SCENE := "res://scenes/career_start.tscn"
const HUB_SCENE := "res://scenes/career_hub.tscn"
const UI_MODAL := preload("res://scripts/ui/ui_modal.gd")

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var breadcrumb: UiBreadcrumb = $Design/PanelWrap/Breadcrumb
@onready var body: Control = $Design/PanelWrap/Body
@onready var scroll: ScrollContainer = $Design/PanelWrap/Body/Scroll
@onready var rows_box: VBoxContainer = $Design/PanelWrap/Body/Scroll/Rows
@onready var empty: Panel = $Design/PanelWrap/Body/Empty
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints

var _store: CareerSaveStore
var _catalog: TeamCatalog
var _entries: Array = []
var _rows: Array = []
var _focus_index := 0
var _delete_modal


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	breadcrumb.set_items(["CAREER", "LOAD"])
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	empty.add_theme_stylebox_override(&"panel", box)
	hints.setup(_keyboard_hints())
	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_back)
	UiNav.device_changed.connect(_on_device_changed)
	_delete_modal = UI_MODAL.new()
	_delete_modal.name = "DeleteModal"
	add_child(_delete_modal)
	_delete_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_delete_modal.action_chosen.connect(_on_delete_action)
	_delete_modal.closed.connect(_on_delete_closed)
	_refresh()
	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_focus_initial")


func _refresh() -> void:
	_store = CareerSession.store if CareerSession.store != null else CareerSaveStore.new()
	_catalog = CareerSession.catalog if CareerSession.catalog != null else TeamCatalog.new()
	if not _catalog.is_loaded():
		_catalog.load_data_root()
	_entries = CareerFactory.list_entries(_store, _catalog)
	empty.visible = _entries.is_empty()
	scroll.visible = not _entries.is_empty()
	for row in _rows:
		rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	if _entries.is_empty():
		hints.set_status("0 saves", false)
		return

	var first_loadable := -1
	for index in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		var row := CareerRow.new()
		row.title_size = 26
		row.custom_minimum_size.y = 88.0
		var detail := ""
		var meta := ""
		if bool(entry.get("compatible", false)):
			detail = "SEASON %s · CAREER DATE %s" % [
				_season_label(str(entry.get("date", ""))),
				_date(str(entry.get("date", ""))),
			]
			meta = "UPDATED %s" % _timestamp(str(entry.get("updated_at", "")))
			if first_loadable < 0:
				first_loadable = index
		else:
			detail = str(entry.get("problem", ""))
			meta = "INCOMPATIBLE · VERSION %d" % int(entry.get("version", 0))
		var tags: Array = []
		for value in [entry.get("league_name", ""), entry.get("country_name", "")]:
			if not str(value).is_empty():
				tags.append(str(value))
		row.set_content(
			str(entry.get("club_name", "")),
			str(entry.get("manager_name", "")),
			meta,
			" · ".join(tags),
			detail
		)
		var team: Dictionary = entry.get("club", {})
		if not team.is_empty():
			row.set_lead(UiAssets.usable_texture(UiAssets.team_logo(team)))
		var league: Dictionary = entry.get("league", {})
		if not league.is_empty():
			row.set_league_lead(UiAssets.usable_texture(UiAssets.league_logo(league)))
		row.pressed.connect(_load_entry.bind(index))
		row.focus_entered.connect(_on_row_focused.bind(index, row))
		rows_box.add_child(row)
		_rows.append(row)
	_focus_index = maxi(first_loadable, 0)
	hints.set_status("%d %s" % [_entries.size(), "career" if _entries.size() == 1 else "careers"])


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
	body.position = Vector2(0.0, UiTokens.TAB_H + UiTokens.GAP)
	body.size = Vector2(UiTokens.PANEL_W, UiTokens.GRID_H)
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(UiTokens.PANEL_W - 6.0, UiTokens.GRID_H)
	empty.position = Vector2.ZERO
	empty.size = Vector2(UiTokens.PANEL_W, 160.0)
	hints.position = Vector2(
		0.0, UiTokens.TAB_H + UiTokens.GAP + UiTokens.GRID_H + UiTokens.HINTS_GAP)
	hints.size = Vector2(UiTokens.PANEL_W, hints_height)


func _focus_initial() -> void:
	if _rows.is_empty():
		return
	_focus_index = clampi(_focus_index, 0, _rows.size() - 1)
	_rows[_focus_index].grab_focus()
	scroll.ensure_control_visible(_rows[_focus_index])


func _on_row_focused(index: int, row: Control) -> void:
	_focus_index = index
	scroll.ensure_control_visible(row)


func _on_nav_moved(direction: Vector2i) -> void:
	if _delete_modal.is_open():
		_delete_modal.move_focus(direction)
		return
	if UiNav.is_modal() or UiNav.event_was_modal():
		return
	if _rows.is_empty():
		return
	if direction != Vector2i.UP and direction != Vector2i.DOWN:
		return
	var step := -1 if direction == Vector2i.UP else 1
	_focus_index = posmod(_focus_index + step, _rows.size())
	_rows[_focus_index].grab_focus()
	scroll.ensure_control_visible(_rows[_focus_index])


func _on_nav_confirmed() -> void:
	if _delete_modal.is_open():
		_delete_modal.activate_focused()
		return
	if UiNav.is_modal() or UiNav.event_was_modal():
		return
	if _rows.is_empty():
		return
	_rows[_focus_index].pressed.emit()


func _input(event: InputEvent) -> void:
	if _delete_modal == null or _delete_modal.is_open() or UiNav.is_modal():
		return
	var wants_delete := false
	if event is InputEventKey:
		var key := event as InputEventKey
		wants_delete = key.pressed and not key.echo and (
			key.keycode == KEY_DELETE or key.physical_keycode == KEY_DELETE)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		wants_delete = button.pressed and button.button_index == JOY_BUTTON_X
	if wants_delete:
		get_viewport().set_input_as_handled()
		_open_delete()


func _open_delete() -> void:
	if _rows.is_empty():
		return
	var entry: Dictionary = _entries[_focus_index]
	var confirm_key := "A" if UiNav.using_gamepad() else "ENTER"
	var cancel_key := "B" if UiNav.using_gamepad() else "ESC"
	_delete_modal.open(
		"Are you sure you want to delete this career save?\n\n%s — %s. This cannot be undone." % [
			str(entry.get("club_name", "")), str(entry.get("manager_name", "")),
		],
		[
			{"id": "delete", "label": "DELETE CAREER", "key": confirm_key},
			{"id": "cancel", "label": "CANCEL", "key": cancel_key},
		]
	)
	hints.setup(_modal_hints())


func _on_delete_action(id: String) -> void:
	if id == "delete":
		_delete_focused()
	_delete_modal.close()


func _delete_focused() -> void:
	if _entries.is_empty():
		return
	var entry: Dictionary = _entries[_focus_index]
	if not _store.delete(str(entry.get("id", ""))):
		hints.set_status(_store.last_error, true)
		return
	_refresh()
	_focus_index = clampi(_focus_index, 0, maxi(0, _rows.size() - 1))


func _on_delete_closed() -> void:
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())
	if _rows.is_empty():
		hints.set_status("0 saves", false)
		return
	_focus_index = clampi(_focus_index, 0, _rows.size() - 1)
	_rows[_focus_index].grab_focus()
	scroll.ensure_control_visible(_rows[_focus_index])


func _on_device_changed(_gamepad: bool) -> void:
	if _delete_modal != null and _delete_modal.is_open():
		hints.setup(_modal_hints())
		return
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())


func _load_entry(index: int) -> void:
	var entry: Dictionary = _entries[index]
	if not bool(entry.get("compatible", false)):
		hints.set_status(str(entry.get("problem", "This save cannot be loaded.")), true)
		return
	var career := _store.load_career(str(entry.get("id", "")))
	if career == null:
		hints.set_status(_store.last_error, true)
		return
	CareerSession.career = career
	CareerSession.store = _store
	CareerSession.catalog = _catalog
	UiTransition.change_scene(HUB_SCENE)


func _back() -> void:
	if _delete_modal != null and _delete_modal.is_open():
		_delete_modal.close()
		return
	if UiNav.event_was_modal():
		return
	UiTransition.change_scene(START_SCENE)


func _keyboard_hints() -> Array:
	return [
		{"keys": ["ARROWS"], "label": "move"},
		{"keys": ["ENTER"], "label": "open"},
		{"keys": ["DEL"], "label": "delete"},
		{"keys": ["ESC"], "label": "back"},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["D-PAD"], "label": "move"},
		{"keys": ["A"], "label": "open"},
		{"keys": ["X"], "label": "delete"},
		{"keys": ["B"], "label": "back"},
	]


func _modal_hints() -> Array:
	return [
		{"keys": ["LEFT", "RIGHT"], "label": "choose"},
		{"keys": ["ENTER"], "label": "confirm"},
		{"keys": ["ESC"], "label": "cancel"},
	]


static func _timestamp(iso: String) -> String:
	return iso.substr(0, 16).replace("T", " ") if iso.length() >= 16 else iso


static func _date(iso: String) -> String:
	return iso.substr(0, 10) if iso.length() >= 10 else iso


static func _season_label(date: String) -> String:
	if date.length() < 7:
		return date
	var year := int(date.substr(0, 4))
	var month := int(date.substr(5, 2))
	var start := year if month >= 7 else year - 1
	return "%d/%d" % [start, start + 1]
