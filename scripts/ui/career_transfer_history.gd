class_name CareerTransferHistory
extends Control
# Prototype TransferHistory.svelte: every completed deal and every transfer
# waiting for the window, newest first. Three filter tabs (all leagues / my
# league / my club), a FEE / OVR column header and one focusable row per entry:
# photo, player + role, club crests, fee, overall and date/status.
#
# Rows come from CareerTransfers.history_rows(career, catalog); the screen never
# writes. It is an overlay of the TRANSFERS tab: Back closes it, Q/E cycles the
# filter and the host draws the hints bar from hints().

signal closed

const TABS := [
	{"id": "all", "label": "ALL LEAGUES"},
	{"id": "league", "label": "MY LEAGUE"},
	{"id": "club", "label": "MY CLUB"},
]
const STATUS_LABELS := {
	"completed": "COMPLETED",
	"agreed": "AGREED",
	"signed": "SIGNED",
	"pending": "PENDING",
	"accepted": "ACCEPTED",
	"refused": "REFUSED",
	"counter": "COUNTER",
	"expired": "EXPIRED",
}
const TABS_H := 52.0
const GAP := 8.0
const HEAD_H := 22.0
const ROW_H := 76.0
const ROW_GAP := 6.0
const COL_GAP := 14.0
const ROW_PAD_L := 16.0
const ROW_PAD_R := 12.0
const PHOTO_COL := 56.0
const OVR_COL := 56.0
const WIN := Color("2f7d4f")
const WARN := Color("a66a00")



