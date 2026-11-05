class_name UiOnScreenKeyboard
extends Control
# Reusable on-screen keyboard in the career OSK style: a light modal panel with
# QWERTY rows, a digit/symbol row, space/delete/clear/apply actions and a live
# display. It owns navigation while open (UiNav modal), accepts physical typing,
# and returns the edited text on Apply.

signal applied(text: String)
signal closed

enum Zone { KEYS, ACTIONS }

const ACTION_SPACE := 0
const ACTION_BACKSPACE := 1
const ACTION_CLEAR := 2
const ACTION_APPLY := 3

var _open := false
var _title := ""
var _text := ""
var _max_length := 0
var _allowed := ""
var _zone := Zone.KEYS
var _focus_row := 0
var _focus_col := 0
var _focus_action := 0
var _built := false

var _scrim: ColorRect
var _panel: PanelContainer
var _eyebrow: Label
var _display_box: PanelContainer
var _display: Label
var _keys_box: VBoxContainer
var _actions_box: VBoxContainer
var _key_buttons: Array = []
var _action_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	_build()
	resized.connect(_layout)
	_connect_nav()
	call_deferred("_layout")


func open(title: String, text: String, max_length: int, allowed: String = "") -> void:
	_title = title
	_text = text
	_max_length = max_length
	_allowed = allowed
	_zone = Zone.KEYS
	_focus_row = 0
	_focus_col = 0
	_focus_action = 0
	_eyebrow.text = title.to_upper()
	_refresh_display()
	_update_key_hints()
	visible = true
	_open = true
	var ui_nav := _ui_nav()
	if ui_nav != null:
		ui_nav.push_modal(self)
	_layout()
	_focus_first_allowed()
	_focus_current()



func close(apply := false) -> void:
	if not _open:
		return
	_open = false
	visible = false
	var ui_nav := _ui_nav()
	if ui_nav != null:
		ui_nav.pop_modal(self)
	if apply:
		applied.emit(_text)
	else:
		closed.emit()


func is_open() -> bool:
	return _open


func current_text() -> String:
	return _text


func display_text() -> String:
	return _display.text if _display != null else ""


func zone() -> int:
	return _zone


func row_index() -> int:
	return _focus_row


func col_index() -> int:
	return _focus_col


func action_index() -> int:
	return _focus_action


func key_button(row: int, col: int) -> Button:
	if row < 0 or row >= _key_buttons.size():
		return null
	var buttons: Array = _key_buttons[row]
	if col < 0 or col >= buttons.size():
		return null
	return buttons[col]


func action_button(index: int) -> Button:
	if index < 0 or index >= _action_buttons.size():
		return null
	return _action_buttons[index]


func focus_key(row: int, col: int) -> void:
	_zone = Zone.KEYS
	_focus_row = clampi(row, 0, _key_buttons.size() - 1)
	var buttons: Array = _key_buttons[_focus_row]
	_focus_col = clampi(col, 0, maxi(0, buttons.size() - 1))
	_focus_current()


func focus_action(index: int) -> void:
	_zone = Zone.ACTIONS
	_focus_action = clampi(index, 0, _action_buttons.size() - 1)
	_focus_current()


func press_character(character: String) -> void:
	_insert_character(character)


func press_backspace() -> void:
	_backspace()


func press_clear() -> void:
	_clear_text()


func press_apply() -> void:
	_apply()


