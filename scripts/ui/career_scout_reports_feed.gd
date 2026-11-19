class_name CareerScoutReportsFeed
extends Control
# Prototype career/scouting/ScoutReportsFeed.svelte: the REPORTS view — the
# report tabs, the two-column entry grid and the selected player's detail card
# on the right (the shared CareerPlayerPane, so the attributes/stats/photograph
# come from the same widget as the transfer screens).
#
# The host owns the filter and the selection; this screen reports them and
# re-renders from the entries it is given.

signal filter_selected(id: String)
signal entry_focused(player_id: String)
signal entry_activated(player_id: String)

const GAP := 10.0
const PAD := 14.0
const CARD_GAP := 8.0
const COLUMNS := 2

const EMPTY := {
	"requests": ["NO REQUESTED REPORTS YET",
		"Open a player card in the search and send a scout."],
	"all": ["YOUR SCOUTS HAVE NO RECOMMENDATIONS YET",
		"Set up a network in a country and they will start sending players."],
	"": ["NOBODY FOR THIS POSITION YET",
		"Change the filter or wait for the next scout reports."],
}

var _entries: Array = []
var _filters: Array = []
var _filter := "all"
var _selected_id := ""
var _date := ""
var _note_text := ""

var _left: Panel
var _tabs: UiTabBar
var _note: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
var _right: Control
var _detail_bg: Panel
var _pane: CareerPlayerPane
var _cards: Array[CareerPlayerCard] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	resized.connect(_layout)
	call_deferred("_layout")


# `filters`: [{id,label}]. `note` is the scout-filter caption ("" when none).
func setup(entries: Array, filters: Array, filter: String, note: String,
		date: String) -> void:
	_entries = entries
	_filters = filters
	_filter = filter
	_note_text = note
	_date = date
	if _grid == null:
		return
	_sync_tabs(filters)
	_note.text = note
	_note.visible = not note.is_empty()
	_rebuild_cards()
	_apply_selection()


func select(player_id: String) -> void:
	_selected_id = player_id
	_apply_selection()


func selected_id() -> String:
	return _selected_id


func entry_count() -> int:
	return _entries.size()


func tab_buttons() -> Array[Control]:
	var buttons: Array[Control] = []
	for index in _filters.size():
		var button := _tabs.get_tab_button(index)
		if button != null:
			buttons.append(button)
	return buttons


func entry_cards() -> Array[Control]:
	var cards: Array[Control] = []
	for card in _cards:
		cards.append(card)
	return cards


func active_tab() -> int:
	return _tabs.get_active_tab() if _tabs != null else 0


# Moves the tab strip without touching the entry list; the tab_selected signal
# carries the filter id back to the host, which rebuilds the feed.
func select_tab_index(index: int) -> void:
	if _tabs != null and _tabs.get_tab_button(0) != null:
		_tabs.select_tab(index)


func _build() -> void:
	_left = Panel.new()
	_left.name = "Feed"
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	_left.add_theme_stylebox_override(&"panel", box)
	add_child(_left)

	_tabs = UiTabBar.new()
	_tabs.name = "ReportTabs"
	_left.add_child(_tabs)
	_tabs.tab_selected.connect(_on_tab_selected)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.add_theme_font_override(&"font", UiTheme.inter(600))
	_note.add_theme_font_size_override(&"font_size", 15)
	_note.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_left.add_child(_note)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", int(CARD_GAP))
	_grid.add_theme_constant_override(&"v_separation", int(CARD_GAP))
	_scroll.add_child(_grid)

	_empty = Label.new()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_theme_font_override(&"font", UiTheme.inter(500))
	_empty.add_theme_font_size_override(&"font_size", 16)
	_empty.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_left.add_child(_empty)

	_right = Control.new()
	_right.name = "Detail"
	add_child(_right)
	_detail_bg = Panel.new()
	_detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail_box := StyleBoxFlat.new()
	detail_box.bg_color = UiTokens.TILE
	detail_box.shadow_color = UiTokens.SHADOW
	detail_box.shadow_size = 32
	detail_box.shadow_offset = Vector2(0.0, 24.0)
	_detail_bg.add_theme_stylebox_override(&"panel", detail_box)
	_right.add_child(_detail_bg)

	_pane = CareerPlayerPane.new()
	_pane.name = "Pane"
	_right.add_child(_pane)


func _sync_tabs(filters: Array) -> void:
	if _tabs.get_tab_button(0) == null:
		var labels: Array[String] = []
		for tab in filters:
			labels.append(str((tab as Dictionary).get("label", "")))
		_tabs.setup(labels)
	var index := _index_of_filter(filters)
	_tabs.select_tab(index, false)


