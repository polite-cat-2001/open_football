class_name SettingsScreen
extends Control
# Shared system settings ported from GameplayFootball's menu/settings.cpp, on
# the shell design system. One screen for the pause menu and the prematch hub:
# a bento grid of categories, each opening an in-screen list with a breadcrumb.
#
# Input is routed by the host (handle_key / handle_joy / handle_motion); the
# mouse works directly on tiles, rows and sliders.

signal closed
signal side_select_requested
signal match_options_changed(field: String, value: float)

const HINTS_SCENE := preload("res://scenes/ui/ui_hints_bar.tscn")
const GRID_COLS := 4
const GRID_ROWS := 2

const TILES := [
	{"id": "gameplay", "title": "GAMEPLAY", "glyph": "sliders"},
	{"id": "controls", "title": "CONTROLS", "glyph": "gamepad"},
	{"id": "graphics", "title": "GRAPHICS", "glyph": "monitor"},
	{"id": "audio", "title": "AUDIO", "glyph": "volume"},
	{"id": "camera", "title": "CAMERA", "glyph": "play"},
	{"id": "options", "title": "MATCH OPTIONS", "glyph": "tactics"},
	{"id": "sides", "title": "SIDE SELECTION", "glyph": "sides"},
]

const GAMEPLAY_ROWS := [
	{"key": "shortpass_direction", "label": "short pass - direction assist"},
	{"key": "shortpass_power", "label": "short pass - power assist"},
	{"key": "throughpass_direction", "label": "through pass - direction assist"},
	{"key": "throughpass_power", "label": "through pass - power assist"},
	{"key": "highpass_direction", "label": "high pass - direction assist"},
	{"key": "highpass_power", "label": "high pass - power assist"},
	{"key": "shot_direction", "label": "shot - direction assist"},
	{"key": "curl_spin", "label": "shot curl - spin", "format": "spin"},
	{"key": "curl_aim", "label": "shot curl - aim offset", "format": "aim"},
	{"key": "agility", "label": "human agility factor"},
	{"key": "acceleration", "label": "human acceleration factor"},
	{"key": "quantization", "label": "8-way quantization (d-pad)"},
]

const CAMERA_ROWS := [
	{"key": "zoom", "label": "zoom"},
	{"key": "height", "label": "height"},
	{"key": "fov", "label": "fov (perspective)"},
	{"key": "angle", "label": "horizontal angle"},
]

const FUNCTION_GROUPS := [
	{"title": "modifier", "functions": [12, 13, 14, 15]},
	{"title": "on the ball", "functions": [4, 5, 6, 7]},
	{"title": "off the ball", "functions": [8, 9, 10, 11]},
]

const SLIDER_PAGES := ["gameplay", "camera", "audio", "options"]
const ROW_H := 44.0
const ROW_GAP := 8.0
const TRANSITION_OUT := 0.15
const TRANSITION_IN := 0.24
const TRANSITION_SCALE := 0.96

const RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]

var _context: Dictionary = {}
var _runtime: Node = null
var _mode := "menu"
var _tile_index := 0
var _focus := 0
var _capture := {}
var _swap_group := -1
var _swap_index := -1
var _scroll := 0.0
var _scroll_max := 0.0
var _transitioning := false
var _rows: Array = []
var _row_nodes: Array = []
var _headers: Array = []

var _breadcrumb: UiBreadcrumb
var _hints: UiHintsBar
var _grid: BentoGrid
var _tiles: Array[BentoTile] = []
var _panel: Panel
var _title: Label
var _note: Label
var _scroll_track: ColorRect
var _scroll_thumb: ColorRect
var _scrim := true


func _ready() -> void:
	_build()
	resized.connect(_layout)
	visible = false
	set_process(false)


# Axis capture is polled: UiNav consumes stick motion before it reaches a host.
func _process(_delta: float) -> void:
	if not visible or _capture.is_empty() or _capture["kind"] != "button":
		set_process(false)
		return
	for device in Input.get_connected_joypads():
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X,
				JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			var value := Input.get_joy_axis(int(device), axis)
			if absf(value) > 0.7:
				SettingsStore.set_gamepad_buttons_at(int(_capture["index"]),
					SettingsStore.encode_axis(axis, value > 0.0))
				_finish_gamepad_capture()
				return


func set_scrim(value: bool) -> void:
	_scrim = value
	queue_redraw()


func open(context: Dictionary = {}) -> void:
	_build()
	_context = context.duplicate(true)
	_runtime = context.get("runtime")
	_mode = "menu"
	_capture.clear()
	_swap_group = -1
	_swap_index = -1
	visible = true
	_transitioning = false
	for node in [_grid, _panel]:
		(node as Control).modulate.a = 1.0
		(node as Control).scale = Vector2.ONE
	_project_state()
	_tiles[6].set_tile_disabled(not bool(_context.get("side_select_available", false)))
	_show_menu(true)
	_layout()
	_refresh_hints()
	queue_redraw()


func close() -> void:
	if not visible:
		return
	if bool(_context.get("animate_close", false)):
		# The host fades the screen out and calls dismiss() afterwards.
		if _capture.is_empty():
			SettingsStore.save()
		closed.emit()
		return
	dismiss()
	closed.emit()


