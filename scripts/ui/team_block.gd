class_name TeamBlock
extends Control
# One of the three stacked blocks in a TeamPanel. Draws the prototype gradient
# surface and the focus/ready inversion. The lime cues live in TeamPanel because
# they flank the art, not the block edges.

enum Mode { NORMAL, FOCUS, DARK }

var mode := Mode.NORMAL

var _gradient_texture: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		UiTokens.TEAM_BLOCK_TOP,
		UiTokens.TEAM_BLOCK_BOTTOM,
	])
	_gradient_texture = GradientTexture2D.new()
	_gradient_texture.gradient = gradient
	_gradient_texture.width = 8
	_gradient_texture.height = 256
	_gradient_texture.fill_from = Vector2(0.0, 0.0)
	_gradient_texture.fill_to = Vector2(0.0, 1.0)


func set_mode(value: Mode) -> void:
	if mode == value:
		return
	mode = value
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	match mode:
		Mode.FOCUS:
			draw_rect(Rect2(Vector2.ZERO, size), UiTokens.TEAM_BLOCK_FOCUS)
		Mode.DARK:
			draw_rect(Rect2(Vector2.ZERO, size), UiTokens.TEAM_BLOCK_DARK)
		_:
			if _gradient_texture != null:
				draw_texture_rect(_gradient_texture, Rect2(Vector2.ZERO, size), false)
