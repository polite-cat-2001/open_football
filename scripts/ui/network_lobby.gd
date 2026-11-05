extends Control
# Network adapter for TeamSelectView: both sides come from the host-authoritative
# lobby snapshot; only the local chooser slots are editable. Every edit goes back
# through the old set_selection/set_team_ready actions.

const NETWORK_MENU_SCENE := "res://scenes/network_menu.tscn"
const SIDES_SCENE := "res://scenes/network_sides.tscn"
const KIT_SCENE := "res://scenes/network_kit_select.tscn"
const NET_SHELL := preload("res://scripts/net/net_shell.gd")
const UI_ASSETS := preload("res://scripts/data/ui_assets.gd")

const FIELD_COUNTRY := "country"
const FIELD_COMPETITION := "competition"
const FIELD_TEAM := "team"

@export var data_root := ""

@onready var view: TeamSelectView = $TeamSelectView

var catalog := TeamCatalog.new()
var national_league_id := -1
var country_entries: Array = []
var sides: Array = []
var back_vote: NetworkBackVote

var _local_id := -1
var _chooser_sides: Array = []
var _default_sent := [false, false]
var _applying := false
var _last_revision := -1
var _last_device := -1
var _input_device := {"kind": "keyboard", "device": 0}
var _catalog_error := false
var _status := ""
var _status_error := false
var _leaving := false
var _last_signature := ""
var _back_status := ""


func _ready() -> void:
	add_to_group(&"ui_shell")
	theme = UiTheme.load_or_build()
	_sides_init()
	view.side_move_requested.connect(_on_side_move)
	view.side_confirm_requested.connect(_on_side_confirm)
	view.side_cancel_requested.connect(_on_side_cancel)
	view.back_requested.connect(_request_back)
	view.retry_requested.connect(_reload)
	_setup_back_vote()
	_load_catalog()
	_poll_lobby()
	set_process(true)


func _setup_back_vote() -> void:
	back_vote = NetworkBackVote.new()
	back_vote.name = "BackVote"
	_back_vote_parent().add_child(back_vote)
	back_vote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_vote.setup(NetworkBackVote.VOTE_BACK_TO_SIDES)
	back_vote.action_agreed.connect(_on_back_agreed)
	back_vote.state_changed.connect(_on_back_status)
	if NetShell.is_active(get_tree()):
		back_vote.clear_server_vote()


func _back_vote_parent() -> Control:
	return view.design if view != null and view.design != null else self


func _sides_init() -> void:

	sides = [
		_side_model(0),
		_side_model(1),
	]


func _side_model(side: int) -> Dictionary:
	return {
		"side": side,
		"country_index": 0,
		"league_index": 0,
		"team_index": 0,
		"league_entries": [],
		"team_entries": [],
		"ready": false,
		"editable": false,
		"live": false,
		"owner": "",
		"device": {"kind": "keyboard", "device": 0},
	}


func _load_catalog() -> void:
	_catalog_error = false
	if not catalog.load_data_root(data_root):
		_catalog_error = true
		_status = catalog.error
		_clear_entries()
		_refresh()
		return
	national_league_id = catalog.national_league_id()
	_build_country_entries()
	if country_entries.is_empty():
		_catalog_error = true
		_status = "No teams in the database."
		_clear_entries()
		_refresh()


func _reload() -> void:
	_default_sent = [false, false]
	_last_signature = ""
	_load_catalog()
	if not _catalog_error:
		_last_revision = -1
		_poll_lobby()


func _clear_entries() -> void:
	country_entries.clear()
	for side in sides:
		side["league_entries"] = []
		side["team_entries"] = []
		side["ready"] = false
		side["editable"] = false
		side["live"] = false


func _build_country_entries() -> void:
	country_entries.clear()
	if national_league_id >= 0:
		country_entries.append({
			"id": "national",
			"name": TeamCatalog.NATIONAL_LEAGUE_NAME,
			"texture": null,
			"_texture_loaded": true,
		})
	for country in catalog.countries():
		country_entries.append({
			"id": str(country.get("id", 0)),
			"name": str(country.get("name", "")),
			"tm_id": str(country.get("tm_id", "")),
			"_texture_loaded": false,
		})


