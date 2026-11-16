class_name CareerSquadActionsRow
extends Control
# Prototype shared/SquadActions.svelte: the actions the squad roster unfolds
# under a player. Three columns — TRANSFER (list/loan/block, applied at once
# through CareerTransfers.set_status and toggled by repeating the same status),
# SQUAD (manage team / shirt number) and CONTRACT (renew with the unread dot,
# release) — built from the shared CareerAccordionAction rows, so the colours and
# focus state are the same as every other accordion in the career screens.
#
# It docks in the gap the roster leaves under the row, so it pushes the list
# instead of covering it, and reports "plan"/"number"/"renew"/"release" to the
# host. Focus is the host's: it drives handle_moved/handle_confirmed.

signal action_requested(action: String, player_id: String)
signal changed
# The fold finished (the host may free the row now).
signal closed
# The plate grew or shrank: the host repositions the rows under it.
signal fold_changed

const GAP := 2.0
const PAD_X := 16.0
const PAD_TOP := 12.0
const PAD_BOTTOM := 14.0
const HEAD_H := 20.0
const HEAD_GAP := 8.0
const ROW_MIN_H := 166.0
const ACTION_GAP := 2.0
const DOT := 7.0

var career: Career
var catalog: TeamCatalog

var _player: Dictionary = {}
var _player_id := ""
var _status := ""
var _notice := false
var _columns: Array = []
var _focus := Vector2i(0, 0)
var _pending := ""
var _folded := 1.0
var _full_h := ROW_MIN_H
var _animating := false
var _closing := false
var _closed_emitted := false
var _fold_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()

# Host contract ---------------------------------------------------------------

func setup(next_career: Career, next_catalog: TeamCatalog, player: Dictionary) -> void:
	career = next_career
	catalog = next_catalog
	_player = player
	_player_id = str(player.get("id", player.get("player_id", "")))
	_status = _stored_status()
	_focus = Vector2i(0, 0)
	_rebuild()
	_layout()


func set_notice(value: bool) -> void:
	if _notice == value:
		return
	_notice = value
	_rebuild()
	_layout()


func notice() -> bool:
	return _notice


func height_hint() -> float:
	return ROW_MIN_H


func hints() -> Array:
	var gamepad := _gamepad()
	return [
		{"keys": ["L-STICK"] if gamepad else ["ARROWS"], "label": "Actions"},
		{"keys": ["A"] if gamepad else ["ENTER"], "label": "Select"},
		{"keys": ["B"] if gamepad else ["ESC"], "label": "Close"},
	]


func focus_initial() -> void:
	_focus = Vector2i(0, 0)
	_grab()


func focused_id() -> String:
	return str(_focused_action().get("id", ""))


func action_ids() -> Array:
	var ids: Array = []
	for column in _columns:
		for action in (column["actions"] as Array):
			ids.append(str(action.get("id", "")))
	return ids


func action_label(id: String) -> String:
	var action := _action_by_id(id)
	return str(action.get("label", "")) if not action.is_empty() else ""


func handle_moved(direction: Vector2i) -> bool:
	if _columns.is_empty() or _closing:
		return false
	var next := _focus
	if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
		next.x = clampi(_focus.x + (-1 if direction == Vector2i.LEFT else 1),
			0, _columns.size() - 1)
	elif direction == Vector2i.UP or direction == Vector2i.DOWN:
		next.y = clampi(_focus.y + (-1 if direction == Vector2i.UP else 1),
			0, (_columns[_focus.x]["actions"] as Array).size() - 1)
	else:
		return false
	if next == _focus:
		return false
	next.y = mini(next.y, (_columns[next.x]["actions"] as Array).size() - 1)
	if next == _focus:
		return false
	_focus = next
	_grab()
	return true


func handle_confirmed() -> bool:
	if _closing or _animating:
		return false
	var action := _focused_action()
	if action.is_empty():
		return false
	_activate(str(action.get("id", "")))
	return true


func focused_column() -> int:
	return _focus.x


func focused_row() -> int:
	return _focus.y


# Folding ---------------------------------------------------------------------

