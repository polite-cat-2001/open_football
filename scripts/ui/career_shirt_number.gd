class_name CareerShirtNumberScreen
extends Control
# Prototype squad/NumberScreen.svelte: the shirt-number picker. The big shirt
# carries the candidate number, the copy names the player, explains that free
# numbers run 1–99 and taken ones are skipped, and shows the current number.
# Left/right walks the free numbers (CareerSquadActions.free_shirt_numbers),
# confirm stores it through set_shirt_number, back cancels. The host owns the
# breadcrumb, the hints bar and the fade.

signal closed
signal changed

const PAD := 16.0
const CARD_H := 460.0
const CARD_MAX_W := 1040.0
const CARD_PAD_X := 40.0
const CARD_PAD_Y := 32.0
const SHIRT_W := 260.0
const SHIRT_H := 214.0
const COPY_GAP := 36.0
const MARK_LOSS := Color("b23a48")

var _career: Career
var _catalog: TeamCatalog
var _player: Dictionary = {}
var _player_id := ""
var _candidate := 0
var _free: Array = []
var _error := ""

var _card: Panel
var _shirt_bg: Panel
var _shirt: KitArt
var _number: Label
var _kicker: Label
var _name: Label
var _note_a: Label
var _note_b: Label
var _error_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	var nav := _ui_nav()
	if nav != null:
		nav.moved.connect(_on_nav_moved)
		nav.confirmed.connect(_on_nav_confirmed)
		nav.cancelled.connect(_on_nav_cancelled)
	call_deferred("_layout")


# Host contract ---------------------------------------------------------------

func open(career: Career, catalog: TeamCatalog, payload: Dictionary) -> void:
	_career = career
	_catalog = catalog
	_error = ""
	var next_player := str(payload.get("player_id", ""))
	if not next_player.is_empty():
		_player_id = next_player
	_resolve_player()
	_free = CareerSquadActions.free_shirt_numbers(career, _player_id)
	var current := _current_number()
	_candidate = current if _free.has(current) else int(_free[0]) if not _free.is_empty() else 0
	_refresh()
	_layout()
	_play_enter()


func close() -> void:
	pass


func hints() -> Array:
	var gamepad := _gamepad()
	return [
		{"keys": ["D-PAD"] if gamepad else ["←", "→"], "label": "number"},
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "confirm"},
		{"keys": ["B"] if gamepad else ["ESC"], "label": "cancel"},
	]


func focus_initial() -> void:
	_refresh()


func status() -> String:
	return _error


func status_error() -> bool:
	return not _error.is_empty()


# State for the host and the tests --------------------------------------------

func candidate() -> int:
	return _candidate


func current_number() -> int:
	return _current_number()


func free_numbers() -> Array:
	return _free


func _resolve_player() -> void:
	_player = {}
	if _career == null or _catalog == null:
		return
	var players := _catalog.career_players_by_ids(_career.player_ids, false)
	if players.is_empty():
		return
	CareerSquad.ensure_finances(_career, players)
	for player in CareerSquad.enrich_players(_career, players):
		if str((player as Dictionary).get("id", "")) == _player_id:
			_player = player
			return


func _current_number() -> int:
	var value = _player.get("shirt_number")
	return 0 if value == null else int(value)


# Build -----------------------------------------------------------------------

func _build() -> void:
	_card = Panel.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = Color(UiTokens.SHADOW, 0.30)
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	_card.add_theme_stylebox_override(&"panel", box)
	add_child(_card)

	_shirt_bg = Panel.new()
	_shirt_bg.name = "ShirtBg"
	_shirt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shirt_box := StyleBoxFlat.new()
	shirt_box.bg_color = Color(UiTokens.INK, 0.05)
	_shirt_bg.add_theme_stylebox_override(&"panel", shirt_box)
	_card.add_child(_shirt_bg)

	_shirt = KitArt.new()
	_shirt.name = "Shirt"
	_shirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_shirt)

	_number = _make_label("Number", UiTheme.barlow(700), 62, UiTokens.INK)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_child(_number)

	_kicker = _make_label("Kicker", UiTheme.inter(600), 15, UiTokens.INK_2)
	_kicker.text = "SHIRT NUMBER"
	_card.add_child(_kicker)
	_name = _make_label("Name", UiTheme.barlow(700), 46, UiTokens.INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	_card.add_child(_name)
	_note_a = _make_label("NoteFree", UiTheme.inter(500), 16, UiTokens.INK_2)
	_note_a.text = "Free numbers 1–99 · taken numbers are skipped"
	_note_a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_note_a)
	_note_b = _make_label("NoteCurrent", UiTheme.inter(500), 16, UiTokens.INK_2)
	_card.add_child(_note_b)
	_error_label = _make_label("Error", UiTheme.inter(600), 15, MARK_LOSS)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_error_label)


