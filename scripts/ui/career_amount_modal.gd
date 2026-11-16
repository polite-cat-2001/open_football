class_name CareerAmountModal
extends Control
# Prototype shared/AmountModal.svelte: a modal amount editor. Nine digit places
# in three groups (hundreds of millions … units), left/right walks the places,
# up/down rolls the digit of the focused place, confirm applies and Esc/Back
# closes. Owns UiNav while open (push_modal/pop_modal) and animates with the
# shell's fade+scale (150 out / 240 in). The committed value is
# digits × place_multiplier, clamped to [min, max] and snapped to step.
#
# Money goes through CareerPlayerPane.money so every career screen prints the
# same €12.5M / €850K units.

signal applied(value: int)
signal closed

const PLACES := [
	"HUNDREDS OF MILLIONS", "TENS OF MILLIONS", "MILLIONS",
	"HUNDREDS OF THOUSANDS", "TENS OF THOUSANDS", "THOUSANDS",
	"HUNDREDS", "TENS", "UNITS",
]
const DIGITS := 9
const GROUPS := 3
const CARD_W := 480.0
const CARD_PAD := 28.0
const DIGIT_W := 40.0
const DIGIT_H := 64.0
const SCALE_FROM := 0.96
const OUT_TIME := 0.15
const IN_TIME := 0.24
const SCRIM := Color(0.024, 0.047, 0.102, 0.68)

var _open := false
var _digits := PackedInt32Array()
var _index := DIGITS - 1
var _title := "AMOUNT"
var _hint := ""
var _confirm := "DONE"
var _min := 0
var _max := 999999999
var _step := 0
var _multiplier := 1

var _scrim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _value_box: PanelContainer
var _place: Label
var _preview: Label
var _hint_label: Label
var _foot: HBoxContainer
var _digit_panels: Array[PanelContainer] = []
var _digit_labels: Array[Label] = []
var _carets_top: Array[Label] = []
var _carets_bottom: Array[Label] = []
var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_digits.resize(DIGITS)
	_digits.fill(0)
	_build()
	resized.connect(_layout)
	_connect_nav()
	call_deferred("_layout")


func open(value: int, config := {}) -> void:
	_title = str(config.get("title", "AMOUNT"))
	_hint = str(config.get("hint", ""))
	_confirm = str(config.get("confirm_label", "DONE"))
	_min = int(config.get("min", 0))
	_max = int(config.get("max", 999999999))
	_step = maxi(0, int(config.get("step", 0)))
	_multiplier = maxi(1, int(config.get("place_multiplier", 1)))
	var units := maxi(0, int(value / float(_multiplier)))
	var text := str(mini(units, 999999999)).pad_zeros(DIGITS)
	for index in DIGITS:
		_digits[index] = int(text[index])
	_index = DIGITS - 1
	for index in DIGITS:
		if _digits[index] != 0:
			_index = index
			break
	_title_label.text = _title.to_upper()
	_hint_label.text = _hint
	_hint_label.visible = not _hint.is_empty()
	_refresh()
	if _tween != null:
		_tween.kill()
	visible = true
	_open = true
	var nav := _ui_nav()
	if nav != null:
		nav.push_modal(self)
	_layout()
	_card.pivot_offset = _card.size * 0.5
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE * SCALE_FROM
	_scrim.modulate.a = 0.0
	if not _instant():
		_tween = create_tween().set_parallel(true)
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_card, "modulate:a", 1.0, IN_TIME)
		_tween.tween_property(_card, "scale", Vector2.ONE, IN_TIME)
		_tween.tween_property(_scrim, "modulate:a", 1.0, OUT_TIME)
	else:
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
		_scrim.modulate.a = 1.0


func close() -> void:
	if not _open:
		return
	_open = false
	var nav := _ui_nav()
	if nav != null:
		nav.pop_modal(self)
	closed.emit()
	if _tween != null:
		_tween.kill()
	_card.pivot_offset = _card.size * 0.5
	if _instant():
		visible = false
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_card, "modulate:a", 0.0, OUT_TIME)
	_tween.tween_property(_card, "scale", Vector2.ONE * SCALE_FROM, OUT_TIME)
	_tween.tween_property(_scrim, "modulate:a", 0.0, OUT_TIME)
	_tween.chain().tween_callback(func() -> void: visible = false)


func is_open() -> bool:
	return _open