# One deal: photo, name/role, club crests, fee, overall, date and status.
class Row extends Control:
	var _entry: Dictionary = {}
	var _bg: Panel
	var _rail: ColorRect
	var _photo: CareerPlayerCard.Photo
	var _name: Label
	var _meta: Label
	var _from_logo: TextureRect
	var _from_label: Label
	var _arrow: Label
	var _to_logo: TextureRect
	var _to_label: Label
	var _fee: Label
	var _ovr: Label
	var _ovr_caption: Label
	var _date: Label
	var _status: Label


	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
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
		_name = _label(UiTheme.barlow(700), 20, UiTokens.INK)
		_meta = _label(UiTheme.inter(500), 14, UiTokens.INK_2)
		_from_logo = _crest()
		_from_label = _label(UiTheme.inter(500), 14, UiTokens.INK_2)
		_arrow = _label(UiTheme.inter(500), 15, UiTokens.INK_2)
		_arrow.text = "→"
		_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_to_logo = _crest()
		_to_label = _label(UiTheme.inter(500), 14, UiTokens.INK)
		_fee = _label(UiTheme.barlow(700), 20, UiTokens.INK)
		_fee.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_ovr = _label(UiTheme.barlow(700), 22, UiTokens.INK)
		_ovr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ovr_caption = _label(UiTheme.inter(600), 12, UiTokens.INK_2)
		_ovr_caption.text = "OVR"
		_ovr_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_date = _label(UiTheme.inter(500), 14, UiTokens.INK_2)
		_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_status = _label(UiTheme.inter(600), 14, UiTokens.INK_2)
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		resized.connect(_layout)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()


	func _label(font: Font, font_size: int, color: Color) -> Label:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", color)
		add_child(label)
		return label


	func _crest() -> TextureRect:
		var crest := TextureRect.new()
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(crest)
		return crest


	# Shared with the column header: photo, name (1), clubs (1.7), fee (0.7),
	# overall and date/status (0.8), mirroring the prototype's CSS grid.
	static func column_widths(width: float) -> Array:
		var inner := maxf(0.0, width - ROW_PAD_L - ROW_PAD_R)
		var flex := maxf(0.0, inner - PHOTO_COL - OVR_COL - COL_GAP * 5.0)
		var total := 4.2
		var name_w := maxf(150.0, flex * (1.0 / total))
		var clubs_w := maxf(200.0, flex * (1.7 / total))
		var fee_w := maxf(90.0, flex * (0.7 / total))
		var date_w := maxf(110.0, flex * (0.8 / total))
		var overflow := name_w + clubs_w + fee_w + date_w - flex
		if overflow > 0.0:
			clubs_w = maxf(120.0, clubs_w - overflow)
		return [PHOTO_COL, name_w, clubs_w, fee_w, OVR_COL, date_w]


	func setup(entry: Dictionary, from_logo: Texture2D, to_logo: Texture2D) -> void:
		_entry = entry
		_name.text = str(entry.get("player_name", "")).to_upper()
		var role := str(entry.get("role", ""))
		var kind := str(entry.get("kind_label", "")).to_upper()
		_meta.text = "%s · %s" % [role, kind] if not role.is_empty() else kind
		_from_logo.texture = from_logo
		_from_logo.visible = from_logo != null
		_from_label.text = str(entry.get("from_club_name", ""))
		if _from_label.text.is_empty():
			_from_label.text = "Free agent"
		_to_logo.texture = to_logo
		_to_logo.visible = to_logo != null
		_to_label.text = str(entry.get("to_club_name", ""))
		if _to_label.text.is_empty():
			_to_label.text = "—"
		_fee.text = CareerPlayerPane.money(int(entry.get("fee", 0)))
		var ovr := int(round(float(entry.get("overall", 0.0))))
		_ovr.text = str(ovr)
		var status := str(entry.get("status", ""))
		_status.text = str(STATUS_LABELS.get(status, status.to_upper()))
		_date.text = CareerHubModel.short_date(str(entry.get("date", "")))
		_photo.show_texture(CareerPlayerCard.face_texture(entry))
		_layout()
		_apply_state()


	func _layout() -> void:
		if _bg == null or size.x <= 0.0:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		var widths := column_widths(size.x)
		var x := ROW_PAD_L
		_photo.position = Vector2(x, (size.y - PHOTO_COL) * 0.5)
		_photo.size = Vector2(PHOTO_COL, PHOTO_COL)
		x += widths[0] + COL_GAP
		_name.position = Vector2(x, 8.0)
		_name.size = Vector2(widths[1], 22.0)
		_meta.position = Vector2(x, 32.0)
		_meta.size = Vector2(widths[1], 18.0)
		x += widths[1] + COL_GAP

		# Clubs: [crest] name → [crest] name, each group half the column.
		var clubs_w: float = float(widths[2])
		var arrow_w := 16.0
		var gap := 6.0
		var from_icon := 22.0 if _from_logo.visible else 0.0
		var to_icon := 22.0 if _to_logo.visible else 0.0
		var text_w := maxf(30.0, (clubs_w - arrow_w - gap * 4.0 - from_icon - to_icon) * 0.5)
		var y := (size.y - 22.0) * 0.5
		var cx := x
		if _from_logo.visible:
			_from_logo.position = Vector2(cx, (size.y - 22.0) * 0.5)
			_from_logo.size = Vector2(22.0, 22.0)
			cx += 22.0 + gap
		_from_label.position = Vector2(cx, y)
		_from_label.size = Vector2(text_w, 22.0)
		_from_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cx += text_w + gap
		_arrow.position = Vector2(cx, y)
		_arrow.size = Vector2(arrow_w, 22.0)
		cx += arrow_w + gap
		if _to_logo.visible:
			_to_logo.position = Vector2(cx, (size.y - 22.0) * 0.5)
			_to_logo.size = Vector2(22.0, 22.0)
			cx += 22.0 + gap
		_to_label.position = Vector2(cx, y)
		_to_label.size = Vector2(maxf(20.0, x + clubs_w - cx), 22.0)
		_to_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		x += clubs_w + COL_GAP

		_fee.position = Vector2(x, (size.y - 24.0) * 0.5)
		_fee.size = Vector2(widths[3], 24.0)
		x += widths[3] + COL_GAP
		_ovr.position = Vector2(x, 14.0)
		_ovr.size = Vector2(widths[4], 26.0)
		_ovr_caption.position = Vector2(x, 40.0)
		_ovr_caption.size = Vector2(widths[4], 16.0)
		x += widths[4] + COL_GAP
		_date.position = Vector2(x, 18.0)
		_date.size = Vector2(widths[5], 18.0)
		_status.position = Vector2(x, 40.0)
		_status.size = Vector2(widths[5], 18.0)


	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL if focused else UiTokens.TILE
		box.shadow_color = UiTokens.SHADOW_SELECTED if focused else UiTokens.SHADOW
		box.shadow_size = 22 if focused else 18
		box.shadow_offset = Vector2(0.0, 14.0)
		box.anti_aliasing = true
		_bg.add_theme_stylebox_override(&"panel", box)
		_rail.visible = not focused
		_name.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
		for label in [_meta, _from_label, _arrow, _ovr_caption, _date]:
			label.add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		_to_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if focused else UiTokens.INK)
		for label in [_fee, _ovr]:
			label.add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK if focused else UiTokens.INK)
		var status := str(_entry.get("status", ""))
		_status.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused
			else (WIN if status == "completed" else WARN))
		_photo.tone = UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2
		_photo.queue_redraw()


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				grab_focus()
				accept_event()


