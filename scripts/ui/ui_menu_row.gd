class_name UiMenuRow
extends Button

# One row in a submenu panel: uppercase heading on the left, muted detail on
# the right, 6px magenta rail, dark inversion while focused. Static rows
# ("section in progress") are visible but not focusable.

var title_text := ""
var sub_text := ""
var is_static := false

var _bg: Panel
var _rail: ColorRect
var _title: Label
var _sub: Label
var _normal_box: StyleBoxFlat
var _focused_box: StyleBoxFlat
var _static_box: StyleBoxFlat


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE if is_static else Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE if is_static else Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = 88.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_build()
	_init_boxes()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	if not is_static:
		mouse_entered.connect(grab_focus)
		_apply_state()
	else:
		_apply_state()
	call_deferred("_layout_content")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_layout_content()
		_apply_state()


func _build() -> void:
	_bg = Panel.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_rail = ColorRect.new()
	_rail.color = Color(UiTokens.INK, 0.22) if is_static else UiTokens.RAIL
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)

	_title = Label.new()
	_title.text = title_text
	_title.theme_type_variation = &"RowTitle"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_sub = Label.new()
	_sub.text = sub_text
	_sub.theme_type_variation = &"RowSub"
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.visible = not sub_text.is_empty()
	add_child(_sub)


func _init_boxes() -> void:
	_normal_box = _make_box(UiTokens.TILE, UiTokens.SHADOW, 22, Vector2(0.0, 18.0))
	_focused_box = _make_box(UiTokens.FOCUS_FILL, UiTokens.SHADOW, 22, Vector2(0.0, 18.0))
	_static_box = _make_box(UiTokens.TILE, Color.TRANSPARENT, 0, Vector2.ZERO)


func _make_box(fill: Color, shadow: Color, blur: int, offset: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.shadow_color = shadow
	box.shadow_size = blur
	box.shadow_offset = offset
	return box


func _layout_content() -> void:
	if _bg == null or size.x <= 0.0:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)

	var sub_width := 0.0
	if _sub.visible:
		var font := _sub.get_theme_font(&"font")
		var font_size := _sub.get_theme_font_size(&"font_size")
		sub_width = font.get_string_size(
			_sub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		_sub.position = Vector2(size.x - 24.0 - sub_width, 0.0)
		_sub.size = Vector2(sub_width, size.y)

	var title_width := size.x - 48.0 - (sub_width + 20.0 if sub_width > 0.0 else 0.0)
	_title.position = Vector2(24.0, 0.0)
	_title.size = Vector2(maxf(title_width, 0.0), size.y)


func _apply_state() -> void:
	if _bg == null:
		return
	var selected := has_focus() and not is_static
	if is_static:
		_bg.add_theme_stylebox_override(&"panel", _static_box)
		_rail.visible = true
		_title.add_theme_color_override(&"font_color", UiTokens.INK_2)
		_sub.add_theme_color_override(&"font_color", UiTokens.INK_2)
	elif selected:
		_bg.add_theme_stylebox_override(&"panel", _focused_box)
		_rail.visible = false
		_title.add_theme_color_override(&"font_color", UiTokens.FOCUS_MARK)
		_sub.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK_2)
	else:
		_bg.add_theme_stylebox_override(&"panel", _normal_box)
		_rail.visible = true
		_title.add_theme_color_override(&"font_color", UiTokens.INK)
		_sub.add_theme_color_override(&"font_color", UiTokens.INK_2)
