class_name CareerPlayerActions
extends Control
# Prototype PlayerActionsModal.svelte: the one player-actions card of the career
# screens (the transfer search, the transfer centre shortlist and the scout
# report all open this class). The player himself is drawn by the shared
# CareerPlayerPane (photo, facts, metrics, attributes, status), the action rows
# are the pane's rows: scout assignment, shortlist, transfer / loan offers and
# the personal contract, plus the host's `extra_rows` ("REMOVE FROM REPORT").
# Rows follow the prototype, including the disabled ones and their ticket reason
# ("HIRE A SCOUT", "NOT EXPIRING", …); a disabled row still takes focus but does
# nothing on confirm.
#
# The card owns UiNav while open (push_modal / pop_modal), fades + scales in
# 240 ms and out in 150 ms, and reports through signals — the host screen owns
# routing to the offer / contract screens.

signal navigate(view: String, payload: Dictionary)
signal changed
signal scout_requested(scout_id: String)
# A host row (`extra_rows`): "remove", "close", …
signal extra_action(id: String)
signal closed

const CARD_W := 860.0
const PAD := 16.0
const SCALE_FROM := 0.96
const SCRIM := Color(0.024, 0.047, 0.102, 0.68)
# The recall confirm over a running report: same rows as the prototype's scout
# card (action first, Cancel last).
const RECALL_ROWS := [
	{"id": "recall", "label": "Recall scout", "ticket": "A"},
	{"id": "cancel", "label": "Cancel", "ticket": "B"},
]


var career: Career
var catalog: TeamCatalog

var _player: Dictionary = {}
var _player_id := ""
var _scouts: Array = []
var _report: Dictionary = {}
var _date := ""
var _can_discuss := false
var _eyebrow := "PLAYER ACTIONS"
var _extra_rows: Array = []
var _show_scout := true
var _show_shortlist := true
var _open := false
var _armed := false
# The host put another screen over this card (offer / contract): keep the player
# and bring the card back with resume() instead of closing it.
var _resume := false
var _resume_focus := ""
var _rows: Array = []
var _by_id: Dictionary = {}
var _picker: CareerScoutPicker
var _recall_modal: CareerScoutingModal
var _tween: Tween

var _scrim: ColorRect
var _card: PanelContainer
var _window_scrim: ColorRect
var _eyebrow_label: Label
var _pane: CareerPlayerPane


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_build()
	resized.connect(_layout)
	_connect_nav()
	call_deferred("_layout")


# `options`: {scouts: Array, report: Dictionary, date: String, eyebrow: String,
# extra_rows: Array, show_scout: bool, show_shortlist: bool}. `report` is the
# active scouting report for this player ({scout_name, days_left, …}) or {}.
func setup(next_career: Career, next_catalog: TeamCatalog, player: Dictionary,
		options := {}) -> void:
	career = next_career
	catalog = next_catalog
	_player = player
	_player_id = str(player.get("player_id", player.get("id", "")))
	# The host may not know the network (the transfer centre omits both): fall
	# back to the scouting module so the row still names the watching scout and
	# only a free scout can be sent.
	if options.has("scouts") and options.get("scouts") is Array:
		_scouts = options.get("scouts")
	else:
		_scouts = CareerScouting.assignable_scouts(career) if career != null else []
	var report = options.get("report", {})
	if not (report is Dictionary) or (report as Dictionary).is_empty():
		report = CareerScouting.report_for(career, _player_id) if career != null else {}
	_report = report if report is Dictionary else {}
	_date = str(options.get("date", career.date if career != null else ""))
	_can_discuss = career != null and catalog != null \
		and CareerTransferContracts.can_discuss(catalog, career, player)
	_eyebrow = str(options.get("eyebrow", "PLAYER ACTIONS"))
	_extra_rows = options.get("extra_rows", []) if options.get("extra_rows") is Array else []
	_show_scout = bool(options.get("show_scout", true))
	_show_shortlist = bool(options.get("show_shortlist", true))
	if _card == null:
		return
	_refresh()


