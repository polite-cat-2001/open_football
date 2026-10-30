extends Control

const MATCH_SCENE := "res://scenes/gpf_slice.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@export var data_root := ""

var catalog := TeamCatalog.new()
var home_team: Dictionary = {}
var away_team: Dictionary = {}

var league_list: ItemList
var team_list: ItemList
var home_label: Label
var away_label: Label
var status_label: Label
var set_home_button: Button
var set_away_button: Button
var start_button: Button
var back_button: Button


func _ready() -> void:
	_build_ui()
	_load_catalog()


func _load_catalog() -> void:
	if not catalog.load_data_root(data_root):
		_show_error(catalog.error)
		return
	status_label.text = "%d leagues, %d teams in the database." \
		% [catalog.leagues.size(), catalog.teams.size()]
	_fill_leagues()
	if league_list.item_count > 0:
		league_list.select(0)
		_on_league_selected(0)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.06)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Select Teams"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Leagues and teams are read from the game database."
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
	column.add_child(subtitle)

	column.add_child(HSeparator.new())

	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.add_theme_constant_override("separation", 24)
	column.add_child(lists)

	var league_column := VBoxContainer.new()
	league_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	league_column.size_flags_stretch_ratio = 1.2
	lists.add_child(league_column)
	league_column.add_child(_header("League"))
	league_list = ItemList.new()
	league_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	league_list.add_theme_font_size_override("font_size", 20)
	league_list.item_selected.connect(_on_league_selected)
	league_column.add_child(league_list)

	var team_column := VBoxContainer.new()
	team_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_column.size_flags_stretch_ratio = 1.0
	lists.add_child(team_column)
	team_column.add_child(_header("Team"))
	team_list = ItemList.new()
	team_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	team_list.add_theme_font_size_override("font_size", 20)
	team_column.add_child(team_list)

	var slot_column := VBoxContainer.new()
	slot_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_column.size_flags_stretch_ratio = 0.9
	slot_column.add_theme_constant_override("separation", 10)
	lists.add_child(slot_column)

	slot_column.add_child(_header("Home"))
	home_label = _slot_label()
	slot_column.add_child(home_label)
	set_home_button = _button("Set as home", 20)
	set_home_button.pressed.connect(_on_set_home)
	slot_column.add_child(set_home_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_column.add_child(spacer)

	slot_column.add_child(_header("Away"))
	away_label = _slot_label()
	slot_column.add_child(away_label)
	set_away_button = _button("Set as away", 20)
	set_away_button.pressed.connect(_on_set_away)
	slot_column.add_child(set_away_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.75))
	column.add_child(status_label)

	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	back_button = _button("Back", 24)
	back_button.custom_minimum_size = Vector2(200, 60)
	back_button.pressed.connect(_on_back)
	bottom.add_child(back_button)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)
	start_button = _button("Start Match", 24)
	start_button.custom_minimum_size = Vector2(260, 60)
	start_button.disabled = true
	start_button.pressed.connect(_on_start)
	bottom.add_child(start_button)

	_update_slots()


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	return label


func _slot_label() -> Label:
	var label := Label.new()
	label.text = "not selected"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	return label


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	return button


func _fill_leagues() -> void:
	league_list.clear()
	for league in catalog.leagues:
		var label := str(league["name"])
		if not str(league["country"]).is_empty():
			label = "%s — %s" % [league["country"], label]
		var index := league_list.add_item(label)
		league_list.set_item_metadata(index, int(league["id"]))


func _on_league_selected(index: int) -> void:
	team_list.clear()
	if index < 0:
		return
	var league_id := int(league_list.get_item_metadata(index))
	for team in catalog.teams_for_league(league_id):
		var team_index := team_list.add_item(team["name"])
		team_list.set_item_metadata(team_index, team)
	if team_list.item_count > 0:
		team_list.select(0)


func _on_set_home() -> void:
	var team := _selected_team()
	if team.is_empty():
		return
	home_team = team.duplicate(true)
	_update_slots()


func _on_set_away() -> void:
	var team := _selected_team()
	if team.is_empty():
		return
	away_team = team.duplicate(true)
	_update_slots()


func _selected_team() -> Dictionary:
	var selected := team_list.get_selected_items()
	if selected.is_empty():
		return {}
	var metadata = team_list.get_item_metadata(selected[0])
	if typeof(metadata) != TYPE_DICTIONARY:
		return {}
	return metadata


func _update_slots() -> void:
	home_label.text = _describe(home_team)
	away_label.text = _describe(away_team)
	start_button.disabled = home_team.is_empty() or away_team.is_empty()


func _describe(team: Dictionary) -> String:
	if team.is_empty():
		return "not selected"
	var league := catalog.league_by_id(int(team["league_id"]))
	if league.is_empty():
		return str(team["name"])
	return "%s (%s)" % [team["name"], league["name"]]


func save_selection() -> bool:
	if home_team.is_empty() or away_team.is_empty():
		return false
	ShellState.set_teams(home_team, away_team)
	return true


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	status_label.add_theme_font_size_override("font_size", 24)
	start_button.disabled = true
	league_list.clear()
	team_list.clear()


func _on_start() -> void:
	if not save_selection():
		return
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
