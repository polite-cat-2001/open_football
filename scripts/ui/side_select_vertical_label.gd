class_name SideSelectVerticalLabel
extends Control

@export var text := "":
	set(value):
		text = value
		queue_redraw()

@export var upward := true:
	set(value):
		upward = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	theme_changed.connect(queue_redraw)


func _draw() -> void:
	if text.is_empty():
		return
	var font := get_theme_font(&"font", &"SideName")
	if font == null:
		return
	var font_size := get_theme_font_size(&"font_size", &"SideName")
	var color := get_theme_color(&"font_color", &"SideName")
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var angle := -PI * 0.5 if upward else PI * 0.5
	draw_set_transform(size * 0.5, angle, Vector2.ONE)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, (ascent - descent) * 0.5),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