func open() -> void:
	if _open:
		return
	# A fresh open wins over a pending resume: this card is a new player.
	_resume = false
	# Before `_open`: reparenting leaves and re-enters the tree, and _exit_tree
	# would pop an open modal off the stack.
	CareerScoutingModal.host_overlay(self)
	_host_scrim()
	_open = true
	_armed = false
	visible = true
	move_to_front()
	var nav := _ui_nav()
	if nav != null:
		nav.push_modal(self)
	# Opened from a host's confirm handler: stay deaf until the next frame so the
	# very event that opened this card does not also press its first row.
	call_deferred("_arm")
	_layout()
	_focus_first()
	_scrim.modulate.a = 0.0
	if _window_scrim != null:
		_window_scrim.modulate.a = 0.0
	if _instant():
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
		_scrim.modulate.a = 1.0
		if _window_scrim != null:
			_window_scrim.modulate.a = 1.0
		return
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE * SCALE_FROM
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "modulate:a", 1.0, UiTokens.SCREEN_IN)
	_tween.tween_property(_card, "scale", Vector2.ONE, UiTokens.SCREEN_IN)
	_tween.tween_property(_scrim, "modulate:a", 1.0, UiTokens.SCREEN_OUT)
	if _window_scrim != null:
		_tween.tween_property(_window_scrim, "modulate:a", 1.0, UiTokens.SCREEN_OUT)


func close() -> void:
	_resume = false
	if not _open:
		return
	_open = false
	if _picker != null and _picker.is_open():
		_picker.close()
	if _recall_modal != null and _recall_modal.is_open():
		_recall_modal.close()
	var nav := _ui_nav()
	if nav != null:
		nav.pop_modal(self)
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()
	closed.emit()
	if _tween != null:
		_tween.kill()
	if _instant():
		visible = false
		_release_scrim()
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_card, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	_tween.tween_property(_card, "scale", Vector2.ONE * SCALE_FROM, UiTokens.SCREEN_OUT)
	_tween.tween_property(_scrim, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	if _window_scrim != null:
		_tween.tween_property(_window_scrim, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		_release_scrim())


# Leaves the card for an offer / contract screen the host shows over this one:
# input and the scrim go away, the player and the rows stay for resume().
func suspend() -> void:
	if not _open:
		return
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	_resume_focus = ""
	if focused != null and focused is CareerPlayerPane.ActionRow and is_ancestor_of(focused):
		_resume_focus = (focused as CareerPlayerPane.ActionRow).id
	_resume = true
	_open = false
	_armed = false
	if _picker != null and _picker.is_open():
		_picker.close()
	if _recall_modal != null and _recall_modal.is_open():
		_recall_modal.close()
	var nav := _ui_nav()
	if nav != null:
		nav.pop_modal(self)
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if _tween != null:
		_tween.kill()
	visible = false
	_release_scrim()


# Puts a suspended card back, with the career state it may have missed.
func resume() -> bool:
	if not _resume:
		return false
	_resume = false
	setup(career, catalog, _player, {"scouts": _scouts, "date": _date})
	open()
	var row := _row(_resume_focus)
	if row != null:
		row.grab_focus()
	return true


# The design canvas is letterboxed inside the window, so a scrim drawn inside it
# leaves the bars at the edges uncovered. A second dim layer on the screen root
# covers the whole window; it is input-transparent (a root-level STOP rect would
# eat the mouse before the card, as Godot picks Controls by tree order, not z),
# and the card's own scrim keeps the click-to-close.
func _host_scrim() -> void:
	var tree := get_tree()
	if tree == null or _scrim == null or _window_scrim != null:
		return
	var screen := tree.current_scene
	if not (screen is Control) or screen == self:
		return
	_window_scrim = ColorRect.new()
	_window_scrim.name = "WindowScrim"
	_window_scrim.color = SCRIM
	_window_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_scrim.z_index = 90
	_window_scrim.modulate.a = 0.0
	(screen as Control).add_child(_window_scrim)
	_window_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(SCRIM, 0.0)


func _release_scrim() -> void:
	if _window_scrim != null:
		_window_scrim.queue_free()
		_window_scrim = null
	if _scrim != null:
		_scrim.color = SCRIM


func is_open() -> bool:
	return _open


func player_id() -> String:
	return _player_id


func row_ids() -> Array:
	var ids: Array = []
	for row in _rows:
		ids.append(str(row.id))
	return ids


func row_label(id: String) -> String:
	var row := _row(id)
	return "" if row == null else row.label_text()


func row_enabled(id: String) -> bool:
	var row := _row(id)
	return row != null and row.enabled


func row_ticket(id: String) -> String:
	var row := _row(id)
	return "" if row == null else str(row.key)


func _row(id: String) -> CareerPlayerPane.ActionRow:
	return _by_id.get(id, null) as CareerPlayerPane.ActionRow


# Build ----------------------------------------------------------------------

func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW_SELECTED
	box.shadow_size = 44
	box.shadow_offset = Vector2(0.0, 24.0)
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 0)
	_card.add_child(column)

	var head := MarginContainer.new()
	head.name = "Head"
	head.add_theme_constant_override(&"margin_left", int(PAD))
	head.add_theme_constant_override(&"margin_right", int(PAD))
	head.add_theme_constant_override(&"margin_top", 12)
	head.add_theme_constant_override(&"margin_bottom", 4)
	_eyebrow_label = Label.new()
	_eyebrow_label.name = "Eyebrow"
	_eyebrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyebrow_label.add_theme_font_override(&"font", UiTheme.inter(600))
	_eyebrow_label.add_theme_font_size_override(&"font_size", 16)
	_eyebrow_label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	head.add_child(_eyebrow_label)
	column.add_child(head)

	# The player body is the one shared renderer (photo, facts, metrics,
	# attributes, status) — the same widget the report feed and the search pane
	# draw. Its rows are the action rows of this card.
	_pane = CareerPlayerPane.new()
	_pane.name = "Pane"
	_pane.action_chosen.connect(_on_row_pressed)
	column.add_child(_pane)