func _apply_country(side: Dictionary) -> void:
	side["league_index"] = 0
	side["team_index"] = 0
	var entry := _country_entry(side)
	if str(entry.get("id", "")) == "national":
		side["league_entries"] = [{
			"id": str(national_league_id),
			"name": TeamCatalog.NATIONAL_LEAGUE_NAME,
			"texture": null,
			"_texture_loaded": true,
		}]
		_setup_teams(side, national_league_id)
		return
	var country_id := int(str(entry.get("id", "0")))
	side["league_entries"] = _league_entries(country_id)
	_setup_teams(side, _league_id(side))


func _apply_league(side: Dictionary) -> void:
	side["team_index"] = 0
	_setup_teams(side, _league_id(side))


func _setup_teams(side: Dictionary, league_id: int) -> void:
	side["team_entries"] = _team_entries(league_id)
	if int(side["team_index"]) >= (side["team_entries"] as Array).size():
		side["team_index"] = 0


func _league_entries(country_id: int) -> Array:
	var entries: Array = []
	for league in catalog.leagues_for_country(country_id):
		entries.append({
			"id": str(league.get("id", 0)),
			"name": str(league.get("name", "")),
			"logo_url": str(league.get("logo_url", "")),
			"_texture_loaded": false,
		})
	return entries


func _team_entries(league_id: int) -> Array:
	var entries: Array = []
	for team in catalog.teams_for_league(league_id):
		entries.append({
			"id": str(team.get("id", 0)),
			"name": str(team.get("name", "")),
			"logo_url": str(team.get("logo_url", "")),
			"_texture_loaded": false,
		})
	return entries


func _country_entry(side: Dictionary) -> Dictionary:
	var index := clampi(int(side["country_index"]), 0, maxi(0, country_entries.size() - 1))
	side["country_index"] = index
	if country_entries.is_empty():
		return {}
	return _ensure_texture(country_entries[index], "country")


func _league_entry(side: Dictionary) -> Dictionary:
	var entries: Array = side["league_entries"]
	if entries.is_empty():
		return {}
	var index := clampi(int(side["league_index"]), 0, entries.size() - 1)
	side["league_index"] = index
	return _ensure_texture(entries[index], "league")


func _team_entry(side: Dictionary) -> Dictionary:
	var entries: Array = side["team_entries"]
	if entries.is_empty():
		return {}
	var index := clampi(int(side["team_index"]), 0, entries.size() - 1)
	side["team_index"] = index
	return _ensure_texture(entries[index], "team")


func _ensure_texture(entry: Dictionary, kind: String) -> Dictionary:
	if bool(entry.get("_texture_loaded", false)):
		return entry
	match kind:
		"country":
			entry["texture"] = UI_ASSETS.usable_texture(UI_ASSETS.country_flag(entry))
		"league":
			entry["texture"] = UI_ASSETS.usable_texture(UI_ASSETS.league_logo(entry))
		_:
			entry["texture"] = UI_ASSETS.usable_texture(UI_ASSETS.team_logo(entry))
	entry["_texture_loaded"] = true
	return entry


func _league_id(side: Dictionary) -> int:
	return int(str(_league_entry(side).get("id", "0")))


func _team_id(side: Dictionary) -> int:
	return int(str(_team_entry(side).get("id", "0")))


func _poll_lobby() -> void:
	if _leaving:
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
	if phase == 2:
		_enter_kits(lobby)
		return

	var revision := int(lobby.get("revision", -1))
	if revision != _last_revision:
		_last_revision = revision
		_apply_lobby_state(lobby)

	_local_id = int(info.get("local_id", -1))
	_chooser_sides = _chooser_sides_for(lobby, _local_id)
	_update_owners(lobby)
	for side in _chooser_sides:
		_seed_defaults(int(side))
	_refresh()


func _chooser_sides_for(lobby: Dictionary, local_id: int) -> Array:
	var chooser: Array = lobby.get("chooser", [])
	var result: Array = []
	for side in 2:
		if side < chooser.size() and int(chooser[side]) == local_id:
			result.append(side)
	return result


