class_name CareerReleaseScreen
extends Control
# Prototype squad/ReleaseScreen.svelte: the release confirmation. One card with
# the player, what the release costs the squad (value, wage, contract, squad
# size), the danger action and the cancel that keeps the focus first. The
# release is blocked at eleven players; the reason comes from
# CareerSquadActions.release_preview and the action stays disabled then.
# The host owns the breadcrumb, the hints bar and the fade.

signal closed
signal changed

const CARD_W := 760.0
const CARD_PAD_X := 40.0
const CARD_PAD_Y := 32.0
const INFO_H := 34.0
const ACTION_H := 56.0
const ACTION_GAP := 4.0
const MARK_LOSS := Color("b23a48")
const MARK_WARN := Color("a66a00")

var _career: Career
var _catalog: TeamCatalog
var _player: Dictionary = {}
var _player_id := ""
var _preview: Dictionary = {}
var _error := ""
var _focus := 0

var _card: Panel
var _kicker: Label
var _title: Label
var _note: Label
var _info_rows: Array = []
var _reason: Label
var _error_label: Label
var _actions: Array = []


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
	_preview = CareerSquadActions.release_preview(career, catalog, _player_id)
	_focus = 0
	_refresh()
	focus_initial()
	_layout()
	_play_enter()


func close() -> void:
	pass


func hints() -> Array:
	var gamepad := _gamepad()
	return [
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "select"},
		{"keys": ["B"] if gamepad else ["ESC"], "label": "back"},
	]


func focus_initial() -> void:
	# The prototype focuses cancel, so a stray confirm never releases.
	_focus = maxi(0, _focus_ids().find("cancel"))
	_apply_state()


func status() -> String:
	return _error


func status_error() -> bool:
	return not _error.is_empty()


# State for the host and the tests --------------------------------------------

func preview() -> Dictionary:
	return _preview


