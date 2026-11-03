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

	await _swap_overlap(path, packed)
	await get_tree().process_frame

	var next := _current_target()
	if next != null:
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


# Windowed scene change: add the next scene above the old one, let it render one
# frame, then free the old scene. Without the overlap the viewport shows one
# clear-colour frame between freeing the old scene and drawing the new one.
func _swap_overlap(path: String, packed: PackedScene) -> void:
	var scene := packed
	if scene == null:
		scene = load(path) as PackedScene
	if scene == null:
		push_error("UiTransition: cannot load scene: " + path)
		return
	var old := get_tree().current_scene
	var next := scene.instantiate()
	var target := _find_target(next)
	if target == null:
		# The next screen has no explicit transition target: keep the old cut
		# (it now happens on the stage-coloured clear frame, not grey).
		next.free()
		_swap("", scene)
		return
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	target.modulate.a = 0.0
	target.scale = Vector2.ONE * SCALE_FROM
	target.pivot_offset = target.size * 0.5
	if old != null:
		old.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	if old != null:
		old.queue_free()


func _find_target(scene: Node) -> Control:
	if scene.is_in_group(TARGET_GROUP):
		return scene as Control
	for child in scene.get_children():
		var found := _find_target(child)
		if found != null:
			return found
	return null


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
