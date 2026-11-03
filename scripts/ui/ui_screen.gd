class_name UiScreen
extends Control
# Base for menus built on the shared static stage. Subclasses own their content
# (Design/PanelWrap); layout_canvas() places the stage and applies the uniform
# 1920x1080 design scale. UiTransition only animates the node in
# "ui_transition_target", which is the content panel — the stage never moves.

@onready var stage: UiStage = $Stage
@onready var design: Control = $Design


func layout_canvas() -> float:
	if not is_inside_tree():
		return 1.0
	var view_size := get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return 1.0
	if stage != null:
		stage.layout(view_size)
	var design_scale := minf(
		view_size.x / UiTokens.DESIGN_SIZE.x,
		view_size.y / UiTokens.DESIGN_SIZE.y
	)
	design.scale = Vector2(design_scale, design_scale)
	design.position = (view_size - UiTokens.DESIGN_SIZE * design_scale) * 0.5
	design.size = UiTokens.DESIGN_SIZE
	design.pivot_offset = Vector2.ZERO
	return design_scale
