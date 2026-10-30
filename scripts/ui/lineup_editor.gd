class_name LineupEditor
extends VBoxContainer
# Editable prematch lineup for one team: the formation on a normalized pitch
# (dots can be dragged), the starting eleven and the bench. Changes live in a
# MatchLineup; the prematch screen validates it and hands it to MatchPackage.

signal changed

const SLOT_COUNT := Formation.SLOT_COUNT

var lineup: MatchLineup

var pitch
var starter_list: ItemList
var bench_list: ItemList
var reset_button: Button
var status_label: Label
var hint_label: Label

var _squad: Dictionary = {}
var _selected_slot := -1
var _pending_player_id := -1


class LineupPitch extends Control:
	signal slot_clicked(slot: int)
	signal slot_dragged(slot: int, position: Vector2)

	const PADDING := 0.06
	const HIT_RADIUS := 20.0

	var entries: Array = []
	var selected_slot := -1
	var dragging_slot := -1

	func set_entries(value: Array) -> void:
		entries = value
		queue_redraw()

	func set_selected_slot(value: int) -> void:
		selected_slot = value
		queue_redraw()

	func _draw() -> void:
		var area := get_size()
		if area.x <= 0.0 or area.y <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, area), Color(0.08, 0.22, 0.1), true)
		var line_color := Color(0.75, 0.85, 0.75, 0.8)
		draw_rect(Rect2(Vector2(3, 3), area - Vector2(6, 6)), line_color, false, 3.0)
		draw_line(Vector2(3, area.y * 0.5), Vector2(area.x - 3, area.y * 0.5), line_color, 2.0)
		draw_circle(Vector2(area.x * 0.5, area.y * 0.5), area.x * 0.12, line_color, false, 2.0)
		for entry in entries:
			var point: Vector2 = _entry_point(entry)
			var selected := int(entry.get("slot", -1)) == selected_slot
			var radius := 18.0 if selected else 15.0
			var fill := Color(1.0, 0.82, 0.25) if selected else Color(0.2, 0.55, 0.95)
			draw_circle(point, radius, fill)
			draw_circle(point, radius, Color(0.9, 0.95, 1.0), false, 2.0)
			draw_string(ThemeDB.fallback_font, point + Vector2(-18, 5), str(int(entry.get("slot", 0)) + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			draw_string(ThemeDB.fallback_font, point + Vector2(18, 5), str(entry.get("role", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.9, 0.85))
			var name := str(entry.get("name", ""))
			if name.length() > 14:
				name = name.substr(0, 13) + "…"
			draw_string(ThemeDB.fallback_font, point + Vector2(-24, 30), name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.95, 0.92))

	func _entry_point(entry: Dictionary) -> Vector2:
		var area := get_size()
		var position: Vector2 = entry.get("position", Vector2.ZERO)
		var shown := position
		if str(entry.get("role", "")) != "GK":
			# Same depth compression as the original plan map (planmap.cpp).
			shown.x = position.x * 0.8 + 0.1
		var across := (shown.y + 1.0) * 0.5
		var along := (shown.x + 1.0) * 0.5
		return Vector2(
			(PADDING + (1.0 - across) * (1.0 - 2.0 * PADDING)) * area.x,
			(PADDING + (1.0 - along) * (1.0 - 2.0 * PADDING)) * area.y)

	func _point_to_position(entry: Dictionary, point: Vector2) -> Vector2:
		var area := get_size()
		if area.x <= 0.0 or area.y <= 0.0:
			return Vector2.ZERO
		var across := 1.0 - (point.x / area.x - PADDING) / (1.0 - 2.0 * PADDING)
		var along := 1.0 - (point.y / area.y - PADDING) / (1.0 - 2.0 * PADDING)
		var shown := Vector2(along * 2.0 - 1.0, across * 2.0 - 1.0)
		var position := shown
		if str(entry.get("role", "")) != "GK":
			position.x = (shown.x - 0.1) / 0.8
		return Vector2(clampf(position.x, -1.0, 1.0), clampf(position.y, -1.0, 1.0))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var slot := _slot_at(event.position)
				if slot >= 0:
					dragging_slot = slot
					slot_clicked.emit(slot)
					accept_event()
			else:
				if dragging_slot >= 0:
					dragging_slot = -1
					accept_event()
		elif event is InputEventMouseMotion and dragging_slot >= 0:
			var entry := _entry_at(dragging_slot)
			if not entry.is_empty():
				slot_dragged.emit(dragging_slot, _point_to_position(entry, event.position))
				accept_event()

	func _slot_at(point: Vector2) -> int:
		var best := -1
		var best_distance := HIT_RADIUS
		for entry in entries:
			var distance := _entry_point(entry).distance_to(point)
			if distance <= best_distance:
				best_distance = distance
				best = int(entry.get("slot", -1))
		return best

	func _entry_at(slot: int) -> Dictionary:
		for entry in entries:
			if int(entry.get("slot", -1)) == slot:
				return entry
		return {}


func setup(squad: Dictionary) -> void:
	_squad = squad
	lineup = MatchLineup.from_squad(squad)
	if get_child_count() == 0:
		_build_ui()
	_refresh()


func set_lineup(value: MatchLineup) -> void:
	lineup = value
	_refresh()


func validation_error() -> String:
	if lineup == null:
		return "No lineup loaded."
	var result := lineup.validate()
	if bool(result.get("ok", false)):
		return ""
	return str(result.get("error", "Invalid lineup."))


func warning() -> String:
	if lineup == null:
		return ""
	return lineup.warning()


func _build_ui() -> void:
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	add_child(header)
	var name_label := Label.new()
	name_label.text = "%s — starting eleven" % str(_squad.get("team", {}).get("name", "Team"))
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	reset_button = Button.new()
	reset_button.name = "ResetLineupBtn"
	reset_button.text = "Reset"
	reset_button.add_theme_font_size_override("font_size", 18)
	reset_button.pressed.connect(_on_reset)
	header.add_child(reset_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	add_child(body)

	pitch = LineupPitch.new()
	pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pitch.custom_minimum_size = Vector2(340, 430)
	pitch.mouse_filter = Control.MOUSE_FILTER_STOP
	pitch.slot_clicked.connect(_on_pitch_slot_clicked)
	pitch.slot_dragged.connect(_on_pitch_slot_dragged)
	body.add_child(pitch)

	var lists := VBoxContainer.new()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.size_flags_stretch_ratio = 1.25
	lists.add_theme_constant_override("separation", 4)
	body.add_child(lists)

	lists.add_child(_header("Starting XI"))
	starter_list = ItemList.new()
	starter_list.name = "StarterList"
	starter_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	starter_list.add_theme_font_size_override("font_size", 17)
	starter_list.item_selected.connect(_on_starter_selected)
	lists.add_child(starter_list)

	lists.add_child(_header("Bench"))
	bench_list = ItemList.new()
	bench_list.name = "BenchList"
	bench_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bench_list.add_theme_font_size_override("font_size", 17)
	bench_list.item_selected.connect(_on_bench_selected)
	lists.add_child(bench_list)

	var actions := HBoxContainer.new()
	lists.add_child(actions)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
	hint_label.text = "Click one player, then another to swap. Drag a dot to move the position."
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(hint_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 17)
	add_child(status_label)


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	return label


func _refresh() -> void:
	if lineup == null or starter_list == null:
		return
	starter_list.clear()
	for slot in SLOT_COUNT:
		var role := str(lineup.formation[slot].get("role", "CM")) if slot < lineup.formation.size() else "CM"
		var player_id := lineup.lineup[slot]
		var text := "%d. %s — empty" % [slot + 1, role]
		if player_id != 0:
			var player := lineup.player_by_id(player_id)
			text = "%d. %s — %s" % [slot + 1, role, str(player.get("name", "?"))]
		var index := starter_list.add_item(text)
		starter_list.set_item_metadata(index, slot)

	bench_list.clear()
	for player_id in lineup.bench:
		var player := lineup.player_by_id(player_id)
		var index := bench_list.add_item("%s  %s" % [
			str(player.get("role", "")), str(player.get("name", "?"))])
		bench_list.set_item_metadata(index, player_id)

	if _pending_player_id != -1:
		var pending_slot := lineup.slot_for_player(_pending_player_id)
		if pending_slot >= 0:
			_selected_slot = pending_slot
			starter_list.select(pending_slot)
		else:
			_selected_slot = -1
			var pending_bench := lineup.bench.find(_pending_player_id)
			if pending_bench >= 0:
				bench_list.select(pending_bench)
		hint_label.text = "Selected: %s — click another player to swap." \
			% str(lineup.player_by_id(_pending_player_id).get("name", "?"))
	else:
		_selected_slot = -1
		hint_label.text = "Click one player, then another to swap. Drag a dot to move the position."

	_pitch_entries()
	_update_status()


func _update_status() -> void:
	var validation := lineup.validate()
	if not bool(validation.get("ok", false)):
		status_label.text = str(validation.get("error", "Invalid lineup."))
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		return
	var warning: String = lineup.warning()
	if not warning.is_empty():
		status_label.text = warning
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
		return
	status_label.text = "Ready: %d starters, %d on the bench." % [
		lineup.lineup_players().size(), lineup.bench.size()]
	status_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.75))


func _pitch_entries() -> void:
	var entries: Array = []
	for entry in lineup.formation:
		var copy: Dictionary = entry.duplicate()
		var player_id := lineup.lineup[int(copy.get("slot", 0))]
		copy["name"] = str(lineup.player_by_id(player_id).get("name", ""))
		entries.append(copy)
	pitch.set_entries(entries)
	pitch.set_selected_slot(_selected_slot)


func _on_starter_selected(index: int) -> void:
	if index < 0 or index >= lineup.lineup.size():
		return
	var player_id := lineup.lineup[index]
	if player_id != 0:
		_handle_pick(player_id)


func _on_bench_selected(index: int) -> void:
	if index < 0 or index >= lineup.bench.size():
		return
	_handle_pick(lineup.bench[index])


func _handle_pick(player_id: int) -> void:
	if player_id == 0:
		return
	if _pending_player_id == -1:
		_pending_player_id = player_id
		_refresh()
		return
	if _pending_player_id == player_id:
		_pending_player_id = -1
		_refresh()
		return
	var first_id := _pending_player_id
	_pending_player_id = -1
	if not lineup.swap_players(first_id, player_id):
		_refresh()
		status_label.text = lineup.error
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		return
	_refresh()
	changed.emit()


func _on_reset() -> void:
	lineup = MatchLineup.from_squad(_squad)
	_selected_slot = -1
	_pending_player_id = -1
	_refresh()
	changed.emit()


func _on_pitch_slot_clicked(slot: int) -> void:
	_selected_slot = slot
	if slot < starter_list.item_count:
		starter_list.select(slot)
	_pitch_entries()


func _on_pitch_slot_dragged(slot: int, position: Vector2) -> void:
	if lineup.move_position(slot, position):
		_pitch_entries()
		_update_status()
		changed.emit()
