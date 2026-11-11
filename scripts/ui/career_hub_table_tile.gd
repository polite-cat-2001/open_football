class_name CareerHubTableTile
extends BentoTile
# Centre "Overview" tile: a six-row league-table window around the own club and
# the section dots from the prototype's OverviewTile.svelte. Only the table has
# data today; the other sections are the prototype's "soon" placeholders.

const PAD := 22.0
const HEAD_H := 20.0
const DOT := 16.0
const DOT_GAP := 2.0

var _title: Label
var _competition: Label
var _round: Label
var _rows: Array = []
var _dots: Array = []
var _soon: Label
var _section := 0


func _ready() -> void:
	super._ready()
	_title = _label(30, UiTheme.barlow(700), UiTokens.INK)
	_competition = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_round = _label(16, UiTheme.inter(600), UiTokens.INK_2)
	_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_soon = _label(16, UiTheme.inter(500), UiTokens.INK_2)
	_soon.text = "SOON"
	_soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_soon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)
	add_child(_competition)
	add_child(_round)
	add_child(_soon)
	for index in range(CareerHubModel.OVERVIEW_SECTIONS.size()):
		var dot := Button.new()
		dot.flat = true
		dot.focus_mode = Control.FOCUS_NONE
		dot.mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			dot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var mark := Panel.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(mark)
		dot.pressed.connect(_select_section.bind(index))
		add_child(dot)
		_dots.append({"button": dot, "mark": mark})
	_layout_content()


func setup(model: Dictionary) -> void:
	if _title == null:
		return
	_competition.text = str(model.get("competition", "")).to_upper()
	var round := int(model.get("round", 0))
	_round.text = "ROUND %d" % round if round > 0 else ""
	_build_rows(model.get("rows", []))
	_select_section(_section)


func _build_rows(rows: Array) -> void:
	for row in _rows:
		row["root"].queue_free()
	_rows.clear()
	var head := _make_row()
	_set_row_text(head, "#", "", "CLUB", "P", "PTS", false, true)
	_rows.append(head)
	for item in rows:
		var row := _make_row()
		_set_row_text(row,
			str(int(item.get("position", 0))),
			str(item.get("club_logo", "")),
			str(item.get("club_name", "")),
			str(int(item.get("played", 0))),
			str(int(item.get("points", 0))),
			bool(item.get("own", false)),
			false)
		_rows.append(row)


func _make_row() -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail := ColorRect.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pos := _label(16, UiTheme.inter(500), UiTokens.INK_2)
	var crest := TextureRect.new()
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var name := _label(16, UiTheme.inter(600), UiTokens.INK)
	name.clip_text = true
	var played := _label(16, UiTheme.inter(500), UiTokens.INK_2)
	played.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var points := _label(16, UiTheme.inter(700), UiTokens.INK)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(bg)
	root.add_child(rail)
	for node in [pos, crest, name, played, points]:
		root.add_child(node)
	add_child(root)
	return {
		"root": root, "bg": bg, "rail": rail, "pos": pos, "crest": crest,
		"name": name, "played": played, "points": points, "own": false, "head": false,
	}


func _set_row_text(row: Dictionary, pos: String, logo: String, club: String,
		played: String, points: String, own: bool, head: bool) -> void:
	(row["pos"] as Label).text = pos
	(row["name"] as Label).text = club
	(row["played"] as Label).text = played
	(row["points"] as Label).text = points
	(row["crest"] as TextureRect).texture = _logo(logo)
	row["own"] = own
	row["head"] = head


func _select_section(index: int) -> void:
	_section = clampi(index, 0, CareerHubModel.OVERVIEW_SECTIONS.size() - 1)
	_title.text = CareerHubModel.OVERVIEW_SECTIONS[_section]
	var show_table := _section == 0
	for row in _rows:
		(row["root"] as Control).visible = show_table
	_soon.visible = not show_table
	for i in range(_dots.size()):
		(_dots[i]["button"] as Button).set_meta(&"active", i == _section)
	_apply_state(false)


