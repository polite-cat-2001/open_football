class_name GpfReplay
extends Node
# Goal replay presentation: a short ring buffer of actor poses, ball, camera and net
# state. While playing it pauses the C++ match and drives the recorded frames itself.

const MAX_FRAMES := 300
const MIN_FRAMES := 30
const TAIL_FRAMES := 180
const PLAYBACK_FPS := 60.0

var replay_layer: CanvasLayer
var replay_banner: Label
var replay_hint: Label

var replay_history: Array = []
var replay_frames: Array = []
var pending_replay_frames: Array = []
var replay_tail: Array = []
var replay_tail_active := false
var replay_time := 0.0
var goal_replay_captured := false

var _active := false
var _runtime: Node
var _camera: Camera3D
var _actors: GpfActors
var _goal_nets: GpfGoalNets
var _hud: GpfHud


func setup(runtime: Node, camera: Camera3D, actors: GpfActors, goal_nets: GpfGoalNets,
		hud: GpfHud) -> void:
	_runtime = runtime
	_camera = camera
	_actors = actors
	_goal_nets = goal_nets
	_hud = hud
	_build_ui()


func is_active() -> bool:
	return _active


func record(poses: Dictionary) -> void:
	if _active:
		return
	var frame := {
		"poses": poses,
		"ball": _actors.capture_ball_transform(),
		"camera": _camera.global_transform,
		"camera_fov": _camera.fov,
		"camera_near": _camera.near,
		"camera_far": _camera.far,
		"net_positions": _goal_nets.get_positions(),
	}
	replay_history.append(frame)
	while replay_history.size() > MAX_FRAMES:
		replay_history.pop_front()
	if replay_tail_active:
		replay_tail.append(frame)
		if replay_tail.size() >= TAIL_FRAMES:
			replay_tail_active = false


func on_snapshot(snap: Dictionary) -> void:
	_capture_goal(snap)
	_update_moment(snap)


func update(delta: float) -> void:
	if replay_frames.is_empty():
		finish()
		return
	replay_time += delta
	var frame_index := int(replay_time * PLAYBACK_FPS)
	if frame_index >= replay_frames.size():
		finish()
		return
	_apply_frame(replay_frames[frame_index])


func finish() -> void:
	if not _active:
		return
	_active = false
	replay_frames.clear()
	pending_replay_frames.clear()
	replay_tail.clear()
	replay_tail_active = false
	replay_history.clear()
	goal_replay_captured = false
	replay_time = 0.0
	_runtime.set_replay_active(false)
	if replay_banner != null:
		replay_banner.visible = false
	if replay_hint != null:
		replay_hint.visible = false
	_hud.set_replay_mode(false)
	_actors.set_labels_visible(true)


func _capture_goal(snap: Dictionary) -> void:
	if not bool(snap.get("goal_scored", false)):
		goal_replay_captured = false
		return
	if goal_replay_captured or _active:
		return
	goal_replay_captured = true
	pending_replay_frames = replay_history.duplicate()
	replay_tail.clear()
	replay_tail_active = true


func _update_moment(snap: Dictionary) -> void:
	if _active or not bool(snap.get("replay_moment", false)):
		return
	if pending_replay_frames.size() >= MIN_FRAMES:
		_start()
	else:
		_runtime.set_replay_active(false)


func _start() -> void:
	replay_frames = pending_replay_frames.duplicate()
	replay_frames.append_array(replay_tail)
	pending_replay_frames.clear()
	replay_tail.clear()
	replay_tail_active = false
	replay_history.clear()
	replay_time = 0.0
	_active = true
	_runtime.set_replay_active(true)
	if replay_banner != null:
		replay_banner.visible = true
	if replay_hint != null:
		replay_hint.visible = true
	_hud.set_replay_mode(true)
	_actors.set_labels_visible(false)
	_actors.set_reticle_visible(false)


func _apply_frame(frame: Dictionary) -> void:
	var poses: Dictionary = frame.get("poses", {})
	for id in poses:
		_actors.apply_pose(int(id), poses[id])
	_camera.global_transform = frame.get("camera", _camera.global_transform)
	_camera.fov = float(frame.get("camera_fov", _camera.fov))
	_camera.near = float(frame.get("camera_near", _camera.near))
	_camera.far = float(frame.get("camera_far", _camera.far))
	_actors.apply_ball_transform(frame.get("ball", _actors.capture_ball_transform()))
	_goal_nets.apply_positions(frame.get("net_positions", []))


func _build_ui() -> void:
	replay_layer = CanvasLayer.new()
	replay_layer.name = "ReplayOverlay"
	replay_layer.layer = 1
	add_child(replay_layer)
	replay_banner = Label.new()
	replay_banner.name = "ReplayBanner"
	replay_banner.text = "REPLAY"
	replay_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	replay_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	replay_banner.offset_top = 34
	replay_banner.add_theme_font_size_override("font_size", 34)
	replay_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	replay_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	replay_banner.add_theme_constant_override("outline_size", 6)
	replay_banner.visible = false
	replay_layer.add_child(replay_banner)
	replay_hint = Label.new()
	replay_hint.name = "ReplayHint"
	replay_hint.text = "SPACE / ESC — skip"
	replay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	replay_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	replay_hint.offset_top = 82
	replay_hint.add_theme_font_size_override("font_size", 16)
	replay_hint.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	replay_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	replay_hint.add_theme_constant_override("outline_size", 4)
	replay_hint.visible = false
	replay_layer.add_child(replay_hint)
