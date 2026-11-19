class_name CareerSentOfferRow
extends Control
# Prototype transfers/SentOfferCard.svelte: one offer sent to a club. The
# header is the six-column row of the prototype's offer table (status dot or
# the "needs an answer" flag, club crest, kind, photo + name, position, date);
# opening it slides in the two-column accordion (NEGOTIATIONS with the status
# actions, TRANSFER TALKS with the club and the money). Focus inverts the header
# like every other career row; an open row stays inverted.
#
# The host owns the list, the detail pane and the actions: this row only reports
# activated / action_requested / focused and exposes its action metadata so the
# screen can drive focus and confirm.

signal activated(offer_id: String)
signal action_requested(id: String)
signal focused(offer_id: String)

const HEAD_H := 52.0
const PAD_X := 16.0
const COL_GAP := 10.0
const STATUS_W := 56.0
const CREST_W := 34.0
const POS_W := 52.0
const DATE_W := 58.0
const PHOTO_W := 34.0
const PHOTO_H := 44.0
const CREST := 24.0
const DOT := 9.0
const FLAG := 22.0
const ACC_PAD := 16.0
const WIN := Color("2f7d4f")
const WARN := Color("a66a00")
const LOSS := Color("b23a48")


var row: Dictionary = {}

var _player: Dictionary = {}
var _offer: Dictionary = {}
var _offer_id := ""
var _open := false
var _needs_action := false
var _actions: Array[CareerAccordionAction] = []
var _tween: Tween

var _bg: Panel
var _rail: ColorRect
var _head: Button
var _dot: ColorRect
var _flag: PanelContainer
var _crest: TextureRect
var _kind: Label
var _photo: CareerPlayerCard.Photo
var _name: Label
var _pos: Label
var _date: Label
var _acc: PanelContainer
var _height_tween: Tween
var _left: VBoxContainer
var _right: VBoxContainer
var _note: Label
var _actions_box: VBoxContainer
var _club_crest: TextureRect
var _club_name: Label
var _club_label: Label
var _club_amount: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = HEAD_H
	_build()


func setup(next_row: Dictionary) -> void:
	row = next_row
	_player = row.get("player", {}) if row.get("player") is Dictionary else {}
	_offer = row.get("offer", {}) if row.get("offer") is Dictionary else {}
	_offer_id = str(row.get("offer_id", _offer.get("offer_id", "")))
	_needs_action = bool(row.get("can_accept_counter", false)) \
		or bool(row.get("can_reoffer", false)) \
		or (str(_offer.get("status", "")) == "accepted" \
			and not bool(_offer.get("signed", false)))
	_refresh()
	_build_accordion()
	_sync_height()


func offer_id() -> String:
	return _offer_id


func set_open(value: bool) -> void:
	if _open == value:
		return
	_open = value
	if _open:
		_build_accordion()
		_sync_height(true)
		_apply_state()
		_play_open()
		return
	# Closing keeps the body while the plate folds, so the collapse is visible.
	_sync_height(true)
	_apply_state()
	_play_close()


# Fold the panel down and come back when the animation is over, so a host can
# run its action only after the accordion is gone.
func fold() -> void:
	if not _open:
		return
	set_open(false)
	if UiTransition.instant or _height_tween == null:
		return
	await _height_tween.finished


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
	for action in _actions:
		if action.id == id:
			return action.ticket_text()
	return ""


func focus_header() -> void:
	if _head != null:
		_head.grab_focus()


func focus_first_action() -> void:
	for action in _actions:
		action.grab_focus()
		return


func header() -> Control:
	return _head


