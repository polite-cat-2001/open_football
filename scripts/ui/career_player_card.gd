class_name CareerPlayerCard
extends Control
# Prototype .tf-result: one player in the transfer search / transfer centre
# result grid. Portrait on the left, name / position·rating / age and the state
# chips on the right, club crest in the corner. Focus inverts the card exactly
# like CareerRow/BentoTile (FOCUS_FILL, lime name, focus-ink body, magenta rail
# while idle). Owns the shared helper statics for the transfer screens: position
# codes, face and crest lookups, status labels.
#
# A Button cannot declare its own pressed(player_id) signal (the native one
# exists), so the card is a focusable Control: mouse click emits pressed, and a
# host that owns the confirm key calls activate().

signal pressed(player_id: String)

const MIN_H := 112.0
const PAD := 12.0
const PHOTO_W := 72.0
const PHOTO_H := 88.0
const CREST := 28.0
const MAIN_GAP := 8.0
const CHIP_H := 18.0
const META_H := 20.0
const AGE_H := 18.0
const GAP := 6.0

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

var _player: Dictionary = {}
var _player_id := ""
var _selected := false
# The idle magenta rail; hosts that use the rail as an unread marker turn it off
# for the entries that are already read.
var _rail_idle := true

var _bg: Panel
var _rail: ColorRect
var _photo: Photo
var _crest: TextureRect
var _name: Label
var _age: Label
var _pos: Label
var _pos_dot: Panel
var _ovr_tile: Panel
var _ovr_tile_label: Label
var _chips: HBoxContainer
var _chip_panels: Array[PanelContainer] = []
var _chip_labels: Array[Label] = []
var _normal_box: StyleBoxFlat
var _focused_box: StyleBoxFlat


# Portrait: the face texture bottom-centre, or the shared silhouette. The
# fallback keeps one tone in every state (focus no longer recolours it).
class Photo extends Control:
	var texture: Texture2D

	func show_texture(next: Texture2D) -> void:
		texture = next
		queue_redraw()

	func _draw() -> void:
		if texture == null:
			UiAssets.draw_player_placeholder(self, Rect2(Vector2.ZERO, size), UiTokens.INK_2)
			return
		var tex_size := Vector2(texture.get_size())
		if tex_size.x <= 0.0 or tex_size.y <= 0.0:
			return
		var scale := minf(size.x / tex_size.x, size.y / tex_size.y)
		var drawn := tex_size * scale
		draw_texture_rect(texture,
			Rect2(Vector2((size.x - drawn.x) * 0.5, size.y - drawn.y), drawn), false)


# Shared helpers -------------------------------------------------------------

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


# A scouted player's OVR is known and sits next to the position.
static func shows_overall_tile(player: Dictionary) -> bool:
	return int(round(float(player.get("overall", 0)))) > 0 \
		and bool(player.get("scouted", false))


static func age_value(player: Dictionary) -> String:
	# ~3.5k of the 122k players have no birth date; the prototype reports those
	# as null, so the card must not print "0".
	var age := int(player.get("age", 0))
	return str(age) if age > 0 else "—"


static func age_text(player: Dictionary) -> String:
	var value := age_value(player)
	return value + " y.o." if value != "—" else value


static func crest_texture(player: Dictionary) -> Texture2D:
	var path := str(player.get("club_logo", ""))
	if path.is_empty():
		return null
	return UiAssets.usable_texture(
		UiAssets.load_texture_mipmapped(path.trim_prefix("/")))


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
	if options.has("rail"):
		_rail_idle = bool(options["rail"])
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

	_ovr_tile = Panel.new()
	_ovr_tile.name = "OvrTile"
	_ovr_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ovr_tile)
	_ovr_tile_label = Label.new()
	_ovr_tile_label.name = "Value"
	_ovr_tile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ovr_tile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ovr_tile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ovr_tile_label.add_theme_font_override(&"font", UiTheme.inter(700))
	_ovr_tile_label.add_theme_font_size_override(&"font_size", 13)
	_ovr_tile_label.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK)
	_ovr_tile.add_child(_ovr_tile_label)
	_ovr_tile_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_crest = TextureRect.new()
	_crest.name = "Crest"
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crest)

	_name = _make_label("Name", UiTheme.barlow(700), 21, UiTokens.INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 1
	_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_age = _make_label("Age", UiTheme.inter(600), 15, UiTokens.INK_2)

	_pos_dot = Panel.new()
	_pos_dot.name = "PositionDot"
	_pos_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pos_dot)
	var dot_box := StyleBoxFlat.new()
	dot_box.bg_color = UiTokens.INK_2
	dot_box.corner_radius_top_left = 4
	dot_box.corner_radius_top_right = 4
	dot_box.corner_radius_bottom_left = 4
	dot_box.corner_radius_bottom_right = 4
	_pos_dot.add_theme_stylebox_override(&"panel", dot_box)
	_pos = _make_label("Position", UiTheme.inter(700), 13, UiTokens.INK)
	_pos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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


