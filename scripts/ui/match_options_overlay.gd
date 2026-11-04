class_name MatchOptionsOverlay
extends Control
# Match options as a full-screen overlay over the hub: the two live sliders and
# the original tab stubs (Stadium / Weather / Camera / System) marked SOON.
# Host-only in network matches; the client sees the same values read-only.

signal option_changed(field: String, value: float)
signal closed

const ROW_COUNT := 6
const ROW_DIFFICULTY := 0
const ROW_DURATION := 1
const ROW_STADIUM := 2

var _panel: Panel
var _title: Label
var _row_layer: Control
var _row_bgs: Array = []
var _focus_bar: ColorRect
var _rows: Array = []
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _focus_row := 0
var _editable := true
var _syncing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func setup(state: Dictionary, options: Dictionary = {}) -> void:
	var option_state: Dictionary = state.get("options", {})
	_editable = bool(option_state.get("editable", true))
	_syncing = true
	var difficulty: HubValueSlider = _sliders["difficulty"]
	var duration: HubValueSlider = _sliders["duration"]
	difficulty.setup(0.6, 1.0, 0.05, float(option_state.get("difficulty", 0.8)), _editable)
	duration.setup(0.5, 1.5, 0.5, float(option_state.get("duration", 1.0)), _editable)
	_update_values()
	_syncing = false
	_focus_row = clampi(_focus_row, 0, ROW_COUNT - 1)
	_refresh_rows()


func is_editable() -> bool:
	return _editable


func focus_row() -> int:
	return _focus_row


func slider_value(field: String) -> float:
	var slider: HubValueSlider = _sliders.get(field)
	return slider.value if slider != null else 0.0


func move_focus(delta: int) -> void:
	if delta == 0:
		return
	_focus_row = posmod(_focus_row + delta, ROW_COUNT)
	_refresh_rows()


func adjust(delta: int) -> void:
	if not _editable or delta == 0:
		return
	if _focus_row == ROW_DIFFICULTY:
		_adjust_slider("difficulty", delta)
	elif _focus_row == ROW_DURATION:
		_adjust_slider("duration", delta)


func confirm() -> void:
	# The overlay has no separate commit: slider changes are live.
	pass


func cancel() -> void:
	closed.emit()


func _build() -> void:
	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_FILL
	box.shadow_color = UiTokens.SHADOW_SELECTED
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)

	_row_layer = Control.new()
	_row_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_row_layer)
	for index in ROW_COUNT:
		var row_bg := ColorRect.new()
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_bg.color = UiTokens.HUB_OPTION_ROW
		_row_layer.add_child(row_bg)
		_row_bgs.append(row_bg)
	_focus_bar = ColorRect.new()
	_focus_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_bar.color = UiTokens.RAIL
	_focus_bar.visible = false
	_row_layer.add_child(_focus_bar)

	_title = _label(&"HubOptionTitle", "MATCH OPTIONS")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_panel.add_child(_title)

	_add_slider_row(ROW_DIFFICULTY, "difficulty", "DIFFICULTY (HUMAN VS CPU)")
	_add_slider_row(ROW_DURATION, "duration", "MATCH DURATION")
	_add_stub_row(ROW_STADIUM, "STADIUM", "DEFAULT STADIUM")
	_add_stub_row(ROW_STADIUM + 1, "WEATHER", "RANDOMIZED AT KICK-OFF")
	_add_stub_row(ROW_STADIUM + 2, "CAMERA", "DEFAULT BROADCAST")
	_add_stub_row(ROW_STADIUM + 3, "SYSTEM", "NOT PORTED")


func _add_slider_row(row: int, field: String, caption: String) -> void:
	var label := _label(&"HubOptionLabel", caption.to_upper())
	var value_label := _label(&"HubOptionValue", "")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HubValueSlider.new()
	slider.value_changed.connect(_on_slider_changed.bind(field))
	_panel.add_child(label)
	_panel.add_child(slider)
	_panel.add_child(value_label)
	_rows.append({"row": row, "caption": label, "value": value_label, "slider": slider})
	_sliders[field] = slider
	_values[field] = value_label


