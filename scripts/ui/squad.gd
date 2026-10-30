extends Control
# Read-only squad preview: the eleven formation slots on a normalized pitch and
# the team's players with their final (age-adjusted) stats. This is the visual
# check for the stat/formation port; the editable prematch comes later.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"

@export var team_id := 0

var catalog := TeamCatalog.new()
var squad := {}

var team_label: Label
var league_label: Label
var status_label: Label
var player_list: ItemList
var stats_grid: GridContainer
var player_info: Label
var pitch_view
var back_button: Button


class PitchView extends Control:
	var entries: Array = []

	func set_entries(value: Array) -> void:
		entries = value
		queue_redraw()

	func _draw() -> void:
		var area := get_size()
		draw_rect(Rect2(Vector2.ZERO, area), Color(0.08, 0.22, 0.1), true)
		var line_color := Color(0.75, 0.85, 0.75, 0.8)
		draw_rect(Rect2(Vector2(3, 3), area - Vector2(6, 6)), line_color, false, 3.0)
		draw_line(Vector2(3, area.y * 0.5), Vector2(area.x - 3, area.y * 0.5), line_color, 2.0)
		draw_circle(Vector2(area.x * 0.5, area.y * 0.5), area.x * 0.12, line_color, false, 2.0)
		var padding := 0.06
		for entry in entries:
			var position: Vector2 = entry["position"]
			# Same depth compression as the original plan map (planmap.cpp):
			# field players are pulled forward so the keeper is not on their line.
			var shown := position
			if str(entry["role"]) != "GK":
				shown.x = position.x * 0.8 + 0.1
			var across := (shown.y + 1.0) * 0.5
			var along := (shown.x + 1.0) * 0.5
			var point := Vector2(
				(padding + (1.0 - across) * (1.0 - 2.0 * padding)) * area.x,
				(padding + (1.0 - along) * (1.0 - 2.0 * padding)) * area.y)
			draw_circle(point, 15.0, Color(0.2, 0.55, 0.95))
			draw_circle(point, 15.0, Color(0.9, 0.95, 1.0), false, 2.0)
			draw_string(ThemeDB.fallback_font, point + Vector2(-18, 5), str(int(entry["slot"]) + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			draw_string(ThemeDB.fallback_font, point + Vector2(18, 5), str(entry["role"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.9, 0.85))


func _ready() -> void:
	_build_ui()
	_load_squad()


func _load_squad() -> void:
	if team_id <= 0 and not ShellState.preview_team.is_empty():
		team_id = int(ShellState.preview_team.get("id", 0))
	if team_id <= 0:
		_show_error("No team selected.")
		return
	if not catalog.load_data_root():
		_show_error(catalog.error)
		return
	squad = catalog.load_squad(team_id)
	if not catalog.error.is_empty() or squad.is_empty():
		_show_error(catalog.error if not catalog.error.is_empty() else "Team could not be loaded.")
		return
	_fill_squad()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.06)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	team_label = Label.new()
	team_label.text = "Squad"
	team_label.add_theme_font_size_override("font_size", 48)
	team_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	column.add_child(team_label)

	league_label = Label.new()
	league_label.add_theme_font_size_override("font_size", 20)
	league_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
	column.add_child(league_label)

	column.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)

	var pitch_column := VBoxContainer.new()
	pitch_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch_column.size_flags_stretch_ratio = 1.0
	body.add_child(pitch_column)
	var pitch_header := Label.new()
	pitch_header.text = "Formation"
	pitch_header.add_theme_font_size_override("font_size", 22)
	pitch_header.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	pitch_column.add_child(pitch_header)
	pitch_view = PitchView.new()
	pitch_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pitch_view.custom_minimum_size = Vector2(340, 500)
	pitch_column.add_child(pitch_view)

	var player_column := VBoxContainer.new()
	player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_column.size_flags_stretch_ratio = 1.2
	body.add_child(player_column)
	var player_header := Label.new()
	player_header.text = "Players"
	player_header.add_theme_font_size_override("font_size", 22)
	player_header.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	player_column.add_child(player_header)
	player_list = ItemList.new()
	player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_list.add_theme_font_size_override("font_size", 18)
	player_list.item_selected.connect(_on_player_selected)
	player_column.add_child(player_list)

	var stats_column := VBoxContainer.new()
	stats_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_column.size_flags_stretch_ratio = 1.1
	body.add_child(stats_column)
	var stats_header := Label.new()
	stats_header.text = "Final stats"
	stats_header.add_theme_font_size_override("font_size", 22)
	stats_header.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	stats_column.add_child(stats_header)
	player_info = Label.new()
	player_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_info.add_theme_font_size_override("font_size", 18)
	player_info.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	stats_column.add_child(player_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_column.add_child(scroll)
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 24)
	scroll.add_child(stats_grid)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	column.add_child(status_label)

	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(200, 56)
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.pressed.connect(_on_back)
	bottom.add_child(back_button)


func _fill_squad() -> void:
	var team: Dictionary = squad["team"]
	var league: Dictionary = squad["league"]
	team_label.text = str(team.get("name", "Squad"))
	league_label.text = str(league.get("name", ""))
	var formation: Array = squad["formation"]
	pitch_view.set_entries(formation)

	var lineup: Array = squad["lineup"]
	var players: Array = squad["players"]
	player_list.clear()
	for index in players.size():
		var player: Dictionary = players[index]
		var role := str(player.get("role", ""))
		var prefix := ""
		if index < lineup.size() and index < formation.size():
			role = str(formation[index].get("role", role))
			prefix = "%d. " % (index + 1)
		var label := "%s%s  %s (%d)" % [prefix, role, player.get("name", ""), int(player.get("age", 0))]
		var item := player_list.add_item(label)
		player_list.set_item_metadata(item, player)
	if players.size() > 0:
		player_list.select(0)
		_on_player_selected(0)
	status_label.text = "%d players, %d in the lineup." % [players.size(), lineup.size()]
	status_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.75))


func _on_player_selected(index: int) -> void:
	if index < 0 or index >= player_list.item_count:
		return
	var player = player_list.get_item_metadata(index)
	if typeof(player) != TYPE_DICTIONARY:
		return
	player_info.text = "%s — %s, age %d, base %.3f, average %.3f" % [
		player.get("name", ""), player.get("role", ""), int(player.get("age", 0)),
		float(player.get("base_stat", 0.0)), float(player.get("average", 0.0))]
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
	var stats: Dictionary = player.get("stats", {})
	for name in PlayerStats.STAT_NAMES:
		var name_label := Label.new()
		name_label.text = str(name)
		name_label.add_theme_font_size_override("font_size", 16)
		var value_label := Label.new()
		value_label.text = "%.3f" % float(stats.get(name, 0.0))
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
		stats_grid.add_child(name_label)
		stats_grid.add_child(value_label)


func _show_error(message: String) -> void:
	status_label.text = message
	if player_list != null:
		player_list.clear()
	if pitch_view != null:
		pitch_view.set_entries([])
	if team_label != null:
		team_label.text = "Squad"


func _on_back() -> void:
	var target := TEAM_SELECT_SCENE if not ShellState.preview_team.is_empty() else MAIN_MENU_SCENE
	get_tree().change_scene_to_file(target)
