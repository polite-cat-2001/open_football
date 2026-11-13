class_name MatchOverScreen
extends Control
# Shared base for the two end-of-match screens (result and the 90:00 draw choice):
# the pause scoreboard header, a meta line (competition), a 2x2 bento block on
# the left and one informational tile on the right, plus the shell hints bar.
# Subclasses only declare their four tiles and their own actions.
#
# Input is routed by the match orchestrator (GpfSlice); the direct
# handle_key/handle_joy path stays for headless tests, which run without
# autoloads. Layout follows PauseScreen: one 1920x1080 design canvas.

# Emitted once the close animation finished (the screen is hidden), so the caller
# can swap the scene after the fade instead of cutting it.
signal closed

const PANEL_W := 1480.0
const HEADER_H := 156.0
const META_H := 22.0
const META_GAP := 6.0
const INFO_GAP := 10.0
const SCREEN_OUT := 0.15
const SCREEN_IN := 0.24
const SCREEN_SCALE := 0.96

var design: Control
var scrim: ColorRect
var meta: Label
var scoreboard: PauseScoreboard
var body: Control
var menu_grid: BentoGrid
var info_tile: BentoTile
var hints: UiHintsBar
var content: Control

var _tiles: Array[BentoTile] = []
var _built := false
var _viewport_connected := false
var _closing := false
var _online := false
var _nav: Node = null
var _data: Dictionary = {}


func _ready() -> void:
	_build_once()
	_connect_viewport()


# Bind lazily: the match carrier (and headless checks) may add and open this
# screen before its own _ready has run.
func _build_once() -> void:
	if _built:
		return
	_built = true
	theme = UiTheme.load_or_build()

	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.0156863, 0.0352941, 0.0784314, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	design = Control.new()
	design.name = "Design"
	design.size = UiTokens.DESIGN_SIZE
	add_child(design)

	content = Control.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_to_group(&"ui_transition_target")
	design.add_child(content)

	meta = Label.new()
	meta.name = "Meta"
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta.add_theme_font_override("font", UiTheme.barlow(600))
	meta.add_theme_font_size_override("font_size", 18)
	meta.add_theme_color_override("font_color", UiTokens.FOCUS_INK_2)
	content.add_child(meta)

	scoreboard = PauseScoreboard.new()
	scoreboard.name = "Scoreboard"
	content.add_child(scoreboard)

	body = Control.new()
	body.name = "Body"
	content.add_child(body)

	info_tile = _make_tile(_info_spec())
	info_tile.name = "InfoTile"
	info_tile.still = true
	info_tile.set_tile_disabled(true)
	body.add_child(info_tile)

	menu_grid = BentoGrid.new()
	menu_grid.name = "MenuGrid"
	menu_grid.columns = 2
	menu_grid.rows = 2
	body.add_child(menu_grid)
	var specs := _tile_specs()
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var tile := _make_tile(spec)
		tile.name = String(spec.get("name", "Tile%d" % index))
		menu_grid.add_child(tile)
		menu_grid.add_cell(tile, index % 2 + 1, index / 2 + 1)
		_tiles.append(tile)
		tile.pressed.connect(_on_tile_pressed.bind(String(spec.get("id", ""))))

	hints = preload("res://scenes/ui/ui_hints_bar.tscn").instantiate() as UiHintsBar
	hints.name = "Hints"
	content.add_child(hints)

	_nav = get_node_or_null("/root/UiNav")
	_apply_hints()
	_layout()
	_apply_online()
	visible = false


func _make_tile(spec: Dictionary) -> BentoTile:
	var tile := BentoTile.new()
	tile.title = String(spec.get("title", ""))
	tile.glyph_name = String(spec.get("glyph", ""))
	tile.chip = String(spec.get("chip", ""))
	tile.disabled = bool(spec.get("disabled", false))
	return tile


# Subclass contract: four tiles, row-major, each
# {name, id, title, glyph, chip, disabled}.
func _tile_specs() -> Array:
	return []


# Right-hand informational tile (SOON placeholder).
func _info_spec() -> Dictionary:
	return {"title": "MATCH INFO", "glyph": "tactics", "chip": "SOON"}


func _on_tile_pressed(id: String) -> void:
	pass


func set_match_data(data: Dictionary) -> void:
	_data = data
	if not _built:
		return
	var home: Dictionary = data.get("home", {})
	var away: Dictionary = data.get("away", {})
	meta.text = String(data.get("meta", "")).to_upper()
	scoreboard.setup(home, away, int(data.get("score0", 0)),
		int(data.get("score1", 0)), "FULL TIME", String(data.get("caption", "")))


func set_online(value: bool) -> void:
	_online = value
	if not _built:
		return
	_apply_online()


# Network matches: the host decides, the client only watches.
func _apply_online() -> void:
	pass


func is_online() -> bool:
	return _online


func tiles() -> Array:
	_build_once()
	return _tiles


func is_open() -> bool:
	return visible


func is_closing() -> bool:
	return _closing


func open() -> void:
	_build_once()
	var was_open := visible
	_closing = false
	visible = true
	_layout()
	_focus_initial()
	if not was_open:
		_animate_open()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var transition := get_node_or_null("/root/UiTransition")
	if transition == null or bool(transition.get("instant")):
		_finish_close()
		return
	transition.hide_target(content, _finish_close)


