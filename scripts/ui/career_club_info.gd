class_name CareerClubInfo
extends Control
# Right-hand club dossier on New Career. The club data comes from TeamCatalog;
# this control only lays out the facts the career shell already has.

const ROW_ICONS := ["trophy", "globe", "layers", "pitch", "shirt", "sliders"]
const ROW_LABELS := ["LEAGUE", "COUNTRY", "TIER", "FOUNDED", "STADIUM", "CAPACITY"]

var _bg: Panel
var _title: Label
var _club_name: Label
var _founded: Label
var _description: Label
var _divider: ColorRect
var _row_icons: Array[TextureRect] = []
var _row_labels: Array[Label] = []
var _row_values: Array[Label] = []
var _row_boxes: Array[Panel] = []
var _stat_cells: Array[Panel] = []
var _stat_labels: Array[Label] = []
var _stat_values: Array[Label] = []
var _kits_title: Label
var _kit_arts: Array[KitArt] = []
var _kit_labels: Array[Label] = []
var _kit_catalog: KitCatalog
var _club: Dictionary = {}
var _squad: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kit_catalog = KitCatalog.new()
	_kit_catalog.load_data_root()
	_build()
	resized.connect(_layout_content)
	call_deferred("_layout_content")


func setup(club: Dictionary, squad: Array) -> void:
	_club = club
	_squad = squad
	_refresh()