func value() -> int:
	var units := 0
	for digit in _digits:
		units = units * 10 + digit
	return units * _multiplier


func index() -> int:
	return _index


func digit(at: int) -> int:
	return _digits[clampi(at, 0, DIGITS - 1)]


func place_text() -> String:
	return str(_place.text)


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
	box.content_margin_left = CARD_PAD
	box.content_margin_right = CARD_PAD
	box.content_margin_top = 24.0
	box.content_margin_bottom = 24.0
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 16)
	_card.add_child(column)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override(&"font", UiTheme.barlow(700))
	_title_label.add_theme_font_size_override(&"font_size", 24)
	_title_label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	column.add_child(_title_label)

	_value_box = PanelContainer.new()
	_value_box.name = "Value"
	var value_box := StyleBoxFlat.new()
	value_box.bg_color = Color(UiTokens.INK, 0.055)
	value_box.content_margin_left = 18.0
	value_box.content_margin_right = 18.0
	value_box.content_margin_top = 16.0
	value_box.content_margin_bottom = 16.0
	_value_box.add_theme_stylebox_override(&"panel", value_box)
	column.add_child(_value_box)

	var groups := HBoxContainer.new()
	groups.name = "Groups"
	groups.alignment = BoxContainer.ALIGNMENT_CENTER
	groups.add_theme_constant_override(&"separation", 18)
	_value_box.add_child(groups)
	for group_index in GROUPS:
		var group := HBoxContainer.new()
		group.name = "Group%d" % group_index
		group.add_theme_constant_override(&"separation", 4)
		groups.add_child(group)
		for offset in 3:
			group.add_child(_make_digit(group_index * 3 + offset))

	_place = Label.new()
	_place.name = "Place"
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place.add_theme_font_override(&"font", UiTheme.inter(600))
	_place.add_theme_font_size_override(&"font_size", 18)
	_place.add_theme_color_override(&"font_color", UiTokens.INK_2)
	column.add_child(_place)

	_preview = Label.new()
	_preview.name = "Preview"
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.add_theme_font_override(&"font", UiTheme.barlow(700))
	_preview.add_theme_font_size_override(&"font_size", 28)
	_preview.add_theme_color_override(&"font_color", UiTokens.INK)
	column.add_child(_preview)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	_hint_label.add_theme_font_override(&"font", UiTheme.inter(500))
	_hint_label.add_theme_font_size_override(&"font_size", 15)
	_hint_label.add_theme_color_override(&"font_color", UiTokens.INK_2)
	column.add_child(_hint_label)

	_foot = HBoxContainer.new()
	_foot.name = "Foot"
	_foot.alignment = BoxContainer.ALIGNMENT_BEGIN
	_foot.add_theme_constant_override(&"separation", 20)
	add_child(_foot)


func _make_digit(index: int) -> Control:
	var column := VBoxContainer.new()
	column.name = "Digit%d" % index
	column.add_theme_constant_override(&"separation", 2)
	var top := _make_caret("▲")
	top.name = "Up"
	column.add_child(top)
	_carets_top.append(top)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(DIGIT_W, DIGIT_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_digit_input.bind(index))
	column.add_child(panel)
	_digit_panels.append(panel)
	var label := Label.new()
	label.name = "Digit"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.barlow(700))
	label.add_theme_font_size_override(&"font_size", 40)
	panel.add_child(label)
	_digit_labels.append(label)
	var bottom := _make_caret("▼")
	bottom.name = "Down"
	column.add_child(bottom)
	_carets_bottom.append(bottom)
	return column


