extends Control
# Local adapter for TeamSelectView: the catalog (lazy), the per-side selection
# indices and the 1P/2P ready flow live here; layout and input live in the view.

const CONTROLLER_SELECT_SCENE := "res://scenes/controller_select.tscn"
const KIT_SELECT_SCENE := "res://scenes/kit_select.tscn"
const UI_ASSETS := preload("res://scripts/data/ui_assets.gd")

const FIELD_COUNTRY := "country"
const FIELD_COMPETITION := "competition"
const FIELD_TEAM := "team"
# Default Quick Match pairing: FC Barcelona vs Real Madrid (shared with the
# network lobby through ShellState).

@export var data_root := ""

@onready var view: TeamSelectView = $TeamSelectView

var catalog := TeamCatalog.new()
var national_league_id := ""
var country_entries: Array = []
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
	_sides_init()
	view.side_move_requested.connect(_on_side_move)
	view.side_confirm_requested.connect(_on_side_confirm)
	view.side_cancel_requested.connect(_on_side_cancel)
	view.back_requested.connect(_leave)
	view.retry_requested.connect(_reload)
	_load_catalog()


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
		"live": false,
		"editable": false,
		"device": {"kind": "keyboard", "device": 0},
	}


func _load_catalog() -> void:
	_error = false
	_status = ""
	if not catalog.load_data_root(data_root):
		_error = true
		_status = catalog.error
		_clear_entries()
		_refresh()
		return
	national_league_id = catalog.national_league_id()
	_build_country_entries()
	if country_entries.is_empty():
		_error = true
		_status = "No teams in the database."
		_clear_entries()
		_refresh()
		return
	# National Teams is the synthetic first entry; opening on it would list 217
	# teams and pay the eligibility filter. Start on the first real country and
	# restore a previous pair directly, without listing National Teams first.
	var default_country := 1 if not national_league_id.is_empty() and country_entries.size() > 1 else 0
	for side in sides:
		side["country_index"] = default_country
		side["league_index"] = 0
		side["team_index"] = 0
		side["ready"] = false
		side["league_entries"] = []
		side["team_entries"] = []
	# Returning from the pre-match hub restores the teams each side had.
	if ShellState.has_selection():
		_restore_team(0, int(ShellState.home_team.get("id", 0)))
		_restore_team(1, int(ShellState.away_team.get("id", 0)))
	else:
		_restore_team(0, ShellState.DEFAULT_HOME_TEAM_ID)
		_restore_team(1, ShellState.DEFAULT_AWAY_TEAM_ID)
		for side in sides:
			if (side["team_entries"] as Array).is_empty():
				side["country_index"] = default_country
				side["league_index"] = 0
				side["team_index"] = 0
				_apply_country(side)
	_resolve_devices()
	_apply_live_flags()
	_refresh()


func _reload() -> void:
	_load_catalog()


func _clear_entries() -> void:
	country_entries.clear()
	for side in sides:
		side["league_entries"] = []
		side["team_entries"] = []
		side["ready"] = false
		side["live"] = false
		side["editable"] = false


func _build_country_entries() -> void:
	country_entries.clear()
	if not national_league_id.is_empty():
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


func _setup_teams(side: Dictionary, league_id: String) -> void:
	side["team_entries"] = _team_entries(league_id)
	if int(side["team_index"]) >= (side["team_entries"] as Array).size():
		side["team_index"] = 0


func _league_entries(country_id: int) -> Array:
	var entries: Array = []
	for league in catalog.leagues_for_country(country_id):
		entries.append({
			"id": str(league.get("id", 0)),
			"legacy_id": int(league.get("legacy_id", 0)),
			"name": str(league.get("name", "")),
			"logo_url": str(league.get("logo_url", "")),
			"_texture_loaded": false,
		})
	return entries


func _team_entries(league_id: String) -> Array:
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


func _league_id(side: Dictionary) -> String:
	return str(_league_entry(side).get("id", ""))


func _team_id(side: Dictionary) -> int:
	return int(str(_team_entry(side).get("id", "0")))


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
		if parallel:
			side["editable"] = true
			side["live"] = not bool(side["ready"])
		else:
			side["editable"] = index == active_side
			side["live"] = side["editable"] and not bool(side["ready"])


func _refresh() -> void:
	if _error:
		for side in sides:
			side["live"] = false
			side["editable"] = false
	else:
		_apply_live_flags()
	if view != null:
		view.setup(_build_state(), {
			"back_label": "leave",
			"status": _status,
			"status_error": _error,
		})


func _build_state() -> Dictionary:
	var side_states: Array = []
	for side in sides:
		var team := _team_entry(side)
		var rating := {}
		if not team.is_empty() and not _error:
			rating = catalog.load_team_rating(int(str(team.get("id", "0"))))
		side_states.append({
			"side": int(side["side"]),
			"label": "HOME" if int(side["side"]) == 0 else "AWAY",
			"owner": "",
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
		"status": _status,
		"status_error": _error,
		"error": _error,
	}


func _on_side_move(side: int, field: String, delta: int, _input: Dictionary) -> void:
	var model: Dictionary = sides[side]
	if _error or bool(model["ready"]) or delta == 0:
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
	_refresh()


func _on_side_confirm(side: int, _input: Dictionary) -> void:
	var model: Dictionary = sides[side]
	if _error:
		_reload()
		return
	if bool(model["ready"]) or not bool(model["live"]):
		return
	var team := _team_entry(model)
	if team.is_empty():
		_status = "Choose a team."
		_refresh()
		return
	if not catalog.can_field_eleven(int(str(team.get("id", "0")))):
		_status = "This team cannot field 11 players."
		_refresh()
		return
	_status = ""
	model["ready"] = true
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
	var home_id := _team_id(sides[0])
	var away_id := _team_id(sides[1])
	if home_id <= 0 or away_id <= 0:
		_status = "Choose both teams."
		_error = false
		_refresh()
		return
	var home := catalog.team_by_id(home_id)
	var away := catalog.team_by_id(away_id)
	if home.is_empty() or away.is_empty():
		_status = "One of the chosen teams is missing from the database."
		_error = false
		_refresh()
		return
	if not catalog.can_field_eleven(home_id) or not catalog.can_field_eleven(away_id):
		_status = "One of the chosen teams cannot field 11 players."
		_error = false
		_refresh()
		return
	if _leaving:
		return
	_leaving = true
	ShellState.set_teams(home, away)
	UiTransition.change_scene(KIT_SELECT_SCENE)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	UiTransition.change_scene(CONTROLLER_SELECT_SCENE)


func _restore_team(side_index: int, team_id: int) -> void:
	var team := catalog.team_by_id(team_id)
	if team.is_empty():
		return
	var league := catalog.league_by_id(str(team.get("league_id", "")))
	if league.is_empty():
		return
	var national := str(league.get("name", "")) == TeamCatalog.NATIONAL_LEAGUE_NAME
	var country_id := "national" if national else str(league.get("country_id", 0))
	var country_index := -1
	for index in country_entries.size():
		if str(country_entries[index].get("id", "")) == country_id:
			country_index = index
			break
	if country_index < 0:
		return
	var side: Dictionary = sides[side_index]
	side["country_index"] = country_index
	_apply_country(side)
	if not national:
		var leagues: Array = side["league_entries"]
		for index in leagues.size():
			if str(leagues[index].get("id", "")) == str(league.get("id", 0)):
				side["league_index"] = index
				break
		_apply_league(side)
	var teams: Array = side["team_entries"]
	for index in teams.size():
		if str(teams[index].get("id", "")) == str(team_id):
			side["team_index"] = index
			break
