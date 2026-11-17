class_name CareerTransferCentre
extends Control
# Prototype transfers/TransferCentre.svelte: the TRANSFER CENTRE with its four
# tabs. SHORTLIST is the search-result card list plus the shared player pane
# (confirm opens CareerPlayerActions); SENT and RECEIVED are the prototype's
# offer tables — an accordion row per offer with the negotiation actions and a
# detail pane on the right; LISTED is our own transfer list with the
# REMOVE FROM LIST accordion action. The tab strip carries the unread badge of
# the received offers, Left/Right (or Q/E) cycles the tabs, Down enters the
# list and Back closes the screen.
#
# The host (CareerTransfersView) owns routing and animation: this screen only
# reports `navigate` ("offer" with a re-offer preset, "contract" with the offer
# and player), `changed` (career mutated → host saves) and draws its hints bar
# from hints().

signal navigate(view: String, payload: Dictionary)
signal closed
signal changed
signal state_changed
signal scout_requested(player_id: String, scout_id: String)

const TABS := [
	{"id": "shortlist", "label": "SHORTLIST"},
	{"id": "sent", "label": "SENT"},
	{"id": "received", "label": "RECEIVED"},
	{"id": "listed", "label": "LISTED"},
]
const EMPTY := {
	"shortlist": ["SHORTLIST", "Nothing on the shortlist yet. Open a player from search and add him."],
	"sent": ["SENT OFFERS", "No offers have been sent yet."],
	"received": ["RECEIVED OFFERS", "No offers have been received yet."],
	"listed": ["LISTED FOR TRANSFER", "Nobody is on the transfer list. Open a player's card to set a status."],
}
const TABS_H := 52.0
const GAP := 8.0
const PAD := 16.0
const HEAD_H := 32.0
const CARD_H := 120.0
const CARD_GAP := 8.0
const COLUMNS := 2
const LOAD_ERRORS := 26.0
const DETAIL_RATIO := 1.35 / 2.15


