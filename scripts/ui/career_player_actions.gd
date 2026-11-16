class_name CareerPlayerActions
extends Control
# Prototype PlayerActionsModal.svelte: the player-actions card of the transfer
# search (and of the scout report later). Header photo/name/facts/club, the
# metrics row with the fog (`?` until scouted), the status lines and the action
# rows: scout assignment, shortlist, transfer / loan offers and the personal
# contract. Rows follow the prototype, including the disabled ones and their
# ticket reason ("HIRE A SCOUT", "NOT EXPIRING", …); a disabled row still takes
# focus but does nothing on confirm.
#
# The card owns UiNav while open (push_modal / pop_modal), fades + scales in
# 240 ms and out in 150 ms, and reports through signals — the host screen owns
# routing to the offer / contract screens.

signal navigate(view: String, payload: Dictionary)
signal changed
signal scout_requested(scout_id: String)
signal closed

const CARD_W := 860.0
const PAD := 16.0
const ROW_H := 44.0
const PHOTO_W := 92.0
const PHOTO_H := 100.0
const CREST := 32.0
const METRIC_H := 58.0
const STATUS_H := 26.0
const SCALE_FROM := 0.96
const SCRIM := Color(0.024, 0.047, 0.102, 0.68)
const HIDDEN := "?"


# One action row: label on the left, the confirm key or the disabled reason on
# the right. Focus inverts it like every other career list row.
class Row extends Button:
	var id := ""
	var enabled := true
	var _bg: Panel
	var _label: Label
	var _ticket: Label
	var _normal: StyleBoxFlat
	var _focus: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_normal = StyleBoxFlat.new()
		_normal.bg_color = Color(UiTokens.INK, 0.055)
		_focus = StyleBoxFlat.new()
		_focus.bg_color = UiTokens.FOCUS_FILL
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_override(&"font", UiTheme.barlow(700))
		_label.add_theme_font_size_override(&"font_size", 18)
		add_child(_label)
		_ticket = Label.new()
		_ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ticket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ticket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ticket.add_theme_font_override(&"font", UiTheme.inter(600))
		_ticket.add_theme_font_size_override(&"font_size", 16)
		add_child(_ticket)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func setup(row: Dictionary) -> void:
		id = str(row.get("id", ""))
		enabled = bool(row.get("enabled", true))
		if _label == null:
			return
		set_label(str(row.get("label", "")))
		_ticket.text = str(row.get("ticket", ""))
		_apply_state()
		_layout_content()

	func set_label(text: String) -> void:
		_label.text = text.to_upper()

	func label_text() -> String:
		return "" if _label == null else str(_label.text)

	func ticket_text() -> String:
		return "" if _ticket == null else str(_ticket.text)

	func _layout_content() -> void:
		if _bg == null:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		var ticket_w := 0.0
		if not _ticket.text.is_empty():
			var font := _ticket.get_theme_font(&"font")
			var font_size := _ticket.get_theme_font_size(&"font_size")
			ticket_w = font.get_string_size(_ticket.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size).x + 16.0
		_ticket.position = Vector2(size.x - 14.0 - ticket_w, (size.y - 20.0) * 0.5)
		_ticket.size = Vector2(ticket_w, 20.0)
		var text_x := 14.0
		_label.position = Vector2(text_x, 0.0)
		_label.size = Vector2(maxf(0.0, size.x - text_x - 14.0 - ticket_w - 10.0), size.y)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus if focused else _normal)
		var ink := UiTokens.INK
		var ticket_ink := UiTokens.INK_2
		var ticket_fill := Color(UiTokens.INK, 0.07)
		if focused:
			ink = UiTokens.FOCUS_MARK if enabled else UiTokens.FOCUS_INK_2
			ticket_ink = UiTokens.FOCUS_INK_2
			ticket_fill = Color(UiTokens.FOCUS_INK, 0.14)
		elif not enabled:
			ink = UiTokens.INK_2
		_label.add_theme_color_override(&"font_color", ink)
		_ticket.add_theme_color_override(&"font_color", ticket_ink)
		var box := StyleBoxFlat.new()
		box.bg_color = ticket_fill
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		_ticket.add_theme_stylebox_override(&"normal", box)


