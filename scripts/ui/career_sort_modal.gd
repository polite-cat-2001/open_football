class_name CareerSortModal
extends Control
# Player-search sort editor over the transfer results: two toggles (the field and
# the direction) and a confirm row. Left/right steps the focused toggle, up/down
# moves between the rows, confirm applies and Back closes. Opens over the whole
# design canvas with the shared dim scrim and the shell's fade+scale (150 out /
# 240 in), and owns UiNav while open.

signal applied(sort: String, direction: String)
signal closed

const FIELDS := [
	{"value": "overall", "label": "OVR"},
	{"value": "age", "label": "AGE"},
	{"value": "height", "label": "HEIGHT"},
	{"value": "value", "label": "VALUE"},
	{"value": "wage", "label": "WAGE"},
	{"value": "position", "label": "POSITION"},
]
const DIRECTIONS := [
	{"value": "asc", "label": "ASCENDING"},
	{"value": "desc", "label": "DESCENDING"},
]
const CARD_W := 480.0
const PAD := 24.0
const ROW_H := 52.0
const ROW_GAP := 8.0
const SCALE_FROM := 0.96
const SCRIM := Color(0.024, 0.047, 0.102, 0.68)
const CONFIRM := 2

var _sort := "overall"
var _direction := "desc"
var _focus := 0
var _open := false
# The caller picks the field list and the heading (player search, history…);
# the search's own list is the default.
var _fields: Array = FIELDS
var _title := "SORT PLAYERS"

var _scrim: ColorRect
var _window_scrim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _rows: Array = []
var _confirm_panel: PanelContainer
var _confirm_label: Label
var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_build()
	resized.connect(_layout)
	_connect_nav()
	call_deferred("_layout")


func open(sort: String, direction: String, fields: Array = [],
		title := "SORT PLAYERS") -> void:
	if _open:
		return
	_fields = FIELDS if fields.is_empty() else fields
	_title = title
	_sort = _option_value(_fields, sort, str(_fields[0]["value"]))
	_direction = _option_value(DIRECTIONS, direction, "asc")
	_focus = 0
	_refresh()
	CareerScoutingModal.host_overlay(self)
	_host_scrim()
	_open = true
	visible = true
	move_to_front()
	var nav := _ui_nav()
	if nav != null:
		nav.push_modal(self)
	_layout()
	_scrim.modulate.a = 0.0
	if _window_scrim != null:
		_window_scrim.modulate.a = 0.0
	if _instant():
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
		_scrim.modulate.a = 1.0
		if _window_scrim != null:
			_window_scrim.modulate.a = 1.0
		return
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE * SCALE_FROM
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "modulate:a", 1.0, UiTokens.SCREEN_IN)
	_tween.tween_property(_card, "scale", Vector2.ONE, UiTokens.SCREEN_IN)
	_tween.tween_property(_scrim, "modulate:a", 1.0, UiTokens.SCREEN_OUT)
	if _window_scrim != null:
		_tween.tween_property(_window_scrim, "modulate:a", 1.0, UiTokens.SCREEN_OUT)


