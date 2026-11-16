class_name CareerScoutingModal
extends Control
# Shared modal shell of the scouting screen, ported from the prototype's
# ScoutingModal / ScoutActionsModal / PlayerActionsModal overlays: a scrim, a
# light card with a title line, an optional content block (the player pane for
# the report card, a list for hiring) and a stack of action rows.
#
# Owns UiNav while open (push_modal / pop_modal), fades + scales in 240 ms and
# out in 150 ms, and reports the chosen row id. Content controls keep their own
# buttons: the shell only moves focus and confirms them.

signal action_chosen(id: String)
signal closed

const CARD_W := 860.0
const PAD := 16.0
const ROW_H := 46.0
const MARGIN := 24.0
const MAX_HEIGHT_RATIO := 0.92
const SCALE_FROM := 0.96
const SCRIM := Color(0.024, 0.047, 0.102, 0.68)


# One action row: label on the left, the ticket (key or reason) on the right.
class Row extends Button:
	var id := ""
	var enabled := true
	var _bg: Panel
	var _label: Label
	var _ticket: Label
	var _normal: StyleBoxFlat
	var _focus: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_normal = StyleBoxFlat.new()
		_normal.bg_color = Color(UiTokens.INK, 0.055)
		_normal.anti_aliasing = true
		_focus = StyleBoxFlat.new()
		_focus.bg_color = UiTokens.FOCUS_FILL
		_focus.anti_aliasing = true
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_override(&"font", UiTheme.inter(600))
		_label.add_theme_font_size_override(&"font_size", 20)
		add_child(_label)
		_ticket = Label.new()
		_ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ticket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ticket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ticket.add_theme_font_override(&"font", UiTheme.inter(600))
		_ticket.add_theme_font_size_override(&"font_size", 15)
		add_child(_ticket)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func setup(row_id: String, label_text: String, ticket_text: String,
			row_enabled := true) -> void:
		id = row_id
		enabled = row_enabled
		_label.text = label_text.to_upper()
		_ticket.text = ticket_text
		_apply_state()
		_layout_content()

	func label_text() -> String:
		return "" if _label == null else str(_label.text)

	func _layout_content() -> void:
		if _bg == null:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		var ticket_w := 0.0
		if not _ticket.text.is_empty():
			var font := _ticket.get_theme_font(&"font")
			var width := font.get_string_size(_ticket.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			ticket_w = maxf(26.0, width + 14.0)
		_ticket.position = Vector2(size.x - 14.0 - ticket_w, (size.y - 24.0) * 0.5)
		_ticket.size = Vector2(ticket_w, 24.0)
		_label.position = Vector2(16.0, 0.0)
		_label.size = Vector2(maxf(0.0, size.x - 32.0 - ticket_w - 10.0), size.y)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus if focused else _normal)
		var ink := UiTokens.FOCUS_MARK if focused and enabled else (
			UiTokens.FOCUS_INK_2 if focused else (UiTokens.INK if enabled else UiTokens.INK_2))
		_label.add_theme_color_override(&"font_color", ink)
		_ticket.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.FOCUS_INK, 0.12) if focused \
			else Color(UiTokens.INK, 0.07)
		box.content_margin_left = 6.0
		box.content_margin_right = 6.0
		_ticket.add_theme_stylebox_override(&"normal", box)


var _scrim: ColorRect
var _card: PanelContainer
var _box: VBoxContainer
var _window_scrim: ColorRect
var _head: MarginContainer
var _title: Label
var _subtitle: Label
var _content_holder: MarginContainer
var _rows_holder: MarginContainer
var _rows_box: VBoxContainer
var _rows: Array[Row] = []
var _content: Control = null
var _extra_focus: Array[Control] = []
var _open := false
var _armed := false
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


func setup(title: String, subtitle: String, rows: Array) -> void:
	if _title == null:
		return
	_title.text = title.to_upper()
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	_rebuild_rows(rows)
	_layout()
	call_deferred("_layout")