var career: Career
var catalog: TeamCatalog

var _player: Dictionary = {}
var _player_id := ""
var _scouts: Array = []
var _report: Dictionary = {}
var _date := ""
var _can_discuss := false
var _contract_months := -1
var _open := false
var _armed := false
var _rows: Array[Row] = []
var _by_id: Dictionary = {}
var _picker: CareerScoutPicker
var _tween: Tween

var _scrim: ColorRect
var _card: PanelContainer
var _window_scrim: ColorRect
var _photo: CareerPlayerCard.Photo
var _name: Label
var _fact_values: Array[Label] = []
var _crest: CareerPlayerCard.Photo
var _club: Label
var _metric_values: Array[Label] = []
var _status_box: VBoxContainer
var _actions_box: VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_build()
	resized.connect(_layout)
	_connect_nav()
	call_deferred("_layout")


# `options`: {scouts: Array, report: Dictionary, date: String}. `report` is the
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
	var expires := str(player.get("contract_expires", ""))
	_contract_months = CareerPlayerPane.months_until(expires, _date) \
		if not expires.is_empty() else -1
	if _card == null:
		return
	_refresh()
	_rebuild_rows()


func open() -> void:
	if _open:
		return
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
	if not _open:
		return
	_open = false
	if _picker != null and _picker.is_open():
		_picker.close()
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
		ids.append(row.id)
	return ids


func row_label(id: String) -> String:
	var row: Row = _by_id.get(id, null)
	return "" if row == null else row.label_text()


func row_enabled(id: String) -> bool:
	var row: Row = _by_id.get(id, null)
	return row != null and row.enabled


func row_ticket(id: String) -> String:
	var row: Row = _by_id.get(id, null)
	return "" if row == null else row.ticket_text()


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

	column.add_child(_build_head())
	var divider := ColorRect.new()
	divider.color = Color(UiTokens.INK, 0.10)
	divider.custom_minimum_size.y = 2.0
	column.add_child(divider)
	column.add_child(_build_body())


func _build_head() -> Control:
	var margin := MarginContainer.new()
	margin.name = "Head"
	margin.add_theme_constant_override(&"margin_left", int(PAD))
	margin.add_theme_constant_override(&"margin_right", int(PAD))
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	margin.add_child(head)

	_photo = CareerPlayerCard.Photo.new()
	_photo.custom_minimum_size = Vector2(PHOTO_W, PHOTO_H)
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_photo)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 6)
	head.add_child(info)
	var eyebrow := Label.new()
	eyebrow.text = "PLAYER ACTIONS"
	eyebrow.add_theme_font_override(&"font", UiTheme.inter(600))
	eyebrow.add_theme_font_size_override(&"font_size", 16)
	eyebrow.add_theme_color_override(&"font_color", UiTokens.INK_2)
	info.add_child(eyebrow)
	_name = Label.new()
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	_name.add_theme_font_override(&"font", UiTheme.barlow(700))
	_name.add_theme_font_size_override(&"font_size", 30)
	_name.add_theme_color_override(&"font_color", UiTokens.INK)
	info.add_child(_name)
	var facts := GridContainer.new()
	facts.columns = 4
	facts.add_theme_constant_override(&"h_separation", 12)
	facts.add_theme_constant_override(&"v_separation", 3)
	info.add_child(facts)
	for key in ["AGE", "HEIGHT", "POSITION", "FOOT"]:
		var fact := VBoxContainer.new()
		fact.name = key
		fact.add_theme_constant_override(&"separation", 1)
		facts.add_child(fact)
		var label := Label.new()
		label.text = key
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 14)
		label.add_theme_color_override(&"font_color", UiTokens.INK_2)
		fact.add_child(label)
		var value := Label.new()
		value.add_theme_font_override(&"font", UiTheme.inter(600))
		value.add_theme_font_size_override(&"font_size", 18)
		value.add_theme_color_override(&"font_color", UiTokens.INK)
		fact.add_child(value)
		_fact_values.append(value)

	var club := VBoxContainer.new()
	club.add_theme_constant_override(&"separation", 6)
	club.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(club)
	_crest = CareerPlayerCard.Photo.new()
	_crest.custom_minimum_size = Vector2(CREST, CREST)
	_crest.size_flags_horizontal = Control.SIZE_SHRINK_END
	club.add_child(_crest)
	_club = Label.new()
	_club.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_club.max_lines_visible = 2
	_club.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_club.custom_minimum_size.x = 140.0
	_club.add_theme_font_override(&"font", UiTheme.inter(500))
	_club.add_theme_font_size_override(&"font_size", 16)
	_club.add_theme_color_override(&"font_color", UiTokens.INK_2)
	club.add_child(_club)
	return margin


