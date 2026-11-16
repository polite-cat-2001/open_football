class_name CareerScoutHireModal
extends CareerScoutingModal
# Prototype career/scouting/ScoutingModal.svelte, hire state: the candidate list
# with experience/judgement stars and the price, the budget line and the
# unavailable rows dimmed. Confirm on an affordable candidate asks the host to
# hire him; the host runs the confirmation dialog.

signal hire_requested(scout_id: String)

const HIRE_ROW_H := 54.0


# One candidate row: scout + nationality, experience, judgement, price.
class HireRow extends Button:
	var id := ""
	var enabled := true
	var _bg: Panel
	var _flag: TextureRect
	var _name: Label
	var _country: Label
	var _experience: HBoxContainer
	var _judgement: HBoxContainer
	var _price: Label
	var _experience_count := 0
	var _judgement_count := 0
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
		_normal.bg_color = UiTokens.TILE
		_normal.anti_aliasing = true
		_focus = StyleBoxFlat.new()
		_focus.bg_color = UiTokens.FOCUS_FILL
		_focus.anti_aliasing = true
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_flag = TextureRect.new()
		_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_flag)
		_name = _label(UiTheme.barlow(700), 20)
		_country = _label(UiTheme.inter(500), 15)
		_country.add_theme_color_override(&"font_color", UiTokens.INK_2)
		_experience = CareerScoutCard.star_row()
		add_child(_experience)
		_judgement = CareerScoutCard.star_row()
		add_child(_judgement)
		_price = _label(UiTheme.barlow(700), 20)
		_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)

	func setup(candidate: Dictionary) -> void:
		id = str(candidate.get("id", ""))
		enabled = bool(candidate.get("affordable", true))
		_flag.texture = CareerScoutCard.flag_texture(candidate)
		_flag.visible = _flag.texture != null
		_name.text = str(candidate.get("name", "")).to_upper()
		_country.text = str(candidate.get("nationality", ""))
		_experience_count = int(candidate.get("experience", 0))
		_judgement_count = int(candidate.get("judgement", 0))
		CareerScoutCard.paint_stars(_experience, _experience_count,
			UiTokens.INK, CareerScoutCard.STAR_OFF)
		CareerScoutCard.paint_stars(_judgement, _judgement_count,
			UiTokens.INK, CareerScoutCard.STAR_OFF)
		_price.text = CareerPlayerPane.money(int(candidate.get("price", 0)))
		modulate.a = 1.0 if enabled else 0.42
		_apply_state()
		_layout_content()

	func _label(font: Font, font_size: int) -> Label:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", UiTokens.INK)
		add_child(label)
		return label

	func _layout_content() -> void:
		if _bg == null:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		var inner := maxf(0.0, size.x - 32.0)
		var scout_w := inner * 0.46
		var stars_w := inner * 0.17
		var price_w := inner * 0.15
		var x := 16.0
		if _flag.visible:
			_flag.position = Vector2(x, (size.y - 24.0) * 0.5)
			_flag.size = Vector2(36.0, 24.0)
			x += 46.0
		var name_w := maxf(40.0, scout_w - (x - 16.0))
		_name.position = Vector2(x, 8.0)
		_name.size = Vector2(name_w, 24.0)
		_country.position = Vector2(x, 30.0)
		_country.size = Vector2(name_w, 18.0)
		var stars_x := 16.0 + scout_w + 12.0
		_experience.position = Vector2(stars_x, (size.y - 22.0) * 0.5 - 10.0)
		_experience.size = Vector2(stars_w, 22.0)
		_judgement.position = Vector2(stars_x + stars_w + 12.0,
			(size.y - 22.0) * 0.5 - 10.0)
		_judgement.size = Vector2(stars_w, 22.0)
		_price.position = Vector2(size.x - 16.0 - price_w, 0.0)
		_price.size = Vector2(price_w, size.y)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus if focused else _normal)
		_name.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if focused else UiTokens.INK)
		_country.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK_2 if focused else UiTokens.INK_2)
		_price.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if focused else UiTokens.INK)
		for box in [_experience, _judgement]:
			CareerScoutCard.paint_stars(box,
				_experience_count if box == _experience else _judgement_count,
				UiTokens.FOCUS_INK if focused else UiTokens.INK,
				Color(UiTokens.FOCUS_INK, 0.24) if focused else CareerScoutCard.STAR_OFF)


var _hire_rows: Array[HireRow] = []


func setup_candidates(candidates: Array, balance: int) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 1)
	set_content(column)
	_hire_rows.clear()
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		var row := HireRow.new()
		row.custom_minimum_size.y = HIRE_ROW_H
		column.add_child(row)
		row.setup(candidate)
		row.pressed.connect(_on_hire_row.bind(row))
		_hire_rows.append(row)
	if _hire_rows.is_empty():
		var empty := Label.new()
		empty.text = "No scouts are available."
		empty.custom_minimum_size.y = 44.0
		empty.add_theme_font_override(&"font", UiTheme.inter(500))
		empty.add_theme_font_size_override(&"font_size", 16)
		empty.add_theme_color_override(&"font_color", UiTokens.INK_2)
		column.add_child(empty)
	set_focusables(_hire_rows)
	setup("Hire a scout", "Budget %s" % CareerPlayerPane.money(balance), [])


func candidate_ids() -> Array:
	var ids: Array = []
	for row in _hire_rows:
		ids.append(row.id)
	return ids


func _on_hire_row(row: HireRow) -> void:
	if row.enabled:
		hire_requested.emit(row.id)