# Build ----------------------------------------------------------------------

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
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		_head.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_head.pressed.connect(_on_head_pressed)
	_head.focus_entered.connect(_on_head_focused)
	_head.focus_exited.connect(_apply_state)
	_head.mouse_entered.connect(_head.grab_focus)
	_head.clip_contents = true
	add_child(_head)

	_dot = ColorRect.new()
	_dot.color = WARN
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.size = Vector2(DOT, DOT)
	_head.add_child(_dot)

	_flag = PanelContainer.new()
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flag_box := StyleBoxFlat.new()
	flag_box.bg_color = UiTokens.RAIL
	_flag.add_theme_stylebox_override(&"panel", flag_box)
	_head.add_child(_flag)
	var flag_label := Label.new()
	flag_label.text = "!"
	flag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flag_label.add_theme_font_override(&"font", UiTheme.barlow(800))
	flag_label.add_theme_font_size_override(&"font_size", 18)
	flag_label.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK)
	_flag.add_child(flag_label)

	_crest = TextureRect.new()
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_crest)

	_kind = _label(_head, UiTheme.inter(600), 16, UiTokens.INK_2)
	_photo = CareerPlayerCard.Photo.new()
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_photo)
	_name = _label(_head, UiTheme.barlow(700), 20, UiTokens.INK)
	_pos = _label(_head, UiTheme.inter(700), 16, UiTokens.INK)
	_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date = _label(_head, UiTheme.inter(600), 16, UiTokens.INK_2)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_acc = PanelContainer.new()
	_acc.name = "Accordion"
	_acc.mouse_filter = Control.MOUSE_FILTER_PASS
	_acc.clip_contents = true
	var acc_box := StyleBoxFlat.new()
	acc_box.bg_color = UiTokens.FOCUS_FILL_SOFT
	acc_box.content_margin_left = ACC_PAD
	acc_box.content_margin_right = ACC_PAD
	acc_box.content_margin_top = 12.0
	acc_box.content_margin_bottom = 14.0
	_acc.add_theme_stylebox_override(&"panel", acc_box)
	_acc.visible = false
	add_child(_acc)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 2)
	_acc.add_child(columns)
	_left = VBoxContainer.new()
	_left.name = "Negotiations"
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_stretch_ratio = 1.0
	_left.add_theme_constant_override(&"separation", 8)
	columns.add_child(_left)
	_right = VBoxContainer.new()
	_right.name = "Club"
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_stretch_ratio = 0.92
	_right.add_theme_constant_override(&"separation", 8)
	columns.add_child(_right)

	resized.connect(_layout)
	_layout()


func _label(parent: Control, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label


# Portrait plus name, like the prototype's .tf-offer-player.
func _refresh() -> void:
	var status := str(_offer.get("status", ""))
	var kind := str(_offer.get("kind", "transfer"))
	_dot.color = _status_tone(status)
	_dot.visible = not _needs_action
	_flag.visible = _needs_action
	_flag.custom_minimum_size = Vector2(FLAG, FLAG)
	_crest.texture = CareerPlayerCard.crest_texture(_player)
	_crest.visible = _crest.texture != null
	_kind.text = CareerTransfers.kind_label(kind).to_upper()
	_photo.show_texture(CareerPlayerCard.face_texture(_player))
	_name.text = str(_player.get("name", "")).to_upper()
	_pos.text = CareerPlayerCard.position_code(str(_player.get("position", "")),
		str(_player.get("position_group", "")))
	var created := str(_offer.get("created_at", "") if _offer.get("created_at") != null else "")
	_date.text = CareerHubModel.short_date(created)
	_apply_state()
	_layout()


func _status_tone(status: String) -> Color:
	if status == "accepted":
		return WIN
	if status in ["refused", "expired", "withdrawn"]:
		return LOSS
	return WARN


# Accordion content ----------------------------------------------------------

func _build_accordion() -> void:
	for child in _left.get_children():
		_left.remove_child(child)
		child.queue_free()
	for child in _right.get_children():
		_right.remove_child(child)
		child.queue_free()
	_actions.clear()
	if not _open:
		_acc.visible = false
		return
	_acc.visible = true
	_left.add_child(_acc_title("NEGOTIATIONS"))
	_note = Label.new()
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.add_theme_font_override(&"font", UiTheme.inter(500))
	_note.add_theme_font_size_override(&"font_size", 16)
	_note.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK_2)
	_left.add_child(_note)
	_actions_box = VBoxContainer.new()
	_actions_box.add_theme_constant_override(&"separation", 2)
	_left.add_child(_actions_box)
	for spec in _action_specs():
		if spec.has("note"):
			_note.text = str(spec["note"])
			continue
		var action := CareerAccordionAction.new()
		_actions_box.add_child(action)
		action.setup(spec)
		action.pressed.connect(_on_action_pressed.bind(str(spec.get("id", ""))))
		_actions.append(action)
	_note.visible = not str(_note.text).is_empty()

	_right.add_child(_acc_title("TRANSFER TALKS"))
	var club := HBoxContainer.new()
	club.add_theme_constant_override(&"separation", 12)
	_right.add_child(club)
	var crest := TextureRect.new()
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.custom_minimum_size = Vector2(56.0, 56.0)
	var path := str(_player.get("club_logo", ""))
	crest.texture = null if path.is_empty() else UiAssets.usable_texture(
		UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
	crest.visible = crest.texture != null
	club.add_child(crest)
	var info := VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	club.add_child(info)
	_club_name = _label(info, UiTheme.inter(600), 16, UiTokens.FOCUS_INK)
	_club_name.text = str(_player.get("club_name", ""))
	if _club_name.text.is_empty():
		_club_name.text = "FREE AGENT"
	_club_name.text = _club_name.text.to_upper()
	_club_label = _label(info, UiTheme.inter(500), 16, UiTokens.FOCUS_INK_2)
	var counter = _offer.get("counter")
	_club_label.text = "CLUB COUNTER-OFFER" if counter is Dictionary else "OFFER"
	_club_amount = _label(info, UiTheme.barlow(700), 28, UiTokens.FOCUS_INK)
	_club_amount.text = CareerPlayerPane.money(_club_amount_value())


func _acc_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", UiTheme.barlow(700))
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK)
	return label


