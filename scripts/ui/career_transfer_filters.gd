class_name CareerTransferFilters
extends Control
# Prototype transfers/TransferFilters.svelte: the transfer search filter board
# for the TRANSFERS tab body — eight tiles in a 4×2 grid (name, position & role,
# citizenship, league, age, transfer status, country, club) plus the SEARCH /
# RESET actions. Clicking a tile opens it for editing: left/right steps the
# focused row, up/down picks the row of a two-row tile, confirm closes it and
# the name tile opens the shared on-screen keyboard. The host owns the hints
# bar and calls hints()/status-free, like CareerSquadView.
#
# Filter schema (agreed, do not rename):
#   {name, group, position, age_min, age_max, citizenship, country_id,
#    league_id, club_id, status, foot, height_min, height_max, sort}
# "no filter" is "" for text/enums and 0 for the age/height ranges.

signal applied(filters: Dictionary)
signal closed

const GAP := 10.0
const ACTION_H := 64.0
const GRID_COLUMNS := 4
const GRID_ROWS := 2

const TILE_IDS := [
	"name", "role", "citizenship", "league",
	"age", "status", "country", "club",
]
const GROUPS := [
	{"value": "", "label": "ALL"},
	{"value": "FWD", "label": "FWD"},
	{"value": "MID", "label": "MID"},
	{"value": "DEF", "label": "DEF"},
	{"value": "GK", "label": "GK"},
]
const STATUSES := [
	{"value": "", "label": "ANY"},
	{"value": "free", "label": "FREE AGENT"},
	{"value": "transfer", "label": "TRANSFER LISTED"},
	{"value": "loan", "label": "ON LOAN"},
	{"value": "blocked", "label": "BLOCKED"},
]
const POSITIONS := [
	"Goalkeeper", "Sweeper", "Defender", "Centre-Back", "Left-Back",
	"Right-Back", "Defensive Midfield", "Central Midfield",
	"Attacking Midfield", "Left Midfield", "Right Midfield", "Midfielder",
	"Left Winger", "Right Winger", "Striker", "Centre-Forward",
	"Second Striker",
]
const AGE_MIN := 15
const AGE_MAX := 50
# Tile id -> filter schema key (the tiles label themselves, the schema is fixed).
const FIELD_OF := {
	"name": "name",
	"citizenship": "citizenship",
	"league": "league_id",
	"status": "status",
	"country": "country_id",
	"club": "club_id",
}
# Kept literal: const arrays have no const size(); _ready asserts the pair.
const SEARCH_ACTION := 8
const RESET_ACTION := 9


# The name tile's users glyph. A child Control (not Tile._draw) so it paints
# above the background panel.
class Glyph extends Control:
	var focused := false

	func _draw() -> void:
		var color := Color(UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2, 0.42)
		var radius := size.x * 0.15
		var head := Vector2(size.x * 0.34, size.y * 0.32)
		draw_circle(head, radius, color)
		draw_circle(head + Vector2(radius * 2.0, radius * 0.4), radius * 0.86, color)
		draw_arc(Vector2(head.x, size.y), radius * 2.1, PI, TAU, 18, color,
			maxf(2.0, radius * 0.5), true)
		draw_arc(Vector2(head.x + radius * 2.7, size.y), radius * 1.5, PI, TAU, 18,
			color, maxf(2.0, radius * 0.5), true)


