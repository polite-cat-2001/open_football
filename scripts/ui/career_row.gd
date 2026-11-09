class_name CareerRow
extends Button
# Prototype .gf-row: optional lead image, title/sub/detail on the left and
# meta/tags on the right. Focus inverts the row like the bento tiles.

@export var title_text := ""
@export var sub_text := ""
@export var meta_text := ""
@export var tags_text := ""
@export var detail_text := ""
@export var title_size := 28
var detail_error := false
var lead_texture: Texture2D
var league_texture: Texture2D

var _bg: Panel
var _rail: ColorRect
var _lead: TextureRect
var _league_lead: TextureRect
var _title: Label
var _sub: Label
var _detail: Label
var _meta: Label
var _tags: Label
var _normal_box: StyleBoxFlat
var _focused_box: StyleBoxFlat


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 72.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build()
	_init_boxes()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	_apply_state()
	call_deferred("_layout_content")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_layout_content()
		_apply_state()


func set_content(next_title: String, next_sub: String, next_meta := "",
		next_tags := "", next_detail := "") -> void:
	title_text = next_title
	sub_text = next_sub
	meta_text = next_meta
	tags_text = next_tags
	detail_text = next_detail
	if _title == null:
		return
	_refresh_text()
	_layout_content()
	_apply_state()


func set_lead(texture: Texture2D) -> void:
	lead_texture = texture
	_apply_lead_art()


func set_league_lead(texture: Texture2D) -> void:
	league_texture = texture
	_apply_lead_art()


func _apply_lead_art() -> void:
	if _lead != null:
		_lead.texture = lead_texture
		_lead.visible = lead_texture != null
	if _league_lead != null:
		_league_lead.texture = league_texture
		_league_lead.visible = league_texture != null
	_layout_content()


func _build() -> void:
	_bg = Panel.new()
	_bg.name = "Bg"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_rail = ColorRect.new()
	_rail.name = "Rail"
	_rail.color = UiTokens.RAIL
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)

	_lead = TextureRect.new()
	_lead.name = "Lead"
	_lead.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lead.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lead.visible = lead_texture != null
	_lead.texture = lead_texture
	add_child(_lead)

	_league_lead = TextureRect.new()
	_league_lead.name = "LeagueLead"
	_league_lead.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_league_lead.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_league_lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_league_lead.visible = league_texture != null
	_league_lead.texture = league_texture
	add_child(_league_lead)

	_title = _make_label("Title")
	_sub = _make_label("Sub")
	_detail = _make_label("Detail")
	_meta = _make_label("Meta")
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tags = _make_label("Tags")
	_tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_text()


func _make_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label


func _refresh_text() -> void:
	_title.text = title_text
	_sub.text = sub_text
	_detail.text = detail_text
	_meta.text = meta_text
	_tags.text = tags_text
	_sub.visible = not sub_text.is_empty()
	_detail.visible = not detail_text.is_empty()
	_meta.visible = not meta_text.is_empty()
	_tags.visible = not tags_text.is_empty()


func _init_boxes() -> void:
	_normal_box = _make_box(UiTokens.TILE, UiTokens.SHADOW)
	_focused_box = _make_box(UiTokens.FOCUS_FILL, UiTokens.SHADOW_SELECTED)


func _make_box(fill: Color, shadow: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.shadow_color = shadow
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	box.anti_aliasing = true
	return box


func _layout_content() -> void:
	if _bg == null or size.x <= 0.0:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)

	var pad := 22.0
	var x := pad
	if _lead.visible:
		_lead.position = Vector2(pad, (size.y - 56.0) * 0.5)
		_lead.size = Vector2(56.0, 56.0)
		x += 56.0 + 12.0
	if _league_lead.visible:
		_league_lead.position = Vector2(x, (size.y - 40.0) * 0.5)
		_league_lead.size = Vector2(40.0, 40.0)
		x += 40.0 + 14.0

	var side_width := maxf(180.0, size.x * 0.34)
	_meta.position = Vector2(size.x - pad - side_width, 10.0)
	_meta.size = Vector2(side_width, 22.0)
	_tags.position = Vector2(size.x - pad - side_width, 34.0)
	_tags.size = Vector2(side_width, 22.0)

	var main_width := size.x - x - pad - side_width - 14.0
	_title.position = Vector2(x, 8.0)
	_title.size = Vector2(main_width, float(title_size) + 6.0)
	_sub.position = Vector2(x, 8.0 + float(title_size) + 4.0)
	_sub.size = Vector2(main_width, 20.0)
	_detail.position = Vector2(x, 8.0 + float(title_size) + 24.0)
	_detail.size = Vector2(main_width, 18.0)
	_apply_fonts()


func _apply_fonts() -> void:
	_title.add_theme_font_override(&"font", UiTheme.barlow(700))
	_title.add_theme_font_size_override(&"font_size", title_size)
	for label in [_sub, _detail, _meta, _tags]:
		label.add_theme_font_override(&"font", UiTheme.inter(500))
		label.add_theme_font_size_override(&"font_size", 15)


func _apply_state() -> void:
	if _bg == null:
		return
	var selected := has_focus()
	_bg.add_theme_stylebox_override(&"panel", _focused_box if selected else _normal_box)
	_rail.visible = not selected
	var title_color := UiTokens.FOCUS_MARK if selected else UiTokens.INK
	var body_color := UiTokens.FOCUS_INK_2 if selected else UiTokens.INK_2
	_title.add_theme_color_override(&"font_color", title_color)
	for label in [_sub, _meta, _tags]:
		label.add_theme_color_override(&"font_color", body_color)
	_detail.add_theme_color_override(&"font_color",
		body_color if selected or not detail_error else UiTokens.ERROR_PINK)