func play_open() -> void:
	visible = true
	_full_h = maxf(ROW_MIN_H, size.y)
	_folded = 0.0
	_closing = false
	_closed_emitted = false
	_pending = ""
	_animating = true
	_apply_fold()
	modulate.a = 0.0
	var tween := _tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_fold, 0.0, 1.0, 0.2)
	tween.finished.connect(func() -> void:
		_animating = false
		_set_fold(1.0))


func play_close() -> void:
	if _closing:
		return
	_closing = true
	_animating = true
	_closed_emitted = false
	var tween := _tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_fold, _folded, 0.0, 0.16)
	tween.finished.connect(_on_close_finished)


# Tests and hosts call this to jump to the end of the running fold.
func finish_animation() -> void:
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.kill()
	if _closing:
		_on_close_finished()
		return
	_animating = false
	_folded = 1.0
	_apply_fold()


func is_animating() -> bool:
	return _animating


func is_closing() -> bool:
	return _closing


func is_closed() -> bool:
	return _closing and _folded <= 0.01


func _tween() -> Tween:
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.kill()
	_fold_tween = create_tween()
	return _fold_tween


func _set_fold(value: float) -> void:
	_folded = value
	_apply_fold()


# The plate unfolds from its own height: content is laid out at full height and
# clipped, so nothing reflows while the fold runs.
func _apply_fold() -> void:
	size.y = _full_h * _folded
	modulate.a = _folded
	queue_redraw()
	fold_changed.emit()


# Build -----------------------------------------------------------------------

func _rebuild() -> void:
	for column in _columns:
		(column["node"] as Control).queue_free()
	_columns.clear()
	var rows := _action_rows()
	_full_h = maxf(_full_h, ROW_MIN_H)
	var specs := [
		{"id": "transfer", "label": "TRANSFER", "tone": UiTokens.MARK_WARN,
			"actions": rows[0]},
		{"id": "squad", "label": "SQUAD", "tone": UiTokens.MARK_WIN,
			"actions": rows[1]},
		{"id": "contract", "label": "CONTRACT", "tone": UiTokens.INK_2,
			"actions": rows[2]},
	]
	for spec in specs:
		var column := Panel.new()
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		var box := StyleBoxFlat.new()
		box.bg_color = UiTokens.FOCUS_FILL_SOFT
		column.add_theme_stylebox_override(&"panel", box)
		add_child(column)
		var head := Label.new()
		head.text = str(spec["label"])
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_theme_font_override(&"font", UiTheme.barlow(700))
		head.add_theme_font_size_override(&"font_size", 18)
		head.add_theme_color_override(&"font_color", UiTokens.FOCUS_INK)
		column.add_child(head)
		var dot := ColorRect.new()
		dot.color = spec["tone"]
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(dot)
		var actions: Array = []
		for data in (spec["actions"] as Array):
			var button := CareerAccordionAction.new()
			column.add_child(button)
			button.setup(data)
			button.pressed.connect(_on_action_pressed.bind(str(data.get("id", ""))))
			actions.append(data)
		_columns.append({
			"id": spec["id"], "actions": actions, "node": column,
			"head": head, "dot": dot, "buttons": column.get_children().filter(
				func(node: Node) -> bool: return node is CareerAccordionAction),
		})
	_focus.x = clampi(_focus.x, 0, _columns.size() - 1)
	_focus.y = mini(_focus.y, (_columns[_focus.x]["actions"] as Array).size() - 1)
	_grab()


func _action_rows() -> Array:
	var on_transfer := _status == "transfer"
	var on_loan := _status == "loan"
	var blocked := _status == "blocked"
	return [
		[
			{"id": "transfer", "label": "REMOVE" if on_transfer else "ON TRANSFER"},
			{"id": "loan", "label": "RECALL FROM LOAN" if on_loan else "LOAN"},
			{"id": "blocked", "label": "UNBLOCK" if blocked else "BLOCK"},
		],
		[
			{"id": "plan", "label": "MANAGE TEAM"},
			{"id": "number", "label": "CHANGE NUMBER"},
		],
		[
			{"id": "renew", "label": "RENEW CONTRACT",
				"ticket": "!" if _notice else ""},
			{"id": "release", "label": "RELEASE PLAYER"},
		],
	]