func _club_amount_value() -> int:
	var counter = _offer.get("counter")
	if counter is Dictionary:
		if str(_offer.get("kind", "")) == "loan":
			return int((counter as Dictionary).get("loan_fee",
				(counter as Dictionary).get("amount", 0)))
		return int((counter as Dictionary).get("amount", 0))
	return int(_offer.get("amount", 0))


func _action_specs() -> Array:
	var specs: Array = []
	var status := str(_offer.get("status", ""))
	if status == "pending":
		specs.append({"note": _pending_note()})
		if bool(row.get("can_withdraw", false)):
			specs.append({"id": "withdraw", "label": "END TALKS"})
	elif status == "accepted":
		if bool(_offer.get("signed", false)):
			specs.append({"note": _signed_note()})
		else:
			specs.append({"id": "contract", "label": "CONTRACT TALKS",
				"enabled": bool(row.get("can_negotiate", false))})
			if bool(row.get("can_withdraw", false)):
				specs.append({"id": "withdraw", "label": "END TALKS"})
	else:
		if bool(row.get("can_accept_counter", false)):
			specs.append({"id": "accept_counter", "label": "ACCEPT COUNTER-OFFER"})
		elif status == "counter":
			specs.append({"note": "NOT ENOUGH FUNDS FOR THE COUNTER-OFFER."})
		if bool(row.get("can_reoffer", false)):
			specs.append({"id": "reoffer",
				"label": "SEND OFFER AGAIN" if status == "refused" else "SEND NEW OFFER"})
		if bool(row.get("can_withdraw", false)):
			specs.append({"id": "withdraw", "label": "END TALKS"})
	return specs


func _pending_note() -> String:
	var due = _offer.get("due")
	if due == null or str(due).is_empty():
		return "THE CLUB HAS NOT ANSWERED YET."
	return "THE CLUB HAS NOT ANSWERED YET. ANSWER BY %s." \
		% CareerHubModel.short_date(str(due)).to_upper()


func _signed_note() -> String:
	var execute_on = _offer.get("execute_on")
	if execute_on == null or str(execute_on).is_empty():
		return "TRANSFER COMPLETED."
	return "TRANSFER COMPLETED · JOINS %s." \
		% CareerHubModel.short_date(str(execute_on)).to_upper()