# Right-hand offer detail (prototype SentOfferDetail / ReceivedOfferDetail):
# hero, market values, the state note, the offer table and the extra rows. The
# two prototype panes differ only in title, note and a few extra rows, so one
# widget serves both modes.
class Detail extends ScrollContainer:
	var _row: Dictionary = {}
	var _mode := ""
	var _card: PanelContainer
	var _box: VBoxContainer


	func _ready() -> void:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		mouse_filter = Control.MOUSE_FILTER_PASS
		_card = PanelContainer.new()
		_card.name = "Card"
		_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var panel := StyleBoxFlat.new()
		panel.bg_color = UiTokens.TILE
		panel.shadow_color = UiTokens.SHADOW
		panel.shadow_size = 32
		panel.shadow_offset = Vector2(0.0, 24.0)
		panel.content_margin_left = 16.0
		panel.content_margin_right = 16.0
		panel.content_margin_top = 16.0
		panel.content_margin_bottom = 16.0
		_card.add_theme_stylebox_override(&"panel", panel)
		add_child(_card)
		_box = VBoxContainer.new()
		_box.add_theme_constant_override(&"separation", 10)
		_card.add_child(_box)
		if not _row.is_empty():
			_refresh()


	func setup(row: Dictionary, mode: String) -> void:
		_row = row
		_mode = mode
		if _box == null:
			return
		_refresh()


	func title() -> String:
		if _box == null or _box.get_child_count() == 0:
			return ""
		return str((_box.get_child(0) as Label).text)


	func _player() -> Dictionary:
		return _row.get("player", {}) if _row.get("player") is Dictionary else {}


	# Sent rows carry the offer view separately; a received row is the offer.
	func _data() -> Dictionary:
		if _mode == "sent":
			return _row.get("offer", {}) if _row.get("offer") is Dictionary else {}
		return _row


	func _refresh() -> void:
		for child in _box.get_children():
			_box.remove_child(child)
			child.queue_free()
		if _row.is_empty():
			_box.add_child(_label("Pick an offer in the list.", UiTheme.inter(500), 16,
				UiTokens.INK_2))
			return
		var title := Label.new()
		title.text = "SENT OFFERS" if _mode == "sent" else "TRANSFER OFFERS"
		title.add_theme_font_override(&"font", UiTheme.barlow(800))
		title.add_theme_font_size_override(&"font_size", 20)
		title.add_theme_color_override(&"font_color", UiTokens.INK)
		_box.add_child(title)
		_box.add_child(_divider())
		_box.add_child(_hero())
		_box.add_child(_divider())
		_box.add_child(_values())
		_box.add_child(_divider())
		_box.add_child(_note_box())
		_box.add_child(_table())
		var extras := _extras()
		if not extras.is_empty():
			_box.add_child(_divider())
			for extra in extras:
				_box.add_child(_extra(str(extra[0]), str(extra[1])))


	func _label(text: String, font: Font, font_size: int, color: Color,
			wrap := false) -> Label:
		var label := Label.new()
		label.text = text
		label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", color)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = not wrap
		if wrap:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return label


	func _divider() -> ColorRect:
		var line := ColorRect.new()
		line.color = Color(UiTokens.INK, 0.12)
		line.custom_minimum_size = Vector2(0.0, 1.0)
		return line


	func _hero() -> Control:
		var player := _player()
		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 12)
		var photo := CareerPlayerCard.Photo.new()
		photo.custom_minimum_size = Vector2(84.0, 100.0)
		photo.size_flags_vertical = Control.SIZE_SHRINK_END
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(photo)
		photo.show_texture(CareerPlayerCard.face_texture(player))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_END
		info.add_theme_constant_override(&"separation", 4)
		head.add_child(info)
		var name := _label(str(player.get("name", "")).to_upper(), UiTheme.barlow(700),
			30, UiTokens.INK, true)
		name.max_lines_visible = 2
		name.clip_text = false
		info.add_child(name)
		var facts: Array[String] = []
		facts.append(CareerPlayerCard.position_code(str(player.get("position", "")),
			str(player.get("position_group", ""))))
		facts.append("AGE %s" % str(player.get("age", "—")))
		var height := int(player.get("height", 0))
		facts.append("%d CM" % height if height > 0 else "— CM")
		var citizenship = player.get("citizenship")
		if citizenship is Array and not (citizenship as Array).is_empty():
			var names: Array[String] = []
			for entry in citizenship:
				names.append(str(entry))
			facts.append(", ".join(names))
		info.add_child(_label(" · ".join(facts), UiTheme.inter(500), 15, UiTokens.INK_2))
		var rating := VBoxContainer.new()
		rating.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(rating)
		var overall := Label.new()
		overall.text = str(int(round(float(player.get("overall", 0.0))))) \
			if bool(player.get("scouted", false)) else "?"
		overall.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		overall.add_theme_font_override(&"font", UiTheme.barlow(800))
		overall.add_theme_font_size_override(&"font_size", 40)
		overall.add_theme_color_override(&"font_color", UiTokens.INK)
		rating.add_child(overall)
		var caption := _label("OVR", UiTheme.inter(600), 15, UiTokens.INK_2)
		caption.clip_text = false
		caption.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rating.add_child(caption)
		return head


	func _values() -> Control:
		var player := _player()
		var values := HBoxContainer.new()
		values.add_theme_constant_override(&"separation", 10)
		var scouted := bool(player.get("scouted", false))
		values.add_child(_value_block("MARKET VALUE",
			CareerPlayerPane.money(int(player.get("market_value", 0))) if scouted else "—"))
		values.add_child(_value_block("WEEKLY WAGE",
			CareerPlayerPane.money(int(player.get("weekly_wage", 0))) if scouted else "—"))
		values.add_child(_value_block("RELEASE CLAUSE",
			CareerPlayerPane.money(int(player.get("release_clause", 0)))))
		return values


	func _value_block(caption: String, value: String) -> PanelContainer:
		var block := PanelContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.INK, 0.055)
		box.content_margin_left = 10.0
		box.content_margin_right = 10.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		block.add_theme_stylebox_override(&"panel", box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 2)
		block.add_child(column)
		column.add_child(_label(caption, UiTheme.inter(600), 14, UiTokens.INK_2))
		column.add_child(_label(value, UiTheme.barlow(700), 20, UiTokens.INK))
		return block


	func _needs_action() -> bool:
		var offer := _data()
		var status := str(offer.get("status", ""))
		if _mode == "received":
			return bool(_row.get("unread", false)) or status == "pending"
		return bool(_row.get("can_accept_counter", false)) \
			or bool(_row.get("can_reoffer", false)) \
			or (status == "accepted" and not bool(offer.get("signed", false)))


	func _note_text() -> String:
		var offer := _data()
		var status := str(offer.get("status", ""))
		if _mode == "received":
			var club := str(_row.get("club_name", ""))
			var intro := "New offer from %s." % club if bool(_row.get("unread", false)) \
				else str(offer.get("message", "Offer from %s." % club))
			if intro.is_empty():
				intro = "Offer from %s." % club
			var expires = offer.get("expires_at")
			if expires != null and not str(expires).is_empty():
				intro += " Answer by %s." % CareerHubModel.short_date(str(expires))
			return intro
		match status:
			"pending":
				var text := "The club has not answered yet."
				var due = offer.get("due")
				if due != null and not str(due).is_empty():
					text += " Answer by %s." % CareerHubModel.short_date(str(due))
				return text
			"counter":
				return str(offer.get("message", "The club proposes new terms."))
			"accepted":
				if bool(offer.get("signed", false)):
					var execute_on = offer.get("execute_on")
					if execute_on != null and not str(execute_on).is_empty():
						return "Transfer completed. The player joins on %s." \
							% CareerHubModel.short_date(str(execute_on))
					return "Transfer completed."
				return str(offer.get("message", "The club accepted the offer."))
			"refused":
				var retry = offer.get("retry_after")
				if retry != null and not str(retry).is_empty():
					return "The club rejected the offer. You can try again after %s." \
						% CareerHubModel.short_date(str(retry))
				return "The club rejected the offer."
			"withdrawn":
				return "The offer has been withdrawn."
		return str(offer.get("message", ""))


	func _note_box() -> PanelContainer:
		var panel := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_MARK
		box.content_margin_left = 14.0
		box.content_margin_right = 12.0
		box.content_margin_top = 10.0
		box.content_margin_bottom = 10.0
		panel.add_theme_stylebox_override(&"panel", box)
		# One label: an HBox marker plus an autowrapped label kept collapsing the
		# text to zero width in Godot's container layout.
		var prefix := "!  " if _needs_action() else ""
		var note := _label(prefix + _note_text(), UiTheme.inter(600), 16,
			UiTokens.INK, false)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(note)
		return panel


	func _table() -> Control:
		var offer := _data()
		var table := VBoxContainer.new()
		table.add_theme_constant_override(&"separation", 8)
		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 10)
		table.add_child(head)
		head.add_child(_column_header("", 46.0))
		head.add_child(_column_header("TO" if _mode == "sent" else "FROM", 0.0, 1.0))
		head.add_child(_column_header("OFFER", 0.0, 1.1))
		head.add_child(_column_header("NEGOTIATION STATUS", 0.0, 1.1))
		head.add_child(_column_header("OFFER TYPE", 0.0, 0.9))
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		table.add_child(row)
		var crest := TextureRect.new()
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.custom_minimum_size = Vector2(36.0, 36.0)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var path := str(_player().get("club_logo", "")) if _mode == "sent" \
			else str(_row.get("club_logo", ""))
		crest.texture = null if path.is_empty() else UiAssets.usable_texture(
			UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(46.0, 36.0)
		crest.position = Vector2(0.0, 0.0)
		cell.add_child(crest)
		row.add_child(cell)
		var amount := _label(CareerPlayerPane.money(int(offer.get("amount", 0))),
			UiTheme.barlow(700), 20, UiTokens.INK)
		amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount.size_flags_stretch_ratio = 1.0
		row.add_child(amount)
		var status := HBoxContainer.new()
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.size_flags_stretch_ratio = 1.1
		status.add_theme_constant_override(&"separation", 6)
		row.add_child(status)
		if _needs_action():
			var bang := PanelContainer.new()
			bang.custom_minimum_size = Vector2(18.0, 18.0)
			bang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var bang_box := StyleBoxFlat.new()
			bang_box.bg_color = UiTokens.RAIL
			bang.add_theme_stylebox_override(&"panel", bang_box)
			status.add_child(bang)
			var bang_label := Label.new()
			bang_label.text = "!"
			bang_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bang_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			bang_label.add_theme_font_override(&"font", UiTheme.barlow(800))
			bang_label.add_theme_font_size_override(&"font_size", 14)
			bang_label.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK)
			bang.add_child(bang_label)
		var status_label := _label(
			CareerTransfers.offer_status_label(str(offer.get("status", ""))),
			UiTheme.inter(600), 16, UiTokens.INK)
		status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.add_child(status_label)
		var kind := _label(CareerTransfers.kind_label(str(offer.get("kind", ""))),
			UiTheme.inter(500), 16, UiTokens.INK_2)
		kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kind.size_flags_stretch_ratio = 0.9
		row.add_child(kind)
		return table


	func _column_header(text: String, width: float, ratio := 0.0) -> Label:
		var label := _label(text, UiTheme.inter(600), 14, UiTokens.INK_2)
		if width > 0.0:
			label.custom_minimum_size.x = width
		else:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_stretch_ratio = ratio
		return label


	func _extras() -> Array:
		var offer := _data()
		var kind := str(offer.get("kind", ""))
		var extras: Array = []
		if kind == "loan":
			extras.append(["WAGE SHARE", "%d%%" % int(offer.get("wage_share", 0))])
		var counter = offer.get("counter")
		if counter is Dictionary:
			var terms: Dictionary = counter
			var amount := int(terms.get("loan_fee", terms.get("amount", 0))) \
				if kind == "loan" else int(terms.get("amount", 0))
			extras.append(["CLUB COUNTER-OFFER", CareerPlayerPane.money(amount)])
			if kind == "loan":
				extras.append(["COUNTER WAGE SHARE",
					"%d%%" % int(terms.get("wage_share", 0))])
		if _mode == "received":
			var expires = offer.get("expires_at")
			if expires != null and not str(expires).is_empty():
				extras.append(["EXPIRES", CareerHubModel.short_date(str(expires))])
			return extras
		var status := str(offer.get("status", ""))
		var due = offer.get("due")
		if status == "pending" and due != null and not str(due).is_empty():
			extras.append(["ANSWER BY", CareerHubModel.short_date(str(due))])
		var retry = offer.get("retry_after")
		if status == "refused" and retry != null and not str(retry).is_empty():
			extras.append(["RETRY AFTER", CareerHubModel.short_date(str(retry))])
		var contract := CareerTransfers.contract_status_label(offer.get("contract_status"))
		if not contract.is_empty():
			extras.append(["CONTRACT", contract])
		var execute_on = offer.get("execute_on")
		if execute_on != null and not str(execute_on).is_empty():
			extras.append(["TRANSFER", CareerHubModel.short_date(str(execute_on))])
		return extras


	func _extra(caption: String, value: String) -> Control:
		var line := HBoxContainer.new()
		var caption_label := _label(caption, UiTheme.inter(500), 16, UiTokens.INK_2)
		caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(caption_label)
		var value_label := _label(value, UiTheme.inter(700), 16, UiTokens.INK)
		value_label.clip_text = false
		value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		line.add_child(value_label)
		return line