# Hide without emitting closed (hosts that already own the transition).
func dismiss() -> void:
	if not visible:
		return
	if _capture.is_empty():
		SettingsStore.save()
	visible = false
	_transitioning = false
	for node in [_grid, _panel]:
		(node as Control).modulate.a = 1.0
		(node as Control).scale = Vector2.ONE
	_capture.clear()
	set_process(false)
	_swap_group = -1
	_swap_index = -1
	modulate.a = 1.0
	scale = Vector2.ONE


func is_open() -> bool:
	return visible


func is_capturing() -> bool:
	return not _capture.is_empty()


func options_editable() -> bool:
	return bool(_context.get("options_editable", true))


func focused_row() -> Dictionary:
	return _rows[_focus] if _focus >= 0 and _focus < _rows.size() else {}


func scroll_offset() -> float:
	return _scroll


func handle_nav(direction: Vector2i) -> bool:
	if not visible:
		return false
	if direction == Vector2i.UP:
		_move(-1, 0)
	elif direction == Vector2i.DOWN:
		_move(1, 0)
	elif direction == Vector2i.LEFT:
		_move(0, -1)
	elif direction == Vector2i.RIGHT:
		_move(0, 1)
	else:
		return false
	return true


func handle_confirm() -> void:
	if visible and not is_capturing():
		_confirm()


func handle_cancel() -> void:
	if visible:
		_cancel()


func mode_name() -> String:
	return _mode


func context() -> Dictionary:
	return _context


func update_context(context: Dictionary) -> void:
	_context.merge(context, true)
	_runtime = _context.get("runtime")
	_project_state()
	if _tiles.size() > 6:
		_tiles[6].set_tile_disabled(not bool(_context.get("side_select_available", false)))


func _build() -> void:
	if _breadcrumb != null:
		return
	theme = UiTheme.load_or_build()
	mouse_filter = Control.MOUSE_FILTER_STOP

	_breadcrumb = UiBreadcrumb.new()
	_breadcrumb.name = "Breadcrumb"
	_breadcrumb.visible = false
	add_child(_breadcrumb)

	_grid = BentoGrid.new()
	_grid.name = "Tiles"
	_grid.columns = GRID_COLS
	_grid.rows = GRID_ROWS
	add_child(_grid)
	for index in TILES.size():
		var tile := BentoTile.new()
		tile.name = "Tile%d" % index
		tile.title = str(TILES[index]["title"])
		tile.glyph_name = str(TILES[index]["glyph"])
		tile.wide = true
		_grid.add_child(tile)
		tile.pressed.connect(_open_tile.bind(index))
		tile.focus_entered.connect(_on_tile_focused.bind(index))
		_tiles.append(tile)
	_grid.add_cell(_tiles[0], 1, 1)
	_grid.add_cell(_tiles[1], 2, 1)
	_grid.add_cell(_tiles[2], 3, 1)
	_grid.add_cell(_tiles[3], 4, 1)
	_grid.add_cell(_tiles[4], 1, 2)
	_grid.add_cell(_tiles[5], 2, 2)
	_grid.add_cell(_tiles[6], 3, 2)

	_panel = Panel.new()
	_panel.name = "Page"
	_panel.visible = false
	_panel.clip_contents = true
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_FILL
	box.shadow_color = UiTokens.SHADOW_SELECTED
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)

	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"HubOptionTitle"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	_note = Label.new()
	_note.name = "Note"
	_note.theme_type_variation = &"HubMeta"
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_note)

	_scroll_track = ColorRect.new()
	_scroll_track.name = "ScrollTrack"
	_scroll_track.color = Color(1.0, 1.0, 1.0, 0.12)
	_scroll_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_track.z_index = 5
	_scroll_track.visible = false
	_panel.add_child(_scroll_track)

	_scroll_thumb = ColorRect.new()
	_scroll_thumb.name = "ScrollThumb"
	_scroll_thumb.color = UiTokens.FOCUS_MARK
	_scroll_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_thumb.z_index = 6
	_scroll_thumb.visible = false
	_panel.add_child(_scroll_thumb)

	_hints = HINTS_SCENE.instantiate() as UiHintsBar
	_hints.name = "Hints"
	add_child(_hints)


func _project_state() -> void:
	var context_options: Dictionary = _context.get("options", {})
	if not context_options.is_empty():
		_context["options_editable"] = bool(context_options.get("editable", true))
		_context["difficulty"] = float(context_options.get("difficulty", 0.8))
		_context["duration"] = float(context_options.get("duration", 1.0))


func _show_menu(focus: bool) -> void:
	_mode = "menu"
	_panel.visible = false
	_grid.visible = true
	_breadcrumb.visible = false
	_clear_rows()
	_layout_tiles()
	if focus and _tiles.size() > 0:
		_tile_index = clampi(_tile_index, 0, _tiles.size() - 1)
		_tiles[_tile_index].grab_focus()
	_refresh_hints()


func _open_tile(index: int) -> void:
	if _transitioning:
		return
	if index < 0 or index >= _tiles.size():
		return
	if _tiles[index].disabled:
		return
	_tile_index = index
	var id := str(TILES[index]["id"])
	if id == "sides":
		close_signal_side_select()
		return
	_transition(func(): _enter_page(id))