func _build() -> void:
	_bg = Panel.new()
	_bg.name = "Bg"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.HUB_PANEL_TOP
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	_bg.add_theme_stylebox_override(&"panel", box)
	add_child(_bg)

	_title = _label("Title", 15, UiTheme.inter(700), UiTokens.FOCUS_INK_2)
	_title.text = "CLUB PROFILE"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)

	_club_name = _label("ClubName", 38, UiTheme.barlow(800), UiTokens.FOCUS_INK)
	_founded = _label("Founded", 16, UiTheme.inter(500), UiTokens.FOCUS_INK_2)
	_description = _label("Description", 17, UiTheme.inter(500), UiTokens.FOCUS_INK_2)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_club_name)
	add_child(_founded)
	add_child(_description)

	_divider = ColorRect.new()
	_divider.name = "Divider"
	_divider.color = Color(UiTokens.FOCUS_INK, 0.14)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)

	for index in ROW_LABELS.size():
		var row := Panel.new()
		row.name = "Row%d" % index
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row_box := StyleBoxFlat.new()
		row_box.bg_color = Color(UiTokens.FOCUS_INK, 0.055)
		row.add_theme_stylebox_override(&"panel", row_box)
		add_child(row)
		_row_boxes.append(row)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = UiIcon.texture(ROW_ICONS[index])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = UiTokens.FOCUS_INK_2
		row.add_child(icon)
		_row_icons.append(icon)

		var label := _label("Label", 11, UiTheme.inter(700), UiTokens.FOCUS_INK_2)
		label.text = ROW_LABELS[index]
		row.add_child(label)
		_row_labels.append(label)

		var value := _label("Value", 19, UiTheme.barlow(700), UiTokens.FOCUS_INK)
		row.add_child(value)
		_row_values.append(value)

	for index in 4:
		var cell := Panel.new()
		cell.name = "Stat%d" % index
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cell_box := StyleBoxFlat.new()
		cell_box.bg_color = Color(UiTokens.FOCUS_INK, 0.055)
		cell.add_theme_stylebox_override(&"panel", cell_box)
		add_child(cell)
		_stat_cells.append(cell)
		var stat_label := _label("Label", 11, UiTheme.inter(700), UiTokens.FOCUS_INK_2)
		cell.add_child(stat_label)
		_stat_labels.append(stat_label)
		var stat_value := _label("Value", 24, UiTheme.barlow(700), UiTokens.FOCUS_INK)
		cell.add_child(stat_value)
		_stat_values.append(stat_value)

	_kits_title = _label("KitsTitle", 11, UiTheme.inter(700), UiTokens.FOCUS_INK_2)
	_kits_title.text = "KITS"
	add_child(_kits_title)
	for index in 4:
		var art := KitArt.new()
		art.name = "Kit%d" % index
		add_child(art)
		_kit_arts.append(art)
		var label := _label("KitLabel", 12, UiTheme.inter(700), UiTokens.FOCUS_INK_2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		_kit_labels.append(label)


func _label(node_name: String, font_size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _refresh() -> void:
	if _club_name == null:
		return
	var club_name := str(_club.get("name", ""))
	var founded := str(_club.get("founded_on", ""))
	var founded_year := founded.substr(0, 4) if founded.length() >= 4 else "-"
	var league := str(_club.get("league_name", ""))
	var country := str(_club.get("country_name", ""))
	var tier := str(_club.get("tier_name", ""))
	if tier.is_empty():
		tier = "TIER %d" % int(_club.get("tier", 0))
	var stadium: Dictionary = _club.get("stadium", {})
	var stadium_name := str(stadium.get("name", ""))
	var seats := int(stadium.get("seats", 0))

	_club_name.text = club_name
	_founded.text = "Founded %s  ·  %s" % [founded_year, tier]
	_description.text = _describe(club_name, league, country, founded_year,
		stadium_name, seats)

	_row_values[0].text = league if not league.is_empty() else "-"
	_row_values[1].text = country if not country.is_empty() else "-"
	_row_values[2].text = tier
	_row_values[3].text = founded_year
	_row_values[4].text = stadium_name if not stadium_name.is_empty() else "-"
	_row_values[5].text = _thousands(seats) if seats > 0 else "-"

	var overalls: Array = []
	var ages: Array = []
	for player in _squad:
		overalls.append(float(player.get("overall", 0.0)))
		var age := int(player.get("age", 0))
		if age > 0:
			ages.append(age)
	var average_overall := 0.0
	if not overalls.is_empty():
		average_overall = round(_array_sum(overalls) / overalls.size() * 10.0) / 10.0
	var average_age := 0.0
	if not ages.is_empty():
		average_age = round(float(_array_sum(ages)) / ages.size() * 10.0) / 10.0
	_stat_labels[0].text = "SQUAD"
	_stat_values[0].text = str(_squad.size())
	_stat_labels[1].text = "AVG OVR"
	_stat_values[1].text = "%.1f" % average_overall
	_stat_labels[2].text = "AVG AGE"
	_stat_values[2].text = "%.1f" % average_age if not ages.is_empty() else "-"
	_stat_labels[3].text = "SQUAD VALUE"
	_stat_values[3].text = _format_value(_squad_value())
	var kits: Array = []
	if _kit_catalog != null and not _club.is_empty():
		kits = _kit_catalog.kits_for(_club)
	_kits_title.visible = not kits.is_empty()
	for index in _kit_arts.size():
		var shown: bool = index < kits.size()
		_kit_arts[index].visible = shown
		_kit_labels[index].visible = shown
		if shown:
			var kit: Dictionary = kits[index]
			_kit_arts[index].set_kit(kit)
			_kit_labels[index].text = str(kit.get("label", ""))
	_layout_content()


func _describe(club_name: String, league: String, country: String, founded: String,
		stadium: String, seats: int) -> String:
	var parts: Array[String] = []
	if not league.is_empty() and not country.is_empty():
		parts.append("%s plays in %s (%s)." % [club_name, league, country])
	elif not league.is_empty():
		parts.append("%s plays in %s." % [club_name, league])
	if founded != "-":
		parts.append("Founded in %s." % founded)
	if not stadium.is_empty():
		parts.append("Home ground: %s%s." % [
			stadium, "" if seats <= 0 else " (%s seats)" % _thousands(seats),
		])
	return " ".join(parts)


func _layout_content() -> void:
	if _bg == null or size.x <= 0.0:
		return
	_bg.position = Vector2.ZERO
	_bg.size = size
	var pad := 28.0
	var left_width := 360.0
	var right_x := pad + left_width + 24.0
	var right_width := size.x - right_x - pad
	var row_top := 68.0
	var row_height := 62.0
	var row_gap := 8.0

	_title.position = Vector2(pad, 22.0)
	_title.size = Vector2(left_width, 22.0)
	for index in _row_boxes.size():
		var row := _row_boxes[index]
		row.position = Vector2(pad, row_top + float(index) * (row_height + row_gap))
		row.size = Vector2(left_width, row_height)
		var icon := _row_icons[index]
		icon.position = Vector2(14.0, 14.0)
		icon.size = Vector2(34.0, 34.0)
		var label := _row_labels[index]
		label.position = Vector2(60.0, 10.0)
		label.size = Vector2(left_width - 74.0, 16.0)
		var value := _row_values[index]
		value.position = Vector2(60.0, 28.0)
		value.size = Vector2(left_width - 74.0, 26.0)

	_club_name.position = Vector2(right_x, 18.0)
	_club_name.size = Vector2(right_width, 48.0)
	_founded.position = Vector2(right_x, 68.0)
	_founded.size = Vector2(right_width, 22.0)
	_description.position = Vector2(right_x, 102.0)
	_description.size = Vector2(right_width, 150.0)
	_divider.position = Vector2(right_x, 268.0)
	_divider.size = Vector2(right_width, 1.0)

	var cell_gap := 10.0
	var cell_width := (right_width - cell_gap) * 0.5
	var cell_height := 96.0
	for index in _stat_cells.size():
		var cell := _stat_cells[index]
		var column := index % 2
		var row := index / 2
		cell.position = Vector2(
			right_x + float(column) * (cell_width + cell_gap),
			278.0 + float(row) * (cell_height + cell_gap)
		)
		cell.size = Vector2(cell_width, cell_height)
		_stat_labels[index].position = Vector2(14.0, 10.0)
		_stat_labels[index].size = Vector2(cell_width - 28.0, 16.0)
		_stat_values[index].position = Vector2(14.0, 30.0)
		_stat_values[index].size = Vector2(cell_width - 28.0, 46.0)

	_kits_title.position = Vector2(pad, 580.0)
	_kits_title.size = Vector2(220.0, 18.0)
	var kit_gap := 18.0
	var kit_width := (size.x - pad * 2.0 - kit_gap * 3.0) * 0.25
	for index in _kit_arts.size():
		var art := _kit_arts[index]
		art.position = Vector2(pad + float(index) * (kit_width + kit_gap), 606.0)
		art.size = Vector2(kit_width, 140.0)
		var label := _kit_labels[index]
		label.position = Vector2(art.position.x, 750.0)
		label.size = Vector2(kit_width, 18.0)


func _squad_value() -> int:
	var total := 0
	for player in _squad:
		total += int(player.get("market_value", 0))
	return total


static func _format_value(value: int) -> String:
	if value >= 1000000000:
		return "€%.2fB" % (float(value) / 1000000000.0)
	if value >= 1000000:
		return "€%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "€%.0fK" % (float(value) / 1000.0)
	return "€%d" % value


static func _thousands(value: int) -> String:
	var text := str(value)
	var out := ""
	while text.length() > 3:
		out = " " + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out


static func _array_sum(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total
