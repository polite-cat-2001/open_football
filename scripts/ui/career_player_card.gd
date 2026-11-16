class_name CareerPlayerCard
extends Control
# Prototype .tf-result: one player in the transfer search / transfer centre
# result grid. Photo on the left, name / club / age·position·OVR and the state
# chips on the right, club crest in the corner. Focus inverts the card exactly
# like CareerRow/BentoTile (FOCUS_FILL, lime name, focus-ink body, magenta rail
# while idle). Owns the shared helper statics for the transfer screens:
# position tones/codes, face and crest lookups, status labels.
#
# A Button cannot declare its own pressed(player_id) signal (the native one
# exists), so the card is a focusable Control: mouse click emits pressed, and a
# host that owns the confirm key calls activate().

signal pressed(player_id: String)

const MIN_H := 120.0
const PAD := 12.0
const PHOTO_W := 72.0
const PHOTO_H := 88.0
const CREST := 28.0
const MAIN_GAP := 8.0
const CHIP_H := 18.0

const POS_TONES := {
	"GK": Color("d96b00"),
	"DEF": Color("a88600"),
	"MID": Color("23864a"),
	"FWD": Color("1f63b8"),
}
const POSITION_CODES := {
	"Goalkeeper": "GK",
	"Sweeper": "SW",
	"Defender": "DEF",
	"Centre-Back": "CB",
	"Left-Back": "LB",
	"Right-Back": "RB",
	"Defensive Midfield": "DM",
	"Central Midfield": "CM",
	"Attacking Midfield": "AM",
	"Left Midfield": "LM",
	"Right Midfield": "RM",
	"Midfielder": "MID",
	"Left Winger": "LW",
	"Right Winger": "RW",
	"Striker": "ST",
	"Centre-Forward": "CF",
	"Second Striker": "SS",
}
const MARK_WIN := Color("2f7d4f")
const MARK_LOSS := Color("b23a48")
const MARK_WARN := Color("a66a00")

var _player: Dictionary = {}
var _player_id := ""
var _selected := false

var _bg: Panel
var _rail: ColorRect
var _photo: Photo
var _crest: TextureRect
var _name: Label
var _club: Label
var _age: Label
var _pos: PanelContainer
var _pos_label: Label
var _ovr: Label
var _chips: HBoxContainer
var _chip_panels: Array[PanelContainer] = []
var _chip_labels: Array[Label] = []
var _normal_box: StyleBoxFlat
var _focused_box: StyleBoxFlat


# Portrait: the face texture bottom-centre, or the shared silhouette. A child
# Control so it paints above the card's background panel.
class Photo extends Control:
	var texture: Texture2D
	var tone := UiTokens.INK_2

	func show_texture(next: Texture2D) -> void:
		texture = next
		queue_redraw()

	func _draw() -> void:
		if texture == null:
			CareerPlayerCard.draw_photo_placeholder(self, Rect2(Vector2.ZERO, size),
				Color(tone, 0.30))
			return
		var tex_size := Vector2(texture.get_size())
		if tex_size.x <= 0.0 or tex_size.y <= 0.0:
			return
		var scale := minf(size.x / tex_size.x, size.y / tex_size.y)
		var drawn := tex_size * scale
		draw_texture_rect(texture,
			Rect2(Vector2((size.x - drawn.x) * 0.5, size.y - drawn.y), drawn), false)


# Shared helpers -------------------------------------------------------------

static func position_tone(group: String) -> Color:
	return POS_TONES.get(group.to_upper(), UiTokens.INK_2)


static func position_code(position: String, group := "") -> String:
	if POSITION_CODES.has(position):
		return String(POSITION_CODES[position])
	return group.to_upper() if not group.is_empty() else "—"


static func status_label(status: String) -> String:
	match status:
		"free":
			return "FREE AGENT"
		"transfer":
			return "TRANSFER LISTED"
		"loan":
			return "ON LOAN"
		"blocked":
			return "BLOCKED"
	return "AT CLUB"


static func face_texture(player: Dictionary) -> Texture2D:
	var photo = player.get("photo", "")
	if photo is String and not (photo as String).is_empty():
		var texture := UiAssets.usable_texture(
			UiAssets.load_texture_mipmapped((photo as String).trim_prefix("/")))
		if texture != null:
			return texture
	var tm_id := str(player.get("player_id", player.get("id", "0")))
	if photo is int or photo is float:
		tm_id = str(int(photo))
	return UiAssets.player_face(int(tm_id))


