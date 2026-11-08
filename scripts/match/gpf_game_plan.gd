class_name GpfGamePlan
extends Control
# Game plan screen shared by the pre-match hub and the in-match pause menu.
# Layout follows the career prototype / FIFA reference: one half per team, a
# tab strip (SQUAD / FORMATIONS / ROLES), a player header with a radar, a
# vertical pitch, a bottom drawer (bench + reserve, scheme cards or role tiles)
# and a READY overlay that replaces the whole half.
#
# Two data sources, never read by the screen itself:
#   prematch: MatchLineup objects (swaps rewrite the lineup used by the package)
#   match:    GpfRuntimeNode.get_squad() plus the substitution/plan bridge

signal close_requested
signal lineup_changed
signal ready_changed(team_id: int, ready: bool)

const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const FONT_HEAD := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const FONT_HEAD_X := preload("res://assets/ui/fonts/BarlowCondensed-ExtraBold.ttf")
const FONT_BODY := preload("res://assets/ui/fonts/Inter-Variable.ttf")
const HINTS_SCENE := preload("res://scenes/ui/ui_hints_bar.tscn")

# Career prototype theme (web/src/styles/theme.css + squad*.css).
const C_TILE := UiTokens.TILE
const C_INK := UiTokens.INK
const C_INK2 := UiTokens.INK_2
const C_FOCUS_FILL := UiTokens.FOCUS_FILL
const C_FOCUS_INK := UiTokens.FOCUS_INK
const C_FOCUS_INK2 := UiTokens.FOCUS_INK_2
const C_RAIL := UiTokens.RAIL
const C_MARK := UiTokens.FOCUS_MARK
const C_WIN := Color(0.184, 0.490, 0.310, 1.0)
const C_LOSS := Color(0.698, 0.227, 0.282, 1.0)
const C_WARN := Color(0.651, 0.416, 0.0, 1.0)
const C_PITCH := Color("#528023")
const C_PITCH_HI := Color("#5a8929")
const C_PITCH_LINE := Color(1.0, 1.0, 1.0, 0.86)
const C_TILE_ALT := Color(0.910, 0.925, 0.949, 1.0)
const C_SHADOW := Color(0.016, 0.035, 0.078, 0.30)

const TAB_SQUAD := 0
const TAB_FORMATIONS := 1
const TAB_ROLES := 2
const TAB_NAMES: Array[String] = ["SQUAD", "FORMATIONS", "ROLES"]
# FORMATIONS and ROLES share one drawer height so the pitch above them keeps
# the same size when the tab changes.
const TAB_DRAWER_H := 224.0
const TAB_DRAWER_MIN_H := 168.0

# User-facing role order from GamePlanPage::planRoleOrder.
const TEAM_ROLE_ROWS := [
	{"role": 0, "name": "Captain"},
	{"role": 3, "name": "Free kick far"},
	{"role": 2, "name": "Free kick near"},
	{"role": 1, "name": "Penalty taker"},
	{"role": 4, "name": "Left corner"},
	{"role": 5, "name": "Right corner"},
]

const RADAR_AXES := [
	{"label": "Tempo", "keys": ["physical_velocity", "physical_acceleration"]},
	{"label": "Shots", "keys": ["technical_shot", "physical_shotpower", "technical_volley"]},
	{"label": "Pass", "keys": ["technical_shortpass", "technical_highpass", "mental_vision"]},
	{"label": "Dribble", "keys": ["technical_ballcontrol", "technical_dribble", "physical_agility"]},
	{"label": "Defence", "keys": ["technical_standingtackle", "technical_slidingtackle", "mental_defensivepositioning"]},
	{"label": "Phys", "keys": ["physical_stamina", "mental_resilience", "physical_reaction"]},
]

const STAT_LABELS := {
	"physical_balance": "Balance",
	"physical_reaction": "Reaction",
	"physical_acceleration": "Acceleration",
	"physical_velocity": "Velocity",
	"physical_stamina": "Stamina",
	"physical_agility": "Agility",
	"physical_shotpower": "Shot power",
	"technical_standingtackle": "Stand. tackle",
	"technical_slidingtackle": "Slide tackle",
	"technical_ballcontrol": "Ball control",
	"technical_dribble": "Dribbling",
	"technical_shortpass": "Short pass",
	"technical_highpass": "High pass",
	"technical_header": "Header",
	"technical_shot": "Shot",
	"technical_volley": "Volley",
	"mental_calmness": "Calmness",
	"mental_workrate": "Work rate",
	"mental_resilience": "Resilience",
	"mental_defensivepositioning": "Def. positioning",
	"mental_offensivepositioning": "Off. positioning",
	"mental_vision": "Vision",
}

const DEFAULT_COLORS := {
	0: Color(0.16, 0.32, 0.95),
	1: Color(0.95, 0.16, 0.12),
}
const PHOTO_ASPECT := 0.80
const ROW_REPEAT_MS := 180
const READY_HOLD_MS := 550
const BENCH_SIZE := MatchLineup.BENCH_SIZE


static func _draw_texture_contain(canvas: CanvasItem, texture: Texture2D,
		rect: Rect2, align_bottom := true, modulate := Color(1, 1, 1, 1)) -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var draw_size := tex_size * scale
	var y := rect.position.y + rect.size.y - draw_size.y
	if not align_bottom:
		y = rect.position.y + (rect.size.y - draw_size.y) * 0.5
	var position := Vector2(rect.position.x + (rect.size.x - draw_size.x) * 0.5, y)
	canvas.draw_texture_rect(texture, Rect2(position, draw_size), false, modulate)


static func _draw_refresh_icon(canvas: CanvasItem, center: Vector2, radius: float,
		color: Color) -> void:
	var icon_size := int(round(clampf(radius * 2.2, 14.0, 22.0)))
	var rect := Rect2(center - Vector2(icon_size * 0.6, icon_size * 0.5),
		Vector2(icon_size * 1.2, icon_size))
	var baseline := rect.position.y + icon_size * 0.78
	canvas.draw_string(FONT_BODY, Vector2(rect.position.x + 1.0, baseline + 1.0),
		"↻", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, icon_size,
		Color(0.0, 0.0, 0.0, 0.42))
	canvas.draw_string(FONT_BODY, Vector2(rect.position.x, baseline),
		"↻", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, icon_size, color)


static func _fatigue_bar_polygon(rect: Rect2, slant: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(slant, 0.0),
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x - slant, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y),
	])


