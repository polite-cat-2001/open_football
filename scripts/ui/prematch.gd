extends Control
# Local adapter for the shared MatchHubView. It owns the catalog, the editable
# MatchLineup models, the package build and the local 2P start vote; layout and
# input live in the view.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const KIT_SCENE := "res://scenes/kit_select.tscn"
const TEAM_SELECT_SCENE := "res://scenes/team_select.tscn"
const MATCH_SCENE := "res://scenes/gpf_slice.tscn"

@export var data_root := ""

@onready var view: MatchHubView = $MatchHubView

var catalog := TeamCatalog.new()
var package_builder := MatchPackage.new()
var kit_catalog := KitCatalog.new()

var home_lineup: MatchLineup
var away_lineup: MatchLineup

var _match_started := false
var _status := ""


func _ready() -> void:
	view.start_requested.connect(_on_start_requested)
	view.back_requested.connect(_on_back_requested)
	view.game_plan_requested.connect(_on_game_plan_requested)
	view.lineup_changed.connect(_on_lineups_changed)
	view.option_changed.connect(_on_option_changed)
	view.exit_requested.connect(_on_exit_requested)
	if not catalog.load_data_root(data_root):
		_leave_to(TEAM_SELECT_SCENE)
		return
	kit_catalog.load_data_root(data_root)
	_load_lineups()
	_refresh_state()


func _load_lineups() -> void:
	if not ShellState.has_selection():
		_leave_to(TEAM_SELECT_SCENE)
		return
	var home_squad := catalog.load_squad(int(ShellState.home_team.get("id", 0)))
	var away_squad := catalog.load_squad(int(ShellState.away_team.get("id", 0)))
	if home_squad.is_empty() or away_squad.is_empty():
		_leave_to(TEAM_SELECT_SCENE)
		return
	home_lineup = MatchLineup.from_squad(home_squad)
	away_lineup = MatchLineup.from_squad(away_squad)
	view.setup_game_plan(home_lineup, away_lineup, _human_teams(), {
		"local_two_player": _device_keys().size() > 1,
	})


func _refresh_state() -> void:
	if home_lineup == null or away_lineup == null:
		return
	var validation_ok := _lineups_valid()
	var message := _lineup_message()
	_status = "" if validation_ok else message
	var start_label := "STARTING..." if _match_started else "START MATCH"
	view.setup(_build_state(start_label), {"back_label": "back"})


func _build_state(start_label: String) -> Dictionary:
	var sides: Array = []
	for index in 2:
		var team: Dictionary = ShellState.home_team if index == 0 else ShellState.away_team
		var lineup: MatchLineup = home_lineup if index == 0 else away_lineup
		var controller := _controller_for_side(index)
		sides.append({
			"side": index,
			"label": "HOME" if index == 0 else "AWAY",
			"team": {
				"name": str(team.get("name", "")),
				"texture": UiAssets.usable_texture(UiAssets.team_logo(team)),
				"rating": catalog.load_team_rating(int(team.get("id", 0))),
			},
			"lineup": MatchHubState.lineup_rows(lineup),
			"kit": MatchHubState.kit_for_side(kit_catalog, index, team),
			"device": controller,
			"owner": str(controller.get("name", "")),
		})
	var options := ShellState.match_options
	var devices := _device_keys()
	return {
		"meta": {
			"competition": MatchHubState.competition_name(catalog, ShellState.home_team,
				ShellState.away_team),
			"difficulty": float(options.get("difficulty", 0.8)),
			"duration": float(options.get("duration", 1.0)),
		},
		"sides": sides,
		"options": {
			"difficulty": float(options.get("difficulty", 0.8)),
			"duration": float(options.get("duration", 1.0)),
			"editable": not _match_started,
		},
		"flags": {
			"can_start": _lineups_valid() and not _match_started,
			"can_manage": true,
			"can_options": not _match_started,
			"network": false,
			"host": true,
			"client": false,
			"local_two_player": devices.size() > 1,
			"start_label": start_label,
			"start_votes": 0,
			"start_votes_needed": 1,
		},
		"status": _status,
		"status_error": false,
		"error": false,
	}


func _controller_for_side(side: int) -> Dictionary:
	for controller in ShellState.controllers:
		if controller is Dictionary and _side_index(controller) == side:
			return (controller as Dictionary).duplicate(true)
	return {"kind": "keyboard", "device": 0, "name": "Keyboard", "side": "home" if side == 0 else "away"}


