class_name CareerScoutPicker
extends Control
# Prototype career/transfers/ScoutPicker.svelte: the "who should watch him?"
# modal of the transfer search. A list of free scouts — flag, name, experience /
# judgement line and the five judgement stars — or "BUSY: WATCHING <name>" for a
# scout who already has a report running. Confirm assigns and closes, Back
# closes; there is no cancel row.
#
# Owns UiNav while open (push_modal / pop_modal) and animates with the shell's
# fade+scale (150 out / 240 in). The host of the picker decides what an
# assignment means; this screen only reports the scout id.

signal assigned(scout_id: String)
signal closed

const CARD_W := 680.0
const ROW_H := 64.0
const FLAG_W := 34.0
const FLAG_H := 24.0
const LIST_MAX_H := 420.0
const PAD := 16.0
const SCALE_FROM := 0.96
const SCRIM := Color(0.024, 0.047, 0.102, 0.68)


# One scout row: flag, name + experience/judgement (or the busy report), stars.
# A busy row stays focusable like the prototype's aria-disabled rows, it just
# does nothing on confirm.
class Row extends Button:
	var id := ""
	var enabled := true
	var _bg: Panel
	var _flag: TextureRect
	var _name: Label
	var _note: Label
	var _stars: HBoxContainer
	var _star_labels: Array[Label] = []
	var _judgement := 0
	var _normal: StyleBoxFlat
	var _focus: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_normal = _make_box(Color(UiTokens.INK, 0.055))
		_focus = _make_box(UiTokens.FOCUS_FILL)
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_flag = TextureRect.new()
		_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_flag)
		_name = _make_label(UiTheme.barlow(700), 24)
		_note = _make_label(UiTheme.inter(500), 16)
		_stars = HBoxContainer.new()
		_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stars.add_theme_constant_override(&"separation", 3)
		add_child(_stars)
		for index in 5:
			var star := Label.new()
			star.text = "★"
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star.add_theme_font_override(&"font", UiTheme.inter(600))
			star.add_theme_font_size_override(&"font_size", 18)
			_stars.add_child(star)
			_star_labels.append(star)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func _make_box(fill: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.anti_aliasing = true
		return box

	func _make_label(font: Font, font_size: int) -> Label:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", font_size)
		add_child(label)
		return label

	func setup(scout: Dictionary) -> void:
		id = str(scout.get("id", ""))
		var report = scout.get("report")
		var busy := report is Dictionary and not (report as Dictionary).is_empty()
		enabled = not busy
		_judgement = int(scout.get("judgement", 0))
		if _name == null:
			return
		_name.text = str(scout.get("name", "")).to_upper()
		_flag.texture = CareerScoutPicker.flag_texture(scout)
		_flag.visible = _flag.texture != null
		var note := "EXPERIENCE %d · JUDGEMENT %d" % [
			int(scout.get("experience", 0)), _judgement]
		if busy:
			note = "BUSY · WATCHING %s" % str((report as Dictionary).get("player_name", ""))
		var nationality := str(scout.get("nationality", ""))
		if not nationality.is_empty():
			note = "%s · %s" % [nationality.to_upper(), note]
		_note.text = note
		_apply_state()
		_layout_content()

	func _layout_content() -> void:
		if _bg == null:
			return
		_bg.position = Vector2.ZERO
		_bg.size = size
		_flag.position = Vector2(14.0, (size.y - FLAG_H) * 0.5)
		_flag.size = Vector2(FLAG_W, FLAG_H)
		var text_x := 14.0 + FLAG_W + 14.0
		# Size the stars to what they draw: a fixed slot left a gap at the edge.
		var stars_w := _stars.get_combined_minimum_size().x
		var text_w := maxf(40.0, size.x - text_x - stars_w - 28.0)
		_name.position = Vector2(text_x, size.y * 0.5 - 30.0)
		_name.size = Vector2(text_w, 30.0)
		_note.position = Vector2(text_x, size.y * 0.5)
		_note.size = Vector2(text_w, 24.0)
		_stars.position = Vector2(size.x - 14.0 - stars_w, (size.y - 22.0) * 0.5)
		_stars.size = Vector2(stars_w, 22.0)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus if focused else _normal)
		var title := UiTokens.INK
		var body := UiTokens.INK_2
		if focused:
			title = UiTokens.FOCUS_MARK
			body = UiTokens.FOCUS_INK_2
		elif not enabled:
			title = UiTokens.INK_2
			body = Color(UiTokens.INK_2, 0.7)
		_name.add_theme_color_override(&"font_color", title)
		_note.add_theme_color_override(&"font_color", body)
		for index in _star_labels.size():
			var on := index < _judgement
			var color := Color(UiTokens.INK, 0.22) if not on else UiTokens.INK
			if focused:
				color = UiTokens.FOCUS_MARK if on else Color(UiTokens.FOCUS_INK, 0.26)
			_star_labels[index].add_theme_color_override(&"font_color", color)


var _scouts: Array = []
var _player_name := ""
var _open := false
var _armed := false
var _rows: Array[Row] = []
var _scrim: ColorRect
var _card: PanelContainer
var _text: Label
var _list: ScrollContainer
var _rows_box: VBoxContainer
var _tween: Tween


