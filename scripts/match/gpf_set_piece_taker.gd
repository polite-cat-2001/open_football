class_name GpfSetPieceTakerMenu
extends Control
# Port of the original SetPieceTakerPage (src/menu/ingame/setpiecetaker.cpp):
# "set-piece taker" caption, the taking team's active players as buttons (the
# current taker marked with `*`, keeper suffixed "(GK)") and the
# "enter: apply   escape: close" hint. Only the device that owns the taker may
# open or drive it; the caller (GpfHud) enforces that before calling here.

signal closed

const TITLE_TEXT := "set-piece taker"
const HINT_TEXT := "enter: apply   escape: close"
const MOVE_REPEAT_MS := 220
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")

const LIST_LEFT := 0.30
const LIST_WIDTH := 0.40
const LIST_TOP := 0.15
const ROW_STEP := 0.038
const ROW_HEIGHT := 0.034

var runtime: Node
var title_label: Label
var hint_label: Label
var buttons: Array[Button] = []
var candidates: Array = []
var selected := 0
var owner_kind := "keyboard"
var owner_device := 0

var _built := false
var _open := false
var _repeat_dir := 0
var _repeat_ms := 0
var _last_stick_ms := 0


func setup(runtime_node: Node) -> void:
	runtime = runtime_node
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_caption()
	visible = false
	resized.connect(_apply_layout)
	_apply_layout()


func open(entries: Array, kind: String, device: int, current_index: int = -1) -> bool:
	candidates = entries.duplicate(true)
	if candidates.is_empty():
		return false
	owner_kind = kind
	owner_device = device
	selected = current_index
	if selected < 0 or selected >= candidates.size():
		selected = 0
		for i in candidates.size():
			if bool(candidates[i].get("current", false)):
				selected = i
				break
	_rebuild_buttons()
	_repeat_dir = 0
	_repeat_ms = 0
	_open = true
	visible = true
	_apply_layout()
	if not buttons.is_empty():
		buttons[selected].grab_focus()
	return true


func close(apply_choice: bool, notify_runtime: bool = true) -> void:
	if not _open:
		return
	var chosen := -1
	if apply_choice and selected >= 0 and selected < candidates.size():
		chosen = int(candidates[selected].get("id", -1))
	_open = false
	visible = false
	_repeat_dir = 0
	_repeat_ms = 0
	if chosen >= 0 and runtime != null:
		runtime.request_set_piece_taker(chosen)
	if notify_runtime and runtime != null:
		runtime.close_set_piece_taker_menu()
	closed.emit()


func is_open() -> bool:
	return _open


func accepts_keyboard() -> bool:
	return _open and owner_kind == "keyboard"


func accepts_joy(device: int) -> bool:
	return _open and owner_kind == "gamepad" and int(device) == owner_device


func handle_key(event: InputEventKey) -> bool:
	if not (_open and accepts_keyboard()):
		return false
	if not event.pressed:
		if event.keycode in [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE,
				KEY_W, KEY_A, KEY_S, KEY_D]:
			_repeat_dir = 0
			_repeat_ms = 0
			return true
		return false
	match event.keycode:
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_ENTER, KEY_KP_ENTER:
			_activate(selected)
		KEY_ESCAPE:
			close(false)
		KEY_W, KEY_A, KEY_S, KEY_D:
			# A kick button closes the overlay without striking: gameplay input
			# is frozen by the runtime while it is open (original Process()).
			close(false)
		_:
			return false
	return true


func handle_joy(event: InputEventJoypadButton) -> bool:
	if not accepts_joy(int(event.device)):
		return false
	if not event.pressed:
		if int(event.button_index) in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
				JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			_repeat_dir = 0
			_repeat_ms = 0
			return true
		return false
	match int(event.button_index):
		JOY_BUTTON_A:
			_activate(selected)
		JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
			close(false)
		JOY_BUTTON_DPAD_UP:
			_move(-1)
		JOY_BUTTON_DPAD_DOWN:
			_move(1)
		_:
			return false
	return true


func handle_joy_motion(event: InputEventJoypadMotion) -> bool:
	if not accepts_joy(int(event.device)):
		return false
	if int(event.axis) != JOY_AXIS_LEFT_Y:
		return true
	var value := float(event.axis_value)
	if absf(value) <= 0.5:
		_repeat_dir = 0
		_repeat_ms = 0
		return true
	var now := Time.get_ticks_msec()
	if now - _last_stick_ms < MOVE_REPEAT_MS:
		return true
	_last_stick_ms = now
	var direction := 1 if value > 0.0 else -1
	_move(direction)
	_repeat_dir = direction
	_repeat_ms = now + MOVE_REPEAT_MS
	return true


func button_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for button in buttons:
		texts.append(button.text)
	return texts


func selected_index() -> int:
	return selected