func _enter_page(id: String) -> void:
	_mode = id
	_capture.clear()
	_swap_group = -1
	_swap_index = -1
	_grid.visible = false
	_panel.visible = true
	_build_page()
	_layout()
	_focus = 0
	_refresh_rows()
	_refresh_hints()


func close_signal_side_select() -> void:
	side_select_requested.emit()


func _open_pad_page(device: int) -> void:
	_transition(func(): _enter_pad_page(device))


func _enter_pad_page(device: int) -> void:
	_mode = "pad"
	_context["pad"] = device
	_context["pad_name"] = Input.get_joy_name(device)
	_grid.visible = false
	_panel.visible = true
	_build_page()
	_layout()
	_focus = 0
	_refresh_rows()
	_refresh_hints()


func _transition(builder: Callable) -> void:
	if _transitioning:
		return
	var current: Control = _panel if _panel.visible else _grid
	if _animations_instant():
		builder.call()
		_layout()
		return
	_transitioning = true
	await _animate(current, false)
	builder.call()
	_layout()
	var target: Control = _panel if _panel.visible else _grid
	target.visible = true
	target.modulate.a = 0.0
	target.scale = Vector2.ONE * TRANSITION_SCALE
	await _animate(target, true)
	_transitioning = false


func _animate(target: Control, show: bool) -> void:
	if target == null:
		return
	target.pivot_offset = target.size * 0.5
	var duration := TRANSITION_IN if show else TRANSITION_OUT
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 1.0 if show else 0.0, duration) \
		.set_trans(Tween.TRANS_CUBIC if show else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT if show else Tween.EASE_IN)
	tween.tween_property(target, "scale",
		Vector2.ONE if show else Vector2.ONE * TRANSITION_SCALE, duration) \
		.set_trans(Tween.TRANS_CUBIC if show else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT if show else Tween.EASE_IN)
	await tween.finished


func _animations_instant() -> bool:
	return DisplayServer.get_name() == "headless" or not is_inside_tree()


func _clear_rows() -> void:
	_scroll = 0.0
	_scroll_max = 0.0
	for node in _row_nodes:
		if node is Node and is_instance_valid(node):
			node.queue_free()
	_row_nodes.clear()
	_rows.clear()
	for header in _headers:
		if header is Node and is_instance_valid(header):
			header.queue_free()
	_headers.clear()
	_focus = 0


func _build_page() -> void:
	_clear_rows()
	_title.text = _page_title()
	_breadcrumb.set_items(_page_crumbs())
	match _mode:
		"gameplay":
			for entry in GAMEPLAY_ROWS:
				_add_slider_row(str(entry["label"]), SettingsStore.gameplay()[entry["key"]],
					0.0, 1.0, 0.01, str(entry.get("format", "ratio")),
					"gameplay:" + str(entry["key"]))
		"camera":
			for entry in CAMERA_ROWS:
				_add_slider_row(str(entry["label"]), SettingsStore.camera()[entry["key"]],
					0.0, 1.0, 0.01, "ratio", "camera:" + str(entry["key"]))
		"audio":
			_add_slider_row("volume", SettingsStore.audio(), 0.0, 1.0, 0.01, "percent",
				"audio:volume")
		"graphics":
			_build_graphics_rows()
		"options":
			var editable := bool(_context.get("options_editable", true))
			_add_slider_row("difficulty (human vs cpu)",
				float(_context.get("difficulty", 0.8)), 0.6, 1.0, 0.05, "ratio",
				"option:difficulty", editable)
			var lengths: Array = []
			for minutes in MatchPackage.LENGTH_PRESETS:
				lengths.append(MatchPackage.duration_from_minutes(float(minutes)))
			_add_choice_row("match length",
				lengths,
				float(_context.get("duration", MatchPackage.DEFAULT_DURATION)),
				"minutes", "option:duration", editable)
			_add_note_row("substitutions per match: 3")
			if not editable:
				_add_note_row("applies to the next match (locked while playing)")
		"controls":
			_add_action_row("keyboard", "configure", "open:keyboard")
			_add_action_row("gamepad(s)", "configure", "open:gamepads")
		"keyboard":
			for index in SettingsStore.KEY_FUNCTION_LABELS.size():
				_add_action_row(str(SettingsStore.KEY_FUNCTION_LABELS[index]),
					SettingsStore.key_name(index), "bind_key:%d" % index)
			_add_action_row("reset to defaults", "", "reset_keyboard")
		"gamepads":
			_build_gamepad_rows()
		"pad":
			_add_action_row("button mapping", "", "open:mapping")
			_add_action_row("function setup", "", "open:functions")
			_add_action_row("reset to defaults", "", "reset_gamepad")
			_add_action_row("back", "", "back")
		"mapping":
			for index in SettingsStore.GAMEPAD_BUTTON_LABELS.size():
				_add_action_row(str(SettingsStore.GAMEPAD_BUTTON_LABELS[index]),
					SettingsStore.controller_label(SettingsStore.gamepad_buttons()[index]),
					"bind_gamepad:%d" % index)
		"functions":
			for group_index in FUNCTION_GROUPS.size():
				var group: Dictionary = FUNCTION_GROUPS[group_index]
				_headers.append(_make_header(str(group["title"]), group_index))
				for function_index in Array(group["functions"]):
					_add_action_row(str(SettingsStore.GAMEPAD_FUNCTION_LABELS[function_index]),
						SettingsStore.gamepad_label(int(function_index)),
						"bind_function:%d" % int(function_index))
		_:
			_show_menu(false)


