class_name CareerAccordion
extends Control
# The career accordion, ported from the prototype's Accordion.svelte: a navy
# plate that unfolds its content instead of popping it over the neighbours. The
# height is animated (and the content clipped), so a list that hosts it can
# reflow and push the rows below; opening is 200 ms, closing 160 ms.
#
# Hosts read `height()` and listen to `height_changed` while the fold animates:
# the host decides what to shift (a VBox reflows on custom_minimum_size, a
# hand-drawn list repositions its rows).

signal height_changed
signal closed

const PAD_X := 16.0
const PAD_Y := 12.0
const OPEN_TIME := 0.2
const CLOSE_TIME := 0.16

var _content: Control = null
var _plate: Panel
var _tween: Tween
var _open := false
var _full_h := 0.0
var _height := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_FILL_SOFT
	_plate = Panel.new()
	_plate.name = "Plate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override(&"panel", box)
	add_child(_plate)
	resized.connect(_layout_content)


func set_content(node: Control) -> void:
	if _content != null:
		_content.queue_free()
	_content = node
	if node == null:
		return
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(node)
	_full_h = content_height()
	if _open:
		_height = _full_h
		custom_minimum_size.y = _height
		_layout_content()


func content() -> Control:
	return _content


func is_open() -> bool:
	return _open


# Height the accordion needs when fully unfolded, plate padding included.
func content_height() -> float:
	if _content == null:
		return 0.0
	return maxf(0.0, _content.get_combined_minimum_size().y) + PAD_Y * 2.0


# Current (animating) height; hosts lay their rows out from it.
func height() -> float:
	return _height


func open(animate := true) -> void:
	_full_h = content_height()
	_open = true
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or _instant():
		_set_height(_full_h)
		modulate.a = 1.0
		return
	_set_height(0.0)
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		_set_height(_full_h * t)
		modulate.a = t, 0.0, 1.0, OPEN_TIME)


func close(animate := true) -> void:
	if not _open:
		return
	_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or _instant():
		_set_height(0.0)
		visible = false
		closed.emit()
		return
	var from := _height
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_method(func(t: float) -> void:
		_set_height(from * (1.0 - t))
		modulate.a = 1.0 - t, 0.0, 1.0, CLOSE_TIME)
	_tween.finished.connect(func() -> void:
		if not _open:
			visible = false
			closed.emit())


func _set_height(value: float) -> void:
	_height = maxf(0.0, value)
	custom_minimum_size.y = _height
	_plate.position = Vector2.ZERO
	_plate.size = Vector2(size.x, _height)
	_layout_content()
	height_changed.emit()


func _layout_content() -> void:
	if _content == null:
		return
	_plate.size = Vector2(size.x, _height)
	_content.position = Vector2(PAD_X, PAD_Y)
	_content.size = Vector2(maxf(0.0, size.x - PAD_X * 2.0),
		maxf(0.0, _height - PAD_Y * 2.0))


func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))
