class_name UiBreadcrumb
extends Control

# Submenu path plate from the prototype: a light strip with a slanted right
# edge, uppercase items and small chevron separators. Width fits its content.

const HEIGHT := 52.0
const PAD_LEFT := 24.0
const PAD_RIGHT := 40.0
const GAP := 16.0
const SEPARATOR := 7.0
const SLANT := 22.0

var _labels: Array[Label] = []
var _separator_centers: Array[float] = []


func set_items(items: Array[String]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_labels.clear()
	_separator_centers.clear()
	visible = not items.is_empty()
	if items.is_empty():
		return

	var x := PAD_LEFT
	for i in items.size():
		var current := i == items.size() - 1
		var font := UiTheme.barlow(800 if current else 600)
		var width := font.get_string_size(
			items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.SIZE_CRUMBS
		).x
		var label := Label.new()
		label.name = "Crumb%d" % i
		label.text = items[i]
		label.theme_type_variation = &"CrumbsCurrent" if current else &"Crumbs"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(x, 0.0)
		label.size = Vector2(width, HEIGHT)
		add_child(label)
		_labels.append(label)
		x += width
		if not current:
			var center := x + GAP + SEPARATOR * 0.5
			_separator_centers.append(center)
			x = center + SEPARATOR * 0.5 + GAP

	size = Vector2(x + PAD_RIGHT, HEIGHT)
	custom_minimum_size = size
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(size.x, 0.0),
		Vector2(size.x - SLANT, size.y),
		Vector2(0.0, size.y),
	])
	draw_colored_polygon(points, UiTokens.CRUMBS_PLATE)
	var color := Color(UiTokens.INK, 0.45)
	for center in _separator_centers:
		var middle := Vector2(center, size.y * 0.5)
		var line := PackedVector2Array([
			middle + Vector2(-3.5, -3.5),
			middle + Vector2(3.5, 0.0),
			middle + Vector2(-3.5, 3.5),
		])
		draw_polyline(line, color, 2.0, true)
