class_name CareerTransferContractScreen
extends Control
# Prototype transfers/TransferContractScreen.svelte: the personal-contract
# step after a club accepts an offer (or for a free agent). The left column
# carries the player and the deal (fee, balance after, club, current wage); the
# right column is the contract itself: the player's counter or the editable
# draft (years, weekly wage, squad role, release clause), the player's demand,
# then the action for the current state (submit -> pending, accept counter ->
# accepted, sign -> done). Numbers, steps and roles follow the prototype; the
# host owns routing, animation and the hints bar.

signal closed
signal navigate(view: String, payload: Dictionary)
signal changed

const GAP := 10.0
const PAD := 16.0
const FIELD_H := 64.0
const FIELD_GAP := 2.0
const ACTION_H := 48.0
const ACTION_GAP := 2.0
const HEAD_H := 62.0
const ERROR_H := 30.0
const FOOTER_H := 44.0
const REPLY_H := 126.0
const TERMS_H := 128.0
const INFO_H := 38.0
const INFO_GAP := 1.0
const LEFT_RATIO := 0.39
const LEFT_MIN := 240.0
const LEFT_MAX := 640.0
const PHOTO_W := 80.0
const PHOTO_H := 100.0
const AMOUNT_MAX := 999999999
const MIN_WAGE := 1000
const MAX_WAGE := 2000000
const MIN_CLAUSE_STEP := 100000
const MARK_LOSS := Color("b23a48")
const MARK_WARN := Color("a66a00")

const ROLES := [
	{"id": "key", "label": "KEY PLAYER"},
	{"id": "first", "label": "FIRST TEAM"},
	{"id": "rotation", "label": "ROTATION"},
	{"id": "squad", "label": "SQUAD PLAYER"},
	{"id": "prospect", "label": "PROSPECT"},
]
const FIELD_IDS := ["weekly_wage", "years", "squad_role", "release_clause"]


# 2x2 (or 1x4 compact) terms grid, the prototype's shared ContractTerms.
class Terms extends Control:
	const GAP := 2.0
	var _compact := false
	var _cells: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for index in 4:
			var panel := Panel.new()
			panel.name = "Term%d" % index
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var box := StyleBoxFlat.new()
			box.bg_color = Color(UiTokens.INK, 0.055)
			panel.add_theme_stylebox_override(&"panel", box)
			add_child(panel)
			var caption := Label.new()
			caption.name = "Caption"
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.clip_text = true
			caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			caption.add_theme_font_override(&"font", UiTheme.inter(600))
			caption.add_theme_font_size_override(&"font_size", 13)
			caption.add_theme_color_override(&"font_color", UiTokens.INK_2)
			panel.add_child(caption)
			var value := Label.new()
			value.name = "Value"
			value.mouse_filter = Control.MOUSE_FILTER_IGNORE
			value.clip_text = true
			value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			value.add_theme_font_override(&"font", UiTheme.barlow(700))
			value.add_theme_font_size_override(&"font_size", 20)
			value.add_theme_color_override(&"font_color", UiTokens.INK)
			panel.add_child(value)
			_cells.append({"panel": panel, "caption": caption, "value": value})

	func setup(terms: Dictionary, compact: bool) -> void:
		_compact = compact
		var captions := ["WAGE / WEEK", "YEARS", "SQUAD ROLE", "RELEASE CLAUSE"]
		var values := [
			CareerPlayerPane.money(int(terms.get("weekly_wage", 0))),
			"%d %s" % [int(terms.get("years", 0)),
				"YEAR" if int(terms.get("years", 0)) == 1 else "YEARS"],
			CareerTransferContractScreen.role_label(str(terms.get("squad_role", ""))),
			CareerPlayerPane.money(int(terms.get("release_clause", 0))),
		]
		for index in _cells.size():
			var cell: Dictionary = _cells[index]
			(cell["caption"] as Label).text = captions[index]
			(cell["value"] as Label).text = values[index]
			(cell["caption"] as Label).add_theme_font_size_override(&"font_size",
				11 if compact else 13)
			(cell["value"] as Label).add_theme_font_size_override(&"font_size",
				16 if compact else 20)
		_layout()

	func _layout() -> void:
		if _cells.is_empty() or size.x <= 0.0 or size.y <= 0.0:
			return
		var columns := 4 if _compact else 2
		var rows := 1 if _compact else 2
		var cell_w := (size.x - GAP * (columns - 1)) / float(columns)
		var cell_h := (size.y - GAP * (rows - 1)) / float(rows)
		for index in _cells.size():
			var cell: Dictionary = _cells[index]
			var column := index % columns
			var row := floori(float(index) / float(columns))
			var panel := cell["panel"] as Panel
			panel.position = Vector2(column * (cell_w + GAP), row * (cell_h + GAP))
			panel.size = Vector2(cell_w, cell_h)
			var caption := cell["caption"] as Label
			caption.position = Vector2(10.0, 4.0)
			caption.size = Vector2(maxf(0.0, cell_w - 20.0), 16.0)
			var value := cell["value"] as Label
			value.position = Vector2(10.0, 22.0)
			value.size = Vector2(maxf(0.0, cell_w - 20.0), maxf(0.0, cell_h - 26.0))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layout()


