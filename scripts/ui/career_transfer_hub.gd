class_name CareerTransferHub
extends Control
# Prototype transfers/TransferHub.svelte: the TRANSFERS landing. The scouting
# reports card fills two of four columns and both rows; the four hub cards sit
# in the remaining 2×2 grid. Feed and counts come from
# CareerScouting.snapshot: eight report tiles per page (the shared player card),
# free-slot placeholders,
# Left/Right paging while the card owns focus, confirm opens the reports centre.
#
# The host owns routing/animation (CareerTransfersView) and draws the hints bar
# from hints(); this screen only reports navigate/closed/tab_requested.

signal navigate(view: String, payload: Dictionary)
signal closed
signal tab_requested(delta: int)
# A push at the edge of the card grid: the host switches section or hands
# focus back to the main tab strip (same as the Centre dashboard).
signal edge_requested(direction: Vector2i)

const PAGE := 8
const GAP := 10.0
const PAD := 18.0
const FocusGrid := preload("res://scripts/ui/ui_focus_grid.gd")
const HEAD_H := 75.0
const FOOT_H := 34.0
const FEED_GAP := 6.0
const PAGER_W := 34.0

# transferHubCards from the prototype, translated. Payloads feed the host.
const CARDS := [
	{"id": "search", "label": "SEARCH PLAYERS",
		"note": "Find a specific player to buy, loan or study.",
		"icon": "tactics", "view": "filters", "payload": {}},
	{"id": "centre", "label": "TRANSFER CENTRE",
		"note": "Shortlist, offers and negotiations",
		"icon": "shirt", "view": "centre", "payload": {}},
	{"id": "network", "label": "WORLD NETWORK",
		"note": "Scouts, assignments and reports across the world",
		"icon": "globe", "view": "network", "payload": {"mode": "scouts"}},
	{"id": "history", "label": "HISTORY",
		"note": "Every deal, offer and move",
		"icon": "layers", "view": "history", "payload": {}},
]