func close() -> void:
	if not _open:
		return
	_open = false
	var nav := _ui_nav()
	if nav != null:
		nav.pop_modal(self)
	closed.emit()
	if _tween != null:
		_tween.kill()
	if _instant():
		visible = false
		_release_scrim()
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_card, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	_tween.tween_property(_card, "scale", Vector2.ONE * SCALE_FROM, UiTokens.SCREEN_OUT)
	_tween.tween_property(_scrim, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	if _window_scrim != null:
		_tween.tween_property(_window_scrim, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		_release_scrim())


# Host teardown: drop input and the scrim at once, without a fade or a signal.
func dismiss() -> void:
	if not _open:
		return
	_open = false
	var nav := _ui_nav()
	if nav != null:
		nav.pop_modal(self)
	if _tween != null:
		_tween.kill()
	visible = false
	_release_scrim()


func is_open() -> bool:
	return _open


func sort_key() -> String:
	return _sort


func direction() -> String:
	return _direction


func focus_index() -> int:
	return _focus


# Build ----------------------------------------------------------------------

func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW_SELECTED
	box.shadow_size = 44
	box.shadow_offset = Vector2(0.0, 24.0)
	box.content_margin_left = PAD
	box.content_margin_right = PAD
	box.content_margin_top = 22.0
	box.content_margin_bottom = PAD
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", int(ROW_GAP))
	_card.add_child(column)

	var title := Label.new()
	title.name = "Title"
	_title_label = title
	title.text = "SORT PLAYERS"
	title.add_theme_font_override(&"font", UiTheme.barlow(700))
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", UiTokens.INK)
	column.add_child(title)

	_rows.append(_make_toggle("SORT BY", 0))
	_rows.append(_make_toggle("ORDER", 1))
	for row in _rows:
		column.add_child(row["panel"])

	_confirm_panel = PanelContainer.new()
	_confirm_panel.name = "Confirm"
	_confirm_panel.custom_minimum_size = Vector2(0.0, ROW_H + 8.0)
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_panel.gui_input.connect(_on_confirm_input)
	_confirm_panel.mouse_entered.connect(_focus_row.bind(CONFIRM))
	column.add_child(_confirm_panel)
	_confirm_label = Label.new()
	_confirm_label.text = "CONFIRM"
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_label.add_theme_font_override(&"font", UiTheme.barlow(700))
	_confirm_label.add_theme_font_size_override(&"font_size", 24)
	_confirm_panel.add_child(_confirm_label)


func _make_toggle(title: String, index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Toggle%d" % index
	panel.custom_minimum_size = Vector2(0.0, ROW_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_row_input.bind(index))
	panel.mouse_entered.connect(_focus_row.bind(index))
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	panel.add_child(line)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", UiTheme.inter(600))
	label.add_theme_font_size_override(&"font_size", 15)
	line.add_child(label)
	var left := _make_arrow("‹")
	line.add_child(left)
	var value := Label.new()
	value.custom_minimum_size.x = 150.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_override(&"font", UiTheme.barlow(700))
	value.add_theme_font_size_override(&"font_size", 20)
	line.add_child(value)
	var right := _make_arrow("›")
	line.add_child(right)
	return {"panel": panel, "label": label, "value": value, "left": left, "right": right}


func _make_arrow(text: String) -> Label:
	var arrow := Label.new()
	arrow.text = text
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_font_override(&"font", UiTheme.barlow(700))
	arrow.add_theme_font_size_override(&"font_size", 22)
	arrow.modulate.a = 0.0
	return arrow


# State ----------------------------------------------------------------------

func _refresh() -> void:
	if _rows.is_empty():
		return
	_title_label.text = _title
	var values := [
		_option_label(_fields, _sort, "OVR"),
		_option_label(DIRECTIONS, _direction, "ASCENDING"),
	]
	for index in _rows.size():
		var row: Dictionary = _rows[index]
		var focused := _focus == index
		(row["panel"] as PanelContainer).add_theme_stylebox_override(&"panel",
			_box(focused, Color(UiTokens.INK, 0.055)))
		(row["label"] as Label).add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK_2)
		(row["value"] as Label).text = values[index]
		(row["value"] as Label).add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
		for key in ["left", "right"]:
			(row[key] as Label).modulate.a = 1.0 if focused else 0.0
			(row[key] as Label).add_theme_color_override(&"font_color",
				UiTokens.FOCUS_MARK)
	var confirm_focused := _focus == CONFIRM
	_confirm_panel.add_theme_stylebox_override(&"panel",
		_box(confirm_focused, Color(UiTokens.INK, 0.08)))
	_confirm_label.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if confirm_focused else UiTokens.RAIL)