func _apply_lobby_state(lobby: Dictionary) -> void:
	if _catalog_error:
		return
	_applying = true
	var countries: Array = lobby.get("country_ids", [])
	var leagues: Array = lobby.get("league_ids", [])
	var teams: Array = lobby.get("team_ids", [])
	var ready: Array = lobby.get("team_ready", [])
	for side in sides:
		var index := int(side["side"])
		var country_id := int(countries[index]) if index < countries.size() else -1
		var country_index := _find_country_index(country_id)
		side["country_index"] = country_index
		_apply_country(side)
		var league_id := int(leagues[index]) if index < leagues.size() else -1
		if league_id > 0:
			var league_index := _find_entry_index(side["league_entries"], str(league_id))
			if league_index >= 0:
				side["league_index"] = league_index
				_apply_league(side)
		var team_id := int(teams[index]) if index < teams.size() else -1
		if team_id > 0:
			var team_index := _find_entry_index(side["team_entries"], str(team_id))
			if team_index >= 0:
				side["team_index"] = team_index
		side["ready"] = bool(ready[index]) if index < ready.size() else false
	_applying = false


func _find_country_index(country_id: int) -> int:
	if country_id <= 0 and national_league_id >= 0:
		return 0
	for index in country_entries.size():
		if str(country_entries[index].get("id", "")) == str(country_id):
			return index
	return 0


func _find_entry_index(entries: Array, id: String) -> int:
	for index in entries.size():
		if str(entries[index].get("id", "")) == id:
			return index
	return -1


func _seed_defaults(side_index: int) -> void:
	if _applying or _catalog_error or bool(_default_sent[side_index]):
		return
	var side: Dictionary = sides[side_index]
	# Open a fresh LAN match on the same pair Quick Match shows by default.
	var default_team_id := ShellState.DEFAULT_HOME_TEAM_ID if side_index == 0 \
		else ShellState.DEFAULT_AWAY_TEAM_ID
	if not _select_team_by_id(side, default_team_id):
		# The catalog may not contain the default team; keep the first entry.
		if _team_entry(side).is_empty():
			return
	var country := _country_entry(side)
	var league := _league_entry(side)
	var team := _team_entry(side)
	if country.is_empty() or team.is_empty():
		return
	_default_sent[side_index] = true
	var country_id := 0 if str(country.get("id", "")) == "national" \
		else int(str(country.get("id", "0")))
	NET_SHELL.action(get_tree(), "set_selection", side_index, 0, country_id)
	var league_id := int(str(league.get("id", "0")))
	if league_id > 0:
		NET_SHELL.action(get_tree(), "set_selection", side_index, 1, league_id)
	var team_id := int(str(team.get("id", "0")))
	if team_id > 0:
		NET_SHELL.action(get_tree(), "set_selection", side_index, 2, team_id)


func _select_team_by_id(side: Dictionary, team_id: int) -> bool:
	if team_id <= 0:
		return false
	var team := catalog.team_by_id(team_id)
	if team.is_empty():
		return false
	var league := catalog.league_by_id(int(team.get("league_id", 0)))
	if league.is_empty():
		return false
	var country_index := _country_index_for_id(int(league.get("country_id", 0)))
	if country_index < 0:
		return false
	side["country_index"] = country_index
	_apply_country(side)
	var league_index := _find_entry_index(side["league_entries"],
		str(league.get("id", 0)))
	if league_index < 0:
		return false
	side["league_index"] = league_index
	_apply_league(side)
	var team_index := _find_entry_index(side["team_entries"], str(team_id))
	if team_index < 0:
		return false
	side["team_index"] = team_index
	return true


func _country_index_for_id(country_id: int) -> int:
	for index in country_entries.size():
		var id := str(country_entries[index].get("id", ""))
		if id == "national":
			if country_id == 0:
				return index
		elif id == str(country_id):
			return index
	return -1