func _build_body() -> Control:
	var margin := MarginContainer.new()
	margin.name = "Body"
	margin.add_theme_constant_override(&"margin_left", int(PAD))
	margin.add_theme_constant_override(&"margin_right", int(PAD))
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", int(PAD))
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 6)
	margin.add_child(body)

	var metrics := HBoxContainer.new()
	metrics.name = "Metrics"
	metrics.add_theme_constant_override(&"separation", 8)
	body.add_child(metrics)
	for index in 4:
		var block := PanelContainer.new()
		block.custom_minimum_size.y = METRIC_H
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.INK, 0.055)
		box.content_margin_left = 12.0
		box.content_margin_right = 12.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		block.add_theme_stylebox_override(&"panel", box)
		metrics.add_child(block)
		var column := VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 0)
		block.add_child(column)
		var label := Label.new()
		label.text = ["OVERALL", "PRICE", "WAGE", "RELEASE CLAUSE"][index]
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 14)
		label.add_theme_color_override(&"font_color", UiTokens.INK_2)
		column.add_child(label)
		var value := Label.new()
		value.add_theme_font_override(&"font", UiTheme.barlow(700))
		value.add_theme_font_size_override(&"font_size", 22)
		value.add_theme_color_override(&"font_color", UiTokens.INK)
		column.add_child(value)
		_metric_values.append(value)

	_status_box = VBoxContainer.new()
	_status_box.name = "Status"
	_status_box.add_theme_constant_override(&"separation", 1)
	body.add_child(_status_box)

	_actions_box = VBoxContainer.new()
	_actions_box.name = "Actions"
	_actions_box.add_theme_constant_override(&"separation", 1)
	body.add_child(_actions_box)
	return margin


# Content --------------------------------------------------------------------

func _refresh() -> void:
	var revealed := bool(_player.get("scouted", false))
	_photo.show_texture(CareerPlayerCard.face_texture(_player))
	_name.text = str(_player.get("name", "")).to_upper()
	_fact_values[0].text = str(_player.get("age", "—"))
	var height := int(_player.get("height", 0))
	_fact_values[1].text = "%d CM" % height if height > 0 else "—"
	_fact_values[2].text = CareerPlayerCard.position_code(
		str(_player.get("position", "")), str(_player.get("position_group", "")))
	_fact_values[3].text = _foot_label(str(_player.get("foot", ""))) if revealed else HIDDEN
	var crest := CareerPlayerCard.crest_texture(_player)
	_crest.show_texture(crest)
	_crest.visible = crest != null
	var club_name := str(_player.get("club_name", ""))
	_club.text = club_name if not club_name.is_empty() else "Free agent"
	_refresh_metrics(revealed)
	_refresh_status()


func _refresh_metrics(revealed: bool) -> void:
	var raw := [
		int(round(float(_player.get("overall", 0)))),
		int(_player.get("market_value", 0)),
		int(_player.get("weekly_wage", 0)),
		int(_player.get("release_clause", 0)),
	]
	for index in _metric_values.size():
		var text := HIDDEN
		if revealed or index == 3:
			match index:
				0:
					text = str(raw[0]) if int(raw[0]) > 0 else "—"
				2:
					text = CareerPlayerPane.money(int(raw[2])) + " / WEEK"
				_:
					text = CareerPlayerPane.money(int(raw[index]))
		_metric_values[index].text = text
		_metric_values[index].add_theme_color_override(&"font_color",
			UiTokens.INK if revealed or index == 3 else UiTokens.INK_2)