# Content --------------------------------------------------------------------

func _refresh() -> void:
	_eyebrow_label.text = _eyebrow.to_upper()
	# No eyebrow, no header row: the card starts at the top.
	(_eyebrow_label.get_parent() as Control).visible = not _eyebrow.is_empty()
	# The pane rebuilds the player body and the action rows from the current
	# career state; the card only collects the rows for its own focus nav.
	# No inner scrollbar: the card is sized from the pane's full height.
	_pane.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pane.setup(_player, {"date": _date, "action_rows": _action_rows(),
		"show_actions": true, "flat": true})
	_collect_rows()
	call_deferred("_layout")


# Rows changed, the player body did not (scout report / recall).
func _set_rows() -> void:
	_pane.set_action_rows(_action_rows())
	_collect_rows()


func _collect_rows() -> void:
	_rows.clear()
	_by_id.clear()
	for button in _pane.action_buttons():
		var row := button as CareerPlayerPane.ActionRow
		if row == null:
			continue
		_rows.append(row)
		_by_id[row.id] = row


func _action_rows() -> Array:
	var rows: Array = []
	var revealed := bool(_player.get("scouted", false))
	if _show_scout and not revealed:
		if not _report.is_empty():
			var days := int(_report.get("days_left", 0))
			rows.append({
				"id": "scout",
				# A running report opens the recall card; a finished one has
				# nothing to recall (its player is `scouted` by then anyway).
				"enabled": str(_report.get("kind", "")) == "studying",
				"label": "%s IS WATCHING" % str(_report.get("scout_name", "A SCOUT")),
				"key": ("%d DAYS LEFT" % days) if days > 0 else "REPORT DUE",
			})
		elif not _scouts.is_empty():
			rows.append({"id": "scout", "enabled": true,
				"label": "ASSIGN SCOUT", "key": "A"})
		else:
			rows.append({"id": "scout", "enabled": false,
				"label": "HIRE A SCOUT", "key": "NETWORK"})
	if _show_shortlist:
		rows.append({
			"id": "shortlist", "enabled": true,
			"label": "REMOVE FROM SHORTLIST" if bool(_player.get("shortlisted", false)) \
				else "ADD TO SHORTLIST",
			"key": "A",
		})
	rows.append_array(_offer_rows())
	for row in _extra_rows:
		if row is Dictionary:
			rows.append(row)
	return rows


