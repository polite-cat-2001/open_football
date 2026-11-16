class_name UiTabBar
extends Control

# Port of the prototype TabBar: a translucent strip, a measured sliding marker
# (white plate with a 4px magenta rule; dark plate with a lime rule while the
# bar owns focus) and uppercase tabs.

signal tab_selected(index: int)
signal bar_focused

const TAB_PADDING := 64.0

var _labels: Array[String] = []
var _buttons: Array[Button] = []
var _badges: Array[PanelContainer] = []
var _strip: ColorRect
var _marker: Panel
var _normal_marker: StyleBoxFlat
var _focused_marker: StyleBoxFlat
var _active := 0
var _bar_focused := false
var _marker_tween: Tween
# Screens that never hand keyboard focus to the tabs (the game plan) still
# want the focused look, so they can pin it on.
var always_focused := false
# A host with its own focus model drives the bar instead of the viewport.
var external_focus := false


func setup(labels: Array[String]) -> void:
	_labels = labels
	_build()
	_layout_tabs()
	_update_colors()
	_update_marker(false)


func select_tab(index: int, emit_signal := true) -> void:
	if _labels.is_empty():
		return
	_active = clampi(index, 0, _labels.size() - 1)
	_update_colors()
	_update_marker(true)
	if emit_signal:
		tab_selected.emit(_active)


func get_active_tab() -> int:
	return _active


func get_tab_button(index: int) -> Button:
	if index < 0 or index >= _buttons.size():
		return null
	return _buttons[index]


func tab_count() -> int:
	return _buttons.size()


# The tab's rect in bar coordinates: a view that hosts the bar inside its own
# layout (the squad centre draws its body) maps its hit areas to these.
func tab_rect(index: int) -> Rect2:
	if index < 0 or index >= _buttons.size():
		return Rect2()
	return Rect2(_buttons[index].position, _buttons[index].size)


# External-focus mode: the host owns the focus model (custom-drawn screens), so
# the buttons never take viewport focus and the plate state is driven by
# `set_focused`. Mouse still picks a tab.
func set_focused(value: bool) -> void:
	if _bar_focused == value:
		return
	_bar_focused = value
	_update_colors()


func is_focused() -> bool:
	return _bar_focused or always_focused


func set_badge(index: int, count: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	var badge: PanelContainer = _badges[index]
	if badge == null:
		badge = _build_badge(_buttons[index])
		_badges[index] = badge
	badge.get_node("Count").text = str(count)
	badge.visible = count > 0
	_layout_tabs()


func _build_badge(button: Button) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.RAIL
	box.content_margin_left = 5.0
	box.content_margin_right = 5.0
	badge.add_theme_stylebox_override(&"panel", box)
	var label := Label.new()
	label.name = "Count"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.inter(700))
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK)
	badge.add_child(label)
	button.add_child(badge)
	return badge


func refresh_layout() -> void:
	if _strip == null:
		return
	_layout_tabs()
	_update_marker(false)


func fit_width() -> void:
	# The bar is only as wide as its tabs, like the prototype's flex: 0 1 auto.
	if _strip == null:
		return
	_layout_tabs()
	var width := 0.0
	if not _buttons.is_empty():
		width = _buttons[-1].position.x + _buttons[-1].size.x
	size = Vector2(width, UiTokens.TAB_H)
	_layout_tabs()
	_update_marker(false)


func focus_tab(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_buttons[index].grab_focus()


func _build() -> void:
	if _strip != null:
		return
	_strip = ColorRect.new()
	_strip.name = "Strip"
	_strip.color = UiTokens.TAB_STRIP
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)

	_marker = Panel.new()
	_marker.name = "Marker"
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker)

	_normal_marker = StyleBoxFlat.new()
	_normal_marker.bg_color = UiTokens.TILE
	_normal_marker.border_color = UiTokens.RAIL
	_normal_marker.border_width_bottom = 4
	_focused_marker = StyleBoxFlat.new()
	_focused_marker.bg_color = UiTokens.FOCUS_FILL
	_focused_marker.border_color = UiTokens.FOCUS_MARK
	_focused_marker.border_width_bottom = 4

	for i in _labels.size():
		var button := Button.new()
		button.name = "Tab" + _labels[i].capitalize()
		button.text = _labels[i]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE if external_focus else Control.FOCUS_ALL
		button.theme_type_variation = &"TabButton"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(select_tab.bind(i))
		if not external_focus:
			button.focus_entered.connect(_on_tab_focus_entered)
			button.focus_exited.connect(_on_tab_focus_exited)
			button.mouse_entered.connect(button.grab_focus)
		add_child(button)
		_buttons.append(button)
		_badges.append(null)


func _layout_tabs() -> void:
	_strip.position = Vector2.ZERO
	_strip.size = size
	var font := UiTheme.barlow(700)
	var x := 0.0
	for i in _buttons.size():
		var text_width := font.get_string_size(
			_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.SIZE_TAB
		).x
		var badge: PanelContainer = _badges[i]
		var badge_w := 30.0 if badge != null and badge.visible else 0.0
		var width := text_width + TAB_PADDING + badge_w
		_buttons[i].position = Vector2(x, 0.0)
		_buttons[i].size = Vector2(width, UiTokens.TAB_H)
		if badge != null:
			badge.position = Vector2(width - 30.0, (UiTokens.TAB_H - 22.0) * 0.5)
			badge.size = Vector2(22.0, 22.0)
		x += width
	_marker.size = Vector2(
		_buttons[_active].size.x if not _buttons.is_empty() else 0.0,
		UiTokens.TAB_H
	)


func _update_colors() -> void:
	var focused := _bar_focused or always_focused
	for i in _buttons.size():
		var color := UiTokens.TAB_INACTIVE
		if i == _active:
			color = UiTokens.FOCUS_MARK if focused else UiTokens.INK
		for item in [&"font_color", &"font_hover_color", &"font_pressed_color",
				&"font_focus_color", &"font_disabled_color"]:
			_buttons[i].add_theme_color_override(item, color)
	_marker.add_theme_stylebox_override(
		&"panel", _focused_marker if focused else _normal_marker
	)


func _update_marker(animate: bool) -> void:
	if _marker == null or _buttons.is_empty():
		return
	var button := _buttons[_active]
	var target := Vector2(button.position.x, 0.0)
	var target_size := Vector2(button.size.x, UiTokens.TAB_H)
	if not animate:
		_marker.position = target
		_marker.size = target_size
		return
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = create_tween().set_parallel(true)
	_marker_tween.tween_property(_marker, "position", target, UiTokens.TAB_MARKER) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_marker_tween.tween_property(_marker, "size", target_size, UiTokens.TAB_MARKER) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_tab_focus_entered() -> void:
	if not _bar_focused:
		_bar_focused = true
		bar_focused.emit()
	_update_colors()


func _on_tab_focus_exited() -> void:
	call_deferred("_check_focus_lost")


func _check_focus_lost() -> void:
	if not is_inside_tree():
		return
	var owner := get_viewport().gui_get_focus_owner()
	for button in _buttons:
		if button == owner:
			return
	_bar_focused = false
	_update_colors()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed(&"ui_left"):
		select_tab(_active - 1)
		focus_tab(_active)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		select_tab(_active + 1)
		focus_tab(_active)
		accept_event()