func _index_of_filter(filters: Array) -> int:
	for index in filters.size():
		if str((filters[index] as Dictionary).get("id", "")) == _filter:
			return index
	return 0


func _rebuild_cards() -> void:
	for card in _cards:
		_grid.remove_child(card)
		card.queue_free()
	_cards.clear()
	for entry in _entries:
		if not (entry is Dictionary):
			continue
		# The same tile as the transfer search: one card component, two screens.
		var card := CareerPlayerCard.new()
		_grid.add_child(card)
		var player: Dictionary = entry.get("player", {}) if entry.get("player") is Dictionary \
			else {}
		# The rail marks an unread report; read entries lose it.
		card.setup(player, {"rail": not bool(entry.get("acknowledged", false))})
		# `pressed` carries the player id, so the handler takes it as well (a
		# no-argument lambda raised and swallowed every mouse click).
		card.pressed.connect(_activate_card)
		card.focus_entered.connect(_on_card_focused.bind(card))
		_cards.append(card)
	var empty := _entries.is_empty()
	_grid.visible = not empty
	_empty.visible = empty
	if empty:
		var copy: Array = EMPTY.get(_filter, EMPTY[""])
		_empty.text = "%s\n%s" % [copy[0], copy[1]]
	if _selected_id.is_empty() and not _cards.is_empty():
		_selected_id = _cards[0].player_id()


func _apply_selection() -> void:
	if _selected_id.is_empty() and not _cards.is_empty():
		_selected_id = _cards[0].player_id()
	for card in _cards:
		card.set_selected(card.player_id() == _selected_id)
	var entry := _entry_for(_selected_id)
	var player: Dictionary = entry.get("player", {}) if entry.get("player") is Dictionary \
		else {}
	var has_player := not player.is_empty()
	_pane.visible = has_player
	if not has_player:
		return
	_pane.setup(player, {"date": _date})


func _entry_for(player_id: String) -> Dictionary:
	for entry in _entries:
		if entry is Dictionary and str(
				(entry.get("player", {}) as Dictionary).get("player_id", "")) == player_id:
			return entry
	return {}


static func _date_label(iso: String) -> String:
	if iso.length() < 10:
		return iso
	return "%d %s %s" % [int(iso.substr(8, 2)), CareerHubModel.MONTHS[
		int(iso.substr(5, 2)) - 1], iso.substr(0, 4)]


func _on_tab_selected(index: int) -> void:
	if index < 0 or index >= _filters.size():
		return
	filter_selected.emit(str((_filters[index] as Dictionary).get("id", "")))


func _activate_card(player_id: String) -> void:
	entry_activated.emit(player_id)


# The ScrollContainer does not follow keyboard focus by itself, so the card that
# takes focus is scrolled into view (same as the transfer results grid).
func _on_card_focused(card: Control) -> void:
	_scroll.ensure_control_visible.call_deferred(card)
	entry_focused.emit((card as CareerPlayerCard).player_id())


func _layout() -> void:
	if _left == null or size.x <= 0.0:
		return
	var left_w := floorf((size.x - GAP) * 1.02 / 2.0)
	var right_w := maxf(0.0, size.x - left_w - GAP)
	_left.position = Vector2.ZERO
	_left.size = Vector2(left_w, size.y)
	_right.position = Vector2(left_w + GAP, 0.0)
	_right.size = Vector2(right_w, size.y)

	var inner := maxf(0.0, left_w - PAD * 2.0)
	_tabs.position = Vector2(PAD, 10.0)
	_tabs.fit_width()
	_note.position = Vector2(PAD + _tabs.size.x + 10.0, 10.0)
	_note.size = Vector2(maxf(0.0, inner - _tabs.size.x - 10.0), UiTokens.TAB_H)
	var list_top := 10.0 + UiTokens.TAB_H + 8.0
	_scroll.position = Vector2(PAD, list_top)
	_scroll.size = Vector2(inner, maxf(0.0, size.y - list_top - PAD))
	var card_w := floorf((_scroll.size.x - float(COLUMNS - 1) * CARD_GAP
		- 8.0) / float(COLUMNS))
	for card in _cards:
		card.custom_minimum_size.x = card_w
	_empty.position = Vector2(PAD, list_top + 8.0)
	_empty.size = Vector2(inner, 90.0)

	_detail_bg.position = Vector2.ZERO
	_detail_bg.size = Vector2(right_w, size.y)
	_pane.position = Vector2.ZERO
	_pane.size = Vector2(right_w, size.y)
	_pane.custom_minimum_size.x = right_w