func _refresh_status() -> void:
	for child in _status_box.get_children():
		_status_box.remove_child(child)
		child.queue_free()
	var status := str(_player.get("status", ""))
	_status_box.add_child(_status_line(CareerPlayerPane.status_line(status), false))
	if _contract_months >= 0 and status != "free":
		var text := "Contract expires in %d %s" % [_contract_months,
			"month" if _contract_months == 1 else "months"]
		if _contract_months <= 0:
			text = "Contract expires this month"
		_status_box.add_child(_status_line(text, _contract_months <= 6))


func _status_line(text: String, warn: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.055)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	panel.add_theme_stylebox_override(&"panel", box)
	panel.custom_minimum_size.y = STATUS_H
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.inter(500))
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_color",
		Color("a66a00") if warn else UiTokens.INK_2)
	panel.add_child(label)
	return panel


static func _foot_label(foot: String) -> String:
	match foot.to_lower():
		"left":
			return "Left"
		"right":
			return "Right"
		"both":
			return "Both"
	return "—"


func _rebuild_rows() -> void:
	for child in _actions_box.get_children():
		_actions_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	_by_id.clear()
	for row in _action_rows():
		var button := Row.new()
		button.custom_minimum_size.y = ROW_H
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actions_box.add_child(button)
		button.setup(row)
		button.pressed.connect(_on_row_pressed.bind(str(row.get("id", ""))))
		_rows.append(button)
		_by_id[str(row.get("id", ""))] = button


func _action_rows() -> Array:
	var rows: Array = []
	var revealed := bool(_player.get("scouted", false))
	if not revealed:
		if not _report.is_empty():
			var days := int(_report.get("days_left", 0))
			rows.append({
				"id": "scout", "enabled": false,
				"label": "%s IS WATCHING" % str(_report.get("scout_name", "A SCOUT")),
				"ticket": ("%d DAYS LEFT" % days) if days > 0 else "REPORT DUE",
			})
		elif not _scouts.is_empty():
			rows.append({"id": "scout", "enabled": true,
				"label": "ASSIGN SCOUT", "ticket": "A"})
		else:
			rows.append({"id": "scout", "enabled": false,
				"label": "HIRE A SCOUT", "ticket": "NETWORK"})
	rows.append({
		"id": "shortlist", "enabled": true,
		"label": "REMOVE FROM SHORTLIST" if bool(_player.get("shortlisted", false)) \
			else "ADD TO SHORTLIST",
		"ticket": "A",
	})
	if not str(_player.get("club_id", "")).is_empty():
		rows.append({"id": "offer_transfer", "enabled": true,
			"label": "MAKE TRANSFER OFFER", "ticket": "A"})
		rows.append({"id": "offer_loan", "enabled": true,
			"label": "MAKE LOAN OFFER", "ticket": "A"})
	rows.append({"id": "discuss", "enabled": _can_discuss,
		"label": "DISCUSS MOVE", "ticket": "A" if _can_discuss else "NOT EXPIRING"})
	return rows


# Actions --------------------------------------------------------------------

func _on_row_pressed(id: String) -> void:
	var row: Row = _by_id.get(id, null)
	if row == null or not row.enabled:
		return
	match id:
		"scout":
			_open_picker()
		"shortlist":
			_toggle_shortlist()
		"offer_transfer":
			_offer("transfer")
		"offer_loan":
			_offer("loan")
		"discuss":
			var key := _player_id
			close()
			navigate.emit("contract", {"player_id": key})


func _toggle_shortlist() -> void:
	if career == null or catalog == null:
		return
	var result := CareerTransfers.toggle_shortlist(career, catalog, _player_id)
	if not bool(result.get("ok", false)):
		return
	_player["shortlisted"] = bool(result.get("shortlisted", false))
	var row: Row = _by_id.get("shortlist", null)
	if row != null:
		row.set_label("REMOVE FROM SHORTLIST" if bool(_player["shortlisted"]) \
			else "ADD TO SHORTLIST")
	changed.emit()


func _offer(kind: String) -> void:
	var preset := CareerTransferOffers.proposal(career, catalog, _player_id, kind)
	var key := _player_id
	close()
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
	var row := get_viewport().gui_get_focus_owner() as Row
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