static func _draw_fatigue_bar(canvas: CanvasItem, rect: Rect2, percent: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var slant := clampf(rect.size.y * 0.8, 1.5, 4.0)
	var outer := _fatigue_bar_polygon(rect, slant)
	canvas.draw_colored_polygon(outer, Color(0.0, 0.0, 0.0, 0.92))
	var inset := 1.0
	var inner_rect := Rect2(rect.position + Vector2(inset, inset),
		rect.size - Vector2(inset * 2.0, inset * 2.0))
	var inner := _fatigue_bar_polygon(inner_rect, maxf(1.0, slant * 0.7))
	var ratio := clampf(float(percent) / 100.0, 0.0, 1.0)
	var fill := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
	var pieces := Geometry2D.intersect_polygons(inner, PackedVector2Array([
		fill.position,
		fill.position + Vector2(fill.size.x, 0.0),
		fill.position + fill.size,
		fill.position + Vector2(0.0, fill.size.y),
	]))
	var fill_color := C_WIN if percent >= 50 else C_LOSS
	for piece in pieces:
		canvas.draw_colored_polygon(piece, fill_color)
	var outline := outer.duplicate()
	outline.append(outer[0])
	canvas.draw_polyline(outline, Color(0.0, 0.0, 0.0, 1.0), 1.0)



class GamePlanPitch extends Control:
	signal card_clicked(panel_index: int, entry_index: int)
	signal card_hovered(panel_index: int, entry_index: int)

	var panel_index := 0
	var team_color := Color(0.2, 0.4, 0.9)
	var cards: Array = []
	var cursor := -1
	var held := -1
	var editing := false
	var strength := -1
	var strength_delta := 0
	var _hover_index := -1

	func set_cards(value: Array) -> void:
		cards = value
		queue_redraw()

	func set_markers(new_cursor: int, new_held: int, is_editing: bool) -> void:
		cursor = new_cursor
		held = new_held
		editing = is_editing
		queue_redraw()

	func set_strength(value: int, delta: int) -> void:
		strength = value
		strength_delta = delta
		queue_redraw()

	func _draw() -> void:
		var area := get_size()
		if area.x <= 0.0 or area.y <= 0.0:
			return
		_draw_pitch_surface(area)

		for card in cards:
			var entry: Dictionary = card["entry"]
			var rect: Rect2 = card["rect"]
			var photo: Rect2 = card["photo"]
			var name_rect: Rect2 = card["name"]
			var role_rect: Rect2 = card["role"]
			var bar_rect: Rect2 = card["bar"]
			var focused := editing and int(card["entry_index"]) == cursor
			var anchored := editing and int(card["entry_index"]) == held
			if focused:
				draw_rect(rect.grow(maxf(2.0, rect.size.x * 0.04)), C_FOCUS_FILL, true)
			var texture: Texture2D = card.get("photo_texture", null)
			if texture != null:
				GpfGamePlan._draw_texture_contain(self, texture, photo)
			else:
				_draw_silhouette(photo)
			draw_rect(role_rect, Color(0.031, 0.078, 0.059, 0.72), true)

			var role := str(card.get("display_role", entry.get("role", "")))
			var rating := int(entry.get("rating", -1))
			var role_size := maxi(11, int(photo.size.y * 0.32))
			var rating_size := maxi(16, int(photo.size.y * 0.46))
			var role_color := BenchCard._pos_color(role)
			var rating_color := C_FOCUS_INK
			draw_string(FONT_BODY, Vector2(role_rect.position.x + 2.0,
				role_rect.position.y + role_rect.size.y * 0.76), role,
				HORIZONTAL_ALIGNMENT_LEFT, role_rect.size.x * 0.62, role_size, role_color)
			if rating >= 0:
				draw_string(FONT_HEAD, Vector2(role_rect.position.x + role_rect.size.x * 0.60,
					role_rect.position.y + role_rect.size.y * 0.80), str(rating),
					HORIZONTAL_ALIGNMENT_RIGHT, role_rect.size.x * 0.38, rating_size, rating_color)

			var name := _short_name(str(entry.get("name", "")))
			var name_size := maxi(14, int(photo.size.y * 0.40))
			var name_color := C_MARK if focused else C_FOCUS_INK
			draw_string(FONT_HEAD, Vector2(name_rect.position.x + 1.0,
				name_rect.position.y + name_rect.size.y * 0.82 + 1.0), name,
				HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x - 2.0, name_size,
				Color(0, 0, 0, 0.65))
			draw_string(FONT_HEAD, Vector2(name_rect.position.x,
				name_rect.position.y + name_rect.size.y * 0.82), name,
				HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x, name_size, name_color)

			var fatigue := clampi(int(entry.get("fatigue", 100)), 0, 100)
			GpfGamePlan._draw_fatigue_bar(self, bar_rect, fatigue)

			if bool(entry.get("pending_out", false)):
				draw_rect(rect.grow(1.0), Color(0.88, 0.25, 0.22, 0.95), false, 2.0)
			elif bool(entry.get("pending_in", false)):
				draw_rect(rect.grow(1.0), Color(0.28, 0.80, 0.40, 0.95), false, 2.0)
			if anchored:
				var icon_radius := clampf(rect.size.x * 0.105, 6.5, 9.0)
				GpfGamePlan._draw_refresh_icon(self,
					Vector2(rect.end.x - icon_radius - 2.0,
						rect.position.y + icon_radius + 2.0), icon_radius, C_RAIL)

		if strength >= 0:
			_draw_strength_badge(area)

	func _draw_pitch_surface(area: Vector2) -> void:
		var top_y := area.y * 0.02
		var bottom_y := area.y * 0.98
		var top_left := Vector2(area.x * 0.13, top_y)
		var top_right := Vector2(area.x * 0.87, top_y)
		var bottom_left := Vector2(area.x * 0.02, bottom_y)
		var bottom_right := Vector2(area.x * 0.98, bottom_y)
		var surface := PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
		var shadow := PackedVector2Array()
		for point in surface:
			shadow.append(point + Vector2(0.0, area.y * 0.024))
		draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.35))
		draw_colored_polygon(surface, C_PITCH)

		# Mowing bands: 8 keeps the halfway line on a stripe edge.
		var bands := 8
		for band in bands:
			if band % 2 != 0:
				continue
			var v0 := float(band) / float(bands)
			var v1 := float(band + 1) / float(bands)
			draw_colored_polygon(PackedVector2Array([
				_pitch_point(area, 0.0, v0),
				_pitch_point(area, 1.0, v0),
				_pitch_point(area, 1.0, v1),
				_pitch_point(area, 0.0, v1),
			]), C_PITCH_HI)

		var line_width := maxf(2.0, area.x * 0.0026)
		var line_color := C_PITCH_LINE
		draw_polyline(_closed(surface), Color(0.0, 0.0, 0.0, 0.30), line_width + 0.5)
		draw_polyline(_closed(surface), line_color, line_width)
		draw_line(_pitch_point(area, 0.0, 0.5), _pitch_point(area, 1.0, 0.5),
			line_color, line_width)
		var center := _pitch_point(area, 0.5, 0.5)
		_draw_ellipse(center, area.x * 0.11, area.y * 0.075, line_color, line_width)
		draw_circle(center, maxf(1.6, line_width), line_color)
		_draw_penalty_area(area, true, line_color, line_width)
		_draw_penalty_area(area, false, line_color, line_width)

	func _pitch_point(area: Vector2, u: float, v: float) -> Vector2:
		var left_x := lerpf(area.x * 0.13, area.x * 0.02, v)
		var right_x := lerpf(area.x * 0.87, area.x * 0.98, v)
		return Vector2(lerpf(left_x, right_x, u),
			lerpf(area.y * 0.02, area.y * 0.98, v))

	func _draw_penalty_area(area: Vector2, top: bool, color: Color,
			width: float) -> void:
		var goal_v := 0.0 if top else 1.0
		var far_v := 0.1875 if top else 0.8125
		# Three sides only: the goal-line edge is already the pitch outline, and
		# drawing it again made that horizontal line read thicker.
		draw_polyline(PackedVector2Array([
			_pitch_point(area, 0.75, goal_v),
			_pitch_point(area, 0.75, far_v),
			_pitch_point(area, 0.25, far_v),
			_pitch_point(area, 0.25, goal_v),
		]), color, width)
		var goal_far_v := 0.0729 if top else 0.9271
		draw_polyline(PackedVector2Array([
			_pitch_point(area, 0.60, goal_v),
			_pitch_point(area, 0.60, goal_far_v),
			_pitch_point(area, 0.40, goal_far_v),
			_pitch_point(area, 0.40, goal_v),
		]), color, width)
		draw_circle(_pitch_point(area, 0.5, 0.125 if top else 0.875),
			maxf(1.4, width * 0.8), color)

	func _draw_strength_badge(area: Vector2) -> void:
		var h := clampf(area.y * 0.105, 42.0, 66.0)
		var w := h * 0.78
		var rect := Rect2(Vector2(area.x - w - 12.0, 12.0), Vector2(w, h))
		var shield := PackedVector2Array([
			rect.position + Vector2(w * 0.5, h * 0.03),
			rect.position + Vector2(w * 0.94, h * 0.15),
			rect.position + Vector2(w * 0.94, h * 0.49),
			rect.position + Vector2(w * 0.5, h * 0.97),
			rect.position + Vector2(w * 0.06, h * 0.49),
			rect.position + Vector2(w * 0.06, h * 0.15),
		])
		var shadow := PackedVector2Array()
		for point in shield:
			shadow.append(point + Vector2(0, 4))
		draw_colored_polygon(shadow, C_SHADOW)
		draw_colored_polygon(shield, C_TILE)
		draw_polyline(_closed(shield), C_INK2, maxf(1.4, h * 0.035))
		var delta_text := ""
		if strength_delta > 0:
			delta_text = "+%d" % strength_delta
		elif strength_delta < 0:
			delta_text = "%d" % strength_delta
		draw_string(FONT_HEAD, Vector2(rect.position.x, rect.position.y + h * 0.57),
			str(strength), HORIZONTAL_ALIGNMENT_CENTER, w,
			maxi(18, int(h * 0.38)), C_INK)
		if not delta_text.is_empty():
			draw_string(FONT_BODY, Vector2(rect.position.x, rect.position.y + h * 0.78),
				delta_text, HORIZONTAL_ALIGNMENT_CENTER, w,
				maxi(8, int(h * 0.17)),
				C_WIN if strength_delta > 0 else C_LOSS)

	func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
		var points := PackedVector2Array()
		for index in 33:
			var angle := TAU * float(index) / 32.0
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_polyline(points, color, width)

	func _closed(points: PackedVector2Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(point)
		if not points.is_empty():
			result.append(points[0])
		return result

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			var hovered := -1
			for card in cards:
				if (card["rect"] as Rect2).has_point(motion.position):
					hovered = int(card["entry_index"])
					break
			if hovered != _hover_index:
				_hover_index = hovered
				if hovered >= 0:
					card_hovered.emit(panel_index, hovered)
			return
		if not (event is InputEventMouseButton):
			return
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return
		for card in cards:
			if (card["rect"] as Rect2).has_point(mouse.position):
				card_clicked.emit(panel_index, int(card["entry_index"]))
				accept_event()
				return

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hover_index = -1

	func _draw_silhouette(photo: Rect2) -> void:
		var center := photo.get_center()
		var r := minf(photo.size.x, photo.size.y) * 0.22
		draw_circle(center + Vector2(0, -r * 0.55), r * 0.55, Color(0.82, 0.86, 0.88, 0.55))
		var body := Rect2(center.x - r, center.y + r * 0.1, r * 2.0, photo.size.y * 0.38)
		draw_rect(body, Color(0.82, 0.86, 0.88, 0.45), true)

	func _fatigue_color(percent: int) -> Color:
		if percent >= 90:
			return Color(0.35, 0.78, 1.0)
		if percent >= 70:
			return Color(0.31, 0.86, 0.35)
		if percent >= 50:
			return Color(0.92, 0.86, 0.24)
		if percent >= 30:
			return Color(0.94, 0.59, 0.18)
		return Color(0.88, 0.24, 0.22)

	func _rating_suffix(entry: Dictionary) -> String:
		var rating := int(entry.get("rating", -1))
		return "" if rating < 0 else " %d" % rating

	func _short_name(value: String) -> String:
		return value if value.length() <= 13 else value.substr(0, 12) + "."


class GamePlanHeader extends Control:
	var entry: Dictionary = {}
	var compare: Dictionary = {}
	var team_color := Color(0.2, 0.4, 0.9)

	func set_players(primary: Dictionary, secondary: Dictionary, color: Color) -> void:
		entry = primary
		compare = secondary
		team_color = color
		queue_redraw()

	func _draw() -> void:
		var area := get_size()
		if area.x <= 2.0 or area.y <= 2.0 or entry.is_empty():
			return
		draw_rect(Rect2(Vector2(0, 6), area), C_SHADOW, true)
		draw_rect(Rect2(Vector2.ZERO, area), C_TILE, true)
		var comparing := not compare.is_empty() \
			and int(compare.get("id", -1)) != int(entry.get("id", -2))
		if comparing:
			var radar_w := clampf(area.x * 0.15, 84.0, 120.0)
			var side_w := (area.x - radar_w - 24.0) * 0.5
			_draw_block(Rect2(Vector2.ZERO, Vector2(side_w, area.y)), entry, false)
			var radar_rect := Rect2(Vector2(side_w + 12.0, area.y * 0.06),
				Vector2(radar_w, area.y * 0.88))
			if str(entry.get("role", "")) == "GK":
				_draw_gk_note(radar_rect)
			else:
				_draw_radar(radar_rect, radar_values(entry), radar_values(compare))
			_draw_block(Rect2(Vector2(area.x - side_w, 0.0), Vector2(side_w, area.y)),
				compare, true)
		else:
			var radar_w := clampf(area.x * 0.16, 96.0, 150.0)
			_draw_block(Rect2(Vector2.ZERO, Vector2(area.x - radar_w - 12.0, area.y)),
				entry, false)
			var radar_rect := Rect2(Vector2(area.x - radar_w, area.y * 0.06),
				Vector2(radar_w, area.y * 0.88))
			if str(entry.get("role", "")) == "GK":
				_draw_gk_note(radar_rect)
			else:
				_draw_radar(radar_rect, radar_values(entry), [])

	func _draw_gk_note(rect: Rect2) -> void:
		var size := maxi(10, int(rect.size.y * 0.13))
		draw_string(FONT_BODY, rect.position + Vector2(0, rect.size.y * 0.46),
			"Goalkeeper profile", HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, size, C_INK2)
		draw_string(FONT_BODY, rect.position + Vector2(0, rect.size.y * 0.61),
			"is not in the canon", HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, size, C_INK2)

	func _draw_block(rect: Rect2, data: Dictionary, mirrored: bool) -> void:
		if data.is_empty():
			return
		var pad := maxf(8.0, rect.size.y * 0.08)
		var photo_w := clampf(rect.size.x * 0.18, 64.0, 96.0)
		var photo_h := clampf(rect.size.y * 0.68, 76.0, 118.0)
		var bar_h := maxf(8.0, rect.size.y * 0.055)
		var content_h := photo_h + 4.0 + bar_h
		var content_top := rect.position.y + maxf(pad * 0.5, (rect.size.y - content_h) * 0.5)
		var photo_x := rect.end.x - pad - photo_w if mirrored else rect.position.x + pad
		var photo_rect := Rect2(Vector2(photo_x, content_top),
			Vector2(photo_w, photo_h))
		var texture: Texture2D = UiAssets.player_face(int(data.get("tm_id", 0)))
		if texture != null:
			GpfGamePlan._draw_texture_contain(self, texture, photo_rect)
		else:
			_draw_silhouette(photo_rect)
		var bar := Rect2(Vector2(photo_rect.position.x, photo_rect.end.y + 4.0),
			Vector2(photo_w, bar_h))
		var fatigue := clampi(int(data.get("fatigue", 100)), 0, 100)
		GpfGamePlan._draw_fatigue_bar(self, bar, fatigue)

		var text_x := rect.position.x + pad if mirrored else photo_rect.end.x + pad
		var text_w := (photo_rect.position.x - pad - text_x) if mirrored \
			else (rect.end.x - pad - text_x)
		var name := GpfGamePlan._full_player_name(data).to_upper()
		var name_size := maxi(18, int(rect.size.y * 0.22))
		var rating := int(data.get("rating", -1))
		var rating_text := "—" if rating < 0 else str(rating)
		var rating_size := maxi(24, int(rect.size.y * 0.30))
		var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
		draw_string(FONT_HEAD, Vector2(text_x, content_top + photo_h * 0.36),
			name, align, text_w, name_size, C_INK)
		draw_string(FONT_HEAD, Vector2(text_x, content_top + photo_h * 0.74),
			rating_text, align, text_w, rating_size, C_INK)
		draw_string(FONT_BODY, Vector2(text_x, content_top + photo_h * 0.96),
			str(data.get("role", "")), align, text_w,
			maxi(12, int(rect.size.y * 0.14)), C_INK2)

	static func radar_values(data: Dictionary) -> Array:
		var axes := [
			["physical_velocity", "physical_acceleration"],
			["technical_shot", "physical_shotpower", "technical_volley"],
			["technical_shortpass", "technical_highpass", "mental_vision"],
			["technical_ballcontrol", "technical_dribble", "physical_agility"],
			["technical_standingtackle", "technical_slidingtackle", "mental_defensivepositioning"],
			["physical_stamina", "mental_resilience", "physical_reaction"],
		]
		var stats: Dictionary = data.get("stats", {})
		var values: Array = []
		for keys in axes:
			var total := 0.0
			var count := 0
			for key in keys:
				if stats.has(key):
					total += float(stats[key])
					count += 1
			values.append(total / float(count) if count > 0 else 0.0)
		return values

	func _draw_radar(rect: Rect2, values: Array, secondary_values: Array) -> void:
		var center := rect.get_center()
		var radius := minf(rect.size.x, rect.size.y) * 0.38
		var grid_color := Color(C_INK, 0.20)
		for ring in 3:
			var points := PackedVector2Array()
			var scale := float(ring + 1) / 3.0
			for index in RADAR_AXES.size():
				var angle := -PI * 0.5 + TAU * float(index) / float(RADAR_AXES.size())
				points.append(center + Vector2(cos(angle), sin(angle)) * radius * scale)
			points.append(points[0])
			draw_polyline(points, grid_color if ring == 2 else Color(C_INK, 0.10), 1.0)
		for index in RADAR_AXES.size():
			var angle := -PI * 0.5 + TAU * float(index) / float(RADAR_AXES.size())
			draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius,
				Color(C_INK, 0.10), 1.0)
		_draw_radar_polygon(center, radius, values, Color(0.114, 0.129, 0.22, 0.07), C_RAIL, false)
		if not secondary_values.is_empty():
			_draw_radar_polygon(center, radius, secondary_values,
				Color(0.114, 0.129, 0.22, 0.05), C_INK2, true)
		var label_size := maxi(10, int(radius * 0.24))
		for index in RADAR_AXES.size():
			var angle := -PI * 0.5 + TAU * float(index) / float(RADAR_AXES.size())
			var direction := Vector2(cos(angle), sin(angle))
			var label_pos := center + direction * (radius + 9.0)
			draw_string(FONT_BODY, label_pos + Vector2(-30.0, label_size * 0.34),
				str(RADAR_AXES[index]["label"]), HORIZONTAL_ALIGNMENT_CENTER,
				60.0, label_size, C_INK2)

	func _draw_radar_polygon(center: Vector2, radius: float, values: Array,
			fill: Color, stroke: Color, dashed: bool) -> void:
		var polygon := PackedVector2Array()
		for index in RADAR_AXES.size():
			var angle := -PI * 0.5 + TAU * float(index) / float(RADAR_AXES.size())
			var value := clampf(float(values[index]), 0.0, 1.0)
			polygon.append(center + Vector2(cos(angle), sin(angle)) * radius * value)
		if polygon.size() < 3:
			return
		draw_colored_polygon(polygon, fill)
		var closed := PackedVector2Array()
		for point in polygon:
			closed.append(point)
		closed.append(polygon[0])
		if dashed:
			for index in range(0, closed.size() - 1):
				if index % 2 == 0:
					draw_line(closed[index], closed[index + 1], stroke, 1.4)
		else:
			draw_polyline(closed, stroke, 1.6)

	func _draw_silhouette(photo: Rect2) -> void:
		var center := photo.get_center()
		var r := minf(photo.size.x, photo.size.y) * 0.24
		draw_circle(center + Vector2(0, -r * 0.45), r * 0.55, Color(C_INK2, 0.35))
		draw_rect(Rect2(center.x - r, center.y + r * 0.15, r * 2.0, photo.size.y * 0.36),
			Color(C_INK2, 0.25), true)

	func _fatigue_color(percent: int) -> Color:
		return C_WIN if percent >= 50 else C_LOSS


