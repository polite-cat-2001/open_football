extends UiScreen
# Join setup on the design system: address + port + name, the shared OSK,
# inline validation, "Connecting..." polling and readable reject reasons.
# Back cancels a pending connection instead of leaving a dead client behind.

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"

@onready var panel_wrap: Control = $Design/PanelWrap
@onready var breadcrumb: UiBreadcrumb = $Design/PanelWrap/Breadcrumb
@onready var form_panel: PanelContainer = $Design/PanelWrap/FormPanel
@onready var address_row: UiFormRow = $Design/PanelWrap/FormPanel/Content/AddressRow
@onready var port_row: UiFormRow = $Design/PanelWrap/FormPanel/Content/PortRow
@onready var name_row: UiFormRow = $Design/PanelWrap/FormPanel/Content/NameRow
@onready var connect_row: UiMenuRow = $Design/PanelWrap/FormPanel/Content/ConnectRow
@onready var hints: UiHintsBar = $Design/PanelWrap/Hints
var status_label: Label
var legend: UiLegend
@onready var osk: UiOnScreenKeyboard = $Design/Osk


var _rows: Array = []
var _focus_index := 0
var _osk_row: UiFormRow
var _connecting := false


func _ready() -> void:
	add_to_group(&"ui_shell")
	panel_wrap.add_to_group(&"ui_transition_target")
	theme = UiTheme.load_or_build()
	_rows = [address_row, port_row, name_row, connect_row]
	status_label = hints.status_label
	legend = hints.legend
	breadcrumb.set_items(["PLAY", "NETWORK", "JOIN"])

	_load_values()
	_connect_rows()
	osk.applied.connect(_on_osk_applied)
	osk.closed.connect(_on_osk_closed)
	_connect_nav()
	hints.setup(_keyboard_hints())

	_layout()
	get_viewport().size_changed.connect(_layout)
	theme_changed.connect(_layout)
	resized.connect(_layout)
	call_deferred("_focus_initial")


func _load_values() -> void:
	var values := NetworkSettings.load_join()
	address_row.set_value(str(values.get("address", NetworkSettings.DEFAULT_JOIN_ADDRESS)))
	port_row.set_value(str(values.get("port", NetworkSettings.DEFAULT_JOIN_PORT)))
	name_row.set_value(str(values.get("name", NetworkSettings.DEFAULT_JOIN_NAME)))


func _connect_rows() -> void:
	address_row.pressed.connect(_open_address)
	port_row.pressed.connect(_open_port)
	name_row.pressed.connect(_open_name)
	connect_row.pressed.connect(_connect)
	for row in _rows:

		row.focus_entered.connect(_on_row_focused.bind(row))


func _connect_nav() -> void:
	UiNav.moved.connect(_on_nav_moved)
	UiNav.confirmed.connect(_on_nav_confirmed)
	UiNav.cancelled.connect(_on_nav_cancelled)
	UiNav.device_changed.connect(_on_device_changed)


func _layout() -> void:
	if layout_canvas() <= 0.0:
		return
	var hints_height := hints.height()
	var panel_height := form_panel.get_combined_minimum_size().y
	var total := UiTokens.TAB_H + UiTokens.FORM_BREADCRUMB_GAP + panel_height \
		+ UiTokens.HINTS_GAP + hints_height

	panel_wrap.position = Vector2(
		(UiTokens.DESIGN_SIZE.x - UiTokens.PANEL_W) * 0.5,
		(UiTokens.DESIGN_SIZE.y - total) * 0.5
	)
	panel_wrap.size = Vector2(UiTokens.PANEL_W, total)
	var panel_x := (UiTokens.PANEL_W - UiTokens.FORM_PANEL_W) * 0.5
	breadcrumb.position = Vector2(panel_x, 0.0)
	form_panel.position = Vector2(panel_x, UiTokens.TAB_H + UiTokens.FORM_BREADCRUMB_GAP)
	form_panel.size = Vector2(UiTokens.FORM_PANEL_W, panel_height)
	var hints_y := UiTokens.TAB_H + UiTokens.FORM_BREADCRUMB_GAP + panel_height \
		+ UiTokens.HINTS_GAP
	hints.position = Vector2(panel_x, hints_y)
	hints.size = Vector2(UiTokens.FORM_PANEL_W, hints_height)



func _focus_initial() -> void:
	address_row.grab_focus()
	_focus_index = 0


func _on_row_focused(row: Control) -> void:
	_focus_index = _rows.find(row)


func _on_nav_moved(direction: Vector2i) -> void:
	if _event_modal():
		return
	if _connecting:
		return
	if direction == Vector2i.UP or direction == Vector2i.DOWN:
		_move_focus(-1 if direction == Vector2i.UP else 1)


func _on_nav_confirmed() -> void:
	if _event_modal() or _connecting:
		return
	_activate_focused()