# The offer / contract part of the rows: an accepted offer leaves CONTRACT
# TALKS, a signed one the joining note; only a kind that can actually be sent
# gets a row (an offer with the club, a counter of the other kind, a refusal in
# its cooldown, or your own squad leave nothing to send).
func _offer_rows() -> Array:
	var rows: Array = []
	var offer := CareerTransferOffers.latest(career, _player_id) if career != null else {}
	if bool(offer.get("can_negotiate", false)):
		rows.append({"id": "discuss", "enabled": true,
			"label": "CONTRACT TALKS", "key": "A"})
	elif bool(offer.get("signed", false)):
		var joins := str(offer.get("execute_on", ""))
		rows.append({"id": "transfer_agreed", "enabled": false,
			"label": "TRANSFER AGREED",
			"key": ("JOINS " + joins) if not joins.is_empty() else "SIGNED"})
	else:
		if not str(_player.get("club_id", "")).is_empty():
			# One negotiation per player at a time — transfer or loan — so any
			# offer in progress (or a refusal in its cooldown) hides both rows.
			var own := career != null and career.player_ids.has(_player_id)
			var blocked := CareerTransferOffers.block(career, _player_id) \
				if career != null else {}
			if not own and blocked.is_empty():
				rows.append({"id": "offer_transfer", "enabled": true,
					"label": "MAKE TRANSFER OFFER", "key": "A"})
				rows.append({"id": "offer_loan", "enabled": true,
					"label": "MAKE LOAN OFFER", "key": "A"})
			elif not own:
				var pending := str(blocked.get("status", "")) == "pending"
				rows.append({"id": "offer_blocked", "enabled": false,
					"label": "OFFER IS WITH THE CLUB" if pending else "OFFER REFUSED",
					"key": "TRANSFER CENTRE" if pending \
						else "RETRY " + str(blocked.get("retry_after", ""))})
		rows.append({"id": "discuss", "enabled": _can_discuss,
			"label": "DISCUSS MOVE", "key": "A" if _can_discuss else "NOT EXPIRING"})
	return rows


# The contract screen route, with the accepted offer when there is one (the
# screen cannot send terms without its id).
func _contract_payload() -> Dictionary:
	var payload := {"player_id": _player_id}
	var offer := CareerTransferOffers.latest(career, _player_id) if career != null else {}
	if bool(offer.get("can_negotiate", false)):
		payload["offer_id"] = str(offer.get("offer_id", ""))
		payload["kind"] = str(offer.get("kind", "transfer"))
	return payload


# Actions --------------------------------------------------------------------

func _on_row_pressed(id: String) -> void:
	var row := _row(id)
	if row == null or not row.enabled:
		return
	match id:
		"scout":
			if _report.is_empty():
				_open_picker()
			else:
				_open_recall()
		"shortlist":
			_toggle_shortlist()
		"offer_transfer":
			_offer("transfer")
		"offer_loan":
			_offer("loan")
		"discuss":
			suspend()
			navigate.emit("contract", _contract_payload())
		_:
			# A host row ("REMOVE FROM REPORT", "CLOSE"): the host owns it.
			extra_action.emit(id)


func _toggle_shortlist() -> void:
	if career == null or catalog == null:
		return
	var result := CareerTransfers.toggle_shortlist(career, catalog, _player_id)
	if not bool(result.get("ok", false)):
		return
	_player["shortlisted"] = bool(result.get("shortlisted", false))
	# The chip and the row label both follow; one pane refresh keeps them in sync.
	_refresh()
	var row := _row("shortlist")
	if row != null:
		row.grab_focus()
	changed.emit()


func _offer(kind: String) -> void:
	var preset := CareerTransferOffers.proposal(career, catalog, _player_id, kind)
	var key := _player_id
	suspend()
	navigate.emit("offer", {"player_id": key, "kind": kind, "preset": preset})


