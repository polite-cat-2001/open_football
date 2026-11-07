class_name UiLegend
extends HBoxContainer

# Bottom control legend. Hints are plain data so the same component can show
# the keyboard or gamepad set when the input router switches devices.

const KEY_MIN_WIDTH := 26.0


func setup(hints: Array) -> void:
	for child in get_children():
		# Immediate free so a container's minimum width updates in the same
		# layout pass (half-width hints bars depend on shrinking between states).
		child.free()
	add_theme_constant_override(&"separation", 24)
	for hint in hints:
		var group := HBoxContainer.new()
		group.add_theme_constant_override(&"separation", 8)
		for key in hint.get("keys", []):
			var box := PanelContainer.new()
			box.theme_type_variation = &"KbdBox"
			box.custom_minimum_size.x = KEY_MIN_WIDTH
			var label := Label.new()
			label.theme_type_variation = &"Kbd"
			label.text = String(key)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(label)
			group.add_child(box)
		var text := Label.new()
		text.theme_type_variation = &"LegendLabel"
		text.text = String(hint.get("label", ""))
		group.add_child(text)
		add_child(group)
