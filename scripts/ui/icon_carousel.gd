class_name UiIconCarousel
extends Control
# Godot port of Gui2IconSelector: icons laid out on a shallow arc around the
# selected entry, title at the top, selected name at the bottom. Input is driven
# by the parent (TeamSelect) so two panels can run in parallel.

const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const MAX_VISIBLE_OFFSET := 1.5708 # pi / 2

var title := ""
var entries: Array = []
var selected := 0
var highlighted := false
var dimmed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_entries(new_entries: Array, keep_selection: bool = false) -> void:
	entries = new_entries
	if not keep_selection:
		selected = 0
	selected = clampi(selected, 0, maxi(0, entries.size() - 1))
	queue_redraw()


func set_selected(index: int) -> void:
	if entries.is_empty():
		selected = 0
	else:
		selected = clampi(index, 0, entries.size() - 1)
	queue_redraw()


func move_selection(delta: int) -> bool:
	if entries.is_empty() or delta == 0:
		return false
	var next := clampi(selected + delta, 0, entries.size() - 1)
	if next == selected:
		return false
	selected = next
	queue_redraw()
	return true


func selected_entry() -> Dictionary:
	if entries.is_empty() or selected < 0 or selected >= entries.size():
		return {}
	return entries[selected]


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	queue_redraw()


func set_dimmed(value: bool) -> void:
	if dimmed == value:
		return
	dimmed = value
	queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var alpha := 0.42 if dimmed else (0.85 if highlighted else 0.58)
	draw_rect(box, Color(0.02, 0.02, 0.02, alpha))
	if highlighted:
		draw_rect(box.grow(-1.0), Color(1.0, 0.84, 0.28, 0.9), false, 2.0)

	var title_size := maxi(10, int(size.y * 0.15))
	draw_string(MENU_FONT, Vector2(6.0, size.y * 0.16), title,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 6.0, title_size,
		Color(0.78, 0.78, 0.70, 0.9))

	if entries.is_empty():
		draw_string(MENU_FONT, Vector2(0.0, size.y * 0.62), "None selected",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, Color(0.6, 0.6, 0.55))
		return

	var max_height := size.y * 0.55
	var max_width := size.x * 0.22
	var icon_unit := minf(max_width, max_height / 1.25)
	var center := Vector2(size.x * 0.5, size.y * 0.50)
	for i in range(maxi(0, selected - 4), mini(entries.size(), selected + 5)):
		var offset := float(i - selected)
		if absf(offset) >= MAX_VISIBLE_OFFSET:
			continue
		var scale := cos(offset)
		var width := icon_unit * scale
		var height := width * 1.25
		var x := center.x + sin(offset) * size.x * 0.38 - width * 0.5
		var y := center.y - height * 0.5
		var rect := Rect2(Vector2(x, y), Vector2(width, height))
		var entry: Dictionary = entries[i]
		var texture: Texture2D = entry.get("texture", null)
		var tint := Color(1, 1, 1, 0.45 if dimmed else (1.0 if offset == 0.0 else 0.8))
		if texture != null:
			draw_texture_rect(texture, rect, false, tint)
		else:
			draw_rect(rect, Color(0.85, 0.42, 0.08, 0.75 * tint.a))
		if i == selected:
			draw_rect(rect.grow(2.0), Color(1.0, 0.84, 0.28, 0.95), false, 2.0)

	var name_size := maxi(10, int(size.y * 0.17))
	var name := str(selected_entry().get("caption", ""))
	draw_string(MENU_FONT, Vector2(0.0, size.y * 0.88), name,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, name_size,
		Color(1.0, 0.96, 0.80, 1.0 if highlighted else 0.9))