func _page_title() -> String:
	match _mode:
		"gameplay": return "GAMEPLAY"
		"controls": return "CONTROLLER SETUP"
		"keyboard": return "KEYBOARD SETUP"
		"gamepads": return "GAMEPADS SETUP"
		"pad": return "GAMEPAD SETUP"
		"mapping": return "BUTTON MAPPING"
		"functions": return "FUNCTION SETUP"
		"graphics": return "GRAPHICS SETUP"
		"audio": return "AUDIO SETUP"
		"camera": return "CAMERA SETUP"
		"options": return "MATCH OPTIONS"
	return "SETTINGS"


func _page_crumbs() -> Array[String]:
	match _mode:
		"keyboard", "gamepads":
			return _crumbs(["SYSTEM SETTINGS", "CONTROLLER", _page_title()])
		"mapping", "functions":
			return _crumbs(["SYSTEM SETTINGS", "CONTROLLER", "GAMEPAD", _page_title()])
		"pad":
			return _crumbs(["SYSTEM SETTINGS", "CONTROLLER", "GAMEPAD"])
	return _crumbs(["SYSTEM SETTINGS", _page_title()])


func _crumbs(items: Array) -> Array[String]:
	var typed: Array[String] = []
	for item in items:
		typed.append(str(item))
	return typed


func _build_graphics_rows() -> void:
	var current := SettingsStore.graphics()
	var current_size := Vector2i(int(current["width"]), int(current["height"]))
	var seen: Array[Vector2i] = []
	for resolution in RESOLUTIONS:
		seen.append(resolution)
	if not seen.has(current_size):
		seen.append(current_size)
	for resolution in seen:
		var current_windowed := not bool(current["fullscreen"]) and resolution == current_size
		var current_full := bool(current["fullscreen"]) and resolution == current_size
		_add_action_row("%d x %d windowed" % [resolution.x, resolution.y],
			"current" if current_windowed else "",
			"resolution:%d:%d:0" % [resolution.x, resolution.y])
		_add_action_row("%d x %d fullscreen" % [resolution.x, resolution.y],
			"current" if current_full else "",
			"resolution:%d:%d:1" % [resolution.x, resolution.y])


func _build_gamepad_rows() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_add_note_row("no gamepads connected")
		_add_action_row("button mapping", "", "open:mapping")
		_add_action_row("function setup", "", "open:functions")
		return
	for device in pads:
		_add_action_row(Input.get_joy_name(int(device)), "setup",
			"pad:%d" % int(device))


