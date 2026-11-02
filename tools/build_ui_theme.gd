extends SceneTree

# Regenerates assets/ui/theme/ui_theme.tres from UiTheme.build().
# Run: godot --headless --path . -s res://tools/build_ui_theme.gd


func _init() -> void:
	var theme := UiTheme.build()
	var error := ResourceSaver.save(theme, UiTheme.THEME_PATH)
	if error != OK:
		push_error("build_ui_theme: save failed: " + str(error))
		quit(1)
		return
	print("build_ui_theme: saved ", UiTheme.THEME_PATH)
	quit(0)
