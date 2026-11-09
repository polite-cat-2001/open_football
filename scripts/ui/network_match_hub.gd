extends Control
# Network adapter for the shared MatchHubView. The lobby owns the teams, the
# sides and the kickoff options; the host alone edits the options and starts.
# The client mirrors the lobby snapshot and waits for MatchSetup.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"
const KIT_SCENE := "res://scenes/network_kit_select.tscn"
const MATCH_SCENE := "res://scenes/gpf_slice.tscn"
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
const NETWORK_MATCH := preload("res://scripts/net/network_match.gd")

@export var data_root := ""

@onready var view: MatchHubView = $MatchHubView

var catalog := TeamCatalog.new()
var kit_catalog := KitCatalog.new()

var home_lineup: MatchLineup
var away_lineup: MatchLineup
var back_vote: NetworkBackVote

var _host := false
var _local_id := -1
var _lobby: Dictionary = {}
var _status := ""
var _back_status := ""
var _leaving := false
var _match_started := false
var _last_revision := -1
var _start_vote := false
var _last_options: Dictionary = {}


func _ready() -> void:
	view.start_requested.connect(_on_start_requested)
	view.back_requested.connect(_on_back_requested)
	view.game_plan_requested.connect(_on_game_plan_requested)
	view.options_requested.connect(_on_options_requested)
	view.lineup_changed.connect(_on_lineups_changed)
	view.option_changed.connect(_on_option_changed)
	view.exit_requested.connect(_on_exit_requested)
	_setup_back_vote()
	_load_data()
	_poll_lobby()
	set_process(true)


func _setup_back_vote() -> void:
	back_vote = NetworkBackVote.new()
	back_vote.name = "BackVote"
	_back_vote_parent().add_child(back_vote)
	back_vote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_vote.setup(NetworkBackVote.VOTE_BACK_TO_TEAMS)
	back_vote.action_agreed.connect(_on_back_agreed)
	back_vote.state_changed.connect(_on_back_status)
	if NetShell.is_active(get_tree()):
		back_vote.clear_server_vote()


func _back_vote_parent() -> Control:
	return view.design if view != null and view.design != null else self


func _load_data() -> void:

	if not catalog.load_data_root(data_root):
		_leave_session()
		return
	kit_catalog.load_data_root(data_root)
	if not _populate_teams_from_lobby():
		_leave_session()
		return
	var home_squad := catalog.load_squad(int(ShellState.home_team.get("id", 0)))
	var away_squad := catalog.load_squad(int(ShellState.away_team.get("id", 0)))
	if home_squad.is_empty() or away_squad.is_empty():
		_leave_session()
		return
	home_lineup = MatchLineup.from_squad(home_squad)
	away_lineup = MatchLineup.from_squad(away_squad)
	view.setup_game_plan(home_lineup, away_lineup, [_local_team()], {
		"network": true,
		"local_two_player": false,
	})
	_ensure_network_package()


func _ensure_network_package() -> void:
	var runtime := NET_SHELL.runtime(get_tree())
	if runtime == null:
		return
	var ids: Array = _lobby.get("team_ids", [])
	if ids.size() != 2:
		return
	var builder := MatchPackage.new()
	if not catalog.load_data_root(data_root):
		_status = catalog.error
		return
	var package := builder.build(catalog, ShellState.home_team, ShellState.away_team,
		_lobby_options(), {},
		{"home": ShellState.kit_home, "away": ShellState.kit_away})
	if package.is_empty():
		_status = builder.error
		return
	ShellState.set_match_package(package)
	if not bool(runtime.set_match_package(package)):
		_status = runtime.get_last_error()


func _populate_teams_from_lobby() -> bool:
	var info := NET_SHELL.lobby(get_tree())
	if info.is_empty():
		return false
	_lobby = info.get("lobby", {})
	var ids: Array = _lobby.get("team_ids", [])
	if ids.size() != 2 or int(ids[0]) <= 0 or int(ids[1]) <= 0:
		return false
	if ShellState.has_selection() \
			and int(ShellState.home_team.get("id", 0)) == int(ids[0]) \
			and int(ShellState.away_team.get("id", 0)) == int(ids[1]):
		return true
	var home := catalog.team_by_id(int(ids[0]))
	var away := catalog.team_by_id(int(ids[1]))
	if home.is_empty() or away.is_empty():
		return false
	ShellState.set_teams(home, away)
	return true