func _layout() -> void:
	if _columns.is_empty() or size.x <= 0.0:
		return
	# Columns are laid out at the unfolded height; the fold only clips them, so
	# nothing squashes while the plate opens or closes.
	var column_w := (size.x - GAP * 2.0) / 3.0
	var column_h := maxf(ROW_MIN_H, _full_h)
	for index in _columns.size():
		var column: Dictionary = _columns[index]
		var node: Panel = column["node"]
		node.position = Vector2(index * (column_w + GAP), 0.0)
		node.size = Vector2(column_w, column_h)
		var inner := maxf(0.0, column_w - PAD_X * 2.0)
		var dot: ColorRect = column["dot"]
		dot.position = Vector2(PAD_X, PAD_TOP + 6.0)
		dot.size = Vector2(DOT, DOT)
		var head: Label = column["head"]
		head.position = Vector2(PAD_X + DOT + 8.0, PAD_TOP)
		head.size = Vector2(maxf(0.0, inner - DOT - 8.0), HEAD_H)
		var buttons: Array = column["buttons"]
		var top := PAD_TOP + HEAD_H + HEAD_GAP
		var room := column_h - PAD_BOTTOM - top
		var action_h := CareerAccordionAction.HEIGHT
		if not buttons.is_empty():
			action_h = clampf((room - (buttons.size() - 1) * ACTION_GAP)
				/ float(buttons.size()), CareerAccordionAction.HEIGHT, 44.0)
		for row in buttons.size():
			var button: CareerAccordionAction = buttons[row]
			button.position = Vector2(PAD_X, top + row * (action_h + ACTION_GAP))
			button.size = Vector2(inner, action_h)


func _grab() -> void:
	var button := _focused_button()
	if button != null and button.is_inside_tree():
		button.grab_focus()


# Actions ---------------------------------------------------------------------

func _on_action_pressed(id: String) -> void:
	if _closing:
		return
	_activate(id)


func _activate(id: String) -> void:
	match id:
		"transfer", "loan", "blocked":
			_toggle_status(id)
		"plan", "number", "renew", "release":
			# The panel folds away first; the host gets the action once it is
			# gone, so no screen opens on top of a plate that is still on screen.
			_pending = id
			play_close()


func _on_close_finished() -> void:
	_animating = false
	_closing = true
	_folded = 0.0
	_apply_fold()
	if _closed_emitted:
		return
	_closed_emitted = true
	closed.emit()
	if not _pending.is_empty():
		var action := _pending
		_pending = ""
		action_requested.emit(action, _player_id)


func _toggle_status(status: String) -> void:
	if career == null or catalog == null:
		return
	var result := CareerTransfers.set_status(career, catalog, _player_id, status)
	if not bool(result.get("ok", false)):
		return
	_status = str(result.get("status", ""))
	_rebuild()
	_layout()
	changed.emit()


# Helpers ---------------------------------------------------------------------

func _stored_status() -> String:
	if career != null:
		return str(career.player_transfers.get(_player_id, ""))
	return str(_player.get("transfer_status", ""))


func _focused_action() -> Dictionary:
	if _focus.x < 0 or _focus.x >= _columns.size():
		return {}
	var actions: Array = _columns[_focus.x]["actions"]
	if _focus.y < 0 or _focus.y >= actions.size():
		return {}
	return actions[_focus.y]


func _focused_button() -> CareerAccordionAction:
	if _focus.x < 0 or _focus.x >= _columns.size():
		return null
	var buttons: Array = _columns[_focus.x]["buttons"]
	if _focus.y < 0 or _focus.y >= buttons.size():
		return null
	return buttons[_focus.y]


func _action_by_id(id: String) -> Dictionary:
	for column in _columns:
		for action in (column["actions"] as Array):
			if str(action.get("id", "")) == id:
				return action
	return {}


# Autoloads are looked up by path: the row is also instantiated by the headless
# tests directly, where a bare UiNav identifier does not resolve.
func _gamepad() -> bool:
	var nav := get_node_or_null("/root/UiNav")
	return nav != null and bool(nav.using_gamepad())