func _process(_delta: float) -> void:
	if not _open:
		return
	var direction := _poll_direction()
	var now := Time.get_ticks_msec()
	if direction == 0:
		_repeat_dir = 0
		_repeat_ms = 0
		return
	if _repeat_dir != direction:
		_repeat_dir = direction
		_repeat_ms = now + MOVE_REPEAT_MS
		return
	if now >= _repeat_ms:
		_move(direction)
		_repeat_ms = now + MOVE_REPEAT_MS


func _poll_direction() -> int:
	if owner_kind == "keyboard":
		if Input.is_key_pressed(KEY_UP):
			return -1
		if Input.is_key_pressed(KEY_DOWN):
			return 1
		return 0
	if not Input.is_joy_button_pressed(owner_device, JOY_BUTTON_DPAD_DOWN) \
			and not Input.is_joy_button_pressed(owner_device, JOY_BUTTON_DPAD_UP):
		var axis := Input.get_joy_axis(owner_device, JOY_AXIS_LEFT_Y)
		if absf(axis) > 0.5:
			return 1 if axis > 0.0 else -1
	if Input.is_joy_button_pressed(owner_device, JOY_BUTTON_DPAD_UP):
		return -1
	if Input.is_joy_button_pressed(owner_device, JOY_BUTTON_DPAD_DOWN):
		return 1
	return 0


func _move(delta: int) -> void:
	var count := buttons.size()
	if count == 0:
		return
	selected = wrapi(selected + delta, 0, count)
	buttons[selected].grab_focus()


func _activate(index: int) -> void:
	if index < 0 or index >= candidates.size():
		close(false)
		return
	selected = index
	close(true)


func _build_caption() -> void:
	title_label = Label.new()
	title_label.name = "TakerTitle"
	title_label.text = TITLE_TEXT
	title_label.add_theme_font_override("font", MENU_FONT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("outline_size", 5)
	title_label.anchor_top = 0.07
	title_label.anchor_bottom = 0.10
	title_label.anchor_right = 1.0
	add_child(title_label)

	hint_label = Label.new()
	hint_label.name = "TakerHint"
	hint_label.text = HINT_TEXT
	hint_label.add_theme_font_override("font", MENU_FONT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("outline_size", 4)
	hint_label.anchor_top = 0.93
	hint_label.anchor_bottom = 0.96
	hint_label.anchor_right = 1.0
	add_child(hint_label)


func _rebuild_buttons() -> void:
	for button in buttons:
		button.queue_free()
	buttons.clear()
	for index in candidates.size():
		var entry: Dictionary = candidates[index]
		var button := Button.new()
		button.name = "TakerButton%d" % index
		button.text = _caption_for(entry)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.anchor_left = LIST_LEFT
		button.anchor_right = LIST_LEFT + LIST_WIDTH
		button.anchor_top = LIST_TOP + index * ROW_STEP
		button.anchor_bottom = button.anchor_top + ROW_HEIGHT
		_apply_button_style(button)
		button.pressed.connect(_activate.bind(index))
		add_child(button)
		buttons.append(button)
	var count := buttons.size()
	for index in count:
		var button := buttons[index]
		button.focus_neighbor_top = button.get_path_to(buttons[(index - 1 + count) % count])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(index + 1) % count])
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom


func _caption_for(entry: Dictionary) -> String:
	var caption := String(entry.get("name", ""))
	if String(entry.get("role", "")) == "goalkeeper":
		caption += " (GK)"
	if bool(entry.get("current", false)):
		caption += " *"
	return caption


func _apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _style(
		Color(0.04, 0.07, 0.12, 0.62), Color(0.62, 0.66, 0.72, 0.55)))
	button.add_theme_stylebox_override("hover", _style(
		Color(0.16, 0.32, 0.55, 0.88), Color(1.0, 0.86, 0.2, 0.95)))
	button.add_theme_stylebox_override("pressed", _style(
		Color(0.22, 0.42, 0.70, 0.95), Color(1.0, 0.86, 0.2, 1.0)))
	button.add_theme_stylebox_override("focus", _style(
		Color(0.16, 0.32, 0.55, 0.88), Color(1.0, 0.86, 0.2, 0.95), 2))
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	button.add_theme_constant_override("outline_size", 3)


func _style(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _apply_layout() -> void:
	if not _built:
		return
	var height := maxf(size.y, 1.0)
	var title_size := int(clampf(height * 0.030, 18.0, 44.0))
	var hint_size := int(clampf(height * 0.018, 11.0, 24.0))
	var row_size := int(clampf(height * 0.025, 13.0, 34.0))
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", title_size)
	if hint_label != null:
		hint_label.add_theme_font_size_override("font_size", hint_size)
	for button in buttons:
		button.add_theme_font_size_override("font_size", row_size)
