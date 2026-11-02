class_name BentoTile
extends Button

# Bento tile from the prototype's TileGrid: a flat Button that owns its own
# background (stylebox with shadow), rail, hero hatch, labels and glyph. Focus
# is the selection: focus_entered/exited swaps the style and nudges the tile.

const HATCH_SHADER := preload("res://shaders/ui_hatch.gdshader")

@export var title := ""
@export var subtitle := ""
@export var meta := ""
@export var glyph_name := ""
@export var hero := false
@export var wide := false
@export var chip := ""

var _bg: Panel
var _rail: ColorRect
var _hatch: ColorRect
var _title_label: Label
var _sub_label: Label
var _meta_label: Label
var _glyph_rect: TextureRect
var _chip: PanelContainer
var _chip_label: Label

var _normal_box: StyleBoxFlat
var _selected_box: StyleBoxFlat
var _disabled_box: StyleBoxFlat
var _base_rect := Rect2()
var _push := Vector2.ZERO
var _selected := false
var _tween: Tween
var _entrance_tween: Tween
var _glyph_size := UiTokens.GLYPH_SMALL


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	if disabled:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

	_build_nodes()
	_init_boxes()
	resized.connect(_layout_content)
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	if not disabled:
		mouse_entered.connect(_on_mouse_entered)
	_apply_state(false)
	call_deferred("_layout_content")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_layout_content()
		_apply_state(false)


func set_base_rect(rect: Rect2, push: Vector2) -> void:
	_base_rect = rect
	_push = push
	size = rect.size
	pivot_offset = size * 0.5
	position = rect.position + (_push if _selected else Vector2.ZERO)
	_layout_content()


func _build_nodes() -> void:
	_bg = Panel.new()
	_bg.name = "Bg"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_rail = ColorRect.new()
	_rail.name = "Rail"
	_rail.color = UiTokens.RAIL
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)

	_hatch = ColorRect.new()
	_hatch.name = "Hatch"
	_hatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = HATCH_SHADER
	_hatch.material = material
	_hatch.visible = hero
	add_child(_hatch)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = title
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.name = "Sub"
	_sub_label.text = subtitle
	_sub_label.visible = not subtitle.is_empty()
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_sub_label)

	_meta_label = Label.new()
	_meta_label.name = "Meta"
	_meta_label.text = meta
	_meta_label.visible = not meta.is_empty()
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meta_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_meta_label)

	_glyph_rect = TextureRect.new()
	_glyph_rect.name = "Glyph"
	_glyph_rect.texture = UiIcon.texture(glyph_name)
	_glyph_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph_rect)

	_chip = PanelContainer.new()
	_chip.name = "Chip"
	_chip.theme_type_variation = &"SoonChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.visible = not chip.is_empty()
	_chip_label = Label.new()
	_chip_label.theme_type_variation = &"SoonChipLabel"
	_chip_label.text = chip
	_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(_chip_label)
	add_child(_chip)

	var title_variation := &"TileTitle"
	if hero:
		title_variation = &"HeroTitle"
	elif wide:
		title_variation = &"WideTitle"
	_title_label.theme_type_variation = title_variation
	_sub_label.theme_type_variation = &"TileSubWide" if wide else &"TileSub"
	_meta_label.theme_type_variation = &"TileMeta"

	if hero:
		_glyph_size = UiTokens.GLYPH_HERO
	elif wide:
		_glyph_size = UiTokens.GLYPH_WIDE
	else:
		_glyph_size = UiTokens.GLYPH_SMALL


func _init_boxes() -> void:
	_normal_box = _make_box(UiTokens.TILE, UiTokens.SHADOW, 22, Vector2(0.0, 18.0))
	_selected_box = _make_box(UiTokens.FOCUS_FILL, UiTokens.SHADOW_SELECTED, 32, Vector2(0.0, 28.0))
	_disabled_box = _make_box(UiTokens.TILE_DISABLED, UiTokens.SHADOW_DISABLED, 10, Vector2(0.0, 10.0))


