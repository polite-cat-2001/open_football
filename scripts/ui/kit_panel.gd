class_name KitPanel
extends Control
# One HOME/AWAY panel of the kit-select screen. Renders a snapshot only; the
# view owns focus and input, the adapter owns the chosen kit.

enum Mode { NORMAL, FOCUS, READY }

const PAD_SIDE := UiTokens.KIT_PAD_SIDE

var mode := Mode.NORMAL

var _shadow: Panel
var _gradient: TextureRect
var _solid: ColorRect
var _logo: TextureRect
var _team: Label
var _count: Label
var _name: Label
var _carousel: Control
var _left_arrow: KitArrow
var _right_arrow: KitArrow
var _prev_art: KitArt
var _hero_art: KitArt
var _next_art: KitArt
var _foot: Control
var _dots: HBoxContainer
var _ready_label: Label

var _kits: Array = []
var _kit_index := 0
var _is_ready := false
var _live := false
var _focus := false
var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_built()
	resized.connect(_layout)
	_layout()


func setup(data: Dictionary) -> void:
	_ensure_built()
	var team: Dictionary = data.get("team", {})
	_kits = data.get("kits", [])
	if not (_kits is Array):
		_kits = []
	_kit_index = clampi(int(data.get("kit_index", 0)), 0, maxi(0, _kits.size() - 1))
	_is_ready = bool(data.get("ready", false))
	_live = bool(data.get("live", false))
	_focus = bool(data.get("focus", _live))

	_team.text = _entry_name(team)
	var texture = team.get("texture", team.get("logo", null))
	_logo.texture = texture if texture is Texture2D else null
	_logo.visible = _logo.texture != null

	_count.text = "%d / %d" % [_kit_index + 1, _kits.size()] if not _kits.is_empty() else "—"
	var kit := _current_kit()
	_name.text = str(kit.get("label", "—")).to_upper() if not kit.is_empty() else "—"
	_hero_art.set_kit(kit)
	_prev_art.set_kit(_neighbor(-1))
	_next_art.set_kit(_neighbor(1))
	_build_dots()
	_apply_mode()
	_layout()


func set_focus(value: bool) -> void:
	if _focus == value:
		return
	_focus = value
	_apply_mode()


func kit_name_text() -> String:
	return _name.text


func team_name_text() -> String:
	return _team.text


func count_text() -> String:
	return _count.text


func kit_index() -> int:
	return _kit_index


func arrows_visible() -> bool:
	return _left_arrow.active and _right_arrow.active


func dots_visible() -> bool:
	return _dots.visible and _dots.get_child_count() > 0


func dots_count() -> int:
	return _dots.get_child_count()


func ready_visible() -> bool:
	return _is_ready and _ready_label.visible


func carousel_rect() -> Rect2:
	return Rect2(_carousel.position, _carousel.size)


func hero_rect() -> Rect2:
	return Rect2(_hero_art.position, _hero_art.size)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_shadow = Panel.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)

	_gradient = TextureRect.new()
	_gradient.name = "Gradient"
	_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_gradient.texture = _gradient_texture()
	add_child(_gradient)

	_solid = ColorRect.new()
	_solid.name = "Solid"
	_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solid.visible = false
	add_child(_solid)

	_logo = TextureRect.new()
	_logo.name = "TeamLogo"
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_logo)

	_team = _label("Team", &"KitTeam")
	add_child(_team)
	_count = _label("Count", &"KitCount", HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_count)
	_name = _label("KitName", &"KitName")
	add_child(_name)

	_carousel = Control.new()
	_carousel.name = "Carousel"
	_carousel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_carousel)

	_left_arrow = KitArrow.new()
	_left_arrow.name = "LeftArrow"
	_left_arrow.direction = -1
	_carousel.add_child(_left_arrow)
	_prev_art = KitArt.new()
	_prev_art.name = "PreviousKit"
	_carousel.add_child(_prev_art)
	_hero_art = KitArt.new()
	_hero_art.name = "HeroKit"
	_carousel.add_child(_hero_art)
	_next_art = KitArt.new()
	_next_art.name = "NextKit"
	_carousel.add_child(_next_art)
	_right_arrow = KitArrow.new()
	_right_arrow.name = "RightArrow"
	_right_arrow.direction = 1
	_carousel.add_child(_right_arrow)

	_foot = Control.new()
	_foot.name = "Foot"
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_foot)
	_dots = HBoxContainer.new()
	_dots.name = "Dots"
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.add_theme_constant_override("separation", int(UiTokens.KIT_DOT_GAP))
	_foot.add_child(_dots)
	_ready_label = _label("Ready", &"KitReady", HORIZONTAL_ALIGNMENT_CENTER)
	_ready_label.name = "Ready"
	_ready_label.text = "READY!"
	_ready_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_foot.add_child(_ready_label)


