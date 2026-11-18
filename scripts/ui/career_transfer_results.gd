class_name CareerTransferResults
extends Control
# Prototype transfers/TransferResults.svelte (the body of TransferPlayers.svelte):
# the transfer-search results. A scrollable two-column card grid on the left with
# the title, the match total and the date above it, and the shared
# CareerPlayerPane for the selected player on the right. The pane follows the
# focused card, confirm (or a click) opens the CareerPlayerActions modal over the
# screen, and Back closes the screen. Pages are 40 players; the next page loads
# when focus reaches the last five cards (mouse hover grabs focus, so the wheel
# path is covered too).
#
# The host owns routing and animation: this screen only reports `navigate`
# ("offer" / "contract"), `changed` (career mutated → save) and
# `scout_requested`, and the host draws the hints bar from hints().

signal closed
signal navigate(view: String, payload: Dictionary)
signal changed
signal scout_requested(player_id: String, scout_id: String)
# Hints changed (a modal opened/closed): the host redraws its hints bar.
signal state_changed

const PAGE := 40
const GAP := 10.0
const PAD := 16.0
const HEAD_H := 48.0
const CARD_H := 112.0
const CARD_GAP := 8.0
const COLUMNS := 2
const LOAD_AHEAD := 5

var career: Career
var catalog: TeamCatalog

var _filters: Dictionary = {}
var _scouts: Array = []
var _items: Array = []
var _cards: Array[CareerPlayerCard] = []
var _total := 0
var _has_more := false
var _selected_id := ""
var _focus := -1
var _focus_pending := false
var _loading := false
var _error := ""
# The card handed over to an offer / contract screen and must come back.
var _resume_actions := false

var _left: Panel
var _title: Label
var _meta: Label
var _divider: ColorRect
var _scroll: ScrollContainer
var _grid: GridContainer
var _note: Label
var _right: Control
var _pane: CareerPlayerPane
var _empty: PanelContainer
var _actions: CareerPlayerActions


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Listen before the actions modal exists: when it closes on the same signal
	# this screen must already have seen the modal and stood down.
	_connect_nav()
	_build()
	resized.connect(_layout)
	call_deferred("_layout")


# `payload`: {filters: Dictionary, scouts: Array}. `scouts` are the free scouts
# of the world network (empty until that screen lands) and may carry the report
# they are working on: {id, name, flag, experience, judgement, report}.
func setup(next_career: Career, next_catalog: TeamCatalog, payload := {}) -> void:
	career = next_career
	catalog = next_catalog
	# Back from the offer / contract screen: the list and the player card are
	# still valid, so give the card its input back instead of re-running the
	# search under the player's feet.
	if bool(payload.get("resume", false)) and _actions != null and _actions.resume():
		return
	var filters = payload.get("filters", null)
	_filters = (filters as Dictionary).duplicate(true) if filters is Dictionary \
		and not (filters as Dictionary).is_empty() else CareerSearch.filters_default()
	_scouts = []
	if payload.has("scouts") and payload.get("scouts") is Array:
		_scouts = _flagged_scouts(payload.get("scouts"))
	elif career != null:
		# No scouting screen yet: use whoever the scouting module has free.
		_scouts = _flagged_scouts(CareerScouting.assignable_scouts(career))
	if not is_node_ready():
		return
	# The list must take the keyboard as soon as it appears: the host shows this
	# screen without calling focus_initial().
	_focus_pending = true
	_reset()
	_start_search()


func filters() -> Dictionary:
	return _filters.duplicate(true)


# The host closes the view: drop any modal still owning input above it.
func close() -> void:
	if _actions == null:
		return
	# An offer / contract screen is coming over this one: hide the card but keep
	# it, so the manager lands back on the player after sending the offer.
	if _resume_actions:
		_resume_actions = false
		_actions.suspend()
		return
	_actions.close()


func hints() -> Array:
	var gamepad := false
	var nav := _ui_nav()
	if nav != null:
		gamepad = nav.using_gamepad()
	var select := ["A"] if gamepad else ["ENTER"]
	var back := ["B"] if gamepad else ["ESC"]
	if _actions != null and _actions.is_open():
		return [
			{"keys": select, "label": "select"},
			{"keys": back, "label": "back"},
		]
	return [
		{"keys": ["D-PAD"] if gamepad else ["↑", "↓", "←", "→"], "label": "players"},
		{"keys": select, "label": "actions"},
		{"keys": back, "label": "back"},
	]