func _build() -> void:
	if _built:
		return
	_built = true

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = UiTokens.OSK_SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"FormPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override(&"separation", int(UiTokens.OSK_BODY_GAP))
	_panel.add_child(content)

	var head := VBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override(&"separation", int(UiTokens.OSK_HEAD_GAP))
	content.add_child(head)

	_eyebrow = Label.new()
	_eyebrow.name = "Eyebrow"
	_eyebrow.theme_type_variation = &"OskEyebrow"
	_eyebrow.custom_minimum_size.y = UiTokens.OSK_EYEBROW_H
	head.add_child(_eyebrow)

	_display_box = PanelContainer.new()
	_display_box.name = "DisplayBox"
	_display_box.theme_type_variation = &"OskDisplayBox"
	_display_box.custom_minimum_size.y = UiTokens.OSK_DISPLAY_H
	head.add_child(_display_box)

	_display = Label.new()
	_display.name = "Display"
	_display.theme_type_variation = &"OskDisplayText"
	_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_display.clip_text = true
	_display.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_display_box.add_child(_display)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override(&"separation", int(UiTokens.OSK_BODY_GAP * 2.0))
	content.add_child(body)

	_keys_box = VBoxContainer.new()
	_keys_box.name = "Keys"
	_keys_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_keys_box.add_theme_constant_override(&"separation", int(UiTokens.OSK_KEY_GAP))
	_keys_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_keys_box)

	_actions_box = VBoxContainer.new()
	_actions_box.name = "Actions"
	_actions_box.custom_minimum_size.x = UiTokens.OSK_ACTION_W
	_actions_box.add_theme_constant_override(&"separation", int(UiTokens.OSK_ACTION_GAP))
	body.add_child(_actions_box)

	for row_index in UiTokens.OSK_ROWS.size():
		var row := HBoxContainer.new()
		row.name = "Row%d" % row_index
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", int(UiTokens.OSK_KEY_GAP))
		_keys_box.add_child(row)
		var buttons: Array = []
		var text := String(UiTokens.OSK_ROWS[row_index])
		for col_index in text.length():
			var button := _make_key_button(text[col_index], row_index, col_index)
			row.add_child(button)
			buttons.append(button)
		_key_buttons.append(buttons)

	for action_index in UiTokens.OSK_ACTION_LABELS.size():
		var button := _make_action_button(String(UiTokens.OSK_ACTION_LABELS[action_index]),
			action_index)
		_actions_box.add_child(button)
		_action_buttons.append(button)

	_layout()


func _make_key_button(character: String, row: int, col: int) -> Button:
	var button := Button.new()
	button.name = "Key_%d_%d" % [row, col]
	button.text = character
	button.theme_type_variation = &"OskKey"
	button.custom_minimum_size = Vector2(UiTokens.OSK_KEY_W, UiTokens.OSK_KEY_H)
	button.focus_mode = Control.FOCUS_ALL
	_apply_key_style(button, false)
	button.pressed.connect(_on_key_pressed.bind(character))
	button.focus_entered.connect(_on_key_focused.bind(row, col))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _make_action_button(label: String, index: int) -> Button:
	var button := Button.new()
	button.name = "Action_%d" % index
	button.text = label
	button.theme_type_variation = &"OskAction"
	button.custom_minimum_size = Vector2(UiTokens.OSK_ACTION_W, UiTokens.OSK_ACTION_H)
	button.focus_mode = Control.FOCUS_ALL
	_apply_key_style(button, index == ACTION_APPLY)
	button.pressed.connect(_on_action_pressed.bind(index))
	button.focus_entered.connect(_on_action_focused.bind(index))
	button.mouse_entered.connect(button.grab_focus)
	return button


func _apply_key_style(button: Button, primary: bool) -> void:
	var normal := _key_box(primary)
	var focused := _key_focus_box()
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", normal)
	button.add_theme_stylebox_override(&"pressed", focused)
	button.add_theme_stylebox_override(&"focus", focused)
	button.add_theme_stylebox_override(&"disabled", normal)


