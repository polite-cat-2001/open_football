class_name PauseLineup
extends Control
# Read-only starting XI card for the pause menu: a perspective pitch with one
# shirt chip per active player (rating + surname), matching the prototype's
# pause lineup. Data comes from GpfRuntimeNode.get_squad(); the kit art is the
# shared KitArt silhouette.

const PITCH := Color("#528023")
const PITCH_HI := Color("#5a8929")
const LINE := Color(1.0, 1.0, 1.0, 0.86)
const PLATE := Color(0.031, 0.078, 0.059, 0.82)

var _entries: Array = []
var _kit: Dictionary = {}
var _shirts: Array[KitArt] = []
var _cards: Array[Dictionary] = []

var _name_font: Font = UiTheme.barlow(700)
var _rating_font: Font = UiTheme.barlow(700)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)


func setup(entries: Array, kit: Dictionary) -> void:
	_entries = entries
	_kit = kit
	for shirt in _shirts:
		shirt.queue_free()
	_shirts.clear()
	for i in _entries.size():
		var shirt := KitArt.new()
		shirt.set_kit(_kit)
		add_child(shirt)
		_shirts.append(shirt)
	_layout()


func card_count() -> int:
	return _cards.size()


func _layout() -> void:
	_cards.clear()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pitch := Rect2(Vector2(size.x * 0.04, size.y * 0.02),
		Vector2(size.x * 0.92, size.y * 0.96))
	var card_w := clampf(pitch.size.x * 0.092, 40.0, 62.0)
	var shirt_h := card_w * 0.78
	var rating_h := 15.0
	var name_h := 17.0
	var card_h := shirt_h + rating_h + name_h

	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		# Same preview transform as GpfGamePlan._build_cards: the GK sits off the
		# goal line and defenders drop a line so the back four never stacks on top
		# of the keeper.
		var shown: Vector2 = entry.get("position", Vector2.ZERO)
		var role := str(entry.get("role", "CM"))
		if role == "GK":
			shown = Vector2(-0.74, 0.0)
		else:
			if role in ["CB", "LB", "RB", "LWB", "RWB", "SW"]:
				shown.x = -0.40
			else:
				shown.x *= 0.82 if shown.x < 0.0 else 0.68
			shown.y = clampf(shown.y * 0.80, -0.68, 0.68)
		var depth := shown.x * 0.5 + 0.5
		# GamePlan anchors x at (1 - side); flip u to land the same way.
		var side := 1.0 - (shown.y * 0.5 + 0.5)
		var anchor := pitch.position + _point(pitch.size, side, 1.0 - depth)
		var x := clampf(anchor.x - card_w * 0.5, pitch.position.x,
			pitch.end.x - card_w)
		var y := clampf(anchor.y - card_h * 0.5, pitch.position.y,
			pitch.end.y - card_h - 8.0)
		_cards.append({
			"entry": entry,
			"rect": Rect2(x, y, card_w, card_h),
			"shirt": Rect2(x + card_w * 0.08, y, card_w * 0.84, shirt_h),
			"rating": Rect2(x + card_w * 0.5 - card_w * 0.24, y + shirt_h + 1.0,
				card_w * 0.48, rating_h),
			"name": Rect2(x, y + shirt_h + rating_h + 1.0, card_w, name_h),
		})

	for i in _shirts.size():
		var shirt := _shirts[i]
		shirt.visible = i < _cards.size()
		if shirt.visible:
			shirt.position = (_cards[i]["shirt"] as Rect2).position
			shirt.size = (_cards[i]["shirt"] as Rect2).size
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pitch := Rect2(Vector2(size.x * 0.04, size.y * 0.02),
		Vector2(size.x * 0.92, size.y * 0.96))
	_draw_pitch(pitch)

	for card in _cards:
		var entry: Dictionary = card["entry"]
		var rating_rect: Rect2 = card["rating"]
		var name_rect: Rect2 = card["name"]
		var rating := int(entry.get("rating", -1))
		if rating >= 0:
			draw_rect(rating_rect, PLATE, true)
			draw_string(_rating_font,
				Vector2(rating_rect.position.x, rating_rect.position.y + 12.0),
				str(rating), HORIZONTAL_ALIGNMENT_CENTER, rating_rect.size.x, 14,
				UiTokens.FOCUS_INK)
		draw_string(_name_font,
			Vector2(name_rect.position.x, name_rect.position.y + name_rect.size.y * 0.78),
			_short_name(str(entry.get("name", ""))), HORIZONTAL_ALIGNMENT_CENTER,
			name_rect.size.x, 13, UiTokens.INK)


