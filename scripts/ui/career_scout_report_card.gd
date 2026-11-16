class_name CareerScoutReportCard
extends Control
# Prototype career/scouting/ScoutReportCard.svelte: one row of the reports feed
# — portrait, name, age and position code, the unread dot, the overall and the
# club crest. Focus inverts it like every other career list row.

signal pressed(player_id: String)

const H := 78.0
const PAD := 10.0
const PHOTO_W := 44.0
const PHOTO_H := 52.0
const SIDE_W := 54.0
const CREST := 22.0

var _player_id := ""
var _entry: Dictionary = {}
var _selected := false

var _bg: Panel
var _rail: ColorRect
var _photo: CareerPlayerCard.Photo
var _name: Label
var _meta: Label
var _new: Panel
var _ovr: Label
var _crest: TextureRect
var _normal_box: StyleBoxFlat
var _focus_box: StyleBoxFlat


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = H
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_normal_box = StyleBoxFlat.new()
	_normal_box.bg_color = Color(UiTokens.INK, 0.05)
	_normal_box.anti_aliasing = true
	_focus_box = StyleBoxFlat.new()
	_focus_box.bg_color = UiTokens.FOCUS_FILL
	_focus_box.anti_aliasing = true
	_bg = Panel.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_rail = ColorRect.new()
	_rail.color = UiTokens.RAIL
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)
	_photo = CareerPlayerCard.Photo.new()
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_photo)
	_name = _label(UiTheme.barlow(700), 22)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_meta = _label(UiTheme.inter(500), 15)
	_meta.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_ovr = _label(UiTheme.barlow(700), 20)
	_ovr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_new = Panel.new()
	_new.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_new)
	var dot := StyleBoxFlat.new()
	dot.bg_color = UiTokens.RAIL
	_new.add_theme_stylebox_override(&"panel", dot)
	_crest = TextureRect.new()
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crest)
	_apply_state()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	call_deferred("_layout_content")


func setup(entry: Dictionary) -> void:
	_entry = entry
	var player: Dictionary = entry.get("player", {}) if entry.get("player") is Dictionary else {}
	_player_id = str(player.get("player_id", ""))
	if _name == null:
		return
	_photo.show_texture(CareerPlayerCard.face_texture(player))
	_name.text = str(player.get("name", "")).to_upper()
	var code := CareerPlayerCard.position_code(str(player.get("position", "")),
		str(player.get("position_group", "")))
	_meta.text = "%s · %s" % [str(player.get("age", "—")), code]
	_ovr.text = str(int(round(float(player.get("overall", 0)))))
	_crest.texture = CareerPlayerCard.crest_texture(player)
	_crest.visible = _crest.texture != null
	_new.visible = not bool(entry.get("acknowledged", false))
	_layout_content()
	_apply_state()


func player_id() -> String:
	return _player_id


func set_selected(value: bool) -> void:
	_selected = value
	_apply_state()


func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", UiTokens.INK)
	add_child(label)
	return label


func _layout_content() -> void:
	if _bg == null:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)
	_photo.position = Vector2(PAD, size.y - PHOTO_H - 8.0)
	_photo.size = Vector2(PHOTO_W, PHOTO_H)
	var text_x := PAD + PHOTO_W + 10.0
	var text_w := maxf(20.0, size.x - text_x - PAD - SIDE_W)
	_name.position = Vector2(text_x, 12.0)
	_name.size = Vector2(text_w, 26.0)
	_meta.position = Vector2(text_x, 38.0)
	_meta.size = Vector2(text_w, 20.0)
	_ovr.position = Vector2(size.x - PAD - SIDE_W, 24.0)
	_ovr.size = Vector2(SIDE_W, 24.0)
	_crest.position = Vector2(size.x - PAD - CREST, size.y - 8.0 - CREST)
	_crest.size = Vector2(CREST, CREST)
	_new.position = Vector2(size.x - PAD - SIDE_W - 10.0, 12.0)
	_new.size = Vector2(8.0, 8.0)


func _apply_state() -> void:
	if _bg == null:
		return
	var focused := has_focus()
	_bg.add_theme_stylebox_override(&"panel", _focus_box if focused else _normal_box)
	_rail.visible = focused
	_name.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if focused else UiTokens.INK)
	_meta.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
	_ovr.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK if focused else UiTokens.INK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			pressed.emit(_player_id)
			accept_event()


func activate() -> void:
	pressed.emit(_player_id)
