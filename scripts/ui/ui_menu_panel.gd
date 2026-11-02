class_name UiMenuPanel
extends Control

# Submenu panel: translucent note plate + a vertical stack of 88px rows. With
# no rows it shows the static "section in progress" row, matching the
# prototype's placeholder panels.

signal row_pressed(index: int)

const NOTE_GAP := 10.0
const ROW_GAP := 10.0

var _note_box: PanelContainer
var _note_label: Label
var _rows_box: VBoxContainer
var _rows: Array[UiMenuRow] = []


func _ready() -> void:
	_note_box = PanelContainer.new()
	_note_box.name = "NoteBox"
	_note_box.theme_type_variation = &"PanelNoteBox"
	_note_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label = Label.new()
	_note_label.name = "Note"
	_note_label.theme_type_variation = &"PanelNote"
	_note_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_note_box)
	_note_box.add_child(_note_label)

	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.add_theme_constant_override(&"separation", int(ROW_GAP))
	add_child(_rows_box)

	resized.connect(_layout_content)


func setup(note: String, rows: Array) -> void:
	if _note_box == null:
		return
	_note_label.text = note
	_note_box.visible = not note.is_empty()

	for row in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()

	if rows.is_empty():
		_add_row("SECTION IN PROGRESS", "It will arrive in a later build.", true)
	else:
		for i in rows.size():
			var row: Dictionary = rows[i]
			var added := _add_row(
				String(row.get("title", "")),
				String(row.get("sub", "")),
				false
			)
			added.pressed.connect(row_pressed.emit.bind(i))
	_layout_content()


func has_rows() -> bool:
	for row in _rows:
		if not row.is_static:
			return true
	return false


func content_height() -> float:
	if _note_box == null:
		return 0.0
	var note_height := 0.0
	if _note_box.visible:
		note_height = _note_box.size.y + NOTE_GAP
	return note_height + _rows_box.get_combined_minimum_size().y


func focus_first() -> void:
	for row in _rows:
		if not row.is_static:
			row.grab_focus()
			return


func move_focus(direction: Vector2i) -> void:
	if direction != Vector2i.UP and direction != Vector2i.DOWN:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var index := _rows.find(focus)
	if index == -1:
		focus_first()
		return
	var step := -1 if direction == Vector2i.UP else 1
	var next := clampi(index + step, 0, _rows.size() - 1)
	if not _rows[next].is_static:
		_rows[next].grab_focus()


func activate_focused() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var index := _rows.find(focus)
	if index >= 0 and not _rows[index].is_static:
		_rows[index].pressed.emit()


func _add_row(title: String, sub: String, is_static: bool) -> UiMenuRow:
	var row := UiMenuRow.new()
	row.title_text = title
	row.sub_text = sub
	row.is_static = is_static
	_rows_box.add_child(row)
	_rows.append(row)
	return row


func _layout_content() -> void:
	if _note_box == null:
		return
	var note_height := 0.0
	if _note_box.visible:
		_note_box.position = Vector2.ZERO
		_note_box.size = Vector2(size.x, _note_box.get_combined_minimum_size().y)
		note_height = _note_box.size.y + NOTE_GAP
	_rows_box.position = Vector2(0.0, note_height)
	_rows_box.size = Vector2(size.x, maxf(0.0, size.y - note_height))
	queue_redraw()
