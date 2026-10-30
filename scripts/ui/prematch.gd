extends Control
# Minimal prematch: confirms the two chosen teams, lets the player pick match
# length and difficulty, then builds the match package the C++ runtime consumes.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"
const MATCH_SCENE := "res://scenes/gpf_slice.tscn"

const DURATIONS := [
	{"label": "Short", "value": 0.5},
	{"label": "Normal", "value": 1.0},
	{"label": "Long", "value": 1.5},
]
const DIFFICULTIES := [
	{"label": "Easy", "value": 0.6},
	{"label": "Normal", "value": 0.8},
	{"label": "Hard", "value": 1.0},
]
const DEFAULT_DURATION := 1
const DEFAULT_DIFFICULTY := 1

@export var data_root := ""

var catalog := TeamCatalog.new()
var package_builder := MatchPackage.new()

var home_label: Label
var away_label: Label
var duration_option: OptionButton
var difficulty_option: OptionButton
var status_label: Label
var start_button: Button
var back_button: Button


func _ready() -> void:
	_build_ui()
	# Loaded for the league captions; a missing database is reported on kickoff.
	catalog.load_data_root(data_root)
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.06)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 110)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Pre-Match"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose the match length and difficulty, then kick off."
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
	column.add_child(subtitle)

	column.add_child(HSeparator.new())

	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 40)
	column.add_child(teams)
	teams.add_child(_team_block("Home", true))
	teams.add_child(_team_block("Away", false))

	column.add_child(HSeparator.new())

	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 60)
	column.add_child(settings)
	settings.add_child(_setting_block("Match length", true))
	settings.add_child(_setting_block("Difficulty", false))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	column.add_child(status_label)

	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	back_button = _button("Back", 24)
	back_button.name = "BackBtn"
	back_button.custom_minimum_size = Vector2(200, 60)
	back_button.pressed.connect(_on_back)
	bottom.add_child(back_button)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)
	start_button = _button("Kick Off", 24)
	start_button.name = "StartBtn"
	start_button.custom_minimum_size = Vector2(260, 60)
	start_button.pressed.connect(_on_start)
	bottom.add_child(start_button)


func _team_block(header: String, home: bool) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 8)
	var caption := Label.new()
	caption.text = header
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	block.add_child(caption)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	label.text = "not selected"
	block.add_child(label)
	if home:
		home_label = label
	else:
		away_label = label
	return block


func _setting_block(caption_text: String, duration: bool) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 8)
	var caption := Label.new()
	caption.text = caption_text
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	block.add_child(caption)
	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", 22)
	option.custom_minimum_size = Vector2(260, 52)
	block.add_child(option)
	if duration:
		duration_option = option
		option.name = "DurationOption"
		for index in DURATIONS.size():
			option.add_item(str(DURATIONS[index]["label"]))
			option.set_item_metadata(index, float(DURATIONS[index]["value"]))
		option.select(DEFAULT_DURATION)
		option.item_selected.connect(_on_option_changed)
	else:
		difficulty_option = option
		option.name = "DifficultyOption"
		for index in DIFFICULTIES.size():
			option.add_item(str(DIFFICULTIES[index]["label"]))
			option.set_item_metadata(index, float(DIFFICULTIES[index]["value"]))
		option.select(DEFAULT_DIFFICULTY)
		option.item_selected.connect(_on_option_changed)
	return block


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	return button


func _refresh() -> void:
	if not ShellState.has_selection():
		home_label.text = "not selected"
		away_label.text = "not selected"
		status_label.text = "Choose two teams first."
		start_button.disabled = true
		return
	home_label.text = _describe(ShellState.home_team)
	away_label.text = _describe(ShellState.away_team)
	status_label.text = ""
	start_button.disabled = false


func _describe(team: Dictionary) -> String:
	var league := catalog.league_by_id(int(team.get("league_id", 0)))
	if league.is_empty():
		return str(team.get("name", "?"))
	return "%s (%s)" % [team.get("name", "?"), league.get("name", "")]


func _selected_duration() -> float:
	if duration_option == null or duration_option.selected < 0:
		return float(DURATIONS[DEFAULT_DURATION]["value"])
	return float(duration_option.get_item_metadata(duration_option.selected))


func _selected_difficulty() -> float:
	if difficulty_option == null or difficulty_option.selected < 0:
		return float(DIFFICULTIES[DEFAULT_DIFFICULTY]["value"])
	return float(difficulty_option.get_item_metadata(difficulty_option.selected))


func _on_option_changed(_index: int) -> void:
	ShellState.set_match_options({
		"duration": _selected_duration(),
		"difficulty": _selected_difficulty(),
	})


func build_package() -> Dictionary:
	package_builder.error = ""
	if not ShellState.has_selection():
		package_builder.error = "Choose two teams first."
		return {}
	if not catalog.load_data_root(data_root):
		package_builder.error = catalog.error
		return {}
	var options := {
		"duration": _selected_duration(),
		"difficulty": _selected_difficulty(),
	}
	var package := package_builder.build(catalog, ShellState.home_team, ShellState.away_team, options)
	if package.is_empty():
		package_builder.error = package_builder.error if not package_builder.error.is_empty() \
			else "Match package could not be built."
		return {}
	ShellState.set_match_options(options)
	ShellState.set_match_package(package)
	return package


func _on_start() -> void:
	var package := build_package()
	if package.is_empty():
		status_label.text = package_builder.error
		return
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_back() -> void:
	var target := TEAM_SELECT_SCENE if ShellState.has_selection() else MAIN_MENU_SCENE
	get_tree().change_scene_to_file(target)