func hide_now() -> void:
	visible = false
	_closing = false
	if content != null:
		content.modulate.a = 1.0
		content.scale = Vector2.ONE
	var viewport := get_viewport()
	if viewport != null:
		var focus := viewport.gui_get_focus_owner()
		# Only drop our own focus: during a cross-fade the incoming screen in this
		# same overlay may already own it.
		if focus != null and is_ancestor_of(focus):
			focus.release_focus()


func _finish_close() -> void:
	hide_now()
	closed.emit()


func _animate_open() -> void:
	var transition := get_node_or_null("/root/UiTransition")
	if transition == null or bool(transition.get("instant")):
		content.modulate.a = 1.0
		content.scale = Vector2.ONE
		return
	transition.show_target(content)


func _animations_instant() -> bool:
	return DisplayServer.get_name() == "headless"


func _connect_viewport() -> void:
	if _viewport_connected:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	viewport.size_changed.connect(_layout)
	_viewport_connected = true


func _layout() -> void:
	if get_viewport() == null:
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var scale := minf(view.x / UiTokens.DESIGN_SIZE.x,
		view.y / UiTokens.DESIGN_SIZE.y)
	design.scale = Vector2(scale, scale)
	design.position = (view - UiTokens.DESIGN_SIZE * scale) * 0.5
	design.size = UiTokens.DESIGN_SIZE
	design.pivot_offset = Vector2.ZERO

	var panel_x := (UiTokens.DESIGN_SIZE.x - PANEL_W) * 0.5
	var hints_height := hints.height()
	var total_height := META_H + META_GAP + HEADER_H + UiTokens.GAP \
		+ UiTokens.GRID_H + UiTokens.HINTS_GAP + hints_height
	var top := (UiTokens.DESIGN_SIZE.y - total_height) * 0.5

	meta.position = Vector2(panel_x, top)
	meta.size = Vector2(PANEL_W, META_H)

	scoreboard.position = Vector2(panel_x, top + META_H + META_GAP)
	scoreboard.size = Vector2(PANEL_W, HEADER_H)

	body.position = Vector2(panel_x, top + META_H + META_GAP + HEADER_H
		+ UiTokens.GAP)
	body.size = Vector2(PANEL_W, UiTokens.GRID_H)

	var column_w := (PANEL_W - INFO_GAP) * 0.5
	menu_grid.position = Vector2.ZERO
	menu_grid.size = Vector2(column_w, UiTokens.GRID_H)
	info_tile.set_base_rect(Rect2(column_w + INFO_GAP, 0.0, column_w,
		UiTokens.GRID_H), Vector2.ZERO)

	hints.position = Vector2(panel_x, body.position.y + UiTokens.GRID_H
		+ UiTokens.HINTS_GAP)
	hints.size = Vector2(PANEL_W, hints_height)


func _apply_hints() -> void:
	var gamepad := _nav != null and bool(_nav.using_gamepad())
	hints.setup([
		{"keys": ["D-PAD"] if gamepad else ["←", "↑", "↓", "→"], "label": "move"},
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
	])


func _focus_initial() -> void:
	for tile in _tiles:
		if not tile.disabled:
			tile.grab_focus()
			return


func handle_key(event: InputEventKey) -> bool:
	if not visible or not event.pressed:
		return false
	match event.keycode:
		KEY_UP:
			_move(Vector2i.UP)
		KEY_DOWN:
			_move(Vector2i.DOWN)
		KEY_LEFT:
			_move(Vector2i.LEFT)
		KEY_RIGHT:
			_move(Vector2i.RIGHT)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate_focused()
		KEY_ESCAPE:
			pass
		_:
			return false
	return true


func handle_joy(event: InputEventJoypadButton) -> bool:
	if not visible or not event.pressed:
		return false
	match int(event.button_index):
		JOY_BUTTON_A:
			_activate_focused()
		JOY_BUTTON_B:
			pass
		JOY_BUTTON_DPAD_UP:
			_move(Vector2i.UP)
		JOY_BUTTON_DPAD_DOWN:
			_move(Vector2i.DOWN)
		JOY_BUTTON_DPAD_LEFT:
			_move(Vector2i.LEFT)
		JOY_BUTTON_DPAD_RIGHT:
			_move(Vector2i.RIGHT)
		_:
			return false
	return true


func _move(direction: Vector2i) -> void:
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() != null \
		else null
	var index := _tiles.find(focus)
	if index == -1:
		_focus_initial()
		return
	var col := index % 2
	var row := index / 2
	var step := Vector2i.ZERO
	if direction == Vector2i.LEFT:
		step = Vector2i(-1, 0)
	elif direction == Vector2i.RIGHT:
		step = Vector2i(1, 0)
	elif direction == Vector2i.UP:
		step = Vector2i(0, -1)
	else:
		step = Vector2i(0, 1)
	col += step.x
	row += step.y
	while col >= 0 and col < 2 and row >= 0 and row < 2:
		var next := _tiles[row * 2 + col]
		if not next.disabled:
			next.grab_focus()
			return
		col += step.x
		row += step.y


func _activate_focused() -> void:
	if get_viewport() == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton and not (focus as BaseButton).disabled:
		(focus as BaseButton).pressed.emit()