func focus_initial() -> void:
	_focus_pending = true
	_focus_first()


func selected_id() -> String:
	return _selected_id


func total() -> int:
	return _total


func item_count() -> int:
	return _items.size()


# Build ----------------------------------------------------------------------

func _build() -> void:
	_left = Panel.new()
	_left.name = "Results"
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	_left.add_theme_stylebox_override(&"panel", box)
	add_child(_left)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "SEARCH RESULTS"
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_override(&"font", UiTheme.barlow(700))
	_title.add_theme_font_size_override(&"font_size", 30)
	_title.add_theme_color_override(&"font_color", UiTokens.INK)
	_left.add_child(_title)

	_meta = Label.new()
	_meta.name = "Meta"
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meta.add_theme_font_override(&"font", UiTheme.inter(600))
	_meta.add_theme_font_size_override(&"font_size", 16)
	_meta.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_left.add_child(_meta)

	_divider = ColorRect.new()
	_divider.color = Color(UiTokens.INK, 0.12)
	_left.add_child(_divider)

	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", int(CARD_GAP))
	_grid.add_theme_constant_override(&"v_separation", int(CARD_GAP))
	_scroll.add_child(_grid)

	_note = Label.new()
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_theme_font_override(&"font", UiTheme.inter(500))
	_note.add_theme_font_size_override(&"font_size", 16)
	_note.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_note.visible = false
	_left.add_child(_note)

	_right = Control.new()
	_right.name = "Detail"
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right)
	_pane = CareerPlayerPane.new()
	_pane.name = "Pane"
	_pane.visible = false
	_right.add_child(_pane)
	_empty = PanelContainer.new()
	_empty.name = "Empty"
	_empty.custom_minimum_size.y = 120.0
	_empty.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var empty_box := StyleBoxFlat.new()
	empty_box.bg_color = UiTokens.TILE
	empty_box.content_margin_left = PAD
	empty_box.content_margin_right = PAD
	empty_box.content_margin_top = PAD
	empty_box.content_margin_bottom = PAD
	_empty.add_theme_stylebox_override(&"panel", empty_box)
	_right.add_child(_empty)
	var empty_label := Label.new()
	empty_label.text = "Pick a player from the list."
	empty_label.add_theme_font_override(&"font", UiTheme.inter(500))
	empty_label.add_theme_font_size_override(&"font_size", 16)
	empty_label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_empty.add_child(empty_label)

	_actions = CareerPlayerActions.new()
	_actions.name = "PlayerActions"
	_actions.navigate.connect(_on_actions_navigate)
	_actions.changed.connect(_on_actions_changed)
	_actions.scout_requested.connect(_on_scout_requested)
	_actions.closed.connect(_on_actions_closed)
	add_child(_actions)


func _layout() -> void:
	if _left == null or size.x <= 0.0:
		return
	var left_w := floorf((size.x - GAP) * 1.1 / 2.0)
	_left.position = Vector2.ZERO
	_left.size = Vector2(left_w, size.y)
	_right.position = Vector2(left_w + GAP, 0.0)
	_right.size = Vector2(maxf(0.0, size.x - left_w - GAP), size.y)

	var inner_w := maxf(0.0, left_w - PAD * 2.0)
	_title.position = Vector2(PAD, 10.0)
	_title.size = Vector2(inner_w, 32.0)
	_meta.position = Vector2(PAD, 12.0)
	_meta.size = Vector2(inner_w, 24.0)
	_divider.position = Vector2(PAD, HEAD_H)
	_divider.size = Vector2(inner_w, 1.0)
	var list_top := HEAD_H + 10.0
	_scroll.position = Vector2(PAD, list_top)
	_scroll.size = Vector2(inner_w, maxf(0.0, size.y - list_top - PAD))
	_note.position = _scroll.position + Vector2(0.0, 24.0)
	_note.size = Vector2(_scroll.size.x, 60.0)
	_pane.position = Vector2.ZERO
	_pane.size = _right.size
	_empty.position = Vector2.ZERO
	_empty.size = Vector2(_right.size.x,
		maxf(120.0, _empty.get_combined_minimum_size().y))


# Search ---------------------------------------------------------------------

func _reset() -> void:
	_items.clear()
	_cards.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_selected_id = ""
	_focus = -1
	_total = 0
	_has_more = false
	_error = ""
	_loading = false
	_pane.visible = false
	_empty.visible = false
	_set_note("SEARCHINGвЂ¦")


func _start_search() -> void:
	_loading = true
	_set_note("SEARCHING…")
	call_deferred("_run_search")