func _update_owners(lobby: Dictionary) -> void:
	var owners := [{}, {}]
	for player in lobby.get("players", []):
		var side := int(player.get("side", -1))
		if side < 0 or side > 1:
			continue
		var owner := str(player.get("name", ""))
		if int(player.get("id", -1)) == _local_id:
			owner = "YOU  " + owner
		owners[side] = {"name": owner}
	for side in sides:
		var index := int(side["side"])
		side["owner"] = str(owners[index].get("name", ""))
		side["device"] = _input_device


func _refresh() -> void:
	if view == null:
		return
	for side in sides:
		var index := int(side["side"])
		side["editable"] = not _catalog_error and _chooser_sides.has(index)
		side["live"] = side["editable"] and not bool(side["ready"])
	var signature := _signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	view.setup(_build_state(), {
		"back_label": "leave",
		"status": _effective_status(),
		"status_error": _status_error and _back_status.is_empty(),
	})


func _effective_status() -> String:
	return _back_status if not _back_status.is_empty() else _status


func _signature() -> String:
	var parts: Array[String] = [str(_status), str(_status_error), str(_catalog_error),
		str(_back_status)]
	for side in sides:
		var device: Dictionary = side["device"]
		parts.append("%d/%d/%d/%d/%d/%d/%s/%s:%d" % [
			int(side["country_index"]),
			int(side["league_index"]),
			int(side["team_index"]),
			1 if bool(side["ready"]) else 0,
			1 if bool(side["live"]) else 0,
			1 if bool(side["editable"]) else 0,
			str(side.get("owner", "")),
			str(device.get("kind", "keyboard")),
			int(device.get("device", 0)),
		])
	return "|".join(parts)


func _build_state() -> Dictionary:
	var side_states: Array = []
	for side in sides:
		var team := _team_entry(side)
		var rating := {}
		if not team.is_empty() and not _catalog_error:
			rating = catalog.load_team_rating(int(str(team.get("id", "0"))))
		side_states.append({
			"side": int(side["side"]),
			"label": "HOME" if int(side["side"]) == 0 else "AWAY",
			"owner": str(side.get("owner", "")),
			"ready": bool(side["ready"]),
			"live": bool(side["live"]),
			"editable": bool(side["editable"]),
			"device": side["device"],
			"country": _country_entry(side),
			"competition": _league_entry(side),
			"team": team,
			"rating": rating,
			"choices": {
				"country": country_entries.size(),
				"competition": (side["league_entries"] as Array).size(),
				"team": (side["team_entries"] as Array).size(),
			},
		})
	return {
		"sides": side_states,
		"status": _effective_status(),
		"status_error": _status_error and _back_status.is_empty(),
		"error": _catalog_error,
	}


func _note_input(input: Dictionary) -> void:
	var kind := str(input.get("kind", "keyboard"))
	var device_id := int(input.get("device", 0))
	_input_device = {"kind": kind, "device": device_id}
	_send_device(0 if kind == "keyboard" else 1)
	NET_SHELL.note_local_device(get_tree(), kind, device_id)


func _send_device(device: int) -> void:
	if device == _last_device:
		return
	_last_device = device
	NET_SHELL.action(get_tree(), "set_device", 0, device, 0)


func _on_side_move(side: int, field: String, delta: int, input: Dictionary) -> void:
	_note_input(input)
	var model: Dictionary = sides[side]
	if _catalog_error or _applying or not bool(model["editable"]) or delta == 0:
		return
	match field:
		FIELD_COUNTRY:
			var count := country_entries.size()
			if count <= 1:
				return
			model["country_index"] = posmod(int(model["country_index"]) + delta, count)
			_apply_country(model)
		FIELD_COMPETITION:
			var leagues: Array = model["league_entries"]
			if leagues.size() <= 1:
				return
			model["league_index"] = posmod(int(model["league_index"]) + delta, leagues.size())
			_apply_league(model)
		FIELD_TEAM:
			var teams: Array = model["team_entries"]
			if teams.size() <= 1:
				return
			model["team_index"] = posmod(int(model["team_index"]) + delta, teams.size())
	_status = ""
	_status_error = false
	_send_selection(side, field)
	_refresh()


