class_name HubLineupColumn
extends Control
# One side of the prototype MatchHub: eleven starter rows on a dark gradient.
# The column is a pure function of the side snapshot; editing only happens in
# the Game Plan overlay.

var side := 0
var rows: Array = []

var _name_font: Font = UiTheme.barlow(700)
var _num_font: Font = UiTheme.barlow(700)
var _role_font: Font = UiTheme.inter(700)
var _cap_font: Font = UiTheme.barlow(800)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(data: Dictionary) -> void:
	side = int(data.get("side", 0))
	rows = data.get("lineup", [])
	queue_redraw()


func row_count() -> int:
	return maxi(rows.size(), UiTokens.HUB_LINEUP_MIN_ROWS)


func row_text(index: int) -> String:
	if index < 0 or index >= rows.size():
		return ""
	return str((rows[index] as Dictionary).get("name", ""))


func row_role(index: int) -> String:
	if index < 0 or index >= rows.size():
		return ""
	return str((rows[index] as Dictionary).get("role", ""))


func row_is_captain(index: int) -> bool:
	if index < 0 or index >= rows.size():
		return false
	return bool((rows[index] as Dictionary).get("captain", false))


func row_rect(index: int) -> Rect2:
	var row_h := _row_height()
	return Rect2(
		Vector2(0.0, UiTokens.HUB_LINEUP_PAD_TOP + row_h * float(index)),
		Vector2(size.x, row_h)
	)


func _row_height() -> float:
	var count := maxi(row_count(), 1)
	return (size.y - UiTokens.HUB_LINEUP_PAD_TOP - UiTokens.HUB_LINEUP_PAD_BOTTOM) \
		/ float(count)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_gradient()
	var row_h := _row_height()
	var pad_side := UiTokens.HUB_LINEUP_PAD_SIDE
	var num_w := UiTokens.HUB_LINEUP_NUM_W
	var cap_w := UiTokens.HUB_LINEUP_CAP_W
	var role_w := UiTokens.HUB_LINEUP_ROLE_W
	var gap := UiTokens.HUB_LINEUP_GAP
	var name_w := size.x - pad_side * 2.0 - num_w - cap_w - role_w - gap * 3.0
	var count := row_count()
	for index in count:
		var top := UiTokens.HUB_LINEUP_PAD_TOP + row_h * float(index)
		var center_y := top + row_h * 0.5
		if index > 0:
			draw_line(Vector2(pad_side, top), Vector2(size.x - pad_side, top),
				UiTokens.HUB_DIVIDER, 1.0)
		var row: Dictionary = rows[index] if index < rows.size() else {}
		var role := str(row.get("role", ""))
		var final_role := str(row.get("role_label", role))
		var number := int(row.get("number", index + 1))
		var name := str(row.get("name", "-"))
		if name.is_empty():
			name = "-"
		var is_gk := role.to_upper() == "GK"
		if side == 0:
			_draw_text(_num_font, str(number), UiTokens.SIZE_HUB_LINEUP_NUM,
				Vector2(pad_side, top), Vector2(num_w, row_h),
				HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_CENTER,
				UiTokens.HUB_LINEUP_INK_2)
			_draw_text(_name_font, name, UiTokens.SIZE_HUB_LINEUP_NAME,
				Vector2(pad_side + num_w + gap, top), Vector2(name_w, row_h),
				HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER,
				UiTokens.HUB_LINEUP_INK)
			var cap_x := pad_side + num_w + gap + name_w + gap
			_draw_captain(cap_x, center_y, bool(row.get("captain", false)))
			_draw_role(final_role, is_gk,
				Rect2(size.x - pad_side - role_w, top, role_w, row_h),
				center_y, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			_draw_role(final_role, is_gk, Rect2(pad_side, top, role_w, row_h),
				center_y, HORIZONTAL_ALIGNMENT_LEFT)
			var cap_x := pad_side + role_w + gap
			_draw_captain(cap_x, center_y, bool(row.get("captain", false)))
			var name_x := cap_x + cap_w + gap
			_draw_text(_name_font, name, UiTokens.SIZE_HUB_LINEUP_NAME,
				Vector2(name_x, top), Vector2(name_w, row_h),
				HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_CENTER,
				UiTokens.HUB_LINEUP_INK)
			_draw_text(_num_font, str(number), UiTokens.SIZE_HUB_LINEUP_NUM,
				Vector2(size.x - pad_side - num_w, top), Vector2(num_w, row_h),
				HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_CENTER,
				UiTokens.HUB_LINEUP_INK_2)


func _draw_gradient() -> void:
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	var colors := PackedColorArray([
		UiTokens.HUB_PANEL_TOP,
		UiTokens.HUB_PANEL_TOP,
		UiTokens.HUB_PANEL_BOTTOM,
		UiTokens.HUB_PANEL_BOTTOM,
	])
	draw_polygon(points, colors)


func _draw_role(text: String, is_gk: bool, rect: Rect2, center_y: float,
		alignment: int) -> void:
	if text.is_empty():
		return
	if is_gk:
		var box := Rect2(rect.position.x - 5.0, center_y - 9.0, rect.size.x + 10.0, 18.0)
		draw_rect(box, UiTokens.HUB_LINEUP_INK, true)
		_draw_text(_role_font, text, UiTokens.SIZE_HUB_LINEUP_ROLE,
			rect.position, rect.size, alignment, VERTICAL_ALIGNMENT_CENTER,
			UiTokens.INK)
		return
	_draw_text(_role_font, text, UiTokens.SIZE_HUB_LINEUP_ROLE,
		rect.position, rect.size, alignment, VERTICAL_ALIGNMENT_CENTER,
		UiTokens.HUB_LINEUP_INK_2)


func _draw_captain(x: float, center_y: float, captain: bool) -> void:
	if not captain:
		return
	var box := Rect2(x, center_y - 9.0, UiTokens.HUB_LINEUP_CAP_W, 18.0)
	draw_rect(box, UiTokens.HUB_CAP, true)
	_draw_text(_cap_font, "C", 14, box.position, box.size,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, UiTokens.FOCUS_INK)


func _draw_text(font: Font, text: String, font_size: int, position: Vector2,
		box: Vector2, horizontal: int, vertical: int, color: Color) -> void:
	var y := position.y
	if vertical == VERTICAL_ALIGNMENT_CENTER:
		y += (box.y + float(font_size)) * 0.5 - 2.0
	else:
		y += float(font_size)
	draw_string(font, Vector2(position.x, y), text, horizontal, box.x, font_size, color)