func _run_search() -> void:
	# One frame first so the note above is painted: the query below runs on this
	# thread. It goes through native SQLite and needs no preloaded player index.
	await get_tree().process_frame
	if not _loading or not is_inside_tree():
		return
	_load_first()


func _load_first() -> void:
	# The host may have closed the screen while the deferred call was queued.
	if not _loading or not is_inside_tree():
		return
	_loading = false
	_search_page(0)
	_after_load()


func _load_more() -> void:
	if _loading or not _has_more:
		return
	_loading = true
	_search_page(_items.size())
	_loading = false
	_after_load()


func _search_page(offset: int) -> void:
	var page := CareerSearch.search(catalog, career, _filters, PAGE, offset)
	_error = str(CareerSearch.last_error)
	if not _error.is_empty():
		return
	_total = int(page.get("total", 0))
	_has_more = bool(page.get("has_more", false))
	var items: Array = page.get("items", [])
	_items.append_array(items)
	_build_cards(items)


func _build_cards(items: Array) -> void:
	var first := _cards.size()
	for item in items:
		var card := CareerPlayerCard.new()
		card.custom_minimum_size.y = CARD_H
		_grid.add_child(card)
		card.setup(item)
		card.pressed.connect(_on_card_pressed)
		card.focus_entered.connect(_on_card_focused.bind(card))
		_cards.append(card)
	if first < _cards.size():
		_apply_selection()


func _after_load() -> void:
	_grid.visible = not _items.is_empty()
	if not _error.is_empty():
		_set_note(_error)
		return
	if _items.is_empty():
		_set_note("Nobody found вЂ” loosen the filters.")
		_pane.visible = false
		_empty.visible = false
		_update_meta()
		return
	_set_note("")
	if _selected_id.is_empty():
		_selected_id = _item_id(_items[0])
	_apply_selection()
	_show_player()
	_update_meta()
	if _focus_pending and _focus < 0:
		_focus_first()


func _update_meta() -> void:
	if _meta == null:
		return
	var parts: Array[String] = [_grouped(_total)]
	if career != null and not career.date.is_empty():
		parts.append(CareerHubModel.month_label(career.date))
	_meta.text = " · ".join(parts)


func _set_note(text: String) -> void:
	if _note == null:
		return
	_note.text = text
	_note.visible = not text.is_empty()
	_note.add_theme_color_override(&"font_color",
		UiTokens.INK_2 if _error.is_empty() else Color("b23a48"))