func _make_label(node_name: String, font: Font, font_size: int,
		color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


# Content ---------------------------------------------------------------------

func _refresh() -> void:
	if _card == null:
		return
	_number.text = str(_candidate) if _candidate > 0 else "—"
	_number.add_theme_color_override(&"font_color", UiTokens.RAIL)
	_name.text = str(_player.get("name", "")).to_upper()
	var current := _current_number()
	_note_b.text = "Current number: %s" % (str(current) if current > 0 else "—")
	_error_label.text = _error
	_error_label.visible = not _error.is_empty()
	_shirt.set_kit(_club_kit())
	var focused_box := StyleBoxFlat.new()
	focused_box.bg_color = UiTokens.FOCUS_FILL
	_shirt_bg.add_theme_stylebox_override(&"panel", focused_box)
	_layout()


func _club_kit() -> Dictionary:
	if _career == null or _catalog == null:
		return {}
	var club := _catalog.career_club(int(_career.club_id))
	return KitCatalog.new().default_kit(club, 0)


func _cycle(delta: int) -> void:
	if _free.is_empty():
		return
	var index := maxi(0, _free.find(_candidate))
	_candidate = int(_free[posmod(index + delta, _free.size())])
	_error = ""
	_refresh()


func _confirm() -> void:
	if _candidate <= 0:
		return
	var result := CareerSquadActions.set_shirt_number(_career, _player_id, _candidate,
		_catalog)
	if not bool(result.get("ok", false)):
		_error = str(result.get("error", ""))
		_refresh()
		return
	_error = ""
	changed.emit()
	closed.emit()


# Layout ---------------------------------------------------------------------

func _layout() -> void:
	if _card == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var card_w := minf(CARD_MAX_W, size.x - PAD * 2.0)
	var card_h := minf(CARD_H, size.y - PAD * 2.0)
	_card.position = ((size - Vector2(card_w, card_h)) * 0.5).round()
	_card.size = Vector2(card_w, card_h)
	var copy_x := CARD_PAD_X + SHIRT_W + COPY_GAP
	var copy_w := maxf(0.0, card_w - copy_x - CARD_PAD_X)
	var shirt_y := (card_h - SHIRT_H) * 0.5
	_shirt_bg.position = Vector2(CARD_PAD_X, shirt_y)
	_shirt_bg.size = Vector2(SHIRT_W, SHIRT_H)
	_shirt.position = _shirt_bg.position
	_shirt.size = _shirt_bg.size
	_number.position = Vector2(CARD_PAD_X, shirt_y + SHIRT_H * 0.50)
	_number.size = Vector2(SHIRT_W, SHIRT_H * 0.42)
	var y := (card_h - 210.0) * 0.5
	_kicker.position = Vector2(copy_x, y)
	_kicker.size = Vector2(copy_w, 20.0)
	_name.position = Vector2(copy_x, y + 24.0)
	_name.size = Vector2(copy_w, 62.0)
	_note_a.position = Vector2(copy_x, y + 96.0)
	_note_a.size = Vector2(copy_w, 26.0)
	_note_b.position = Vector2(copy_x, y + 126.0)
	_note_b.size = Vector2(copy_w, 24.0)
	_error_label.position = Vector2(copy_x, y + 158.0)
	_error_label.size = Vector2(copy_w, 40.0)


func _play_enter() -> void:
	if _instant():
		return
	_card.modulate.a = 0.4
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.15)


# Input ----------------------------------------------------------------------

func _ui_nav() -> Node:
	return get_node_or_null("/root/UiNav")


func _gamepad() -> bool:
	var nav := _ui_nav()
	return nav != null and bool(nav.using_gamepad())


func _is_active() -> bool:
	var nav := _ui_nav()
	return is_visible_in_tree() and (nav == null or not nav.is_modal())


func _on_nav_moved(direction: Vector2i) -> void:
	if not _is_active():
		return
	if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
		_cycle(-1 if direction == Vector2i.LEFT else 1)


func _on_nav_confirmed() -> void:
	if _is_active():
		_confirm()


func _on_nav_cancelled() -> void:
	if _is_active():
		closed.emit()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var local := mouse.position - (_card.position + _shirt_bg.position)
		if Rect2(Vector2.ZERO, _shirt_bg.size).has_point(local):
			_confirm()
			accept_event()


# Autoloads are looked up by path: the screens are also instantiated by the
# headless tests directly, where a bare UiTransition identifier does not resolve.
func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))