func _make_box(fill: Color, shadow: Color, blur: int, offset: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.shadow_color = shadow
	box.shadow_size = blur
	box.shadow_offset = offset
	box.anti_aliasing = true
	return box


func _layout_content() -> void:
	if _bg == null or size.x <= 0.0:
		return

	_bg.position = Vector2.ZERO
	_bg.size = size

	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)

	if hero:
		_hatch.position = Vector2(size.x * 0.48, 0.0)
		_hatch.size = Vector2(size.x * 0.52, size.y)
		var material := _hatch.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter(&"area", _hatch.size)

	var pad_left := 24.0
	var pad_top := 22.0
	var pad_bottom := 22.0
	var title_size := float(_title_label.get_theme_font_size(&"font_size"))
	if title_size <= 0.0:
		title_size = 44.0
	var title_height := title_size * 0.92
	# Godot clamps a Label's height to the full font line box, so centre that
	# box inside the CSS line box instead of letting the glyphs sit lower.
	var title_font := _title_label.get_theme_font(&"font")
	var font_height := title_font.get_height(int(title_size))
	var line_offset := (font_height - title_height) * 0.5

	_title_label.position = Vector2(pad_left, pad_top - line_offset)
	_title_label.size = Vector2(size.x - pad_left * 2.0, title_height)

	_sub_label.position = Vector2(pad_left, pad_top + title_height + UiTokens.GAP)
	_sub_label.size = Vector2(minf(size.x - pad_left * 2.0, 340.0), 44.0)

	_meta_label.position = Vector2(pad_left, size.y - pad_bottom - 20.0)
	_meta_label.size = Vector2(size.x - pad_left * 2.0, 20.0)

	_glyph_rect.position = Vector2(
		size.x - pad_left - _glyph_size,
		size.y - pad_bottom - _glyph_size
	)
	_glyph_rect.size = Vector2(_glyph_size, _glyph_size)

	if _chip.visible:
		_chip.position = Vector2(pad_left, 0.0)
		_chip.size = _chip.get_combined_minimum_size()
		_chip.position = Vector2(pad_left, size.y - pad_bottom - _chip.size.y)


func _on_mouse_entered() -> void:
	if not disabled:
		grab_focus()


func play_entrance(direction: int, delay: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	var target := _base_rect.position + (_push if _selected else Vector2.ZERO)
	var start := target + Vector2(UiTokens.TILE_ENTER_SHIFT * float(signi(direction)), 0.0)
	position = start
	modulate.a = 0.0
	scale = Vector2.ONE * (UiTokens.SELECTED_SCALE if _selected else 1.0)
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(self, "position", target, UiTokens.TILE_ENTER) \
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(self, "modulate:a", 1.0, UiTokens.TILE_ENTER) \
		.set_delay(delay)


func _on_focus_changed() -> void:
	var now_selected := has_focus() and not disabled
	if now_selected == _selected:
		return
	_selected = now_selected
	_apply_state(true)


func _apply_state(animate: bool) -> void:
	if _bg == null:
		return

	if disabled:
		_bg.add_theme_stylebox_override(&"panel", _disabled_box)
	elif _selected:
		_bg.add_theme_stylebox_override(&"panel", _selected_box)
	else:
		_bg.add_theme_stylebox_override(&"panel", _normal_box)

	_rail.visible = not _selected and not disabled

	var title_color := UiTokens.INK
	var sub_color := UiTokens.INK_2
	var glyph_color := Color(UiTokens.INK, 0.72)
	if disabled:
		title_color = UiTokens.INK_2
		sub_color = Color(UiTokens.INK_2, 0.9)
		glyph_color = Color(UiTokens.INK_2, 0.45)
	elif _selected:
		title_color = UiTokens.FOCUS_MARK
		sub_color = UiTokens.FOCUS_INK_2
		glyph_color = UiTokens.RAIL

	_title_label.add_theme_color_override(&"font_color", title_color)
	_sub_label.add_theme_color_override(&"font_color", sub_color)
	_meta_label.add_theme_color_override(&"font_color", sub_color)
	_glyph_rect.modulate = glyph_color

	var material := _hatch.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"line_color", title_color)

	z_index = 3 if _selected else 1
	_animate_selection(animate)


func _animate_selection(animate: bool) -> void:
	var target_position := _base_rect.position + (_push if _selected else Vector2.ZERO)
	var target_scale := Vector2.ONE * (UiTokens.SELECTED_SCALE if _selected else 1.0)
	if not animate:
		position = target_position
		scale = target_scale
		return
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", target_position, UiTokens.TILE_MOVE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale, UiTokens.TILE_MOVE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