var _career: Career
var _catalog: TeamCatalog
var _player: Dictionary = {}
var _player_id := ""
var _offer_id := ""
var _kind := "transfer"
var _state: Dictionary = {}
var _draft: Dictionary = {}
var _error := ""
var _focus := 0

var _left: Panel
var _right: Panel
var _photo: CareerPlayerCard.Photo
var _eyebrow: Label
var _name: Label
var _sub: Label
var _block_head: Label
var _info_rows: Array = []
var _free_note: Label
var _head_eyebrow: Label
var _head_title: Label
var _fields: Array = []
var _terms: Terms
var _reply: Panel
var _reply_eyebrow: Label
var _reply_message: Label
var _reply_terms: Terms
var _footer: Label
var _error_label: Label
var _actions: Array = []
var _amount_modal: CareerAmountModal
var _amount_modal_field := ""
var _modal_closed_frame := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	var nav := _ui_nav()
	if nav != null:
		nav.moved.connect(_on_nav_moved)
		nav.confirmed.connect(_on_nav_confirmed)
		nav.cancelled.connect(_on_nav_cancelled)
	call_deferred("_layout")


# Host contract ---------------------------------------------------------------

func open(career: Career, catalog: TeamCatalog, payload: Dictionary) -> void:
	_career = career
	_catalog = catalog
	_error = ""
	# A host refresh may pass an empty payload: keep the current player then.
	var next_player := str(payload.get("player_id", ""))
	if not next_player.is_empty():
		if next_player != _player_id:
			_player_id = next_player
			_offer_id = ""
			_kind = ""
		_offer_id = str(payload.get("offer_id", ""))
		if not str(payload.get("kind", "")).is_empty():
			_kind = str(payload.get("kind", ""))
	_state = CareerTransferContracts.state(career, catalog,
		_offer_id if not _offer_id.is_empty() else _player_id)
	var state_offer_id = _state.get("offer_id")
	if state_offer_id != null and not str(state_offer_id).is_empty():
		_offer_id = str(state_offer_id)
	_player_id = str(_state.get("player_id", _player_id))
	_player = CareerSearch.profile(catalog, career, _player_id)
	if _player_id.is_empty():
		_error = "player not found"
		_state = {}
	elif str(_state.get("error", "")).is_empty() and _kind.is_empty():
		_kind = str(_state.get("kind", "transfer"))
	_draft = _draft_from_state()
	_focus = 0
	_refresh()
	_layout()


func close() -> void:
	if _amount_modal != null and _amount_modal.is_open():
		_amount_modal.close()