func _poll_lobby() -> void:
	if _leaving or _match_started:
		return
	var info := NET_SHELL.lobby(get_tree())
	if info.is_empty() or not bool(info.get("active", false)):
		_leave_session()
		return
	if bool(info.get("is_client", false)) and int(info.get("connection", 0)) == 0:
		_leave_session()
		return
	_lobby = info.get("lobby", {})
	_host = bool(info.get("is_host", false))
	_local_id = int(info.get("local_id", -1))
	var phase := int(_lobby.get("phase", -1))
	if phase == 0:
		_leaving = true
		if back_vote != null:
			back_vote.withdraw()
		UiTransition.change_scene(SIDES_SCENE)
		return
	if phase == 1:
		_leaving = true
		if back_vote != null:
			back_vote.withdraw()
		UiTransition.change_scene(LOBBY_SCENE)
		return
	if phase != 2:
		_leave_session()
		return
	var options := _lobby_options()
	if not _last_options.is_empty() and options != _last_options and _start_vote:
		# Host-side option changes invalidate a previous confirmation.
		_withdraw_start_vote()
	_last_options = options
	var revision := int(_lobby.get("revision", -1))
	if revision != _last_revision:
		_last_revision = revision
		_refresh_state()
	if _host and not _match_started and int(_lobby.get("hub_vote", 0)) == 2:
		_start_host()
	if not _host:
		var runtime := NET_SHELL.active_runtime(get_tree())
		if runtime != null:
			var setup: Dictionary = runtime.net_take_match_setup()
			if not setup.is_empty():
				_start_client(setup)


func _refresh_state() -> void:
	if home_lineup == null or away_lineup == null:
		return
	var options := _lobby_options()
	ShellState.set_match_options(options)
	var sides: Array = []
	for index in 2:
		var team: Dictionary = ShellState.home_team if index == 0 else ShellState.away_team
		var lineup: MatchLineup = home_lineup if index == 0 else away_lineup
		var owner := _owner_for_side(index)
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
			"device": _controller_for_side(index),
			"owner": owner,
		})
	var status := _back_status
	if status.is_empty():
		status = _status
	var votes := _start_vote_count()
	var peers := _peer_count()
	if status.is_empty():
		status = "WAITING FOR OTHER PLAYER" if _start_vote else \
			("START MATCH WHEN READY" if _host else "WAITING FOR HOST")
	var start_label := "STARTING..." if _match_started else "START MATCH (%d/%d)" % [votes, peers]
	if _start_vote and not _match_started:
		start_label = "WAITING FOR OTHER PLAYER"
	view.setup({
		"meta": {
			"competition": MatchHubState.competition_name(catalog, ShellState.home_team,
				ShellState.away_team),
			"difficulty": options["difficulty"],
			"duration": options["duration"],
		},
		"sides": sides,
		"options": {
			"difficulty": options["difficulty"],
			"duration": options["duration"],
			"editable": _host and not _match_started,
		},
		"flags": {
			"can_start": not _match_started,
			"can_manage": true,
			"can_options": true,
			"network": true,
			"settings_sides": false,
			"host": _host,
			"client": not _host,
			"local_two_player": false,
			"start_label": start_label,
			"start_votes": votes,
			"start_votes_needed": peers,
		},
		"status": status,
		"status_error": false,
		"error": false,
	}, {"back_label": "back"})


func _lobby_options() -> Dictionary:
	return {
		"difficulty": float(_lobby.get("match_difficulty", 0.8)),
		"duration": float(_lobby.get("match_duration", 1.0)),
	}


func _owner_for_side(side: int) -> String:
	for player in _lobby.get("players", []):
		if int(player.get("side", -1)) != side:
			continue
		var name := str(player.get("name", ""))
		if int(player.get("id", -1)) == _local_id:
			return "YOU  " + name
		return name
	return ""


func _controller_for_side(side: int) -> Dictionary:
	for controller in ShellState.controllers:
		if controller is Dictionary and _side_index(controller) == side:
			return (controller as Dictionary).duplicate(true)
	return {
		"kind": "keyboard",
		"device": 0,
		"name": "Keyboard",
		"side": "home" if side == 0 else "away",
	}


func _side_index(controller: Dictionary) -> int:
	return 1 if str(controller.get("side", "home")) == "away" else 0