static func flag_texture(scout: Dictionary) -> Texture2D:
	# Hosts may hand a ready texture (the transfer search resolves the catalog
	# flags); elsewhere the scout's country id is its transfermarkt id.
	var raw = scout.get("flag", null)
	if raw is Texture2D:
		return raw
	var path := str(raw)
	if not path.is_empty() and (path.contains("/") or path.contains(".")):
		return UiAssets.usable_texture(
			UiAssets.load_texture_mipmapped(path.trim_prefix("/")))
	if str(scout.get("nationality_id", "")).is_empty():
		return null
	return CareerScoutCard.flag_texture(scout)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_build()
	resized.connect(_layout)
	_connect_nav()
	call_deferred("_layout")


func setup(scouts: Array, player_name: String) -> void:
	_scouts = scouts
	_player_name = player_name
	_rows.clear()
	if _rows_box == null:
		return
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	for scout in _scouts:
		if not (scout is Dictionary):
			continue
		var row := Row.new()
		row.custom_minimum_size.y = ROW_H
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows_box.add_child(row)
		row.setup(scout)
		row.pressed.connect(_on_row_pressed.bind(row))
		_rows.append(row)
	_text.text = ("No scouts are available." if _rows.is_empty()
		else "Who should watch %s?" % _player_name)
	_list.custom_minimum_size.y = minf(LIST_MAX_H, ROW_H * float(_rows.size())
		+ float(maxi(0, _rows.size() - 1)))


func open() -> void:
	if _open:
		return
	# Before `_open`: reparenting leaves and re-enters the tree, and _exit_tree
	# would pop an open modal off the stack.
	CareerScoutingModal.host_overlay(self)
	_open = true
	_armed = false
	visible = true
	move_to_front()
	var nav := _ui_nav()
	if nav != null:
		nav.push_modal(self)
	# Opened from the actions card's confirm handler: stay deaf until the next
	# frame so that press does not also pick the first scout.
	call_deferred("_arm")
	_layout()
	_focus_first()
	var card := _card
	_scrim.modulate.a = 0.0
	if _instant():
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		_scrim.modulate.a = 1.0
		return
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * SCALE_FROM
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "modulate:a", 1.0, UiTokens.SCREEN_IN)
	_tween.tween_property(card, "scale", Vector2.ONE, UiTokens.SCREEN_IN)
	_tween.tween_property(_scrim, "modulate:a", 1.0, UiTokens.SCREEN_OUT)


func close() -> void:
	if not _open:
		return
	_open = false
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
		return
	var card := _card
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(card, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	_tween.tween_property(card, "scale", Vector2.ONE * SCALE_FROM, UiTokens.SCREEN_OUT)
	_tween.tween_property(_scrim, "modulate:a", 0.0, UiTokens.SCREEN_OUT)
	_tween.chain().tween_callback(func() -> void: visible = false)


func is_open() -> bool:
	return _open


func scout_ids() -> Array:
	var ids: Array = []
	for row in _rows:
		ids.append(row.id)
	return ids


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
	box.content_margin_bottom = PAD
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 6)
	_card.add_child(column)

	var head := MarginContainer.new()
	head.name = "Head"
	head.add_theme_constant_override(&"margin_left", int(PAD))
	head.add_theme_constant_override(&"margin_right", int(PAD))
	head.add_theme_constant_override(&"margin_top", 12)
	column.add_child(head)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 2)
	head.add_child(titles)
	var eyebrow := Label.new()
	eyebrow.text = "ASSIGN SCOUT"
	eyebrow.add_theme_font_override(&"font", UiTheme.inter(600))
	eyebrow.add_theme_font_size_override(&"font_size", 16)
	eyebrow.add_theme_color_override(&"font_color", UiTokens.INK_2)
	titles.add_child(eyebrow)
	var title := Label.new()
	title.text = "CHOOSE A SCOUT"
	title.add_theme_font_override(&"font", UiTheme.barlow(700))
	title.add_theme_font_size_override(&"font_size", 30)
	title.add_theme_color_override(&"font_color", UiTokens.INK)
	titles.add_child(title)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", int(PAD))
	margin.add_theme_constant_override(&"margin_right", int(PAD))
	column.add_child(margin)
	_text = Label.new()
	_text.add_theme_font_override(&"font", UiTheme.inter(500))
	_text.add_theme_font_size_override(&"font_size", 16)
	_text.add_theme_color_override(&"font_color", UiTokens.INK_2)
	margin.add_child(_text)

	_list = ScrollContainer.new()
	_list.name = "List"
	_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.custom_minimum_size.y = ROW_H
	column.add_child(_list)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override(&"separation", 1)
	_list.add_child(_rows_box)


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


# Input ----------------------------------------------------------------------

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
	var focus := get_viewport().gui_get_focus_owner()
	var row := focus as Row
	if row != null:
		_on_row_pressed(row)


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
	for row in _rows:
		if row.enabled:
			row.grab_focus()
			return
	if not _rows.is_empty():
		_rows[0].grab_focus()


func _on_row_pressed(row: Row) -> void:
	if not row.enabled:
		return
	assigned.emit(row.id)
	close()


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
	if _open:
		var nav := _ui_nav()
		if nav != null:
			nav.pop_modal(self)
		_open = false