class GamePlanDetails extends Control:
	var entry: Dictionary = {}
	var team_color := Color(0.2, 0.4, 0.9)

	func set_player(data: Dictionary, color: Color) -> void:
		entry = data
		team_color = color
		queue_redraw()

	func _draw() -> void:
		var area := get_size()
		if area.x <= 2.0 or area.y <= 2.0 or entry.is_empty():
			return
		draw_rect(Rect2(Vector2(0, 6), area), C_SHADOW, true)
		draw_rect(Rect2(Vector2.ZERO, area), Color(C_TILE.r, C_TILE.g, C_TILE.b, 1.0), true)
		var pad := maxf(12.0, area.y * 0.035)
		var title_h := maxf(24.0, area.y * 0.040)
		draw_string(FONT_HEAD, Vector2(pad, pad + title_h * 0.78), "ATTRIBUTES",
			HORIZONTAL_ALIGNMENT_LEFT, area.x - pad * 2.0,
			maxi(16, int(title_h * 0.78)), C_INK)
		var content_top := pad + title_h + 4.0
		var photo_w := clampf(area.x * 0.075, 58.0, 72.0)
		var photo_h := clampf(area.y * 0.20, 66.0, 82.0)
		var photo := Rect2(Vector2(pad, content_top), Vector2(photo_w, photo_h))
		var texture: Texture2D = UiAssets.player_face(int(entry.get("tm_id", 0)))
		if texture != null:
			GpfGamePlan._draw_texture_contain(self, texture, photo)
		else:
			_draw_silhouette(photo)
		var x := photo.end.x + pad
		var rating := int(entry.get("rating", -1))
		draw_string(FONT_HEAD, Vector2(x, content_top + photo_h * 0.55),
			"—" if rating < 0 else str(rating), HORIZONTAL_ALIGNMENT_LEFT,
			area.x - x - pad, maxi(20, int(photo_h * 0.45)), C_INK)
		draw_string(FONT_BODY, Vector2(x, content_top + photo_h * 0.78),
			str(entry.get("role", "")), HORIZONTAL_ALIGNMENT_LEFT,
			area.x - x - pad, maxi(10, int(photo_h * 0.20)), C_INK2)
		draw_string(FONT_HEAD, Vector2(x + photo_w * 0.55, content_top + photo_h * 0.55),
			str(entry.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
			area.x - x - photo_w * 0.55 - pad, maxi(18, int(photo_h * 0.30)), C_INK)

		var stats: Dictionary = entry.get("stats", {})
		var stats_top := photo.end.y + pad
		var columns := [
			[
				{"label": "PHYSICAL", "keys": ["physical_balance", "physical_reaction",
					"physical_acceleration", "physical_velocity", "physical_stamina",
					"physical_agility", "physical_shotpower"]},
				{"label": "MENTAL", "keys": ["mental_calmness", "mental_workrate",
					"mental_resilience", "mental_defensivepositioning",
					"mental_offensivepositioning", "mental_vision"]},
			],
			[
				{"label": "TECHNICAL", "keys": ["technical_standingtackle",
					"technical_slidingtackle", "technical_ballcontrol", "technical_dribble",
					"technical_shortpass", "technical_highpass", "technical_header",
					"technical_shot", "technical_volley"]},
			],
		]
		var col_w := (area.x - pad * 2.0) * 0.5
		var row_h := maxf(12.0, (area.y - stats_top - pad) / 18.0)
		for column in columns.size():
			var y := stats_top
			for group in columns[column]:
				var label := str(group["label"])
				draw_string(FONT_BODY, Vector2(pad + col_w * column, y + row_h * 0.8),
					label, HORIZONTAL_ALIGNMENT_LEFT, col_w - 18.0,
					maxi(9, int(row_h * 0.55)), C_INK2)
				draw_line(Vector2(pad + col_w * column, y + row_h * 0.95),
					Vector2(pad + col_w * (column + 1) - 18.0, y + row_h * 0.95),
					Color(C_INK2, 0.18), 1.0)
				y += row_h * 1.2
				for key in group["keys"]:
					var value := int(round(float(stats.get(str(key), 0.0)) * 100.0))
					draw_rect(Rect2(Vector2(pad + col_w * column, y + 1.0),
						Vector2(34.0, row_h * 0.86)), C_TILE_ALT, true)
					draw_string(FONT_HEAD, Vector2(pad + col_w * column, y + row_h * 0.72),
						str(value), HORIZONTAL_ALIGNMENT_CENTER, 34.0,
						maxi(8, int(row_h * 0.55)), C_INK)
					draw_string(FONT_BODY, Vector2(pad + col_w * column + 42.0, y + row_h * 0.72),
						str(STAT_LABELS.get(str(key), key)), HORIZONTAL_ALIGNMENT_LEFT,
						col_w - 60.0, maxi(8, int(row_h * 0.50)), C_INK2)
					y += row_h
				y += row_h * 0.4
		for dot in 3:
			var dot_rect := Rect2(Vector2(area.x * 0.5 - 18.0 + dot * 14.0,
				area.y - 14.0), Vector2(8, 8))
			draw_rect(dot_rect, C_INK if dot == 0 else Color(C_INK, 0.20), true)

	func _draw_silhouette(photo: Rect2) -> void:
		var center := photo.get_center()
		var r := minf(photo.size.x, photo.size.y) * 0.24
		draw_circle(center + Vector2(0, -r * 0.45), r * 0.55, Color(C_INK2, 0.35))
		draw_rect(Rect2(center.x - r, center.y + r * 0.15, r * 2.0, photo.size.y * 0.36),
			Color(C_INK2, 0.25), true)


class BenchCard extends Control:
	signal activated(entry_index: int)

	var entry: Dictionary = {}
	var entry_index := 0
	var focused := false
	var anchor := false
	var editable := true

	func setup(data: Dictionary, index: int, can_edit: bool) -> void:
		entry = data
		entry_index = index
		editable = can_edit
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		queue_redraw()

	func set_state(is_focused: bool, is_anchor: bool) -> void:
		focused = is_focused
		anchor = is_anchor
		queue_redraw()

	func _draw() -> void:
		var area := get_size()
		if area.x <= 2.0 or area.y <= 2.0:
			return
		var unavailable := bool(entry.get("left_pitch", false))
		var fill := Color(1.0, 1.0, 1.0, 0.58)
		if focused:
			fill = C_FOCUS_FILL
		draw_rect(Rect2(Vector2.ZERO, area), fill, true)
		if bool(entry.get("pending_out", false)):
			draw_rect(Rect2(Vector2.ZERO, area), Color(0.88, 0.25, 0.22, 0.95), false, 2.0)
		elif bool(entry.get("pending_in", false)):
			draw_rect(Rect2(Vector2.ZERO, area), Color(0.28, 0.80, 0.40, 0.95), false, 2.0)
		if anchor:
			GpfGamePlan._draw_refresh_icon(self, Vector2(area.x - 10.0, 11.0),
				6.0, C_RAIL)

		var ink := C_INK
		var ink2 := C_INK2
		var mark := C_MARK if focused else C_INK
		if focused:
			ink = C_FOCUS_INK
			ink2 = C_FOCUS_INK2
		if unavailable:
			ink = Color(ink, 0.55)
			ink2 = Color(ink2, 0.55)

		var pad_l := clampf(area.x * 0.045, 8.0, 14.0)
		var pad_r := clampf(area.x * 0.035, 6.0, 11.0)
		var pad_t := clampf(area.y * 0.07, 5.0, 9.0)
		var pad_b := clampf(area.y * 0.05, 4.0, 7.0)
		var top_h := clampf(area.y * 0.62, 44.0, 68.0)
		var baseline := pad_t + top_h - 5.0

		var role := str(entry.get("role", ""))
		draw_circle(Vector2(pad_l + 5.0, baseline - 4.0), 5.0, _pos_color(role))
		draw_string(FONT_BODY, Vector2(pad_l + 15.0, baseline), _short_role(role),
			HORIZONTAL_ALIGNMENT_LEFT, area.x * 0.38,
			maxi(11, int(area.y * 0.14)), ink2)

		var rating := int(entry.get("rating", -1))
		draw_string(FONT_HEAD, Vector2(area.x - pad_r - 48.0, baseline),
			"—" if rating < 0 else str(rating), HORIZONTAL_ALIGNMENT_RIGHT,
			48.0, maxi(17, int(area.y * 0.28)), mark)

		var photo_top := pad_t + maxf(2.0, area.y * 0.025)
		var photo_h := maxf(28.0, top_h - (photo_top - pad_t))
		var photo_w := minf(area.x * 0.46, photo_h * 0.95)
		var photo := Rect2(Vector2(area.x * 0.5 - photo_w * 0.5, photo_top),
			Vector2(photo_w, photo_h))
		var texture: Texture2D = UiAssets.player_face(int(entry.get("tm_id", 0)))
		if texture != null:
			GpfGamePlan._draw_texture_contain(self, texture, photo)
		else:
			_draw_silhouette(photo, ink2)

		var name_size := maxi(14, int(area.y * 0.21))
		var name_baseline := area.y - pad_b - 1.0
		var bar_y := minf(pad_t + top_h + 2.0,
			name_baseline - float(name_size) - 4.0)
		var bar_h := maxf(4.0, area.y * 0.035)
		var bar := Rect2(Vector2(pad_l, bar_y), Vector2(area.x - pad_l - pad_r, bar_h))
		var fatigue := clampi(int(entry.get("fatigue", 100)), 0, 100)
		GpfGamePlan._draw_fatigue_bar(self, bar, fatigue)

		draw_string(FONT_HEAD, Vector2(pad_l, name_baseline),
			_short_name(str(entry.get("name", ""))), HORIZONTAL_ALIGNMENT_CENTER,
			area.x - pad_l - pad_r, name_size, mark)

	func _draw_silhouette(photo: Rect2, color: Color) -> void:
		var center := photo.get_center()
		var radius := minf(photo.size.x, photo.size.y) * 0.22
		draw_circle(center + Vector2(0, -radius * 0.55), radius * 0.55,
			Color(color, 0.35))
		draw_rect(Rect2(center.x - radius, center.y + radius * 0.15,
			radius * 2.0, photo.size.y * 0.36), Color(color, 0.25), true)

	func _gui_input(event: InputEvent) -> void:
		if not editable:
			return
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
				activated.emit(entry_index)
				accept_event()

	static func _short_name(value: String) -> String:
		if value.length() <= 15:
			return value
		return value.substr(0, 14) + "."

	static func _short_role(role: String) -> String:
		return role if role.length() <= 3 else role.substr(0, 3)

	static func _pos_color(role: String) -> Color:
		match role:
			"GK":
				return Color(0.95, 0.55, 0.10, 1.0)
			"CB", "LB", "RB", "LWB", "RWB", "SW":
				return Color(0.95, 0.82, 0.16, 1.0)
			"DM", "CM", "LM", "RM", "AM":
				return Color(0.30, 0.78, 0.35, 1.0)
			"CF", "ST", "LW", "RW":
				return Color(0.22, 0.52, 0.95, 1.0)
			_:
				return C_INK2


class SchemeRail extends Control:
	var page := 0
	var page_count := 1

	func _draw() -> void:
		var area := get_size()
		if area.x <= 0.0 or area.y <= 1.0:
			return
		draw_rect(Rect2(Vector2.ZERO, Vector2(7.0, area.y)), Color(C_INK, 0.24), true)
		if page_count <= 1:
			return
		var thumb_h := area.y / float(page_count)
		var thumb_y := thumb_h * float(clampi(page, 0, page_count - 1))
		draw_rect(Rect2(Vector2(0, thumb_y), Vector2(7.0, thumb_h)),
			Color(C_INK, 0.78), true)


class SchemeCard extends Control:
	var index := 0
	var selected := false
	var focused := false
	var scheme_name := ""

	func setup(scheme_index: int, name_text: String) -> void:
		index = scheme_index
		scheme_name = name_text
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var area := get_size()
		if area.x <= 2.0 or area.y <= 2.0:
			return
		var fill := C_TILE_ALT
		var ink := C_INK
		if focused:
			fill = C_FOCUS_FILL
			ink = C_FOCUS_INK
		draw_rect(Rect2(Vector2.ZERO, area), fill, true)
		draw_string(FONT_HEAD, Vector2(8, area.y * 0.15), scheme_name,
			HORIZONTAL_ALIGNMENT_LEFT, area.x - 16.0, maxi(14, int(area.y * 0.16)),
			C_MARK if focused else ink)
		var pitch := Rect2(Vector2(8, area.y * 0.22), Vector2(area.x - 16.0, area.y * 0.66))
		var surface := PackedVector2Array([
			_pitch_point(pitch, 0.0, 0.0),
			_pitch_point(pitch, 1.0, 0.0),
			_pitch_point(pitch, 1.0, 1.0),
			_pitch_point(pitch, 0.0, 1.0),
		])
		draw_colored_polygon(surface, C_PITCH)
		var bands := 8
		for band in bands:
			if band % 2 != 0:
				continue
			var v0 := float(band) / float(bands)
			var v1 := float(band + 1) / float(bands)
			draw_colored_polygon(PackedVector2Array([
				_pitch_point(pitch, 0.0, v0),
				_pitch_point(pitch, 1.0, v0),
				_pitch_point(pitch, 1.0, v1),
				_pitch_point(pitch, 0.0, v1),
			]), C_PITCH_HI)
		var line := Color(1, 1, 1, 0.55)
		draw_polyline(_closed(surface), line, 1.0)
		draw_line(_pitch_point(pitch, 0.0, 0.5), _pitch_point(pitch, 1.0, 0.5), line, 0.8)
		var center := _pitch_point(pitch, 0.5, 0.5)
		var circle := PackedVector2Array()
		for i in 24:
			var angle := TAU * float(i) / 24.0
			circle.append(center + Vector2(cos(angle) * pitch.size.x * 0.11,
				sin(angle) * pitch.size.y * 0.06))
		draw_polyline(circle, line, 0.8)
		for top in [true, false]:
			var goal_v := 0.0 if top else 1.0
			var far_v := 0.16 if top else 0.84
			draw_polyline(PackedVector2Array([
				_pitch_point(pitch, 0.75, goal_v),
				_pitch_point(pitch, 0.75, far_v),
				_pitch_point(pitch, 0.25, far_v),
				_pitch_point(pitch, 0.25, goal_v),
			]), line, 0.8)
			var goal_far_v := 0.06 if top else 0.94
			draw_polyline(PackedVector2Array([
				_pitch_point(pitch, 0.60, goal_v),
				_pitch_point(pitch, 0.60, goal_far_v),
				_pitch_point(pitch, 0.40, goal_far_v),
				_pitch_point(pitch, 0.40, goal_v),
			]), line, 0.8)
		var entries: Array = TacticalSchemes.SCHEMES[index]["entries"]
		for entry in entries:
			var pos: Vector2 = entry["position"]
			var role := str(entry["role"])
			var side := clampf(pos.y * 0.5 + 0.5, 0.06, 0.94)
			var depth := clampf(1.0 - (pos.x * 0.5 + 0.5), 0.10, 0.90)
			if role == "GK":
				depth = 0.92
			elif role in ["CB", "LB", "RB", "LWB", "RWB", "SW"]:
				depth = clampf(depth, 0.68, 0.80)
			var point := _pitch_point(pitch, side, depth)
			var dot := Color(1.0, 0.30, 0.43, 1.0) if role == "GK" \
				else Color(0.96, 0.97, 0.99, 1.0)
			var dot_r := clampf(pitch.size.x * 0.018, 2.4, 3.6)
			draw_circle(point + Vector2(0.0, 0.8), dot_r + 0.8, Color(0, 0, 0, 0.28))
			draw_circle(point, dot_r, dot)
		if selected:
			var check := Rect2(Vector2(8, area.y - 24.0), Vector2(18, 18))
			draw_rect(check, C_MARK, true)
			draw_line(check.position + Vector2(4, 9), check.position + Vector2(8, 13),
				C_INK, 2.0)
			draw_line(check.position + Vector2(8, 13), check.position + Vector2(14, 5),
				C_INK, 2.0)

	func _pitch_point(pitch: Rect2, u: float, v: float) -> Vector2:
		var left := lerpf(pitch.position.x + pitch.size.x * 0.08, pitch.position.x, v)
		var right := lerpf(pitch.end.x - pitch.size.x * 0.08, pitch.end.x, v)
		return Vector2(lerpf(left, right, u), lerpf(pitch.position.y, pitch.end.y, v))

	func _closed(points: PackedVector2Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(point)
		if not points.is_empty():
			result.append(points[0])
		return result

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
				accept_event()


class RoleTile extends Control:
	var index := 0
	var title := ""
	var player_name := "—"
	var focused := false
	var assigned := false

	func _draw() -> void:
		var area := get_size()
		if area.x <= 2.0 or area.y <= 2.0:
			return
		var fill := C_TILE
		var ink := C_INK
		var ink2 := C_INK2
		if focused:
			fill = C_FOCUS_FILL
			ink = C_MARK
			ink2 = C_FOCUS_INK2
		draw_rect(Rect2(Vector2.ZERO, area), fill, true)
		draw_rect(Rect2(Vector2.ZERO, area), Color(C_INK, 0.16), false, 1.0)
		var pad := maxf(6.0, area.y * 0.06)
		draw_string(FONT_HEAD_X, Vector2(pad, pad + area.y * 0.16), title.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, area.x - pad * 2.0,
			maxi(15, int(area.y * 0.17)), ink)
		var glyph_center := Vector2(area.x * 0.5, area.y * 0.48)
		var glyph := minf(area.x, area.y) * 0.16
		_draw_glyph(glyph_center, glyph, ink2)
		draw_string(FONT_HEAD_X, Vector2(pad, area.y - pad * 0.7), player_name.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, area.x - pad * 2.0,
			maxi(15, int(area.y * 0.18)), ink)

	func _draw_glyph(center: Vector2, size: float, color: Color) -> void:
		match index:
			0:
				draw_rect(Rect2(center - Vector2(size * 0.5, size * 0.5),
					Vector2(size, size)), color, false, 2.0)
				draw_string(FONT_HEAD_X, center + Vector2(-size * 0.5, size * 0.34),
					"C", HORIZONTAL_ALIGNMENT_CENTER, size,
					maxi(12, int(size * 1.1)), color)
			1, 2:
				draw_circle(center + Vector2(-size * 0.10, 0), size * 0.34, color)
				draw_line(center + Vector2(size * 0.12, size * 0.28),
					center + Vector2(size * 0.55, size * 0.55), color, 2.0)
			3:
				draw_circle(center, size * 0.55, color)
				draw_circle(center, size * 0.16, color)
				draw_line(center + Vector2(-size * 0.8, 0), center + Vector2(size * 0.8, 0),
					color, 1.0)
			4, 5:
				draw_line(center + Vector2(-size * 0.4, size * 0.55),
					center + Vector2(-size * 0.4, -size * 0.55), color, 2.0)
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-size * 0.4, -size * 0.55),
					center + Vector2(size * 0.45, -size * 0.35),
					center + Vector2(-size * 0.4, -size * 0.10),
				]), color)
			_:
				draw_circle(center, size * 0.35, color)


class ReadyOverlay extends Control:
	var crest: Texture2D = null
	var team_name := ""
	var ready_text := "READY!"
	var dim := true
	var watermark := false

	func _draw() -> void:
		var area := get_size()
		if area.x <= 2.0 or area.y <= 2.0:
			return
		if watermark:
			if crest != null:
				var watermark_size := clampf(minf(area.x, area.y) * 0.38, 160.0, 320.0)
				var watermark_rect := Rect2(
					Vector2(area.x * 0.5 - watermark_size * 0.5,
						area.y * 0.5 - watermark_size * 0.5),
					Vector2(watermark_size, watermark_size))
				GpfGamePlan._draw_texture_contain(self, crest, watermark_rect, false,
					Color(1, 1, 1, 0.24))
			return
		if dim:
			draw_rect(Rect2(Vector2.ZERO, area), Color(0.02, 0.05, 0.04, 0.45), true)
		var font := FONT_HEAD_X
		var crest_size := clampf(minf(area.x, area.y) * 0.30, 120.0, 220.0)
		var crest_rect := Rect2(
			Vector2(area.x * 0.5 - crest_size * 0.5, area.y * 0.42 - crest_size * 0.5),
			Vector2(crest_size, crest_size))
		if crest != null:
			GpfGamePlan._draw_texture_contain(self, crest, crest_rect, false)
		else:
			draw_circle(crest_rect.get_center(), crest_size * 0.42, Color(0.14, 0.22, 0.38, 0.9))
			draw_string(font, crest_rect.get_center() + Vector2(-crest_size * 0.22, crest_size * 0.08),
				team_name.substr(0, 3).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
				crest_size * 0.44, maxi(14, int(crest_size * 0.22)), Color(0.86, 0.90, 0.94))
		draw_string(font, Vector2(0, area.y * 0.70), ready_text, HORIZONTAL_ALIGNMENT_CENTER,
			area.x, maxi(28, int(area.y * 0.08)), C_TILE)


var mode := "prematch" # "prematch" | "match" | "demo"
var runtime = null
var network_mode := false
var local_two_player := false

var _lineups: Dictionary = {}
var _demo_teams: Dictionary = {}
var _team_names: Dictionary = {}
var _team_colors: Dictionary = {}
var _human_teams: Array = []
var _panels: Array = []
var _display_teams: Array = []

var _built := false
var _background: ColorRect
var _panels_root: Control
var _status: Label
var _status_until_ms := 0
var _move_ms := 0
var _close_at_ms := 0
var _net_refresh_ms := 0

var _match_bench_ids: Dictionary = {}
var _match_reserve_ids: Dictionary = {}
var _match_players_by_db: Dictionary = {}


func _ready() -> void:
	theme = UiTheme.load_or_build()
	_build_chrome()
	set_process(true)


func setup_prematch(home_lineup: MatchLineup, away_lineup: MatchLineup,
		human_teams: Array = [0], options: Dictionary = {}) -> void:
	mode = "prematch"
	runtime = null
	network_mode = bool(options.get("network", false))
	local_two_player = bool(options.get("local_two_player", false))
	_lineups = {0: home_lineup, 1: away_lineup}
	_human_teams = _unique_teams(human_teams)
	_resolve_teams()
	_rebuild()


func setup_match(runtime_node, human_teams: Array = [0], options: Dictionary = {}) -> void:
	mode = "match"
	runtime = runtime_node
	network_mode = bool(options.get("network", false))
	local_two_player = bool(options.get("local_two_player", false))
	_human_teams = _unique_teams(human_teams)
	_resolve_teams()
	_build_match_roster()
	_rebuild()