func _add_stub_row(row: int, caption: String, value_text: String) -> void:
	var label := _label(&"HubOptionLabel", caption.to_upper())
	var value_label := _label(&"HubOptionStub", value_text.to_upper())
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"SoonChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_box := StyleBoxFlat.new()
	chip_box.bg_color = Color(1.0, 1.0, 1.0, 0.14)
	chip_box.content_margin_left = 8.0
	chip_box.content_margin_right = 8.0
	chip_box.content_margin_top = 3.0
	chip_box.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override(&"panel", chip_box)
	var chip_label := Label.new()
	chip_label.theme_type_variation = &"SoonChipLabel"
	chip_label.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK_2)
	chip_label.text = "SOON"
	chip.add_child(chip_label)
	_panel.add_child(label)
	_panel.add_child(value_label)
	_panel.add_child(chip)
	_rows.append({"row": row, "caption": label, "value": value_label, "chip": chip})


func _label(variation: StringName, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout() -> void:
	if _panel == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var panel_size := Vector2(UiTokens.HUB_OPTIONS_PANEL_W, UiTokens.HUB_OPTIONS_PANEL_H)
	_panel.position = (size - panel_size) * 0.5
	_panel.size = panel_size
	var pad := 32.0
	_title.position = Vector2(pad, 22.0)
	_title.size = Vector2(panel_size.x - pad * 2.0, 36.0)
	var rows_top := 78.0
	var row_h := UiTokens.HUB_OPTIONS_ROW_H
	var gap := UiTokens.HUB_OPTIONS_GAP
	for row in ROW_COUNT:
		var bg: ColorRect = _row_bgs[row]
		bg.position = Vector2(24.0, rows_top + float(row) * (row_h + gap))
		bg.size = Vector2(panel_size.x - 48.0, row_h)
	_focus_bar.position = Vector2(24.0, rows_top + float(_focus_row) * (row_h + gap))
	_focus_bar.size = Vector2(4.0, row_h)
	_focus_bar.visible = true
	for entry in _rows:
		var row := int(entry["row"])
		var y := rows_top + float(row) * (row_h + gap)
		var caption: Label = entry["caption"]
		caption.position = Vector2(pad, y)
		caption.size = Vector2(panel_size.x * 0.36, row_h)
		var value: Label = entry["value"]
		if entry.has("chip"):
			value.position = Vector2(panel_size.x - pad - 330.0, y)
			value.size = Vector2(250.0, row_h)
		else:
			value.position = Vector2(panel_size.x - pad - 170.0, y)
			value.size = Vector2(170.0, row_h)
		if entry.has("slider"):
			var slider: HubValueSlider = entry["slider"]
			slider.position = Vector2(panel_size.x * 0.38, y + (row_h - 32.0) * 0.5)
			slider.size = Vector2(panel_size.x * 0.45, 32.0)
		if entry.has("chip"):
			var chip: PanelContainer = entry["chip"]
			chip.position = Vector2(panel_size.x - pad - 78.0, y + 15.0)
	queue_redraw()


func _draw() -> void:
	if _panel == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UiTokens.HUB_SCRIM, true)


func _refresh_rows() -> void:
	if _focus_bar == null:
		return
	var row_h := UiTokens.HUB_OPTIONS_ROW_H
	var gap := UiTokens.HUB_OPTIONS_GAP
	var rows_top := 78.0
	_focus_bar.position = Vector2(24.0, rows_top + float(_focus_row) * (row_h + gap))
	_focus_bar.size = Vector2(4.0, row_h)
	_focus_bar.visible = true
	for row in _row_bgs.size():
		var bg: ColorRect = _row_bgs[row]
		bg.color = Color(1.0, 1.0, 1.0, 0.10) if row == _focus_row \
			else UiTokens.HUB_OPTION_ROW
	queue_redraw()


func _adjust_slider(field: String, delta: int) -> void:
	var slider: HubValueSlider = _sliders.get(field)
	if slider == null or not _editable:
		return
	slider.adjust(delta)


func _on_slider_changed(value: float, field: String) -> void:
	_update_values()
	if _syncing or not _editable:
		return
	option_changed.emit(field, value)


func _update_values() -> void:
	var difficulty: HubValueSlider = _sliders.get("difficulty")
	var duration: HubValueSlider = _sliders.get("duration")
	if difficulty != null:
		(_values["difficulty"] as Label).text = "%.2f" % difficulty.value
	if duration != null:
		(_values["duration"] as Label).text = "~%d MIN" % (
			5 + int(round(20.0 * duration.value)))


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			var panel_rect := Rect2(_panel.position, _panel.size)
			if not panel_rect.has_point(mouse.position):
				cancel()
				accept_event()
