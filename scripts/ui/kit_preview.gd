class_name KitPreview
extends Control
# Middle column of the kit select: "MATCH PREVIEW" header, a static 3D
# broadcast-camera diorama, and the two team names. The 3D node lives in its own
# SubViewport so the menu's 2D canvas stays flat.

const VIEWPORT_SIZE := Vector2i(640, 480)

var home_kit: Dictionary = {}
var away_kit: Dictionary = {}

var _shadow: Panel
var _gradient: TextureRect
var _title: Label
var _sub: Label
var _pitch_bg: ColorRect
var _pitch: TextureRect
var _footer: HBoxContainer
var _home_name: Label
var _vs: Label
var _away_name: Label
var _sub_viewport: SubViewport
var _preview_3d: KitPreview3D
var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_built()
	resized.connect(_layout)
	_layout()


func setup(state: Dictionary) -> void:
	_ensure_built()
	var home: Dictionary = state.get("home", {})
	var away: Dictionary = state.get("away", {})
	_home_name.text = _entry_name(home)
	_away_name.text = _entry_name(away)
	home_kit = home.get("kit", {})
	away_kit = away.get("kit", {})
	if _preview_3d != null:
		_preview_3d.set_kits(home_kit, away_kit)
	_layout()


func home_name_text() -> String:
	return _home_name.text


func away_name_text() -> String:
	return _away_name.text


func pitch_rect() -> Rect2:
	return Rect2(_pitch.position, _pitch.size)


func render_size() -> Vector2i:
	return _sub_viewport.size if _sub_viewport != null else Vector2i.ZERO


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_shadow = Panel.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_box := StyleBoxFlat.new()
	shadow_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	shadow_box.shadow_color = UiTokens.SHADOW
	shadow_box.shadow_size = 22
	shadow_box.shadow_offset = Vector2(0.0, 18.0)
	_shadow.add_theme_stylebox_override("panel", shadow_box)
	add_child(_shadow)

	_gradient = TextureRect.new()
	_gradient.name = "Gradient"
	_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_gradient.texture = _gradient_texture()
	add_child(_gradient)

	_title = _label("Title", &"KitPreviewTitle", "MATCH PREVIEW")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_title)
	_sub = _label("Sub", &"KitPreviewSub", "TOP CAMERA")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_sub)

	_pitch_bg = ColorRect.new()
	_pitch_bg.name = "PitchPlaceholder"
	_pitch_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pitch_bg.color = UiTokens.KIT_PREVIEW_PITCH
	add_child(_pitch_bg)

	_pitch = TextureRect.new()
	_pitch.name = "Pitch"
	_pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pitch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pitch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pitch.clip_contents = true
	_pitch.visible = false
	add_child(_pitch)

	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "PreviewViewport"
	_sub_viewport.size = VIEWPORT_SIZE
	_sub_viewport.own_world_3d = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.disable_3d = false
	add_child(_sub_viewport)
	# Instantiating 22 skinned bodies is the expensive part of this screen. Do it
	# after the panel has been laid out, so the scene transition is not stalled by
	# it (the placeholder grass is shown for one frame).
	_build_preview.call_deferred()

	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 14)
	add_child(_footer)

	_home_name = _label("HomeName", &"KitPreviewTeam", "—")
	_home_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_home_name)
	_vs = _label("Vs", &"KitPreviewVs", "VS")
	_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs.custom_minimum_size = Vector2(24.0, 0.0)
	_footer.add_child(_vs)
	_away_name = _label("AwayName", &"KitPreviewTeam", "—")
	_away_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_away_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_away_name)


func _build_preview() -> void:
	if _preview_3d != null:
		return
	_preview_3d = KitPreview3D.new()
	_preview_3d.name = "Preview3D"
	_sub_viewport.add_child(_preview_3d)
	_preview_3d.set_kits(home_kit, away_kit)
	_pitch.texture = _sub_viewport.get_texture()
	_pitch.visible = true
	_pitch_bg.visible = false
	_layout()


func _label(node_name: String, variation: StringName, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _gradient_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		UiTokens.KIT_PANEL_TOP,
		UiTokens.KIT_PANEL_BOTTOM,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 256
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


func _layout() -> void:
	if not _built or size.x <= 0.0 or size.y <= 0.0:
		return
	_shadow.position = Vector2.ZERO
	_shadow.size = size
	_gradient.position = Vector2.ZERO
	_gradient.size = size
	var pad := UiTokens.KIT_PREVIEW_PAD
	var head_height := UiTokens.KIT_PREVIEW_HEAD_H
	_title.position = Vector2(pad, pad)
	_title.size = Vector2(maxf(0.0, size.x - pad * 2.0 - 120.0), head_height)
	_sub.position = Vector2(size.x - pad - 120.0, pad)
	_sub.size = Vector2(120.0, head_height)

	var foot_height := UiTokens.KIT_PREVIEW_FOOT_H
	var foot_y := size.y - pad - foot_height
	_footer.position = Vector2(pad, foot_y)
	_footer.size = Vector2(size.x - pad * 2.0, foot_height)

	var pitch_y := pad + head_height + UiTokens.KIT_PREVIEW_GAP
	var pitch_bottom := foot_y - UiTokens.KIT_PREVIEW_GAP
	_pitch.position = Vector2(pad, pitch_y)
	_pitch.size = Vector2(size.x - pad * 2.0, maxf(0.0, pitch_bottom - pitch_y))
	_pitch_bg.position = _pitch.position
	_pitch_bg.size = _pitch.size


func _entry_name(entry: Dictionary) -> String:
	var name := str(entry.get("name", "")).strip_edges()
	return name.to_upper() if not name.is_empty() else "—"