func hints() -> Array:
	var gamepad := _gamepad()
	if _field_ids().is_empty():
		return [
			{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
			{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
		]
	return [
		{"keys": ["D-PAD"] if gamepad else ["←", "→"], "label": "adjust"},
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
		{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
	]


func focus_initial() -> void:
	_focus = 0
	_refresh()


func status() -> String:
	return _error


func status_error() -> bool:
	return not _error.is_empty()


# State for the host and the tests --------------------------------------------

func state() -> Dictionary:
	return _state


func draft() -> Dictionary:
	return _draft


func focused_id() -> String:
	var ids := _focus_ids()
	return str(ids[_focus]) if _focus >= 0 and _focus < ids.size() else ""


func focus_index() -> int:
	return _focus


func _draft_from_state() -> Dictionary:
	for key in ["offer", "counter"]:
		var terms = _state.get(key)
		if terms is Dictionary:
			return _clean(terms)
	var defaults = _state.get("contract_defaults")
	return _clean(defaults if defaults is Dictionary else {})


func _clean(terms: Dictionary) -> Dictionary:
	var years := clampi(int(terms.get("years", 3)), 1, 5)
	var role := str(terms.get("squad_role", "rotation"))
	return {
		"years": years,
		"weekly_wage": clampi(int(terms.get("weekly_wage", MIN_WAGE)),
			MIN_WAGE, MAX_WAGE),
		"squad_role": role if _role_index(role) >= 0 else "rotation",
		"release_clause": maxi(0, int(terms.get("release_clause", 0))),
	}


# Build ----------------------------------------------------------------------

func _build() -> void:
	var made := _make_panel(self, "Player", UiTokens.TILE, 0.30)
	_left = made["panel"] as Panel
	made = _make_panel(self, "Form", UiTokens.TILE, 0.30)
	_right = made["panel"] as Panel

	_photo = CareerPlayerCard.Photo.new()
	_photo.name = "Photo"
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_photo)
	_eyebrow = _make_label(_left, "Eyebrow", UiTheme.inter(600), 14, UiTokens.INK_2)
	_name = _make_label(_left, "Name", UiTheme.barlow(700), 28, UiTokens.INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	_sub = _make_label(_left, "Sub", UiTheme.inter(500), 14, UiTokens.INK_2)
	_block_head = _make_label(_left, "BlockHead", UiTheme.inter(600), 14, UiTokens.INK_2)
	_block_head.text = "DEAL TERMS"
	for caption in ["FEE", "BALANCE AFTER", "WAGE", "WAGE SHARE", "CLUB"]:
		_info_rows.append(_make_info(_left, caption))
	_free_note = _make_label(_left, "FreeNote", UiTheme.inter(500), 13, UiTokens.INK_2)
	_free_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_head_eyebrow = _make_label(_right, "HeadEyebrow", UiTheme.inter(600), 14,
		UiTokens.INK_2)
	_head_title = _make_label(_right, "HeadTitle", UiTheme.barlow(700), 30, UiTokens.INK)
	for id in FIELD_IDS:
		_fields.append(_make_field(_right, id))

	_terms = Terms.new()
	_terms.name = "Terms"
	_right.add_child(_terms)

	_reply = Panel.new()
	_reply.name = "Reply"
	_reply.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reply_box := StyleBoxFlat.new()
	reply_box.bg_color = Color(UiTokens.INK, 0.055)
	_reply.add_theme_stylebox_override(&"panel", reply_box)
	_right.add_child(_reply)
	_reply_eyebrow = _make_label(_reply, "Eyebrow", UiTheme.inter(600), 13, UiTokens.INK_2)
	_reply_message = _make_label(_reply, "Message", UiTheme.inter(500), 14, UiTokens.INK_2)
	_reply_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reply_terms = Terms.new()
	_reply_terms.name = "ReplyTerms"
	_reply.add_child(_reply_terms)

	for id in ["accept_counter", "submit", "sign", "back"]:
		_actions.append(_make_action(_right, id))
	_footer = _make_label(_right, "Footer", UiTheme.inter(500), 13, UiTokens.INK_2)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label = _make_label(_right, "Error", UiTheme.inter(600), 14, MARK_LOSS)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_amount_modal = CareerAmountModal.new()
	_amount_modal.name = "AmountModal"
	_amount_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_amount_modal.applied.connect(_on_amount_applied)
	_amount_modal.closed.connect(func() -> void:
		_modal_closed_frame = Engine.get_process_frames())
	add_child(_amount_modal)


func _make_panel(parent: Control, node_name: String, fill: Color,
		shadow_alpha: float) -> Dictionary:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.shadow_color = Color(UiTokens.SHADOW, shadow_alpha)
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	box.anti_aliasing = true
	panel.add_theme_stylebox_override(&"panel", box)
	return {"panel": panel, "box": box}


func _make_label(parent: Control, node_name: String, font: Font, font_size: int,
		color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label


func _make_info(parent: Control, caption: String) -> Dictionary:
	var panel := Panel.new()
	panel.name = "Info_" + caption.to_lower().replace(" ", "_")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.055)
	panel.add_theme_stylebox_override(&"panel", box)
	parent.add_child(panel)
	var label := _make_label(panel, "Label", UiTheme.inter(600), 13, UiTokens.INK_2)
	label.text = caption
	var value := _make_label(panel, "Value", UiTheme.barlow(700), 19, UiTokens.INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return {"panel": panel, "caption": caption, "label": label, "value": value}


func _make_field(parent: Control, id: String) -> Dictionary:
	var root := Control.new()
	root.name = "Field_" + id
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var made := _make_panel(root, "Bg", Color(UiTokens.INK, 0.055), 0.0)
	var panel := made["panel"] as Panel
	panel.position = Vector2.ZERO
	var rail := ColorRect.new()
	rail.name = "Rail"
	rail.color = UiTokens.RAIL
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rail)
	var label := _make_label(root, "Label", UiTheme.inter(600), 14, UiTokens.INK_2)
	var value := _make_label(root, "Value", UiTheme.barlow(700), 26, UiTokens.INK)
	var hint := _make_label(root, "Hint", UiTheme.inter(500), 13, UiTokens.INK_2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.mouse_entered.connect(_set_focus.bind(id))
	root.gui_input.connect(_on_field_input.bind(id))
	return {"id": id, "root": root, "panel": panel, "rail": rail,
		"label": label, "value": value, "hint": hint}


func _make_action(parent: Control, id: String) -> Dictionary:
	var root := Control.new()
	root.name = "Action_" + id
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var made := _make_panel(root, "Bg", Color(UiTokens.INK, 0.10), 0.0)
	var panel := made["panel"] as Panel
	panel.position = Vector2.ZERO
	var rail := ColorRect.new()
	rail.name = "Rail"
	rail.color = UiTokens.RAIL
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rail)
	var label := _make_label(root, "Label", UiTheme.barlow(700), 19, UiTokens.INK)
	var key_panel := Panel.new()
	key_panel.name = "Key"
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(key_panel)
	var key_label := _make_label(key_panel, "KeyLabel", UiTheme.inter(700), 13, UiTokens.INK_2)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.text = "A"
	root.mouse_entered.connect(_set_focus.bind(id))
	root.gui_input.connect(_on_action_input.bind(id))
	return {"id": id, "root": root, "panel": panel, "rail": rail, "label": label,
		"key_panel": key_panel, "key_label": key_label, "visible": false,
		"enabled": true}


# Content --------------------------------------------------------------------

func _field_ids() -> Array:
	if _state.is_empty():
		return []
	var status := str(_state.get("status", ""))
	if status == "pending" or status == "accepted":
		return []
	return FIELD_IDS


func _focus_ids() -> Array:
	var ids := _field_ids().duplicate()
	for action in _actions:
		if bool(action["visible"]) and bool(action["enabled"]):
			ids.append(str(action["id"]))
	return ids


func _refresh() -> void:
	if _left == null:
		return
	_state = CareerTransferContracts.state(_career, _catalog,
		_offer_id if not _offer_id.is_empty() else _player_id) \
		if _career != null and _catalog != null else {}
	if not str(_state.get("error", "")).is_empty():
		_error = str(_state.get("error", ""))
	var status := str(_state.get("status", ""))
	var is_loan := _kind == "loan" or str(_state.get("kind", "")) == "loan"
	_refresh_player(is_loan)
	_refresh_info(is_loan)
	_refresh_head(status)
	_refresh_fields()
	_refresh_terms(status)
	_refresh_reply(status)
	_refresh_actions(status)
	_refresh_footer(status)
	var reason := _error
	if reason.is_empty() and not _state.is_empty() \
			and not str(_state.get("error", "")).is_empty():
		reason = str(_state.get("error", ""))
	_error_label.text = reason
	_error_label.visible = not reason.is_empty()
	_focus = clampi(_focus, 0, maxi(0, _focus_ids().size() - 1))
	_apply_state()
	_layout()


func _refresh_player(is_loan: bool) -> void:
	_photo.show_texture(CareerPlayerCard.face_texture(_player))
	_eyebrow.text = "LOAN" if is_loan else ("FREE AGENT"
		if _offer_id.is_empty() and str(_player.get("club_id", "")).is_empty() else "TRANSFER")
	_name.text = str(_player.get("name", _state.get("player_name", ""))).to_upper()
	var position := str(_player.get("position", ""))
	var role := str(_player.get("role", ""))
	var overall := int(roundf(float(_state.get("overall", 0.0))))
	if overall <= 0:
		overall = int(roundf(float(_player.get("overall", 0.0))))
	var bits: Array = []
	if not position.is_empty():
		bits.append(position)
	if not role.is_empty():
		bits.append(role)
	if overall > 0:
		bits.append("%d OVR" % overall)
	_sub.text = " · ".join(bits) if not bits.is_empty() else "—"


func _refresh_info(is_loan: bool) -> void:
	var fee := int(_state.get("fee", 0))
	var wage_share := int(_state.get("wage_share", 100))
	if not _offer_id.is_empty():
		# Before talks start the contract state has no fee yet; the accepted
		# offer is the source, like the prototype's transferContractOffer.
		var offer := CareerTransferOffers.find_offer(_career, _offer_id)
		if fee <= 0:
			fee = int(offer.get("loan_fee", 0)) if str(offer.get("kind", "")) == "loan" \
				else int(offer.get("amount", 0))
		if not _state.get("offer") is Dictionary:
			wage_share = int(offer.get("wage_share", wage_share))
	var balance_after = _state.get("balance_after")
	if balance_after == null and _career != null:
		balance_after = int(_career.balance) - fee
	var club_name := str(_player.get("club_name", ""))
	var rows := [
		{"caption": "LOAN FEE" if is_loan else "AGREED FEE",
			"value": CareerPlayerPane.money(fee) if fee > 0 else "No compensation",
			"visible": true},
		{"caption": "BALANCE AFTER",
			"value": CareerPlayerPane.money(int(balance_after)) if balance_after != null
				else "—",
			"visible": true},
		{"caption": "CURRENT WAGE" if not club_name.is_empty() else "REPORTED WAGE",
			"value": CareerPlayerPane.money(int(_player.get("weekly_wage", 0)))
				if int(_player.get("weekly_wage", 0)) > 0 else "—",
			"visible": true},
		{"caption": "WAGE SHARE", "value": "%d%%" % wage_share,
			"visible": is_loan},
		{"caption": "CLUB",
			"value": club_name if not club_name.is_empty() else "Free agent",
			"visible": true},
	]
	for index in _info_rows.size():
		var row: Dictionary = _info_rows[index]
		var data: Dictionary = rows[index]
		(row["panel"] as Panel).visible = bool(data["visible"])
		(row["label"] as Label).text = str(data["caption"])
		(row["value"] as Label).text = str(data["value"])
	_free_note.visible = club_name.is_empty()
	_free_note.text = "The wage is the scout report estimate; the player reveals his exact demand in the counter." \
		if club_name.is_empty() else ""


func _refresh_head(status: String) -> void:
	match status:
		"pending":
			_head_eyebrow.text = "AWAITING REPLY"
			_head_title.text = "THE PLAYER IS THINKING"
		"accepted":
			_head_eyebrow.text = "AGREED"
			_head_title.text = "TERMS ACCEPTED"
		_:
			_head_eyebrow.text = "PLAYER CONTRACT"
			_head_title.text = "TERMS"


func _refresh_fields() -> void:
	for field in _fields:
		var id := str(field["id"])
		field["root"].visible = _field_ids().has(id)
		match id:
			"weekly_wage":
				field["label"].text = "WEEKLY WAGE"
				field["value"].text = CareerPlayerPane.money(int(_draft.get("weekly_wage", 0)))
				field["hint"].text = "← → step · A exact amount"
			"years":
				field["label"].text = "LENGTH"
				var years := int(_draft.get("years", 1))
				field["value"].text = "%d %s" % [years, "YEAR" if years == 1 else "YEARS"]
				field["hint"].text = "← → change length"
			"squad_role":
				field["label"].text = "SQUAD ROLE"
				field["value"].text = role_label(str(_draft.get("squad_role", "")))
				field["hint"].text = "← → choose role"
			"release_clause":
				field["label"].text = "RELEASE CLAUSE"
				field["value"].text = CareerPlayerPane.money(
					int(_draft.get("release_clause", 0)))
				field["hint"].text = "← → step · A exact amount"


func _refresh_terms(status: String) -> void:
	var terms = _state.get("terms")
	_terms.visible = (status == "pending" or status == "accepted") and terms is Dictionary
	if _terms.visible:
		_terms.setup(terms, false)


func _refresh_reply(status: String) -> void:
	var counter = _state.get("counter")
	var message := str(_state.get("message", ""))
	var refused := status == "refused"
	_reply.visible = _field_ids().size() > 0 and (counter is Dictionary or refused)
	if not _reply.visible:
		return
	_reply_eyebrow.text = "REFUSED" if refused else "PLAYER COUNTER"
	_reply_message.text = message
	_reply_message.add_theme_color_override(&"font_color",
		MARK_LOSS if refused else UiTokens.INK_2)
	_reply_terms.visible = counter is Dictionary
	if counter is Dictionary:
		_reply_terms.setup(counter, true)


func _refresh_actions(status: String) -> void:
	var labels := {
		"accept_counter": "ACCEPT PLAYER TERMS",
		"submit": "OFFER AGAIN" if status == "refused" else "SUBMIT TERMS",
		"sign": "SIGN",
		"back": "BACK",
	}
	var shown := {"accept_counter": false, "submit": false, "sign": false, "back": false}
	var enabled := {"accept_counter": false, "submit": false, "sign": true, "back": true}
	if not str(_state.get("error", "")).is_empty() or _state.is_empty():
		shown["back"] = true
	else:
		match status:
			"pending":
				shown["back"] = true
			"accepted":
				shown["sign"] = true
				enabled["sign"] = bool(_state.get("can_sign", false))
			_:
				if _state.get("counter") is Dictionary:
					shown["accept_counter"] = true
					enabled["accept_counter"] = bool(_state.get("can_accept_counter", false)) \
						and bool(_state.get("affordable", true))
				shown["submit"] = true
				# An accepted club offer opens talks even when the player's own
				# contract runs long (can_discuss is false there); the prototype
				# lets the submit through and shows the validation error inline.
				enabled["submit"] = bool(_state.get("can_submit", false)) \
					or bool(_state.get("offer_accepted", false))
	for action in _actions:
		var id := str(action["id"])
		action["visible"] = shown.get(id, false)
		action["enabled"] = enabled.get(id, false)
		action["label"].text = str(labels.get(id, ""))
		(action["root"] as Control).visible = bool(action["visible"])


func _refresh_footer(status: String) -> void:
	var note := ""
	if status == "pending":
		note = str(_state.get("message", ""))
		var due = _state.get("due")
		if due != null and not str(due).is_empty():
			note += "\nReply by %s" % _date(str(due))
	elif status == "accepted":
		note = str(_state.get("message", ""))
		if not bool(_state.get("affordable", true)):
			note += "\nNot enough money to complete the move."
		note += "\nThe move goes through now if the window is open, otherwise when it opens."
	_footer.text = note
	_footer.visible = not note.is_empty()
	_footer.add_theme_color_override(&"font_color",
		MARK_WARN if status == "accepted" and not bool(_state.get("affordable", true))
		else UiTokens.INK_2)


func _role_index(id: String) -> int:
	for index in ROLES.size():
		if str(ROLES[index]["id"]) == id:
			return index
	return -1


static func role_label(id: String) -> String:
	for role in ROLES:
		if str(role["id"]) == id:
			return str(role["label"])
	return id.to_upper() if not id.is_empty() else "—"


func _date(iso: String) -> String:
	if iso.length() < 10:
		return iso
	return "%d %s %s" % [int(iso.substr(8, 2)),
		CareerHubModel.MONTHS[int(iso.substr(5, 2)) - 1], iso.substr(0, 4)]


# Layout ---------------------------------------------------------------------

func _layout() -> void:
	if _left == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var left_w := clampf(size.x * LEFT_RATIO, LEFT_MIN, minf(LEFT_MAX, size.x - GAP))
	_left.position = Vector2.ZERO
	_left.size = Vector2(left_w, size.y)
	_right.position = Vector2(left_w + GAP, 0.0)
	_right.size = Vector2(maxf(0.0, size.x - left_w - GAP), size.y)
	_layout_player()
	_layout_form()


func _layout_player() -> void:
	var inner_w := maxf(0.0, _left.size.x - PAD * 2.0)
	var y := PAD
	_photo.position = Vector2(PAD, y)
	_photo.size = Vector2(PHOTO_W, PHOTO_H)
	var text_x := PAD + PHOTO_W + 12.0
	var text_w := maxf(0.0, inner_w - PHOTO_W - 12.0)
	_eyebrow.position = Vector2(text_x, y)
	_eyebrow.size = Vector2(text_w, 18.0)
	_name.position = Vector2(text_x, y + 20.0)
	_name.size = Vector2(text_w, 48.0)
	_sub.position = Vector2(text_x, y + 72.0)
	_sub.size = Vector2(text_w, 22.0)
	y += PHOTO_H + 10.0
	_block_head.position = Vector2(PAD, y)
	_block_head.size = Vector2(inner_w, 18.0)
	y += 22.0
	var visible_rows: Array = []
	for row in _info_rows:
		if (row["panel"] as Panel).visible:
			visible_rows.append(row)
	var note_h := 60.0 if _free_note.visible else 0.0
	var room := _left.size.y - PAD - y - note_h - 6.0
	var row_h := INFO_H
	if not visible_rows.is_empty():
		row_h = clampf(room / float(visible_rows.size()) - INFO_GAP, 26.0, INFO_H)
	for row in visible_rows:
		var panel := row["panel"] as Panel
		panel.position = Vector2(PAD, y)
		panel.size = Vector2(inner_w, row_h)
		_layout_info(row, inner_w, row_h)
		y += row_h + INFO_GAP
	_free_note.position = Vector2(PAD, y + 4.0)
	_free_note.size = Vector2(inner_w, note_h)


func _layout_info(row: Dictionary, width: float, height: float) -> void:
	var label := row["label"] as Label
	label.position = Vector2(10.0, 0.0)
	label.size = Vector2(maxf(0.0, width - 20.0 - 130.0), height)
	var value := row["value"] as Label
	value.position = Vector2(maxf(10.0, width - 10.0 - 140.0), 0.0)
	value.size = Vector2(140.0, height)


func _layout_form() -> void:
	var inner_w := maxf(0.0, _right.size.x - PAD * 2.0)
	var y := PAD
	_head_eyebrow.position = Vector2(PAD, y)
	_head_eyebrow.size = Vector2(inner_w, 18.0)
	_head_title.position = Vector2(PAD, y + 20.0)
	_head_title.size = Vector2(inner_w, 36.0)
	y += HEAD_H

	var bottom := _right.size.y - PAD
	var footer_h := FOOTER_H if _footer.visible else 0.0
	_footer.position = Vector2(PAD, bottom - footer_h)
	_footer.size = Vector2(inner_w, footer_h)
	bottom -= footer_h + (8.0 if footer_h > 0.0 else 0.0)

	var shown: Array = []
	for action in _actions:
		if bool(action["visible"]):
			shown.append(action)
	var actions_h := 0.0
	if not shown.is_empty():
		actions_h = shown.size() * ACTION_H + (shown.size() - 1) * ACTION_GAP
		var action_y := bottom - actions_h
		for action in shown:
			var root := action["root"] as Control
			root.position = Vector2(PAD, action_y)
			root.size = Vector2(inner_w, ACTION_H)
			_layout_action(action, inner_w)
			action_y += ACTION_H + ACTION_GAP
		bottom -= actions_h + 8.0

	var error_h := ERROR_H if _error_label.visible else 0.0
	_error_label.position = Vector2(PAD, bottom - error_h)
	_error_label.size = Vector2(inner_w, error_h)
	bottom -= error_h + (8.0 if error_h > 0.0 else 0.0)

	if _terms.visible:
		var height := clampf(bottom - y, 60.0, TERMS_H)
		_terms.position = Vector2(PAD, y)
		_terms.size = Vector2(inner_w, height)
		_terms._layout()
		y += height + 8.0

	var fields: Array = []
	for field in _fields:
		if (field["root"] as Control).visible:
			fields.append(field)
	if not fields.is_empty():
		var room := bottom - y
		if _reply.visible:
			room -= REPLY_H + 8.0
		var field_h := clampf((room - (fields.size() - 1) * FIELD_GAP) / float(fields.size()),
			48.0, FIELD_H)
		for field in fields:
			var root := field["root"] as Control
			root.position = Vector2(PAD, y)
			root.size = Vector2(inner_w, field_h)
			_layout_field(field, inner_w, field_h)
			y += field_h + FIELD_GAP

	if _reply.visible:
		var reply_h := clampf(bottom - y - 8.0, 96.0, REPLY_H)
		_reply.position = Vector2(PAD, y + 8.0)
		_reply.size = Vector2(inner_w, reply_h)
		_layout_reply(inner_w, reply_h)
	else:
		_reply.position = Vector2(PAD, bottom)
		_reply.size = Vector2.ZERO


func _layout_reply(width: float, height: float) -> void:
	_reply_eyebrow.position = Vector2(12.0, 8.0)
	_reply_eyebrow.size = Vector2(maxf(0.0, width - 24.0), 16.0)
	_reply_message.position = Vector2(12.0, 26.0)
	_reply_message.size = Vector2(maxf(0.0, width - 24.0), 34.0)
	_reply_terms.position = Vector2(12.0, 62.0)
	_reply_terms.size = Vector2(maxf(0.0, width - 24.0), maxf(0.0, height - 70.0))
	_reply_terms._layout()


func _layout_field(field: Dictionary, width: float, height: float) -> void:
	var panel := field["panel"] as Panel
	panel.size = Vector2(width, height)
	var rail := field["rail"] as ColorRect
	rail.position = Vector2.ZERO
	rail.size = Vector2(UiTokens.RAIL_W, height)
	var label := field["label"] as Label
	var value := field["value"] as Label
	var hint := field["hint"] as Label
	label.position = Vector2(18.0, 6.0)
	label.size = Vector2(maxf(0.0, width - 36.0), 16.0)
	var hint_w := minf(width * 0.42, 240.0)
	hint.position = Vector2(width - 14.0 - hint_w, 8.0)
	hint.size = Vector2(hint_w, height - 16.0)
	value.position = Vector2(18.0, 24.0)
	value.size = Vector2(maxf(0.0, width - 36.0 - hint_w), height - 28.0)


func _layout_action(action: Dictionary, width: float) -> void:
	var root := action["root"] as Control
	var panel := action["panel"] as Panel
	panel.size = root.size
	var rail := action["rail"] as ColorRect
	rail.position = Vector2.ZERO
	rail.size = Vector2(UiTokens.RAIL_W, root.size.y)
	var label := action["label"] as Label
	label.position = Vector2(18.0, 0.0)
	label.size = Vector2(maxf(0.0, width - 66.0), root.size.y)
	var key_panel := action["key_panel"] as Panel
	key_panel.position = Vector2(width - 42.0, (root.size.y - 24.0) * 0.5)
	key_panel.size = Vector2(28.0, 24.0)
	var key_label := action["key_label"] as Label
	key_label.position = Vector2.ZERO
	key_label.size = key_panel.size


# Focus / state --------------------------------------------------------------

func _apply_state() -> void:
	if _left == null:
		return
	var focused_id := focused_id()
	for field in _fields:
		var focused := str(field["id"]) == focused_id
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL if focused else Color(UiTokens.INK, 0.055)
		box.anti_aliasing = true
		(field["panel"] as Panel).add_theme_stylebox_override(&"panel", box)
		(field["rail"] as ColorRect).visible = not focused
		(field["label"] as Label).add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		(field["hint"] as Label).add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		(field["value"] as Label).add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
	for action in _actions:
		if not bool(action["visible"]):
			continue
		var id := str(action["id"])
		var focused := id == focused_id
		var enabled := bool(action["enabled"])
		var primary := id != "accept_counter"
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL if focused \
			else Color(UiTokens.INK, 0.10 if primary else 0.055)
		box.anti_aliasing = true
		(action["panel"] as Panel).add_theme_stylebox_override(&"panel", box)
		(action["rail"] as ColorRect).visible = enabled and (focused or primary)
		var ink := UiTokens.FOCUS_MARK if focused else (
			UiTokens.INK if enabled else UiTokens.INK_2)
		(action["label"] as Label).add_theme_color_override(&"font_color", ink)
		var key_box := StyleBoxFlat.new()
		key_box.bg_color = Color(UiTokens.RAIL, 0.16) if focused \
			else Color(UiTokens.INK, 0.09)
		key_box.content_margin_left = 4.0
		key_box.content_margin_right = 4.0
		(action["key_panel"] as Panel).add_theme_stylebox_override(&"panel", key_box)
		(action["key_label"] as Label).add_theme_color_override(&"font_color",
			UiTokens.RAIL if focused else UiTokens.INK_2)


func _set_focus(id: String) -> void:
	var ids := _focus_ids()
	var index := ids.find(id)
	if index < 0 or index == _focus:
		return
	_focus = index
	_apply_state()


# Actions --------------------------------------------------------------------

func _wage_step() -> int:
	var base := 0
	for key in ["terms", "offer"]:
		var terms = _state.get(key)
		if terms is Dictionary and int(terms.get("weekly_wage", 0)) > 0:
			base = int(terms.get("weekly_wage", 0))
			break
	if base <= 0:
		base = int((_state.get("contract_defaults") as Dictionary).get("weekly_wage", 0)) \
			if _state.get("contract_defaults") is Dictionary else 0
	if base <= 0:
		base = int(_player.get("weekly_wage", 0))
	if base <= 0:
		base = MIN_WAGE
	return maxi(MIN_WAGE, roundi(float(base) * 0.1 / 100.0) * 100)


func _clause_step() -> int:
	var base := int(_player.get("market_value", 0))
	if base <= 0:
		base = 1000000
	return maxi(MIN_CLAUSE_STEP, roundi(float(base) * 0.05 / 100000.0) * 100000)


func _step_field(id: String, delta: int) -> void:
	match id:
		"years":
			_draft["years"] = clampi(int(_draft.get("years", 3)) + delta, 1, 5)
		"weekly_wage":
			_draft["weekly_wage"] = clampi(int(_draft.get("weekly_wage", MIN_WAGE))
				+ delta * _wage_step(), MIN_WAGE, MAX_WAGE)
		"release_clause":
			_draft["release_clause"] = maxi(0, int(_draft.get("release_clause", 0))
				+ delta * _clause_step())
		"squad_role":
			var index := maxi(0, _role_index(str(_draft.get("squad_role", "rotation"))))
			var next := posmod(index + delta, ROLES.size())
			_draft["squad_role"] = str(ROLES[next]["id"])
	_refresh()


func _open_amount(id: String) -> void:
	if _amount_modal == null:
		return
	var value := 0
	var title := "AMOUNT"
	match id:
		"weekly_wage":
			value = int(_draft.get("weekly_wage", 0))
			title = "Weekly wage"
		"release_clause":
			value = int(_draft.get("release_clause", 0))
			title = "Release clause"
		_:
			return
	_amount_modal_field = id
	_amount_modal.open(value, {"title": title, "min": 0, "max": AMOUNT_MAX,
		"confirm_label": "DONE"})


func _on_amount_applied(value: int) -> void:
	var id := _amount_modal_field
	_amount_modal_field = ""
	if id == "weekly_wage":
		_draft["weekly_wage"] = clampi(value, MIN_WAGE, MAX_WAGE)
	elif id == "release_clause":
		_draft["release_clause"] = maxi(0, value)
	_refresh()


func _activate(id: String) -> void:
	match id:
		"weekly_wage", "release_clause":
			_open_amount(id)
		"years", "squad_role":
			_step_field(id, 1)
		"accept_counter":
			_accept_counter()
		"submit":
			_submit()
		"sign":
			_sign()
		"back":
			closed.emit()


func _accept_counter() -> void:
	var result := CareerTransferContracts.accept_counter(_career, _catalog, _player_id)
	if not bool(result.get("ok", false)):
		_error = str(result.get("error", ""))
		_refresh()
		return
	_error = ""
	changed.emit()
	_refresh()


func _submit() -> void:
	var result := CareerTransferContracts.submit(_career, _catalog, _player_id, _draft,
		_offer_id)
	if not bool(result.get("ok", false)):
		_error = str(result.get("error", ""))
		_refresh()
		return
	_error = ""
	changed.emit()
	_refresh()


func _sign() -> void:
	var result := CareerTransferContracts.sign(_career, _catalog, _player_id)
	if not bool(result.get("ok", false)):
		_error = str(result.get("error", ""))
		_refresh()
		return
	_error = ""
	changed.emit()
	navigate.emit("centre", {"tab": "sent"})


# Input ----------------------------------------------------------------------

func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _gamepad() -> bool:
	var nav := _ui_nav()
	return nav != null and bool(nav.using_gamepad())


func _is_active() -> bool:
	var nav := _ui_nav()
	# `event_was_modal` also covers a modal (the amount editor) that closed inside
	# this same event: the screen must not run its own Back on that keystroke.
	return is_visible_in_tree() and (nav == null or not (
		nav.is_modal() or nav.event_was_modal()))


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_active():
		return
	var id := focused_id()
	if _field_ids().has(id) and (direction == Vector2i.LEFT or direction == Vector2i.RIGHT):
		_step_field(id, -1 if direction == Vector2i.LEFT else 1)
		return
	if direction == Vector2i.UP or direction == Vector2i.LEFT:
		_move_focus(-1)
	else:
		_move_focus(1)


func _move_focus(delta: int) -> void:
	var count := _focus_ids().size()
	if count <= 0:
		return
	_focus = clampi(_focus + delta, 0, count - 1)
	_apply_state()


func _on_nav_confirmed() -> void:
	if not _is_active() or _modal_consumed():
		return
	_activate(focused_id())


func _on_nav_cancelled() -> void:
	if not _is_active() or _modal_consumed():
		return
	closed.emit()


# The amount modal closes itself inside the same confirm/cancel signal, so the
# screen must not treat that same event as its own.
func _modal_consumed() -> bool:
	return _modal_closed_frame == Engine.get_process_frames()


func _on_field_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_set_focus(id)
		_activate(id)
		accept_event()


func _on_action_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		if not _focus_ids().has(id):
			return
		_set_focus(id)
		_activate(id)
		accept_event()