func _key_box(primary: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_MARK if primary else UiTokens.OSK_KEY
	box.anti_aliasing = true
	return box


func _key_focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.OSK_KEY_FOCUS
	box.anti_aliasing = true
	return box


func _layout() -> void:
	if not _built or size.x <= 0.0 or size.y <= 0.0:
		return
	_scrim.position = Vector2.ZERO
	_scrim.size = size
	if _panel == null:
		return
	_panel.size = Vector2(UiTokens.OSK_PANEL_W, _panel.get_combined_minimum_size().y)
	var panel_height := _panel.get_combined_minimum_size().y
	_panel.size = Vector2(UiTokens.OSK_PANEL_W, panel_height)
	_panel.position = (size - _panel.size) * 0.5


func _refresh_display() -> void:
	if _display == null:
		return
	_display.text = _text if not _text.is_empty() else "\u2014"


func _update_key_hints() -> void:
	for row in _key_buttons.size():
		var buttons: Array = _key_buttons[row]
		var text := String(UiTokens.OSK_ROWS[row])
		for col in buttons.size():
			var button := buttons[col] as Button
			var allowed := _allowed.is_empty() or _allowed.find(text[col]) >= 0
			button.modulate = Color(1.0, 1.0, 1.0, 1.0 if allowed else 0.32)


func _insert_character(character: String) -> void:
	if character.is_empty():
		return
	if _max_length > 0 and _text.length() >= _max_length:
		return
	if not _allowed.is_empty() and _allowed.find(character) < 0:
		return
	_text += character
	_refresh_display()


func _backspace() -> void:
	if _text.is_empty():
		return
	_text = _text.substr(0, _text.length() - 1)
	_refresh_display()


func _clear_text() -> void:
	_text = ""
	_refresh_display()


func _apply() -> void:
	close(true)


func _on_key_pressed(character: String) -> void:
	_insert_character(character)


func _on_action_pressed(index: int) -> void:
	_run_action(index)


func _on_key_focused(row: int, col: int) -> void:
	_zone = Zone.KEYS
	_focus_row = row
	_focus_col = col


func _on_action_focused(index: int) -> void:
	_zone = Zone.ACTIONS
	_focus_action = index


func _run_action(index: int) -> void:
	match index:
		ACTION_SPACE:
			_insert_character(" ")
		ACTION_BACKSPACE:
			_backspace()
		ACTION_CLEAR:
			_clear_text()
		ACTION_APPLY:
			_apply()


func _press_current() -> void:
	if _zone == Zone.KEYS:
		var text := String(UiTokens.OSK_ROWS[_focus_row])
		_insert_character(text[_focus_col])
	else:
		_run_action(_focus_action)


func _focus_current() -> void:
	if _zone == Zone.KEYS:
		var button := key_button(_focus_row, _focus_col)
		if button != null:
			button.grab_focus()
	else:
		var button := action_button(_focus_action)
		if button != null:
			button.grab_focus()


func _focus_first_allowed() -> void:
	_zone = Zone.KEYS
	if _allowed.is_empty():
		_focus_row = 0
		_focus_col = 0
		return
	for row in _key_buttons.size():
		var text := String(UiTokens.OSK_ROWS[row])
		for col in text.length():
			if _allowed.find(text[col]) >= 0:
				_focus_row = row
				_focus_col = col
				return
	_zone = Zone.ACTIONS
	_focus_action = ACTION_APPLY



func _move(direction: Vector2i) -> void:
	if not _open:
		return
	if _zone == Zone.KEYS:
		var text := String(UiTokens.OSK_ROWS[_focus_row])
		match direction:
			Vector2i.LEFT:
				_focus_col = maxi(0, _focus_col - 1)
			Vector2i.RIGHT:
				if _focus_col < text.length() - 1:
					_focus_col += 1
				else:
					_zone = Zone.ACTIONS
					_focus_action = mini(_focus_row, _action_buttons.size() - 1)
			Vector2i.UP:
				_focus_row = maxi(0, _focus_row - 1)
				_focus_col = mini(_focus_col, String(UiTokens.OSK_ROWS[_focus_row]).length() - 1)
			Vector2i.DOWN:
				_focus_row = mini(_key_buttons.size() - 1, _focus_row + 1)
				_focus_col = mini(_focus_col, String(UiTokens.OSK_ROWS[_focus_row]).length() - 1)
	else:
		match direction:
			Vector2i.UP:
				_focus_action = maxi(0, _focus_action - 1)
			Vector2i.DOWN:
				_focus_action = mini(_action_buttons.size() - 1, _focus_action + 1)
			Vector2i.LEFT:
				_zone = Zone.KEYS
				_focus_row = _focus_action
				_focus_col = String(UiTokens.OSK_ROWS[_focus_row]).length() - 1
	_focus_current()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			close(false)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_BACKSPACE:
		_backspace()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_SPACE:
		_insert_character(" ")
		get_viewport().set_input_as_handled()
		return
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if key.unicode > 0:
		var character := String.chr(key.unicode)
		if character.length() == 1 and character >= " ":
			_insert_character(character)
			get_viewport().set_input_as_handled()
	elif key.keycode >= 32 and key.keycode <= 126:
		# Some external input bridges only fill keycode; treat the ASCII range
		# as the printable character it represents.
		_insert_character(String.chr(key.keycode))
		get_viewport().set_input_as_handled()



func _on_nav_moved(direction: Vector2i) -> void:
	if _is_modal_owner():
		_move(direction)


func _on_nav_confirmed() -> void:
	if _is_modal_owner():
		_press_current()


func _on_nav_cancelled() -> void:
	if _is_modal_owner():
		close(false)


func _connect_nav() -> void:
	var ui_nav := _ui_nav()
	if ui_nav == null:
		return
	ui_nav.moved.connect(_on_nav_moved)
	ui_nav.confirmed.connect(_on_nav_confirmed)
	ui_nav.cancelled.connect(_on_nav_cancelled)


func _is_modal_owner() -> bool:
	var ui_nav := _ui_nav()
	return _open and ui_nav != null and ui_nav.modal_owner() == self


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _exit_tree() -> void:
	if _open:
		var ui_nav := _ui_nav()
		if ui_nav != null:
			ui_nav.pop_modal(self)
		_open = false

