class_name CareerPlayerPane
extends ScrollContainer
# Prototype .tf-detail + the player-actions metric blocks: the right-hand player
# card of the transfer screens. Photo, name, club crest, a facts row, the state
# chips, the two-column metrics/attribute block, status lines and optional
# action rows. Everything the scouts have not revealed (scouted == false) shows
# as a single ?.
#
# Deviation from the prototype: the attribute column lists every attribute,
# paged one group per page (MENTAL / PHYSICAL / TECHNICAL) with arrows, the
# right stick and a dot indicator — all 22 in one list would need a scrollbar.
#
# The root scrolls vertically like .tf-detail (overflow-y:auto): put it in the
# right-hand column and give it the column's size.
#
# Money formatting mirrors the other career screens
# (CareerSquadView._format_value): €1.2B / €12M / €850K / €0.

signal action_chosen(id: String)

const PAD := 16.0
const PHOTO_W := 120.0
const PHOTO_H := 128.0
const CREST := 32.0
const METRIC_ROW_H := 30.0
const STATUS_ROW_H := 26.0
const ACTION_H := 44.0
const HIDDEN := "?"
const MARK_WIN := Color("2f7d4f")
const MARK_LOSS := Color("b23a48")
const MARK_WARN := Color("a66a00")


# One focusable action row (large flat row, rail on focus). A disabled row keeps
# focus but does nothing on confirm and prints its ticket dimmed.
class ActionRow extends Button:
	var id := ""
	var key := ""
	var enabled := true
	var _bg: Panel
	var _rail: ColorRect
	var _label: Label
	var _ticket: Label

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_rail = ColorRect.new()
		_rail.color = UiTokens.RAIL
		_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rail)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_override(&"font", UiTheme.barlow(700))
		_label.add_theme_font_size_override(&"font_size", 20)
		add_child(_label)
		_ticket = Label.new()
		_ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ticket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ticket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ticket.add_theme_font_override(&"font", UiTheme.inter(700))
		_ticket.add_theme_font_size_override(&"font_size", 14)
		add_child(_ticket)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func setup(row: Dictionary) -> void:
		id = str(row.get("id", ""))
		key = str(row.get("key", ""))
		enabled = bool(row.get("enabled", true))
		_label.text = str(row.get("label", "")).to_upper()
		_apply_state()
		_layout_content()

	func label_text() -> String:
		return "" if _label == null else str(_label.text)

	func ticket_text() -> String:
		return key

	func _layout_content() -> void:
		if _bg == null:
			return
		_bg.size = size
		_rail.position = Vector2.ZERO
		_rail.size = Vector2(UiTokens.RAIL_W, size.y)
		# The ticket carries a key or a reason ("TRANSFER CENTRE"), so it is as
		# wide as its text.
		var ticket_w := 0.0
		if not key.is_empty():
			ticket_w = _ticket.get_theme_font(&"font").get_string_size(key,
				HORIZONTAL_ALIGNMENT_LEFT, -1,
				_ticket.get_theme_font_size(&"font_size")).x + 14.0
		_ticket.position = Vector2(size.x - 14.0 - ticket_w, (size.y - 20.0) * 0.5)
		_ticket.size = Vector2(ticket_w, 20.0)
		_label.position = Vector2(14.0, 0.0)
		_label.size = Vector2(maxf(0.0, size.x - 28.0 - ticket_w - 10.0), size.y)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL if focused else Color(UiTokens.INK, 0.055)
		box.anti_aliasing = true
		_bg.add_theme_stylebox_override(&"panel", box)
		_rail.visible = not focused
		var ink := UiTokens.FOCUS_MARK if focused and enabled else (
			UiTokens.FOCUS_INK_2 if focused else (UiTokens.INK if enabled else UiTokens.INK_2))
		_label.add_theme_color_override(&"font_color", ink)
		_ticket.visible = not key.is_empty()
		_ticket.text = key
		var ticket_box := StyleBoxFlat.new()
		ticket_box.bg_color = Color(UiTokens.RAIL, 0.16) if focused \
			else Color(UiTokens.INK, 0.09)
		_ticket.add_theme_stylebox_override(&"normal", ticket_box)
		_ticket.add_theme_color_override(&"font_color",
			UiTokens.RAIL if focused else UiTokens.INK_2)