func setup_demo(home: Dictionary, away: Dictionary, human_teams: Array = [0],
		options: Dictionary = {}) -> void:
	mode = "demo"
	runtime = null
	network_mode = bool(options.get("network", false))
	local_two_player = bool(options.get("local_two_player", false))
	_demo_teams = {0: home, 1: away}
	_human_teams = _unique_teams(human_teams)
	_resolve_teams()
	_rebuild()


func is_open() -> bool:
	return _built and visible


func open_plan() -> void:
	if not _built:
		_build_chrome()
	visible = true
	move_to_front()
	_close_at_ms = 0
	for panel in _panels:
		panel["ready"] = false
		panel["held"] = -1
		panel["details_open"] = false
		panel["role_picking"] = false
		panel["strength_initial"] = -1
		_collapse_drawer(panel)
		var hints: UiHintsBar = panel.get("hints", null)
		if hints != null:
			hints.set_status("")
	_rebuild()
	_layout()


func close_plan() -> void:
	visible = false
	_close_at_ms = 0
	_held_clear()


func handle_key(event: InputEventKey) -> bool:
	if not is_open() or not event.pressed or event.echo:
		return false
	var panel_index := _panel_for_keyboard()
	if panel_index < 0:
		return false
	match event.keycode:
		KEY_LEFT:
			return _handle_panel(panel_index, Vector2i(-1, 0), false, false)
		KEY_RIGHT:
			return _handle_panel(panel_index, Vector2i(1, 0), false, false)
		KEY_UP:
			return _handle_panel(panel_index, Vector2i(0, -1), false, false)
		KEY_DOWN:
			return _handle_panel(panel_index, Vector2i(0, 1), false, false)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			return _handle_panel(panel_index, Vector2i.ZERO, true, false)
		KEY_ESCAPE:
			return _handle_panel(panel_index, Vector2i.ZERO, false, true)
		KEY_Q:
			return _switch_tab(panel_index, -1)
		KEY_E:
			return _switch_tab(panel_index, 1)
		KEY_Y:
			return _toggle_details(panel_index)
		_:
			return false


func handle_joy_button(event: InputEventJoypadButton) -> bool:
	if not is_open() or not event.pressed:
		return false
	var panel_index := _panel_for_device(int(event.device))
	if panel_index < 0:
		return false
	match int(event.button_index):
		JOY_BUTTON_A:
			return _handle_panel(panel_index, Vector2i.ZERO, true, false)
		JOY_BUTTON_B:
			return _handle_panel(panel_index, Vector2i.ZERO, false, true)
		JOY_BUTTON_Y:
			return _toggle_details(panel_index)
		JOY_BUTTON_LEFT_SHOULDER:
			return _switch_tab(panel_index, -1)
		JOY_BUTTON_RIGHT_SHOULDER:
			return _switch_tab(panel_index, 1)
		JOY_BUTTON_DPAD_LEFT:
			return _handle_panel(panel_index, Vector2i(-1, 0), false, false)
		JOY_BUTTON_DPAD_RIGHT:
			return _handle_panel(panel_index, Vector2i(1, 0), false, false)
		JOY_BUTTON_DPAD_UP:
			return _handle_panel(panel_index, Vector2i(0, -1), false, false)
		JOY_BUTTON_DPAD_DOWN:
			return _handle_panel(panel_index, Vector2i(0, 1), false, false)
	return false


func handle_joy_motion(event: InputEventJoypadMotion) -> bool:
	if not is_open():
		return false
	var panel_index := _panel_for_device(int(event.device))
	if panel_index < 0:
		return false
	if absf(event.axis_value) <= 0.55:
		return false
	var now := Time.get_ticks_msec()
	if now - _move_ms < ROW_REPEAT_MS:
		return true
	var axis := int(event.axis)
	var direction := Vector2i.ZERO
	if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_RIGHT_X:
		direction = Vector2i(1 if event.axis_value > 0.0 else -1, 0)
	elif axis == JOY_AXIS_LEFT_Y or axis == JOY_AXIS_RIGHT_Y:
		direction = Vector2i(0, 1 if event.axis_value > 0.0 else -1)
	else:
		return false
	_move_ms = now
	return _handle_panel(panel_index, direction, false, false)


func handle_ui_action(action: String, device: int = -1) -> bool:
	if not is_open():
		return false
	var panel_index := _panel_for_device(device) if device >= 0 else _panel_for_keyboard()
	if panel_index < 0:
		return false
	match action:
		"left":
			return _handle_panel(panel_index, Vector2i(-1, 0), false, false)
		"right":
			return _handle_panel(panel_index, Vector2i(1, 0), false, false)
		"up":
			return _handle_panel(panel_index, Vector2i(0, -1), false, false)
		"down":
			return _handle_panel(panel_index, Vector2i(0, 1), false, false)
		"confirm":
			return _handle_panel(panel_index, Vector2i.ZERO, true, false)
		"cancel":
			return _handle_panel(panel_index, Vector2i.ZERO, false, true)
		"tab_prev", "bench":
			return _switch_tab(panel_index, -1)
		"tab_next":
			return _switch_tab(panel_index, 1)
		"details":
			return _toggle_details(panel_index)
	return false


func set_context(network: bool, two_player: bool) -> void:
	network_mode = network
	local_two_player = two_player


func set_status(text: String, duration_ms: int = 4000) -> void:
	if _status != null:
		_status.text = text
		_status_until_ms = Time.get_ticks_msec() + duration_ms
	for panel in _panels:
		var hints: UiHintsBar = panel.get("hints", null)
		if hints != null and bool(panel.get("editable", false)):
			hints.set_status(text)


func _process(_delta: float) -> void:
	if _status != null and Time.get_ticks_msec() > _status_until_ms and not _status.text.is_empty():
		_status.text = ""
		for panel in _panels:
			var hints: UiHintsBar = panel.get("hints", null)
			if hints != null:
				hints.set_status("")
	if _close_at_ms > 0 and Time.get_ticks_msec() >= _close_at_ms:
		_close_at_ms = 0
		close_requested.emit()
	if network_mode and mode == "match" and is_open():
		var now := Time.get_ticks_msec()
		if now - _net_refresh_ms >= 250:
			_net_refresh_ms = now
			for panel in _panels:
				_refresh_panel(panel, false)
			_layout()


# ---------------------------------------------------------------------------
# Chrome / panels
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
	if _built:
		return
	_built = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_background = ColorRect.new()
	_background.color = Color(0.015, 0.035, 0.078, 0.18)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_panels_root = Control.new()
	_panels_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panels_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panels_root)

	_status = Label.new()
	_status.visible = false
	_status.text = ""
	add_child(_status)

	resized.connect(_layout)
	_layout()


func _resolve_teams() -> void:
	_team_names.clear()
	_team_colors.clear()
	for team_id in [0, 1]:
		_team_colors[team_id] = _shell_color(team_id)
	if mode == "demo":
		for team_id in [0, 1]:
			_team_names[team_id] = str(_demo_teams.get(team_id, {}).get("name", "TEAM %d" % (team_id + 1)))
			var color = _demo_teams.get(team_id, {}).get("color", null)
			if color is Color:
				_team_colors[team_id] = color
	else:
		for team_id in [0, 1]:
			var team: Dictionary = ShellState.home_team if team_id == 0 else ShellState.away_team
			_team_names[team_id] = str(team.get("name", "HOME" if team_id == 0 else "AWAY"))
	_display_teams = [0, 1]


func _shell_color(team_id: int) -> Color:
	var team: Dictionary = ShellState.home_team if team_id == 0 else ShellState.away_team
	var raw := str(team.get("color1", ""))
	if raw.is_empty():
		return DEFAULT_COLORS.get(team_id, Color(0.4, 0.4, 0.4))
	return Color.from_string(raw, DEFAULT_COLORS.get(team_id, Color(0.4, 0.4, 0.4)))


func _unique_teams(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var team_id := int(value)
		if team_id >= 0 and team_id <= 1 and not result.has(team_id):
			result.append(team_id)
	if result.is_empty():
		result = [0]
	result.sort()
	return result


func _is_editable(team_id: int) -> bool:
	return _human_teams.has(team_id)


func _show_crest(panel: Dictionary) -> bool:
	var team_id := int(panel["team_id"])
	if _is_editable(team_id):
		return false
	return mode != "match" and mode != "demo"


func _rebuild() -> void:
	if not _built or not is_inside_tree():
		return
	_build_panels()
	_layout()
	for index in _panels.size():
		_refresh_panel(_panels[index])


func _build_panels() -> void:
	if not _panels.is_empty():
		return
	for team_id in _display_teams:
		_panels.append(_make_panel(team_id))
	_layout()


func _make_panel(team_id: int) -> Dictionary:
	var panel: Dictionary = {
		"team_id": team_id,
		"editable": _is_editable(team_id),
		"control": Control.new(),
		"tabs": UiTabBar.new(),
		"header": GamePlanHeader.new(),
		"pitch": GamePlanPitch.new(),
		"drawer": Control.new(),
		"drawer_bg": Panel.new(),
		"bench_scroll": ScrollContainer.new(),
		"bench_box": VBoxContainer.new(),
		"bench_header": Label.new(),
		"bench_grid": GridContainer.new(),
		"bench_cards": {},
		"reserve_rule": ColorRect.new(),
		"reserve_header": Label.new(),
		"reserve_grid": GridContainer.new(),
		"drawer_open": false,
		"drawer_t": 0.0,
		"drawer_tween": null,
		"scheme_grid": GridContainer.new(),
		"scheme_rail": SchemeRail.new(),
		"scheme_header": Label.new(),
		"scheme_cards": [],
		"scheme_page": 0,
		"role_grid": Control.new(),
		"role_header": Label.new(),
		"role_tiles": [],
		"hints": null,
		"ready_overlay": ReadyOverlay.new(),
		"crest_overlay": ReadyOverlay.new(),
		"details": GamePlanDetails.new(),
		"entries": [],
		"pitch_entries": [],
		"bench_entries": [],
		"reserve_entries": [],
		"entry_points": {},
		"cursor": -1,
		"held": -1,
		"tab": TAB_SQUAD,
		"scheme_cursor": 0,
		"committed_scheme": -1,
		"role_cursor": 0,
		"role_picking": false,
		"role_picking_index": 0,
		"pending": [],
		"bench_order": [],
		"strength_initial": -1,
		"ready": false,
		"details_open": false,
		"pitch_rect": Rect2(),
		"drawer_rect": Rect2(),
	}
	var control: Control = panel["control"]
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	_panels_root.add_child(control)

	var tabs: UiTabBar = panel["tabs"]
	tabs.always_focused = true
	tabs.setup(TAB_NAMES)
	tabs.tab_selected.connect(_on_tab_bar_selected.bind(team_id))
	control.add_child(tabs)

	var header: GamePlanHeader = panel["header"]
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(header)

	var pitch: GamePlanPitch = panel["pitch"]
	pitch.panel_index = _panels.size()
	pitch.team_color = _team_colors.get(team_id, Color(0.3, 0.4, 0.8))
	pitch.mouse_filter = Control.MOUSE_FILTER_STOP
	pitch.card_clicked.connect(_on_card_clicked)
	pitch.card_hovered.connect(_on_card_hovered)
	control.add_child(pitch)

	var drawer: Control = panel["drawer"]
	drawer.mouse_filter = Control.MOUSE_FILTER_PASS
	control.add_child(drawer)
	var drawer_bg: Panel = panel["drawer_bg"]
	drawer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(drawer_bg)

	var scroll: ScrollContainer = panel["bench_scroll"]
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	drawer.add_child(scroll)
	var box: VBoxContainer = panel["bench_box"]
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	for header_key in ["bench_header", "reserve_header"]:
		var header_label: Label = panel[header_key]
		header_label.add_theme_font_override("font", FONT_BODY)
		header_label.add_theme_color_override("font_color", C_INK2)
		header_label.add_theme_font_size_override("font_size", 18)
	for grid_key in ["bench_grid", "reserve_grid"]:
		var grid: GridContainer = panel[grid_key]
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Header above its own group: BENCH header, bench row, thin rule,
	# RESERVE header, reserve row (the reserve label must not float above
	# the bench).
	var reserve_rule: ColorRect = panel["reserve_rule"]
	reserve_rule.color = Color(C_INK, 0.16)
	reserve_rule.custom_minimum_size = Vector2(0.0, 1.0)
	reserve_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reserve_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(panel["bench_header"])
	box.add_child(panel["bench_grid"])
	box.add_child(reserve_rule)
	box.add_child(panel["reserve_header"])
	box.add_child(panel["reserve_grid"])

	var scheme_header: Label = panel["scheme_header"]
	scheme_header.add_theme_font_override("font", FONT_BODY)
	scheme_header.add_theme_color_override("font_color", C_INK2)
	scheme_header.add_theme_font_size_override("font_size", 18)
	scheme_header.text = "FORMATION · 1/2"
	drawer.add_child(scheme_header)
	var scheme_grid: GridContainer = panel["scheme_grid"]
	scheme_grid.columns = 3
	scheme_grid.add_theme_constant_override("h_separation", 8)
	scheme_grid.add_theme_constant_override("v_separation", 8)
	drawer.add_child(scheme_grid)
	var scheme_cards: Array = panel["scheme_cards"]
	for scheme_index in TacticalSchemes.count():
		var card := SchemeCard.new()
		card.setup(scheme_index, TacticalSchemes.scheme_name(scheme_index))
		card.gui_input.connect(_on_scheme_clicked.bind(team_id, scheme_index))
		card.mouse_entered.connect(_on_scheme_hovered.bind(team_id, scheme_index))
		scheme_grid.add_child(card)
		scheme_cards.append(card)
	var scheme_rail: SchemeRail = panel["scheme_rail"]
	scheme_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(scheme_rail)

	var role_header: Label = panel["role_header"]
	role_header.add_theme_font_override("font", FONT_BODY)
	role_header.add_theme_color_override("font_color", C_INK2)
	role_header.add_theme_font_size_override("font_size", 18)
	role_header.text = "SET-PIECE TAKERS"
	drawer.add_child(role_header)
	var role_grid: Control = panel["role_grid"]
	drawer.add_child(role_grid)
	var role_tiles: Array = panel["role_tiles"]
	for row_index in TEAM_ROLE_ROWS.size():
		var tile := RoleTile.new()
		tile.index = row_index
		tile.title = str(TEAM_ROLE_ROWS[row_index]["name"])
		tile.gui_input.connect(_on_role_clicked.bind(team_id, row_index))
		tile.mouse_entered.connect(_on_role_hovered.bind(team_id, row_index))
		role_grid.add_child(tile)
		role_tiles.append(tile)

	var hints: UiHintsBar = HINTS_SCENE.instantiate() as UiHintsBar
	hints.visible = false
	control.add_child(hints)
	panel["hints"] = hints

	var ready_overlay: ReadyOverlay = panel["ready_overlay"]
	ready_overlay.visible = false
	ready_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	control.add_child(ready_overlay)

	var crest_overlay: ReadyOverlay = panel["crest_overlay"]
	crest_overlay.visible = false
	crest_overlay.dim = true
	crest_overlay.watermark = false
	crest_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(crest_overlay)

	var details: GamePlanDetails = panel["details"]
	details.visible = false
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(details)

	return panel


func _layout() -> void:
	if not _built or _panels.is_empty():
		return
	var area := size
	if area.x < 4.0 or area.y < 4.0:
		return
	var u := area.y / 1080.0
	var pad := maxf(8.0, 24.0 * u)
	var half_w := (area.x - pad * 3.0) * 0.5
	var half_h := minf(area.y - pad * 2.0, 960.0 * u)
	var top := (area.y - half_h) * 0.5
	for panel in _panels:
		var team_id := int(panel["team_id"])
		var rect := Rect2(Vector2(pad, top), Vector2(half_w, half_h))
		if team_id == 1:
			rect.position.x = pad * 2.0 + half_w
		var control: Control = panel["control"]
		control.position = rect.position
		control.size = rect.size
		_layout_panel(panel, rect.size, u)


func _layout_panel(panel: Dictionary, panel_size: Vector2, u: float) -> void:
	var control: Control = panel["control"]
	var team_id := int(panel["team_id"])
	var editable := bool(panel["editable"])
	var crest := _show_crest(panel)
	var read_only_pitch := not editable and not crest

	var tabs_h := UiTokens.TAB_H
	var header_h := maxf(110.0, 150.0 * u)
	var hints_h := maxf(44.0, 60.0 * u)
	var collapsed_h := maxf(104.0, 138.0 * u)
	var max_opened_h := minf(panel_size.y * 0.62, 460.0 * u)
	var opened_h := _drawer_content_height(panel, u)
	var gap := maxf(6.0, 10.0 * u)
	var tab := int(panel["tab"])

	var tabs: UiTabBar = panel["tabs"]
	tabs.visible = editable
	tabs.position = Vector2.ZERO
	var tabs_size := Vector2(panel_size.x, tabs_h)
	if tabs.size != tabs_size:
		tabs.size = tabs_size
		tabs.refresh_layout()

	var header: GamePlanHeader = panel["header"]
	header.visible = editable and tab == TAB_SQUAD
	header.position = Vector2(0, tabs_h + gap)
	header.size = Vector2(panel_size.x, header_h)

	var hints: UiHintsBar = panel["hints"]
	hints.visible = editable and not bool(panel["ready"])
	hints.position = Vector2(0, panel_size.y - hints_h)
	hints.size = Vector2(panel_size.x, hints_h)

	var drawer: Control = panel["drawer"]
	var drawer_h := collapsed_h
	if tab == TAB_FORMATIONS or tab == TAB_ROLES:
		drawer_h = maxf(TAB_DRAWER_MIN_H, TAB_DRAWER_H * u)
	else:
		var open_h := clampf(opened_h, collapsed_h, maxf(collapsed_h, max_opened_h))
		drawer_h = lerpf(collapsed_h, open_h,
			clampf(float(panel["drawer_t"]), 0.0, 1.0))
	drawer.visible = editable and not bool(panel["details_open"])
	drawer.position = Vector2(0, panel_size.y - hints_h - drawer_h)
	drawer.size = Vector2(panel_size.x, drawer_h)
	var drawer_bg: Panel = panel["drawer_bg"]
	drawer_bg.position = Vector2.ZERO
	drawer_bg.size = drawer.size
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.941, 0.949, 0.969, 1.0) if tab == TAB_SQUAD else C_TILE
	bg_style.border_width_top = 2
	bg_style.border_color = Color(C_INK, 0.12)
	drawer_bg.add_theme_stylebox_override("panel", bg_style)

	var pitch_bottom_pad := collapsed_h
	if tab == TAB_FORMATIONS or tab == TAB_ROLES:
		pitch_bottom_pad = drawer_h
	var header_span := header_h + gap if tab == TAB_SQUAD else 0.0
	var pitch_rect := Rect2(
		Vector2(0, tabs_h + gap + header_span),
		Vector2(panel_size.x, panel_size.y - tabs_h - header_span - gap * 2 - hints_h
			- pitch_bottom_pad))
	if read_only_pitch:
		pitch_rect = Rect2(Vector2.ZERO, panel_size)
	var pitch: GamePlanPitch = panel["pitch"]
	pitch.visible = not crest
	pitch.position = pitch_rect.position
	pitch.size = pitch_rect.size
	panel["pitch_rect"] = pitch_rect
	panel["drawer_rect"] = Rect2(drawer.position, drawer.size)

	var bench_scroll: ScrollContainer = panel["bench_scroll"]
	var bench_margin := maxf(8.0, 10.0 * u)
	bench_scroll.position = Vector2(bench_margin, bench_margin)
	bench_scroll.size = Vector2(maxf(1.0, drawer.size.x - bench_margin * 2.0),
		maxf(1.0, drawer.size.y - bench_margin * 2.0))

	var scheme_header: Label = panel["scheme_header"]
	scheme_header.position = Vector2(10, 4)
	scheme_header.size = Vector2(drawer.size.x - 20.0, maxf(24.0, 28.0 * u))
	scheme_header.add_theme_font_size_override("font_size", maxi(10, int(13.0 * u)))
	var scheme_grid: GridContainer = panel["scheme_grid"]
	var scheme_w := maxf(200.0, drawer.size.x - 28.0)
	var scheme_content_h := maxf(80.0, drawer.size.y - scheme_header.size.y - 12.0)
	var card_w := (scheme_w - 16.0) / 3.0
	for card in panel["scheme_cards"]:
		card.custom_minimum_size = Vector2(card_w, scheme_content_h)
	scheme_grid.position = Vector2(10, scheme_header.position.y + scheme_header.size.y + 4.0)
	scheme_grid.size = Vector2(scheme_w, scheme_content_h)
	scheme_grid.columns = 3
	var scheme_rail: SchemeRail = panel["scheme_rail"]
	scheme_rail.visible = tab == TAB_FORMATIONS
	scheme_rail.position = Vector2(drawer.size.x - 10.0, scheme_grid.position.y + 4.0)
	scheme_rail.size = Vector2(7.0, maxf(1.0, scheme_content_h - 8.0))

	var role_header: Label = panel["role_header"]
	role_header.position = Vector2(10, 4)
	role_header.size = Vector2(drawer.size.x - 20.0, maxf(24.0, 28.0 * u))
	role_header.add_theme_font_size_override("font_size", maxi(10, int(13.0 * u)))
	var role_grid: Control = panel["role_grid"]
	role_grid.position = Vector2(0, role_header.size.y + 6.0)
	role_grid.size = Vector2(drawer.size.x, drawer.size.y - role_header.size.y - 6.0)
	var role_col_w := role_grid.size.x / 4.0
	var role_row_h := role_grid.size.y / 2.0
	var role_cells := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(1, 1), Vector2i(2, 1)]
	for index in (panel["role_tiles"] as Array).size():
		var tile: RoleTile = (panel["role_tiles"] as Array)[index]
		if index == 0:
			tile.position = Vector2.ZERO
			tile.size = Vector2(role_col_w, role_row_h * 2.0)
		else:
			var cell: Vector2i = role_cells[index - 1]
			tile.position = Vector2(role_col_w * cell.x, role_row_h * cell.y)
			tile.size = Vector2(role_col_w, role_row_h)

	var details: GamePlanDetails = panel["details"]
	details.visible = bool(panel["details_open"])
	details.position = Vector2(0, tabs_h + gap)
	details.size = Vector2(panel_size.x, panel_size.y - tabs_h - gap - hints_h)
	if bool(panel["details_open"]):
		header.visible = false
		pitch.visible = false
		drawer.visible = false

	var ready_overlay: ReadyOverlay = panel["ready_overlay"]
	ready_overlay.visible = bool(panel["ready"])
	ready_overlay.position = Vector2.ZERO
	ready_overlay.size = panel_size
	ready_overlay.crest = _crest_texture(team_id)
	ready_overlay.team_name = str(_team_names.get(team_id, ""))
	ready_overlay.ready_text = "READY!"
	ready_overlay.queue_redraw()

	var crest_overlay: ReadyOverlay = panel["crest_overlay"]
	crest_overlay.visible = crest and not bool(panel["ready"])
	crest_overlay.position = Vector2.ZERO
	crest_overlay.size = panel_size
	crest_overlay.crest = _crest_texture(team_id)
	crest_overlay.team_name = str(_team_names.get(team_id, ""))
	crest_overlay.ready_text = "READY!"
	crest_overlay.dim = true
	crest_overlay.watermark = false
	crest_overlay.queue_redraw()

	if bool(panel["ready"]):
		tabs.visible = false
		header.visible = false
		hints.visible = false
		drawer.visible = false
		pitch.visible = false
		details.visible = false
	elif crest:
		tabs.visible = false
		header.visible = false
		hints.visible = false
		drawer.visible = false
		pitch.visible = false
	elif read_only_pitch:
		tabs.visible = false
		header.visible = false
		hints.visible = false
		drawer.visible = false
	if not crest and not read_only_pitch and not bool(panel["ready"]):
		_update_entry_points(panel)