# One free report slot: the shirt glyph and the "FREE SLOT" caption. Taken slots
# are the shared CareerPlayerCard, the same tile as the search and the reports
# feed.
class EmptySlot extends Control:
	var _bg: Panel
	var _icon: TextureRect
	var _label: Label


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_icon = TextureRect.new()
		_icon.texture = UiIcon.texture("shirt")
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.text = "FREE SLOT"
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.clip_text = true
		_label.add_theme_font_override(&"font", UiTheme.inter(500))
		_label.add_theme_font_size_override(&"font_size", 15)
		add_child(_label)
		resized.connect(_layout)
		set_inverted(false)


	func set_inverted(focused: bool) -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.FOCUS_INK, 0.08) if focused \
			else Color(UiTokens.INK, 0.06)
		box.anti_aliasing = true
		_bg.add_theme_stylebox_override(&"panel", box)
		_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		_icon.modulate = UiTokens.FOCUS_INK_2 if focused \
			else Color(UiTokens.INK_2, 0.5)


	func _layout() -> void:
		if _bg == null or size.x <= 0.0:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		var icon := 28.0
		var text_w := _label.get_theme_font(&"font").get_string_size(
			_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var pair_w := icon + 8.0 + text_w
		var pair_x := maxf(6.0, (size.x - pair_w) * 0.5)
		_icon.position = Vector2(pair_x, (size.y - icon) * 0.5)
		_icon.size = Vector2(icon, icon)
		_label.position = Vector2(pair_x + icon + 8.0, 0.0)
		_label.size = Vector2(text_w, size.y)


# The scouting reports card: header (kicker, title, NEW/UPDATES counts), eight
# feed tiles and the pager footer. Focusable as one control, like the prototype.
class ReportsCard extends Control:
	signal activated
	signal pager_requested(delta: int)

	var _bg: Panel
	var _rail: ColorRect
	var _kicker: Label
	var _title: Label
	var _count_values: Array[Label] = []
	var _count_labels: Array[Label] = []
	var _divider: ColorRect
	var _slots: Array[Control] = []
	var _foot: Label
	var _prev: Label
	var _next: Label
	var _pager_rects: Array[Rect2] = []
	var _normal_box: StyleBoxFlat
	var _focus_box: StyleBoxFlat


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
		_kicker = _label(UiTheme.inter(600), 16, UiTokens.INK_2)
		_kicker.text = "SCOUTING"
		_title = _label(UiTheme.barlow(800), 46, UiTokens.INK)
		_title.text = "SCOUT REPORTS"
		_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for index in 2:
			var value := _label(UiTheme.barlow(700), 24, UiTokens.RAIL)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var caption := _label(UiTheme.inter(600), 15, UiTokens.INK_2)
			caption.text = "NEW" if index == 0 else "UPDATES"
			_count_values.append(value)
			_count_labels.append(caption)
		_divider = ColorRect.new()
		_divider.color = Color(UiTokens.INK, 0.12)
		_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_divider)
		_foot = _label(UiTheme.inter(500), 15, UiTokens.INK_2)
		_prev = _pager_label("‹")
		_next = _pager_label("›")
		_normal_box = _make_box(UiTokens.TILE)
		_focus_box = _make_box(UiTokens.FOCUS_FILL)
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


	func _pager_label(text: String) -> Label:
		var label := _label(UiTheme.barlow(700), 20, UiTokens.INK)
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return label


	func _make_box(fill: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.shadow_color = UiTokens.SHADOW
		box.shadow_size = 32
		box.shadow_offset = Vector2(0.0, 24.0)
		box.anti_aliasing = true
		return box


	func setup(counts: Dictionary, entries: Array, page: int, pages: int) -> void:
		_count_values[0].text = str(int(counts.get("new", 0)))
		_count_values[1].text = str(int(counts.get("updates", 0)))
		# Report tiles are the shared player card; a slot without a report keeps
		# the "FREE SLOT" placeholder.
		for slot in _slots:
			remove_child(slot)
			slot.queue_free()
		_slots.clear()
		for index in PAGE:
			var slot: Control = null
			if index < entries.size():
				var entry: Dictionary = entries[index]
				var player: Dictionary = entry.get("player", {}) \
					if entry.get("player") is Dictionary else {}
				var card := CareerPlayerCard.new()
				# The host owns focus and sizes the tiles; the card only paints.
				# Set after add_child: the card's _ready resets both.
				card.custom_minimum_size.y = 1.0
				add_child(card)
				card.focus_mode = Control.FOCUS_NONE
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.setup(player, {"rail": not bool(entry.get("acknowledged", false))})
				slot = card
			else:
				slot = EmptySlot.new()
				add_child(slot)
			_slots.append(slot)
		if entries.is_empty():
			_foot.text = "No scout reports yet. Send a scout from player search."
		else:
			_foot.text = "%d / %d" % [page + 1, pages]
		_prev.visible = pages > 1
		_next.visible = pages > 1
		_layout()
		_apply_state()


	func _layout() -> void:
		if _bg == null or size.x <= 0.0:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		_rail.visible = not has_focus()
		var inner := size.x - PAD * 2.0
		var counts_w := 150.0
		_kicker.position = Vector2(PAD, PAD)
		_kicker.size = Vector2(maxf(0.0, inner - counts_w), 20.0)
		_title.position = Vector2(PAD, PAD + 21.0)
		_title.size = Vector2(maxf(0.0, inner - counts_w), 44.0)
		var block_x := size.x - PAD - counts_w
		for index in _count_values.size():
			var y := PAD + float(index) * 26.0
			_count_values[index].position = Vector2(block_x, y)
			_count_values[index].size = Vector2(34.0, 24.0)
			_count_labels[index].position = Vector2(block_x + 38.0, y + 5.0)
			_count_labels[index].size = Vector2(counts_w - 38.0, 20.0)
		_divider.position = Vector2(PAD, PAD + HEAD_H - 1.0)
		_divider.size = Vector2(inner, 1.0)

		var feed_top := PAD + HEAD_H + 12.0
		var foot_top := size.y - PAD - FOOT_H
		var feed_h := maxf(0.0, foot_top - 12.0 - feed_top)
		var slot_w := (inner - FEED_GAP) * 0.5
		# Four rows of two: the compact player cards fit eight reports a page.
		var slot_h := (feed_h - FEED_GAP * 3.0) / 4.0
		for index in _slots.size():
			var column := index % 2
			var row := index / 2
			var slot := _slots[index]
			slot.position = Vector2(PAD + float(column) * (slot_w + FEED_GAP),
				feed_top + float(row) * (slot_h + FEED_GAP))
			slot.size = Vector2(slot_w, slot_h)

		_foot.position = Vector2(PAD, foot_top + (FOOT_H - 20.0) * 0.5)
		_foot.size = Vector2(maxf(0.0, inner - 90.0), 20.0)
		var next_rect := Rect2(size.x - PAD - PAGER_W,
			foot_top + (FOOT_H - PAGER_W) * 0.5, PAGER_W, PAGER_W)
		var prev_rect := Rect2(next_rect.position.x - 6.0 - PAGER_W,
			next_rect.position.y, PAGER_W, PAGER_W)
		_prev.position = prev_rect.position
		_prev.size = prev_rect.size
		_next.position = next_rect.position
		_next.size = next_rect.size
		_pager_rects = [prev_rect, next_rect]


	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus_box if focused else _normal_box)
		_rail.visible = not focused
		_kicker.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		_title.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
		_foot.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		for index in _count_values.size():
			_count_values[index].add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK if focused else UiTokens.RAIL)
			_count_labels[index].add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		_prev.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if focused else UiTokens.INK)
		_next.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if focused else UiTokens.INK)
		for slot in _slots:
			slot.call("set_inverted", focused)


	func play_page_shift(direction: int) -> void:
		var transition := get_node_or_null("/root/UiTransition")
		if transition != null and bool(transition.get("instant")):
			return
		var shift := 24.0 * float(signi(direction))
		for index in _slots.size():
			var slot := _slots[index]
			var target := slot.position
			slot.position = target + Vector2(shift, 0.0)
			slot.modulate.a = 0.0
			var tween := create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(slot, "position", target, 0.24).set_delay(0.015 * index)
			tween.tween_property(slot, "modulate:a", 1.0, 0.15).set_delay(0.015 * index)


	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		grab_focus()
		var point := mouse.position
		for index in _pager_rects.size():
			if _pager_rects[index].has_point(point):
				pager_requested.emit(-1 if index == 0 else 1)
				accept_event()
				return
		activated.emit()
		accept_event()


