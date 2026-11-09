class_name CareerSpotlight
extends Button
# Centre club card of New Career: index row, big crest, club name, league line
# and the confirm hint. Focus inverts the whole card.

var _bg: Panel
var _rail: ColorRect
var _index: Label
var _crest: TextureRect
var _name: Label
var _sub: Label
var _hint: Label
var _normal_box: StyleBoxFlat
var _focused_box: StyleBoxFlat


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build_nodes()
	_init_boxes()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	_apply_state()
	call_deferred("_layout_content")


func set_club(club: Dictionary, index: int, total: int, crest: Texture2D,
		confirm_key := "ENTER") -> void:
	if _name == null:
		return
	_index.text = "%d / %d" % [index + 1, total]
	_crest.texture = crest
	_name.text = str(club.get("name", ""))
	var tier := str(club.get("tier_name", ""))
	if tier.is_empty():
		tier = "TIER %d" % int(club.get("tier", 0))
	_sub.text = "%s · %s · %s" % [tier, str(club.get("league_name", "")),
		str(club.get("country_name", ""))]
	_hint.text = "%s · SELECT CLUB" % confirm_key
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
	_index = _label("Index", 16, UiTheme.inter(600))
	_crest = TextureRect.new()
	_crest.name = "Crest"
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crest)
	_name = _label("Name", 46, UiTheme.barlow(800))
	_sub = _label("Sub", 18, UiTheme.inter(500))
	_hint = _label("Hint", 16, UiTheme.inter(600))


func _label(node_name: String, font_size: int, font: Font) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label


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
	var pad := 18.0
	_index.position = Vector2(pad, 10.0)
	_index.size = Vector2(size.x - pad * 2.0, 24.0)
	var crest_size := minf(240.0, size.x - pad * 2.0)
	_crest.position = Vector2((size.x - crest_size) * 0.5, 38.0)
	_crest.size = Vector2(crest_size, crest_size)
	_name.position = Vector2(pad, 38.0 + crest_size + 6.0)
	_name.size = Vector2(size.x - pad * 2.0, 90.0)
	_sub.position = Vector2(pad, 38.0 + crest_size + 94.0)
	_sub.size = Vector2(size.x - pad * 2.0, 50.0)
	_hint.position = Vector2(pad, size.y - 40.0)
	_hint.size = Vector2(size.x - pad * 2.0, 24.0)
	_apply_state()


func _apply_state() -> void:
	if _bg == null:
		return
	var selected := has_focus()
	_bg.add_theme_stylebox_override(&"panel", _focused_box if selected else _normal_box)
	_rail.visible = not selected
	var title_color := UiTokens.FOCUS_MARK if selected else UiTokens.INK
	var body_color := UiTokens.FOCUS_INK_2 if selected else UiTokens.INK_2
	_index.add_theme_color_override(&"font_color", body_color)
	_name.add_theme_color_override(&"font_color", title_color)
	_sub.add_theme_color_override(&"font_color", body_color)
	_hint.add_theme_color_override(&"font_color", body_color)
