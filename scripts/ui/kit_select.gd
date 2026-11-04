extends Control
# Local adapter for KitSelectView. It owns the kit catalog lookup, the per-side
# kit index and the 1P/2P ready flow; layout and input live in the shared view.

const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"
const PREMATCH_SCENE := "res://scenes/prematch.tscn"
const UI_ASSETS := preload("res://scripts/data/ui_assets.gd")

@export var data_root := ""

@onready var view: KitSelectView = $KitSelectView

var catalog := KitCatalog.new()
var sides: Array = []
var parallel := false
var active_side := 0
var human_side := 0

var _status := ""
var _error := false
var _leaving := false


func _ready() -> void:
	add_to_group(&"ui_shell")
	theme = UiTheme.load_or_build()
	view.side_move_requested.connect(_on_side_move)
	view.side_confirm_requested.connect(_on_side_confirm)
	view.side_cancel_requested.connect(_on_side_cancel)
	view.back_requested.connect(_leave)
	view.retry_requested.connect(_reload)
	_load_data()


func _load_data() -> void:
	_error = false
	_status = ""
	if not ShellState.has_selection():
		_leave.call_deferred()
		return
	if not catalog.load_data_root(data_root):
		_error = true
		_status = catalog.error
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
	_resolve_devices()
	_apply_live_flags()
	_refresh()


func _reload() -> void:
	_load_data()


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
		"device": {"kind": "keyboard", "device": 0},
	}


func _resolve_devices() -> void:
	var entries: Array = ShellState.controllers
	if entries.is_empty():
		entries = ShellState.DEFAULT_CONTROLLERS.duplicate(true)
	var present := {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var side := 1 if str(entry.get("side", "home")) == "away" else 0
		present[side] = {
			"kind": str(entry.get("kind", "keyboard")),
			"device": int(entry.get("device", 0)),
		}
	if present.is_empty():
		present[0] = {"kind": "keyboard", "device": 0}
	for side in 2:
		sides[side]["device"] = present.get(side, {})
	parallel = present.has(0) and present.has(1) \
		and not (str(sides[0]["device"].get("kind", "")) == "keyboard"
			and str(sides[1]["device"].get("kind", "")) == "keyboard") \
		and not (str(sides[0]["device"].get("kind", "")) == "gamepad"
			and int(sides[0]["device"].get("device", -1)) == int(sides[1]["device"].get("device", -2)))
	if parallel:
		active_side = 0
		human_side = 0
	else:
		active_side = 0 if present.has(0) else 1
		human_side = active_side
		var other := 1 - active_side
		sides[other]["device"] = (sides[active_side]["device"] as Dictionary).duplicate(true)


func _apply_live_flags() -> void:
	for side in sides:
		var index := int(side["side"])
		if _error:
			side["editable"] = false
			side["live"] = false
		elif parallel:
			side["editable"] = true
			side["live"] = not bool(side["ready"])
		else:
			side["editable"] = index == active_side
			side["live"] = side["editable"] and not bool(side["ready"])


func _refresh() -> void:
	if view == null:
		return
	_apply_live_flags()
	view.setup(_build_state(), {
		"back_label": "back",
		"status": _status,
		"status_error": _error,
	})


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
		"status_error": _error,
		"error": _error,
	}


func _on_side_move(side: int, delta: int, _input: Dictionary) -> void:
	var model: Dictionary = sides[side]
	if _error or bool(model["ready"]) or not bool(model["live"]) or delta == 0:
		return
	var kits: Array = model["kits"]
	if kits.size() < 2:
		return
	model["kit_index"] = posmod(int(model["kit_index"]) + delta, kits.size())
	_status = ""
	_refresh()


func _on_side_confirm(side: int, _input: Dictionary) -> void:
	var model: Dictionary = sides[side]
	if _error:
		_reload()
		return
	if bool(model["ready"]) or not bool(model["live"]):
		return
	if (model["kits"] as Array).is_empty():
		_status = "No kits available for this team."
		_refresh()
		return
	model["ready"] = true
	_status = ""
	if parallel:
		_refresh()
		if bool(sides[0]["ready"]) and bool(sides[1]["ready"]):
			_go_prematch()
		return
	if side == human_side:
		active_side = 1 - human_side
		sides[active_side]["device"] = (sides[human_side]["device"] as Dictionary).duplicate(true)
		_refresh()
		return
	_go_prematch()


func _on_side_cancel(side: int, _input: Dictionary) -> void:
	if _error:
		_leave()
		return
	var model: Dictionary = sides[side]
	if bool(model["ready"]):
		model["ready"] = false
		if not parallel:
			active_side = side
		_refresh()
		return
	if not parallel and active_side != human_side and bool(sides[human_side]["ready"]):
		sides[human_side]["ready"] = false
		active_side = human_side
		_refresh()
		return
	_leave()


func _go_prematch() -> void:
	if _leaving:
		return
	_leaving = true
	ShellState.set_kit(0, sides[0]["kits"][int(sides[0]["kit_index"])])
	ShellState.set_kit(1, sides[1]["kits"][int(sides[1]["kit_index"])])
	UiTransition.change_scene(PREMATCH_SCENE)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	UiTransition.change_scene(TEAM_SELECT_SCENE)