func _draw_pitch(pitch: Rect2) -> void:
	var top_left := _point(pitch.size, 0.0, 0.0) + pitch.position
	var top_right := _point(pitch.size, 1.0, 0.0) + pitch.position
	var bottom_right := _point(pitch.size, 1.0, 1.0) + pitch.position
	var bottom_left := _point(pitch.size, 0.0, 1.0) + pitch.position
	var surface := PackedVector2Array([top_left, top_right, bottom_right, bottom_left])

	var shadow := PackedVector2Array()
	for point in surface:
		shadow.append(point + Vector2(0.0, size.y * 0.02))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.32))
	draw_colored_polygon(surface, PITCH)

	for band in 8:
		if band % 2 != 0:
			continue
		var v0 := float(band) / 8.0
		var v1 := float(band + 1) / 8.0
		draw_colored_polygon(PackedVector2Array([
			pitch.position + _point(pitch.size, 0.0, v0),
			pitch.position + _point(pitch.size, 1.0, v0),
			pitch.position + _point(pitch.size, 1.0, v1),
			pitch.position + _point(pitch.size, 0.0, v1),
		]), PITCH_HI)

	var width := maxf(2.0, pitch.size.x * 0.0028)
	draw_polyline(_closed(surface), Color(0.0, 0.0, 0.0, 0.30), width + 0.5)
	draw_polyline(_closed(surface), LINE, width)
	draw_line(pitch.position + _point(pitch.size, 0.0, 0.5),
		pitch.position + _point(pitch.size, 1.0, 0.5), LINE, width)
	var center := pitch.position + _point(pitch.size, 0.5, 0.5)
	var circle := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		circle.append(center + Vector2(cos(angle) * pitch.size.x * 0.10,
			sin(angle) * pitch.size.y * 0.07))
	draw_polyline(circle, LINE, width)
	draw_circle(center, maxf(1.6, width), LINE)

	# Both penalty boxes: goal-line side touches the outline, so draw three
	# sides only (avoid doubling the goal line).
	for goal_v in [0.0, 1.0]:
		var far_v := 0.1875 if goal_v == 0.0 else 0.8125
		var box := PackedVector2Array([
			pitch.position + _point(pitch.size, 0.75, goal_v),
			pitch.position + _point(pitch.size, 0.75, far_v),
			pitch.position + _point(pitch.size, 0.25, far_v),
			pitch.position + _point(pitch.size, 0.25, goal_v),
		])
		draw_polyline(box, LINE, width)
		var small_v := 0.0729 if goal_v == 0.0 else 0.9271
		draw_polyline(PackedVector2Array([
			pitch.position + _point(pitch.size, 0.60, goal_v),
			pitch.position + _point(pitch.size, 0.60, small_v),
			pitch.position + _point(pitch.size, 0.40, small_v),
			pitch.position + _point(pitch.size, 0.40, goal_v),
		]), LINE, width)


# u = across the pitch (0 left, 1 right); v = depth (0 far, 1 near). The far
# edge is narrower, which gives the prototype's perspective.
func _point(area: Vector2, u: float, v: float) -> Vector2:
	var left_x := lerpf(area.x * 0.10, 0.0, v)
	var right_x := lerpf(area.x * 0.90, area.x, v)
	return Vector2(lerpf(left_x, right_x, u), area.y * v)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point)
	if not points.is_empty():
		result.append(points[0])
	return result


func _short_name(value: String) -> String:
	return value if value.length() <= 11 else value.substr(0, 10) + "."