func _make_header(text: String, column: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HubMetaStrong"
	label.text = text.to_upper()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	label.set_meta("column", column)
	return label


func _add_slider_row(caption: String, value: float, minimum: float, maximum: float,
		step: float, format: String, target: String, editable := true) -> void:
	var row := _make_row(caption, editable)
	row["kind"] = "slider"
	row["target"] = target
	row["format"] = format
	var slider := HubValueSlider.new()
	slider.setup(minimum, maximum, step, value, editable)
	slider.value_changed.connect(_on_slider_changed.bind(row))
	row["slider"] = slider
	_panel.add_child(slider)
	_row_nodes.append(slider)
	_update_row_value(row, value)


# Discrete value list (match length): left/right cycles the presets, the label
# shows the unit the player cares about, the stored value stays the option value.
func _add_choice_row(caption: String, values: Array, current: float,
		format: String, target: String, editable := true) -> void:
	var row := _make_row(caption, editable)
	row["kind"] = "choice"
	row["target"] = target
	row["format"] = format
	row["values"] = values
	row["editable"] = editable
	row["index"] = _nearest_choice(values, current)
	_update_choice_value(row)


func _nearest_choice(values: Array, current: float) -> int:
	var best := 0
	var best_delta := INF
	for index in values.size():
		var delta := absf(float(values[index]) - current)
		if delta < best_delta:
			best_delta = delta
			best = index
	return best


func _update_choice_value(row: Dictionary) -> void:
	var values: Array = row["values"]
	if values.is_empty():
		return
	var index := clampi(int(row.get("index", 0)), 0, values.size() - 1)
	row["index"] = index
	(row["value"] as Label).text = _format_choice(float(values[index]),
		str(row.get("format", "")))


func _format_choice(value: float, format: String) -> String:
	match format:
		"minutes":
			return "%d MIN" % int(round(MatchPackage.minutes_from_duration(value)))
	return "%0.2f" % value


func _step_choice(row: Dictionary, delta: int) -> void:
	var values: Array = row["values"]
	if values.is_empty() or delta == 0 or not bool(row.get("editable", true)):
		return
	row["index"] = posmod(int(row.get("index", 0)) + delta, values.size())
	_update_choice_value(row)
	_on_slider_changed(float(values[row["index"]]), row)


func _add_note_row(text: String) -> void:
	var row := _make_row(text, false)
	row["kind"] = "note"
	row["button"].focus_mode = Control.FOCUS_NONE
	row["button"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	row["value"].text = ""


func _add_action_row(caption: String, value_text: String, action: String) -> void:
	var row := _make_row(caption, true)
	row["kind"] = "action"
	row["action"] = action
	row["value"].text = value_text
	row["button"].pressed.connect(_on_row_pressed.bind(row))


func _make_row(caption: String, focusable: bool) -> Dictionary:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = ""
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_panel.add_child(button)

	var bg := ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = UiTokens.HUB_OPTION_ROW
	button.add_child(bg)

	var rail := ColorRect.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.color = UiTokens.RAIL
	rail.visible = false
	button.add_child(rail)

	var label := Label.new()
	label.theme_type_variation = &"HubOptionLabel"
	label.text = caption.to_upper() if focusable else caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	var value := Label.new()
	value.theme_type_variation = &"HubOptionValue"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(value)

	var row := {
		"button": button, "bg": bg, "rail": rail, "caption": label, "value": value,
		"kind": "action", "action": "", "slider": null,
	}
	_rows.append(row)
	_row_nodes.append(button)
	return row


func _update_row_value(row: Dictionary, value: float) -> void:
	var format := str(row.get("format", "ratio"))
	var text := ""
	match format:
		"spin":
			text = "%d" % int(round(value * SettingsStore.CURL_SPIN_MAX))
		"aim":
			text = "%0.2f" % (value * SettingsStore.CURL_AIM_MAX)
		"minutes":
			text = "%d MIN" % int(round(MatchPackage.minutes_from_duration(value)))
		"percent":
			text = "%d%%" % int(round(value * 100.0))
		_:
			text = "%0.2f" % value
	(row["value"] as Label).text = text


func _on_row_pressed(row: Dictionary) -> void:
	if row["kind"] in ["slider", "choice"]:
		_focus = _rows.find(row)
		_refresh_rows()
		return
	_activate_row(row)


func _activate_row(row: Dictionary) -> void:
	if row["kind"] != "action":
		return
	var action := str(row.get("action", ""))
	match action:
		"open:keyboard", "open:gamepads", "open:mapping", "open:functions":
			_transition(func(): _enter_page(action.substr(5)))
		"reset_keyboard":
			SettingsStore.set_keys_for_defaults()
			_build_page()
			_layout()
			_focus = 0
			_refresh_rows()
		"reset_gamepad":
			SettingsStore.set_gamepad_defaults()
			_apply_runtime()
			_build_page()
			_layout()
			_focus = 0
			_refresh_rows()
		"back":
			_transition(func(): _show_menu(true))
		_:
			if action.begins_with("bind_key:"):
				_start_capture("key", int(action.substr(9)))
			elif action.begins_with("bind_gamepad:"):
				_start_capture("button", int(action.substr(13)))
			elif action.begins_with("bind_function:"):
				_activate_function(int(action.substr(14)))
			elif action.begins_with("resolution:"):
				_apply_resolution(action)
			elif action.begins_with("pad:"):
				_open_pad_page(int(action.substr(4)))


func _activate_function(function_index: int) -> void:
	var group := _group_of(function_index)
	if group < 0:
		return
	if _swap_group == group and _swap_index >= 0:
		if _swap_index != function_index:
			var functions := SettingsStore.gamepad_functions()
			var tmp: int = functions[_swap_index]
			functions[_swap_index] = functions[function_index]
			functions[function_index] = tmp
			SettingsStore.set_gamepad_functions(functions)
			_apply_runtime()
		_swap_group = -1
		_swap_index = -1
	else:
		_swap_group = group
		_swap_index = function_index
	_build_page()
	_layout()
	_refresh_rows()
	_refresh_hints()


func _group_of(function_index: int) -> int:
	for group_index in FUNCTION_GROUPS.size():
		if Array(FUNCTION_GROUPS[group_index]["functions"]).has(function_index):
			return group_index
	return -1


func _start_capture(kind: String, index: int) -> void:
	_capture = {"kind": kind, "index": index}
	set_process(kind == "button")
	_refresh_hints()
	_hints.set_status("press key/button for '%s'" % _capture_label(kind, index))


func _capture_label(kind: String, index: int) -> String:
	if kind == "key":
		return str(SettingsStore.KEY_FUNCTION_LABELS[index])
	if kind == "button":
		return str(SettingsStore.GAMEPAD_BUTTON_LABELS[index])
	return str(SettingsStore.GAMEPAD_FUNCTION_LABELS[index])


func _cancel_capture() -> void:
	_capture.clear()
	set_process(false)
	_hints.set_status("")
	_refresh_hints()


func _apply_resolution(action: String) -> void:
	var parts := action.split(":")
	SettingsStore.set_graphics(int(parts[1]), int(parts[2]), parts[3] == "1")
	SettingsStore.apply_graphics()
	SettingsStore.save()
	_build_page()
	_layout()
	_refresh_rows()


func _apply_runtime() -> void:
	SettingsStore.apply_to_runtime(_runtime)


func _on_slider_changed(value: float, row: Dictionary) -> void:
	var target := str(row.get("target", ""))
	if target.begins_with("gameplay:"):
		SettingsStore.set_gameplay_value(target.substr(9), value)
		_apply_runtime()
	elif target.begins_with("camera:"):
		SettingsStore.set_camera_value(target.substr(7), value)
		_apply_runtime()
	elif target == "audio:volume":
		SettingsStore.set_audio(value)
	elif target.begins_with("option:"):
		_context[target.substr(7)] = value
		match_options_changed.emit(target.substr(7), value)
	if str(row.get("kind", "")) == "choice":
		_update_choice_value(row)
	else:
		_update_row_value(row, value)


func _refresh_rows() -> void:
	var rows_per_col := _rows_per_column()
	for index in _rows.size():
		var row: Dictionary = _rows[index]
		var focused: bool = index == _focus and row["kind"] != "note"
		(row["bg"] as ColorRect).color = Color(1.0, 1.0, 1.0, 0.10) if focused \
			else UiTokens.HUB_OPTION_ROW
		(row["rail"] as ColorRect).visible = focused
		var swap := false
		if _mode == "functions" and _swap_index >= 0:
			var action := str(row.get("action", ""))
			if action.begins_with("bind_function:"):
				swap = int(action.substr(14)) == _swap_index
		if swap:
			(row["bg"] as ColorRect).color = Color(UiTokens.FOCUS_MARK, 0.22)
	_update_note_for_capture()
	queue_redraw()


func _update_note_for_capture() -> void:
	if not _capture.is_empty():
		return
	if _mode == "functions" and _swap_index >= 0:
		_hints.set_status("select another %s function to swap" %
			str(FUNCTION_GROUPS[_swap_group]["title"]))
	elif _mode == "pad":
		_hints.set_status(str(_context.get("pad_name", "")))
	else:
		_hints.set_status("")


func _rows_per_column() -> int:
	if _mode == "keyboard":
		return 9
	if _mode == "mapping":
		return 7
	if _mode == "functions":
		return 4
	if _mode in SLIDER_PAGES:
		return maxi(_rows.size(), 1)
	return maxi(_rows.size(), 1)


func _row_columns() -> int:
	if _mode in ["keyboard", "mapping"]:
		return 2
	if _mode == "functions":
		return 3
	return 1


func _layout() -> void:
	if _breadcrumb == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var content_width := minf(size.x, UiTokens.PANEL_W)
	var content_x := (size.x - content_width) * 0.5
	var hints_height := _hints.height()
	var extra := 0.0 if _mode == "menu" \
		else UiBreadcrumb.HEIGHT + UiTokens.GAP
	var block_height := minf(size.y,
		extra + UiTokens.GRID_H + UiTokens.HINTS_GAP + hints_height)
	var block_top := (size.y - block_height) * 0.5
	var grid_height := maxf(0.0,
		block_height - hints_height - UiTokens.HINTS_GAP - extra)
	var content_top := block_top + extra
	if _mode != "menu":
		_breadcrumb.position = Vector2(content_x, block_top)
		_breadcrumb.size = Vector2(content_width, UiBreadcrumb.HEIGHT)
		_breadcrumb.visible = true
		_panel.position = Vector2(content_x, content_top)
		_panel.size = Vector2(content_width, grid_height)
		_layout_rows()
	_grid.position = Vector2(content_x, content_top)
	_grid.size = Vector2(content_width, grid_height)
	_layout_tiles()
	_hints.position = Vector2(content_x, block_top + block_height - hints_height)
	_hints.size = Vector2(content_width, hints_height)
	queue_redraw()


func _layout_tiles() -> void:
	if _grid == null:
		return
	_grid.position = _grid.position
	_grid.size = _grid.size
	# BentoGrid lays out on resize; a manual poke keeps headless/lazy builds honest.
	_grid.call("_layout_cells")


func _layout_rows() -> void:
	if _panel == null:
		return
	var pad := 28.0
	var header_height := 40.0
	var title_height := 40.0
	_title.visible = false
	var top := _rows_top()
	_note.position = Vector2(_panel.size.x - pad - 360.0, 16.0)
	_note.size = Vector2(360.0, title_height)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var columns := _row_columns()
	var rows_per_col := _rows_per_column()
	var gap := ROW_GAP
	var available := maxf(0.0, _panel.size.y - top - pad)
	var row_height := ROW_H
	if _mode in SLIDER_PAGES:
		var total := float(_rows.size()) * row_height \
			+ float(maxi(_rows.size() - 1, 0)) * gap
		_scroll_max = maxf(0.0, total - available)
		_scroll = clampf(_scroll, 0.0, _scroll_max)
	else:
		_scroll = 0.0
		_scroll_max = 0.0
		if rows_per_col > 0 and _rows.size() > rows_per_col:
			row_height = minf(row_height, (available - gap * float(rows_per_col - 1))
				/ float(maxi(rows_per_col, 1)))
		row_height = maxf(row_height, 26.0)
	var col_width := (_panel.size.x - pad * 2.0 - gap * float(columns - 1)) / float(columns)

	for index in _headers.size():
		var header: Label = _headers[index]
		var column := int(header.get_meta("column"))
		header.position = Vector2(pad + float(column) * (col_width + gap), 16.0)
		header.size = Vector2(col_width, header_height - 4.0)

	for index in _rows.size():
		var row: Dictionary = _rows[index]
		var column := index / maxi(rows_per_col, 1)
		var row_index := index % maxi(rows_per_col, 1)
		var x := pad + float(column) * (col_width + gap)
		var y := top + float(row_index) * (row_height + gap) - _scroll
		var button: Button = row["button"]
		button.position = Vector2(x, y)
		button.size = Vector2(col_width, row_height)
		var bg: ColorRect = row["bg"]
		bg.position = Vector2.ZERO
		bg.size = button.size
		var rail: ColorRect = row["rail"]
		rail.position = Vector2.ZERO
		rail.size = Vector2(4.0, row_height)
		var caption: Label = row["caption"]
		caption.position = Vector2(14.0, 0.0)
		caption.size = Vector2(col_width * 0.48 - 14.0, row_height)
		var value: Label = row["value"]
		value.position = Vector2(col_width * 0.60, 0.0)
		value.size = Vector2(col_width * 0.40 - 14.0, row_height)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var slider: HubValueSlider = row["slider"]
		if slider != null:
			slider.position = Vector2(x + col_width * 0.50,
				y + (row_height - 26.0) * 0.5)
			slider.size = Vector2(col_width * 0.24, 26.0)
			value.position = Vector2(col_width * 0.77, 0.0)
			value.size = Vector2(col_width * 0.23 - 14.0, row_height)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if _scroll_track != null:
		var show_scroll := _scroll_max > 0.0
		_scroll_track.visible = show_scroll
		_scroll_thumb.visible = show_scroll
		if show_scroll:
			var track_x := _panel.size.x - 12.0
			_scroll_track.position = Vector2(track_x, top)
			_scroll_track.size = Vector2(4.0, available)
			var thumb_height := maxf(32.0, available * available
				/ (available + _scroll_max))
			var ratio := _scroll / _scroll_max
			_scroll_thumb.position = Vector2(track_x, top
				+ ratio * (available - thumb_height))
			_scroll_thumb.size = Vector2(4.0, thumb_height)


func _refresh_hints() -> void:
	if _hints == null:
		return
	if not _capture.is_empty():
		_hints.setup([
			{"keys": ["ANY"], "label": "bind"},
			{"keys": ["ESC"], "label": "cancel"},
		])
		return
	var gamepad := _using_gamepad()
	if _mode == "menu":
		_hints.setup([
			{"keys": ["D-PAD"] if gamepad else ["<-", "->", "UP", "DOWN"], "label": "choose"},
			{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
			{"keys": ["B"] if gamepad else ["ESC"], "label": "close"},
		])
		return
	var is_slider_page := _mode in ["gameplay", "camera", "audio", "options"]
	if is_slider_page:
		_hints.setup([
			{"keys": ["D-PAD"] if gamepad else ["UP", "DOWN"], "label": "row"},
			{"keys": ["D-PAD"] if gamepad else ["<-", "->"], "label": "change"},
			{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
		])
	else:
		var select_label := "select / bind" \
			if _mode in ["keyboard", "mapping"] else "select"
		_hints.setup([
			{"keys": ["D-PAD"] if gamepad else ["UP", "DOWN", "<-", "->"], "label": "row"},
			{"keys": ["A"] if gamepad else ["ENTER"], "label": select_label},
			{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
		])


func _using_gamepad() -> bool:
	var nav := get_node_or_null("/root/UiNav")
	return nav != null and bool(nav.using_gamepad())


func _on_tile_focused(index: int) -> void:
	_tile_index = index


# Input ------------------------------------------------------------------

func handle_key(event: InputEventKey) -> bool:
	if not visible or not event.pressed:
		return false
	if not _capture.is_empty():
		if event.keycode == KEY_ESCAPE:
			_cancel_capture()
			return true
		if event.keycode != KEY_SHIFT and event.keycode != KEY_CTRL \
				and event.keycode != KEY_ALT and event.keycode != KEY_META:
			SettingsStore.set_key_for_function(int(_capture["index"]), event.keycode)
			_capture.clear()
			_hints.set_status("")
			_build_page()
			_layout()
			_refresh_rows()
			_refresh_hints()
			return true
		return true
	match event.keycode:
		KEY_UP:
			_move(-1, 0)
		KEY_DOWN:
			_move(1, 0)
		KEY_LEFT:
			_move(0, -1)
		KEY_RIGHT:
			_move(0, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm()
		KEY_ESCAPE:
			_cancel()
		_:
			return false
	return true


func handle_joy(event: InputEventJoypadButton) -> bool:
	if not visible or not event.pressed:
		return false
	if not _capture.is_empty():
		if int(event.button_index) == JOY_BUTTON_B:
			_cancel_capture()
			return true
		SettingsStore.set_gamepad_buttons_at(int(_capture["index"]),
			SettingsStore.encode_button(int(event.button_index)))
		_finish_gamepad_capture()
		return true
	match int(event.button_index):
		JOY_BUTTON_DPAD_UP:
			_move(-1, 0)
		JOY_BUTTON_DPAD_DOWN:
			_move(1, 0)
		JOY_BUTTON_DPAD_LEFT:
			_move(0, -1)
		JOY_BUTTON_DPAD_RIGHT:
			_move(0, 1)
		JOY_BUTTON_A:
			_confirm()
		JOY_BUTTON_B:
			_cancel()
		_:
			return false
	return true


func handle_motion(event: InputEventJoypadMotion) -> bool:
	if not visible:
		return false
	if not _capture.is_empty():
		if _capture["kind"] != "button" or absf(event.axis_value) <= 0.7:
			return false
		SettingsStore.set_gamepad_buttons_at(int(_capture["index"]),
			SettingsStore.encode_axis(int(event.axis), event.axis_value > 0.0))
		_finish_gamepad_capture()
		return true
	if absf(event.axis_value) <= 0.6:
		return false
	if int(event.axis) in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if int(event.axis) == JOY_AXIS_LEFT_X:
			_move(0, 1 if event.axis_value > 0.0 else -1)
		else:
			_move(1 if event.axis_value > 0.0 else -1, 0)
		return true
	return false


func _finish_gamepad_capture() -> void:
	_apply_runtime()
	_capture.clear()
	set_process(false)
	_hints.set_status("")
	_build_page()
	_layout()
	_refresh_rows()
	_refresh_hints()


func _move(row_delta: int, col_delta: int) -> void:
	if _transitioning:
		return
	if _capture.size() > 0:
		return
	if _mode == "menu":
		_move_tiles(row_delta, col_delta)
		return
	if _rows.is_empty():
		return
	var rows_per_col := _rows_per_column()
	var columns := _row_columns()
	if _mode in SLIDER_PAGES:
		if col_delta != 0:
			_adjust_focused(col_delta)
			return
		_focus = clampi(_focus + row_delta, 0, _rows.size() - 1)
		_refresh_rows()
		_ensure_visible()
		return
	var column := _focus / rows_per_col
	var row := _focus % rows_per_col
	if col_delta != 0:
		column = clampi(column + col_delta, 0, columns - 1)
		var candidate := column * rows_per_col + row
		_focus = candidate if candidate < _rows.size() else _last_in_column(column)
	else:
		var candidate := _focus + row_delta
		if candidate >= 0 and candidate < _rows.size() \
				and candidate / rows_per_col == column:
			_focus = candidate
	_refresh_rows()


func _last_in_column(column: int) -> int:
	var rows_per_col := _rows_per_column()
	return mini((column + 1) * rows_per_col - 1, _rows.size() - 1)


func _rows_top() -> float:
	# No page heading anywhere: the breadcrumb names the page. Only the
	# gamepad function page needs room for its three group headings.
	if _mode == "functions":
		return 16.0 + 40.0
	return 16.0


func _ensure_visible() -> void:
	if not (_mode in SLIDER_PAGES) or _rows.is_empty():
		return
	var top := _rows_top()
	var view_height := maxf(0.0, _panel.size.y - top - 28.0)
	var row_index := _focus % _rows_per_column()
	var row_top := float(row_index) * (ROW_H + ROW_GAP)
	var row_bottom := row_top + ROW_H
	var next := _scroll
	if row_top < _scroll:
		next = row_top
	elif row_bottom > _scroll + view_height:
		next = row_bottom - view_height
	next = clampf(next, 0.0, _scroll_max)
	if not is_equal_approx(next, _scroll):
		_scroll = next
		_layout_rows()


func _gui_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or not (_mode in SLIDER_PAGES):
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll = clampf(_scroll - ROW_H, 0.0, _scroll_max)
		_layout_rows()
		accept_event()
	elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll = clampf(_scroll + ROW_H, 0.0, _scroll_max)
		_layout_rows()
		accept_event()


func _move_tiles(row_delta: int, col_delta: int) -> void:
	if row_delta != 0:
		var next := _tile_index + GRID_COLS * row_delta
		if next >= 0 and next < _tiles.size() and not _tiles[next].disabled:
			_tile_index = next
	else:
		var next := _tile_index + col_delta
		if next >= 0 and next < _tiles.size() \
				and next / GRID_COLS == _tile_index / GRID_COLS \
				and not _tiles[next].disabled:
			_tile_index = next
	_tiles[_tile_index].grab_focus()


func _adjust_focused(delta: int) -> void:
	if _focus < 0 or _focus >= _rows.size():
		return
	var row: Dictionary = _rows[_focus]
	if str(row.get("kind", "")) == "choice":
		_step_choice(row, delta)
		return
	var slider: HubValueSlider = row["slider"]
	if slider == null or not slider.editable:
		return
	slider.adjust(delta)


func _confirm() -> void:
	if _transitioning:
		return
	if _mode == "menu":
		_open_tile(_tile_index)
		return
	if _focus >= 0 and _focus < _rows.size():
		_activate_row(_rows[_focus])


func _cancel() -> void:
	if _transitioning:
		return
	if not _capture.is_empty():
		_cancel_capture()
		return
	if _mode == "menu":
		close()
		return
	var target := "menu"
	match _mode:
		"keyboard", "gamepads":
			target = "controls"
		"pad":
			target = "gamepads"
		"mapping", "functions":
			target = "pad"
	_transition(func(): _apply_back(target))


func _apply_back(target: String) -> void:
	_mode = target
	_capture.clear()
	_swap_group = -1
	_swap_index = -1
	if target == "menu":
		_show_menu(true)
		return
	_grid.visible = false
	_panel.visible = true
	_build_page()
	_layout()
	_focus = 0
	_refresh_rows()
	_refresh_hints()


func _draw() -> void:
	if not _scrim:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UiTokens.HUB_SCRIM, true)