func _send_selection(side: int, field: String) -> void:
	if _applying:
		return
	var model: Dictionary = sides[side]
	var country := _country_entry(model)
	var league := _league_entry(model)
	var team := _team_entry(model)
	if field == FIELD_COUNTRY:
		var country_id := 0 if str(country.get("id", "")) == "national" \
			else int(str(country.get("id", "0")))
		NET_SHELL.action(get_tree(), "set_selection", side, 0, country_id)
		if str(country.get("id", "")) == "national":
			var national_team := int(str(team.get("id", "0")))
			if national_team > 0:
				NET_SHELL.action(get_tree(), "set_selection", side, 2, national_team)
			return
		var league_id := int(str(league.get("id", "0")))
		if league_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 1, league_id)
		var default_team := int(str(team.get("id", "0")))
		if default_team > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 2, default_team)
	elif field == FIELD_COMPETITION:
		var league_id := int(str(league.get("id", "0")))
		if league_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 1, league_id)
		var team_id := int(str(team.get("id", "0")))
		if team_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 2, team_id)
	else:
		var team_id := int(str(team.get("id", "0")))
		if team_id > 0:
			NET_SHELL.action(get_tree(), "set_selection", side, 2, team_id)


func _on_side_confirm(side: int, input: Dictionary) -> void:
	_note_input(input)
	var model: Dictionary = sides[side]
	if _catalog_error:
		_reload()
		return
	if not bool(model["editable"]) or bool(model["ready"]):
		return
	var team := _team_entry(model)
	if team.is_empty():
		_set_status("Choose a team.", true)
		return
	if not catalog.can_field_eleven(int(str(team.get("id", "0")))):
		_set_status("This team cannot field 11 players.", true)
		return
	model["ready"] = true
	_status = ""
	_status_error = false
	NET_SHELL.action(get_tree(), "set_team_ready", side, 1, 0)
	_refresh()


func _on_side_cancel(side: int, input: Dictionary) -> void:
	_note_input(input)
	var model: Dictionary = sides[side]
	if not bool(model["editable"]):
		_request_back()
		return
	if bool(model["ready"]):
		model["ready"] = false
		_status = ""
		_status_error = false
		NET_SHELL.action(get_tree(), "set_team_ready", side, 0, 0)
		_refresh()
		return
	_request_back()


func _enter_kits(lobby: Dictionary) -> void:
	var ids: Array = lobby.get("team_ids", [])
	if ids.size() != 2 or int(ids[0]) <= 0 or int(ids[1]) <= 0:
		_set_status("Choose both teams.", true)
		return
	var home := catalog.team_by_id(int(ids[0]))
	var away := catalog.team_by_id(int(ids[1]))
	if home.is_empty() or away.is_empty():
		_set_status("One of the chosen teams is missing from the database.", true)
		return
	if not catalog.can_field_eleven(int(ids[0])) or not catalog.can_field_eleven(int(ids[1])):
		_set_status("One of the chosen teams cannot field 11 players.", true)
		return
	_status = ""
	_status_error = false
	ShellState.set_teams(home, away)
	if _leaving:
		return
	_leaving = true
	UiTransition.change_scene(KIT_SCENE)


func _set_status(text: String, error := false) -> void:
	_status = text
	_status_error = error
	if view != null:
		view.set_status(text, error)


func _request_back() -> void:
	if _leaving:
		return
	if back_vote != null:
		back_vote.request()
		return
	_leave_session()


func _on_back_agreed(action: int) -> void:
	if action == NetworkBackVote.VOTE_LEAVE_SESSION:
		_leave_session()
	else:
		_back_status = "GOING BACK TO SIDE SELECT..."
		_refresh()


func _on_back_status(status: String) -> void:
	_back_status = status
	_refresh()


func _leave_session() -> void:
	if _leaving:
		return
	_leaving = true
	if back_vote != null:
		back_vote.withdraw()
	if NET_SHELL.is_active(get_tree()):
		NET_SHELL.leave(get_tree())
	UiTransition.change_scene(NETWORK_MENU_SCENE)


func _process(_delta: float) -> void:
	_poll_lobby()