func set_content(node: Control) -> void:
	if _content != null:
		_content.queue_free()
	_content = null
	if node == null or _card == null:
		return
	_content = node
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_holder.add_child(node)
	_content_holder.visible = true
	_sync_padding()
	if node.has_method("action_buttons"):
		_extra_focus.clear()
	_layout()
	call_deferred("_layout")


func set_focusables(nodes: Array) -> void:
	_extra_focus.clear()
	for node in nodes:
		if node is Control:
			_extra_focus.append(node)


func content() -> Control:
	return _content


func open() -> void:
	if _open:
		return
	# Before `_open`: reparenting leaves and re-enters the tree, and _exit_tree
	# pops an open modal off the stack.
	host_overlay(self)
	_host_scrim()
	_open = true
	_armed = false
	visible = true
	move_to_front()
	var nav := _ui_nav()
	if nav != null:
		nav.push_modal(self)
	# An open triggered from another modal's confirm handler lands in the middle
	# of the same UiNav event; stay deaf until the next frame so the very event
	# that opened this card does not also press its first row.
	call_deferred("_arm")
	_layout()
	focus_first()
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
	_armed = false
	var nav := _ui_nav()
	if nav != null:
		nav.pop_modal(self)
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()
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


# The design canvas is letterboxed inside the window, so a scrim drawn inside it
# leaves the bars at the edges uncovered. A second dim layer on the screen root
# covers the whole window; it is input-transparent (a root-level STOP rect would
# eat the mouse before the card, as Godot picks Controls by tree order, not z),
# and the card's own scrim keeps the click-to-close.
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


func is_open() -> bool:
	return _open


func row_ids() -> Array:
	var ids: Array = []
	for row in _rows:
		ids.append(row.id)
	return ids


func row_enabled(id: String) -> bool:
	for row in _rows:
		if row.id == id:
			return row.enabled
	return false


func row_label(id: String) -> String:
	for row in _rows:
		if row.id == id:
			return row.label_text()
	return ""


func focus_first() -> void:
	var list := _focusables()
	if not list.is_empty():
		list[0].grab_focus()


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
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)

	# A PanelContainer lays every child out over its own rect, so the title, the
	# content and the rows have to share one column or they overlap.
	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.add_theme_constant_override(&"separation", 8)
	_card.add_child(_box)

	_head = _margin(12, 0)
	_head.name = "Head"
	_box.add_child(_head)
	var titles := VBoxContainer.new()
	titles.name = "Titles"
	titles.add_theme_constant_override(&"separation", 2)
	_head.add_child(titles)

	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_override(&"font", UiTheme.barlow(800))
	_title.add_theme_font_size_override(&"font_size", 26)
	_title.add_theme_color_override(&"font_color", UiTokens.INK)
	titles.add_child(_title)
	_subtitle = Label.new()
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.clip_text = true
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.add_theme_font_override(&"font", UiTheme.inter(500))
	_subtitle.add_theme_font_size_override(&"font_size", 15)
	_subtitle.add_theme_color_override(&"font_color", UiTokens.INK_2)
	titles.add_child(_subtitle)

	_content_holder = _margin(0, 0)
	_content_holder.name = "Content"
	_content_holder.visible = false
	_box.add_child(_content_holder)

	_rows_holder = _margin(0, int(PAD))
	_rows_holder.name = "Rows"
	_rows_holder.visible = false
	_box.add_child(_rows_holder)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "List"
	_rows_box.add_theme_constant_override(&"separation", 1)
	_rows_holder.add_child(_rows_box)


