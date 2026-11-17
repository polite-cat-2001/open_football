class_name CareerTransferOffer
extends Control
# Prototype transfers/TransferOfferScreen.svelte: the SEND OFFER step. The
# player sits on the left (photo, name, facts, club, balance, clause), the
# offer form on the right. A transfer shows the fee plus the release-clause
# buyout switch (only when the player has a clause); a loan shows the loan fee
# and the wage share. Left/right steps the focused field by the prototype's
# step, confirm on a money field opens the shared CareerAmountModal prefilled,
# confirm on an action sends the offer. The host owns routing, animation and
# the hints bar; this screen only emits closed / changed.

signal closed
signal changed

const GAP := 10.0
const PAD := 16.0
const FIELD_H := 78.0
const FIELD_GAP := 4.0
const ACTION_H := 56.0
const NOTE_H := 36.0
const ERROR_H := 32.0
const STAT_H := 40.0
const STAT_GAP := 4.0
const STAT_COUNT := 3
const CLUB_H := 30.0
const FACTS_H := 24.0
const NAME_H := 38.0
const LEFT_RATIO := 0.39
const LEFT_MIN := 240.0
const LEFT_MAX := 640.0
const CREST := 32.0
const PHOTO_MAX_H := 300.0
const AMOUNT_MAX := 999999999
const MARK_LOSS := Color("b23a48")

var _career: Career
var _catalog: TeamCatalog
var _player: Dictionary = {}
var _player_id := ""
var _kind := "transfer"
var _proposal: Dictionary = {}
var _amount := 0
var _loan_fee := 0
var _wage_share := 50
var _buyout := false
var _balance := 0
var _release_clause := 0
var _market_value := 0
var _error := ""
var _focus := 0
var _amount_modal_field := ""
var _modal_closed_frame := -1

var _left: Panel
var _right: Panel
var _photo: CareerPlayerCard.Photo
var _name: Label
var _fact_cells: Array = []
var _club_photo: CareerPlayerCard.Photo
var _club_name: Label
var _stats: Array = []
var _fields: Array = []
var _action: Dictionary = {}
var _note: Label
var _error_label: Label
var _amount_modal: CareerAmountModal


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
	# A host refresh may pass an empty payload: keep the player in that case.
	var next_player := str(payload.get("player_id", ""))
	if not next_player.is_empty():
		_player_id = next_player
	if payload.has("kind"):
		_kind = str(payload.get("kind", ""))
	if _kind != "loan":
		_kind = "transfer"
	_player = CareerSearch.profile(catalog, career, _player_id)
	_proposal = CareerTransferOffers.proposal(career, catalog, _player_id, _kind)
	_amount = int(_proposal.get("fee", 0))
	_loan_fee = int(_proposal.get("loan_fee", 0))
	_wage_share = int(_proposal.get("wage_share", 50))
	_buyout = false
	_balance = int(_proposal.get("balance", 0))
	_release_clause = int(_proposal.get("release_clause", 0))
	_market_value = int(_proposal.get("market_value", 0))
	var preset = payload.get("preset")
	if preset is Dictionary:
		# A re-offer carries the club's counter; the preset wins over defaults.
		if preset.has("amount"):
			_amount = int(preset["amount"])
		if preset.has("loan_fee"):
			_loan_fee = int(preset["loan_fee"])
		if preset.has("wage_share"):
			_wage_share = int(preset["wage_share"])
		if bool(preset.get("buyout", false)) and bool(_proposal.get("buyout_allowed", false)):
			_buyout = true
	_focus = 0
	_refresh()
	_layout()


func close() -> void:
	if _amount_modal != null and _amount_modal.is_open():
		_amount_modal.close()


func hints() -> Array:
	var gamepad := _gamepad()
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

func offer() -> Dictionary:
	return {
		"player_id": _player_id,
		"kind": _kind,
		"amount": _amount,
		"loan_fee": _loan_fee,
		"wage_share": _wage_share,
		"buyout": _buyout,
	}


func focused_id() -> String:
	var ids := _focus_ids()
	return str(ids[_focus]) if _focus >= 0 and _focus < ids.size() else ""


func focus_index() -> int:
	return _focus