static func crest_texture(player: Dictionary) -> Texture2D:
	var path := str(player.get("club_logo", ""))
	if path.is_empty():
		return null
	return UiAssets.usable_texture(
		UiAssets.load_texture_mipmapped(path.trim_prefix("/")))


# Portrait fallback, drawn only from inside the owner's _draw() (assets/faces is
# gitignored, so a missing face is normal).
static func draw_photo_placeholder(target: CanvasItem, rect: Rect2, color: Color) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var head := minf(rect.size.x, rect.size.y) * 0.17
	var center := rect.get_center()
	target.draw_circle(Vector2(center.x, rect.position.y + rect.size.y * 0.34),
		head, color)
	target.draw_arc(Vector2(center.x, rect.end.y), rect.size.x * 0.30, PI, TAU, 18,
		color, maxf(2.0, rect.size.x * 0.12), true)


# Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = MIN_H
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_init_boxes()
	_build()
	_apply_state()
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	call_deferred("_layout_content")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_layout_content()
		_apply_state()


func setup(player: Dictionary, options := {}) -> void:
	_player = player
	_player_id = str(player.get("player_id", player.get("id", "")))
	if options.has("width"):
		custom_minimum_size.x = float(options["width"])
	if _name == null:
		return
	_refresh()


func player() -> Dictionary:
	return _player


func player_id() -> String:
	return _player_id


func set_selected(value: bool) -> void:
	_selected = value
	_apply_state()


func is_selected() -> bool:
	return _selected


# Build ----------------------------------------------------------------------

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

	_photo = Photo.new()
	_photo.name = "Photo"
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_photo)

	_crest = TextureRect.new()
	_crest.name = "Crest"
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crest)

	_name = _make_label("Name", UiTheme.barlow(700), 21, UiTokens.INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_club = _make_label("Club", UiTheme.inter(500), 14, UiTokens.INK_2)
	_club.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_age = _make_label("Age", UiTheme.inter(600), 15, UiTokens.INK_2)
	_ovr = _make_label("Ovr", UiTheme.barlow(700), 20, UiTokens.INK)

	_pos = PanelContainer.new()
	_pos.name = "Position"
	_pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pos)
	_pos_label = Label.new()
	_pos_label.name = "PositionLabel"
	_pos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pos_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pos_label.add_theme_font_override(&"font", UiTheme.inter(700))
	_pos_label.add_theme_font_size_override(&"font_size", 13)
	_pos.add_child(_pos_label)

	_chips = HBoxContainer.new()
	_chips.name = "Chips"
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.add_theme_constant_override(&"separation", 3)
	_chips.clip_contents = true
	add_child(_chips)
	for index in 3:
		var panel := PanelContainer.new()
		panel.name = "Chip%d" % index
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.name = "ChipLabel%d" % index
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 12)
		panel.add_child(label)
		_chips.add_child(panel)
		_chip_panels.append(panel)
		_chip_labels.append(label)
	_refresh()