func _side_index(controller: Dictionary) -> int:
	return 1 if str(controller.get("side", "home")) == "away" else 0


func _human_teams() -> Array:
	var teams: Array = []
	for controller in ShellState.controllers:
		if not (controller is Dictionary):
			continue
		var team_id := _side_index(controller)
		if not teams.has(team_id):
			teams.append(team_id)
	if teams.is_empty():
		teams = [0]
	teams.sort()
	return teams


func _device_keys() -> Array:
	var keys: Array = []
	for controller in ShellState.controllers:
		if not (controller is Dictionary):
			continue
		var key := "%s:%d" % [str(controller.get("kind", "keyboard")),
			int(controller.get("device", 0))]
		if not keys.has(key):
			keys.append(key)
	if keys.is_empty():
		keys.append("keyboard:0")
	return keys


func _input_device_key(input: Dictionary) -> String:
	var kind := str(input.get("kind", "keyboard"))
	var device_id := int(input.get("device", 0))
	for controller in ShellState.controllers:
		if not (controller is Dictionary):
			continue
		if str(controller.get("kind", "keyboard")) != kind:
			continue
		if kind == "gamepad" and int(controller.get("device", -1)) != device_id:
			continue
		return "%s:%d" % [kind, int(controller.get("device", 0))]
	return ""


func _lineups_valid() -> bool:
	if home_lineup == null or away_lineup == null:
		return false
	return bool(home_lineup.validate().get("ok", false)) \
		and bool(away_lineup.validate().get("ok", false))


func _lineup_message() -> String:
	if home_lineup == null or away_lineup == null:
		return "Lineups are not loaded."
	var validation := home_lineup.validate()
	if not bool(validation.get("ok", false)):
		return "Home lineup: " + str(validation.get("error", ""))
	validation = away_lineup.validate()
	if not bool(validation.get("ok", false)):
		return "Away lineup: " + str(validation.get("error", ""))
	return ""


func _on_start_requested(_input: Dictionary) -> void:
	# Local 2P has no kickoff vote: the plan's READY gate is the only shared
	# confirmation, so one Start press begins the match.
	if _match_started or not _lineups_valid():
		return
	_start_match()


func _on_back_requested(_input: Dictionary) -> void:
	_leave_to(KIT_SCENE)


func _on_game_plan_requested() -> void:
	_refresh_state()


func _on_lineups_changed() -> void:
	_refresh_state()


func _on_option_changed(field: String, value: float) -> void:
	var options := ShellState.match_options.duplicate(true)
	options[field] = value
	ShellState.set_match_options(options)
	_refresh_state()


func _on_exit_requested() -> void:
	if _match_started:
		return
	UiTransition.change_scene(MAIN_MENU_SCENE)


func build_package() -> Dictionary:
	package_builder.error = ""
	if not ShellState.has_selection():
		package_builder.error = "Choose two teams first."
		return {}
	if home_lineup == null or away_lineup == null:
		package_builder.error = "Lineups are not loaded."
		return {}
	if not _lineups_valid():
		package_builder.error = _lineup_message()
		return {}
	if not catalog.load_data_root(data_root):
		package_builder.error = catalog.error
		return {}
	var options := {
		"duration": float(ShellState.match_options.get("duration", 1.0)),
		"difficulty": float(ShellState.match_options.get("difficulty", 0.8)),
	}
	var lineups := {"home": home_lineup, "away": away_lineup}
	var kits := {"home": ShellState.kit_home, "away": ShellState.kit_away}
	var package := package_builder.build(catalog, ShellState.home_team, ShellState.away_team,
		options, lineups, kits)
	if package.is_empty():
		package_builder.error = package_builder.error if not package_builder.error.is_empty() \
			else "Match package could not be built."
		return {}
	ShellState.set_match_package(package)
	return package


func _start_match() -> void:
	if _match_started:
		return
	var package := build_package()
	if package.is_empty():
		_status = package_builder.error
		_refresh_state()
		return
	_match_started = true
	# No state refresh here: disabling START would make the hub jump its
	# selection to TEAM MANAGEMENT while the scene fades out.
	UiTransition.change_scene(MATCH_SCENE)


func _leave_to(path: String) -> void:
	if is_inside_tree():
		call_deferred("_do_leave", path)


func _do_leave(path: String) -> void:
	UiTransition.change_scene(path)
