class_name SqliteReader
extends RefCounted
# Minimal read-only SQLite 3 reader written in GDScript.
#
# The shell owns the game database, so Godot must read it without going through
# the C++ catalog. This reads table b-trees directly (leaves, interiors, overflow
# pages, record serial types) and exposes whole tables as arrays of dictionaries.
# It never writes and does not support indexes, views or WITHOUT ROWID tables.

const MAGIC_PREFIX := "SQLite format 3"
const SCHEMA_COLUMNS := ["type", "name", "tbl_name", "rootpage", "sql"]
const TABLE_INTERIOR := 0x05
const TABLE_LEAF := 0x0D
const CONSTRAINT_WORDS := ["PRIMARY", "UNIQUE", "CHECK", "FOREIGN", "CONSTRAINT"]

var error := ""

var _file: FileAccess
var _page_size := 4096
var _usable_size := 4096
var _page_count := 0
var _tables := {}


func open(path: String) -> bool:
	close()
	error = ""
	if not FileAccess.file_exists(path):
		error = "file does not exist"
		return false
	_file = FileAccess.open(path, FileAccess.READ)
	if _file == null:
		error = "cannot open file (error %d)" % FileAccess.get_open_error()
		return false

	var header := _file.get_buffer(100)
	if header.size() < 100 or header.slice(0, 15).get_string_from_utf8() != MAGIC_PREFIX:
		error = "not an SQLite 3 database"
		close()
		return false

	var raw_page_size := (header[16] << 8) | header[17]
	if raw_page_size == 1:
		_page_size = 65536
	elif raw_page_size >= 512 and raw_page_size <= 32768 \
			and (raw_page_size & (raw_page_size - 1)) == 0:
		_page_size = raw_page_size
	else:
		error = "invalid page size %d" % raw_page_size
		close()
		return false

	_usable_size = _page_size - int(header[20])
	_page_count = (_file.get_length() + _page_size - 1) / _page_size
	if _page_count < 1:
		error = "database file is empty"
		close()
		return false
	if not _load_schema():
		close()
		return false
	return true


func close() -> void:
	if _file != null:
		_file.close()
	_file = null
	_tables.clear()


func has_table(table_name: String) -> bool:
	return _tables.has(table_name)


func table_names() -> PackedStringArray:
	return PackedStringArray(_tables.keys())


func select_all(table_name: String, wanted: PackedStringArray = PackedStringArray()) -> Array:
	error = ""
	var info: Dictionary = _tables.get(table_name, {})
	if info.is_empty():
		error = "no such table: %s" % table_name
		return []
	var rows: Array = []
	var columns := PackedStringArray(info["columns"])
	var rowid_alias := int(info.get("rowid_alias", -1))
	if not _walk_table(int(info["root_page"]), rows, columns, wanted, rowid_alias, {}):
		return []
	return rows


func _load_schema() -> bool:
	var rows: Array = []
	if not _walk_table(1, rows, PackedStringArray(SCHEMA_COLUMNS), PackedStringArray(), -1, {}):
		return false
	for row in rows:
		if row.get("type") != "table" or row.get("sql") == null:
			continue
		var name := str(row.get("name", ""))
		var sql := str(row["sql"])
		var root_page := int(row.get("rootpage", 0))
		if name.is_empty() or root_page <= 0:
			continue
		var definitions := _split_definitions(sql)
		var columns := _parse_columns(definitions)
		_tables[name] = {
			"root_page": root_page,
			"columns": columns,
			"rowid_alias": _rowid_alias_index(definitions, columns),
			"sql": sql,
		}
	return not _tables.is_empty()


func _walk_table(page_no: int, out_rows: Array, columns: PackedStringArray,
		wanted: PackedStringArray, rowid_alias: int, visited: Dictionary) -> bool:
	if visited.has(page_no):
		return true
	visited[page_no] = true
	var page := _read_page(page_no)
	if page.is_empty():
		error = "page %d is out of range" % page_no
		return false

	var base := 100 if page_no == 1 else 0
	var flags := page[base]
	var cell_count := _u16(page, base + 3)
	var header_size := 8
	if flags == TABLE_INTERIOR:
		header_size = 12
	elif flags != TABLE_LEAF:
		error = "page %d is not a table b-tree page (flags %d)" % [page_no, flags]
		return false

	for i in cell_count:
		var cell_offset := _u16(page, base + header_size + i * 2)
		if flags == TABLE_LEAF:
			var cell = _read_leaf_cell(page, cell_offset)
			if cell == null:
				return false
			out_rows.append(_record_to_dict(cell[0], cell[1], columns, wanted, rowid_alias))
		else:
			var child := _u32(page, cell_offset)
			if not _walk_table(child, out_rows, columns, wanted, rowid_alias, visited):
				return false

	if flags == TABLE_INTERIOR:
		var right_most := _u32(page, base + 8)
		if not _walk_table(right_most, out_rows, columns, wanted, rowid_alias, visited):
			return false
	return true


func _read_page(page_no: int) -> PackedByteArray:
	if _file == null or page_no < 1 or page_no > _page_count:
		return PackedByteArray()
	_file.seek((page_no - 1) * _page_size)
	return _file.get_buffer(_page_size)