func _tile_box(tone: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tone
	box.anti_aliasing = true
	return box


# Content --------------------------------------------------------------------

func _refresh() -> void:
	_name.text = str(_player.get("name", "")).to_upper()
	_photo.show_texture(face_texture(_player))
	var tile := shows_overall_tile(_player)
	_ovr_tile.visible = tile
	if tile:
		var ovr := int(round(float(_player.get("overall", 0))))
		_ovr_tile_label.text = str(ovr)
	_crest.texture = crest_texture(_player)
	_crest.visible = _crest.texture != null
	_age.text = age_text(_player)
	var group := str(_player.get("position_group", ""))
	_pos.text = position_code(str(_player.get("position", "")), group)
	var dot_box := _pos_dot.get_theme_stylebox(&"panel") as StyleBoxFlat
	dot_box.bg_color = UiTokens.position_color(group)
	_refresh_chips()
	_layout_content()
	_apply_state()


func _refresh_chips() -> void:
	# A free agent is obvious from the missing crest, the transfer list from the
	# player actions, and the shortlist likewise — the card only carries the
	# states that change how a club can move for him.
	var labels: Array[String] = []
	var status := str(_player.get("status", ""))
	if status == "loan" or status == "blocked":
		labels.append(status_label(status))
	for index in _chip_panels.size():
		var used := index < labels.size()
		_chip_panels[index].visible = used
		if used:
			_chip_labels[index].text = labels[index]
	_chips.visible = not labels.is_empty()


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
	# The prototype centres the name / meta / state block against the portrait.
	# The name is one line (ellipsis): under 0.1% of the database names wrap.
	var name_h := _name.get_theme_font(&"font").get_height(
		_name.get_theme_font_size(&"font_size"))
	var chips_h := CHIP_H if _chips.visible else 0.0
	var block_h := name_h + GAP + META_H + GAP + AGE_H \
		+ (GAP + chips_h if chips_h > 0.0 else 0.0)
	var top := maxf(4.0, (size.y - block_h) * 0.5)
	_name.position = Vector2(text_x, top)
	_name.size = Vector2(text_w, name_h)
	var meta_y := top + name_h + GAP

	# Position is a dot + plain code; the rating chip stands on its own after it.
	var dot := 8.0
	_pos_dot.position = Vector2(text_x, meta_y + (META_H - dot) * 0.5)
	_pos_dot.size = Vector2(dot, dot)
	var pos_x := text_x + dot + 4.0
	_pos.position = Vector2(pos_x, meta_y)
	_pos.size = Vector2(_text_width(_pos) + 2.0, META_H)
	var chip_w := maxf(26.0, _text_width(_ovr_tile_label) + 12.0)
	_ovr_tile.position = Vector2(pos_x + _pos.size.x + 8.0, meta_y + 1.0)
	_ovr_tile.size = Vector2(chip_w, CHIP_H)

	_age.position = Vector2(text_x, meta_y + META_H + GAP)
	_age.size = Vector2(text_w, AGE_H)

	_chips.position = Vector2(text_x, meta_y + META_H + GAP + AGE_H + GAP)
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
	_rail.visible = _rail_idle and (_selected or not focused)
	var title := UiTokens.FOCUS_MARK if focused else UiTokens.INK
	var body := UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
	_name.add_theme_color_override(&"font_color", title)
	_age.add_theme_color_override(&"font_color", body)
	_pos.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK if focused else UiTokens.INK)
	if _ovr_tile.visible:
		# Focus inverts the whole card, so the chip inverts with it (the squad
		# view paints a focused OVR FOCUS_INK for the same reason).
		var ovr := int(round(float(_player.get("overall", 0))))
		_ovr_tile.add_theme_stylebox_override(&"panel",
			_tile_box(UiTokens.FOCUS_INK if focused else UiTokens.rating_color(ovr)))
		_ovr_tile_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_FILL if focused else UiTokens.FOCUS_INK)
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