# Our own transfer list (prototype TransferListed.svelte): status dot,
# TRANSFER/LOAN kind, position, photo + name, age, date, and the single
# REMOVE FROM LIST accordion action.
class ListedRow extends Control:
	signal activated(player_id: String)
	signal action_requested(id: String)
	signal focused(player_id: String)

	const HEAD_H := 52.0
	const PAD_X := 16.0
	const COL_GAP := 10.0
	const DOT_W := 26.0
	const KIND_W := 92.0
	const POS_W := 46.0
	const AGE_W := 62.0
	const DATE_W := 62.0
	const PHOTO_W := 34.0
	const PHOTO_H := 44.0

	var row: Dictionary = {}
	var _player_id := ""
	var _open := false
	var _actions: Array[CareerSentOfferRow.AccAction] = []
	var _bg: Panel
	var _rail: ColorRect
	var _head: Button
	var _dot: ColorRect
	var _kind: Label
	var _pos: Label
	var _photo: CareerPlayerCard.Photo
	var _name: Label
	var _age: Label
	var _date: Label
	var _acc: PanelContainer
	var _height_tween: Tween


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size.y = HEAD_H
		_build()


	func setup(next_row: Dictionary, date: String) -> void:
		row = next_row
		_player_id = str(row.get("player_id", row.get("id", "")))
		var status := str(row.get("status", ""))
		_dot.color = Color("a66a00") if status == "loan" else UiTokens.RAIL
		_kind.text = ("LOAN" if status == "loan" else "TRANSFER")
		_pos.text = CareerPlayerCard.position_code(str(row.get("position", "")),
			str(row.get("position_group", "")))
		_photo.show_texture(CareerPlayerCard.face_texture(row))
		_name.text = str(row.get("name", "")).to_upper()
		_age.text = str(row.get("age", "—"))
		_date.text = CareerHubModel.short_date(date)
		_build_accordion()
		_sync_height()
		_apply_state()
		_layout()


	func offer_id() -> String:
		return _player_id


	func set_open(value: bool) -> void:
		if _open == value:
			return
		_open = value
		_build_accordion()
		_sync_height(true)
		_apply_state()


	func is_open() -> bool:
		return _open


	func action_ids() -> Array:
		var ids: Array = []
		for action in _actions:
			ids.append(action.id)
		return ids


	func action_buttons() -> Array:
		return _actions


	func action_label(id: String) -> String:
		for action in _actions:
			if action.id == id:
				return action.label_text()
		return ""


	func action_enabled(id: String) -> bool:
		for action in _actions:
			if action.id == id:
				return action.enabled
		return false


	func action_ticket(id: String) -> String:
		return ""


	func focus_header() -> void:
		_head.grab_focus()


	func focus_first_action() -> void:
		for action in _actions:
			action.grab_focus()
			return


	func header() -> Control:
		return _head


	func _build() -> void:
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_rail = ColorRect.new()
		_rail.color = UiTokens.RAIL
		_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rail)
		_head = Button.new()
		_head.name = "Head"
		_head.flat = true
		_head.text = ""
		_head.focus_mode = Control.FOCUS_ALL
		_head.mouse_filter = Control.MOUSE_FILTER_STOP
		_head.clip_contents = true
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			_head.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_head.pressed.connect(func() -> void: activated.emit(_player_id))
		_head.focus_entered.connect(_on_head_focused)
		_head.focus_exited.connect(_apply_state)
		_head.mouse_entered.connect(_head.grab_focus)
		add_child(_head)
		_dot = ColorRect.new()
		_dot.color = UiTokens.RAIL
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot.size = Vector2(9.0, 9.0)
		_head.add_child(_dot)
		_kind = _label(UiTheme.inter(600), 16, UiTokens.INK_2)
		_pos = _label(UiTheme.inter(700), 16, UiTokens.INK)
		_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_photo = CareerPlayerCard.Photo.new()
		_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_head.add_child(_photo)
		_name = _label(UiTheme.barlow(700), 20, UiTokens.INK)
		_age = _label(UiTheme.inter(700), 16, UiTokens.INK)
		_age.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_date = _label(UiTheme.inter(600), 16, UiTokens.INK_2)
		_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_acc = PanelContainer.new()
		_acc.name = "Accordion"
		_acc.mouse_filter = Control.MOUSE_FILTER_PASS
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.168627, 0.192157, 0.341176)
		box.content_margin_left = 16.0
		box.content_margin_right = 16.0
		box.content_margin_top = 10.0
		box.content_margin_bottom = 14.0
		_acc.add_theme_stylebox_override(&"panel", box)
		_acc.visible = false
		add_child(_acc)
		resized.connect(_layout)
		_layout()


	func _label(font: Font, font_size: int, color: Color) -> Label:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", color)
		_head.add_child(label)
		return label


	func _build_accordion() -> void:
		for child in _acc.get_children():
			_acc.remove_child(child)
			child.queue_free()
		_actions.clear()
		if not _open:
			_acc.visible = false
			return
		_acc.visible = true
		var action := CareerSentOfferRow.AccAction.new()
		action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		action.custom_minimum_size.x = 260.0
		_acc.add_child(action)
		action.setup({"id": "remove", "label": "REMOVE FROM LIST"})
		action.pressed.connect(func() -> void: action_requested.emit("remove"))
		_actions.append(action)


	func _layout() -> void:
		if _bg == null or size.x <= 0.0:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		_head.position = Vector2.ZERO
		_head.size = Vector2(size.x, HEAD_H)
		var inner := maxf(0.0, size.x - PAD_X * 2.0)
		var flex := maxf(0.0, inner - DOT_W - KIND_W - POS_W - AGE_W - DATE_W - COL_GAP * 5.0)
		var x := PAD_X
		_dot.position = Vector2(x + (DOT_W - 9.0) * 0.5, (HEAD_H - 9.0) * 0.5)
		x += DOT_W + COL_GAP
		_kind.position = Vector2(x, 0.0)
		_kind.size = Vector2(KIND_W, HEAD_H)
		x += KIND_W + COL_GAP
		_pos.position = Vector2(x, 0.0)
		_pos.size = Vector2(POS_W, HEAD_H)
		x += POS_W + COL_GAP
		_photo.position = Vector2(x, (HEAD_H - PHOTO_H) * 0.5)
		_photo.size = Vector2(PHOTO_W, PHOTO_H)
		_name.position = Vector2(x + PHOTO_W + 10.0, 0.0)
		_name.size = Vector2(maxf(40.0, flex - PHOTO_W - 10.0), HEAD_H)
		x += flex + COL_GAP
		_age.position = Vector2(x, 0.0)
		_age.size = Vector2(AGE_W, HEAD_H)
		x += AGE_W + COL_GAP
		_date.position = Vector2(x, 0.0)
		_date.size = Vector2(DATE_W, HEAD_H)
		_acc.position = Vector2(0.0, HEAD_H)
		_acc.size = Vector2(size.x, maxf(0.0, size.y - HEAD_H))


	# The row grows instead of letting the panel slide over the next offer: the
	# height tween makes the list below reflow while the panel fades in.
	func _sync_height(animate := false) -> void:
		var target := HEAD_H
		if _open:
			_acc.visible = true
			_acc.custom_minimum_size.x = size.x
			var height := maxf(0.0, _acc.get_combined_minimum_size().y)
			_acc.size = Vector2(size.x, height)
			target = HEAD_H + height
		elif not animate:
			_acc.visible = false
		if _height_tween != null and _height_tween.is_valid():
			_height_tween.kill()
		if not animate or UiTransition.instant or not is_inside_tree():
			custom_minimum_size.y = target
			return
		_height_tween = create_tween()
		_height_tween.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT if _open else Tween.EASE_IN)
		_height_tween.tween_property(self, "custom_minimum_size:y", target,
			0.2 if _open else 0.16)
		if not _open:
			_height_tween.tween_callback(func() -> void:
				if not _open:
					_acc.visible = false)


	func _apply_state() -> void:
		if _bg == null:
			return
		var lit := _head.has_focus() or _open
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL if lit else UiTokens.TILE
		box.border_color = Color(UiTokens.INK, 0.10)
		box.border_width_bottom = 0 if lit else 1
		box.anti_aliasing = true
		_bg.add_theme_stylebox_override(&"panel", box)
		_rail.visible = not lit
		_name.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if lit else UiTokens.INK)
		for label in [_kind, _age, _date]:
			label.add_theme_color_override(&"font_color",
				UiTokens.FOCUS_INK_2 if lit else UiTokens.INK_2)
		_pos.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if lit else UiTokens.INK)
		_photo.tone = UiTokens.FOCUS_INK_2 if lit else UiTokens.INK_2
		_photo.queue_redraw()


	func _on_head_focused() -> void:
		_apply_state()
		focused.emit(_player_id)


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				_head.grab_focus()
				accept_event()


