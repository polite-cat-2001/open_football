class_name UiHintsBar
extends VBoxContainer
# Shared bottom block for every shell screen: a reserved status line and the
# control-hints legend. Screens position it with UiTokens.HINTS_GAP below their
# content; never build a local legend or use a per-screen top gap.

var status_label: Label
var legend: UiLegend


func _ready() -> void:
	_bind()


# Headless pause tests build and open the screen before this node's _ready
# runs, so every entry point binds its children on demand.
func _bind() -> void:
	if status_label != null:
		return
	status_label = $Status
	legend = $Legend
	add_theme_constant_override(&"separation", int(UiTokens.HINTS_STATUS_GAP))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.custom_minimum_size.y = UiTokens.HINTS_STATUS_H
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.custom_minimum_size.y = UiTokens.HINTS_LEGEND_H


func setup(hints: Array) -> void:
	_bind()
	legend.setup(hints)


func set_status(text: String, error := false) -> void:
	_bind()
	status_label.text = text
	status_label.theme_type_variation = &"SideStatusError" if error else &"SideStatus"


func status_text() -> String:
	_bind()
	return status_label.text


func height() -> float:
	_bind()
	var legend_height := maxf(UiTokens.HINTS_LEGEND_H, legend.get_combined_minimum_size().y)
	return UiTokens.HINTS_STATUS_H + UiTokens.HINTS_STATUS_GAP + legend_height