static func _grouped(value: int) -> String:
	# 121927 -> 121,927 (prototype total.toLocaleString('en-US')).
	var text := str(value)
	var grouped := ""
	var count := 0
	for index in range(text.length() - 1, -1, -1):
		grouped = text[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = "," + grouped
	return grouped


# Selection ------------------------------------------------------------------

func _item_id(item: Dictionary) -> String:
	return str(item.get("player_id", item.get("id", "")))


func _index_of(player_id: String) -> int:
	for index in _items.size():
		if _item_id(_items[index]) == player_id:
			return index
	return -1


func _item_for(player_id: String) -> Dictionary:
	var index := _index_of(player_id)
	return _items[index] if index >= 0 else {}


func _select(player_id: String) -> void:
	if player_id.is_empty():
		return
	_selected_id = player_id
	_apply_selection()
	_show_player()


func _apply_selection() -> void:
	for card in _cards:
		card.set_selected(card.player_id() == _selected_id)


func _show_player() -> void:
	var player := _item_for(_selected_id)
	if player.is_empty():
		_pane.visible = false
		_empty.visible = true
		return
	_empty.visible = false
	_pane.visible = true
	_pane.setup(player, {"date": career.date if career != null else ""})


func _focus_card(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_focus = index
	_cards[index].grab_focus()
	# Deferred: focusing may pull in the next page, and the scroll offset must
	# be computed once the list has its final height.
	_scroll.ensure_control_visible.call_deferred(_cards[index])


func _focus_first() -> void:
	if _cards.is_empty():
		return
	_focus_card(0)
	_focus_pending = false


func _focus_id(player_id: String) -> void:
	var index := _index_of(player_id)
	if index >= 0:
		_focus_card(index)


func _maybe_load_more(index: int) -> void:
	if not _has_more or _items.is_empty():
		return
	if index < _items.size() - LOAD_AHEAD:
		return
	_load_more()


# Cards / modal --------------------------------------------------------------

func _on_card_focused(card: CareerPlayerCard) -> void:
	_focus = _cards.find(card)
	_select(card.player_id())
	_maybe_load_more(_focus)


func _on_card_pressed(player_id: String) -> void:
	_select(player_id)
	_open_actions()


func _open_actions() -> void:
	if _selected_id.is_empty() or _actions == null or _actions.is_open():
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var index := _index_of(_selected_id)
	if index < 0:
		return
	_focus = index
	_actions.setup(career, catalog, _items[index], {
		"scouts": _scouts,
		"report": _report_for(_selected_id),
		"date": career.date,
	})
	_actions.open()
	state_changed.emit()


func _on_actions_closed() -> void:
	_resume_actions = false
	_focus_id(_selected_id)
	state_changed.emit()


func _on_actions_navigate(view: String, payload: Dictionary) -> void:
	_resume_actions = view == "offer" or view == "contract"
	navigate.emit(view, payload)


func _on_actions_changed() -> void:
	var player_id := _actions.player_id()
	_refresh_player(player_id)
	# Assignment / recall changes who is free.
	_refresh_scouts()
	changed.emit()


func _on_scout_requested(scout_id: String) -> void:
	scout_requested.emit(_actions.player_id(), scout_id)
	# The host assigned inside that signal: the scout is busy now, so the next
	# card opened must not offer him again.
	_refresh_scouts()


func _refresh_scouts() -> void:
	if career != null:
		_scouts = _flagged_scouts(CareerScouting.assignable_scouts(career))


func _refresh_player(player_id: String) -> void:
	var index := _index_of(player_id)
	if index < 0:
		return
	_cards[index].setup(_items[index])
	_cards[index].set_selected(_selected_id == player_id)
	if _selected_id == player_id:
		_pane.setup(_items[index], {"date": career.date})


# The report a free scout is already working on, tagged with his name, or {}.
func _report_for(player_id: String) -> Dictionary:
	if career == null:
		return {}
	var report := CareerScouting.report_for(career, player_id)
	return report if report is Dictionary else {}


# Scouts carry their country by name (scouting snapshot); the picker wants a
# texture, so resolve it once through the catalog's country list.
func _flagged_scouts(scouts: Array) -> Array:
	var tm_ids := {}
	if catalog != null:
		for country in catalog.countries():
			tm_ids[str(country.get("name", ""))] = str(country.get("tm_id", ""))
	var result: Array = []
	for scout in scouts:
		if not (scout is Dictionary):
			continue
		var copy: Dictionary = (scout as Dictionary).duplicate(true)
		var flag = copy.get("flag")
		if flag is String and not (flag as String).contains("/") \
				and not (flag as String).contains("."):
			var tm_id := str(tm_ids.get(str(flag), ""))
			copy["flag"] = UiAssets.usable_texture(
				UiAssets.country_flag({"tm_id": tm_id})) if not tm_id.is_empty() else null
		result.append(copy)
	return result


# Input ----------------------------------------------------------------------

func _is_active() -> bool:
	var nav := _ui_nav()
	return is_visible_in_tree() and (nav == null or not nav.is_modal())


func _connect_nav() -> void:
	var nav := _ui_nav()
	if nav == null:
		return
	nav.moved.connect(_on_nav_moved)
	nav.confirmed.connect(_on_nav_confirmed)
	nav.cancelled.connect(_on_nav_cancelled)


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_active() or _cards.is_empty() or _focus < 0:
		return
	var index := _focus
	match direction:
		Vector2i.UP:
			index -= COLUMNS
		Vector2i.DOWN:
			index += COLUMNS
		Vector2i.LEFT:
			index -= 1
		Vector2i.RIGHT:
			index += 1
	if index < 0 or index >= _cards.size():
		return
	if (direction == Vector2i.LEFT or direction == Vector2i.RIGHT) \
			and floori(float(index) / COLUMNS) != floori(float(_focus) / COLUMNS):
		return
	_focus_card(index)
	_maybe_load_more(index)


func _on_nav_confirmed() -> void:
	if not _is_active():
		return
	if _focus < 0:
		_focus_first()
		return
	# Deferred: the modal's own confirm handler must not see the event that
	# opened it (trigger buttons stay unsafe across one signal emission).
	call_deferred("_open_actions")


func _on_nav_cancelled() -> void:
	if not _is_active() or _event_was_modal():
		return
	closed.emit()


func _event_was_modal() -> bool:
	var nav := _ui_nav()
	return nav != null and bool(nav.event_was_modal())


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")
