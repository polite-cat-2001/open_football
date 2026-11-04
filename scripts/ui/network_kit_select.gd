extends Control
# Network adapter for KitSelectView. The lobby stays in its Options phase: every
# peer walks this local kit step and then opens the existing match-options
# screen. Kit choices are deliberately not synchronized (one local kit choice
# per chooser slot); only the match options remain host-authoritative.

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"
const OPTIONS_SCENE := "res://scenes/network_match_options.tscn"
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
const UI_ASSETS := preload("res://scripts/data/ui_assets.gd")

@export var data_root := ""

@onready var view: KitSelectView = $KitSelectView

var catalog := KitCatalog.new()
var team_catalog := TeamCatalog.new()
var sides: Array = []
var sides_ready := false

var _local_id := -1
var _chooser_sides: Array = []
var _input_device := {"kind": "keyboard", "device": 0}
var _last_revision := -1
var _status := ""
var _status_error := false
var _leaving := false
var _last_signature := ""


func _ready() -> void:
	add_to_group(&"ui_shell")
	theme = UiTheme.load_or_build()
	view.side_move_requested.connect(_on_side_move)
	view.side_confirm_requested.connect(_on_side_confirm)
	view.side_cancel_requested.connect(_on_side_cancel)
	view.back_requested.connect(_back)
	view.retry_requested.connect(_reload)
	_load_data()
	_poll_lobby()
	set_process(true)


func _load_data() -> void:
	_status = ""
	_status_error = false
	if not catalog.load_data_root(data_root):
		_status = catalog.error
		_status_error = true
	if not ShellState.has_selection():
		_populate_teams_from_lobby()
	if not ShellState.has_selection():
		_status = "Choose both teams first."
		_status_error = true
		sides = [_side_model(0), _side_model(1)]
		sides_ready = true
		_refresh()
		return
	sides = [_side_model(0), _side_model(1)]
	for side in sides:
		var index := int(side["side"])
		var team: Dictionary = ShellState.home_team if index == 0 else ShellState.away_team
		side["team"] = team.duplicate(true)
		side["team_texture"] = UI_ASSETS.usable_texture(UI_ASSETS.team_logo(team))
		side["kits"] = catalog.kits_for(team)
		var selected: Dictionary = ShellState.kit_for(index)
		var kit_index := catalog.kit_index(side["kits"], str(selected.get("id", "")))
		if kit_index < 0:
			if index == 0:
				kit_index = 0
			else:
				var home_kits: Array = sides[0]["kits"]
				var home_kit: Dictionary = home_kits[clampi(int(sides[0]["kit_index"]), 0,
					home_kits.size() - 1)] if not home_kits.is_empty() else {}
				kit_index = catalog.default_away_index(side["kits"], home_kit)
		side["kit_index"] = clampi(kit_index, 0, maxi(0, (side["kits"] as Array).size() - 1))
		side["ready"] = false
	sides_ready = true
	_refresh()


func _populate_teams_from_lobby() -> void:
	var info := NET_SHELL.lobby(get_tree())
	var lobby: Dictionary = info.get("lobby", {})
	var ids: Array = lobby.get("team_ids", [])
	if ids.size() != 2 or int(ids[0]) <= 0 or int(ids[1]) <= 0:
		return
	if not team_catalog.load_data_root(data_root):
		return
	var home := team_catalog.team_by_id(int(ids[0]))
	var away := team_catalog.team_by_id(int(ids[1]))
	if not home.is_empty() and not away.is_empty():
		ShellState.set_teams(home, away)


func _reload() -> void:
	_last_signature = ""
	_load_data()
	if not _status_error:
		_last_revision = -1
		_poll_lobby()


func _side_model(side: int) -> Dictionary:
	return {
		"side": side,
		"team": {},
		"team_texture": null,
		"kits": [],
		"kit_index": 0,
		"ready": false,
		"live": false,
		"editable": false,
		"device": _input_device.duplicate(true),
	}


func _poll_lobby() -> void:
	if _leaving or not sides_ready:
		return
	var info := NET_SHELL.lobby(get_tree())
	if info.is_empty() or not bool(info.get("active", false)):
		_leave_session()
		return
	if bool(info.get("is_client", false)) and int(info.get("connection", 0)) == 0:
		_leave_session()
		return
	var lobby: Dictionary = info.get("lobby", {})
	var phase := int(lobby.get("phase", -1))
	if phase == 0:
		_leaving = true
		UiTransition.change_scene(SIDES_SCENE)
		return
	if phase == 1:
		_leaving = true
		UiTransition.change_scene(LOBBY_SCENE)
		return
	if phase != 2:
		_leave_session()
		return

	var revision := int(lobby.get("revision", -1))
	if revision != _last_revision:
		_last_revision = revision
		_chooser_sides = _chooser_sides_for(lobby, int(info.get("local_id", -1)))
	_local_id = int(info.get("local_id", -1))
	_chooser_sides = _chooser_sides_for(lobby, _local_id)
	_apply_live_flags()
	_refresh()