func _on_start_requested(_input: Dictionary) -> void:
	if _match_started:
		return
	if _start_vote:
		_withdraw_start_vote()
		return
	_start_vote = true
	NET_SHELL.action(get_tree(), "hubvote", 0, 2, 0)
	_refresh_state()


func _withdraw_start_vote() -> void:
	if _match_started:
		return
	if _start_vote:
		_start_vote = false
		NET_SHELL.action(get_tree(), "hubvote", 0, 0, 0)
		_refresh_state()


func _start_vote_count() -> int:
	var count := 0
	for player in _lobby.get("players", []):
		if int(player.get("hub_vote", 0)) == 2:
			count += 1
	return count


func _peer_count() -> int:
	var players: Array = _lobby.get("players", [])
	return maxi(1, players.size())


func _local_team() -> int:
	for player in _lobby.get("players", []):
		if int(player.get("id", -1)) == _local_id:
			return 0 if int(player.get("side", 0)) == 0 else 1
	return 0


func _start_host() -> void:
	var info := NET_SHELL.lobby(get_tree())
	var lobby: Dictionary = info.get("lobby", _lobby)
	var ids: Array = lobby.get("team_ids", [])
	var runtime := NET_SHELL.active_runtime(get_tree())
	if runtime == null:
		_status = "Network session is gone."
		_refresh_state()
		return
	if back_vote != null:
		back_vote.withdraw()
	# The package (and its pre-match MatchData) was built when the hub opened;
	# plan swaps have been applied to it. Do not rebuild it here or the edits
	# would be lost.
	_ensure_network_package()
	if not bool(runtime.net_start()):
		_status = runtime.get_last_error()
		_refresh_state()
		return
	_match_started = true
	UiTransition.change_scene(MATCH_SCENE)


func _start_client(setup: Dictionary) -> void:
	if _match_started:
		return
	var runtime := NET_SHELL.active_runtime(get_tree())
	if runtime == null or not ShellState.has_package():
		var package := NETWORK_MATCH.apply_setup(get_tree(), runtime, setup, _lobby_options(),
			data_root)
		if package.is_empty():
			_status = NETWORK_MATCH.error
			_refresh_state()
			return
	_match_started = true
	UiTransition.change_scene(MATCH_SCENE)


func _on_back_requested(_input: Dictionary) -> void:
	if _match_started:
		return
	_withdraw_start_vote()
	if back_vote != null:
		back_vote.withdraw()
	_leaving = true
	UiTransition.change_scene(KIT_SCENE)


func _on_back_agreed(action: int) -> void:
	if action == NetworkBackVote.VOTE_LEAVE_SESSION:
		_leave_session()
	else:
		_back_status = "GOING BACK TO TEAM SELECT..."
		_refresh_state()


func _on_back_status(status: String) -> void:
	_back_status = status
	_refresh_state()


func _on_game_plan_requested() -> void:
	# Entering the plan (or any hub submenu) invalidates this peer's kickoff
	# confirmation; it must press Start again after leaving.
	_withdraw_start_vote()


func _on_options_requested() -> void:
	_withdraw_start_vote()


func _on_lineups_changed() -> void:
	_withdraw_start_vote()
	_refresh_state()


func _on_option_changed(field: String, value: float) -> void:
	if not _host:
		return
	_withdraw_start_vote()
	var field_index := 0 if field == "difficulty" else 1
	_lobby["match_difficulty" if field == "difficulty" else "match_duration"] = value
	NET_SHELL.action(get_tree(), "set_match_options", 0, field_index,
		int(round(value * 1000.0)))
	_refresh_state()


func _on_exit_requested() -> void:
	if _match_started:
		return
	_withdraw_start_vote()
	if back_vote != null:
		back_vote.withdraw()
	_leaving = true
	call_deferred("_do_exit_to_main_menu")


func _do_exit_to_main_menu() -> void:
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	UiTransition.change_scene(MAIN_MENU_SCENE)


func _leave_session() -> void:
	if _leaving:
		return
	_leaving = true
	if back_vote != null:
		back_vote.withdraw()
	call_deferred("_do_leave_session")


func _do_leave_session() -> void:
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	UiTransition.change_scene(NETWORK_MENU_SCENE)


func _process(_delta: float) -> void:
	_poll_lobby()

