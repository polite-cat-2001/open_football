class_name CareerPlayerPane
extends ScrollContainer
# Prototype .tf-detail + the player-actions metric blocks: the right-hand player
# card of the transfer screens. Photo, name, club crest, a facts row, the state
# chips, the two-column metrics/attribute block, status lines and optional
# action rows. Everything the scouts have not revealed (scouted == false) shows
# as ? / ???.
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
const HIDDEN_STAT := "???"
const UNKNOWN := "—"
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
var _chips: HBoxContainer
var _metric_values: Array[Label] = []
var _stat_values: Array[Label] = []
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
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	club.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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

	_chips = HBoxContainer.new()
	_chips.name = "Chips"
	_chips.add_theme_constant_override(&"separation", 6)
	_content.add_child(_chips)

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
		var labels := ["OVERALL", "PRICE", "WAGE", "RELEASE CLAUSE"] if column == 0 \
			else _stat_labels()
		for label_text in labels:
			var value := Label.new()
			value.add_theme_font_override(&"font", UiTheme.barlow(700))
			value.add_theme_font_size_override(&"font_size", 20)
			value.add_theme_color_override(&"font_color", UiTokens.INK)
			var row := _make_block(label_text, label_text, value, 5, 12, METRIC_ROW_H)
			row.name = label_text
			box.add_child(row)
			if column == 0:
				_metric_values.append(value)
			else:
				_stat_values.append(value)

	_status_box = VBoxContainer.new()
	_status_box.name = "Status"
	_status_box.add_theme_constant_override(&"separation", 1)
	_content.add_child(_status_box)

	_actions = VBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override(&"separation", 1)
	_actions.visible = false
	_content.add_child(_actions)


func _stat_labels() -> Array:
	var labels: Array = []
	for key in _stat_keys():
		labels.append(str(CareerSquad.STAT_LABELS.get(key, key)).to_upper())
	return labels


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
	_fact_values[1].text = "%d CM" % height if height > 0 else UNKNOWN
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
				text = str(overall) if overall > 0 else UNKNOWN
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
		var text := HIDDEN_STAT
		if revealed:
			var raw := int(round(float(stats.get(keys[index], 0))))
			text = str(raw) if raw > 0 else UNKNOWN
		_stat_values[index].text = text
		_stat_values[index].add_theme_color_override(&"font_color",
			UiTokens.INK if revealed else UiTokens.INK_2)
	_refresh_status()


func _stat_keys() -> Array:
	var keys: Array = []
	for group in CareerSquad.ATTRIBUTE_GROUPS:
		for key in group["keys"]:
			if keys.size() >= 6:
				return keys
			keys.append(key)
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
	return UNKNOWN


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