func _layout_content() -> void:
	super._layout_content()
	if _title == null or size.x <= 0.0:
		return
	var width := size.x
	_title.position = Vector2(PAD, 16.0)
	_title.size = Vector2(width * 0.6, 34.0)
	_competition.position = Vector2(PAD, 52.0)
	_competition.size = Vector2(width * 0.7, 20.0)
	_round.position = Vector2(width - PAD - 160.0, 18.0)
	_round.size = Vector2(160.0, 20.0)

	var dots_width := _dots.size() * DOT + maxi(0, _dots.size() - 1) * DOT_GAP
	var dots_y := size.y - PAD - DOT
	for index in range(_dots.size()):
		var dot: Dictionary = _dots[index]
		var button: Button = dot["button"]
		button.position = Vector2(width - PAD - dots_width + index * (DOT + DOT_GAP), dots_y)
		button.size = Vector2(DOT, DOT)
		var mark: Panel = dot["mark"]
		mark.position = Vector2(5.0, 5.0)
		mark.size = Vector2(6.0, 6.0)
		var box := StyleBoxFlat.new()
		box.bg_color = _dot_color(bool(button.get_meta(&"active", false)))
		box.corner_radius_top_left = 3
		box.corner_radius_top_right = 3
		box.corner_radius_bottom_left = 3
		box.corner_radius_bottom_right = 3
		mark.add_theme_stylebox_override(&"panel", box)

	var top := 80.0
	var available := dots_y - 6.0 - top
	var row_height := available / maxf(1.0, float(_rows.size()))
	for index in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var root: Control = row["root"]
		root.position = Vector2(PAD - 6.0, top + index * row_height)
		root.size = Vector2(width - PAD * 2.0 + 12.0, row_height)
		var bg: Panel = row["bg"]
		bg.position = Vector2.ZERO
		bg.size = root.size
		var rail: ColorRect = row["rail"]
		rail.position = Vector2.ZERO
		rail.size = Vector2(2.0, root.size.y)
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.TABLE_ROW_OWN if bool(row["own"]) \
			else Color(0.0, 0.0, 0.0, 0.0)
		box.border_width_bottom = 1
		box.border_color = UiTokens.TABLE_DIVIDER_FOCUS if has_focus() \
			else UiTokens.TABLE_DIVIDER
		bg.add_theme_stylebox_override(&"panel", box)
		bg.visible = true
		rail.visible = bool(row["own"])
		rail.color = UiTokens.RAIL
		var text_x := 6.0
		var crest_size := 20.0
		var pos: Label = row["pos"]
		pos.position = Vector2(text_x, 0.0)
		pos.size = Vector2(24.0, root.size.y)
		var crest: TextureRect = row["crest"]
		crest.position = Vector2(text_x + 26.0, (root.size.y - crest_size) * 0.5)
		crest.size = Vector2(crest_size, crest_size)
		crest.visible = not bool(row["head"])
		var name: Label = row["name"]
		name.position = Vector2(text_x + 52.0, 0.0)
		name.size = Vector2(root.size.x - 52.0 - 74.0, root.size.y)
		var played: Label = row["played"]
		played.position = Vector2(root.size.x - 74.0, 0.0)
		played.size = Vector2(30.0, root.size.y)
		var points: Label = row["points"]
		points.position = Vector2(root.size.x - 34.0, 0.0)
		points.size = Vector2(28.0, root.size.y)
	_soon.position = Vector2(PAD, top)
	_soon.size = Vector2(width - PAD * 2.0, available)


func _apply_state(animate: bool) -> void:
	super._apply_state(animate)
	if _title == null:
		return
	var focused := has_focus() and not disabled
	var ink := UiTokens.FOCUS_INK if focused else UiTokens.INK
	var ink_2 := UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
	_title.add_theme_color_override(&"font_color", ink)
	_competition.add_theme_color_override(&"font_color", ink_2)
	_round.add_theme_color_override(&"font_color", ink_2)
	_soon.add_theme_color_override(&"font_color", ink_2)
	for row in _rows:
		(row["pos"] as Label).add_theme_color_override(&"font_color", ink_2)
		(row["played"] as Label).add_theme_color_override(&"font_color", ink_2)
		(row["name"] as Label).add_theme_color_override(&"font_color", ink)
		(row["points"] as Label).add_theme_color_override(&"font_color", ink)
	for i in range(_dots.size()):
		var active := bool((_dots[i]["button"] as Button).get_meta(&"active", false))
		var mark: Panel = _dots[i]["mark"]
		var box := StyleBoxFlat.new()
		box.bg_color = _dot_color(active)
		for corner in ["corner_radius_top_left", "corner_radius_top_right",
				"corner_radius_bottom_left", "corner_radius_bottom_right"]:
			box.set(corner, 3)
		mark.add_theme_stylebox_override(&"panel", box)
	_layout_content()


func _dot_color(active: bool) -> Color:
	var focused := has_focus()
	if active:
		return UiTokens.FOCUS_MARK if focused else UiTokens.INK
	return Color(UiTokens.FOCUS_INK, 0.28) if focused else Color(UiTokens.INK, 0.24)


func _label(size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _logo(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return UiAssets.usable_texture(
		UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