# One filter tile: uppercase label, one or two value rows, an optional logo /
# position badge, arrows while editing and the prototype's users glyph on the
# name tile. Focus inverts it like the bento tiles (FOCUS_FILL + lime label).
class Tile extends Control:
	signal activated
	signal stepped(delta: int)
	signal row_clicked(index: int)

	const PAD_X := 18.0
	const PAD_TOP := 16.0
	const PAD_BOTTOM := 16.0
	const ROW_H := 32.0
	const ROW_GAP := 6.0
	const ARROW := 26.0
	const ICON := 46.0

	var _label: Label
	var _rail: ColorRect
	var _bg: Panel
	var _glyph: Glyph
	var _normal_box: StyleBoxFlat
	var _focus_box: StyleBoxFlat
	var _rows: Array = []
	var _focused := false
	var _editing := false
	var _active_row := 0
	var _icon_rect := Rect2()


	func _init(tile_label: String, row_count: int, with_icon := false) -> void:
		name = "Tile_%s" % tile_label.to_lower()
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_rail = ColorRect.new()
		_rail.color = UiTokens.RAIL
		_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rail)
		_glyph = Glyph.new()
		_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glyph.visible = with_icon
		add_child(_glyph)
		_normal_box = _make_box(UiTokens.TILE, 0.30)
		_focus_box = _make_box(UiTokens.FOCUS_FILL, 0.44)
		_label = Label.new()
		_label.name = "Label"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.add_theme_font_override(&"font", UiTheme.barlow(700))
		_label.add_theme_font_size_override(&"font_size", 21)
		add_child(_label)
		_label.text = tile_label
		for index in row_count:
			_rows.append(_make_row(index))
		resized.connect(_layout_content)
		_apply_state()


	func _make_box(fill: Color, shadow_alpha: float) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.shadow_color = Color(UiTokens.SHADOW, shadow_alpha)
		box.shadow_size = 22
		box.shadow_offset = Vector2(0.0, 18.0)
		box.anti_aliasing = true
		return box


	func _make_row(index: int) -> Dictionary:
		var panel := PanelContainer.new()
		panel.name = "Row%d" % index
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		box.content_margin_top = 4.0
		box.content_margin_bottom = 4.0
		panel.add_theme_stylebox_override(&"panel", box)
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(line)

		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 12)
		line.add_child(label)

		var left := _make_arrow("‹", index, -1)
		line.add_child(left["panel"])

		var main := HBoxContainer.new()
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.add_theme_constant_override(&"separation", 8)
		main.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(main)

		var logo := TextureRect.new()
		logo.custom_minimum_size = Vector2(22.0, 22.0)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.visible = false
		main.add_child(logo)

		var badge_panel := PanelContainer.new()
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge_panel.visible = false
		var badge_box := StyleBoxFlat.new()
		badge_box.bg_color = Color(UiTokens.INK, 0.10)
		badge_box.content_margin_left = 5.0
		badge_box.content_margin_right = 5.0
		badge_box.content_margin_top = 1.0
		badge_box.content_margin_bottom = 1.0
		badge_panel.add_theme_stylebox_override(&"panel", badge_box)
		main.add_child(badge_panel)
		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override(&"font", UiTheme.inter(700))
		badge.add_theme_font_size_override(&"font_size", 13)
		badge_panel.add_child(badge)

		var value := Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		value.add_theme_font_override(&"font", UiTheme.inter(600))
		value.add_theme_font_size_override(&"font_size", 15)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.add_child(value)

		var right := _make_arrow("›", index, 1)
		line.add_child(right["panel"])

		add_child(panel)
		return {
			"panel": panel, "box": box, "line": line, "label": label,
			"main": main, "logo": logo, "badge_panel": badge_panel,
			"badge": badge, "value": value,
			"left": left["panel"], "left_label": left["label"],
			"right": right["panel"], "right_label": right["label"],
		}


	func _make_arrow(text: String, row_index: int, delta: int) -> Dictionary:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(ARROW, ARROW)
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.visible = false
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				row_clicked.emit(row_index)
				stepped.emit(delta)
				panel.accept_event())
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.INK, 0.08)
		panel.add_theme_stylebox_override(&"panel", box)
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override(&"font", UiTheme.barlow(700))
		label.add_theme_font_size_override(&"font_size", 18)
		panel.add_child(label)
		return {"panel": panel, "label": label}


	func set_rows(rows: Array, editing: bool, active_row: int) -> void:
		_editing = editing
		_active_row = active_row
		for index in _rows.size():
			var row: Dictionary = _rows[index]
			var used := index < rows.size()
			(row["panel"] as Control).visible = used
			if not used:
				continue
			var data: Dictionary = rows[index]
			var text := str(data.get("label", ""))
			(row["label"] as Label).text = text
			(row["label"] as Label).visible = not text.is_empty()
			var has_label := not text.is_empty()
			var value := row["value"] as Label
			value.text = str(data.get("value", ""))
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if has_label \
				else HORIZONTAL_ALIGNMENT_LEFT
			(row["main"] as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END if has_label \
				else BoxContainer.ALIGNMENT_BEGIN
			var badge_text := str(data.get("badge", ""))
			(row["badge"] as Label).text = badge_text
			(row["badge_panel"] as Control).visible = not badge_text.is_empty()
			var logo := data.get("logo") as Texture2D
			var logo_rect := row["logo"] as TextureRect
			logo_rect.texture = logo
			logo_rect.visible = logo != null
			var arrows := editing
			(row["left"] as Control).visible = arrows
			(row["right"] as Control).visible = arrows
		_layout_content()
		_apply_state()


	func set_state(focused: bool) -> void:
		_focused = focused
		_apply_state()


	func is_editing() -> bool:
		return _editing


	func _apply_state() -> void:
		if _bg == null:
			return
		_bg.add_theme_stylebox_override(&"panel",
			_focus_box if _focused else _normal_box)
		_rail.visible = not _focused
		_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if _focused else UiTokens.INK_2)
		_glyph.focused = _focused
		_glyph.queue_redraw()
		for index in _rows.size():
			var row: Dictionary = _rows[index]
			var box := row["box"] as StyleBoxFlat
			var active := _editing and index == _active_row
			box.bg_color = Color(UiTokens.FOCUS_INK, 0.10) if _focused \
				else Color(UiTokens.INK, 0.06)
			box.border_width_left = 2 if active else 0
			box.border_color = UiTokens.FOCUS_MARK
			(row["label"] as Label).add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK_2 if _focused else UiTokens.INK_2)
			(row["value"] as Label).add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK if _focused else UiTokens.INK)
			(row["badge_panel"] as PanelContainer).add_theme_stylebox_override(
				&"panel", _badge_box())
			(row["badge"] as Label).add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK if _focused else UiTokens.INK)
			for arrow_key in ["left", "right"]:
				var arrow := row[arrow_key] as PanelContainer
				var arrow_box := StyleBoxFlat.new()
				arrow_box.bg_color = Color(UiTokens.FOCUS_INK, 0.12) if _focused \
					else Color(UiTokens.INK, 0.08)
				arrow.add_theme_stylebox_override(&"panel", arrow_box)
				(row["%s_label" % arrow_key] as Label).add_theme_color_override(
					&"font_color", UiTokens.FOCUS_MARK if _focused else UiTokens.INK_2)


	func _badge_box() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.FOCUS_INK, 0.12) if _focused \
			else Color(UiTokens.INK, 0.10)
		box.content_margin_left = 5.0
		box.content_margin_right = 5.0
		box.content_margin_top = 1.0
		box.content_margin_bottom = 1.0
		return box


	func _layout_content() -> void:
		if _bg == null or size.x <= 0.0:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		_label.position = Vector2(PAD_X, PAD_TOP)
		_label.size = Vector2(size.x - PAD_X * 2.0, 22.0)
		var visible_rows := 0
		for row in _rows:
			if (row["panel"] as Control).visible:
				visible_rows += 1
		var row_h := ROW_H if visible_rows > 1 else 34.0
		var total := visible_rows * row_h + maxf(0.0, visible_rows - 1) * ROW_GAP
		var y := size.y - PAD_BOTTOM - total
		for row in _rows:
			var panel := row["panel"] as Control
			if not panel.visible:
				continue
			panel.position = Vector2(PAD_X, y)
			panel.size = Vector2(size.x - PAD_X * 2.0, row_h)
			y += row_h + ROW_GAP
		_icon_rect = Rect2(size.x - PAD_X - ICON, size.y - PAD_BOTTOM - total - ICON - 8.0,
			ICON, ICON)
		_glyph.position = _icon_rect.position
		_glyph.size = _icon_rect.size


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				activated.emit()
				accept_event()