func _make_caret(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", UiTheme.inter(600))
	label.add_theme_font_size_override(&"font_size", 10)
	label.add_theme_color_override(&"font_color", UiTokens.INK)
	label.modulate.a = 0.0
	return label


# State ----------------------------------------------------------------------

func _refresh() -> void:
	for index in DIGITS:
		var selected := index == _index
		_digit_labels[index].text = str(_digits[index])
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL if selected else Color(1.0, 1.0, 1.0, 0.72)
		_digit_panels[index].add_theme_stylebox_override(&"panel", box)
		_digit_labels[index].add_theme_color_override(&"font_color",
			UiTokens.FOCUS_MARK if selected else UiTokens.INK)
		_carets_top[index].modulate.a = 1.0 if selected else 0.0
		_carets_bottom[index].modulate.a = 1.0 if selected else 0.0
	_place.text = "PLACE: %s" % PLACES[_index]
	_preview.text = CareerPlayerPane.money(value())
	_refresh_foot()


func _refresh_foot() -> void:
	for child in _foot.get_children():
		_foot.remove_child(child)
		child.queue_free()
	var nav := _ui_nav()
	var gamepad: bool = nav != null and nav.using_gamepad()
	var items := [
		["◀", "▶"] if gamepad else ["←", "→"],
		["▲", "▼"] if gamepad else ["↑", "↓"],
		["A"] if gamepad else ["ENTER"],
		["B"] if gamepad else ["ESC"],
	]
	var labels := ["place", "digit", _confirm.to_lower(), "back"]
	for index in items.size():
		_foot.add_child(_make_foot_item(items[index], labels[index]))


func _make_foot_item(keys: Array, text: String) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override(&"separation", 8)
	for key in keys:
		var cap := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTokens.FOCUS_INK, 0.14)
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		box.content_margin_top = 4.0
		box.content_margin_bottom = 4.0
		cap.add_theme_stylebox_override(&"panel", box)
		var label := Label.new()
		label.text = str(key)
		label.add_theme_font_override(&"font", UiTheme.inter(600))
		label.add_theme_font_size_override(&"font_size", 14)
		label.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK)
		cap.add_child(label)
		item.add_child(cap)
	var text_label := Label.new()
	text_label.text = text
	text_label.add_theme_font_override(&"font", UiTheme.inter(500))
	text_label.add_theme_font_size_override(&"font_size", 15)
	text_label.add_theme_color_override(&"font_color", Color(UiTokens.FOCUS_INK, 0.72))
	item.add_child(text_label)
	return item


func _layout() -> void:
	if _scrim == null:
		return
	_scrim.position = Vector2.ZERO
	_scrim.size = size
	if _card == null or size.x <= 0.0:
		return
	_card.size = Vector2(CARD_W, 0.0)
	_card.custom_minimum_size.x = CARD_W
	var card_size := _card.get_combined_minimum_size()
	_card.size = Vector2(maxf(CARD_W, card_size.x), card_size.y)
	_card.pivot_offset = _card.size * 0.5
	var foot_h := _foot.get_combined_minimum_size().y
	var total := _card.size.y + 12.0 + foot_h
	_card.position = Vector2((size.x - _card.size.x) * 0.5,
		(size.y - total) * 0.5)
	_foot.position = Vector2(_card.position.x, _card.position.y + _card.size.y + 12.0)
	_foot.size = Vector2(_card.size.x, foot_h)


# Input ----------------------------------------------------------------------

func _move(direction: Vector2i) -> void:
	match direction:
		Vector2i.LEFT:
			_index = maxi(0, _index - 1)
		Vector2i.RIGHT:
			_index = mini(DIGITS - 1, _index + 1)
		Vector2i.UP:
			_roll(1)
		Vector2i.DOWN:
			_roll(-1)
	_refresh()


func _roll(delta: int) -> void:
	_digits[_index] = posmod(_digits[_index] + delta, 10)


func _commit() -> void:
	var result := clampi(value(), _min, _max)
	if _step > 0:
		result = clampi(int(round(float(result) / float(_step))) * _step, _min, _max)
	applied.emit(result)
	close()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			close()


func _on_digit_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_index = index
			_refresh()
			accept_event()


func _on_nav_moved(direction: Vector2i) -> void:
	if _is_modal_owner():
		_move(direction)


func _on_nav_confirmed() -> void:
	if _is_modal_owner():
		_commit()


func _on_nav_cancelled() -> void:
	if _is_modal_owner():
		close()


func _connect_nav() -> void:
	var nav := _ui_nav()
	if nav == null:
		return
	nav.moved.connect(_on_nav_moved)
	nav.confirmed.connect(_on_nav_confirmed)
	nav.cancelled.connect(_on_nav_cancelled)
	nav.device_changed.connect(_on_device_changed)


func _on_device_changed(_gamepad: bool) -> void:
	if _open:
		_refresh_foot()


func _is_modal_owner() -> bool:
	var nav := _ui_nav()
	return _open and nav != null and nav.modal_owner() == self


func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


# Looked up by path: the modal is also instantiated by the headless tests
# directly, where a bare UiTransition identifier does not resolve.
func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _exit_tree() -> void:
	if _open:
		var nav := _ui_nav()
		if nav != null:
			nav.pop_modal(self)
		_open = false
