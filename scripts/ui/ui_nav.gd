extends Node

# Shell UI input router (autoload). Owns directional repeat, confirm/back and
# tab switching for keyboard and gamepad so every screen behaves the same.
# Active only while a screen in the "ui_shell" group is in the tree; gameplay
# input is untouched.

signal moved(direction: Vector2i)
signal moved_gamepad(direction: Vector2i, device: int)
signal confirmed
signal cancelled
signal tab_previous
signal tab_next
signal device_changed(gamepad: bool)

enum Device { KEYBOARD, GAMEPAD, MOUSE }

const FIRST_DELAY := 0.32
const REPEAT_DELAY := 0.22
const STICK_DEADZONE := 0.5

var _last_device := Device.KEYBOARD
var _last_device_id := 0
var _held_direction := Vector2i.ZERO
var _repeat_timer := 0.0
var _gamepad_state: Dictionary = {}
var _modal_stack: Array[Object] = []
var _event_modal := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func push_modal(owner: Object) -> void:
	if owner == null or _modal_stack.has(owner):
		return
	_modal_stack.append(owner)


func pop_modal(owner: Object) -> void:
	_modal_stack.erase(owner)


func is_modal() -> bool:
	return not _modal_stack.is_empty()


func modal_owner() -> Object:
	return _modal_stack.back() if not _modal_stack.is_empty() else null


func event_was_modal() -> bool:
	return _event_modal


func _process(delta: float) -> void:
	if not _is_active():
		_reset_repeat()
		_gamepad_state.clear()
		return
	var direction := _read_direction()
	if direction == Vector2i.ZERO:
		_reset_repeat()
	elif direction != _held_direction:
		_held_direction = direction
		_repeat_timer = FIRST_DELAY
		_event_modal = is_modal()
		moved.emit(direction)
	else:
		_repeat_timer -= delta
		if _repeat_timer <= 0.0:
			_repeat_timer = REPEAT_DELAY
			_event_modal = is_modal()
			moved.emit(direction)
	_poll_gamepads(delta)


func _input(event: InputEvent) -> void:
	if not _is_active():
		return

	# Capture the modal state for the whole event: a modal may close while its
	# signal handlers run, and the screen underneath must still ignore that
	# same event (Esc closing the OSK must not also trigger Back).
	_event_modal = is_modal()

	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_set_device(Device.MOUSE)
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_set_device(Device.KEYBOARD)
			_last_device_id = 0
			get_viewport().set_input_as_handled()
			return
		if key.echo or not key.pressed:
			return
		var handled := true
		match code:
			KEY_ENTER, KEY_KP_ENTER:
				_set_device(Device.KEYBOARD)
				_last_device_id = 0
				confirmed.emit()
			KEY_SPACE:
				_set_device(Device.KEYBOARD)
				_last_device_id = 0
				# A modal text keyboard needs the physical space bar; without a
				# modal, Space keeps acting as confirm.
				if is_modal():
					handled = false
				else:
					confirmed.emit()
			KEY_ESCAPE:
				_set_device(Device.KEYBOARD)
				_last_device_id = 0
				cancelled.emit()
			KEY_TAB:
				_set_device(Device.KEYBOARD)
				_last_device_id = 0
				tab_next.emit()
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed:
			return
		_set_device(Device.GAMEPAD)
		_last_device_id = int(button.device)
		var handled := true
		match button.button_index:
			JOY_BUTTON_A:
				confirmed.emit()
			JOY_BUTTON_B:
				cancelled.emit()
			JOY_BUTTON_LEFT_SHOULDER:
				tab_previous.emit()
			JOY_BUTTON_RIGHT_SHOULDER:
				tab_next.emit()
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, \
					JOY_BUTTON_DPAD_RIGHT:
				pass
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadMotion:
		# The UI owns stick navigation. Consume left-stick motion so Godot's
		# built-in ui_* focus navigation does not move focus a second time
		# (it would jump from the first tile to the bottom row).
		var motion := event as InputEventJoypadMotion
		_set_device(Device.GAMEPAD)
		_last_device_id = int(motion.device)
		if motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_LEFT_Y:
			get_viewport().set_input_as_handled()
		return


func using_gamepad() -> bool:
	return _last_device == Device.GAMEPAD


func last_device_id() -> int:
	return _last_device_id


func last_input_gamepad() -> bool:
	return _last_device == Device.GAMEPAD


func _is_active() -> bool:
	if get_tree() == null:
		return false
	if get_tree().get_first_node_in_group(&"ui_shell") == null:
		return false
	var transition := get_node_or_null("/root/UiTransition")
	if transition != null and transition.is_busy():
		return false
	return true


func _read_direction() -> Vector2i:
	var keyboard := _read_keyboard_direction()
	if keyboard != Vector2i.ZERO:
		_set_device(Device.KEYBOARD)
		return keyboard
	var gamepad := _read_gamepad_direction()
	if gamepad != Vector2i.ZERO:
		_set_device(Device.GAMEPAD)
		return gamepad
	return Vector2i.ZERO


func _read_keyboard_direction() -> Vector2i:
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_UP):
		_last_device_id = 0
		return Vector2i.UP
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_DOWN):
		_last_device_id = 0
		return Vector2i.DOWN
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_LEFT):
		_last_device_id = 0
		return Vector2i.LEFT
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_RIGHT):
		_last_device_id = 0
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _read_gamepad_direction() -> Vector2i:
	for device in Input.get_connected_joypads():
		var direction := _read_gamepad_device_direction(int(device))
		if direction != Vector2i.ZERO:
			_last_device_id = int(device)
			return direction
	return Vector2i.ZERO


func _read_gamepad_device_direction(device: int) -> Vector2i:
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		return Vector2i.UP
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		return Vector2i.DOWN
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		return Vector2i.LEFT
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		return Vector2i.RIGHT
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	if absf(x) > absf(y):
		if x > STICK_DEADZONE:
			return Vector2i.RIGHT
		if x < -STICK_DEADZONE:
			return Vector2i.LEFT
	else:
		if y > STICK_DEADZONE:
			return Vector2i.DOWN
		if y < -STICK_DEADZONE:
			return Vector2i.UP
	return Vector2i.ZERO


func _poll_gamepads(delta: float) -> void:
	for device in Input.get_connected_joypads():
		var device_id := int(device)
		var direction := _read_gamepad_device_direction(device_id)
		if direction == Vector2i.ZERO:
			_gamepad_state.erase(device_id)
			continue
		var state: Dictionary = _gamepad_state.get(device_id, {})
		if state.is_empty() or Vector2i(state.get("direction", Vector2i.ZERO)) != direction:
			_gamepad_state[device_id] = {"direction": direction, "timer": FIRST_DELAY}
			_emit_gamepad_move(direction, device_id)
			continue
		var timer := float(state.get("timer", REPEAT_DELAY)) - delta
		if timer <= 0.0:
			timer = REPEAT_DELAY
			_emit_gamepad_move(direction, device_id)
		state["timer"] = timer
		_gamepad_state[device_id] = state


func _emit_gamepad_move(direction: Vector2i, device_id: int) -> void:
	_last_device_id = device_id
	_event_modal = is_modal()
	moved_gamepad.emit(direction, device_id)


func _reset_repeat() -> void:
	_held_direction = Vector2i.ZERO
	_repeat_timer = 0.0


func _set_device(device: Device) -> void:
	if device == _last_device:
		return
	_last_device = device
	device_changed.emit(device == Device.GAMEPAD)