# Screen ---------------------------------------------------------------------

var career: Career
var catalog: TeamCatalog

var _tab := "shortlist"
var _zone := "tabs"
var _tab_focus := 0
var _focus_row := -1
var _selected_id := ""
var _open_id := ""
var _unread := 0
var _error := ""

var _shortlist_data: Array = []
var _short_cards: Array[CareerPlayerCard] = []
var _short_selected := ""
var _row_data: Array = []
var _row_nodes: Array = []
var _rows_box: VBoxContainer
var _amount_row: Dictionary = {}

var _tabs_panel: Panel
var _tab_bar: UiTabBar

var _short_box: Control
var _short_left: Panel
var _short_title: Label
var _short_meta: Label
var _short_scroll: ScrollContainer
var _short_grid: GridContainer
var _short_pane: CareerPlayerPane

var _offers_box: Control
var _offers_main: Panel
var _offer_head: Array[Label] = []
var _offer_scroll: ScrollContainer
var _offer_rows: VBoxContainer
var _detail: Detail

var _listed_box: Panel
var _listed_head: Array[Label] = []
var _listed_scroll: ScrollContainer
var _listed_rows: VBoxContainer

var _empty: Panel
var _empty_title: Label
var _empty_text: Label
var _error_label: Label

var _actions: CareerPlayerActions
var _amount: CareerAmountModal
var _appear_tween: Tween
var _shift_tween: Tween


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


# `payload`: {tab?: "shortlist"|"sent"|"received"|"listed"}. The host may
# reopen the screen without a payload (a refresh) and the tab is kept then.
func open(next_career: Career, next_catalog: TeamCatalog, payload := {}) -> void:
	career = next_career
	catalog = next_catalog
	_error = ""
	var wanted := str(payload.get("tab", ""))
	if not wanted.is_empty() and _tab_index(wanted) >= 0:
		_tab = wanted
	_open_id = ""
	_focus_row = -1
	if not is_node_ready():
		return
	_refresh()
	_layout()
	_focus_tab(_tab_index(_tab))