var _player: Dictionary = {}
var _player_id := ""
var _options: Dictionary = {}
var _show_actions := false
# A host that already draws the card frame (the player-actions modal) turns the
# pane's own tile/shadow off.
var _card_panel: StyleBoxFlat

var _content: VBoxContainer
var _photo: CareerPlayerCard.Photo
var _name: Label
var _fact_values: Array[Label] = []
var _club_photo: CareerPlayerCard.Photo
var _club_name: Label
var _chips: VBoxContainer
var _metric_values: Array[Label] = []
var _stat_values: Array[Label] = []
# One page per attribute group (MENTAL / PHYSICAL / TECHNICAL): the full list no
# longer fits a card without a scrollbar, so Q / E or the right stick page it,
# the dots show where we are.
var _stat_pages: Array[VBoxContainer] = []
var _stat_page := 0
var _pager: HBoxContainer
var _dots: HBoxContainer
var _stick_latch := false
var _status_box: VBoxContainer
var _actions: VBoxContainer
var _tween: Tween


# Shared helpers -------------------------------------------------------------

static func money(value: int) -> String:
	if value >= 1000000000:
		return "€%.1fB" % (float(value) / 1000000000.0)
	if value >= 1000000:
		var millions := float(value) / 1000000.0
		return "€%.0fM" % millions if value >= 10000000 else "€%.1fM" % millions
	if value >= 1000:
		return "€%dK" % int(round(float(value) / 1000.0))
	return "€%d" % value


static func status_line(status: String) -> String:
	match status:
		"free":
			return "Free agent"
		"loan":
			return "On loan"
		"transfer":
			return "Transfer listed"
		"blocked":
			return "Blocked"
	return "At club"


# Whole months between two YYYY-MM-DD dates, -1 when either is unusable.
static func months_until(target: String, current: String) -> int:
	if target.length() < 10 or current.length() < 10:
		return -1
	var target_dict := {
		"year": int(target.substr(0, 4)), "month": int(target.substr(5, 2)),
		"day": int(target.substr(8, 2)),
	}
	var current_dict := {
		"year": int(current.substr(0, 4)), "month": int(current.substr(5, 2)),
		"day": int(current.substr(8, 2)),
	}
	var days := (Time.get_unix_time_from_datetime_dict(target_dict) \
		- Time.get_unix_time_from_datetime_dict(current_dict)) / 86400.0
	if days <= 0.0:
		return 0
	return int(ceil(days / 30.44))


# Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	# The caps name the current input device: Q / E or the right stick.
	var nav := get_node_or_null("/root/UiNav")
	if nav != null and nav.has_signal("device_changed"):
		nav.connect("device_changed", _on_device_changed)


func _on_device_changed(_gamepad: bool) -> void:
	if _pager != null:
		_build_pager()


func setup(player: Dictionary, options := {}) -> void:
	_player = player
	_options = options
	_player_id = str(player.get("player_id", player.get("id", "")))
	_show_actions = bool(options.get("show_actions", options.has("action_rows")))
	if options.has("width"):
		custom_minimum_size.x = float(options["width"])
	if _content == null:
		return
	if _card_panel != null:
		var flat := bool(options.get("flat", false))
		_card_panel.bg_color = Color(UiTokens.TILE, 0.0) if flat else UiTokens.TILE
		_card_panel.shadow_size = 0 if flat else 32
	_refresh()
	if options.has("action_rows"):
		set_action_rows(options["action_rows"])
	_play_swap()


func player() -> Dictionary:
	return _player


func player_id() -> String:
	return _player_id


func set_action_rows(rows: Array) -> void:
	if _actions == null:
		return
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	for row in rows:
		var button := ActionRow.new()
		button.custom_minimum_size.y = ACTION_H
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actions.add_child(button)
		button.setup(row)
		button.pressed.connect(_on_action_pressed.bind(button))
	_actions.visible = _show_actions and not rows.is_empty()