# Screen ---------------------------------------------------------------------

var career: Career
var catalog: TeamCatalog

var _all_rows: Array = []
var _rows: Array = []
var _row_nodes: Array[Row] = []
var _tabs_panel: Panel
var _tab_bar: UiTabBar
var _leagues: Dictionary = {}
var _filter_index := 0
var _focus_row := -1

var _head: Panel
var _head_labels: Array[Label] = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty: Panel
var _empty_title: Label
var _empty_text: Label
var _appear_tween: Tween
var _list_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	var nav := _ui_nav()
	if nav != null:
		nav.moved.connect(_on_nav_moved)
		nav.confirmed.connect(_on_nav_confirmed)
		nav.cancelled.connect(_on_nav_cancelled)
		nav.tab_previous.connect(_on_tab_previous)
		nav.tab_next.connect(_on_tab_next)
	call_deferred("_layout")


func open(next_career: Career, next_catalog: TeamCatalog, _payload := {}) -> void:
	career = next_career
	catalog = next_catalog
	_leagues.clear()
	_filter_index = 0
	_all_rows = []
	if career != null and catalog != null:
		var rows := CareerTransfers.history_rows(career, catalog)
		_all_rows = rows if rows is Array else []
	_refresh_tabs()
	_rebuild(false)
	if is_node_ready():
		_layout()
		_focus_tab(_filter_index)