# Layout / state -------------------------------------------------------------

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
	var flex := maxf(0.0, inner - STATUS_W - CREST_W - POS_W - DATE_W - COL_GAP * 5.0)
	var kind_w := maxf(70.0, flex * 0.74 / 2.54)
	var player_w := maxf(120.0, flex - kind_w)
	var x := PAD_X
	_dot.position = Vector2(x + (STATUS_W - DOT) * 0.5, (HEAD_H - DOT) * 0.5)
	_flag.position = Vector2(x + (STATUS_W - FLAG) * 0.5, (HEAD_H - FLAG) * 0.5)
	_flag.size = Vector2(FLAG, FLAG)
	x += STATUS_W + COL_GAP
	if _crest.visible:
		_crest.position = Vector2(x + (CREST_W - CREST) * 0.5, (HEAD_H - CREST) * 0.5)
		_crest.size = Vector2(CREST, CREST)
	_kind.position = Vector2(x + CREST_W + COL_GAP, 0.0)
	_kind.size = Vector2(kind_w, HEAD_H)
	x += CREST_W + COL_GAP + kind_w + COL_GAP
	_photo.position = Vector2(x, (HEAD_H - PHOTO_H) * 0.5)
	_photo.size = Vector2(PHOTO_W, PHOTO_H)
	_name.position = Vector2(x + PHOTO_W + 10.0, 0.0)
	_name.size = Vector2(maxf(40.0, player_w - PHOTO_W - 10.0), HEAD_H)
	x += player_w + COL_GAP
	_pos.position = Vector2(x, 0.0)
	_pos.size = Vector2(POS_W, HEAD_H)
	x += POS_W + COL_GAP
	_date.position = Vector2(x, 0.0)
	_date.size = Vector2(DATE_W, HEAD_H)

	_acc.position = Vector2(0.0, HEAD_H)
	_acc.size = Vector2(size.x, maxf(0.0, size.y - HEAD_H))
	if _open:
		_acc.custom_minimum_size.x = size.x


# The row grows instead of letting the panel slide over the next offer: the
# height tween makes the list below reflow while the panel fades in.
func _sync_height(animate := false) -> void:
	var target := HEAD_H
	if _open:
		_acc.visible = true
		_acc.size = Vector2(size.x, 0.0)
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
	var focused := _head != null and _head.has_focus()
	var lit := focused or _open
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_FILL if lit else UiTokens.TILE
	box.border_color = Color(UiTokens.INK, 0.10)
	box.border_width_bottom = 0 if lit else 1
	box.anti_aliasing = true
	_bg.add_theme_stylebox_override(&"panel", box)
	_rail.visible = not lit
	_name.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_MARK if lit else UiTokens.INK)
	_pos.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK if lit else UiTokens.INK)
	_kind.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK_2 if lit else UiTokens.INK_2)
	_date.add_theme_color_override(&"font_color",
		UiTokens.FOCUS_INK_2 if lit else UiTokens.INK_2)


func _play_open() -> void:
	var transition := get_node_or_null("/root/UiTransition")
	if transition != null and bool(transition.get("instant")):
		return
	if not is_inside_tree() or _acc == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_acc.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_acc, "modulate:a", 1.0, UiTokens.SCREEN_OUT)


func _play_close() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var transition := get_node_or_null("/root/UiTransition")
	if _acc == null or (transition != null and bool(transition.get("instant"))):
		if _acc != null:
			_acc.visible = false
		return
	_tween = create_tween()
	_tween.tween_property(_acc, "modulate:a", 0.0, 0.16)
	_tween.finished.connect(func() -> void:
		if not _open and _acc != null:
			_acc.visible = false)


# Input ----------------------------------------------------------------------

func _on_head_pressed() -> void:
	activated.emit(_offer_id)


func _on_head_focused() -> void:
	_apply_state()
	focused.emit(_offer_id)


func _on_action_pressed(id: String) -> void:
	for action in _actions:
		if action.id == id and not action.enabled:
			return
	action_requested.emit(id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_head.grab_focus()
			accept_event()
