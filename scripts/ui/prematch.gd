extends Control
# Godot port of PreMatchPage (GameplayFootball src/menu/startmatch/prematch.cpp):
# a PES-style tab strip over the match hub. The tabs keep the original names and
# layout; the shell fills the ones it can back with data (kit preview, kick-off
# lineups/start, options). The lineups editor is opened as an overlay so the
# original Kick-off list stays readable.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"
const MATCH_SCENE := "res://scenes/gpf_slice.tscn"
const MENU_FONT := preload("res://assets/ui/fonts/AlegreyaSansSC-ExtraBold.ttf")
const UI_ASSETS := preload("res://scripts/data/ui_assets.gd")

const TAB_NAMES := ["Kit", "Stadium", "Kick-off", "Game plan", "Options", "Camera", "System"]
const KICKOFF_TAB := 2
const KIT_COUNT := 6
const SLOT_COUNT := 11

@export var data_root := ""

var catalog := TeamCatalog.new()
var package_builder := MatchPackage.new()

var header_label: Label
var status_label: Label
var help_label: Label
var tab_strip: HBoxContainer
var tab_buttons: Array = []
var content_root: Control
var content_views: Array = []
var active_tab := KICKOFF_TAB

var home_editor: LineupEditor
var away_editor: LineupEditor
var editor_tabs: TabContainer
var lineup_overlay: Control
var lineup_close_button: Button
var start_button: Button
var edit_lineups_button: Button

var home_name_labels: Array = []
var away_name_labels: Array = []

var difficulty_slider: HSlider
var duration_slider: HSlider
var difficulty_value: Label
var duration_value: Label

var kit_options: Array = []
var kit_previews: Array = []
var kit_colors: Array = []

var _tab_group := ButtonGroup.new()
var _kits_ready := false


func _ready() -> void:
	_build_ui()
	_build_lineup_overlay()
	catalog.load_data_root(data_root)
	_load_lineups()
	_select_tab(KICKOFF_TAB)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.035, 0.03)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	header_label = _label("", 28, Color(0.96, 0.93, 0.82))
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	tab_strip = HBoxContainer.new()
	tab_strip.add_theme_constant_override("separation", 2)
	add_child(tab_strip)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = TAB_NAMES[i]
		button.toggle_mode = true
		button.button_group = _tab_group
		button.add_theme_font_override("font", MENU_FONT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_tab_pressed.bind(i))
		button.focus_entered.connect(_on_tab_focus.bind(i))
		tab_strip.add_child(button)
		tab_buttons.append(button)

	content_root = Control.new()
	add_child(content_root)
	_build_contents()

	status_label = _label("", 20, Color(1.0, 0.45, 0.4))
	help_label = _label("Tab/Arrows: navigate    Enter: select    Esc: back", 17, Color(0.68, 0.68, 0.62))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _build_contents() -> void:
	content_views = [
		_build_kit_view(),
		_build_stadium_view(),
		_build_kickoff_view(),
		_build_gameplan_view(),
		_build_options_view(),
		_build_camera_view(),
		_build_system_view(),
	]
	for view in content_views:
		content_root.add_child(view)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _view() -> Control:
	var view := Control.new()
	view.visible = false
	return view


func _build_kit_view() -> Control:
	var view := _view()
	var margin := _margin(12)
	view.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var blocks := HBoxContainer.new()
	blocks.add_theme_constant_override("separation", 30)
	blocks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(blocks)
	for side in 2:
		var block := VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_theme_constant_override("separation", 8)
		blocks.add_child(block)

		var caption := Label.new()
		caption.text = "Home kit" if side == 0 else "Away kit"
		caption.add_theme_font_override("font", MENU_FONT)
		caption.add_theme_font_size_override("font_size", 24)
		caption.add_theme_color_override("font_color", Color(0.82, 0.84, 0.74))
		block.add_child(caption)

		var option := OptionButton.new()
		option.add_theme_font_override("font", MENU_FONT)
		option.add_theme_font_size_override("font_size", 20)
		option.custom_minimum_size = Vector2(240, 44)
		option.item_selected.connect(_on_kit_changed.bind(side))
		block.add_child(option)
		kit_options.append(option)

		var preview := Control.new()
		preview.custom_minimum_size = Vector2(220, 220)
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		block.add_child(preview)
		var color_rect := ColorRect.new()
		color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.add_child(color_rect)
		var texture_rect := TextureRect.new()
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.add_child(texture_rect)
		kit_previews.append(texture_rect)
		kit_colors.append(color_rect)

	var info := Label.new()
	info.text = "Pick the strip for each side. The current build renders team colours, not kit art."
	info.add_theme_font_override("font", MENU_FONT)
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.68, 0.68, 0.62))
	column.add_child(info)
	return view


