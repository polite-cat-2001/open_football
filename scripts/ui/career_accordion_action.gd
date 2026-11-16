class_name CareerAccordionAction
extends Button
# One action row of an accordion (prototype `.squad-action` / accordion button):
# transparent on the navy plate, light label, optional ticket on the right, and
# the lime plate with dark ink while focused. Shared by every accordion in the
# career screens so they cannot drift apart.

const HEIGHT := 36.0

var id := ""
var enabled := true
var _label: Label
var _ticket: Label


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = HEIGHT
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override(&"font", UiTheme.inter(600))
	_label.add_theme_font_size_override(&"font_size", 16)
	add_child(_label)
	_ticket = Label.new()
	_ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticket.clip_text = true
	_ticket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ticket.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ticket.add_theme_font_override(&"font", UiTheme.inter(600))
	_ticket.add_theme_font_size_override(&"font_size", 13)
	add_child(_ticket)
	resized.connect(_layout_content)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)
	mouse_entered.connect(grab_focus)
	_apply_state()


func setup(spec: Dictionary) -> void:
	id = str(spec.get("id", ""))
	enabled = bool(spec.get("enabled", true))
	if _label == null:
		return
	_label.text = str(spec.get("label", "")).to_upper()
	_ticket.text = str(spec.get("ticket", "")).to_upper()
	_apply_state()
	_layout_content()


func label_text() -> String:
	return "" if _label == null else str(_label.text)


func ticket_text() -> String:
	return "" if _ticket == null else str(_ticket.text)


func _layout_content() -> void:
	if _label == null:
		return
	var ticket_w := 0.0
	if not _ticket.text.is_empty():
		var font := _ticket.get_theme_font(&"font")
		var font_size := _ticket.get_theme_font_size(&"font_size")
		ticket_w = font.get_string_size(_ticket.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x + 10.0
	_ticket.position = Vector2(maxf(0.0, size.x - 12.0 - ticket_w), 0.0)
	_ticket.size = Vector2(ticket_w, size.y)
	_label.position = Vector2(12.0, 0.0)
	_label.size = Vector2(maxf(0.0, size.x - 24.0 - ticket_w), size.y)


func _apply_state() -> void:
	if _label == null:
		return
	var focused := has_focus()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.FOCUS_MARK if focused else Color(0, 0, 0, 0)
	box.anti_aliasing = true
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		add_theme_stylebox_override(state, box)
	var ink := UiTokens.INK if focused else UiTokens.FOCUS_INK
	if not focused and not enabled:
		ink = Color(UiTokens.FOCUS_INK_2, 0.55)
	_label.add_theme_color_override(&"font_color", ink)
	_ticket.add_theme_color_override(&"font_color",
		Color(UiTokens.INK, 0.6) if focused else Color(UiTokens.FOCUS_INK_2, 0.7))