func _update_entry_points(panel: Dictionary) -> void:
	var tab := int(panel["tab"])
	var preview := _scheme_preview(panel) if tab == TAB_FORMATIONS else {}
	panel["entry_points"] = {}
	var cards := _build_cards(panel, panel["pitch_entries"], preview)
	(panel["pitch"] as GamePlanPitch).set_cards(cards)
	var points: Dictionary = panel["entry_points"]
	var drawer_rect: Rect2 = panel["drawer_rect"]
	var margin := maxf(8.0, 10.0 * size.y / 1080.0)
	var origin := drawer_rect.position + Vector2(margin, margin)
	var usable_w := maxf(1.0, drawer_rect.size.x - margin * 2.0)
	var open := bool(panel["drawer_open"])
	var card_h := clampf(size.y * 0.086, 64.0, 94.0)
	var header_h := maxf(18.0, size.y * 0.020)
	var bench_entries: Array = panel["bench_entries"]
	var visible_bench: Array = bench_entries
	if not open and visible_bench.size() > 4:
		visible_bench = visible_bench.slice(0, 4)
	for row in visible_bench.size():
		var index := int(visible_bench[row])
		var col := row % 4
		var grid_row := row / 4
		points[index] = origin + Vector2(
			usable_w * 0.125 + usable_w * 0.25 * col,
			(header_h if open else 0.0) + card_h * float(grid_row) + card_h * 0.5)
	if open and mode != "match":
		var reserve_entries: Array = panel["reserve_entries"]
		for row in reserve_entries.size():
			var index := int(reserve_entries[row])
			var col := row % 4
			var grid_row := row / 4
			var reserve_y: float = header_h * 2.0 \
				+ card_h * ceil(float(bench_entries.size()) / 4.0) + card_h * 0.5 \
				+ card_h * float(grid_row)
			points[index] = origin + Vector2(
				usable_w * 0.125 + usable_w * 0.25 * col, reserve_y)
	panel["entry_points"] = points

func _team_data(team_id: int) -> Dictionary:
	if mode == "match" and runtime != null:
		var data: Dictionary = runtime.get_squad(team_id)
		if data.is_empty():
			return {"name": _team_names.get(team_id, ""), "players": [], "roles": []}
		return data
	if mode == "demo":
		return _demo_teams.get(team_id, {"name": _team_names.get(team_id, ""), "players": [], "roles": []})
	return {"name": _team_names.get(team_id, ""), "players": [], "roles": []}


func _build_match_roster() -> void:
	_match_bench_ids.clear()
	_match_reserve_ids.clear()
	_match_players_by_db.clear()
	var package: Dictionary = ShellState.match_package
	if package.is_empty():
		return
	for team_id in [0, 1]:
		var side := "home" if team_id == 0 else "away"
		var team: Dictionary = package.get(side, {})
		var players: Array = team.get("players", [])
		var bench_ids := {}
		var reserve_ids := {}
		for index in players.size():
			if typeof(players[index]) != TYPE_DICTIONARY:
				continue
			var player: Dictionary = players[index]
			var db := int(player.get("database_id", -1))
			if db <= 0:
				continue
			_match_players_by_db[db] = player
			if index >= Formation.SLOT_COUNT and index < Formation.SLOT_COUNT + BENCH_SIZE:
				bench_ids[db] = true
			elif index >= Formation.SLOT_COUNT + BENCH_SIZE:
				reserve_ids[db] = true
		_match_bench_ids[team_id] = bench_ids
		_match_reserve_ids[team_id] = reserve_ids


func _entries_for(team_id: int, team_data: Dictionary) -> Array:
	if mode == "match":
		return _match_entries(team_id, team_data)
	return _lineup_entries(team_id)


func _lineup_entries(team_id: int) -> Array:
	var result: Array = []
	if mode == "demo":
		var team_data: Dictionary = _demo_teams.get(team_id, {})
		var players: Array = team_data.get("players", [])
		for index in players.size():
			if typeof(players[index]) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = (players[index] as Dictionary).duplicate(true)
			entry["entry_group"] = "pitch" if bool(entry.get("active", false)) else "bench"
			result.append(entry)
		return result
	var lineup: MatchLineup = _lineups.get(team_id)
	if lineup == null:
		return result
	var formation: Array = lineup.formation
	for slot in mini(Formation.SLOT_COUNT, lineup.lineup.size()):
		var player_id := int(lineup.lineup[slot])
		var player := lineup.player_by_id(player_id)
		if player.is_empty():
			continue
		var role := "CM"
		var position := Vector2.ZERO
		if slot < formation.size():
			role = str(formation[slot].get("role", "CM"))
			position = formation[slot].get("database_position",
				formation[slot].get("position", Vector2.ZERO))
		result.append(_entry_from_player(player_id, slot, player, role, position, true, "pitch"))
	for index in lineup.bench.size():
		var player_id := int(lineup.bench[index])
		var player := lineup.player_by_id(player_id)
		if player.is_empty():
			continue
		result.append(_entry_from_player(player_id, index, player, _natural_role(player),
			Vector2.ZERO, false, "bench"))
	for index in lineup.reserve.size():
		var player_id := int(lineup.reserve[index])
		var player := lineup.player_by_id(player_id)
		if player.is_empty():
			continue
		result.append(_entry_from_player(player_id, index, player, _natural_role(player),
			Vector2.ZERO, false, "reserve"))
	return result