func _build_stadium_view() -> Control:
	var view := _view()
	var margin := _margin(24)
	view.add_child(margin)
	var label := Label.new()
	label.text = "Venue: default stadium. Weather: randomized at kick-off."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.72))
	margin.add_child(label)
	return view


func _build_kickoff_view() -> Control:
	var view := _view()
	var margin := _margin(10)
	view.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 30)
	names.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(names)
	for side in 2:
		var side_column := VBoxContainer.new()
		side_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side_column.add_theme_constant_override("separation", 2)
		names.add_child(side_column)
		var caption := Label.new()
		caption.text = "Home" if side == 0 else "Away"
		caption.add_theme_font_override("font", MENU_FONT)
		caption.add_theme_font_size_override("font_size", 22)
		caption.add_theme_color_override("font_color", Color(0.82, 0.84, 0.74))
		side_column.add_child(caption)
		var labels: Array = []
		for slot in SLOT_COUNT:
			var label := Label.new()
			label.text = "-"
			label.add_theme_font_override("font", MENU_FONT)
			label.add_theme_font_size_override("font_size", 17)
			label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.86))
			side_column.add_child(label)
			labels.append(label)
		if side == 0:
			home_name_labels = labels
		else:
			away_name_labels = labels

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	column.add_child(buttons)
	edit_lineups_button = Button.new()
	edit_lineups_button.text = "Edit lineups"
	edit_lineups_button.add_theme_font_override("font", MENU_FONT)
	edit_lineups_button.add_theme_font_size_override("font_size", 22)
	edit_lineups_button.pressed.connect(_open_lineups)
	buttons.add_child(edit_lineups_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	start_button = Button.new()
	start_button.text = "Start match"
	start_button.add_theme_font_override("font", MENU_FONT)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.custom_minimum_size = Vector2(260, 52)
	start_button.pressed.connect(_on_start)
	buttons.add_child(start_button)
	return view


func _build_gameplan_view() -> Control:
	return _placeholder_view("Open game plan", "Game plan is not ported yet.")


func _build_camera_view() -> Control:
	return _placeholder_view("Camera settings", "Camera settings are not ported yet.")


func _build_system_view() -> Control:
	return _placeholder_view("System settings", "System settings are not ported yet.")


func _placeholder_view(button_text: String, note_text: String) -> Control:
	var view := _view()
	var margin := _margin(24)
	view.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)
	var button := Button.new()
	button.text = button_text
	button.disabled = true
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.custom_minimum_size = Vector2(320, 56)
	column.add_child(button)
	var note := Label.new()
	note.text = note_text
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", MENU_FONT)
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.6))
	column.add_child(note)
	return view


func _build_options_view() -> Control:
	var view := _view()
	var margin := _margin(24)
	view.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var difficulty := float(ShellState.match_options.get("difficulty", 0.8))
	var duration := float(ShellState.match_options.get("duration", 1.0))

	var difficulty_row := HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 14)
	column.add_child(difficulty_row)
	var difficulty_caption := _option_caption("difficulty (when HUMAN vs CPU)")
	difficulty_row.add_child(difficulty_caption)
	difficulty_slider = _slider(0.6, 1.0, 0.2, difficulty)
	difficulty_slider.value_changed.connect(_on_difficulty_changed)
	difficulty_row.add_child(difficulty_slider)
	difficulty_value = _option_value("%.2f" % difficulty)
	difficulty_row.add_child(difficulty_value)

	var duration_row := HBoxContainer.new()
	duration_row.add_theme_constant_override("separation", 14)
	column.add_child(duration_row)
	var duration_caption := _option_caption("match duration (5 .. 25 min.)")
	duration_row.add_child(duration_caption)
	duration_slider = _slider(0.5, 1.5, 0.5, duration)
	duration_slider.value_changed.connect(_on_duration_changed)
	duration_row.add_child(duration_slider)
	duration_value = _option_value("")
	duration_row.add_child(duration_value)
	_update_duration_value()

	var subs := Label.new()
	subs.text = "substitutions per match: 5"
	subs.add_theme_font_override("font", MENU_FONT)
	subs.add_theme_font_size_override("font_size", 18)
	subs.add_theme_color_override("font_color", Color(0.68, 0.68, 0.62))
	column.add_child(subs)
	return view