func _make_label(node_name: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _init_boxes() -> void:
	_normal_box = _make_box(Color(UiTokens.INK, 0.055))
	_focused_box = _make_box(UiTokens.FOCUS_FILL)


func _make_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.anti_aliasing = true
	return box


func _chip_box(focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.FOCUS_INK, 0.10) if focused else Color(UiTokens.INK, 0.07)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box


# Content --------------------------------------------------------------------

func _refresh() -> void:
	_name.text = str(_player.get("name", "")).to_upper()
	_photo.show_texture(face_texture(_player))
	_crest.texture = crest_texture(_player)
	_crest.visible = _crest.texture != null
	_club.text = str(_player.get("club_name", ""))
	_club.visible = not _club.text.is_empty()
	_age.text = str(_player.get("age", "—"))
	var group := str(_player.get("position_group", ""))
	_pos_label.text = position_code(str(_player.get("position", "")), group)
	_pos_label.add_theme_color_override(&"font_color", position_tone(group))
	var ovr := int(round(float(_player.get("overall", 0))))
	_ovr.text = str(ovr) if ovr > 0 else "—"
	_ovr.add_theme_color_override(&"font_color", _overall_tone(ovr))
	_refresh_chips()
	_layout_content()
	_apply_state()


func _refresh_chips() -> void:
	var labels: Array[String] = []
	var status := str(_player.get("status", ""))
	if not status.is_empty() and not _is_contracted(status):
		labels.append(status_label(status))
	if bool(_player.get("shortlisted", false)):
		labels.append("SHORTLIST")
	elif bool(_player.get("listed_for_transfer", false)) \
			and not _is_contracted(status):
		labels.append("LISTED")
	if bool(_player.get("scouted", false)):
		labels.append("SCOUTED")
	for index in _chip_panels.size():
		var used := index < labels.size()
		_chip_panels[index].visible = used
		if used:
			_chip_labels[index].text = labels[index]
	_chips.visible = not labels.is_empty()


# CareerSearch reports an ordinary club player as "contracted"; the prototype
# (and the card) treat that as "no status tag".
static func _is_contracted(status: String) -> bool:
	return status.is_empty() or status == "contracted"


func _overall_tone(value: int) -> Color:
	if value >= 90:
		return UiTokens.INK
	if value >= 80:
		return MARK_WIN
	if value >= 70:
		return MARK_WARN
	return MARK_LOSS if value > 0 else UiTokens.INK_2


# Layout / state -------------------------------------------------------------

func _layout_content() -> void:
	if _bg == null or size.x <= 0.0:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(UiTokens.RAIL_W, size.y)

	_photo.position = Vector2(PAD, maxf(0.0, size.y - PHOTO_H))
	_photo.size = Vector2(PHOTO_W, PHOTO_H)
	if _crest.visible:
		_crest.position = Vector2(size.x - 10.0 - CREST, 10.0)
		_crest.size = Vector2(CREST, CREST)

	var text_x := PAD + PHOTO_W + MAIN_GAP
	var text_w := maxf(60.0, size.x - text_x - PAD - (CREST + 6.0 if _crest.visible else 0.0))
	var chips_y := size.y - 5.0 - CHIP_H
	var meta_y := chips_y - 20.0
	var club_y := meta_y - 18.0
	_name.position = Vector2(text_x, 6.0)
	_name.size = Vector2(text_w, maxf(24.0, club_y - 8.0))
	_club.position = Vector2(text_x, club_y)
	_club.size = Vector2(text_w, 18.0)

	var x := text_x
	_age.position = Vector2(x, meta_y)
	_age.size = Vector2(_text_width(_age) + 2.0, 20.0)
	x += _age.size.x + 6.0
	_pos.position = Vector2(x, meta_y + 1.0)
	_pos.size = Vector2(_text_width(_pos_label) + 14.0, 18.0)
	x += _pos.size.x + 6.0
	_ovr.position = Vector2(x, meta_y - 2.0)
	_ovr.size = Vector2(minf(_text_width(_ovr) + 4.0, maxf(0.0, size.x - PAD - x)), 22.0)

	_chips.position = Vector2(text_x, chips_y)
	_chips.size = Vector2(size.x - text_x - PAD, CHIP_H)
	for panel in _chip_panels:
		panel.custom_minimum_size.y = CHIP_H


func _text_width(label: Label) -> float:
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _apply_state() -> void:
	if _bg == null:
		return
	var focused := has_focus()
	_bg.add_theme_stylebox_override(&"panel", _focused_box if focused else _normal_box)
	_rail.visible = _selected or not focused
	var title := UiTokens.FOCUS_MARK if focused else UiTokens.INK
	var body := UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
	_name.add_theme_color_override(&"font_color", title)
	_club.add_theme_color_override(&"font_color", body)
	_age.add_theme_color_override(&"font_color", body)
	var tone := UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
	if _photo.tone != tone:
		_photo.tone = tone
		_photo.queue_redraw()
	_ovr.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if focused else _overall_tone(
			int(round(float(_player.get("overall", 0))))))
	_pos.add_theme_stylebox_override(&"panel", _chip_box(focused))
	_pos_label.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK if focused
		else position_tone(str(_player.get("position_group", ""))))
	for panel in _chip_panels:
		panel.add_theme_stylebox_override(&"panel", _chip_box(focused))
		for child in panel.get_children():
			(child as Label).add_theme_color_override(&"font_color", body)


func _on_pressed() -> void:
	pressed.emit(_player_id)


func activate() -> void:
	_on_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			_on_pressed()
			accept_event()