func _match_entries(team_id: int, team_data: Dictionary) -> Array:
	var result: Array = []
	var bench_ids: Dictionary = _match_bench_ids.get(team_id, {})
	var reserve_ids: Dictionary = _match_reserve_ids.get(team_id, {})
	var fallback_bench := 0
	for raw in team_data.get("players", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (raw as Dictionary).duplicate(true)
		var db := int(entry.get("database_id", -1))
		var package_player: Dictionary = _match_players_by_db.get(db, {})
		if not package_player.is_empty():
			entry["tm_id"] = int(package_player.get("tm_id", entry.get("tm_id", 0)))
			entry["stats"] = (package_player.get("stats", {}) as Dictionary).duplicate(true)
		if str(entry.get("name", "")).strip_edges().is_empty():
			entry["name"] = str(entry.get("first_name", "?"))
		if bool(entry.get("active", false)):
			entry["entry_group"] = "pitch"
			result.append(entry)
			continue
		if bool(entry.get("left_pitch", false)):
			continue
		if not reserve_ids.is_empty() or not bench_ids.is_empty():
			if reserve_ids.has(db):
				continue
			entry["entry_group"] = "bench" if bench_ids.has(db) else "reserve"
			if entry["entry_group"] == "reserve":
				continue
		else:
			if fallback_bench >= BENCH_SIZE:
				continue
			fallback_bench += 1
			entry["entry_group"] = "bench"
		result.append(entry)
	return result


func _entry_from_player(player_id: int, slot: int, player: Dictionary, role: String,
		position: Vector2, active: bool, group: String) -> Dictionary:
	var rating := _rating_for_player(player)
	return {
		"id": player_id,
		"database_id": player_id,
		"tm_id": int(player.get("tm_id", 0)),
		"slot": slot,
		"name": _player_display_name(player),
		"first_name": str(player.get("firstname", player.get("first_name", ""))).strip_edges(),
		"last_name": str(player.get("lastname", player.get("last_name", ""))).strip_edges(),
		"role": role,
		"position": position,
		"active": active,
		"entry_group": group,
		"left_pitch": false,
		"pending_out": false,
		"pending_in": false,
		"rating": rating,
		"fatigue": 100,
		"stats": (player.get("stats", {}) as Dictionary).duplicate(true),
	}


func _rating_for_player(player: Dictionary) -> int:
	var base_stat := float(player.get("base_stat", 0.0))
	if base_stat > 0.0:
		return int(round(base_stat * 100.0))
	var average := float(player.get("average", 0.0))
	if average > 0.0:
		return int(round(average * 100.0))
	return -1


func _natural_role(player: Dictionary) -> String:
	var roles := str(player.get("role", "CM")).to_upper().replace(",", " ")
	for token in roles.split(" ", false):
		if Formation.VALID_ROLES.has(token):
			return token
	return "CM"


func _refresh_panel(panel: Dictionary, update_hints: bool = true) -> void:
	var team_id := int(panel["team_id"])
	var editable := _is_editable(team_id)
	panel["editable"] = editable
	var team_data := _team_data(team_id)
	panel["team_data"] = team_data
	panel["team_name"] = str(team_data.get("name", _team_names.get(team_id, "")))
	panel["pending"] = _pending_for_team(team_id)
	var entries := _entries_for(team_id, team_data)
	panel["entries"] = entries

	var pitch_entries: Array = []
	var bench_entries: Array = []
	var reserve_entries: Array = []
	for index in entries.size():
		var group := str(entries[index].get("entry_group", "pitch"))
		if group == "pitch":
			pitch_entries.append(index)
		elif group == "bench":
			bench_entries.append(index)
		elif group == "reserve":
			reserve_entries.append(index)
	if mode == "match":
		reserve_entries.clear()
	if not (panel["bench_order"] as Array).is_empty():
		var rank: Dictionary = {}
		var order: Array = panel["bench_order"]
		for position in order.size():
			rank[int(order[position])] = position
		bench_entries.sort_custom(func(a: int, b: int) -> bool:
			return int(rank.get(int(entries[a].get("id", -1)), 10000 + a)) \
				< int(rank.get(int(entries[b].get("id", -1)), 10000 + b)))
	panel["pitch_entries"] = pitch_entries
	panel["bench_entries"] = bench_entries
	panel["reserve_entries"] = reserve_entries

	if int(panel["cursor"]) < 0 or int(panel["cursor"]) >= entries.size():
		panel["cursor"] = int(pitch_entries[0]) if not pitch_entries.is_empty() else -1
		if panel["cursor"] < 0 and not bench_entries.is_empty():
			panel["cursor"] = int(bench_entries[0])
	var was_drawer_open := bool(panel["drawer_open"])
	if int(panel["cursor"]) >= 0:
		panel["drawer_open"] = not bool(entries[int(panel["cursor"])].get("active", false))
	if was_drawer_open != bool(panel["drawer_open"]):
		_animate_drawer(panel, bool(panel["drawer_open"]))

	panel["entry_points"] = {}
	var preview := _scheme_preview(panel) if int(panel["tab"]) == TAB_FORMATIONS else {}
	var cards := _build_cards(panel, pitch_entries, preview)
	var pitch: GamePlanPitch = panel["pitch"]
	pitch.team_color = _team_colors.get(team_id, Color(0.3, 0.4, 0.8))
	pitch.set_cards(cards)
	var show_cursor := editable and not bool(panel["details_open"]) \
		and (int(panel["tab"]) == TAB_SQUAD
			or (int(panel["tab"]) == TAB_ROLES and bool(panel["role_picking"])))
	pitch.set_markers(int(panel["cursor"]), int(panel["held"]), show_cursor)
	panel["strength_current"] = _team_strength(entries, pitch_entries)
	if int(panel["strength_initial"]) < 0:
		panel["strength_initial"] = int(panel["strength_current"])
	pitch.set_strength(int(panel["strength_current"]),
		int(panel["strength_current"]) - int(panel["strength_initial"]))

	_refresh_header(panel)
	_rebuild_drawer(panel)
	_refresh_tabs(panel)
	_refresh_ready(panel)
	if update_hints:
		_refresh_hints(panel)
	var cursor := int(panel["cursor"])
	if cursor >= 0 and cursor < entries.size() \
			and not bool(entries[cursor].get("active", false)):
		call_deferred("_ensure_cursor_visible", team_id)


func _ensure_cursor_visible(team_id: int) -> void:
	await get_tree().process_frame
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	var cursor := int(panel["cursor"])
	var card: BenchCard = panel["bench_cards"].get(cursor, null)
	if card == null or not is_instance_valid(card):
		return
	var scroll: ScrollContainer = panel["bench_scroll"]
	if scroll != null:
		scroll.ensure_control_visible(card)
		# The group label lives inside the scroll box; landing on the first
		# row must also reveal it, otherwise the header stays scrolled away.
		var header: Control = _group_header_for(panel, cursor)
		if header != null and header.visible:
			scroll.ensure_control_visible(header)


func _group_header_for(panel: Dictionary, cursor: int) -> Control:
	var entries: Array = panel["entries"]
	if cursor < 0 or cursor >= entries.size():
		return null
	var group := str(entries[cursor].get("entry_group", "pitch"))
	var list: Array = []
	var header_key := ""
	if group == "bench":
		list = panel["bench_entries"]
		header_key = "bench_header"
	elif group == "reserve":
		list = panel["reserve_entries"]
		header_key = "reserve_header"
	else:
		return null
	var position := list.find(cursor)
	if position < 0 or position >= 4:
		return null
	return panel[header_key]


func _collapse_drawer(panel: Dictionary) -> void:
	var active_tween: Tween = panel.get("drawer_tween", null)
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	panel["drawer_t"] = 0.0
	panel["drawer_open"] = false
	var scroll: ScrollContainer = panel["bench_scroll"]
	if scroll != null:
		scroll.scroll_vertical = 0
	# The drawer opens whenever the cursor sits on a bench player, so returning
	# to SQUAD must put the cursor back on the pitch to keep it collapsed.
	var entries: Array = panel["entries"]
	var cursor := int(panel["cursor"])
	if cursor >= 0 and cursor < entries.size() \
			and not bool(entries[cursor].get("active", false)):
		var pitch_entries: Array = panel["pitch_entries"]
		if not pitch_entries.is_empty():
			panel["cursor"] = int(pitch_entries[0])


func _animate_drawer(panel: Dictionary, open: bool) -> void:
	var active_tween: Tween = panel.get("drawer_tween", null)
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	var target := 1.0 if open else 0.0
	var current := clampf(float(panel["drawer_t"]), 0.0, 1.0)
	if is_equal_approx(current, target):
		panel["drawer_t"] = target
		_layout()
		return
	var tween := create_tween()
	panel["drawer_tween"] = tween
	tween.tween_method(_set_drawer_t.bind(int(panel["team_id"])),
		current, target, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_drawer_t(value: float, team_id: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	_panels[panel_index]["drawer_t"] = clampf(value, 0.0, 1.0)
	_layout()


func _refresh_header(panel: Dictionary) -> void:
	var header: GamePlanHeader = panel["header"]
	var entries: Array = panel["entries"]
	var cursor := int(panel["cursor"])
	var held := int(panel["held"])
	var primary: Dictionary = {}
	var secondary: Dictionary = {}
	if cursor >= 0 and cursor < entries.size():
		primary = entries[cursor]
	if held >= 0 and held < entries.size() and held != cursor:
		secondary = entries[held]
	header.set_players(primary, secondary, _team_colors.get(int(panel["team_id"]), Color(0.3, 0.4, 0.8)))
	var details: GamePlanDetails = panel["details"]
	details.set_player(primary, _team_colors.get(int(panel["team_id"]), Color(0.3, 0.4, 0.8)))
	details.queue_redraw()


func _build_cards(panel: Dictionary, pitch_entries: Array, preview: Dictionary = {}) -> Array:
	var pitch_rect: Rect2 = panel["pitch_rect"]
	var entries: Array = panel["entries"]
	if pitch_rect.size.x <= 2.0 or pitch_rect.size.y <= 2.0:
		return []
	var card_w := clampf(pitch_rect.size.x * 0.10, 54.0, 86.0)
	var photo_h := clampf(card_w * 0.58, 30.0, 46.0)
	var badge_h := maxf(14.0, card_w * 0.24)
	var name_h := maxf(16.0, card_w * 0.24)
	var bar_h := clampf(card_w * 0.07, 4.0, 6.0)
	var gap := 1.0
	var card_h := photo_h + badge_h + name_h + bar_h + gap * 3.0
	var cards: Array = []
	var points: Dictionary = panel["entry_points"]
	for index in pitch_entries:
		var entry: Dictionary = entries[index]
		var display: Dictionary = preview.get(index, {})
		var role := str(display.get("role", entry.get("role", "CM")))
		var position: Vector2 = display.get("database_position", entry.get("position", Vector2.ZERO))
		var shown := position
		if role == "GK":
			shown.x = -0.74
			shown.y = 0.0
		else:
			if role in ["CB", "LB", "RB", "LWB", "RWB", "SW"]:
				shown.x = -0.40
			else:
				shown.x *= 0.82 if shown.x < 0.0 else 0.68
			shown.y = clampf(shown.y * 0.80, -0.68, 0.68)
		var depth := shown.x * 0.5 + 0.5
		var side := shown.y * 0.5 + 0.5
		var anchor := Vector2((1.0 - side) * pitch_rect.size.x, (1.0 - depth) * pitch_rect.size.y)
		var x := clampf(anchor.x - card_w * 0.5, 0.0, pitch_rect.size.x - card_w)
		var y := clampf(anchor.y - card_h * 0.5, 0.0, pitch_rect.size.y - card_h)
		var rect := Rect2(Vector2(x, y), Vector2(card_w, card_h))
		var photo := Rect2(Vector2(x, y), Vector2(card_w, photo_h))
		var plate_w := clampf(card_w * 0.78, 44.0, 68.0)
		var role_rect := Rect2(Vector2(x + (card_w - plate_w) * 0.5, y + photo_h + gap),
			Vector2(plate_w, badge_h))
		var name_rect := Rect2(Vector2(x, role_rect.end.y + gap), Vector2(card_w, name_h))
		var bar_rect := Rect2(Vector2(x, name_rect.end.y + gap), Vector2(card_w, bar_h))
		cards.append({
			"entry_index": index,
			"entry": entry,
			"display_role": role,
			"rect": rect,
			"photo": photo,
			"role": role_rect,
			"name": name_rect,
			"bar": bar_rect,
			"photo_texture": UiAssets.player_face(int(entry.get("tm_id", 0))),
		})
		points[index] = pitch_rect.position + rect.get_center()
	panel["entry_points"] = points
	return cards


func _scheme_preview(panel: Dictionary) -> Dictionary:
	var pitch_entries: Array = panel["pitch_entries"]
	if pitch_entries.is_empty():
		return {}
	var entries: Array = panel["entries"]
	var scheme_cursor := int(panel["scheme_cursor"])
	var candidates: Array = []
	for index in pitch_entries:
		var entry: Dictionary = entries[index]
		candidates.append({
			"slot": index,
			"role": str(entry.get("role", "CM")),
			"position": entry.get("position", Vector2.ZERO),
		})
	var assignment := TacticalSchemes.assign(candidates, scheme_cursor)
	var preview: Dictionary = {}
	for offset in mini(assignment.size(), candidates.size()):
		preview[int(candidates[offset]["slot"])] = assignment[offset]
	return preview


func _team_strength(entries: Array, pitch_entries: Array) -> int:
	var total := 0
	var count := 0
	for index in pitch_entries:
		var rating := int(entries[index].get("rating", -1))
		if rating < 0:
			continue
		total += rating
		count += 1
	if count <= 0:
		return -1
	return int(round(float(total) / float(count)))


func _drawer_content_height(panel: Dictionary, u: float) -> float:
	var card_h := clampf(size.y * 0.086, 64.0, 94.0)
	var header_h := maxf(18.0, size.y * 0.020)
	var margin := maxf(8.0, 10.0 * u)
	var bench_rows := int(ceil(float((panel["bench_entries"] as Array).size()) / 4.0))
	var content := margin * 2.0 + header_h + 4.0
	if bench_rows > 0:
		content += card_h * float(bench_rows) + 8.0 * float(bench_rows - 1)
	if mode != "match":
		var reserve_rows := int(ceil(float((panel["reserve_entries"] as Array).size()) / 4.0))
		if reserve_rows > 0:
			content += 5.0 + 4.0 + header_h + 4.0 + card_h * float(reserve_rows) \
				+ 8.0 * float(reserve_rows - 1)
	return content


func _rebuild_drawer(panel: Dictionary) -> void:
	var tab := int(panel["tab"])
	var bench_scroll: ScrollContainer = panel["bench_scroll"]
	var scheme_grid: GridContainer = panel["scheme_grid"]
	var role_grid: Control = panel["role_grid"]
	bench_scroll.visible = tab == TAB_SQUAD
	scheme_grid.visible = tab == TAB_FORMATIONS
	role_grid.visible = tab == TAB_ROLES
	(panel["scheme_header"] as Control).visible = tab == TAB_FORMATIONS
	(panel["role_header"] as Control).visible = tab == TAB_ROLES
	if tab == TAB_SQUAD:
		_rebuild_bench(panel)
	elif tab == TAB_FORMATIONS:
		_refresh_scheme_cards(panel)
	else:
		_refresh_role_tiles(panel)


func _rebuild_bench(panel: Dictionary) -> void:
	var entries: Array = panel["entries"]
	var bench_entries: Array = panel["bench_entries"]
	var reserve_entries: Array = panel["reserve_entries"]
	var points: Dictionary = panel["entry_points"]
	var drawer_rect: Rect2 = panel["drawer_rect"]
	var open := bool(panel["drawer_open"])
	var team_id := int(panel["team_id"])
	var cursor := int(panel["cursor"])
	var held := int(panel["held"])
	var bench_header: Label = panel["bench_header"]
	var reserve_header: Label = panel["reserve_header"]
	var bench_grid: GridContainer = panel["bench_grid"]
	var reserve_grid: GridContainer = panel["reserve_grid"]
	for grid in [bench_grid, reserve_grid]:
		for child in grid.get_children():
			child.queue_free()
	panel["bench_cards"] = {}

	bench_header.text = "BENCH · %d" % bench_entries.size()
	if mode == "match":
		var team_data: Dictionary = panel.get("team_data", {})
		var pending_count := (panel.get("pending", []) as Array).size()
		bench_header.text += "    SUBS %d/%d" % [
			int(team_data.get("substitutions", 0)) + pending_count,
			int(team_data.get("max_substitutions", 5)),
		]
	bench_header.visible = true
	reserve_header.text = "RESERVE · %d" % reserve_entries.size()
	reserve_header.visible = open and mode != "match" and not reserve_entries.is_empty()
	var reserve_rule: Control = panel["reserve_rule"]
	reserve_rule.visible = reserve_header.visible

	var card_h := clampf(size.y * 0.086, 64.0, 94.0)
	var header_h := maxf(18.0, size.y * 0.020)
	var visible_bench: Array = bench_entries
	if not open and visible_bench.size() > 4:
		visible_bench = visible_bench.slice(0, 4)
	for row in visible_bench.size():
		var index := int(visible_bench[row])
		var entry: Dictionary = entries[index]
		var card := BenchCard.new()
		card.custom_minimum_size = Vector2(40, card_h)
		card.setup(entry, index, bool(panel["editable"]))
		card.set_state(cursor == index, held == index)
		card.activated.connect(_on_entry_pressed.bind(team_id, index))
		card.mouse_entered.connect(_on_entry_hovered.bind(team_id, index))
		bench_grid.add_child(card)
		(panel["bench_cards"] as Dictionary)[index] = card
		var col := row % 4
		var grid_row := row / 4
		points[index] = drawer_rect.position + Vector2(
			drawer_rect.size.x * 0.125 + drawer_rect.size.x * 0.25 * col,
			header_h + card_h * float(grid_row) + card_h * 0.5)
	if open and mode != "match":
		for row in reserve_entries.size():
			var index := int(reserve_entries[row])
			var entry: Dictionary = entries[index]
			var card := BenchCard.new()
			card.custom_minimum_size = Vector2(40, card_h)
			card.setup(entry, index, bool(panel["editable"]))
			card.set_state(cursor == index, held == index)
			card.activated.connect(_on_entry_pressed.bind(team_id, index))
			card.mouse_entered.connect(_on_entry_hovered.bind(team_id, index))
			reserve_grid.add_child(card)
			(panel["bench_cards"] as Dictionary)[index] = card
			var col := row % 4
			var grid_row := row / 4
			var reserve_y: float = header_h * 2.0 \
				+ card_h * ceil(float(bench_entries.size()) / 4.0) + card_h * 0.5 \
				+ card_h * float(grid_row)
			points[index] = drawer_rect.position + Vector2(
				drawer_rect.size.x * 0.125 + drawer_rect.size.x * 0.25 * col, reserve_y)
	panel["entry_points"] = points


func _refresh_scheme_cards(panel: Dictionary) -> void:
	var committed := _detect_committed_scheme(panel)
	panel["committed_scheme"] = committed
	var focused := int(panel["tab"]) == TAB_FORMATIONS
	var cursor := int(panel["scheme_cursor"])
	var page := cursor / 3
	panel["scheme_page"] = page
	var page_count := int(ceil(float(TacticalSchemes.count()) / 3.0))
	var rail: SchemeRail = panel["scheme_rail"]
	rail.page = page
	rail.page_count = page_count
	rail.queue_redraw()
	var scheme_label := "CUSTOM"
	if committed >= 0:
		scheme_label = TacticalSchemes.scheme_name(committed)
	(panel["scheme_header"] as Label).text = "FORMATION · %s · %d/%d" \
		% [scheme_label, page + 1, page_count]
	for index in (panel["scheme_cards"] as Array).size():
		var card: SchemeCard = (panel["scheme_cards"] as Array)[index]
		card.visible = index / 3 == page
		card.selected = index == committed
		card.focused = focused and index == cursor
		card.queue_redraw()


func _detect_committed_scheme(panel: Dictionary) -> int:
	var entries: Array = panel["entries"]
	var formation: Array = []
	for entry in entries:
		if not bool(entry.get("active", false)):
			continue
		formation.append({
			"role": str(entry.get("role", "CM")),
			"position": entry.get("position", Vector2.ZERO),
		})
	if formation.size() != Formation.SLOT_COUNT:
		return -1
	return TacticalSchemes.match_scheme(formation)


func _refresh_role_tiles(panel: Dictionary) -> void:
	for row_index in (panel["role_tiles"] as Array).size():
		var tile: RoleTile = (panel["role_tiles"] as Array)[row_index]
		var role := int(TEAM_ROLE_ROWS[row_index]["role"])
		tile.title = str(TEAM_ROLE_ROWS[row_index]["name"])
		tile.player_name = _role_player_name(panel, role)
		tile.assigned = _role_player_name(panel, role) != "—"
		tile.focused = int(panel["tab"]) == TAB_ROLES and not bool(panel["role_picking"]) \
			and row_index == int(panel["role_cursor"])
		tile.queue_redraw()


func _role_player_name(panel: Dictionary, role: int) -> String:
	var team_id := int(panel["team_id"])
	var team_data: Dictionary = panel.get("team_data", {})
	if mode == "match":
		for entry in team_data.get("roles", []):
			if int(entry.get("role", -1)) == role:
				var name := str(entry.get("name", ""))
				return name if not name.is_empty() else "—"
	elif mode == "demo":
		var roles: Array = team_data.get("roles", [])
		if role >= 0 and role < roles.size():
			var slot := int(roles[role])
			var players: Array = team_data.get("players", [])
			if slot >= 0 and slot < players.size():
				return str(players[slot].get("name", "—"))
	else:
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup != null:
			var slot := lineup.role_slot(role)
			if slot >= 0 and slot < lineup.lineup.size():
				var player := lineup.player_by_id(lineup.lineup[slot])
				if not player.is_empty():
					return str(player.get("lastname", player.get("name", "—")))
	return "—"


func _pending_for_team(team_id: int) -> Array:
	var result: Array = []
	if mode != "match" or runtime == null:
		return result
	if runtime.has_method("get_pending_substitutions"):
		for pair in runtime.get_pending_substitutions():
			if typeof(pair) == TYPE_DICTIONARY and int(pair.get("team", -1)) == team_id:
				result.append(pair)
	return result


func _refresh_tabs(panel: Dictionary) -> void:
	var tabs: UiTabBar = panel["tabs"]
	if tabs != null:
		tabs.select_tab(int(panel["tab"]), false)


func _on_tab_bar_selected(tab: int, team_id: int) -> void:
	_on_tab_pressed(team_id, tab)


func _refresh_hints(panel: Dictionary) -> void:
	var hints: UiHintsBar = panel["hints"]
	if hints == null:
		return
	hints.visible = bool(panel["editable"]) and not bool(panel["ready"])
	if not hints.visible:
		return
	hints.setup(_hints_for(panel))
	var panel_control: Control = panel["control"]
	hints.size = Vector2(panel_control.size.x, hints.size.y)


func _hints_for(panel: Dictionary) -> Array:
	var tab := int(panel["tab"])
	if bool(panel["details_open"]):
		return [{"keys": ["B"], "label": "back"}]
	if tab == TAB_FORMATIONS:
		return [
			{"keys": ["Q/E"], "label": "tabs"},
			{"keys": ["A"], "label": "apply"},
			{"keys": ["B"], "label": "ready"},
		]
	if tab == TAB_ROLES:
		return [
			{"keys": ["Q/E"], "label": "tabs"},
			{"keys": ["A"], "label": "pick"},
			{"keys": ["B"], "label": "ready"},
		]
	return [
		{"keys": ["Q/E"], "label": "tabs"},
		{"keys": ["A"], "label": "select"},
		{"keys": ["Y"], "label": "details"},
		{"keys": ["B"], "label": "ready"},
	]


func _refresh_ready(panel: Dictionary) -> void:
	var overlay: ReadyOverlay = panel["ready_overlay"]
	overlay.visible = bool(panel["ready"])
	overlay.queue_redraw()
	var crest: ReadyOverlay = panel["crest_overlay"]
	crest.visible = _show_crest(panel) and not bool(panel["ready"])
	crest.queue_redraw()
	var hints: UiHintsBar = panel["hints"]
	hints.visible = bool(panel["editable"]) and not bool(panel["ready"])


func _crest_texture(team_id: int) -> Texture2D:
	if mode == "demo":
		return null
	var team: Dictionary = ShellState.home_team if team_id == 0 else ShellState.away_team
	if team.is_empty():
		return null
	return UiAssets.usable_texture(UiAssets.team_logo(team))


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _panel_for_keyboard() -> int:
	for panel in _panels:
		var team_id := int(panel["team_id"])
		for controller in ShellState.controllers:
			if not (controller is Dictionary):
				continue
			if str(controller.get("kind", "keyboard")) == "keyboard" \
					and _side_team(controller) == team_id:
				return _panels.find(panel)
	if _human_teams.size() == 1:
		return _panel_index_for_team(int(_human_teams[0]))
	return -1


func _panel_for_device(device: int) -> int:
	for panel in _panels:
		var team_id := int(panel["team_id"])
		for controller in ShellState.controllers:
			if not (controller is Dictionary):
				continue
			if str(controller.get("kind", "")) == "gamepad" \
					and int(controller.get("device", -1)) == device \
					and _side_team(controller) == team_id:
				return _panels.find(panel)
	if _human_teams.size() == 1:
		return _panel_index_for_team(int(_human_teams[0]))
	return -1


func _side_team(controller: Dictionary) -> int:
	return 1 if str(controller.get("side", "home")) == "away" else 0


func _handle_panel(panel_index: int, direction: Vector2i, accept: bool, back: bool) -> bool:
	if panel_index < 0 or panel_index >= _panels.size():
		return false
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]):
		return false
	if bool(panel["ready"]):
		if back and local_two_player:
			_unready_panel(panel)
			return true
		return true
	if bool(panel["details_open"]):
		if back or accept:
			panel["details_open"] = false
			_refresh_panel(panel)
			_layout()
			return true
		return true

	var tab := int(panel["tab"])
	if tab == TAB_SQUAD:
		if back:
			if int(panel["held"]) != -1:
				panel["held"] = -1
				_refresh_panel(panel)
				set_status("Selection cleared", 1500)
				return true
			_ready_panel(panel)
			return true
		if accept:
			if int(panel["cursor"]) >= 0:
				_press_entry(panel_index, int(panel["cursor"]))
			return true
		if direction != Vector2i.ZERO:
			var next := _navigate_entry(panel, direction)
			if next >= 0:
				panel["cursor"] = next
				_refresh_panel(panel)
				_layout()
				return true
		return false

	if tab == TAB_FORMATIONS:
		if back:
			_ready_panel(panel)
			return true
		if accept:
			_commit_scheme(panel)
			return true
		if direction != Vector2i.ZERO:
			_move_scheme_cursor(panel, direction)
			return true
		return true

	if tab == TAB_ROLES:
		if bool(panel["role_picking"]):
			if back:
				panel["role_picking"] = false
				_refresh_panel(panel)
				return true
			if accept:
				_confirm_role_pick(panel)
				return true
			if direction != Vector2i.ZERO:
				var next := _find_next_entry(panel, int(panel["cursor"]), direction, true)
				if next >= 0:
					panel["cursor"] = next
					_refresh_panel(panel)
				return true
			return true
		if back:
			_ready_panel(panel)
			return true
		if accept:
			_start_role_picking(panel)
			return true
		if direction != Vector2i.ZERO:
			_move_role_cursor(panel, direction)
			return true
		return true
	return false


func _set_section(panel: Dictionary, section: int) -> void:
	# Compatibility hook for the UI lab, which still speaks the old section ids.
	match section:
		0:
			panel["tab"] = TAB_FORMATIONS
		2:
			panel["tab"] = TAB_ROLES
		_:
			panel["tab"] = TAB_SQUAD
	panel["held"] = -1
	panel["role_picking"] = false
	if int(panel["tab"]) == TAB_SQUAD:
		_collapse_drawer(panel)
	_refresh_panel(panel)
	_layout()


func _switch_tab(panel_index: int, delta: int) -> bool:
	if panel_index < 0 or panel_index >= _panels.size():
		return false
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]) or bool(panel["details_open"]):
		return false
	var next := wrapi(int(panel["tab"]) + delta, 0, TAB_NAMES.size())
	panel["tab"] = next
	panel["held"] = -1
	panel["role_picking"] = false
	if next == TAB_FORMATIONS:
		var committed := int(panel["committed_scheme"])
		panel["scheme_cursor"] = committed if committed >= 0 else 0
	elif next == TAB_ROLES:
		panel["role_cursor"] = clampi(int(panel["role_cursor"]), 0, TEAM_ROLE_ROWS.size() - 1)
	else:
		_collapse_drawer(panel)
	_refresh_panel(panel)
	_layout()
	return true