# One of the four hub cards: status line, uppercase title, note and a corner
# glyph; focus inverts the tile like BentoTile/CareerRow.
class Card extends Control:
	signal activated

	var _data: Dictionary
	var _bg: Panel
	var _rail: ColorRect
	var _status: Label
	var _title: Label
	var _note: Label
	var _icon: TextureRect
	var _normal_box: StyleBoxFlat
	var _focus_box: StyleBoxFlat


	func _init(data: Dictionary) -> void:
		_data = data
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_rail = ColorRect.new()
		_rail.color = UiTokens.RAIL
		_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rail)
		_status = _label(UiTheme.inter(600), 15, UiTokens.INK_2)
		_status.text = "OPEN"
		_title = _label(UiTheme.barlow(700), 36, UiTokens.INK)
		_title.text = str(data.get("label", ""))
		_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if str(data.get("id", "")) == "search":
			_title.add_theme_font_size_override(&"font_size", 38)
		_note = _label(UiTheme.inter(500), 15, UiTokens.INK_2)
		_note.text = str(data.get("note", ""))
		_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_icon = TextureRect.new()
		_icon.texture = UiIcon.texture(str(data.get("icon", "")))
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.modulate = Color(UiTokens.INK_2, 0.4)
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		_normal_box = _make_box(UiTokens.TILE)
		_focus_box = _make_box(UiTokens.FOCUS_FILL)
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


	func _make_box(fill: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.shadow_color = UiTokens.SHADOW
		box.shadow_size = 28
		box.shadow_offset = Vector2(0.0, 20.0)
		box.anti_aliasing = true
		return box


	func view() -> String:
		return str(_data.get("view", ""))


	func payload() -> Dictionary:
		var value = _data.get("payload", {})
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}


	func _layout() -> void:
		if _bg == null or size.x <= 0.0:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		var inner := size.x - PAD * 2.0
		_status.position = Vector2(PAD, PAD)
		_status.size = Vector2(inner, 20.0)
		_title.position = Vector2(PAD, PAD + 24.0)
		_title.size = Vector2(maxf(0.0, inner * 0.86), 76.0)
		_note.position = Vector2(PAD, PAD + 24.0 + 76.0 + 8.0)
		_note.size = Vector2(maxf(0.0, inner), maxf(20.0, size.y - PAD * 2.0 - 104.0))
		_icon.position = Vector2(size.x - PAD - 56.0, size.y - PAD - 56.0)
		_icon.size = Vector2(56.0, 56.0)


	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus_box if focused else _normal_box)
		_rail.visible = not focused
		_status.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		_title.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
		_note.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		_icon.modulate = (UiTokens.FOCUS_INK if focused
			else Color(UiTokens.INK_2, 0.4))


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				grab_focus()
				activated.emit()
				accept_event()