func focused_id() -> String:
	var ids := _focus_ids()
	return str(ids[_focus]) if _focus >= 0 and _focus < ids.size() else ""


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

	_kicker = _make_label(_card, "Kicker", UiTheme.inter(600), 15, UiTokens.INK_2)
	_kicker.text = "PLAYER CONTRACT"
	_title = _make_label(_card, "Title", UiTheme.barlow(700), 44, UiTokens.INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = 2
	_note = _make_label(_card, "Note", UiTheme.inter(500), 17, UiTokens.INK_2)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.text = "The player leaves the club and terminates his contract."
	for caption in ["MARKET VALUE", "WEEKLY WAGE", "CONTRACT", "SQUAD SIZE"]:
		_info_rows.append(_make_info(_card, caption))
	_reason = _make_label(_card, "Reason", UiTheme.inter(600), 15, MARK_WARN)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label = _make_label(_card, "Error", UiTheme.inter(600), 15, MARK_LOSS)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for id in ["release", "cancel"]:
		_actions.append(_make_action(_card, id))


func _make_label(parent: Control, node_name: String, font: Font, font_size: int,
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
	parent.add_child(label)
	return label


func _make_info(parent: Control, caption: String) -> Dictionary:
	var panel := Panel.new()
	panel.name = "Info_" + caption.to_lower().replace(" ", "_")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, 0.055)
	panel.add_theme_stylebox_override(&"panel", box)
	parent.add_child(panel)
	var label := _make_label(panel, "Label", UiTheme.inter(600), 13, UiTokens.INK_2)
	label.text = caption
	var value := _make_label(panel, "Value", UiTheme.barlow(700), 19, UiTokens.INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return {"panel": panel, "label": label, "value": value}


func _make_action(parent: Control, id: String) -> Dictionary:
	var root := Control.new()
	root.name = "Action_" + id
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var panel := Panel.new()
	panel.name = "Bg"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var rail := ColorRect.new()
	rail.name = "Rail"
	rail.color = UiTokens.RAIL
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rail)
	var label := _make_label(root, "Label", UiTheme.barlow(700), 22, UiTokens.INK)
	var key_panel := Panel.new()
	key_panel.name = "Key"
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(key_panel)
	var key_label := _make_label(key_panel, "KeyLabel", UiTheme.inter(700), 13,
		UiTokens.INK_2)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.text = "A"
	root.mouse_entered.connect(_set_focus.bind(id))
	root.gui_input.connect(_on_action_input.bind(id))
	return {"id": id, "root": root, "panel": panel, "rail": rail, "label": label,
		"key_panel": key_panel, "key_label": key_label, "enabled": true}


# Content ---------------------------------------------------------------------

func _focus_ids() -> Array:
	var ids: Array = []
	for action in _actions:
		if bool(action["enabled"]):
			ids.append(str(action["id"]))
	return ids


func _refresh() -> void:
	if _card == null:
		return
	var can_release := bool(_preview.get("can_release", false))
	var name := str(_preview.get("player_name", _player.get("name", "")))
	_title.text = "RELEASE %s?" % name.to_upper() if not name.is_empty() \
		else "RELEASE PLAYER?"
	var years := int(_preview.get("years", 1))
	var values := [
		CareerPlayerPane.money(int(_preview.get("market_value", 0))),
		CareerPlayerPane.money(int(_preview.get("weekly_wage", 0))) + " / WEEK",
		"%d %s" % [years, "YEAR" if years == 1 else "YEARS"],
		str(int(_preview.get("squad_size", 0))),
	]
	for index in _info_rows.size():
		var row: Dictionary = _info_rows[index]
		(row["value"] as Label).text = values[index]
	var reason := str(_preview.get("reason", ""))
	if str(_preview.get("player_id", "")) == "" or name.is_empty():
		reason = "The player is not in this squad."
	_reason.text = reason
	_reason.visible = not reason.is_empty()
	for action in _actions:
		var id := str(action["id"])
		action["enabled"] = true if id == "cancel" else can_release
		(action["label"] as Label).text = "RELEASE PLAYER" if id == "release" else "CANCEL"
	_error_label.text = _error
	_error_label.visible = not _error.is_empty()
	_focus = clampi(_focus, 0, maxi(0, _focus_ids().size() - 1))
	_apply_state()
	_layout()


# Layout ---------------------------------------------------------------------

func _card_height() -> float:
	var height := CARD_PAD_Y * 2.0 + 26.0 + 60.0 + 52.0 \
		+ _info_rows.size() * (INFO_H + 2.0) + 8.0
	if _reason.visible:
		height += 26.0
	if _error_label.visible:
		height += 26.0
	height += 10.0 + _actions.size() * ACTION_H + (_actions.size() - 1) * ACTION_GAP
	return height


func _layout() -> void:
	if _card == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var card_w := minf(CARD_W, size.x - 32.0)
	var card_h := minf(_card_height(), size.y - 32.0)
	_card.position = ((size - Vector2(card_w, card_h)) * 0.5).round()
	_card.size = Vector2(card_w, card_h)
	var inner_w := maxf(0.0, card_w - CARD_PAD_X * 2.0)
	var y := CARD_PAD_Y
	_kicker.position = Vector2(CARD_PAD_X, y)
	_kicker.size = Vector2(inner_w, 20.0)
	y += 26.0
	_title.position = Vector2(CARD_PAD_X, y)
	_title.size = Vector2(inner_w, 56.0)
	y += 60.0
	_note.position = Vector2(CARD_PAD_X, y)
	_note.size = Vector2(inner_w, 46.0)
	y += 52.0
	for row in _info_rows:
		var panel := row["panel"] as Panel
		panel.position = Vector2(CARD_PAD_X, y)
		panel.size = Vector2(inner_w, INFO_H)
		(row["label"] as Label).position = Vector2(10.0, 0.0)
		(row["label"] as Label).size = Vector2(maxf(0.0, inner_w - 20.0 - 160.0), INFO_H)
		(row["value"] as Label).position = Vector2(maxf(10.0, inner_w - 10.0 - 170.0), 0.0)
		(row["value"] as Label).size = Vector2(170.0, INFO_H)
		y += INFO_H + 2.0
	y += 8.0
	_reason.position = Vector2(CARD_PAD_X, y)
	_reason.size = Vector2(inner_w, 24.0)
	if _reason.visible:
		y += 26.0
	_error_label.position = Vector2(CARD_PAD_X, y)
	_error_label.size = Vector2(inner_w, 24.0)
	var action_y := card_h - CARD_PAD_Y - _actions.size() * ACTION_H \
		- (_actions.size() - 1) * ACTION_GAP
	for action in _actions:
		var root := action["root"] as Control
		root.position = Vector2(CARD_PAD_X, action_y)
		root.size = Vector2(inner_w, ACTION_H)
		_layout_action(action, inner_w)
		action_y += ACTION_H + ACTION_GAP


func _layout_action(action: Dictionary, width: float) -> void:
	var root := action["root"] as Control
	var panel := action["panel"] as Panel
	panel.position = Vector2.ZERO
	panel.size = root.size
	var rail := action["rail"] as ColorRect
	rail.position = Vector2.ZERO
	rail.size = Vector2(UiTokens.RAIL_W, root.size.y)
	rail.visible = bool(action["enabled"])
	var label := action["label"] as Label
	label.position = Vector2(18.0, 0.0)
	label.size = Vector2(maxf(0.0, width - 66.0), root.size.y)
	var key_panel := action["key_panel"] as Panel
	key_panel.position = Vector2(width - 42.0, (root.size.y - 24.0) * 0.5)
	key_panel.size = Vector2(28.0, 24.0)
	var key_label := action["key_label"] as Label
	key_label.position = Vector2.ZERO
	key_label.size = key_panel.size


func _apply_state() -> void:
	if _card == null:
		return
	var focused_id := focused_id()
	for action in _actions:
		var focused := str(action["id"]) == focused_id
		var panel := action["panel"] as Panel
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL if focused else Color(UiTokens.INK,
			0.10 if str(action["id"]) == "release" else 0.055)
		panel.add_theme_stylebox_override(&"panel", box)
		(action["rail"] as ColorRect).visible = bool(action["enabled"])
		var ink := UiTokens.FOCUS_MARK if focused else UiTokens.INK
		if str(action["id"]) == "release":
			ink = UiTokens.FOCUS_MARK if focused \
				else Color(MARK_LOSS, 1.0 if bool(action["enabled"]) else 0.45)
		(action["label"] as Label).add_theme_color_override(&"font_color", ink)
		var key_box := StyleBoxFlat.new()
		key_box.bg_color = Color(UiTokens.RAIL, 0.16) if focused \
			else Color(UiTokens.INK, 0.09)
		key_box.content_margin_left = 4.0
		key_box.content_margin_right = 4.0
		(action["key_panel"] as Panel).add_theme_stylebox_override(&"panel", key_box)
		(action["key_label"] as Label).add_theme_color_override(&"font_color",
			UiTokens.RAIL if focused else UiTokens.INK_2)


func _set_focus(id: String) -> void:
	var ids := _focus_ids()
	var index := ids.find(id)
	if index < 0 or index == _focus:
		return
	_focus = index
	_apply_state()


# Actions --------------------------------------------------------------------

func _release() -> void:
	var result := CareerSquadActions.release_player(_career, _catalog, _player_id)
	if not bool(result.get("ok", false)):
		_error = str(result.get("error", ""))
		_refresh()
		return
	_error = ""
	changed.emit()
	closed.emit()


func _activate(id: String) -> void:
	if id == "release":
		_release()
	else:
		closed.emit()


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
	if direction == Vector2i.UP or direction == Vector2i.LEFT:
		_move_focus(-1)
	elif direction == Vector2i.DOWN or direction == Vector2i.RIGHT:
		_move_focus(1)


func _move_focus(delta: int) -> void:
	var count := _focus_ids().size()
	if count <= 0:
		return
	_focus = clampi(_focus + delta, 0, count - 1)
	_apply_state()


func _on_nav_confirmed() -> void:
	if _is_active():
		_activate(focused_id())


func _on_nav_cancelled() -> void:
	if _is_active():
		closed.emit()


func _on_action_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		if not _focus_ids().has(id):
			return
		_set_focus(id)
		_activate(id)
		accept_event()


func _play_enter() -> void:
	if _instant():
		return
	_card.modulate.a = 0.4
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.15)


# Autoloads are looked up by path: the screens are also instantiated by the
# headless tests directly, where a bare UiTransition identifier does not resolve.
func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))