func close() -> void:
	for tween in [_appear_tween, _shift_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if _amount != null and _amount.is_open():
		_amount.close()
	if _actions != null and _actions.is_open():
		_actions.close()
	release_focus()


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
	if _zone == "actions" and not _open_id.is_empty():
		return [
			{"keys": ["D-PAD"] if gamepad else ["↑", "↓"], "label": "actions"},
			{"keys": select, "label": "apply"},
			{"keys": back, "label": "close"},
		]
	if _tab == "shortlist":
		return [
			{"keys": ["D-PAD"] if gamepad else ["↑", "↓", "←", "→"], "label": "players"},
			{"keys": ["LB", "RB"] if gamepad else ["Q", "E"], "label": "tabs"},
			{"keys": select, "label": "actions"},
			{"keys": back, "label": "back"},
		]
	return [
		{"keys": ["D-PAD"] if gamepad else ["↑", "↓"], "label": "navigate"},
		{"keys": ["LB", "RB"] if gamepad else ["Q", "E"], "label": "tabs"},
		{"keys": select, "label": "open"},
		{"keys": back, "label": "back"},
	]


func focus_initial() -> void:
	if _tab_bar == null or _tab_bar.tab_count() == 0:
		return
	_focus_tab(_tab_index(_tab))


func status() -> String:
	return _error


func status_error() -> bool:
	return not _error.is_empty()


# Test seams ---------------------------------------------------------------

func tab() -> String:
	return _tab


func tab_ids() -> Array:
	var ids: Array = []
	for tab in TABS:
		ids.append(str(tab["id"]))
	return ids


func tab_label(id: String) -> String:
	var index := _tab_index(id)
	return "" if index < 0 else str(TABS[index].get("label", ""))


func unread_badge() -> int:
	return _unread


func tab_badge(id: String) -> int:
	return _unread if id == "received" else 0


func card_count() -> int:
	return _short_cards.size()


func card_ids() -> Array:
	var ids: Array = []
	for card in _short_cards:
		ids.append(card.player_id())
	return ids


func amount_open() -> bool:
	return _amount != null and _amount.is_open()


func focused_tab() -> int:
	return _tab_focus


func row_count() -> int:
	return _row_nodes.size()


func row_ids() -> Array:
	var ids: Array = []
	for node in _row_nodes:
		ids.append(str(node.offer_id()))
	return ids


func selected_id() -> String:
	return _selected_id


func open_id() -> String:
	return _open_id


func zone() -> String:
	return _zone


func focused_row() -> int:
	return _focus_row


func is_empty_state() -> bool:
	return _empty.visible


func empty_title() -> String:
	return str(_empty_title.text)


func empty_text() -> String:
	return str(_empty_text.text)


func detail_title() -> String:
	return "" if _detail == null else _detail.title()


func action_ids() -> Array:
	var node = _open_node()
	return [] if node == null else node.action_ids()


func action_label(id: String) -> String:
	var node = _open_node()
	return "" if node == null else str(node.action_label(id))


func action_enabled(id: String) -> bool:
	var node = _open_node()
	return false if node == null else bool(node.action_enabled(id))


func action_ticket(id: String) -> String:
	var node = _open_node()
	return "" if node == null else str(node.action_ticket(id))


func focus_row_at(index: int) -> void:
	_focus_item_at(index)


# Build ----------------------------------------------------------------------

func _build() -> void:
	_tabs_panel = Panel.new()
	_tabs_panel.name = "Tabs"
	# The strip itself is drawn by the shared TabBar; the panel stays as the
	# fade target for the whole tab row.
	_tabs_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	add_child(_tabs_panel)
	# Same component as the hub's main tabs: strip, sliding plate, focus look.
	_tab_bar = UiTabBar.new()
	_tab_bar.name = "TabBar"
	add_child(_tab_bar)
	var labels: Array[String] = []
	for data in TABS:
		labels.append(str(data["label"]))
	_tab_bar.setup(labels)
	_tab_bar.tab_selected.connect(_on_tab_selected)

	_short_box = Control.new()
	_short_box.name = "Shortlist"
	add_child(_short_box)
	_short_left = Panel.new()
	_short_left.name = "Cards"
	var left_box := StyleBoxFlat.new()
	left_box.bg_color = UiTokens.TILE
	left_box.shadow_color = UiTokens.SHADOW
	left_box.shadow_size = 32
	left_box.shadow_offset = Vector2(0.0, 24.0)
	_short_left.add_theme_stylebox_override(&"panel", left_box)
	_short_box.add_child(_short_left)
	_short_title = _label(_short_left, "SHORTLIST", UiTheme.barlow(700), 30, UiTokens.INK)
	_short_meta = _label(_short_left, "", UiTheme.inter(600), 16, UiTokens.INK_2)
	_short_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_short_scroll = ScrollContainer.new()
	_short_scroll.name = "List"
	_short_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_short_left.add_child(_short_scroll)
	_short_grid = GridContainer.new()
	_short_grid.name = "Grid"
	_short_grid.columns = COLUMNS
	_short_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_short_grid.add_theme_constant_override(&"h_separation", int(CARD_GAP))
	_short_grid.add_theme_constant_override(&"v_separation", int(CARD_GAP))
	_short_scroll.add_child(_short_grid)
	_short_pane = CareerPlayerPane.new()
	_short_pane.name = "Pane"
	_short_box.add_child(_short_pane)

	_offers_box = Control.new()
	_offers_box.name = "Offers"
	add_child(_offers_box)
	_offers_main = Panel.new()
	_offers_main.name = "Table"
	var main_box := StyleBoxFlat.new()
	main_box.bg_color = UiTokens.TILE
	main_box.shadow_color = UiTokens.SHADOW
	main_box.shadow_size = 32
	main_box.shadow_offset = Vector2(0.0, 24.0)
	_offers_main.add_theme_stylebox_override(&"panel", main_box)
	_offers_box.add_child(_offers_main)
	for text in ["STATUS", "", "KIND", "PLAYER", "POS", "DATE"]:
		_offer_head.append(_label(_offers_main, text, UiTheme.inter(600), 14, UiTokens.INK_2))
	_offer_scroll = ScrollContainer.new()
	_offer_scroll.name = "List"
	_offer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offers_main.add_child(_offer_scroll)
	_offer_rows = VBoxContainer.new()
	_offer_rows.name = "Rows"
	_offer_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_rows.add_theme_constant_override(&"separation", 0)
	_offer_scroll.add_child(_offer_rows)
	_detail = Detail.new()
	_detail.name = "Detail"
	_offers_box.add_child(_detail)

	_listed_box = Panel.new()
	_listed_box.name = "Listed"
	var listed_box := StyleBoxFlat.new()
	listed_box.bg_color = UiTokens.TILE
	listed_box.shadow_color = UiTokens.SHADOW
	listed_box.shadow_size = 32
	listed_box.shadow_offset = Vector2(0.0, 24.0)
	_listed_box.add_theme_stylebox_override(&"panel", listed_box)
	add_child(_listed_box)
	for text in ["", "KIND", "POS", "PLAYER", "AGE", "DATE"]:
		_listed_head.append(_label(_listed_box, text, UiTheme.inter(600), 14, UiTokens.INK_2))
	_listed_scroll = ScrollContainer.new()
	_listed_scroll.name = "List"
	_listed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_listed_box.add_child(_listed_scroll)
	_listed_rows = VBoxContainer.new()
	_listed_rows.name = "Rows"
	_listed_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_listed_rows.add_theme_constant_override(&"separation", 0)
	_listed_scroll.add_child(_listed_rows)

	_empty = Panel.new()
	_empty.name = "Empty"
	var empty_box := StyleBoxFlat.new()
	empty_box.bg_color = UiTokens.TILE
	empty_box.shadow_color = UiTokens.SHADOW
	empty_box.shadow_size = 22
	empty_box.shadow_offset = Vector2(0.0, 16.0)
	_empty.add_theme_stylebox_override(&"panel", empty_box)
	add_child(_empty)
	_empty_title = _label(_empty, "", UiTheme.barlow(800), 34, UiTokens.INK)
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_text = _label(_empty, "", UiTheme.inter(500), 15, UiTokens.INK_2)
	_empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_text.clip_text = false
	_empty_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_error_label = _label(self, "", UiTheme.inter(600), 14, Color("b23a48"))
	_error_label.visible = false

	_actions = CareerPlayerActions.new()
	_actions.name = "PlayerActions"
	_actions.navigate.connect(_on_actions_navigate)
	_actions.changed.connect(_on_actions_changed)
	_actions.scout_requested.connect(_on_scout_requested)
	_actions.closed.connect(_on_actions_closed)
	add_child(_actions)

	_amount = CareerAmountModal.new()
	_amount.name = "AmountModal"
	_amount.applied.connect(_on_amount_applied)
	_amount.closed.connect(_on_amount_closed)
	add_child(_amount)


func _label(parent: Control, text: String, font: Font, font_size: int,
		color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label


func _layout() -> void:
	if _tabs_panel == null or size.x <= 0.0:
		return
	_tabs_panel.position = Vector2.ZERO
	_tabs_panel.size = Vector2(size.x, TABS_H)
	_layout_tabs()
	var top := TABS_H + GAP
	var height := maxf(0.0, size.y - top)
	_error_label.visible = not _error.is_empty()
	if _error_label.visible:
		height = maxf(0.0, height - LOAD_ERRORS)
		_error_label.position = Vector2(0.0, top + height)
		_error_label.size = Vector2(size.x, LOAD_ERRORS)
	for box in [_short_box, _offers_box, _listed_box, _empty]:
		(box as Control).position = Vector2(0.0, top)
		(box as Control).size = Vector2(size.x, height)

	var left_w := floorf(maxf(220.0, (size.x - GAP) * DETAIL_RATIO))
	var inner_w := maxf(0.0, left_w - PAD * 2.0)
	_short_left.position = Vector2.ZERO
	_short_left.size = Vector2(left_w, height)
	_short_title.position = Vector2(PAD, 10.0)
	_short_title.size = Vector2(inner_w * 0.6, 32.0)
	_short_meta.position = Vector2(PAD, 12.0)
	_short_meta.size = Vector2(inner_w, 24.0)
	var list_top := 52.0
	_short_scroll.position = Vector2(PAD, list_top)
	_short_scroll.size = Vector2(inner_w, maxf(0.0, height - list_top - PAD))
	_short_pane.position = Vector2(left_w + GAP, 0.0)
	_short_pane.size = Vector2(maxf(0.0, size.x - left_w - GAP), height)

	_offers_main.position = Vector2.ZERO
	_offers_main.size = Vector2(left_w, height)
	_layout_offer_head()
	_offer_scroll.position = Vector2(0.0, HEAD_H)
	_offer_scroll.size = Vector2(left_w, maxf(0.0, height - HEAD_H))
	_detail.position = Vector2(left_w + GAP, 0.0)
	_detail.size = Vector2(maxf(0.0, size.x - left_w - GAP), height)

	_listed_box.position = Vector2(0.0, top)
	_listed_box.size = Vector2(size.x, height)
	_layout_listed_head()
	_listed_scroll.position = Vector2(0.0, HEAD_H)
	_listed_scroll.size = Vector2(size.x, maxf(0.0, height - HEAD_H))

	_empty_title.position = Vector2(size.x * 0.5 - 260.0,
		maxf(20.0, height * 0.5 - 50.0))
	_empty_title.size = Vector2(520.0, 40.0)
	_empty_text.position = _empty_title.position + Vector2(0.0, 44.0)
	_empty_text.size = Vector2(520.0, 60.0)


func _layout_tabs() -> void:
	if _tab_bar == null:
		return
	_tab_bar.position = Vector2.ZERO
	_tab_bar.size = Vector2(size.x, TABS_H)
	# The badge changes the strip width, so re-fit; animate the marker so a tab
	# switch is not snapped into place by the refresh that follows it.
	_tab_bar.fit_width(true)

func _layout_offer_head() -> void:
	var width := _offers_main.size.x
	if width <= 0.0:
		return
	var inner := maxf(0.0, width - 32.0)
	var flex := maxf(0.0, inner - 56.0 - 34.0 - 52.0 - 58.0 - 50.0)
	var kind_w := maxf(70.0, flex * 0.74 / 2.54)
	var player_w := maxf(120.0, flex - kind_w)
	var xs: Array = [16.0, 16.0 + 56.0 + 10.0, 16.0 + 56.0 + 10.0 + 34.0 + 10.0]
	xs.append(xs[2] + kind_w + 10.0)
	xs.append(xs[3] + player_w + 10.0)
	xs.append(xs[4] + 52.0 + 10.0)
	var widths: Array = [56.0, 34.0, kind_w, player_w, 52.0, 58.0]
	for index in _offer_head.size():
		var label := _offer_head[index]
		label.position = Vector2(xs[index], 0.0)
		label.size = Vector2(widths[index], HEAD_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if index == 5 \
			else HORIZONTAL_ALIGNMENT_CENTER if index == 4 else HORIZONTAL_ALIGNMENT_LEFT


func _layout_listed_head() -> void:
	var width := _listed_box.size.x
	if width <= 0.0:
		return
	var inner := maxf(0.0, width - 32.0)
	var flex := maxf(0.0, inner - 26.0 - 92.0 - 46.0 - 62.0 - 62.0 - 50.0)
	var xs: Array = [16.0]
	xs.append(16.0 + 26.0 + 10.0)
	xs.append(xs[1] + 92.0 + 10.0)
	xs.append(xs[2] + 46.0 + 10.0)
	xs.append(xs[3] + flex + 10.0)
	xs.append(xs[4] + 62.0 + 10.0)
	var widths: Array = [26.0, 92.0, 46.0, flex, 62.0, 62.0]
	for index in _listed_head.size():
		var label := _listed_head[index]
		label.position = Vector2(xs[index], 0.0)
		label.size = Vector2(widths[index], HEAD_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if index == 5 \
			else HORIZONTAL_ALIGNMENT_CENTER if index == 4 else HORIZONTAL_ALIGNMENT_LEFT


# Data ----------------------------------------------------------------------

func _tab_index(id: String) -> int:
	for index in TABS.size():
		if str(TABS[index]["id"]) == id:
			return index
	return -1


func _refresh() -> void:
	_unread = CareerIncomingOffers.unread_count(career) if career != null else 0
	_refresh_tabs()
	match _tab:
		"shortlist":
			_refresh_shortlist()
		"sent", "received":
			_refresh_offers()
		"listed":
			_refresh_listed()
	_update_visibility()


func _refresh_tabs() -> void:
	if _tab_bar == null:
		return
	var index := _tab_index(_tab)
	if _tab_bar.get_active_tab() != index:
		_tab_bar.select_tab(index, false)
	_tab_bar.set_badge(_tab_index("received"), _unread)
	_layout_tabs()


func _refresh_shortlist() -> void:
	for card in _short_cards:
		_short_grid.remove_child(card)
		card.queue_free()
	_short_cards.clear()
	_shortlist_data = CareerTransfers.shortlist_rows(career, catalog) if career != null \
		else []
	if _shortlist_index(_short_selected) < 0:
		_short_selected = _shortlist_id(_shortlist_data[0]) \
			if not _shortlist_data.is_empty() else ""
	for item in _shortlist_data:
		var card := CareerPlayerCard.new()
		card.custom_minimum_size.y = CARD_H
		_short_grid.add_child(card)
		card.setup(item)
		card.pressed.connect(_on_card_pressed)
		card.focus_entered.connect(_on_card_focused.bind(card))
		_short_cards.append(card)
	_short_title.text = "SHORTLIST"
	var parts: Array[String] = [str(_shortlist_data.size())]
	if career != null and not career.date.is_empty():
		parts.append(CareerHubModel.month_label(career.date))
	_short_meta.text = " · ".join(parts)
	_refresh_pane()


func _refresh_offers() -> void:
	_clear_rows()
	_row_data = CareerTransfers.sent_offer_rows(career, catalog) if _tab == "sent" \
		else CareerIncomingOffers.received_rows(career, catalog)
	_rows_box = _offer_rows
	for data in _row_data:
		var node
		if _tab == "sent":
			node = CareerSentOfferRow.new()
		else:
			node = CareerReceivedOfferRow.new()
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows_box.add_child(node)
		node.setup(data)
		node.activated.connect(_on_row_activated)
		node.action_requested.connect(_on_row_action_requested)
		node.focused.connect(_on_row_focused)
		_row_nodes.append(node)
	_sync_selection()
	_refresh_detail()


func _refresh_listed() -> void:
	_clear_rows()
	_row_data = CareerTransfers.listed_rows(career, catalog) if career != null else []
	_rows_box = _listed_rows
	var date := career.date if career != null else ""
	for data in _row_data:
		var node := ListedRow.new()
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows_box.add_child(node)
		node.setup(data, date)
		node.activated.connect(_on_row_activated)
		node.action_requested.connect(_on_row_action_requested)
		node.focused.connect(_on_row_focused)
		_row_nodes.append(node)
	_sync_selection()


func _clear_rows() -> void:
	for node in _row_nodes:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
	_row_nodes.clear()
	_row_data.clear()
	_open_id = ""
	_focus_row = -1


func _sync_selection() -> void:
	if _row_data.is_empty():
		_selected_id = ""
		_focus_row = -1
		return
	if _row_index(_selected_id) < 0:
		_selected_id = str(_row_nodes[0].offer_id())
	_focus_row = _row_index(_selected_id)


func _update_visibility() -> void:
	var count := _shortlist_data.size() if _tab == "shortlist" else _row_data.size()
	var empty := count == 0
	var pair: Array = EMPTY.get(_tab, ["", ""])
	_empty_title.text = str(pair[0])
	_empty_text.text = str(pair[1])
	for box in [_short_box, _offers_box, _listed_box]:
		(box as Control).visible = false
	_empty.visible = empty
	if empty:
		_layout()
		return
	match _tab:
		"shortlist":
			_short_box.visible = true
		"sent", "received":
			_offers_box.visible = true
		"listed":
			_listed_box.visible = true
	_layout()


func _refresh_pane() -> void:
	var index := _shortlist_index(_short_selected)
	if index < 0:
		_short_pane.visible = false
		return
	_short_pane.visible = true
	_short_pane.setup(_shortlist_data[index],
		{"date": career.date if career != null else ""})
	for card in _short_cards:
		card.set_selected(card.player_id() == _short_selected)


func _refresh_detail() -> void:
	if _detail == null:
		return
	if _tab != "sent" and _tab != "received":
		return
	var index := _row_index(_selected_id)
	if index < 0:
		_detail.setup({}, _tab)
		return
	_detail.setup(_row_data[index], _tab)


func _row_index(id: String) -> int:
	for index in _row_nodes.size():
		if str(_row_nodes[index].offer_id()) == id:
			return index
	return -1


func _shortlist_id(item: Dictionary) -> String:
	return str(item.get("player_id", item.get("id", "")))


func _shortlist_index(player_id: String) -> int:
	for index in _shortlist_data.size():
		if _shortlist_id(_shortlist_data[index]) == player_id:
			return index
	return -1


func _row_by_id(id: String) -> Dictionary:
	var index := _row_index(id)
	return {} if index < 0 else _row_data[index]


func _open_node() -> Variant:
	var index := _row_index(_open_id)
	return null if index < 0 else _row_nodes[index]


# Focus / selection ---------------------------------------------------------

func _focus_tab(index: int) -> void:
	if _tab_bar == null or _tab_bar.tab_count() == 0:
		return
	_tab_focus = clampi(index, 0, _tab_bar.tab_count() - 1)
	_zone = "tabs"
	_focus_row = -1
	_tab_bar.focus_tab(_tab_focus)


func _on_tab_selected(index: int) -> void:
	_tab_focus = index
	if index < 0 or index >= TABS.size():
		return
	var id := str(TABS[index]["id"])
	if id != _tab:
		_set_tab(id)


func _on_tab_focused(index: int) -> void:
	_tab_focus = index
	_zone = "tabs"
	_focus_row = -1


func _focus_item_at(index: int) -> void:
	if _tab == "shortlist":
		_focus_card_at(index)
		return
	if index < 0 or index >= _row_nodes.size():
		return
	_zone = "list"
	_focus_row = index
	_row_nodes[index].focus_header()
	_scroll_to(_row_nodes[index])


func _focus_card_at(index: int) -> void:
	if index < 0 or index >= _short_cards.size():
		return
	_zone = "list"
	_focus_row = index
	_short_cards[index].grab_focus()
	_short_scroll.ensure_control_visible.call_deferred(_short_cards[index])


func _scroll_to(node: Control) -> void:
	var scroll := _offer_scroll if _tab == "sent" or _tab == "received" else _listed_scroll
	scroll.ensure_control_visible.call_deferred(node)


func _select_row(id: String) -> void:
	_selected_id = id
	_focus_row = _row_index(id)
	_refresh_detail()


func _select_card(player_id: String) -> void:
	_short_selected = player_id
	_refresh_pane()


# Rows / accordions ---------------------------------------------------------

func _on_row_focused(id: String) -> void:
	_select_row(id)
	_zone = "actions" if _open_id == id else "list"


func _on_row_activated(id: String) -> void:
	var index := _row_index(id)
	if index < 0:
		return
	_select_row(id)
	if _open_id == id:
		_close_open()
		_focus_item_at(index)
		return
	_open_row(index)


func _open_row(index: int) -> void:
	var node = _row_nodes[index]
	var id := str(node.offer_id())
	if not _open_id.is_empty() and _open_id != id:
		var previous = _open_node()
		if previous != null:
			previous.set_open(false)
	if _tab == "received":
		_ack(index)
	_open_id = id
	node.set_open(true)
	_select_row(id)
	if node.action_ids().is_empty():
		_zone = "list"
		node.focus_header()
	else:
		_zone = "actions"
		node.focus_first_action()
	_scroll_to(node)


func _close_open() -> void:
	var node = _open_node()
	if node != null:
		node.set_open(false)
	_open_id = ""


# Opening an incoming offer clears its unread badge (prototype incoming_ack).
func _ack(index: int) -> void:
	var row: Dictionary = _row_data[index]
	if not bool(row.get("unread", false)):
		return
	var result := CareerIncomingOffers.ack(career, str(row.get("offer_id", "")), catalog)
	if not bool(result.get("ok", false)):
		_set_error(str(result.get("error", "")))
		return
	row["unread"] = false
	_unread = CareerIncomingOffers.unread_count(career)
	_refresh_tabs()
	_row_nodes[index].setup(row)
	_refresh_detail()
	changed.emit()


# Actions -------------------------------------------------------------------

func _on_row_action_requested(id: String) -> void:
	match _tab:
		"sent":
			_sent_action(id)
		"received":
			_received_action(id)
		"listed":
			_listed_action(id)


func _sent_action(id: String) -> void:
	var row := _row_by_id(_open_id)
	if row.is_empty():
		return
	var offer: Dictionary = row.get("offer", {}) if row.get("offer") is Dictionary else {}
	var player: Dictionary = row.get("player", {}) if row.get("player") is Dictionary else {}
	var offer_id := str(row.get("offer_id", ""))
	match id:
		"accept_counter":
			_after_mutation(CareerTransferOffers.accept_counter(career, catalog, offer_id))
		"withdraw":
			_after_mutation(CareerTransferOffers.withdraw(career, catalog, offer_id))
		"reoffer":
			var kind := str(offer.get("kind", "transfer"))
			var preset: Dictionary = {}
			var counter = offer.get("counter")
			if kind == "loan":
				preset["loan_fee"] = int((counter as Dictionary).get("loan_fee",
					(counter as Dictionary).get("amount", offer.get("loan_fee", 0)))) \
					if counter is Dictionary else int(offer.get("loan_fee", offer.get("amount", 0)))
				preset["wage_share"] = int((counter as Dictionary).get("wage_share",
					offer.get("wage_share", 50))) if counter is Dictionary \
					else int(offer.get("wage_share", 50))
			else:
				preset["amount"] = int((counter as Dictionary).get("amount",
					offer.get("amount", 0))) if counter is Dictionary \
					else int(offer.get("amount", 0))
			_close_open()
			navigate.emit("offer", {
				"player_id": str(player.get("player_id", "")),
				"kind": kind,
				"preset": preset,
			})
		"contract":
			_close_open()
			navigate.emit("contract", {
				"offer_id": offer_id,
				"player_id": str(player.get("player_id", "")),
				"kind": str(offer.get("kind", "transfer")),
			})


func _received_action(id: String) -> void:
	var row := _row_by_id(_open_id)
	if row.is_empty():
		return
	var offer_id := str(row.get("offer_id", ""))
	match id:
		"accept":
			_after_mutation(CareerIncomingOffers.accept(career, catalog, offer_id))
		"refuse":
			_after_mutation(CareerIncomingOffers.refuse(career, catalog, offer_id))
		"counter":
			_open_counter(row)


func _listed_action(id: String) -> void:
	if id != "remove":
		return
	var row := _row_by_id(_open_id)
	if row.is_empty():
		return
	_after_mutation(CareerTransfers.set_status(career, catalog,
		str(row.get("player_id", row.get("id", ""))), ""))


func _after_mutation(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_set_error(str(result.get("error", "")))
		return
	_set_error("")
	var keep := _selected_id
	changed.emit()
	_refresh()
	if _row_index(keep) >= 0:
		_focus_item_at(_row_index(keep))
	elif not _row_nodes.is_empty():
		_focus_item_at(0)
	else:
		_focus_tab(_tab_index(_tab))


func _open_counter(row: Dictionary) -> void:
	var demand: Dictionary = row.get("demand", {}) if row.get("demand") is Dictionary else {}
	var value := int(demand.get("amount", 0))
	_amount_row = row
	_amount.open(value, {
		"title": "COUNTER-OFFER",
		"hint": "Must be higher than the current offer.",
		"confirm_label": "SEND",
		"min": int(row.get("amount", 0)) + 1,
		"max": 999999999,
	})
	state_changed.emit()


func _on_amount_applied(value: int) -> void:
	var row := _amount_row
	if row.is_empty():
		return
	var result := CareerIncomingOffers.counter(career,
		str(row.get("offer_id", "")), value, catalog)
	if not bool(result.get("ok", false)):
		# Keep the pending counter so the open modal can be corrected.
		_set_error(str(result.get("error", "")))
		return
	_amount_row = {}
	_set_error("")
	_close_open()
	changed.emit()
	_refresh()
	if not _row_nodes.is_empty():
		_focus_item_at(mini(_row_index(_selected_id), _row_nodes.size() - 1))
	else:
		_focus_tab(_tab_index("received"))


func _on_amount_closed() -> void:
	_amount_row = {}
	state_changed.emit()


func _set_error(text: String) -> void:
	_error = text
	if _error_label == null:
		return
	_error_label.text = text.to_upper()
	_layout()


# Shortlist actions ---------------------------------------------------------

func _open_actions() -> void:
	if _actions == null or _actions.is_open():
		return
	var index := _shortlist_index(_short_selected)
	if index < 0 or not is_inside_tree() or not is_visible_in_tree():
		return
	_focus_row = index
	_actions.setup(career, catalog, _shortlist_data[index], {
		"date": career.date if career != null else "",
	})
	_actions.open()
	state_changed.emit()


func _on_actions_navigate(view: String, payload: Dictionary) -> void:
	navigate.emit(view, payload)


func _on_actions_changed() -> void:
	changed.emit()
	_refresh()


func _on_scout_requested(scout_id: String) -> void:
	scout_requested.emit(_actions.player_id(), scout_id)


func _on_actions_closed() -> void:
	var index := _shortlist_index(_short_selected)
	if index >= 0:
		_short_cards[index].grab_focus()
	state_changed.emit()


func _on_card_pressed(player_id: String) -> void:
	_select_card(player_id)
	_open_actions()


func _on_card_focused(card: CareerPlayerCard) -> void:
	_zone = "list"
	_focus_row = _short_cards.find(card)
	_select_card(card.player_id())


# Tab strip ----------------------------------------------------------------

func _set_tab(id: String, focus := true) -> void:
	if id == _tab:
		return
	_tab = id
	_open_id = ""
	_selected_id = ""
	_focus_row = -1
	_zone = "tabs"
	_refresh()
	if focus:
		_focus_tab(_tab_index(id))
	_play_shift(1)


func _cycle_tab(delta: int) -> void:
	var index := _tab_index(_tab)
	_set_tab(str(TABS[posmod(index + delta, TABS.size())]["id"]))


# Input ---------------------------------------------------------------------

func _is_active() -> bool:
	if not is_visible_in_tree():
		return false
	var nav := _ui_nav()
	return nav == null or not nav.is_modal()


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_active():
		return
	if _zone == "actions" and not _open_id.is_empty():
		_move_action(direction)
		return
	if _zone == "tabs":
		if direction == Vector2i.LEFT:
			_cycle_tab(-1)
		elif direction == Vector2i.RIGHT:
			_cycle_tab(1)
		elif direction == Vector2i.DOWN:
			_focus_item_at(0)
		return
	if _tab == "shortlist":
		_move_card(direction)
		return
	if direction == Vector2i.UP:
		if _focus_row <= 0:
			_focus_tab(_tab_index(_tab))
		else:
			_focus_item_at(_focus_row - 1)
	elif direction == Vector2i.DOWN:
		_focus_item_at(_focus_row + 1)


func _move_card(direction: Vector2i) -> void:
	var index := _focus_row
	match direction:
		Vector2i.UP:
			index -= COLUMNS
		Vector2i.DOWN:
			index += COLUMNS
		Vector2i.LEFT:
			index -= 1
		Vector2i.RIGHT:
			index += 1
	if index < 0 or index >= _short_cards.size():
		return
	if (direction == Vector2i.LEFT or direction == Vector2i.RIGHT) \
			and floori(float(index) / COLUMNS) != floori(float(_focus_row) / COLUMNS):
		return
	_focus_card_at(index)


func _move_action(direction: Vector2i) -> void:
	if direction != Vector2i.UP and direction != Vector2i.DOWN:
		return
	var node = _open_node()
	if node == null:
		return
	var buttons: Array = node.action_buttons()
	if buttons.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var index := buttons.find(owner)
	var next := clampi(index + (-1 if direction == Vector2i.UP else 1), 0, buttons.size() - 1)
	buttons[next].grab_focus()


func _on_nav_confirmed() -> void:
	if not _is_active():
		return
	if _zone == "tabs":
		_set_tab(str(TABS[_tab_focus]["id"]))
		return
	if _zone == "actions" and not _open_id.is_empty():
		var owner := get_viewport().gui_get_focus_owner()
		if owner is Button:
			(owner as Button).pressed.emit()
		return
	if _tab == "shortlist":
		_open_actions()
		return
	if _focus_row >= 0 and _focus_row < _row_nodes.size():
		_on_row_activated(str(_row_nodes[_focus_row].offer_id()))


func _on_nav_cancelled() -> void:
	if not _is_active():
		return
	var nav := _ui_nav()
	if nav != null and bool(nav.event_was_modal()):
		return
	if not _open_id.is_empty():
		var index := _row_index(_open_id)
		_close_open()
		if index >= 0:
			_focus_item_at(index)
		return
	closed.emit()


func _on_tab_previous() -> void:
	if _is_active():
		_cycle_tab(-1)


func _on_tab_next() -> void:
	if _is_active():
		_cycle_tab(1)


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if _is_key(event, KEY_Q):
		get_viewport().set_input_as_handled()
		_cycle_tab(-1)
	elif _is_key(event, KEY_E):
		get_viewport().set_input_as_handled()
		_cycle_tab(1)


func _is_key(event: InputEvent, code: Key) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == code or key.physical_keycode == code)


# Motion -------------------------------------------------------------------

func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _play_shift(direction: int) -> void:
	if _instant() or not is_inside_tree():
		return
	var nodes: Array = []
	for box in [_short_box, _offers_box, _listed_box, _empty]:
		if (box as Control).visible:
			nodes.append(box)
	if nodes.is_empty():
		return
	if _shift_tween != null and _shift_tween.is_valid():
		_shift_tween.kill()
	_shift_tween = create_tween().set_parallel(true)
	_shift_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for node in nodes:
		var control := node as Control
		var target := control.position
		control.position = target + Vector2(20.0 * float(signi(direction)), 0.0)
		control.modulate.a = 0.0
		_shift_tween.tween_property(control, "position", target, UiTokens.SCREEN_IN)
		_shift_tween.tween_property(control, "modulate:a", 1.0, UiTokens.SCREEN_OUT)


func _on_visibility_changed() -> void:
	if not visible or not is_inside_tree() or _tabs_panel == null:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not is_ancestor_of(owner):
		_focus_tab(_tab_index(_tab))
	if _instant():
		return
	var nodes: Array = [_tabs_panel, _tab_bar]
	for box in [_short_box, _offers_box, _listed_box, _empty]:
		nodes.append(box)
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	for node in nodes:
		(node as Control).modulate.a = 0.0
	_appear_tween = create_tween().set_parallel(true)
	for index in nodes.size():
		_appear_tween.tween_property(nodes[index], "modulate:a", 1.0,
			UiTokens.SCREEN_OUT).set_delay(0.02 * index)


func _exit_tree() -> void:
	if _amount != null and _amount.is_open():
		_amount.close()
	if _actions != null and _actions.is_open():
		_actions.close()