func _chooser_sides_for(lobby: Dictionary, local_id: int) -> Array:
	var chooser: Array = lobby.get("chooser", [])
	var result: Array = []
	for side in 2:
		if side < chooser.size() and int(chooser[side]) == local_id:
			result.append(side)
	return result


func _apply_live_flags() -> void:
	for side in sides:
		var index := int(side["side"])
		var editable := not _status_error and _chooser_sides.has(index)
		side["editable"] = editable
		side["live"] = editable and not bool(side["ready"])
		side["device"] = _input_device.duplicate(true)


func _refresh() -> void:
	if view == null:
		return
	_apply_live_flags()
	var signature := _signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	view.setup(_build_state(), {
		"back_label": "back",
		"status": _status,
		"status_error": _status_error,
	})


func _signature() -> String:
	var parts: Array[String] = [str(_status), str(_status_error)]
	for side in sides:
			parts.append("%s/%d/%d/%d/%d" % [str((side["team"] as Dictionary).get("name", "")),
			(side["kits"] as Array).size(), int(side["kit_index"]),
			1 if bool(side["ready"]) else 0, 1 if bool(side["editable"]) else 0])
	return "|".join(parts)


func _build_state() -> Dictionary:
	var side_states: Array = []
	for side in sides:
		var index := int(side["side"])
		var kits: Array = side["kits"]
		var kit: Dictionary = kits[clampi(int(side["kit_index"]), 0, maxi(0, kits.size() - 1))] \
			if not kits.is_empty() else {}
		side_states.append({
			"side": index,
			"label": "HOME" if index == 0 else "AWAY",
			"team": {
				"name": str((side["team"] as Dictionary).get("name", "")),
				"texture": side["team_texture"],
			},
			"kits": kits,
			"kit_index": int(side["kit_index"]),
			"ready": bool(side["ready"]),
			"live": bool(side["live"]),
			"editable": bool(side["editable"]),
			"device": side["device"],
			"choices": {"kits": kits.size()},
			"kit": kit,
		})
	var home_state: Dictionary = side_states[0]
	var away_state: Dictionary = side_states[1]
	return {
		"sides": side_states,
		"preview": {
			"home": {"name": home_state["team"]["name"], "kit": home_state["kit"]},
			"away": {"name": away_state["team"]["name"], "kit": away_state["kit"]},
		},
		"status": _status,
		"status_error": _status_error,
		"error": _status_error,
	}


func _note_input(input: Dictionary) -> void:
	_input_device = {
		"kind": str(input.get("kind", "keyboard")),
		"device": int(input.get("device", 0)),
	}
	NET_SHELL.note_local_device(get_tree(), str(_input_device["kind"]),
		int(_input_device["device"]))


func _on_side_move(side: int, delta: int, input: Dictionary) -> void:
	_note_input(input)
	var model: Dictionary = sides[side]
	if _status_error or bool(model["ready"]) or not bool(model["live"]) or delta == 0:
		return
	var kits: Array = model["kits"]
	if kits.size() < 2:
		return
	model["kit_index"] = posmod(int(model["kit_index"]) + delta, kits.size())
	_status = ""
	_status_error = false
	_refresh()


func _on_side_confirm(side: int, input: Dictionary) -> void:
	_note_input(input)
	var model: Dictionary = sides[side]
	if _status_error:
		_reload()
		return
	if bool(model["ready"]) or not bool(model["editable"]):
		return
	if (model["kits"] as Array).is_empty():
		_status = "No kits available for this team."
		_status_error = false
		_refresh()
		return
	model["ready"] = true
	_store_kit(side)
	_status = ""
	_status_error = false
	_refresh()
	if _local_sides_ready():
		_continue()


func _on_side_cancel(side: int, input: Dictionary) -> void:
	_note_input(input)
	var model: Dictionary = sides[side]
	if bool(model["ready"]):
		model["ready"] = false
		_status = ""
		_status_error = false
		_refresh()
		return
	_back()


func _store_kit(side: int) -> void:
	var model: Dictionary = sides[side]
	var kits: Array = model["kits"]
	if kits.is_empty():
		return
	var kit: Dictionary = kits[clampi(int(model["kit_index"]), 0, kits.size() - 1)]
	ShellState.set_kit(side, kit)


func _local_sides_ready() -> bool:
	if _chooser_sides.is_empty():
		return false
	for side in _chooser_sides:
		if not bool(sides[int(side)]["ready"]):
			return false
	return true


func _continue() -> void:
	if _leaving:
		return
	for side in 2:
		if ShellState.kit_for(int(side)).is_empty():
			var team: Dictionary = ShellState.home_team if int(side) == 0 else ShellState.away_team
			ShellState.set_kit(int(side), catalog.default_kit(team, int(side)))
	_leaving = true
	UiTransition.change_scene(OPTIONS_SCENE)


func _back() -> void:
	if _leaving:
		return
	_status = "Back to teams..."
	_status_error = false
	NET_SHELL.action(get_tree(), "backtoteams", 0, 0, 0)
	_refresh()


func _leave_session() -> void:
	if _leaving:
		return
	_leaving = true
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	UiTransition.change_scene(NETWORK_MENU_SCENE)


func _process(_delta: float) -> void:
	_poll_lobby()