func _open_picker() -> void:
	# One scout per player: while a report is running no other scout may be sent.
	if not _report.is_empty():
		return
	if _picker == null:
		_picker = CareerScoutPicker.new()
		_picker.name = "ScoutPicker"
		add_child(_picker)
		_picker.assigned.connect(_on_scout_assigned)
	_picker.setup(_scouts, str(_player.get("name", "")))
	_picker.open()


func _on_scout_assigned(scout_id: String) -> void:
	scout_requested.emit(scout_id)
	# The host assigns synchronously inside that signal, so the card can show the
	# running report now instead of only after it is reopened.
	_reload_report()


func _open_recall() -> void:
	var scout_name := str(_report.get("scout_name", "The scout"))
	if _recall_modal == null:
		_recall_modal = CareerScoutingModal.new()
		_recall_modal.name = "RecallModal"
		add_child(_recall_modal)
		_recall_modal.action_chosen.connect(_on_recall_chosen)
	_recall_modal.setup(scout_name,
		"Call %s back? %s stays unscouted." % [scout_name,
			str(_player.get("name", "The player"))], RECALL_ROWS)
	_recall_modal.open()


func _on_recall_chosen(id: String) -> void:
	_recall_modal.close()
	if id != "recall" or career == null:
		return
	var scout_id := str(_report.get("scout_id", ""))
	if scout_id.is_empty():
		return
	if not bool(CareerScouting.recall(career, scout_id).get("ok", false)):
		return
	_reload_report()
	changed.emit()


func _reload_report() -> void:
	_report = CareerScouting.report_for(career, _player_id) if career != null else {}
	# A recalled scout is free again, also when the host sent no list (his flag
	# comes back with the next list the host builds).
	if career != null and _report.is_empty() and _scouts.is_empty():
		_scouts = CareerScouting.assignable_scouts(career)
	_set_rows()
	var row := _row("scout")
	if row != null:
		row.grab_focus()


# Layout / input -------------------------------------------------------------

func _layout() -> void:
	if _scrim == null:
		return
	_scrim.position = Vector2.ZERO
	_scrim.size = size
	if _card == null or size.x <= 0.0:
		return
	_card.custom_minimum_size.x = CARD_W
	var card_size := _card.get_combined_minimum_size()
	_card.size = Vector2(maxf(CARD_W, card_size.x), card_size.y)
	_card.position = ((size - _card.size) * 0.5).round()
	_card.pivot_offset = _card.size * 0.5


func _connect_nav() -> void:
	var nav := _ui_nav()
	if nav == null:
		return
	nav.moved.connect(_on_nav_moved)
	nav.confirmed.connect(_on_nav_confirmed)
	nav.cancelled.connect(_on_nav_cancelled)


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_modal_owner():
		return
	if direction != Vector2i.UP and direction != Vector2i.DOWN:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var index := _rows.find(focus)
	if index < 0:
		_focus_first()
		return
	var next := clampi(index + (-1 if direction == Vector2i.UP else 1), 0, _rows.size() - 1)
	_rows[next].grab_focus()


func _on_nav_confirmed() -> void:
	if not _is_modal_owner():
		return
	var row := get_viewport().gui_get_focus_owner() as CareerPlayerPane.ActionRow
	if row != null:
		_on_row_pressed(row.id)


func _on_nav_cancelled() -> void:
	if _is_modal_owner():
		close()


# A click on the dark backdrop closes the card; a click on the card itself never
# reaches the scrim (the card stops the mouse).
func _on_scrim_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		close()


func _focus_first() -> void:
	# The prototype's focusFirst() starts on the first row, disabled or not
	# (its disabled rows are focusable too).
	if not _rows.is_empty():
		_rows[0].grab_focus()


func _is_modal_owner() -> bool:
	var nav := _ui_nav()
	return _open and _armed and nav != null and nav.modal_owner() == self


func _arm() -> void:
	if _open:
		_armed = true


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


# Looked up by path: the modal is also instantiated by the headless tests
# directly, where a bare UiTransition identifier does not resolve.
func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _exit_tree() -> void:
	_release_scrim()
	if _open:
		var nav := _ui_nav()
		if nav != null:
			nav.pop_modal(self)
		_open = false
