class_name BentoGrid
extends Control

# Manual bento layout (4x2 by default). Not a Container: the selected tile has
# to be able to translate/scale outside its cell, which a Container would undo.
# Cells are declared in grid coordinates (1-based, CSS-like).

@export var columns := 4
@export var rows := 2

var _cells: Array[Dictionary] = []


func add_cell(tile: Control, col: int, row: int, col_span := 1, row_span := 1) -> void:
	_cells.append({
		"tile": tile,
		"col": col,
		"row": row,
		"col_span": col_span,
		"row_span": row_span,
	})


func _ready() -> void:
	resized.connect(_layout_cells)
	call_deferred("_layout_cells")


func _layout_cells() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var gap := UiTokens.GAP
	var column_width := (size.x - gap * float(columns - 1)) / float(columns)
	var row_height := (size.y - gap * float(rows - 1)) / float(rows)
	var center := size * 0.5

	for cell in _cells:
		var col := int(cell["col"])
		var row := int(cell["row"])
		var col_span := int(cell["col_span"])
		var row_span := int(cell["row_span"])
		var x := float(col - 1) * (column_width + gap)
		var y := float(row - 1) * (row_height + gap)
		var width := column_width * float(col_span) + gap * float(col_span - 1)
		var height := row_height * float(row_span) + gap * float(row_span - 1)
		var cell_center := Vector2(x + width * 0.5, y + height * 0.5)
		var push := Vector2(
			signf(cell_center.x - center.x),
			signf(cell_center.y - center.y)
		) * UiTokens.SELECTED_PUSH
		var tile := cell["tile"] as BentoTile
		if tile != null:
			tile.set_base_rect(Rect2(x, y, width, height), push)


func play_entrance(direction: int) -> void:
	if direction == 0:
		direction = 1
	for i in _cells.size():
		var tile := _cells[i]["tile"] as BentoTile
		if tile != null:
			tile.play_entrance(direction, float(i) * UiTokens.TILE_STAGGER)