# Screen ---------------------------------------------------------------------

var _filters: Dictionary = {}
var _reference: Dictionary = {}
var _editing := ""
var _role_row := "group"
var _age_row := "age_min"
var _focus := 0
var _last_grid_focus := 0
var _tiles: Array = []
var _search_rect := Rect2()
var _reset_rect := Rect2()
var _actions: Array = []
var _osk: UiOnScreenKeyboard
var _appear_tween: Tween


func _ready() -> void:
	assert(TILE_IDS.size() == SEARCH_ACTION, "TILE_IDS must match SEARCH_ACTION")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_filters = normalize({})
	_build()
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	var nav := _ui_nav()
	if nav != null:
		nav.moved.connect(_on_nav_moved)
		nav.confirmed.connect(_on_nav_confirmed)
		nav.cancelled.connect(_on_nav_cancelled)
	call_deferred("_layout")
	_refresh()


func setup(filters: Dictionary, reference: Dictionary) -> void:
	_reference = {
		"countries": reference.get("countries", []) if reference.get("countries") is Array else [],
		"leagues": reference.get("leagues", []) if reference.get("leagues") is Array else [],
		"clubs": reference.get("clubs", []) if reference.get("clubs") is Array else [],
	}
	_filters = normalize(filters)
	_editing = ""
	if is_node_ready():
		_refresh()
		_layout()