func action_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	if _actions == null:
		return buttons
	for child in _actions.get_children():
		buttons.append(child as Button)
	return buttons


# Build ----------------------------------------------------------------------

func _build() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var card := PanelContainer.new()
	card.name = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fills the host column (the ScrollContainer stretches an EXPAND child), so
	# the card is as tall as the list beside it instead of hugging its content.
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := StyleBoxFlat.new()
	panel.bg_color = UiTokens.TILE
	panel.shadow_color = UiTokens.SHADOW
	panel.shadow_size = 32
	panel.shadow_offset = Vector2(0.0, 24.0)
	panel.content_margin_left = PAD
	panel.content_margin_right = PAD
	panel.content_margin_top = PAD
	panel.content_margin_bottom = PAD
	card.add_theme_stylebox_override(&"panel", panel)
	_card_panel = panel
	add_child(card)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override(&"separation", 10)
	card.add_child(_content)

	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override(&"separation", 12)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content.add_child(head)

	_photo = CareerPlayerCard.Photo.new()
	_photo.name = "Photo"
	_photo.custom_minimum_size = Vector2(PHOTO_W, PHOTO_H)
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_photo)

	var info := VBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override(&"separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)

	_name = Label.new()
	_name.name = "Name"
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.add_theme_font_override(&"font", UiTheme.barlow(700))
	_name.add_theme_font_size_override(&"font_size", 30)
	_name.add_theme_color_override(&"font_color", UiTokens.INK)
	info.add_child(_name)

	var facts := GridContainer.new()
	facts.name = "Facts"
	facts.columns = 2
	facts.add_theme_constant_override(&"h_separation", 12)
	facts.add_theme_constant_override(&"v_separation", 4)
	facts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(facts)
	for key in ["AGE", "HEIGHT", "POSITION", "FOOT"]:
		var fact := VBoxContainer.new()
		fact.name = key
		fact.add_theme_constant_override(&"separation", 0)
		facts.add_child(fact)
		var label := Label.new()
		label.text = key
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 12)
		label.add_theme_color_override(&"font_color", UiTokens.INK_2)
		fact.add_child(label)
		var value := Label.new()
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		value.add_theme_font_override(&"font", UiTheme.inter(600))
		value.add_theme_font_size_override(&"font_size", 15)
		value.add_theme_color_override(&"font_color", UiTokens.INK)
		fact.add_child(value)
		_fact_values.append(value)

	var club := VBoxContainer.new()
	club.name = "Club"
	club.add_theme_constant_override(&"separation", 4)
	club.size_flags_vertical = Control.SIZE_EXPAND_FILL
	head.add_child(club)
	_club_photo = CareerPlayerCard.Photo.new()
	_club_photo.name = "Crest"
	_club_photo.custom_minimum_size = Vector2(CREST, CREST)
	_club_photo.size_flags_horizontal = Control.SIZE_SHRINK_END
	club.add_child(_club_photo)
	_club_name = Label.new()
	_club_name.name = "ClubName"
	_club_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_club_name.max_lines_visible = 2
	_club_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_club_name.custom_minimum_size.x = 110.0
	_club_name.add_theme_font_override(&"font", UiTheme.inter(500))
	_club_name.add_theme_font_size_override(&"font_size", 14)
	_club_name.add_theme_color_override(&"font_color", UiTokens.INK_2)
	club.add_child(_club_name)
	# The pager hugs the bottom of the head, right-aligned above the attributes:
	# it stays off the metrics grid, so the attribute rows keep their place.
	var club_spacer := Control.new()
	club_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	club_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	club.add_child(club_spacer)
	_pager = HBoxContainer.new()
	_pager.name = "Pager"
	_pager.alignment = BoxContainer.ALIGNMENT_END
	_pager.add_theme_constant_override(&"separation", 6)
	_pager.custom_minimum_size.y = 28.0
	club.add_child(_pager)

	# Tags stack under the general-info rows of the left column.
	_chips = VBoxContainer.new()
	_chips.name = "Chips"
	_chips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chips.add_theme_constant_override(&"separation", 4)

	var metrics := HBoxContainer.new()
	metrics.name = "Metrics"
	metrics.add_theme_constant_override(&"separation", 8)
	_content.add_child(metrics)
	for column in 2:
		var box := VBoxContainer.new()
		box.name = "Column%d" % column
		box.add_theme_constant_override(&"separation", 1)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics.add_child(box)
		if column == 0:
			for label_text in ["OVERALL", "PRICE", "WAGE", "RELEASE CLAUSE"]:
				var value := _make_value_label()
				var row := _make_block(label_text, label_text, value, 5, 12, METRIC_ROW_H)
				row.name = label_text
				box.add_child(row)
				_metric_values.append(value)
			var chip_wrap := MarginContainer.new()
			chip_wrap.name = "ChipWrap"
			chip_wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			chip_wrap.add_theme_constant_override(&"margin_top", 8)
			chip_wrap.add_child(_chips)
			box.add_child(chip_wrap)
			continue
		for group in CareerSquad.ATTRIBUTE_GROUPS:
			var page := VBoxContainer.new()
			page.name = str(group["id"])
			page.add_theme_constant_override(&"separation", 1)
			box.add_child(page)
			_stat_pages.append(page)
			for key in group["keys"]:
				var value := _make_value_label()
				var row := _make_block(key, _stat_label(str(key)), value, 5, 12, METRIC_ROW_H)
				page.add_child(row)
				_stat_values.append(value)
		_build_pager()
		_set_page(0)

	_status_box = VBoxContainer.new()
	_status_box.name = "Status"
	_status_box.add_theme_constant_override(&"separation", 1)
	# The statuses sit on the bottom edge of the card: the spacer eats the slack.
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(spacer)
	_content.add_child(_status_box)

	_actions = VBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override(&"separation", 1)
	_actions.visible = false
	_content.add_child(_actions)