func close() -> void:
	for tween in [_appear_tween, _list_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	release_focus()


func focus_initial() -> void:
	_focus_tab(_filter_index)


func is_overlay() -> bool:
	return true


func hints() -> Array:
	var gamepad: bool = false
	var nav := _ui_nav()
	if nav != null:
		gamepad = nav.using_gamepad()
	return [
		{"keys": ["D-PAD"] if gamepad else ["↑", "↓"], "label": "navigate"},
		{"keys": ["LB", "RB"] if gamepad else ["Q", "E"], "label": "filter"},
		{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
	]


# Test seams ----------------------------------------------------------------

func row_count() -> int:
	return _rows.size()


func visible_rows() -> Array:
	return _rows.duplicate()


func filter_id() -> String:
	return str(TABS[_filter_index]["id"])


func focused_row() -> int:
	return _focus_row


func is_empty_state() -> bool:
	return _empty.visible


# Layout helpers -------------------------------------------------------------


# Build ----------------------------------------------------------------------

func _build() -> void:
	_tabs_panel = Panel.new()
	_tabs_panel.name = "Tabs"
	# The strip is drawn by the shared TabBar; the panel is only the fade target.
	_tabs_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	add_child(_tabs_panel)
	# Same component as the hub's main tabs.
	_tab_bar = UiTabBar.new()
	_tab_bar.name = "TabBar"
	add_child(_tab_bar)
	var labels: Array[String] = []
	for data in TABS:
		labels.append(str(data["label"]))
	_tab_bar.setup(labels)
	_tab_bar.fit_width()
	_tab_bar.tab_selected.connect(_on_tab_selected)

	_head = Panel.new()
	_head.name = "Head"
	var head_box := StyleBoxFlat.new()
	head_box.bg_color = UiTokens.TILE
	head_box.border_color = Color(UiTokens.INK, 0.12)
	head_box.border_width_bottom = 1
	_head.add_theme_stylebox_override(&"panel", head_box)
	add_child(_head)
	for text in ["", "PLAYER", "CLUBS", "FEE", "OVR", "DATE / STATUS"]:
		var label := Label.new()
		label.text = text
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 14)
		label.add_theme_color_override(&"font_color", UiTokens.INK_2)
		_head.add_child(label)
		_head_labels.append(label)
	_head_labels[3].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_head_labels[4].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head_labels[5].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", int(ROW_GAP))
	_scroll.add_child(_list)

	_empty = Panel.new()
	_empty.name = "Empty"
	var empty_box := StyleBoxFlat.new()
	empty_box.bg_color = UiTokens.TILE
	empty_box.shadow_color = UiTokens.SHADOW
	empty_box.shadow_size = 22
	empty_box.shadow_offset = Vector2(0.0, 16.0)
	_empty.add_theme_stylebox_override(&"panel", empty_box)
	add_child(_empty)
	_empty_title = Label.new()
	_empty_title.text = "NO DEALS YET"
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_title.add_theme_font_override(&"font", UiTheme.barlow(800))
	_empty_title.add_theme_font_size_override(&"font_size", 34)
	_empty_title.add_theme_color_override(&"font_color", UiTokens.INK)
	_empty.add_child(_empty_title)
	_empty_text = Label.new()
	_empty_text.text = "Suitable moves will appear here once clubs start working the transfer market."
	_empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_text.add_theme_font_override(&"font", UiTheme.inter(500))
	_empty_text.add_theme_font_size_override(&"font_size", 15)
	_empty_text.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_empty.add_child(_empty_text)


func _layout() -> void:
	if _tabs_panel == null or size.x <= 0.0:
		return
	var width := size.x
	_tabs_panel.position = Vector2.ZERO
	_tabs_panel.size = Vector2(width, TABS_H)
	_layout_tabs()
	var head_y := TABS_H + GAP
	_head.position = Vector2(0.0, head_y)
	_head.size = Vector2(width, HEAD_H)
	var widths := Row.column_widths(width)
	var x := ROW_PAD_L
	for index in _head_labels.size():
		_head_labels[index].position = Vector2(x, 0.0)
		_head_labels[index].size = Vector2(widths[index], HEAD_H)
		x += widths[index] + COL_GAP
	var list_y := head_y + HEAD_H + ROW_GAP
	_scroll.position = Vector2(0.0, list_y)
	_scroll.size = Vector2(width, maxf(0.0, size.y - list_y))
	_empty.position = _scroll.position
	_empty.size = _scroll.size
	var pad_x := width * 0.5 - 260.0
	_empty_title.position = Vector2(pad_x, maxf(20.0, _empty.size.y * 0.5 - 50.0))
	_empty_title.size = Vector2(520.0, 40.0)
	_empty_text.position = _empty_title.position + Vector2(0.0, 44.0)
	_empty_text.size = Vector2(520.0, 60.0)


func _layout_tabs() -> void:
	if _tab_bar == null:
		return
	_tab_bar.position = Vector2.ZERO


func _refresh_tabs() -> void:
	if _tab_bar == null or _tab_bar.get_active_tab() == _filter_index:
		return
	_tab_bar.select_tab(_filter_index, false)


func _on_tab_selected(index: int) -> void:
	_focus_row = -1
	if index != _filter_index:
		_set_filter(index)


# Filtering -----------------------------------------------------------------

func _in_league(row: Dictionary, league_id: String) -> bool:
	if league_id.is_empty():
		return false
	for key in ["from_club_id", "to_club_id"]:
		var club_id := str(row.get(key, "")) if row.get(key) != null else ""
		if club_id.is_empty() or not club_id.is_valid_int():
			continue
		if not _leagues.has(club_id):
			var club := catalog.career_club(int(club_id))
			_leagues[club_id] = str(club.get("league_id", ""))
		if str(_leagues[club_id]) == league_id:
			return true
	return false


func _in_club(row: Dictionary, club_id: String) -> bool:
	for key in ["from_club_id", "to_club_id"]:
		if str(row.get(key, "")) == club_id:
			return true
	return false


func _filtered() -> Array:
	if career == null:
		return []
	var filter := str(TABS[_filter_index]["id"])
	if filter == "all":
		return _all_rows.duplicate()
	var result: Array = []
	for row in _all_rows:
		if not (row is Dictionary):
			continue
		if filter == "league" and _in_league(row, career.league_id):
			result.append(row)
		elif filter == "club" and _in_club(row, career.club_id):
			result.append(row)
	return result


func _rebuild(animate: bool) -> void:
	for node in _row_nodes:
		_list.remove_child(node)
		node.queue_free()
	_row_nodes.clear()
	_rows = _filtered()
	for row in _rows:
		var node := Row.new()
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.custom_minimum_size.y = ROW_H
		_list.add_child(node)
		node.setup(row, _crest(str(row.get("from_club_logo", ""))),
			_crest(str(row.get("to_club_logo", ""))))
		node.focus_entered.connect(_on_row_focused.bind(_row_nodes.size()))
		_row_nodes.append(node)
	_focus_row = -1
	_empty.visible = _rows.is_empty()
	_scroll.visible = not _rows.is_empty()
	if is_node_ready():
		_layout()
	if animate:
		_animate_list(1)


func _crest(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return UiAssets.usable_texture(UiAssets.load_texture_mipmapped(path.trim_prefix("/")))


func _set_filter(index: int) -> void:
	var next := posmod(index, TABS.size())
	if next == _filter_index:
		return
	_filter_index = next
	_refresh_tabs()
	_rebuild(true)
	_focus_tab(_filter_index)


func _cycle_filter(delta: int) -> void:
	_set_filter(_filter_index + delta)


# Focus ----------------------------------------------------------------------

func _focus_tab(index: int) -> void:
	_focus_row = -1
	if _tab_bar == null or _tab_bar.tab_count() == 0:
		return
	_tab_bar.focus_tab(clampi(index, 0, _tab_bar.tab_count() - 1))


func _focus_row_at(index: int) -> void:
	if index < 0 or index >= _row_nodes.size():
		return
	_focus_row = index
	_row_nodes[index].grab_focus()
	_scroll.ensure_control_visible(_row_nodes[index])


func _on_row_focused(index: int) -> void:
	_focus_row = index


# Input ----------------------------------------------------------------------

func _is_active() -> bool:
	var nav := _ui_nav()
	return is_visible_in_tree() and (nav == null or not nav.is_modal())


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_active():
		return
	if _focus_row < 0:
		if direction == Vector2i.LEFT:
			_cycle_filter(-1)
		elif direction == Vector2i.RIGHT:
			_cycle_filter(1)
		elif direction == Vector2i.DOWN:
			_focus_row_at(0)
		return
	if direction == Vector2i.UP:
		if _focus_row == 0:
			_focus_tab(_filter_index)
		else:
			_focus_row_at(_focus_row - 1)
	elif direction == Vector2i.DOWN:
		_focus_row_at(_focus_row + 1)


# Rows have no action in the prototype; confirm is a deliberate no-op.
func _on_nav_confirmed() -> void:
	pass


func _on_nav_cancelled() -> void:
	if not _is_active():
		return
	var nav := _ui_nav()
	if nav != null and bool(nav.event_was_modal()):
		return
	closed.emit()


func _on_tab_previous() -> void:
	if _is_active():
		_cycle_filter(-1)


func _on_tab_next() -> void:
	if _is_active():
		_cycle_filter(1)


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if _is_key(event, KEY_Q):
		get_viewport().set_input_as_handled()
		_cycle_filter(-1)
	elif _is_key(event, KEY_E):
		get_viewport().set_input_as_handled()
		_cycle_filter(1)


func _is_key(event: InputEvent, code: Key) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == code or key.physical_keycode == code)


# Motion ---------------------------------------------------------------------

func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _animate_list(direction: int) -> void:
	if _instant() or not is_inside_tree():
		return
	if _list_tween != null and _list_tween.is_valid():
		_list_tween.kill()
	_scroll.modulate.a = 0.0
	var target := _scroll.position
	_scroll.position = target + Vector2(20.0 * float(signi(direction)), 0.0)
	_list_tween = create_tween().set_parallel(true)
	_list_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_list_tween.tween_property(_scroll, "position", target, UiTokens.SCREEN_IN)
	_list_tween.tween_property(_scroll, "modulate:a", 1.0, UiTokens.SCREEN_OUT)


func _on_visibility_changed() -> void:
	if not visible or not is_inside_tree() or _tabs_panel == null or _instant():
		return
	var nodes: Array = [_tabs_panel, _head, _scroll, _empty]
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	if _list_tween != null and _list_tween.is_valid():
		_list_tween.kill()
	for node in nodes:
		(node as Control).modulate.a = 0.0
	_appear_tween = create_tween().set_parallel(true)
	for index in nodes.size():
		_appear_tween.tween_property(nodes[index], "modulate:a", 1.0,
			UiTokens.SCREEN_OUT).set_delay(0.02 * index)