func _read_leaf_cell(page: PackedByteArray, offset: int):
	var header := _varint(page, offset)
	var payload_length: int = header[0]
	var cursor: int = header[1]
	var rowid_varint := _varint(page, cursor)
	var rowid: int = rowid_varint[0]
	cursor = rowid_varint[1]

	var max_local := _usable_size - 35
	var local_length := payload_length
	var overflow_page := 0
	if payload_length > max_local:
		var min_local := ((_usable_size - 12) * 32 / 255) - 23
		var k := min_local + ((payload_length - min_local) % (_usable_size - 4))
		local_length = k if k <= max_local else min_local
		overflow_page = _u32(page, cursor + local_length)

	var payload := page.slice(cursor, cursor + local_length)
	var remaining := payload_length - local_length
	while remaining > 0:
		if overflow_page <= 0:
			error = "record payload is truncated"
			return null
		var overflow := _read_page(overflow_page)
		if overflow.is_empty():
			error = "overflow page %d is missing" % overflow_page
			return null
		overflow_page = _u32(overflow, 0)
		var take := mini(remaining, _usable_size - 4)
		payload.append_array(overflow.slice(4, 4 + take))
		remaining -= take
	return [payload, rowid]


func _record_to_dict(payload: PackedByteArray, rowid: int, columns: PackedStringArray,
		wanted: PackedStringArray, rowid_alias: int) -> Dictionary:
	var row := {}
	var header := _varint(payload, 0)
	var header_size: int = header[0]
	var cursor: int = header[1]
	var serial_types: Array[int] = []
	while cursor < header_size:
		var serial := _varint(payload, cursor)
		serial_types.append(serial[0])
		cursor = serial[1]

	var body := header_size
	for i in serial_types.size():
		var serial_type := serial_types[i]
		if i < columns.size():
			var column := columns[i]
			if wanted.is_empty() or wanted.has(column):
				var value = _decode_value(payload, body, serial_type)
				if value == null and i == rowid_alias:
					value = rowid
				row[column] = value
		body += _serial_size(serial_type)
	return row


func _decode_value(payload: PackedByteArray, offset: int, serial_type: int):
	match serial_type:
		0, 10, 11:
			return null
		1, 2, 3, 4, 5, 6:
			return _signed_be(payload, offset, _serial_size(serial_type))
		7:
			return _double_be(payload, offset)
		8:
			return 0
		9:
			return 1
		_:
			var length := _serial_size(serial_type)
			var bytes := payload.slice(offset, offset + length)
			if serial_type % 2 == 0:
				return bytes
			return bytes.get_string_from_utf8()


func _serial_size(serial_type: int) -> int:
	match serial_type:
		0, 8, 9, 10, 11:
			return 0
		1:
			return 1
		2:
			return 2
		3:
			return 3
		4:
			return 4
		5:
			return 6
		6, 7:
			return 8
		_:
			if serial_type >= 12:
				if serial_type % 2 == 0:
					return (serial_type - 12) / 2
				return (serial_type - 13) / 2
	return 0


func _split_definitions(sql: String) -> Array[String]:
	var open_index := sql.find("(")
	if open_index < 0:
		var empty: Array[String] = []
		return empty

	var parts: Array[String] = []
	var current := ""
	var depth := 0
	var quote := ""
	for i in range(open_index + 1, sql.length()):
		var ch := sql[i]
		if not quote.is_empty():
			current += ch
			if ch == quote:
				quote = ""
			continue
		if ch == "'" or ch == "\"" or ch == "`":
			quote = ch
			current += ch
		elif ch == "[":
			quote = "]"
			current += ch
		elif ch == "(":
			depth += 1
			current += ch
		elif ch == ")":
			if depth == 0:
				if not current.strip_edges().is_empty():
					parts.append(current.strip_edges())
				break
			depth -= 1
			current += ch
		elif ch == "," and depth == 0:
			parts.append(current.strip_edges())
			current = ""
		else:
			current += ch

	return parts


func _parse_columns(definitions: Array[String]) -> PackedStringArray:
	var columns := PackedStringArray()
	for part in definitions:
		var column := _column_name(part)
		if not column.is_empty():
			columns.append(column)
	return columns


func _rowid_alias_index(definitions: Array[String], columns: PackedStringArray) -> int:
	for definition in definitions:
		if not definition.to_upper().contains("PRIMARY KEY"):
			continue
		return columns.find(_column_name(definition))
	return -1


func _column_name(definition: String) -> String:
	var text := definition.strip_edges()
	if text.is_empty():
		return ""
	var first := text[0]
	if first == "\"" or first == "`" or first == "'" or first == "[":
		var closing := "]" if first == "[" else first
		var end := text.find(closing, 1)
		if end < 0:
			return ""
		return text.substr(1, end - 1)
	var token := text.split(" ", false)[0]
	if CONSTRAINT_WORDS.has(token.to_upper()):
		return ""
	return token


func _varint(bytes: PackedByteArray, offset: int) -> Array:
	var value := 0
	var cursor := offset
	for i in 9:
		if cursor >= bytes.size():
			break
		var byte := bytes[cursor]
		cursor += 1
		if i == 8:
			value = (value << 8) | byte
		else:
			value = (value << 7) | (byte & 0x7F)
			if (byte & 0x80) == 0:
				return [value, cursor]
	return [value, cursor]


func _signed_be(bytes: PackedByteArray, offset: int, length: int) -> int:
	var value := 0
	for i in length:
		value = (value << 8) | bytes[offset + i]
	if length < 8 and (value & (1 << (length * 8 - 1))) != 0:
		value -= 1 << (length * 8)
	return value


func _double_be(bytes: PackedByteArray, offset: int) -> float:
	var raw := bytes.slice(offset, offset + 8)
	raw.reverse()
	return raw.decode_double(0)


func _u16(bytes: PackedByteArray, offset: int) -> int:
	return (bytes[offset] << 8) | bytes[offset + 1]


func _u32(bytes: PackedByteArray, offset: int) -> int:
	return (bytes[offset] << 24) | (bytes[offset + 1] << 16) \
		| (bytes[offset + 2] << 8) | bytes[offset + 3]