func _toggle_details(panel_index: int) -> bool:
	if panel_index < 0 or panel_index >= _panels.size():
		return false
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]):
		return false
	if int(panel["tab"]) != TAB_SQUAD and not bool(panel["details_open"]):
		return false
	panel["details_open"] = not bool(panel["details_open"])
	_refresh_panel(panel)
	_layout()
	return true


func _on_tab_pressed(team_id: int, tab: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]):
		return
	panel["tab"] = tab
	panel["held"] = -1
	panel["role_picking"] = false
	if tab == TAB_FORMATIONS:
		var committed := _detect_committed_scheme(panel)
		panel["scheme_cursor"] = committed if committed >= 0 else 0
	elif tab == TAB_SQUAD:
		_collapse_drawer(panel)
	_refresh_panel(panel)
	_layout()


func _on_card_clicked(panel_index: int, entry_index: int) -> void:
	if panel_index < 0 or panel_index >= _panels.size():
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]) \
			or int(panel["tab"]) != TAB_SQUAD:
		return
	panel["cursor"] = entry_index
	_press_entry(panel_index, entry_index)


func _on_entry_pressed(team_id: int, entry_index: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]):
		return
	panel["cursor"] = entry_index
	_press_entry(panel_index, entry_index)


func _on_scheme_clicked(event: InputEvent, team_id: int, scheme_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]):
		return
	panel["scheme_cursor"] = scheme_index
	_commit_scheme(panel)


func _on_role_clicked(event: InputEvent, team_id: int, row_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]):
		return
	panel["role_cursor"] = row_index
	_start_role_picking(panel)


func _on_card_hovered(panel_index: int, entry_index: int) -> void:
	_hover_entry(panel_index, entry_index)


func _on_entry_hovered(team_id: int, entry_index: int) -> void:
	_hover_entry(_panel_index_for_team(team_id), entry_index)


func _hover_entry(panel_index: int, entry_index: int) -> void:
	if panel_index < 0 or panel_index >= _panels.size():
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]) or bool(panel["details_open"]):
		return
	var tab := int(panel["tab"])
	if tab != TAB_SQUAD and not (tab == TAB_ROLES and bool(panel["role_picking"])):
		return
	if int(panel["cursor"]) == entry_index:
		return
	panel["cursor"] = entry_index
	_refresh_panel(panel)
	_layout()


func _on_scheme_hovered(team_id: int, scheme_index: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]) or bool(panel["details_open"]):
		return
	if int(panel["tab"]) != TAB_FORMATIONS or int(panel["scheme_cursor"]) == scheme_index:
		return
	panel["scheme_cursor"] = scheme_index
	_refresh_panel(panel)


func _on_role_hovered(team_id: int, row_index: int) -> void:
	var panel_index := _panel_index_for_team(team_id)
	if panel_index < 0:
		return
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]) or bool(panel["details_open"]):
		return
	if int(panel["tab"]) != TAB_ROLES or bool(panel["role_picking"]) \
			or int(panel["role_cursor"]) == row_index:
		return
	panel["role_cursor"] = row_index
	_refresh_panel(panel)


func _press_entry(panel_index: int, entry_index: int) -> void:
	var panel: Dictionary = _panels[panel_index]
	if not bool(panel["editable"]) or bool(panel["ready"]):
		return
	var entries: Array = panel["entries"]
	if entry_index < 0 or entry_index >= entries.size():
		return
	var entry: Dictionary = entries[entry_index]
	if bool(entry.get("left_pitch", false)):
		set_status("%s has already left the pitch" % str(entry.get("name", "")))
		return
	if int(panel["held"]) == -1:
		panel["held"] = entry_index
		_refresh_panel(panel)
		set_status("Selected %s - choose another player - B: cancel" \
			% str(entry.get("name", "")), 60000)
		return
	if int(panel["held"]) == entry_index:
		panel["held"] = -1
		_refresh_panel(panel)
		set_status("Selection cleared", 1500)
		return
	var first_index := int(panel["held"])
	var first: Dictionary = entries[first_index]
	panel["held"] = -1
	if mode == "match":
		var first_group := str(first.get("entry_group", "pitch"))
		var second_group := str(entry.get("entry_group", "pitch"))
		if first_group == "pitch" and second_group == "pitch":
			_match_position_swap(panel, first, entry)
		elif first_group == "bench" and second_group == "bench":
			# A player already queued to come on can be chained out for another
			# bench player: C++ normalises A->B, B->C into A->C (one sub).
			if bool(first.get("pending_in", false)) and not bool(entry.get("pending_in", false)):
				_match_substitution(panel, first, entry)
			elif bool(entry.get("pending_in", false)) and not bool(first.get("pending_in", false)):
				_match_substitution(panel, entry, first)
			else:
				_swap_bench_order(panel, first, entry)
		elif first_group == "pitch" and second_group == "bench":
			_match_substitution(panel, first, entry)
		elif first_group == "bench" and second_group == "pitch":
			_match_substitution(panel, entry, first)
		else:
			set_status("Those players cannot be exchanged")
	else:
		_lineup_swap(panel, first, entry)


func _match_position_swap(panel: Dictionary, first: Dictionary, second: Dictionary) -> void:
	if runtime == null:
		return
	var team_id := int(panel["team_id"])
	var first_db := int(first.get("database_id", -1))
	var second_db := int(second.get("database_id", -1))
	var ok := false
	if network_mode and runtime.has_method("net_action"):
		ok = bool(runtime.net_action("planswap", team_id, first_db, second_db))
	elif runtime.has_method("swap_squad_players"):
		ok = bool(runtime.swap_squad_players(team_id, int(first.get("id", -1)), int(second.get("id", -1))))
	if ok:
		set_status("Swapped positions: %s <-> %s" % [
			str(first.get("name", "")), str(second.get("name", ""))], 4000)
	else:
		set_status("Could not swap those players")
	_refresh_panel(panel)


func _swap_bench_order(panel: Dictionary, first: Dictionary, second: Dictionary) -> void:
	var order: Array = panel["bench_order"]
	if order.is_empty():
		for index in panel["bench_entries"]:
			var entry: Dictionary = (panel["entries"] as Array)[index]
			order.append(int(entry.get("id", -1)))
	var first_position := order.find(int(first.get("id", -1)))
	var second_position := order.find(int(second.get("id", -1)))
	if first_position < 0 or second_position < 0:
		return
	var swap: int = int(order[first_position])
	order[first_position] = order[second_position]
	order[second_position] = swap
	panel["bench_order"] = order
	set_status("Bench order: %s <-> %s" % [
		str(first.get("name", "")), str(second.get("name", ""))], 4000)
	_refresh_panel(panel)


func _match_substitution(panel: Dictionary, out: Dictionary, incoming: Dictionary) -> void:
	if runtime == null:
		return
	var team_id := int(panel["team_id"])
	var out_slot := int(out.get("slot", -1))
	var in_slot := int(incoming.get("slot", -1))
	if _is_pending_pair(panel, out, incoming):
		var cancelled := false
		if network_mode and runtime.has_method("net_action"):
			cancelled = bool(runtime.net_action("cancelsubstitution", team_id, out_slot, 0))
		elif runtime.has_method("cancel_substitution"):
			cancelled = bool(runtime.cancel_substitution(team_id, out_slot))
		if cancelled:
			set_status("Substitution cancelled: %s stays" % str(out.get("name", "")))
		else:
			set_status("Could not cancel the substitution")
		_refresh_panel(panel)
		return
	var queued := false
	if network_mode and runtime.has_method("net_action"):
		queued = bool(runtime.net_action("requestsubstitution", team_id, out_slot, in_slot))
	elif runtime.has_method("queue_substitution"):
		queued = bool(runtime.queue_substitution(team_id,
			int(out.get("id", -1)), int(incoming.get("id", -1))))
	if queued:
		set_status("QUEUED: %s off, %s on - next restart" % [
			str(out.get("name", "")), str(incoming.get("name", ""))], 60000)
	else:
		set_status("Substitution refused: limit reached or player unavailable")
	_refresh_panel(panel)


func _lineup_swap(panel: Dictionary, first: Dictionary, second: Dictionary) -> void:
	var team_id := int(panel["team_id"])
	var lineup: MatchLineup = _lineups.get(team_id)
	if lineup == null:
		return
	var first_id := int(first.get("id", -1))
	var second_id := int(second.get("id", -1))
	if lineup.swap_players(first_id, second_id):
		panel["cursor"] = _find_entry_by_id(panel, second_id)
		if network_mode:
			var net = _network_runtime()
			if net != null:
				net.net_action("planswap", team_id, first_id, second_id)
		lineup_changed.emit()
		_refresh_panel(panel)
		set_status("Lineup updated")
	else:
		set_status(lineup.error if not lineup.error.is_empty() else "Swap failed")
		_refresh_panel(panel)