func _option_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.74))
	label.custom_minimum_size = Vector2(300, 40)
	return label


func _option_value(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	label.custom_minimum_size = Vector2(120, 40)
	return label


func _slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(360, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slider


func _margin(horizontal: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	return margin


func _build_lineup_overlay() -> void:
	lineup_overlay = Control.new()
	lineup_overlay.visible = false
	add_child(lineup_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lineup_overlay.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	lineup_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var caption := Label.new()
	caption.text = "Lineups"
	caption.add_theme_font_override("font", MENU_FONT)
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_color", Color(0.94, 0.92, 0.82))
	column.add_child(caption)
	editor_tabs = TabContainer.new()
	editor_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(editor_tabs)
	lineup_close_button = Button.new()
	lineup_close_button.text = "Back to hub"
	lineup_close_button.add_theme_font_override("font", MENU_FONT)
	lineup_close_button.add_theme_font_size_override("font_size", 22)
	lineup_close_button.custom_minimum_size = Vector2(240, 48)
	lineup_close_button.pressed.connect(_close_lineups)
	column.add_child(lineup_close_button)


func _load_lineups() -> void:
	if not ShellState.has_selection():
		status_label.text = "Choose two teams first."
		start_button.disabled = true
		return
	var home_squad := catalog.load_squad(int(ShellState.home_team.get("id", 0)))
	var away_squad := catalog.load_squad(int(ShellState.away_team.get("id", 0)))
	if home_squad.is_empty() or away_squad.is_empty():
		status_label.text = catalog.error if not catalog.error.is_empty() else "Squad could not be loaded."
		start_button.disabled = true
		return
	home_editor = _build_editor("Home", home_squad)
	away_editor = _build_editor("Away", away_squad)
	header_label.text = "%s  vs  %s" % [
		str(ShellState.home_team.get("name", "Home")),
		str(ShellState.away_team.get("name", "Away")),
	]
	_build_kits()
	_refresh_names()
	_validate_lineups()


func _build_editor(tab_name: String, squad: Dictionary) -> LineupEditor:
	var editor := LineupEditor.new()
	editor.name = tab_name
	editor.setup(squad)
	editor.changed.connect(_on_lineups_changed)
	editor_tabs.add_child(editor)
	return editor


func _build_kits() -> void:
	if _kits_ready:
		return
	_kits_ready = true
	for side in 2:
		var team: Dictionary = ShellState.home_team if side == 0 else ShellState.away_team
		var option: OptionButton = kit_options[side]
		var kits := _available_kits(team)
		option.clear()
		for kit in kits:
			option.add_item("Kit %02d" % kit)
			option.set_item_metadata(option.item_count - 1, kit)
		var selected := int(ShellState.match_options.get("kit_home" if side == 0 else "kit_away",
			1 if side == 0 else 2))
		var index := kits.find(selected)
		option.select(maxi(0, index))
		_refresh_kit_preview(side)


func _available_kits(team: Dictionary) -> Array:
	var kits: Array = []
	var url := str(team.get("kit_url", ""))
	if not url.is_empty():
		for kit in range(1, KIT_COUNT + 1):
			var path := UI_ASSETS.data_root().path_join(
				"databases/default/%s_kit_%02d.png" % [url, kit])
			if FileAccess.file_exists(path):
				kits.append(kit)
	if kits.is_empty():
		kits = [1, 2]
	return kits


func _refresh_kit_preview(side: int) -> void:
	var team: Dictionary = ShellState.home_team if side == 0 else ShellState.away_team
	var option: OptionButton = kit_options[side]
	var kit := int(option.get_item_metadata(maxi(0, option.selected)))
	var texture_rect: TextureRect = kit_previews[side]
	var color_rect: ColorRect = kit_colors[side]
	var texture := UI_ASSETS.kit_texture(team, kit)
	texture_rect.texture = texture
	texture_rect.visible = texture != null
	color_rect.visible = texture == null
	if texture == null:
		color_rect.color = _team_color(team)


func _team_color(team: Dictionary) -> Color:
	var raw := str(team.get("color1", ""))
	if raw.is_empty():
		return Color(0.35, 0.45, 0.35)
	return Color.from_string(raw, Color(0.35, 0.45, 0.35))


func _on_kit_changed(index: int, side: int) -> void:
	_refresh_kit_preview(side)
	_store_options()


func _on_difficulty_changed(value: float) -> void:
	difficulty_value.text = "%.2f" % value
	_store_options()


func _on_duration_changed(_value: float) -> void:
	_update_duration_value()
	_store_options()


func _update_duration_value() -> void:
	if duration_slider == null or duration_value == null:
		return
	var minutes := 5 + int(round(20.0 * duration_slider.value))
	duration_value.text = "~%d min" % minutes


func _store_options() -> void:
	if difficulty_slider == null or duration_slider == null:
		return
	var home_kit := 1
	var away_kit := 2
	if kit_options.size() == 2:
		home_kit = int(kit_options[0].get_item_metadata(maxi(0, kit_options[0].selected)))
		away_kit = int(kit_options[1].get_item_metadata(maxi(0, kit_options[1].selected)))
	ShellState.set_match_options({
		"duration": duration_slider.value,
		"difficulty": difficulty_slider.value,
		"kit_home": home_kit,
		"kit_away": away_kit,
	})


func _refresh_names() -> void:
	_update_name_column(home_editor, home_name_labels)
	_update_name_column(away_editor, away_name_labels)


func _update_name_column(editor: LineupEditor, labels: Array) -> void:
	for slot in labels.size():
		var label: Label = labels[slot]
		if editor == null or editor.lineup == null or slot >= editor.lineup.lineup.size():
			label.text = "-"
			continue
		var player := editor.lineup.player_by_id(editor.lineup.lineup[slot])
		var last := str(player.get("lastname", ""))
		label.text = "%d. %s" % [slot + 1, last if not last.is_empty() else str(player.get("firstname", "?"))]


func _on_lineups_changed() -> void:
	_refresh_names()
	_validate_lineups()


func _validate_lineups() -> void:
	if home_editor == null or away_editor == null:
		start_button.disabled = true
		return
	var message := home_editor.validation_error()
	if message.is_empty():
		message = away_editor.validation_error()
	if not message.is_empty():
		status_label.text = message
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		start_button.disabled = true
		return
	var warning := home_editor.warning()
	if warning.is_empty():
		warning = away_editor.warning()
	if not warning.is_empty():
		status_label.text = warning
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	else:
		status_label.text = ""
	start_button.disabled = false


func build_package() -> Dictionary:
	package_builder.error = ""
	if not ShellState.has_selection():
		package_builder.error = "Choose two teams first."
		return {}
	if home_editor == null or away_editor == null:
		package_builder.error = "Lineups are not loaded."
		return {}
	var lineup_error := home_editor.validation_error()
	if lineup_error.is_empty():
		lineup_error = away_editor.validation_error()
	if not lineup_error.is_empty():
		package_builder.error = lineup_error
		return {}
	if not catalog.load_data_root(data_root):
		package_builder.error = catalog.error
		return {}
	_store_options()
	var options := {
		"duration": float(ShellState.match_options.get("duration", 1.0)),
		"difficulty": float(ShellState.match_options.get("difficulty", 0.8)),
	}
	var lineups := {"home": home_editor.lineup, "away": away_editor.lineup}
	var package := package_builder.build(catalog, ShellState.home_team, ShellState.away_team,
		options, lineups)
	if package.is_empty():
		package_builder.error = package_builder.error if not package_builder.error.is_empty() \
			else "Match package could not be built."
		return {}
	ShellState.set_match_package(package)
	return package


func _on_start() -> void:
	var package := build_package()
	if package.is_empty():
		status_label.text = package_builder.error
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		return
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_back() -> void:
	get_tree().change_scene_to_file(TEAM_SELECT_SCENE)


func _open_lineups() -> void:
	if home_editor == null or away_editor == null:
		return
	lineup_overlay.visible = true
	lineup_overlay.move_to_front()
	editor_tabs.current_tab = 0


func _close_lineups() -> void:
	lineup_overlay.visible = false
	_refresh_names()
	_validate_lineups()


func _on_tab_pressed(index: int) -> void:
	_select_tab(index, true)


func _on_tab_focus(index: int) -> void:
	if active_tab != index:
		_select_tab(index, false)


func _select_tab(index: int, focus_content: bool = false) -> void:
	if index < 0 or index >= content_views.size():
		return
	active_tab = index
	for i in tab_buttons.size():
		tab_buttons[i].button_pressed = i == index
	for i in content_views.size():
		content_views[i].visible = i == index
	if focus_content:
		_focus_first_content()


func _focus_first_content() -> void:
	var focusable := _first_focusable(content_views[active_tab])
	if focusable != null:
		focusable.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.visible and not control.disabled and control.focus_mode != Control.FOCUS_NONE:
				return control
		var nested := _first_focusable(child)
		if nested != null:
			return nested
	return null


func _input(event: InputEvent) -> void:
	if lineup_overlay != null and lineup_overlay.visible:
		if event is InputEventKey and (event as InputEventKey).pressed \
				and (event as InputEventKey).keycode == KEY_ESCAPE:
			_close_lineups()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		_handle_key(event as InputEventKey)
	elif event is InputEventJoypadButton:
		_handle_joy_button(event as InputEventJoypadButton)


func _handle_key(event: InputEventKey) -> void:
	if event.echo or not event.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var on_tab := focus != null and tab_buttons.has(focus)
	match event.keycode:
		KEY_ESCAPE:
			if on_tab or focus == null:
				_on_back()
			else:
				tab_buttons[active_tab].grab_focus()
		KEY_LEFT:
			if on_tab:
				var index := (active_tab - 1 + tab_buttons.size()) % tab_buttons.size()
				_select_tab(index, false)
				tab_buttons[index].grab_focus()
		KEY_RIGHT:
			if on_tab:
				var index := (active_tab + 1) % tab_buttons.size()
				_select_tab(index, false)
				tab_buttons[index].grab_focus()
		KEY_DOWN:
			if on_tab:
				_focus_first_content()
		KEY_UP:
			if not on_tab and focus != null:
				tab_buttons[active_tab].grab_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if on_tab:
				_select_tab(active_tab, true)


func _handle_joy_button(event: InputEventJoypadButton) -> void:
	if not event.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var on_tab := focus != null and tab_buttons.has(focus)
	match int(event.button_index):
		JOY_BUTTON_DPAD_LEFT:
			if on_tab:
				var index := (active_tab - 1 + tab_buttons.size()) % tab_buttons.size()
				_select_tab(index, false)
				tab_buttons[index].grab_focus()
		JOY_BUTTON_DPAD_RIGHT:
			if on_tab:
				var index := (active_tab + 1) % tab_buttons.size()
				_select_tab(index, false)
				tab_buttons[index].grab_focus()
		JOY_BUTTON_DPAD_DOWN:
			if on_tab:
				_focus_first_content()
		JOY_BUTTON_DPAD_UP:
			if not on_tab and focus != null:
				tab_buttons[active_tab].grab_focus()
		JOY_BUTTON_A:
			if on_tab:
				_select_tab(active_tab, true)
			elif focus is Button and not (focus as Button).disabled:
				(focus as Button).pressed.emit()
		JOY_BUTTON_B:
			if on_tab or focus == null:
				_on_back()
			else:
				tab_buttons[active_tab].grab_focus()


func _layout() -> void:
	var view := get_viewport_rect().size
	var header_size := maxi(18, int(view.y * 0.030))
	header_label.add_theme_font_size_override("font_size", header_size)
	header_label.position = Vector2(0, view.y * 0.055)
	header_label.size = Vector2(view.x, view.y * 0.05)

	tab_strip.position = Vector2(view.x * 0.05, view.y * 0.145)
	tab_strip.size = Vector2(view.x * 0.90, view.y * 0.045)
	var tab_font := maxi(12, int(view.y * 0.021))
	for button in tab_buttons:
		button.add_theme_font_size_override("font_size", tab_font)

	content_root.position = Vector2(view.x * 0.20, view.y * 0.24)
	content_root.size = Vector2(view.x * 0.60, view.y * 0.58)

	status_label.add_theme_font_size_override("font_size", maxi(12, int(view.y * 0.019)))
	status_label.position = Vector2(view.x * 0.20, view.y * 0.835)
	status_label.size = Vector2(view.x * 0.60, view.y * 0.035)
	help_label.add_theme_font_size_override("font_size", maxi(11, int(view.y * 0.017)))
	help_label.position = Vector2(view.x * 0.20, view.y * 0.885)
	help_label.size = Vector2(view.x * 0.60, view.y * 0.03)