func _on_nav_cancelled() -> void:
	if _event_modal():
		return
	_back()


func _on_device_changed(_gamepad: bool) -> void:
	hints.setup(_gamepad_hints() if UiNav.using_gamepad() else _keyboard_hints())


func _event_modal() -> bool:
	return UiNav.event_was_modal() or UiNav.is_modal() or osk.is_open()


func _move_focus(delta: int) -> void:
	if _rows.is_empty():
		return
	_focus_index = posmod(_focus_index + delta, _rows.size())
	_rows[_focus_index].grab_focus()


func _activate_focused() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		focus = _rows[_focus_index]
	if focus == address_row:
		_open_address()
	elif focus == port_row:
		_open_port()
	elif focus == name_row:
		_open_name()
	elif focus == connect_row:
		_connect()



func _open_address() -> void:
	if _connecting:
		return
	_osk_row = address_row
	osk.open("ADDRESS", address_row.value_text(), NetworkValidation.ADDRESS_MAX,
		NetworkValidation.ADDRESS_CHARS)


func _open_port() -> void:
	if _connecting:
		return
	_osk_row = port_row
	osk.open("PORT", port_row.value_text(), 5, NetworkValidation.PORT_CHARS)


func _open_name() -> void:
	if _connecting:
		return
	_osk_row = name_row
	osk.open("NAME", name_row.value_text(), NetworkValidation.NAME_MAX,
		NetworkValidation.NAME_CHARS)


func _on_osk_applied(text: String) -> void:
	if _osk_row != null:
		_osk_row.set_value(text)
		_osk_row.set_error("")
		_osk_row.grab_focus()
	_osk_row = null


func _on_osk_closed() -> void:
	if _osk_row != null:
		_osk_row.grab_focus()
	_osk_row = null


func _connect() -> void:
	if _connecting:
		return
	_clear_errors()
	var address := address_row.value_text().strip_edges()
	var port_text := port_row.value_text().strip_edges()
	var name := name_row.value_text().strip_edges()
	var valid := true
	if not NetworkValidation.is_valid_address(address):
		address_row.set_error("Enter an IPv4 address or hostname")
		valid = false
	if not NetworkValidation.is_valid_port(port_text):
		port_row.set_error("Enter a port from 1 to 65535")
		valid = false
	if not NetworkValidation.is_valid_name(name):
		name_row.set_error("Enter a name (1-16 characters)")
		valid = false
	if not valid:
		_set_status("Check the highlighted fields.", true)
		return

	var port := int(port_text)
	var runtime := NetShell.runtime(get_tree())
	if runtime == null:
		_set_status("Runtime is not available.", true)
		return
	if bool(runtime.is_net_active()):
		runtime.net_leave()
	if not bool(runtime.net_join(address, port, name)):
		_set_status(runtime.get_last_error(), true)
		return
	NetworkSettings.save_join(address, port, name)
	_connecting = true
	_set_status("CONNECTING TO %s:%d..." % [address, port], false)


func _process(_delta: float) -> void:
	if not _connecting:
		return
	var runtime := NetShell.active_runtime(get_tree())
	if runtime == null:
		_finish_connection_error("Connection closed")
		return
	var info: Dictionary = runtime.net_lobby()
	var connection := int(info.get("connection", 0))
	if connection == 3 and bool(info.get("accepted", false)):
		_connecting = false
		UiTransition.change_scene(SIDES_SCENE)
		return
	if connection == 0:
		var reason := str(info.get("reject_text", ""))
		_finish_connection_error(reason if not reason.is_empty() else "Connection failed")


func _finish_connection_error(reason: String) -> void:
	_connecting = false
	if NetShell.is_active(get_tree()):
		NetShell.leave(get_tree())
	address_row.set_error(reason)
	_set_status(reason, true)
	address_row.grab_focus()
	_focus_index = 0


func _back() -> void:
	if _connecting:
		_connecting = false
		if NetShell.is_active(get_tree()):
			NetShell.leave(get_tree())
		UiTransition.change_scene(NETWORK_MENU_SCENE)
		return
	if NetShell.is_active(get_tree()):
		NetShell.leave(get_tree())
	UiTransition.change_scene(NETWORK_MENU_SCENE)


func _clear_errors() -> void:
	address_row.set_error("")
	port_row.set_error("")
	name_row.set_error("")


func _set_status(text: String, error: bool) -> void:
	if hints == null:
		return
	hints.set_status(text, error)


func _keyboard_hints() -> Array:
	return [
		{"keys": ["в†‘", "в†“"], "label": "field"},
		{"keys": ["ENTER"], "label": "edit / connect"},
		{"keys": ["ESC"], "label": "back"},
	]


func _gamepad_hints() -> Array:
	return [
		{"keys": ["D-PAD"], "label": "field"},
		{"keys": ["A"], "label": "edit / connect"},
		{"keys": ["B"], "label": "back"},
	]






