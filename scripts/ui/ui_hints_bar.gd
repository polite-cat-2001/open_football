class_name UiHintsBar
extends VBoxContainer
# Shared bottom block for every shell screen: a reserved status line and the
# control-hints legend. Screens position it with UiTokens.HINTS_GAP below their
# content; never build a local legend or use a per-screen top gap.

@onready var status_label: Label = $Status
@onready var legend: UiLegend = $Legend


func _ready() -> void:
	add_theme_constant_override(&"separation", int(UiTokens.HINTS_STATUS_GAP))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.custom_minimum_size.y = UiTokens.HINTS_STATUS_H
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.custom_minimum_size.y = UiTokens.HINTS_LEGEND_H


func setup(hints: Array) -> void:
	legend.setup(hints)


func set_status(text: String, error := false) -> void:
	status_label.text = text
	status_label.theme_type_variation = &"SideStatusError" if error else &"SideStatus"


func status_text() -> String:
	return status_label.text


func height() -> float:
	var legend_height := maxf(UiTokens.HINTS_LEGEND_H, legend.get_combined_minimum_size().y)
	return UiTokens.HINTS_STATUS_H + UiTokens.HINTS_STATUS_GAP + legend_height
