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
var _strip: ColorRect
var _marker: Panel
var _normal_marker: StyleBoxFlat
var _focused_marker: StyleBoxFlat
var _active := 0
var _bar_focused := false
var _marker_tween: Tween


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


func refresh_layout() -> void:
	if _strip == null:
		return
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
		button.focus_mode = Control.FOCUS_ALL
		button.theme_type_variation = &"TabButton"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(select_tab.bind(i))
		button.focus_entered.connect(_on_tab_focus_entered)
		button.focus_exited.connect(_on_tab_focus_exited)
		button.mouse_entered.connect(button.grab_focus)
		add_child(button)
		_buttons.append(button)


func _layout_tabs() -> void:
	_strip.position = Vector2.ZERO
	_strip.size = size
	var font := UiTheme.barlow(700)
	var x := 0.0
	for i in _buttons.size():
		var text_width := font.get_string_size(
			_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.SIZE_TAB
		).x
		var width := text_width + TAB_PADDING
		_buttons[i].position = Vector2(x, 0.0)
		_buttons[i].size = Vector2(width, UiTokens.TAB_H)
		x += width
	_marker.size = Vector2(
		_buttons[_active].size.x if not _buttons.is_empty() else 0.0,
		UiTokens.TAB_H
	)


func _update_colors() -> void:
	for i in _buttons.size():
		var color := UiTokens.TAB_INACTIVE
		if i == _active:
			color = UiTokens.FOCUS_MARK if _bar_focused else UiTokens.INK
		for item in [&"font_color", &"font_hover_color", &"font_pressed_color",
				&"font_focus_color", &"font_disabled_color"]:
			_buttons[i].add_theme_color_override(item, color)
	_marker.add_theme_stylebox_override(
		&"panel", _focused_marker if _bar_focused else _normal_marker
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
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and _buttons.has(owner):
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