func _is_pending_pair(panel: Dictionary, out: Dictionary, incoming: Dictionary) -> bool:
	for candidate in panel["pending"]:
		if int(candidate.get("out_id", -2)) == int(out.get("id", -1)) \
				and int(candidate.get("in_id", -2)) == int(incoming.get("id", -1)):
			return true
	return false


func _commit_scheme(panel: Dictionary) -> void:
	var team_id := int(panel["team_id"])
	var scheme_index := int(panel["scheme_cursor"])
	if scheme_index < 0 or scheme_index >= TacticalSchemes.count():
		return
	if mode == "prematch":
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup == null or not lineup.apply_scheme(scheme_index):
			set_status("Could not apply the scheme")
			return
		if network_mode:
			var net = _network_runtime()
			if net != null:
				net.net_action("planscheme", team_id, scheme_index, 0)
		lineup_changed.emit()
	elif mode == "match":
		if runtime == null:
			return
		if network_mode and runtime.has_method("net_action"):
			runtime.net_action("planscheme", team_id, scheme_index, 0)
		else:
			runtime.apply_tactical_scheme(team_id, scheme_index)
	else:
		_apply_demo_scheme(team_id, scheme_index)
	panel["committed_scheme"] = scheme_index
	set_status("%s applied" % TacticalSchemes.scheme_name(scheme_index), 3000)
	_refresh_panel(panel)


func _apply_demo_scheme(team_id: int, scheme_index: int) -> void:
	var team_data: Dictionary = _demo_teams.get(team_id, {})
	var players: Array = team_data.get("players", [])
	var active: Array = []
	for index in players.size():
		if bool(players[index].get("active", false)):
			active.append(index)
	var candidates: Array = []
	for index in active:
		candidates.append({
			"slot": index,
			"role": str(players[index].get("role", "CM")),
			"position": players[index].get("position", Vector2.ZERO),
		})
	var assignment := TacticalSchemes.assign(candidates, scheme_index)
	for offset in mini(assignment.size(), candidates.size()):
		var index := int(candidates[offset]["slot"])
		players[index]["role"] = str(assignment[offset]["role"])
		players[index]["position"] = assignment[offset]["database_position"]


func _move_scheme_cursor(panel: Dictionary, direction: Vector2i) -> void:
	var count := TacticalSchemes.count()
	if count <= 0:
		return
	var cursor := int(panel["scheme_cursor"])
	var columns := 3
	var next := cursor
	if direction.x != 0:
		next = clampi(cursor + direction.x, 0, count - 1)
	elif direction.y > 0:
		next = clampi(cursor + columns, 0, count - 1)
	elif direction.y < 0:
		next = clampi(cursor - columns, 0, count - 1)
	if next == cursor:
		return
	panel["scheme_cursor"] = next
	_refresh_panel(panel)


func _move_role_cursor(panel: Dictionary, direction: Vector2i) -> void:
	var count := TEAM_ROLE_ROWS.size()
	var cursor := int(panel["role_cursor"])
	var columns := 3
	var next := cursor
	if direction.x != 0:
		next = clampi(cursor + direction.x, 0, count - 1)
	elif direction.y > 0:
		next = clampi(cursor + columns, 0, count - 1)
	elif direction.y < 0:
		next = clampi(cursor - columns, 0, count - 1)
	if next == cursor:
		return
	panel["role_cursor"] = next
	_refresh_panel(panel)


func _start_role_picking(panel: Dictionary) -> void:
	panel["role_picking"] = true
	panel["role_picking_index"] = int(panel["role_cursor"])
	var role := int(TEAM_ROLE_ROWS[int(panel["role_picking_index"])]["role"])
	var player_id := _role_player_id(panel, role)
	var target := _find_entry_by_id(panel, player_id)
	if target < 0:
		var pitch_entries: Array = panel["pitch_entries"]
		target = int(pitch_entries[0]) if not pitch_entries.is_empty() else -1
	panel["cursor"] = target
	_refresh_panel(panel)
	set_status("Pick a player for %s - A: assign, B: cancel" % TEAM_ROLE_ROWS[int(panel["role_cursor"])]["name"])


func _confirm_role_pick(panel: Dictionary) -> void:
	if not bool(panel["role_picking"]):
		return
	var entries: Array = panel["entries"]
	var cursor := int(panel["cursor"])
	if cursor < 0 or cursor >= entries.size() or not bool(entries[cursor].get("active", false)):
		set_status("Pick a player on the pitch")
		return
	var role := int(TEAM_ROLE_ROWS[int(panel["role_picking_index"])]["role"])
	var entry: Dictionary = entries[cursor]
	var team_id := int(panel["team_id"])
	if mode == "prematch":
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup == null:
			return
		var slot := lineup.slot_for_player(int(entry.get("id", -1)))
		if slot < 0 or not lineup.set_role(role, slot):
			set_status("Could not assign the role")
			return
		if network_mode:
			var net = _network_runtime()
			if net != null:
				net.net_action("planrole", team_id, role, slot)
		lineup_changed.emit()
	elif mode == "match":
		if runtime == null:
			return
		var slot := int(entry.get("slot", -1))
		if network_mode and runtime.has_method("net_action"):
			runtime.net_action("planrole", team_id, role, slot)
		elif not runtime.set_team_role(team_id, role, slot):
			set_status("Could not assign the role")
			return
	else:
		var team_data: Dictionary = _demo_teams.get(team_id, {})
		var roles: Array = team_data.get("roles", [])
		if role >= 0 and role < roles.size():
			roles[role] = int(entry.get("slot", 0))
	panel["role_picking"] = false
	set_status("%s: %s" % [TEAM_ROLE_ROWS[int(panel["role_picking_index"])]["name"],
		str(entry.get("name", ""))], 3500)
	_refresh_panel(panel)


func _role_player_id(panel: Dictionary, role: int) -> int:
	var team_id := int(panel["team_id"])
	var team_data: Dictionary = panel.get("team_data", {})
	if mode == "match":
		for entry in team_data.get("roles", []):
			if int(entry.get("role", -1)) == role:
				return int(entry.get("player_id", -1))
	elif mode == "demo":
		var roles: Array = team_data.get("roles", [])
		if role >= 0 and role < roles.size():
			var slot := int(roles[role])
			var players: Array = team_data.get("players", [])
			if slot >= 0 and slot < players.size():
				return int(players[slot].get("id", -1))
	else:
		var lineup: MatchLineup = _lineups.get(team_id)
		if lineup != null:
			var slot := lineup.role_slot(role)
			if slot >= 0 and slot < lineup.lineup.size():
				return int(lineup.lineup[slot])
	return -1


# ---------------------------------------------------------------------------
# Ready / close
# ---------------------------------------------------------------------------

func _ready_panel(panel: Dictionary) -> void:
	if not bool(panel["editable"]) or bool(panel["ready"]):
		return
	panel["ready"] = true
	panel["details_open"] = false
	panel["held"] = -1
	ready_changed.emit(int(panel["team_id"]), true)
	_refresh_panel(panel)
	_layout()
	if local_two_player:
		if _all_editable_ready():
			_schedule_close()
	else:
		_schedule_close()


func _unready_panel(panel: Dictionary) -> void:
	if not bool(panel["editable"]) or not bool(panel["ready"]):
		return
	panel["ready"] = false
	ready_changed.emit(int(panel["team_id"]), false)
	_refresh_panel(panel)
	_layout()


func _all_editable_ready() -> bool:
	for panel in _panels:
		if bool(panel["editable"]) and not bool(panel["ready"]):
			return false
	return true


func _schedule_close() -> void:
	_close_at_ms = Time.get_ticks_msec() + READY_HOLD_MS


# ---------------------------------------------------------------------------
# Navigation helpers
# ---------------------------------------------------------------------------

func _navigate_entry(panel: Dictionary, direction: Vector2i) -> int:
	var entries: Array = panel["entries"]
	var cursor := int(panel["cursor"])
	if cursor < 0 or cursor >= entries.size():
		return -1
	var entry: Dictionary = entries[cursor]
	var group := "pitch" if bool(entry.get("active", false)) \
		else str(entry.get("entry_group", "bench"))
	if group == "pitch":
		if direction.y > 0:
			var role := str(entry.get("role", ""))
			if role in ["CB", "LB", "RB", "LWB", "RWB", "SW"]:
				for index in panel["pitch_entries"]:
					var other: Dictionary = entries[int(index)]
					if str(other.get("role", "")) == "GK":
						var from_point := _entry_point(panel, cursor)
						if _entry_point(panel, int(index)).y > from_point.y + 10.0:
							return int(index)
			var below := _forward_entry(panel, cursor, direction, true)
			if below >= 0:
				return below
			var bench_entries: Array = panel["bench_entries"]
			if not bench_entries.is_empty():
				return int(bench_entries[0])
			return -1
		if str(entry.get("role", "")) == "GK" and direction.y < 0:
			var cb := _nearest_role_entry(panel, cursor, ["CB", "SW"])
			if cb >= 0:
				return cb
		return _forward_entry(panel, cursor, direction, true)

	var list: Array = (panel["bench_entries"] as Array).duplicate()
	if bool(panel["drawer_open"]) and mode != "match":
		list.append_array(panel["reserve_entries"])
	var position := list.find(cursor)
	if position < 0:
		return -1
	var columns := 4
	if direction.x != 0:
		var next_column := position + direction.x
		return int(list[next_column]) if next_column >= 0 and next_column < list.size() else -1
	if direction.y > 0:
		var below := position + columns
		return int(list[below]) if below < list.size() else -1
	if position >= columns:
		return int(list[position - columns])
	var gk := _gk_entry(panel)
	return gk if gk >= 0 else _forward_entry(panel, cursor, direction, true)


func _nearest_role_entry(panel: Dictionary, from_index: int, roles: Array) -> int:
	var entries: Array = panel["entries"]
	var points: Dictionary = panel["entry_points"]
	if not points.has(from_index):
		return -1
	var from_point: Vector2 = points[from_index]
	var best := -1
	var best_score := 1e9
	for index in panel["pitch_entries"]:
		var candidate: Dictionary = entries[int(index)]
		if not roles.has(str(candidate.get("role", ""))):
			continue
		var point: Vector2 = points.get(int(index), Vector2.ZERO)
		var score := absf(point.x - from_point.x) + absf(point.y - from_point.y) * 0.25
		if score < best_score:
			best_score = score
			best = int(index)
	return best


func _gk_entry(panel: Dictionary) -> int:
	var entries: Array = panel["entries"]
	for index in panel["pitch_entries"]:
		if str(entries[int(index)].get("role", "")) == "GK":
			return int(index)
	return -1


func _forward_entry(panel: Dictionary, from_index: int, direction: Vector2i,
		pitch_only: bool) -> int:
	var entries: Array = panel["entries"]
	var points: Dictionary = panel["entry_points"]
	if not points.has(from_index) or direction == Vector2i.ZERO:
		return -1
	var from_point: Vector2 = points[from_index]
	var bench_entries: Array = panel["bench_entries"]
	var reserve_entries: Array = panel["reserve_entries"]
	var open := bool(panel["drawer_open"])
	var visible_bench: Array = bench_entries
	if not open and visible_bench.size() > 4:
		visible_bench = visible_bench.slice(0, 4)
	var best := -1
	var best_score := 1e9
	for index in entries.size():
		if index == from_index:
			continue
		var candidate: Dictionary = entries[index]
		if bool(candidate.get("left_pitch", false)):
			continue
		if pitch_only and not bool(candidate.get("active", false)):
			continue
		if not pitch_only and not bool(candidate.get("active", false)):
			if not visible_bench.has(index):
				if not (open and mode != "match" and reserve_entries.has(index)):
					continue
		if not points.has(index):
			continue
		var point: Vector2 = points[index]
		var delta := point - from_point
		var forward := 0.0
		var sideways := 0.0
		if direction.x > 0:
			forward = delta.x
			sideways = absf(delta.y)
		elif direction.x < 0:
			forward = -delta.x
			sideways = absf(delta.y)
		elif direction.y > 0:
			forward = delta.y
			sideways = absf(delta.x)
		else:
			forward = -delta.y
			sideways = absf(delta.x)
		if forward <= 8.0:
			continue
		var weight := 4.0 if direction.x != 0 else 1.8
		var score := forward + sideways * weight
		if score < best_score:
			best_score = score
			best = index
	return best


func _entry_point(panel: Dictionary, index: int) -> Vector2:
	return (panel["entry_points"] as Dictionary).get(index, Vector2.ZERO)


func _find_next_entry(panel: Dictionary, from_index: int, direction: Vector2i,
		pitch_only: bool = false) -> int:
	var entries: Array = panel["entries"]
	if from_index < 0 or from_index >= entries.size() or entries.is_empty():
		return -1
	var points: Dictionary = panel["entry_points"]
	var from_point: Vector2 = points.get(from_index, Vector2.ZERO)
	var dir := Vector2(direction.x, direction.y)
	var best := -1
	var best_score := 1e9
	for index in entries.size():
		if index == from_index:
			continue
		var entry: Dictionary = entries[index]
		if bool(entry.get("left_pitch", false)):
			continue
		if pitch_only and not bool(entry.get("active", false)):
			continue
		var point: Vector2 = points.get(index, Vector2.ZERO)
		var delta := point - from_point
		var along := delta.dot(dir)
		if along <= 1.0:
			continue
		var perp := absf(delta.x * -dir.y + delta.y * dir.x)
		if perp > along * 1.1 + 48.0:
			continue
		var score := along + perp * 0.75
		if score < best_score:
			best_score = score
			best = index
	return best


func _find_entry_by_id(panel: Dictionary, player_id: int) -> int:
	if player_id < 0:
		return -1
	var entries: Array = panel["entries"]
	for index in entries.size():
		if int(entries[index].get("id", -1)) == player_id:
			return index
	return -1


func _panel_index_for_team(team_id: int) -> int:
	for index in _panels.size():
		if int(_panels[index]["team_id"]) == team_id:
			return index
	return -1


func _held_clear() -> void:
	for panel in _panels:
		panel["held"] = -1


func clear_local_orders() -> void:
	for panel in _panels:
		panel["bench_order"] = []


# ---------------------------------------------------------------------------
# Radar / small helpers
# ---------------------------------------------------------------------------

func _radar_values(data: Dictionary) -> Array:
	var stats: Dictionary = data.get("stats", {})
	var values: Array = []
	for axis in RADAR_AXES:
		var keys: Array = axis["keys"]
		var total := 0.0
		var count := 0
		for key in keys:
			if stats.has(key):
				total += float(stats[key])
				count += 1
		values.append(total / float(count) if count > 0 else 0.0)
	return values


func _network_runtime():
	if runtime != null:
		return runtime
	if is_inside_tree():
		return NetShell.runtime(get_tree())
	return null


func _player_display_name(player: Dictionary) -> String:
	var last := str(player.get("lastname", "")).strip_edges()
	if not last.is_empty():
		return last
	var full := str(player.get("name", "")).strip_edges()
	if not full.is_empty():
		return full
	var first := str(player.get("firstname", "")).strip_edges()
	return first if not first.is_empty() else "?"


static func _full_player_name(data: Dictionary) -> String:
	var first := str(data.get("first_name", data.get("firstname", ""))).strip_edges()
	var last := str(data.get("last_name", data.get("lastname", ""))).strip_edges()
	if last.is_empty():
		last = str(data.get("name", "")).strip_edges()
	if first.is_empty():
		return last
	if last.is_empty():
		return first
	if first.to_lower() == last.to_lower():
		return last
	return "%s %s" % [first, last]


func _short_name(value: String) -> String:
	if value.length() <= 15:
		return value
	return value.substr(0, 14) + "."


# Dev/test hook.
func debug_state() -> Dictionary:
	var result: Array = []
	for panel in _panels:
		var entries: Array = panel["entries"]
		var cursor := int(panel["cursor"])
		var held := int(panel["held"])
		result.append({
			"team": int(panel["team_id"]),
			"editable": bool(panel["editable"]),
			"ready": bool(panel["ready"]),
			"tab": int(panel["tab"]),
			"cursor": cursor,
			"cursor_id": int(entries[cursor].get("id", -1)) if cursor >= 0 and cursor < entries.size() else -1,
			"held": held,
			"held_id": int(entries[held].get("id", -1)) if held >= 0 and held < entries.size() else -1,
			"details": bool(panel["details_open"]),
			"bench_entries": (panel["bench_entries"] as Array).size(),
			"reserve_entries": (panel["reserve_entries"] as Array).size(),
		})
	return {"open": is_open(), "panels": result}