func _box(focused: bool, fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_FILL if focused else fill
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	box.anti_aliasing = true
	return box


func _cycle(options: Array, current: String, delta: int) -> String:
	var index := _option_index(options, current)
	return str(options[posmod(index + delta, options.size())]["value"])


func _option_index(options: Array, value: String) -> int:
	for index in options.size():
		if str(options[index]["value"]) == value:
			return index
	return 0


func _option_value(options: Array, value: String, fallback: String) -> String:
	for option in options:
		if str(option["value"]) == value:
			return value
	return fallback


func _option_label(options: Array, value: String, fallback: String) -> String:
	for option in options:
		if str(option["value"]) == value:
			return str(option["label"])
	return fallback


# Input ----------------------------------------------------------------------

func _step(index: int, delta: int) -> void:
	if index == 0:
		_sort = _cycle(_fields, _sort, delta)
	elif index == 1:
		_direction = _cycle(DIRECTIONS, _direction, delta)
	else:
		return
	_refresh()


func _focus_row(index: int) -> void:
	_focus = index
	_refresh()


func _commit() -> void:
	applied.emit(_sort, _direction)
	close()


func _on_row_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_focus = index
	var width := (_rows[index]["panel"] as Control).size.x
	_step(index, -1 if mouse.position.x < width * 0.5 else 1)


func _on_confirm_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_commit()


func _on_scrim_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		close()


func _connect_nav() -> void:
	var nav := _ui_nav()
	if nav == null:
		return
	nav.moved.connect(_on_nav_moved)
	nav.confirmed.connect(_on_nav_confirmed)
	nav.cancelled.connect(_on_nav_cancelled)


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_modal_owner():
		return
	match direction:
		Vector2i.LEFT:
			_step(_focus, -1)
		Vector2i.RIGHT:
			_step(_focus, 1)
		Vector2i.UP:
			_focus_row(maxi(0, _focus - 1))
		Vector2i.DOWN:
			_focus_row(mini(CONFIRM, _focus + 1))


func _on_nav_confirmed() -> void:
	if not _is_modal_owner():
		return
	if _focus == CONFIRM:
		_commit()
	else:
		_step(_focus, 1)


func _on_nav_cancelled() -> void:
	if _is_modal_owner():
		close()


func _is_modal_owner() -> bool:
	var nav := _ui_nav()
	return _open and nav != null and nav.modal_owner() == self


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


# Layout ---------------------------------------------------------------------

func _layout() -> void:
	if _scrim == null:
		return
	_scrim.position = Vector2.ZERO
	_scrim.size = size
	if _card == null or size.x <= 0.0:
		return
	_card.custom_minimum_size.x = CARD_W
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((size - _card.size) * 0.5).round()
	_card.pivot_offset = _card.size * 0.5


# The design canvas is letterboxed inside the window, so a scrim drawn inside it
# leaves the bars at the edges uncovered. A second dim layer on the screen root
# covers the whole window (transparent to input; the card's scrim keeps the
# click-to-close), like the other career modals.
func _host_scrim() -> void:
	var tree := get_tree()
	if tree == null or _scrim == null or _window_scrim != null:
		return
	var screen := tree.current_scene
	if not (screen is Control) or screen == self:
		return
	_window_scrim = ColorRect.new()
	_window_scrim.name = "WindowScrim"
	_window_scrim.color = SCRIM
	_window_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_scrim.z_index = 90
	_window_scrim.modulate.a = 0.0
	(screen as Control).add_child(_window_scrim)
	_window_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(SCRIM, 0.0)


func _release_scrim() -> void:
	if _window_scrim != null:
		_window_scrim.queue_free()
		_window_scrim = null
	if _scrim != null:
		_scrim.color = SCRIM


func _exit_tree() -> void:
	_release_scrim()
	if _open:
		var nav := _ui_nav()
		if nav != null:
			nav.pop_modal(self)
		_open = false