func _margin(top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", int(PAD))
	margin.add_theme_constant_override(&"margin_right", int(PAD))
	margin.add_theme_constant_override(&"margin_top", top)
	margin.add_theme_constant_override(&"margin_bottom", bottom)
	return margin


func _rebuild_rows(rows: Array) -> void:
	for row in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	for data in rows:
		if not (data is Dictionary):
			continue
		var row := Row.new()
		row.custom_minimum_size.y = ROW_H
		_rows_box.add_child(row)
		row.setup(str((data as Dictionary).get("id", "")),
			str((data as Dictionary).get("label", "")),
			str((data as Dictionary).get("ticket", "A")),
			bool((data as Dictionary).get("enabled", true)))
		row.pressed.connect(_on_row_pressed.bind(row))
		_rows.append(row)
	_rows_holder.visible = not _rows.is_empty()
	_sync_padding()


# The last block of the card always ends with the same inset as its sides, also
# when the modal has no action rows under the content (the hire list).
func _sync_padding() -> void:
	if _content_holder != null:
		_content_holder.add_theme_constant_override(&"margin_bottom",
			0 if not _rows.is_empty() else int(PAD))
	if _rows_holder != null:
		_rows_holder.add_theme_constant_override(&"margin_bottom", int(PAD))


func _on_row_pressed(row: Row) -> void:
	if not row.enabled:
		return
	action_chosen.emit(row.id)


# Layout / input -------------------------------------------------------------

func _layout() -> void:
	if _scrim == null:
		return
	_scrim.position = Vector2.ZERO
	_scrim.size = size
	if _card == null or size.x <= 0.0:
		return
	# The card is as tall as its column needs, capped by the screen: no leftover
	# strip, and the player report card can reach almost the full viewport.
	var width := minf(CARD_W, maxf(320.0, size.x - 40.0))
	var available := maxf(0.0, size.y - MARGIN * 2.0)
	var max_h := minf(available, size.y * MAX_HEIGHT_RATIO)
	_card.custom_minimum_size.x = width
	var height := clampf(_card.get_combined_minimum_size().y, 120.0, max_h)
	_card.size = Vector2(width, height)
	_card.position = Vector2(roundf((size.x - width) * 0.5),
		roundf(MARGIN + (available - height) * 0.5))
	_card.pivot_offset = _card.size * 0.5


func _focusables() -> Array[Control]:
	var list: Array[Control] = []
	if not _extra_focus.is_empty():
		list.append_array(_extra_focus)
	elif _content != null and _content.has_method("action_buttons"):
		for button in _content.call("action_buttons"):
			if button is Control:
				list.append(button)
	for row in _rows:
		list.append(row)
	return list


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
	if direction != Vector2i.UP and direction != Vector2i.DOWN:
		return
	var list := _focusables()
	if list.is_empty():
		return
	var focus := get_viewport().gui_get_focus_owner()
	var index := list.find(focus)
	if index < 0:
		index = 0 if direction == Vector2i.DOWN else list.size() - 1
	else:
		index = clampi(index + (-1 if direction == Vector2i.UP else 1), 0, list.size() - 1)
	list[index].grab_focus()
	if _content is ScrollContainer:
		(_content as ScrollContainer).ensure_control_visible(list[index])


func _on_nav_confirmed() -> void:
	if not _is_modal_owner():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Row:
		_on_row_pressed(focus as Row)
	elif focus is Button:
		(focus as Button).pressed.emit()


func _on_nav_cancelled() -> void:
	if _is_modal_owner():
		close()


# A click on the dark backdrop closes the card; a click on the card itself never
# reaches the scrim (the card stops the mouse).
func _on_scrim_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		close()


# The screen body is a widget: a scrim parented there only dims that widget and
# a tall card is clipped by it. Career overlays move onto the full-screen design
# canvas (the 1920x1080 node the hub's own overlays live on) while they are open.
# Headless tests host the screen in a plain full-rect control, which is found the
# same way; a smaller parent keeps the overlay where it is.
static func host_overlay(overlay: Control) -> void:
	var host: Control = null
	var node := overlay.get_parent()
	while node != null and node is Control:
		if is_equal_approx((node as Control).size.x, UiTokens.DESIGN_SIZE.x) \
				and is_equal_approx((node as Control).size.y, UiTokens.DESIGN_SIZE.y):
			host = node as Control
		node = node.get_parent()
	if host == null or host == overlay.get_parent():
		return
	overlay.reparent(host, false)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _is_modal_owner() -> bool:
	var nav := _ui_nav()
	return _open and _armed and nav != null and nav.modal_owner() == self


func _arm() -> void:
	if _open:
		_armed = true


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _exit_tree() -> void:
	_release_scrim()
	if _open:
		var nav := _ui_nav()
		if nav != null:
			nav.pop_modal(self)
		_open = false
