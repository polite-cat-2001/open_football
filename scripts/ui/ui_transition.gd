extends Node

# Shell screen transition (autoload): fade/scale out, swap the scene, fade/scale
# in. The animated node is the current screen's "ui_transition_target" member
# (falls back to the scene root). In headless the swap is instant so existing
# tests keep their synchronous scene-change expectations.

const OUT_TIME := 0.15
const IN_TIME := 0.24
const SCALE_FROM := 0.96
const TARGET_GROUP := &"ui_transition_target"

var instant := false
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instant = DisplayServer.get_name() == "headless"


func is_busy() -> bool:
	return _busy


func change_scene(path: String) -> void:
	_run_change(path, null)


func change_scene_packed(packed: PackedScene) -> void:
	_run_change("", packed)


func change_content(target: Control, swap: Callable) -> void:
	_run_content_change(target, swap)


func _run_content_change(target: Control, swap: Callable) -> void:
	if _busy:
		return
	_busy = true

	if instant:
		swap.call()
		_busy = false
		return

	await _animate_out(target)
	swap.call()
	await get_tree().process_frame
	target.modulate.a = 0.0
	target.scale = Vector2.ONE * SCALE_FROM
	target.pivot_offset = target.size * 0.5
	await _animate_in(target)
	_busy = false


func _run_change(path: String, packed: PackedScene) -> void:
	if _busy:
		return
	_busy = true

	if instant:
		_swap(path, packed)
		_busy = false
		return

	var target := _current_target()
	if target != null:
		await _animate_out(target)

	_swap(path, packed)
	await get_tree().process_frame
	await get_tree().process_frame

	var next := _current_target()
	if next != null:
		next.modulate.a = 0.0
		next.scale = Vector2.ONE * SCALE_FROM
		next.pivot_offset = next.size * 0.5
		await _animate_in(next)
	_busy = false


func _swap(path: String, packed: PackedScene) -> void:
	var error := ERR_CANT_OPEN
	if packed != null:
		error = get_tree().change_scene_to_packed(packed)
	else:
		error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("UiTransition: cannot change scene: " + str(error))


func _current_target() -> Control:
	var node := get_tree().get_first_node_in_group(TARGET_GROUP) as Control
	if node != null:
		return node
	return get_tree().current_scene as Control


func _animate_out(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 0.0, OUT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(target, "scale", Vector2.ONE * SCALE_FROM, OUT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


func _animate_in(target: Control) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 1.0, IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