func _make_value_label() -> Label:
	var value := Label.new()
	value.add_theme_font_override(&"font", UiTheme.barlow(700))
	value.add_theme_font_size_override(&"font_size", 20)
	value.add_theme_color_override(&"font_color", UiTokens.INK)
	return value


# Pager ----------------------------------------------------------------------

# The caps name whatever pages the card: Q / E on the keyboard, the right stick
# on a gamepad. They are hints, not buttons.
func _build_pager() -> void:
	for child in _pager.get_children():
		_pager.remove_child(child)
		child.free()
	if _gamepad():
		# One circled R: the right stick pages the card both ways.
		_pager.add_child(_make_stick_cap())
	else:
		_pager.add_child(_make_key_cap("Q"))
	_dots = HBoxContainer.new()
	_dots.name = "Dots"
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override(&"separation", 4)
	_pager.add_child(_dots)
	if not _gamepad():
		_pager.add_child(_make_key_cap("E"))
	_set_page(_stat_page)


func _make_stick_cap() -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(22.0, 22.0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTokens.INK, 0.09)
	style.set_corner_radius_all(11)
	box.add_theme_stylebox_override(&"panel", style)
	var label := Label.new()
	label.text = "R"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.inter(700))
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	box.add_child(label)
	return box


func _make_key_cap(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(24.0, 20.0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTokens.INK, 0.09)
	box.add_theme_stylebox_override(&"panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.inter(700))
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	box.add_child(label)
	return box


func _gamepad() -> bool:
	var nav := get_node_or_null("/root/UiNav")
	return nav != null and nav.has_method("using_gamepad") and bool(nav.call("using_gamepad"))


func _step_page(delta: int) -> void:
	_set_page(_stat_page + delta)


func _set_page(index: int) -> void:
	if _stat_pages.is_empty():
		return
	_stat_page = posmod(index, _stat_pages.size())
	for page_index in _stat_pages.size():
		_stat_pages[page_index].visible = page_index == _stat_page
	for child in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	for page_index in _stat_pages.size():
		_dots.add_child(_make_dot(page_index == _stat_page))


func _make_dot(active: bool) -> Control:
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(6.0, 6.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.INK if active else Color(UiTokens.INK_2, 0.3)
	box.set_corner_radius_all(3)
	dot.add_theme_stylebox_override(&"panel", box)
	return dot


# Q / E and the right stick page the attributes of the card on screen: with a
# modal open only the card inside it reacts, never the screen behind.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _owns_input():
		return
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == KEY_Q:
			_step_page(-1)
		elif code == KEY_E:
			_step_page(1)
		return
	var motion := event as InputEventJoypadMotion
	if motion == null or motion.axis != JOY_AXIS_RIGHT_X:
		return
	if absf(motion.axis_value) < 0.6:
		_stick_latch = false
		return
	if _stick_latch:
		return
	_stick_latch = true
	_step_page(1 if motion.axis_value > 0.0 else -1)


func _owns_input() -> bool:
	var nav := get_node_or_null("/root/UiNav")
	if nav == null or not nav.has_method("is_modal") or not bool(nav.call("is_modal")):
		return true
	var owner: Node = nav.call("modal_owner")
	# The pane that sits inside the open modal owns the keys; the pane of the
	# screen behind it does not.
	return owner != null and owner.is_ancestor_of(self)


func _stat_label(key: String) -> String:
	return str(CareerSquad.STAT_LABELS.get(key, key)).to_upper()


# A label/value row on the tinted background (prototype .gf-metric).
func _make_block(row_name: String, label_text: String, value: Label,
		pad_y: float, pad_x: float, min_h := 0.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = row_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.055)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	panel.add_theme_stylebox_override(&"panel", box)
	if min_h > 0.0:
		panel.custom_minimum_size.y = min_h
	var line := HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override(&"separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.inter(600))
	label.add_theme_font_size_override(&"font_size", 14)
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	line.add_child(label)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value)
	return panel


# Content --------------------------------------------------------------------

func _refresh() -> void:
	var revealed := bool(_player.get("scouted", false))
	var group := str(_player.get("position_group", ""))
	_photo.show_texture(CareerPlayerCard.face_texture(_player))
	_name.text = str(_player.get("name", "")).to_upper()
	_fact_values[0].text = CareerPlayerCard.age_value(_player)
	var height := int(_player.get("height", 0))
	_fact_values[1].text = "%d CM" % height if height > 0 else HIDDEN
	_fact_values[2].text = CareerPlayerCard.position_code(
		str(_player.get("position", "")), group)
	_fact_values[3].text = _foot_label(str(_player.get("foot", ""))) if revealed else HIDDEN
	var crest := CareerPlayerCard.crest_texture(_player)
	_club_photo.show_texture(crest)
	_club_photo.visible = crest != null
	var club_name := str(_player.get("club_name", ""))
	_club_name.text = club_name if not club_name.is_empty() else "Free agent"
	_refresh_chips(revealed)
	for index in _metric_values.size():
		var key: String = ["overall", "price", "wage", "release_clause"][index]
		var raw: Variant = _player.get(key, 0)
		if key == "price":
			raw = _player.get("market_value", _player.get("price", 0))
		elif key == "wage":
			raw = _player.get("wage", _player.get("weekly_wage", 0))
		var text := HIDDEN
		# The release clause is public knowledge even for an unscouted player.
		if key == "release_clause":
			text = money(int(raw))
		elif revealed:
			if key == "overall":
				var overall := int(round(float(raw)))
				text = str(overall) if overall > 0 else HIDDEN
			elif key == "wage":
				text = money(int(raw)) + " / WEEK"
			else:
				text = money(int(raw))
		_metric_values[index].text = text
		_metric_values[index].add_theme_color_override(&"font_color",
			UiTokens.INK if revealed or key == "release_clause" else UiTokens.INK_2)
	var stats: Dictionary = _player.get("stats", {}) if _player.get("stats") is Dictionary else {}
	var keys := _stat_keys()
	for index in _stat_values.size():
		var text := HIDDEN
		if revealed:
			var raw := int(round(float(stats.get(keys[index], 0))))
			text = str(raw) if raw > 0 else HIDDEN
		_stat_values[index].text = text
		_stat_values[index].add_theme_color_override(&"font_color",
			UiTokens.INK if revealed else UiTokens.INK_2)
	_refresh_status()


func _stat_keys() -> Array:
	var keys: Array = []
	for group in CareerSquad.ATTRIBUTE_GROUPS:
		keys.append_array(group["keys"])
	return keys


func _money_value(raw: Variant, revealed: bool) -> String:
	if not revealed:
		return HIDDEN
	return money(int(raw))


func _foot_label(foot: String) -> String:
	match foot.to_lower():
		"left":
			return "Left"
		"right":
			return "Right"
		"both":
			return "Both"
	return HIDDEN


func _refresh_chips(revealed: bool) -> void:
	var labels: Array[String] = []
	var status := str(_player.get("status", ""))
	if bool(_player.get("shortlisted", false)):
		labels.append("SHORTLIST")
	if bool(_player.get("listed_for_transfer", false)) \
			and status != "transfer" and status != "loan":
		labels.append("LISTED FOR TRANSFER")
	if not status.is_empty() and status != "blocked" and status != "contracted":
		labels.append(CareerPlayerCard.status_label(status))
	if not revealed:
		labels.append("NOT SCOUTED")
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	for text in labels:
		_chips.add_child(_make_chip(text))
	_chips.visible = not labels.is_empty()


func _make_chip(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.07)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override(&"panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", UiTheme.inter(600))
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	panel.add_child(label)
	return panel


func _refresh_status() -> void:
	for child in _status_box.get_children():
		_status_box.remove_child(child)
		child.queue_free()
	var status := str(_player.get("status", ""))
	var lines: Array = []
	var available := bool(_player.get("available", true))
	lines.append({"text": status_line(status), "warn": status == "blocked"})
	if status != "free" and status != "blocked":
		lines.append({
			"text": "Available for talks" if available else "Unavailable right now",
			"warn": not available,
		})
	var months := int(_player.get("contract_months", -1))
	var expires := str(_player.get("contract_expires", ""))
	if months < 0 and not expires.is_empty():
		months = months_until(expires, str(_options.get("date", "")))
	if months >= 0 and status != "free":
		var text := "Contract expires in %d %s" % [
			months, "month" if months == 1 else "months"]
		if months <= 0:
			text = "Contract expires this month"
		lines.append({"text": text, "warn": months <= 6})
	for line in lines:
		_status_box.add_child(_make_status_line(str(line["text"]), bool(line["warn"])))


func _make_status_line(text: String, warn: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.055)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override(&"panel", box)
	panel.custom_minimum_size.y = STATUS_ROW_H
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	panel.add_child(line)
	line.add_child(_make_status_mark(warn))
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.inter(500))
	label.add_theme_font_size_override(&"font_size", 14)
	label.add_theme_color_override(&"font_color", MARK_WARN if warn else UiTokens.INK_2)
	line.add_child(label)
	return panel


func _make_status_mark(warn: bool) -> Control:
	if warn:
		var bang := PanelContainer.new()
		bang.custom_minimum_size = Vector2(20.0, 20.0)
		bang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var box := StyleBoxFlat.new()
		box.bg_color = Color(MARK_WARN, 0.12)
		bang.add_theme_stylebox_override(&"panel", box)
		var label := Label.new()
		label.text = "!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override(&"font", UiTheme.inter(700))
		label.add_theme_font_size_override(&"font_size", 12)
		label.add_theme_color_override(&"font_color", MARK_WARN)
		bang.add_child(label)
		return bang
	var dot := ColorRect.new()
	dot.color = MARK_WIN
	dot.custom_minimum_size = Vector2(8.0, 8.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return dot


func _play_swap() -> void:
	if not is_inside_tree() or _instant():
		return
	if _tween != null:
		_tween.kill()
	_content.modulate.a = 0.35
	_tween = create_tween()
	_tween.tween_property(_content, "modulate:a", 1.0, 0.12)


# Autoloads are looked up by path: the widgets are also instantiated by the
# headless tests directly, where a bare UiTransition identifier does not resolve.
func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _on_action_pressed(row: ActionRow) -> void:
	if row.enabled:
		action_chosen.emit(row.id)