func _label(node_name: String, variation: StringName,
		alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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


func _current_kit() -> Dictionary:
	if _kits.is_empty():
		return {}
	return _kits[clampi(_kit_index, 0, _kits.size() - 1)]


func _neighbor(delta: int) -> Dictionary:
	if _kits.size() < 2:
		return {}
	var index := posmod(_kit_index + delta, _kits.size())
	return _kits[index]


func _build_dots() -> void:
	for child in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	var show := _kits.size() > 1 and _live and not _is_ready
	_dots.visible = show
	if not show:
		return
	for index in _kits.size():
		var dot := ColorRect.new()
		dot.name = "Dot%d" % index
		dot.custom_minimum_size = Vector2(UiTokens.KIT_DOT_W, UiTokens.KIT_DOT_H)
		dot.color = _dot_color(index == _kit_index)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)


func _dot_color(on: bool) -> Color:
	if _mode() == Mode.FOCUS:
		return UiTokens.KIT_DOT_ON_FOCUS if on else UiTokens.KIT_DOT_OFF_FOCUS
	return UiTokens.KIT_DOT_ON if on else UiTokens.KIT_DOT_OFF


func _mode() -> Mode:
	if _is_ready:
		return Mode.READY
	if _live and _focus:
		return Mode.FOCUS
	return Mode.NORMAL


func _apply_mode() -> void:
	mode = _mode()
	_gradient.visible = mode == Mode.NORMAL
	_solid.visible = not _gradient.visible
	_solid.color = UiTokens.KIT_PANEL_FOCUS if mode == Mode.FOCUS else UiTokens.KIT_PANEL_DARK
	_shadow.add_theme_stylebox_override("panel", _shadow_box(mode, StyleBoxFlat.new()))

	var dark := mode == Mode.FOCUS or mode == Mode.READY
	_team.add_theme_color_override("font_color",
		UiTokens.FOCUS_INK_2 if dark else UiTokens.INK_2)
	_count.add_theme_color_override("font_color",
		UiTokens.FOCUS_INK_2 if dark else UiTokens.INK_2)
	if mode == Mode.FOCUS:
		_name.add_theme_color_override("font_color", UiTokens.FOCUS_MARK)
	elif mode == Mode.READY:
		_name.add_theme_color_override("font_color", UiTokens.FOCUS_INK)
	else:
		_name.add_theme_color_override("font_color", UiTokens.INK)
	_ready_label.visible = mode == Mode.READY

	var arrow_active := _live and not _is_ready and _kits.size() > 1
	var arrow_color := UiTokens.KIT_ARROW_FOCUS if mode == Mode.FOCUS else UiTokens.KIT_ARROW_INK
	_left_arrow.set_state(arrow_active, arrow_color)
	_right_arrow.set_state(arrow_active, arrow_color)
	_prev_art.visible = _kits.size() > 1
	_next_art.visible = _kits.size() > 1
	for index in _dots.get_child_count():
		var dot := _dots.get_child(index) as ColorRect
		if dot != null:
			dot.color = _dot_color(index == _kit_index)
	_layout()


func _shadow_box(value: Mode, box: StyleBoxFlat) -> StyleBoxFlat:
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 0
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	if value == Mode.NORMAL:
		box.shadow_color = UiTokens.SHADOW
		box.shadow_size = 22
		box.shadow_offset = Vector2(0.0, 18.0)
	else:
		box.shadow_color = UiTokens.SHADOW_SELECTED
		box.shadow_size = 32
		box.shadow_offset = Vector2(0.0, 28.0)
	return box