# Screen ---------------------------------------------------------------------

var career: Career
var catalog: TeamCatalog

var _feed: Array = []
var _counts: Dictionary = {}
var _page := 0
var _focus := 0
var _reports: ReportsCard
var _cards: Array[Card] = []
var _appear_tween: Tween
# The career hub's tab strip owns UiNav while it is focused; the landing must
# not react to those moves. Leaving that state is deferred: the same event that
# hands focus to the page (Down/Enter) must not also walk or activate a card.
var _shell_focused := false
var _skip_event := false


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
	_feed = []
	_counts = {}
	if career != null and catalog != null:
		CareerScouting.ensure_scouts(career)
		var block := CareerScouting.snapshot(career, catalog)
		_feed = block.get("feed", []) if block.get("feed") is Array else []
		_counts = block.get("counts", {}) if block.get("counts") is Dictionary else {}
	_page = clampi(_page, 0, page_count() - 1)
	if is_node_ready():
		_refresh()
		_call_layout()


func close() -> void:
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	release_focus()


func focus_initial() -> void:
	focus_index(0)


func is_overlay() -> bool:
	return false


func hints() -> Array:
	var gamepad: bool = false
	var nav := _ui_nav()
	if nav != null:
		gamepad = nav.using_gamepad()
	var first := {"keys": ["D-PAD"] if gamepad else ["↑", "↓", "←", "→"], "label": "navigate"}
	return [
		first,
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
		{"keys": ["LB", "RB"] if gamepad else ["Q", "E"], "label": "tabs"},
		{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
	]


# Test seam + navigation target: focus the reports card (0) or a hub card (1..4).
func focus_index(index: int) -> void:
	_focus = clampi(index, 0, _cards.size())
	if index <= 0:
		if _reports != null:
			_reports.grab_focus()
		return
	_cards[_focus - 1].grab_focus()


func activate_focused() -> void:
	if _focus <= 0:
		_open_reports()
	elif _focus - 1 < _cards.size():
		var card := _cards[_focus - 1]
		navigate.emit(card.view(), card.payload())


func card_count() -> int:
	return _cards.size()


func feed_page() -> Array:
	var start := _page * PAGE
	return _feed.slice(start, mini(start + PAGE, _feed.size()))


func page() -> int:
	return _page


func page_count() -> int:
	return maxi(1, int(ceil(float(_feed.size()) / float(PAGE))))


func focused_index() -> int:
	return _focus


# Build ----------------------------------------------------------------------

func _build() -> void:
	_reports = ReportsCard.new()
	_reports.name = "Reports"
	_reports.activated.connect(_open_reports)
	_reports.pager_requested.connect(_shift_page)
	_reports.focus_entered.connect(_on_focus.bind(0))
	add_child(_reports)
	for index in CARDS.size():
		var card := Card.new(CARDS[index])
		card.name = "Card_%s" % str(CARDS[index]["id"])
		card.activated.connect(_on_card_activated.bind(index))
		card.focus_entered.connect(_on_focus.bind(index + 1))
		add_child(card)
		_cards.append(card)


func _layout() -> void:
	if _reports == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var cell_w := (size.x - GAP * 3.0) / 4.0
	var cell_h := (size.y - GAP) * 0.5
	_reports.position = Vector2.ZERO
	_reports.size = Vector2(cell_w * 2.0 + GAP, size.y)
	for index in _cards.size():
		var column := 2 + index % 2
		var row := index / 2
		var card := _cards[index]
		card.position = Vector2(float(column) * (cell_w + GAP),
			float(row) * (cell_h + GAP))
		card.size = Vector2(cell_w, cell_h)


func _call_layout() -> void:
	if is_inside_tree():
		_layout()


func _refresh() -> void:
	_page = clampi(_page, 0, page_count() - 1)
	_reports.setup(_counts, feed_page(), _page, page_count())
	_layout()


func _shift_page(delta: int) -> void:
	if page_count() <= 1:
		return
	_page = posmod(_page + delta, page_count())
	_reports.setup(_counts, feed_page(), _page, page_count())
	_reports.play_page_shift(delta)


func _open_reports() -> void:
	var entries := feed_page()
	var player_id := ""
	if not entries.is_empty():
		var player: Dictionary = entries[0].get("player", {}) \
			if entries[0].get("player") is Dictionary else {}
		player_id = str(player.get("player_id", ""))
	navigate.emit("network", {"mode": "reports", "player_id": player_id})


func _on_card_activated(index: int) -> void:
	var card := _cards[index]
	navigate.emit(card.view(), card.payload())


func _on_focus(index: int) -> void:
	_focus = index


# Input ----------------------------------------------------------------------

func _is_active() -> bool:
	if _shell_focused:
		return false
	var nav := _ui_nav()
	return is_visible_in_tree() and (nav == null or not nav.is_modal())


func set_shell_focused(value: bool) -> void:
	if value:
		_shell_focused = true
		return
	set_deferred("_shell_focused", false)


# The move/tab event that brings this screen on screen is not a navigation
# intent: drop it once so the entry stops on its first card.
func suppress_event() -> void:
	_skip_event = true


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _on_nav_moved(direction: Vector2i) -> void:
	if _skip_event:
		_skip_event = false
		return
	if not _is_active():
		return
	var tiles: Array[Control] = [_reports]
	tiles.append_array(_cards)
	var rects: Array[Rect2] = []
	for tile in tiles:
		rects.append(tile.get_global_rect())
	var current := tiles[clampi(_focus, 0, tiles.size() - 1)].get_global_rect()
	# 4 px covers the focus styling; tiles at the top edge are the top row, so
	# Up leaves for the main tab strip instead of hopping into a neighbour.
	var index := FocusGrid.neighbour(rects, current, direction, 4.0)
	if index >= 0:
		focus_index(index)
		return
	if direction == Vector2i.LEFT or direction == Vector2i.UP \
			or direction == Vector2i.RIGHT:
		edge_requested.emit(direction)


func _on_nav_confirmed() -> void:
	if not _is_active():
		return
	activate_focused()


func _on_nav_cancelled() -> void:
	if not _is_active():
		return
	var nav := _ui_nav()
	if nav != null and bool(nav.event_was_modal()):
		return
	closed.emit()


func _on_tab_previous() -> void:
	if _skip_event:
		_skip_event = false
		return
	if not _is_active():
		return
	tab_requested.emit(-1)


func _on_tab_next() -> void:
	if _skip_event:
		_skip_event = false
		return
	if not _is_active():
		return
	tab_requested.emit(1)


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if _is_key(event, KEY_Q):
		get_viewport().set_input_as_handled()
		tab_requested.emit(-1)
	elif _is_key(event, KEY_E):
		get_viewport().set_input_as_handled()
		tab_requested.emit(1)


func _is_key(event: InputEvent, code: Key) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == code or key.physical_keycode == code)


# Motion ---------------------------------------------------------------------

func _on_visibility_changed() -> void:
	if not visible or not is_inside_tree() or _reports == null:
		return
	var owner := get_viewport().gui_get_focus_owner()
	# Only restore focus when nothing owns it (a return from a subview). While
	# the shell's main tab strip is focused, the hub must leave it there: the
	# windowed show is animated, so this hook lands after the hub set the tabs.
	if owner == null:
		focus_index(_focus)
	var transition := get_node_or_null("/root/UiTransition")
	if transition != null and bool(transition.get("instant")):
		return
	var nodes: Array = [_reports]
	nodes.append_array(_cards)
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	for node in nodes:
		(node as Control).modulate.a = 0.0
	_appear_tween = create_tween().set_parallel(true)
	for index in nodes.size():
		_appear_tween.tween_property(nodes[index], "modulate:a", 1.0, 0.15) \
			.set_delay(0.02 * index)