func can_submit() -> bool:
	return bool(_proposal.get("can_submit", false))


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
	_name = _make_label(_left, "Name", UiTheme.barlow(700), 30, UiTokens.INK)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2

	_club_photo = CareerPlayerCard.Photo.new()
	_club_photo.name = "Crest"
	_club_photo.custom_minimum_size = Vector2(CREST, CREST)
	_club_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_club_photo)
	_club_name = _make_label(_left, "ClubName", UiTheme.inter(600), 15, UiTokens.INK_2)

	for caption in ["AGE", "POSITION", "HEIGHT"]:
		var cell := {
			"caption": _make_label(_left, "Fact_" + caption, UiTheme.inter(600), 14,
				UiTokens.INK_2),
			"value": _make_label(_left, "Value_" + caption, UiTheme.barlow(700), 18,
				UiTokens.INK),
		}
		(cell["caption"] as Label).text = caption
		_fact_cells.append(cell)

	for caption in ["CLUB BALANCE", "RELEASE CLAUSE", "BALANCE AFTER"]:
		_stats.append(_make_stat(_left, caption))

	for id in ["amount", "buyout", "loan_fee", "wage_share"]:
		_fields.append(_make_field(_right, id))
	_action = _make_action(_right, "submit")
	_note = _make_label(_right, "Note", UiTheme.inter(500), 14, UiTokens.INK_2)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func _make_stat(parent: Control, caption: String) -> Dictionary:
	var made := _make_panel(parent, "Stat_" + caption.to_lower().replace(" ", "_"),
		Color(UiTokens.INK, 0.055), 0.0)
	var panel := made["panel"] as Panel
	var label := _make_label(panel, "Label", UiTheme.inter(600), 14, UiTokens.INK_2)
	label.text = caption
	var value := _make_label(panel, "Value", UiTheme.barlow(700), 22, UiTokens.INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return {"panel": panel, "label": label, "value": value}


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
	var label := _make_label(root, "Label", UiTheme.inter(600), 15, UiTokens.INK_2)
	var value := _make_label(root, "Value", UiTheme.barlow(700), 28, UiTokens.INK)
	var hint := _make_label(root, "Hint", UiTheme.inter(500), 14, UiTokens.INK_2)
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
	var label := _make_label(root, "Label", UiTheme.barlow(700), 20, UiTokens.INK)
	var key_panel := Panel.new()
	key_panel.name = "Key"
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(key_panel)
	var key_label := _make_label(key_panel, "KeyLabel", UiTheme.inter(700), 14, UiTokens.INK_2)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.text = "A"
	root.mouse_entered.connect(_set_focus.bind(id))
	root.gui_input.connect(_on_action_input.bind(id))
	return {"id": id, "root": root, "panel": panel, "rail": rail,
		"label": label, "key_panel": key_panel, "key_label": key_label}


# Content --------------------------------------------------------------------

func _field_ids() -> Array:
	if _kind == "loan":
		return ["loan_fee", "wage_share"]
	var ids: Array = ["amount"]
	if bool(_proposal.get("buyout_allowed", false)):
		ids.append("buyout")
	return ids


func _focus_ids() -> Array:
	var ids := _field_ids()
	ids.append("submit")
	return ids


func _refresh() -> void:
	if _left == null:
		return
	_photo.show_texture(CareerPlayerCard.face_texture(_player))
	_name.text = str(_player.get("name", "")).to_upper()
	_fact_cells[0]["value"].text = str(_player.get("age", "—"))
	_fact_cells[1]["value"].text = CareerPlayerCard.position_code(
		str(_player.get("position", "")), str(_player.get("position_group", "")))
	var height := int(_player.get("height", 0))
	_fact_cells[2]["value"].text = "%d CM" % height if height > 0 else "—"
	var crest := CareerPlayerCard.crest_texture(_player)
	_club_photo.show_texture(crest)
	_club_photo.visible = crest != null
	var club_name := str(_player.get("club_name", ""))
	_club_name.text = club_name if not club_name.is_empty() else "Free agent"
	_stats[0]["value"].text = CareerPlayerPane.money(_balance)
	_stats[1]["value"].text = CareerPlayerPane.money(_release_clause)
	_stats[2]["value"].text = CareerPlayerPane.money(
		_balance - (_loan_fee if _kind == "loan" else _field_amount()))
	for field in _fields:
		var id := str(field["id"])
		field["root"].visible = _field_ids().has(id)
		match id:
			"amount":
				field["label"].text = "BUYOUT AT RELEASE CLAUSE" if _buyout \
					else "OFFER AMOUNT"
				field["value"].text = CareerPlayerPane.money(
					_release_clause if _buyout else _amount)
				field["hint"].text = "The release clause cannot be changed" if _buyout \
					else "← → step · A exact amount"
			"buyout":
				field["label"].text = "BUYOUT AT RELEASE CLAUSE"
				field["value"].text = "ON" if _buyout else "OFF"
				field["hint"].text = "A or ← → toggles"
			"loan_fee":
				field["label"].text = "LOAN FEE"
				field["value"].text = CareerPlayerPane.money(_loan_fee)
				field["hint"].text = "← → step · A exact amount"
			"wage_share":
				field["label"].text = "WAGE SHARE"
				field["value"].text = "%d%%" % _wage_share
				field["hint"].text = "← → step 5%"
	_action["label"].text = "SEND OFFER"
	var reason := str(_proposal.get("reason", ""))
	if not _error.is_empty():
		_error_label.text = _error
	elif not bool(_proposal.get("can_submit", true)):
		_error_label.text = reason
	else:
		_error_label.text = ""
	_error_label.visible = not _error_label.text.is_empty()
	_note.text = "The club answers in 2–4 days; the reply appears in SENT OFFERS."
	_focus = clampi(_focus, 0, _focus_ids().size() - 1)
	_apply_state()
	_layout()


func _field_amount() -> int:
	return _release_clause if _buyout else _amount


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
	var y := _left.size.y - PAD - STAT_COUNT * STAT_H - (STAT_COUNT - 1) * STAT_GAP
	for stat in _stats:
		var panel := stat["panel"] as Panel
		panel.position = Vector2(PAD, y)
		panel.size = Vector2(inner_w, STAT_H)
		_layout_row(stat, inner_w)
		y += STAT_H + STAT_GAP
	var club_y := _left.size.y - PAD - STAT_COUNT * STAT_H \
		- (STAT_COUNT - 1) * STAT_GAP - 8.0 - CLUB_H
	var club_w := CREST + 10.0 + _text_width(_club_name)
	var club_x := PAD + maxf(0.0, (inner_w - club_w) * 0.5)
	_club_photo.position = Vector2(club_x, club_y + (CLUB_H - CREST) * 0.5)
	_club_photo.size = Vector2(CREST, CREST)
	_club_name.position = Vector2(club_x + CREST + 10.0, club_y)
	_club_name.size = Vector2(maxf(0.0, inner_w - (club_x - PAD) - CREST - 10.0), CLUB_H)
	var facts_y := club_y - 6.0 - FACTS_H
	var row_w := 0.0
	for cell in _fact_cells:
		row_w += _text_width(cell["caption"]) + 5.0 + _text_width(cell["value"]) + 18.0
	row_w -= 18.0
	var fact_x := PAD + maxf(0.0, (inner_w - row_w) * 0.5)
	for cell in _fact_cells:
		var caption := cell["caption"] as Label
		var value := cell["value"] as Label
		var caption_w := _text_width(caption)
		var value_w := _text_width(value)
		caption.position = Vector2(fact_x, facts_y)
		caption.size = Vector2(caption_w, FACTS_H)
		value.position = Vector2(fact_x + caption_w + 5.0, facts_y)
		value.size = Vector2(value_w, FACTS_H)
		fact_x += caption_w + 5.0 + value_w + 18.0
	var name_y := facts_y - 6.0 - NAME_H
	_name.position = Vector2(PAD, name_y)
	_name.size = Vector2(inner_w, NAME_H)
	var photo_h := minf(maxf(40.0, name_y - 8.0 - PAD), PHOTO_MAX_H)
	_photo.position = Vector2(PAD, name_y - 8.0 - photo_h)
	_photo.size = Vector2(inner_w, photo_h)


func _text_width(label: Label) -> float:
	var font := label.get_theme_font(&"font")
	if font == null:
		return 0.0
	var font_size := label.get_theme_font_size(&"font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _layout_row(row: Dictionary, width: float) -> void:
	var label := row["label"] as Label
	var value := row["value"] as Label
	var panel := row["panel"] as Panel
	label.position = Vector2(14.0, 0.0)
	label.size = Vector2(maxf(0.0, width - 28.0 - 120.0), panel.size.y)
	value.position = Vector2(maxf(14.0, width - 14.0 - 130.0), 0.0)
	value.size = Vector2(130.0, panel.size.y)


func _layout_form() -> void:
	var inner_w := maxf(0.0, _right.size.x - PAD * 2.0)
	var note_h := NOTE_H
	_note.position = Vector2(PAD, _right.size.y - PAD - note_h)
	_note.size = Vector2(inner_w, note_h)
	var bottom := _note.position.y - 8.0
	var action_root := _action["root"] as Control
	action_root.position = Vector2(PAD, bottom - ACTION_H)
	action_root.size = Vector2(inner_w, ACTION_H)
	_layout_action(inner_w)
	var error_h := ERROR_H if _error_label.visible else 0.0
	_error_label.position = Vector2(PAD, bottom - ACTION_H - 8.0 - error_h)
	_error_label.size = Vector2(inner_w, error_h)
	var fields_top := PAD
	var fields_room := bottom - ACTION_H - (error_h + 8.0 if error_h > 0.0 else 0.0) \
		- 8.0 - fields_top
	var visible_fields: Array = []
	for field in _fields:
		if (field["root"] as Control).visible:
			visible_fields.append(field)
	var count := visible_fields.size()
	var field_h := FIELD_H
	if count > 0:
		field_h = minf(FIELD_H, (fields_room - (count - 1) * FIELD_GAP) / float(count))
		field_h = maxf(54.0, field_h)
	var y := fields_top
	for field in visible_fields:
		var root := field["root"] as Control
		root.position = Vector2(PAD, y)
		root.size = Vector2(inner_w, field_h)
		_layout_field(field, inner_w, field_h)
		y += field_h + FIELD_GAP


func _layout_field(field: Dictionary, width: float, height: float) -> void:
	var panel := field["panel"] as Panel
	panel.size = Vector2(width, height)
	var rail := field["rail"] as ColorRect
	rail.position = Vector2.ZERO
	rail.size = Vector2(UiTokens.RAIL_W, height)
	var label := field["label"] as Label
	var value := field["value"] as Label
	var hint := field["hint"] as Label
	label.position = Vector2(18.0, 8.0)
	label.size = Vector2(maxf(0.0, width - 36.0), 18.0)
	var hint_w := minf(width * 0.42, 260.0)
	hint.position = Vector2(width - 14.0 - hint_w, 10.0)
	hint.size = Vector2(hint_w, height - 20.0)
	value.position = Vector2(18.0, 28.0)
	value.size = Vector2(maxf(0.0, width - 36.0 - hint_w), height - 32.0)


func _layout_action(width: float) -> void:
	var root := _action["root"] as Control
	var panel := _action["panel"] as Panel
	panel.size = root.size
	var rail := _action["rail"] as ColorRect
	rail.position = Vector2.ZERO
	rail.size = Vector2(UiTokens.RAIL_W, root.size.y)
	var label := _action["label"] as Label
	label.position = Vector2(18.0, 0.0)
	label.size = Vector2(maxf(0.0, width - 70.0), root.size.y)
	var key_panel := _action["key_panel"] as Panel
	key_panel.position = Vector2(width - 42.0, (root.size.y - 26.0) * 0.5)
	key_panel.size = Vector2(28.0, 26.0)
	var key_label := _action["key_label"] as Label
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
	var focused_action := focused_id == "submit"
	var enabled := bool(_proposal.get("can_submit", true))
	_action["panel"].add_theme_stylebox_override(&"panel",
		_action_box(focused_action, enabled))
	(_action["rail"] as ColorRect).visible = enabled
	(_action["label"] as Label).add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if focused_action else (UiTokens.INK if enabled else UiTokens.INK_2))
	(_action["key_panel"] as Panel).add_theme_stylebox_override(&"panel",
		_key_box(focused_action))
	(_action["key_label"] as Label).add_theme_color_override(&"font_color",
		UiTokens.RAIL if focused_action else UiTokens.INK_2)


func _action_box(focused: bool, enabled := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_FILL if focused \
		else Color(UiTokens.INK, 0.10 if enabled else 0.055)
	box.anti_aliasing = true
	return box


func _key_box(focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.RAIL, 0.16) if focused else Color(UiTokens.INK, 0.09)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	return box


func _set_focus(id: String) -> void:
	var ids := _focus_ids()
	var index := ids.find(id)
	if index < 0 or index == _focus:
		return
	_focus = index
	_apply_state()


# Actions --------------------------------------------------------------------

func _step_field(id: String, delta: int) -> void:
	match id:
		"buyout":
			_toggle_buyout()
		"amount":
			if _buyout:
				return
			_amount = clampi(_amount + delta * _amount_step(), 0, AMOUNT_MAX)
		"loan_fee":
			_loan_fee = clampi(_loan_fee + delta * _loan_step(), 0, AMOUNT_MAX)
		"wage_share":
			_wage_share = clampi(_wage_share + delta * 5, 0, 100)
	_refresh()


func _amount_step() -> int:
	var base := maxi(maxi(_release_clause, _market_value), 1000000)
	return maxi(100000, roundi(float(base) * 0.05 / 100000.0) * 100000)


func _loan_step() -> int:
	var base := maxi(maxi(_release_clause, _market_value), 1000000)
	return maxi(10000, roundi(float(base) * 0.005 / 10000.0) * 10000)


func _toggle_buyout() -> void:
	if _kind != "transfer" or _release_clause <= 0:
		return
	_buyout = not _buyout
	_refresh()


func _open_amount(id: String) -> void:
	if _amount_modal == null:
		return
	var value := 0
	var title := "AMOUNT"
	match id:
		"amount":
			if _buyout:
				return
			value = _amount
			title = "Offer amount"
		"loan_fee":
			value = _loan_fee
			title = "Loan fee"
		_:
			return
	_amount_modal_field = id
	_amount_modal.open(value, {"title": title, "min": 0, "max": AMOUNT_MAX,
		"confirm_label": "DONE"})


func _on_amount_applied(value: int) -> void:
	var id := _amount_modal_field
	_amount_modal_field = ""
	if id == "amount":
		_amount = value
	elif id == "loan_fee":
		_loan_fee = value
	_refresh()


func _activate(id: String) -> void:
	match id:
		"submit":
			_submit()
		"buyout":
			_toggle_buyout()
		"amount", "loan_fee":
			_open_amount(id)
		"wage_share":
			_step_field(id, 1)
		_:
			pass


func _submit() -> void:
	if _career == null or _catalog == null:
		return
	if not bool(_proposal.get("can_submit", false)):
		_error = str(_proposal.get("reason", ""))
		_refresh()
		return
	var result: Dictionary
	if _kind == "loan":
		result = CareerTransferOffers.submit(_career, _catalog, _player_id, "loan",
			_loan_fee, _loan_fee, _wage_share, false)
	else:
		result = CareerTransferOffers.submit(_career, _catalog, _player_id, "transfer",
			_release_clause if _buyout else _amount, null, null, _buyout)
	if not bool(result.get("ok", false)):
		_error = str(result.get("error", ""))
		_refresh()
		return
	_error = ""
	changed.emit()
	# Back to the search results, not the Transfer Centre's SENT tab: the sent
	# offer lives there, but the manager keeps browsing.
	closed.emit()


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
		# Fields step; the buyout switch toggles on either arrow.
		_step_field(id, -1 if direction == Vector2i.LEFT else 1)
		return
	_move_focus(-1 if direction == Vector2i.UP or direction == Vector2i.LEFT else 1)


func _move_focus(delta: int) -> void:
	_focus = clampi(_focus + delta, 0, _focus_ids().size() - 1)
	_apply_state()


func _on_nav_confirmed() -> void:
	if not _is_active() or _modal_consumed():
		return
	_activate(focused_id())


func _on_nav_cancelled() -> void:
	if not _is_active() or _modal_consumed():
		return
	closed.emit()


# The modal closes itself inside the same confirm/cancel signal, so the
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
		_set_focus(id)
		_activate(id)
		accept_event()