func filters() -> Dictionary:
	return _filters.duplicate(true)


func editing() -> String:
	return _editing


func focus_initial() -> void:
	_focus = 0
	_last_grid_focus = 0
	_refresh()


func hints() -> Array:
	var gamepad: bool = false
	var nav := _ui_nav()
	if nav != null:
		gamepad = nav.using_gamepad()
	if not _editing.is_empty():
		return [
			{"keys": ["D-PAD"] if gamepad else ["←", "→"], "label": "change"},
			{"keys": ["A"] if gamepad else ["ENTER"], "label": "done"},
			{"keys": ["B"] if gamepad else ["ESC"], "label": "done"},
		]
	return [
		{"keys": ["D-PAD"] if gamepad else ["←", "→", "↑", "↓"], "label": "filters"},
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
		{"keys": ["X"], "label": "reset"},
		{"keys": ["Y"], "label": "search"},
		{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
	]


# Schema ---------------------------------------------------------------------

static func normalize(filters: Dictionary) -> Dictionary:
	return {
		"name": str(filters.get("name", "")),
		"group": str(filters.get("group", "")),
		"position": str(filters.get("position", "")),
		"age_min": _int_or_zero(filters.get("age_min")),
		"age_max": _int_or_zero(filters.get("age_max")),
		"citizenship": str(filters.get("citizenship", "")),
		"country_id": str(filters.get("country_id", "")),
		"league_id": str(filters.get("league_id", "")),
		"club_id": str(filters.get("club_id", "")),
		"status": str(filters.get("status", "")),
		"foot": str(filters.get("foot", "")),
		"height_min": _int_or_zero(filters.get("height_min")),
		"height_max": _int_or_zero(filters.get("height_max")),
		"sort": str(filters.get("sort", "overall")),
	}


# int(null) raises in GDScript; CareerSearch.filters_default() uses null for
# "no range", so the panel normalizes it to 0.
static func _int_or_zero(value) -> int:
	return 0 if value == null else int(value)


# Build ----------------------------------------------------------------------

func _build() -> void:
	for index in TILE_IDS.size():
		var id: String = TILE_IDS[index]
		var rows := 2 if id in ["role", "age"] else 1
		var tile := Tile.new(_tile_label(id), rows, id == "name")
		tile.mouse_entered.connect(_focus_tile.bind(index))
		tile.activated.connect(_on_tile_activated.bind(index))
		tile.stepped.connect(_on_tile_stepped.bind(index))
		tile.row_clicked.connect(_on_tile_row.bind(index))
		add_child(tile)
		_tiles.append(tile)
	for index in 2:
		var action := _make_action(index)
		add_child(action["panel"])
		_actions.append(action)
	_osk = UiOnScreenKeyboard.new()
	_osk.name = "SearchKeyboard"
	_osk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_osk.applied.connect(_on_name_applied)
	add_child(_osk)


func _tile_label(id: String) -> String:
	match id:
		"name":
			return "PLAYER NAME"
		"role":
			return "POSITION & ROLE"
		"citizenship":
			return "CITIZENSHIP"
		"league":
			return "LEAGUE"
		"age":
			return "AGE"
		"status":
			return "TRANSFER STATUS"
		"country":
			return "COUNTRY"
		"club":
			return "CLUB"
	return id.to_upper()


func _make_action(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Action%d" % index
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override(&"panel", box)
	var label := Label.new()
	label.text = "SEARCH" if index == 0 else "RESET"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.barlow(700))
	label.add_theme_font_size_override(&"font_size", 24)
	label.add_theme_color_override(&"font_color", UiTokens.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.gui_input.connect(_on_action_input.bind(index))
	panel.mouse_entered.connect(_focus_action.bind(index))
	return {"panel": panel, "label": label, "box": box}


func _layout() -> void:
	if _tiles.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var grid_h := maxf(0.0, size.y - ACTION_H - GAP)
	var cell_w := (size.x - GAP * (GRID_COLUMNS - 1)) / float(GRID_COLUMNS)
	var cell_h := (grid_h - GAP * (GRID_ROWS - 1)) / float(GRID_ROWS)
	for index in _tiles.size():
		var column := index % GRID_COLUMNS
		var row := floori(float(index) / GRID_COLUMNS)
		var tile := _tiles[index] as Control
		tile.position = Vector2(column * (cell_w + GAP), row * (cell_h + GAP))
		tile.size = Vector2(cell_w, cell_h)
	var action_w := cell_w
	_reset_rect = Rect2(size.x - action_w, grid_h + GAP, action_w, ACTION_H)
	_search_rect = Rect2(_reset_rect.position.x - GAP - action_w, _reset_rect.position.y,
		action_w, ACTION_H)
	_place_action(0, _search_rect)
	_place_action(1, _reset_rect)


func _place_action(index: int, rect: Rect2) -> void:
	var panel := _actions[index]["panel"] as PanelContainer
	panel.position = rect.position
	panel.size = rect.size


# Content --------------------------------------------------------------------

func _refresh() -> void:
	for index in _tiles.size():
		var tile := _tiles[index] as Tile
		tile.set_rows(_tile_rows(str(TILE_IDS[index])), _editing == str(TILE_IDS[index]),
			_active_row(str(TILE_IDS[index])))
		tile.set_state(_focus == index)
	for index in _actions.size():
		_apply_action_state(index, _focus == SEARCH_ACTION + index)


func _active_row(id: String) -> int:
	if _editing != id:
		return -1
	if id == "role":
		return 0 if _role_row == "group" else 1
	if id == "age":
		return 0 if _age_row == "age_min" else 1
	return 0


func _tile_rows(id: String) -> Array:
	match id:
		"name":
			return [{"value": _or_any(str(_filters["name"]))}]
		"role":
			return [
				{"label": "POSITION", "value": _group_label()},
				{"label": "ROLE", "value": _position_label(),
					"badge": _position_badge()},
			]
		"citizenship":
			return [{"value": _or_any(str(_filters["citizenship"])),
				"logo": _country_texture_by_name(str(_filters["citizenship"]))}]
		"league":
			return [{"value": _or_any(_entry_name("leagues", "id",
				str(_filters["league_id"]))),
				"logo": _entry_texture("leagues", str(_filters["league_id"]))}]
		"age":
			return [
				{"label": "MIN.", "value": _age_text(int(_filters["age_min"]))},
				{"label": "MAX.", "value": _age_text(int(_filters["age_max"]))},
			]
		"status":
			return [{"value": _status_label(str(_filters["status"]))}]
		"country":
			return [{"value": _or_any(_entry_name("countries", "id",
				str(_filters["country_id"]))),
				"logo": _entry_texture("countries", str(_filters["country_id"]))}]
		"club":
			var value := _or_any(_entry_name("clubs", "id", str(_filters["club_id"])))
			if str(_filters["league_id"]).is_empty() and str(_filters["club_id"]).is_empty():
				value = "PICK A LEAGUE"
			return [{"value": value,
				"logo": _entry_texture("clubs", str(_filters["club_id"]))}]
	return []


func _or_any(value: String) -> String:
	return value if not value.is_empty() else "ANY"


func _group_label() -> String:
	for option in GROUPS:
		if str(option["value"]) == str(_filters["group"]):
			return str(option["label"])
	return "ALL"


func _position_label() -> String:
	var position := str(_filters["position"])
	return position if not position.is_empty() else "ANY"


func _position_badge() -> String:
	var position := str(_filters["position"])
	if position.is_empty():
		return ""
	return CareerPlayerCard.position_code(position, str(_filters["group"]))


func _status_label(status: String) -> String:
	for option in STATUSES:
		if str(option["value"]) == status:
			return str(option["label"])
	return "ANY"


func _age_text(value: int) -> String:
	return "ANY" if value <= 0 else str(value)


func _entry(collection: String) -> Array:
	return _reference.get(collection, []) as Array


func _entry_by_id(collection: String, id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for entry in _entry(collection):
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry
	return {}


func _entry_name(collection: String, key: String, id: String) -> String:
	return str(_entry_by_id(collection, id).get("name", ""))


func _entry_texture(collection: String, id: String) -> Texture2D:
	if id.is_empty():
		return null
	return entry_texture(_entry_by_id(collection, id))


func _country_texture_by_name(name: String) -> Texture2D:
	if name.is_empty():
		return null
	for entry in _entry("countries"):
		if entry is Dictionary and str(entry.get("name", "")) == name:
			return entry_texture(entry)
	return null


# Reference entries may carry the image path as logo / flag / career_logo, a
# country tm_id (flags) or join a league/country by id; otherwise the career
# asset helpers resolve it from the entry itself.
static func entry_texture(entry: Dictionary) -> Texture2D:
	for key in ["flag", "logo", "career_logo", "logo_url"]:
		var path := str(entry.get(key, ""))
		if path.is_empty():
			continue
		var texture := UiAssets.usable_texture(
			UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
		if texture != null:
			return texture
	if entry.has("league_id") or entry.has("career_logo"):
		return UiAssets.usable_texture(UiAssets.team_logo(entry))
	if entry.has("legacy_id") or entry.has("tier"):
		return UiAssets.usable_texture(UiAssets.league_logo(entry))
	if entry.has("tm_id"):
		return UiAssets.usable_texture(
			UiAssets.country_flag({"tm_id": str(entry.get("tm_id", ""))}))
	return null


# Options per field ----------------------------------------------------------

func _options(field: String) -> Array:
	match field:
		"group":
			return GROUPS
		"position":
			var options: Array = [{"value": "", "label": "ANY"}]
			for position in POSITIONS:
				options.append({"value": position, "label": position,
					"badge": CareerPlayerCard.position_code(position)})
			return options
		"citizenship":
			var countries: Array = [{"value": "", "label": "ANY"}]
			for entry in _entry("countries"):
				countries.append({"value": str(entry.get("name", "")),
					"label": str(entry.get("name", "")), "logo": entry_texture(entry)})
			return countries
		"country_id":
			var country_options: Array = [{"value": "", "label": "ANY"}]
			for entry in _entry("countries"):
				country_options.append({"value": str(entry.get("id", "")),
					"label": str(entry.get("name", "")), "logo": entry_texture(entry)})
			return country_options
		"league_id":
			var leagues: Array = [{"value": "", "label": "ANY"}]
			for entry in _entry("leagues"):
				if not str(_filters["country_id"]).is_empty() and entry.has("country_id") \
						and str(entry.get("country_id", "")) != str(_filters["country_id"]):
					continue
				leagues.append({"value": str(entry.get("id", "")),
					"label": str(entry.get("name", "")), "logo": entry_texture(entry)})
			return leagues
		"club_id":
			if str(_filters["league_id"]).is_empty():
				return []
			var clubs: Array = [{"value": "", "label": "ANY"}]
			for entry in _entry("clubs"):
				# The reference may already be scoped to the league.
				if entry.has("league_id") \
						and str(entry.get("league_id", "")) != str(_filters["league_id"]):
					continue
				clubs.append({"value": str(entry.get("id", "")),
					"label": str(entry.get("name", "")), "logo": entry_texture(entry)})
			return clubs
		"status":
			return STATUSES
	return []


func _apply_field(field: String, value: String) -> void:
	_filters[field] = value
	if field == "country_id":
		_filters["league_id"] = ""
		_filters["club_id"] = ""
	elif field == "league_id":
		_filters["club_id"] = ""


func _step_field(field: String, delta: int) -> void:
	var options := _options(field)
	if options.size() < 2:
		return
	var index := 0
	for i in options.size():
		if str(options[i]["value"]) == str(_filters[field]):
			index = i
			break
	var next: Dictionary = options[posmod(index + delta, options.size())]
	_apply_field(field, str(next["value"]))


func _step_age(field: String, delta: int) -> void:
	var current := int(_filters[field])
	var next := 0
	if current <= 0:
		next = AGE_MIN if delta > 0 else AGE_MAX
	else:
		next = current + delta
		if next < AGE_MIN or next > AGE_MAX:
			next = 0
	_filters[field] = next
	if int(_filters["age_min"]) > 0 and int(_filters["age_max"]) > 0 \
			and int(_filters["age_min"]) > int(_filters["age_max"]):
		if field == "age_min":
			_filters["age_max"] = _filters["age_min"]
		else:
			_filters["age_min"] = _filters["age_max"]


func _step_active(delta: int) -> void:
	match _editing:
		"age":
			_step_age(_age_row, delta)
		"role":
			_step_field(_role_row, delta)
		_:
			if not _editing.is_empty():
				_step_field(_field(_editing), delta)


func _field(tile_id: String) -> String:
	return str(FIELD_OF.get(tile_id, tile_id))


func _cycle_row() -> void:
	if _editing == "role":
		_role_row = "position" if _role_row == "group" else "group"
	elif _editing == "age":
		_age_row = "age_max" if _age_row == "age_min" else "age_min"


# Actions --------------------------------------------------------------------

func _activate(index: int) -> void:
	if index >= SEARCH_ACTION:
		if index == SEARCH_ACTION:
			_search()
		else:
			_reset()
		return
	_last_grid_focus = index
	var id: String = TILE_IDS[index]
	if _editing == id:
		_editing = ""
		_refresh()
		return
	if id == "name":
		_editing = ""
		_refresh()
		_open_keyboard()
		return
	_editing = id
	if id == "role":
		_role_row = "group"
	elif id == "age":
		_age_row = "age_min"
	_refresh()


func _search() -> void:
	_editing = ""
	_refresh()
	applied.emit(filters())


func _reset() -> void:
	_filters = normalize({})
	_editing = ""
	_refresh()


func _open_keyboard() -> void:
	if _osk == null:
		return
	_osk.open("Player name", str(_filters["name"]), 24, "",
		UiTokens.OSK_ROWS_CAREER)


func _on_name_applied(text: String) -> void:
	_filters["name"] = text.strip_edges().to_upper()
	_refresh()


func _on_tile_activated(index: int) -> void:
	_focus = index
	_activate(index)


func _on_tile_stepped(index: int, delta: int) -> void:
	_focus = index
	if _editing.is_empty():
		return
	_step_active(delta)


func _on_tile_row(index: int, row: int) -> void:
	_focus = index
	if _editing != TILE_IDS[index]:
		return
	if TILE_IDS[index] == "role":
		_role_row = "group" if row == 0 else "position"
	elif TILE_IDS[index] == "age":
		_age_row = "age_min" if row == 0 else "age_max"
	_refresh()


func _on_action_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_focus = SEARCH_ACTION + index
			_refresh()
			_activate(_focus)
			accept_event()


func _focus_tile(index: int) -> void:
	if _editing == TILE_IDS[index]:
		return
	_focus = index
	_last_grid_focus = index
	_refresh()


func _focus_action(index: int) -> void:
	_focus = SEARCH_ACTION + index
	_refresh()


func _apply_action_state(index: int, focused: bool) -> void:
	var action: Dictionary = _actions[index]
	var box := action["box"] as StyleBoxFlat
	box.bg_color = UiTokens.FOCUS_FILL if focused else UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW_SELECTED if focused else UiTokens.SHADOW
	# The magenta rail is part of the box: a ColorRect child would be stretched
	# over the whole PanelContainer.
	box.border_width_left = 0 if focused else int(UiTokens.RAIL_W)
	box.border_color = UiTokens.RAIL
	var label := action["label"] as Label
	var color := UiTokens.INK
	if focused:
		color = UiTokens.FOCUS_MARK
	elif index == 0:
		color = UiTokens.RAIL
	label.add_theme_color_override(&"font_color", color)


# Input ----------------------------------------------------------------------

func _is_active() -> bool:
	var nav := _ui_nav()
	# `event_was_modal` is the gate for a modal that closed inside the same event
	# (the on-screen keyboard on the name tile): the filter board must not also
	# run its own Back on that keystroke.
	return is_visible_in_tree() and (nav == null or not (
		nav.is_modal() or nav.event_was_modal()))


# Autoloads are looked up by path: the screen is also instantiated by the
# headless tests directly, where bare UiNav/UiTransition identifiers do not
# resolve.
func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_active():
		return
	if not _editing.is_empty():
		if direction == Vector2i.LEFT:
			_step_active(-1)
		elif direction == Vector2i.RIGHT:
			_step_active(1)
		elif direction == Vector2i.UP or direction == Vector2i.DOWN:
			_cycle_row()
		_refresh()
		return
	if _focus >= SEARCH_ACTION:
		if direction == Vector2i.LEFT:
			_focus = maxi(SEARCH_ACTION, _focus - 1)
		elif direction == Vector2i.RIGHT:
			_focus = mini(RESET_ACTION, _focus + 1)
		elif direction == Vector2i.UP:
			_focus = _last_grid_focus
		_refresh()
		return
	var column := _focus % GRID_COLUMNS
	var row := floori(float(_focus) / GRID_COLUMNS)
	match direction:
		Vector2i.LEFT:
			column = maxi(0, column - 1)
		Vector2i.RIGHT:
			column = mini(GRID_COLUMNS - 1, column + 1)
		Vector2i.UP:
			if row == 0:
				return
			row -= 1
		Vector2i.DOWN:
			if row == GRID_ROWS - 1:
				_focus = SEARCH_ACTION
				_refresh()
				return
			row += 1
	_focus = row * GRID_COLUMNS + column
	_last_grid_focus = _focus
	_refresh()


func _on_nav_confirmed() -> void:
	if not _is_active():
		return
	if not _editing.is_empty():
		_editing = ""
		_refresh()
		return
	_activate(_focus)


func _on_nav_cancelled() -> void:
	if not _is_active():
		return
	if not _editing.is_empty():
		_editing = ""
		_refresh()
		return
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _is_active() or not _editing.is_empty():
		return
	if _is_key(event, KEY_X):
		get_viewport().set_input_as_handled()
		_reset()
	elif _is_key(event, KEY_Y):
		get_viewport().set_input_as_handled()
		_search()
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed:
			return
		if button.button_index == JOY_BUTTON_X:
			get_viewport().set_input_as_handled()
			_reset()
		elif button.button_index == JOY_BUTTON_Y:
			get_viewport().set_input_as_handled()
			_search()


func _is_key(event: InputEvent, code: Key) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == code or key.physical_keycode == code)


# Motion ---------------------------------------------------------------------

func _on_visibility_changed() -> void:
	if not visible or _tiles.is_empty() or _instant():
		return
	if _appear_tween != null:
		_appear_tween.kill()
	var nodes: Array = []
	nodes.append_array(_tiles)
	for action in _actions:
		nodes.append(action["panel"])
	for node in nodes:
		(node as Control).modulate.a = 0.0
	_appear_tween = create_tween().set_parallel(true)
	for index in nodes.size():
		_appear_tween.tween_property(nodes[index], "modulate:a", 1.0,
			0.24).set_delay(0.02 * index)