func _layout() -> void:
	if not _built or size.x <= 0.0 or size.y <= 0.0:
		return
	_shadow.position = Vector2.ZERO
	_shadow.size = size
	_gradient.position = Vector2.ZERO
	_gradient.size = size
	_solid.position = Vector2.ZERO
	_solid.size = size

	var inner_width := size.x - PAD_SIDE * 2.0
	var head_y := UiTokens.KIT_PAD_TOP
	_logo.position = Vector2(PAD_SIDE, head_y + (UiTokens.KIT_HEAD_H - UiTokens.KIT_LOGO) * 0.5)
	_logo.size = Vector2(UiTokens.KIT_LOGO, UiTokens.KIT_LOGO)
	var team_x := PAD_SIDE + (UiTokens.KIT_LOGO + UiTokens.KIT_LOGO_GAP if _logo.visible else 0.0)
	var count_x := size.x - PAD_SIDE - 100.0
	_team.position = Vector2(team_x, head_y)
	_team.size = Vector2(maxf(0.0, count_x - team_x - 12.0), UiTokens.KIT_HEAD_H)
	_count.position = Vector2(count_x, head_y)
	_count.size = Vector2(100.0, UiTokens.KIT_HEAD_H)

	var name_y := head_y + UiTokens.KIT_HEAD_H + UiTokens.KIT_NAME_TOP
	_name.position = Vector2(PAD_SIDE, name_y)
	_name.size = Vector2(inner_width, UiTokens.KIT_NAME_H)

	var foot_height := UiTokens.KIT_FOOT_H
	var foot_y := size.y - UiTokens.KIT_PAD_BOTTOM - foot_height
	_foot.position = Vector2(PAD_SIDE, foot_y)
	_foot.size = Vector2(inner_width, foot_height)
	_ready_label.position = Vector2.ZERO
	_ready_label.size = Vector2(inner_width, foot_height)
	var dots_width := 0.0
	if _dots.visible:
		dots_width = _dots.get_combined_minimum_size().x
	_dots.position = Vector2((inner_width - dots_width) * 0.5, foot_height - UiTokens.KIT_DOT_H)
	_dots.size = Vector2(dots_width, UiTokens.KIT_DOT_H)

	var carousel_y := name_y + UiTokens.KIT_NAME_H + UiTokens.KIT_CAROUSEL_TOP
	var carousel_height := maxf(0.0, foot_y - carousel_y)
	_carousel.position = Vector2(PAD_SIDE, carousel_y)
	_carousel.size = Vector2(inner_width, carousel_height)
	var available := maxf(0.0, inner_width - UiTokens.KIT_ARROW_W * 2.0)
	var unit := available / 2.8
	var neighbor_width := unit * 0.45
	var hero_width := unit * 1.9
	_left_arrow.position = Vector2.ZERO
	_left_arrow.size = Vector2(UiTokens.KIT_ARROW_W, carousel_height)
	_right_arrow.position = Vector2(inner_width - UiTokens.KIT_ARROW_W, 0.0)
	_right_arrow.size = Vector2(UiTokens.KIT_ARROW_W, carousel_height)
	var neighbor_height := carousel_height * UiTokens.KIT_NEIGHBOR_H
	var neighbor_y := (carousel_height - neighbor_height) * 0.5
	_prev_art.position = Vector2(UiTokens.KIT_ARROW_W, neighbor_y)
	_prev_art.size = Vector2(neighbor_width, neighbor_height)
	_hero_art.position = Vector2(UiTokens.KIT_ARROW_W + neighbor_width, 0.0)
	_hero_art.size = Vector2(hero_width, carousel_height)
	_next_art.position = Vector2(UiTokens.KIT_ARROW_W + neighbor_width + hero_width, neighbor_y)
	_next_art.size = Vector2(neighbor_width, neighbor_height)
	_left_arrow.queue_redraw()
	_right_arrow.queue_redraw()


func _entry_name(entry: Dictionary) -> String:
	var name := str(entry.get("name", "")).strip_edges()
	return name.to_upper() if not name.is_empty() else "—"
