extends SceneTree
# Headless behaviour check for the ported Game Plan screen: tabs, bench/reserve
# swaps, ready matrix, details, and the in-match bridge.

const PLAYER_STATS := {
	"physical_balance": 0.6, "physical_reaction": 0.6, "physical_acceleration": 0.6,
	"physical_velocity": 0.6, "physical_stamina": 0.6, "physical_agility": 0.6,
	"physical_shotpower": 0.6, "technical_standingtackle": 0.6,
	"technical_slidingtackle": 0.6, "technical_ballcontrol": 0.6,
	"technical_dribble": 0.6, "technical_shortpass": 0.6, "technical_highpass": 0.6,
	"technical_header": 0.6, "technical_shot": 0.6, "technical_volley": 0.6,
	"mental_calmness": 0.6, "mental_workrate": 0.6, "mental_resilience": 0.6,
	"mental_defensivepositioning": 0.6, "mental_offensivepositioning": 0.6,
	"mental_vision": 0.6,
}

var failures: Array[String] = []


class FakeRuntime:
	extends RefCounted
	var squads: Dictionary = {}
	var pending: Array = []
	var queued: Array = []
	var cancelled: Array = []
	var schemes: Array = []
	var role_sets: Array = []
	var swaps: Array = []
	var net_actions: Array = []

	func net_action(action_type, side: int = 0, value: int = 0, value2: int = 0) -> bool:
		net_actions.append({"action": str(action_type), "side": side,
			"value": value, "value2": value2})
		return true

	func get_squad(team_id: int) -> Dictionary:
		var data: Dictionary = (squads.get(team_id, {}) as Dictionary).duplicate(true)
		if data.is_empty():
			return data
		for sub in pending:
			if int(sub["team"]) != team_id:
				continue
			for entry in data["players"]:
				if int(entry["id"]) == int(sub["out_id"]):
					entry["pending_out"] = true
				if int(entry["id"]) == int(sub["in_id"]):
					entry["pending_in"] = true
		return data

	func queue_substitution(team_id: int, out_id: int, in_id: int) -> bool:
		queued.append({"team": team_id, "out": out_id, "in": in_id})
		pending.append({"team": team_id, "out_id": out_id, "in_id": in_id})
		return true

	func cancel_substitution(team_id: int, out_slot: int) -> bool:
		cancelled.append({"team": team_id, "slot": out_slot})
		for index in range(pending.size() - 1, -1, -1):
			var sub: Dictionary = pending[index]
			if int(sub["team"]) != team_id:
				continue
			var slot := -1
			for entry in (squads.get(team_id, {}) as Dictionary).get("players", []):
				if int(entry["id"]) == int(sub["out_id"]):
					slot = int(entry["slot"])
					break
			if slot == out_slot:
				pending.remove_at(index)
				break
		return true

	func get_pending_substitutions() -> Array:
		return pending.duplicate(true)

	func apply_tactical_scheme(team_id: int, scheme_index: int) -> void:
		schemes.append({"team": team_id, "scheme": scheme_index})

	func swap_squad_players(team_id: int, first_id: int, second_id: int) -> bool:
		swaps.append({"team": team_id, "first": first_id, "second": second_id})
		return true

	func set_team_role(team_id: int, role: int, slot: int) -> bool:
		role_sets.append({"team": team_id, "role": role, "slot": slot})
		return true


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _squad(team_id: int, team_name: String) -> Dictionary:
	var roles := ["GK", "CB", "CB", "LB", "RB", "DM", "CM", "CM", "LM", "RM", "ST"]
	var players: Array = []
	for index in 20:
		players.append({
			"id": team_id * 100 + index + 1,
			"firstname": "First%d" % index,
			"lastname": "%s%d" % [team_name.substr(0, 3), index + 1],
			"name": "%s %d" % [team_name, index + 1],
			"role": roles[index] if index < roles.size() else "CM",
			"base_stat": 0.5 + 0.01 * index,
			"average": 0.6,
			"tm_id": team_id * 1000 + index,
			"stats": PLAYER_STATS.duplicate(true),
		})
	var formation: Array = []
	for index in 11:
		var role: String = roles[index]
		var x := -0.8
		if role == "GK":
			x = -1.0
		elif role in ["CM", "DM"]:
			x = 0.0
		elif index >= 8 and index <= 9:
			x = 0.3
		elif index == 10:
			x = 0.8
		formation.append({
			"slot": index,
			"role": role,
			"database_position": Vector2(x, 0.0),
			"position": Vector2(x, 0.0),
		})
	return {"team": {"id": team_id, "name": team_name}, "players": players, "formation": formation}


func _team_data(team_id: int, team_name: String) -> Dictionary:
	var roles := ["GK", "CB", "CB", "LB", "RB", "DM", "CM", "CM", "LM", "RM", "ST"]
	var positions := [
		Vector2(-1.0, 0.0), Vector2(-0.8, -0.2), Vector2(-0.8, 0.2),
		Vector2(-0.7, -0.75), Vector2(-0.7, 0.75), Vector2(-0.45, 0.0),
		Vector2(-0.1, -0.25), Vector2(-0.1, 0.25), Vector2(0.25, -0.7),
		Vector2(0.25, 0.7), Vector2(0.8, 0.0),
	]
	var players: Array = []
	for index in roles.size():
		players.append({
			"id": team_id * 100 + index + 1,
			"database_id": team_id * 100 + index + 1,
			"tm_id": team_id * 1000 + index,
			"slot": index,
			"name": "%s%d" % [team_name.substr(0, 3), index + 1],
			"role": roles[index],
			"position": positions[index],
			"active": true,
			"left_pitch": false,
			"pending_out": false,
			"pending_in": false,
			"rating": 70,
			"fatigue": 100,
		})
	for index in 7:
		players.append({
			"id": team_id * 100 + 20 + index,
			"database_id": team_id * 100 + 20 + index,
			"tm_id": team_id * 1000 + 20 + index,
			"slot": roles.size() + index,
			"name": "%sSUB%d" % [team_name.substr(0, 3), index + 1],
			"role": "CM" if index < 4 else "ST",
			"position": Vector2.ZERO,
			"active": false,
			"left_pitch": false,
			"pending_out": false,
			"pending_in": false,
			"rating": 65,
			"fatigue": 100,
		})
	var role_rows: Array = []
	var role_slots := [5, 10, 7, 8, 9, 8]
	for role in 6:
		var slot := int(role_slots[role])
		role_rows.append({
			"role": role,
			"slot": slot,
			"designated": slot,
			"player_id": int(players[slot]["id"]),
			"name": str(players[slot]["name"]),
		})
	return {
		"name": team_name,
		"players": players,
		"roles": role_rows,
		"substitutions": 0,
		"max_substitutions": 5,
	}


func _run() -> void:
	await _check_prematch()
	await _check_drawer_scroll()
	await _check_ready_matrix()
	await _check_network_prematch()
	await _check_match()
	print("== check_gpf_game_plan: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _make_plan() -> GpfGamePlan:
	var plan := GpfGamePlan.new()
	get_root().add_child(plan)
	plan.size = Vector2(1920, 1080)
	return plan


func _panel(plan: GpfGamePlan, index: int) -> Dictionary:
	return (plan.get("_panels") as Array)[index]


func _find_entry(panel: Dictionary, player_id: int) -> int:
	for index in (panel["entries"] as Array).size():
		if int((panel["entries"] as Array)[index].get("id", -1)) == player_id:
			return index
	return -1


func _check_prematch() -> void:
	print("-- prematch tabs / bench / reserve")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var home := MatchLineup.from_squad(_squad(1, "HOME"))
	var away := MatchLineup.from_squad(_squad(2, "AWAY"))
	_check(home.lineup.size() == 11 and home.bench.size() == 7 and home.reserve.size() == 2,
		"the squad splits into 11 starters, 7 bench and 2 reserve")
	var plan := _make_plan()
	plan.setup_prematch(home, away, [0])
	plan.open_plan()
	await _frames(2)

	_check(plan.is_open(), "the game plan opens")
	_check((plan.get("_panels") as Array).size() == 2, "1P sees both halves")
	var home_panel := _panel(plan, 0)
	_check(GpfGamePlan.TAB_NAMES.size() == 3, "there are three tabs")
	_check(int(home_panel["tab"]) == GpfGamePlan.TAB_SQUAD, "SQUAD is the default tab")
	_check((home_panel["entries"] as Array).size() == 20, "all squad players are listed")
	_check((home_panel["bench_entries"] as Array).size() == 7, "the drawer lists seven bench players")
	_check((home_panel["reserve_entries"] as Array).size() == 2, "the drawer lists the reserve")

	# Starter -> bench, starter -> reserve.
	var starter_id := int(home.lineup[1])
	var bench_id := int(home.bench[0])
	plan._press_entry(0, _find_entry(home_panel, starter_id))
	plan._press_entry(0, _find_entry(home_panel, bench_id))
	_check(home.lineup.has(bench_id) and home.bench.has(starter_id),
		"a starter and a bench player exchange places")
	var reserve_id := int(home.reserve[0])
	var current_starter := int(home.lineup[2])
	plan._press_entry(0, _find_entry(home_panel, current_starter))
	plan._press_entry(0, _find_entry(home_panel, reserve_id))
	_check(home.lineup.has(reserve_id) and home.reserve.has(current_starter),
		"a starter and a reserve player exchange places")

	# Formations tab.
	plan.handle_key(_key(KEY_E))
	_check(int(home_panel["tab"]) == GpfGamePlan.TAB_FORMATIONS, "E switches to FORMATIONS")
	plan.handle_key(_key(KEY_RIGHT))
	plan.handle_key(_key(KEY_ENTER))
	_check(home.current_scheme() >= 0, "a formation can be applied")

	# Roles tab.
	plan.handle_key(_key(KEY_E))
	_check(int(home_panel["tab"]) == GpfGamePlan.TAB_ROLES, "E switches to ROLES")
	plan.handle_key(_key(KEY_ENTER))
	_check(bool(home_panel["role_picking"]), "A starts role picking")
	_check(bool(home_panel["pitch"].get("editing")), "role picking highlights the pitch player")
	home_panel["cursor"] = 5
	plan.handle_key(_key(KEY_ENTER))
	_check(not bool(home_panel["role_picking"]), "assigning a role closes picking")
	_check(int(home.roles.get(0, -1)) == 5, "the captain is stored by starting slot")

	# Details toggles over the pitch.
	plan.handle_key(_key(KEY_E))
	_check(int(home_panel["tab"]) == GpfGamePlan.TAB_SQUAD, "E wraps back to SQUAD")

	# The bench drawer expands when focus moves into it and collapses back.
	home_panel["cursor"] = _find_entry(home_panel, int(home.lineup[0]))
	plan.handle_key(_key(KEY_DOWN))
	_check(bool(home_panel["drawer_open"]), "moving down opens the bench drawer")
	plan.handle_key(_key(KEY_UP))
	_check(not bool(home_panel["drawer_open"]), "moving back to the pitch closes it")

	plan.handle_key(_key(KEY_Y))
	_check(bool(home_panel["details_open"]), "Y opens the details panel")
	plan.handle_key(_key(KEY_Y))
	_check(not bool(home_panel["details_open"]), "Y closes the details panel")

	# 1P READY closes the plan (after the crest hold).
	plan.handle_key(_key(KEY_ESCAPE))
	_check(bool(home_panel["ready"]), "B marks the team ready")
	_check(not (home_panel["pitch"] as Control).visible
		and (home_panel["ready_overlay"] as Control).visible,
		"ready replaces the plan with the crest panel")
	_check(int(plan.get("_close_at_ms")) > 0, "1P schedules the close after the crest hold")
	plan.queue_free()
	await _frames(1)


func _check_drawer_scroll() -> void:
	print("-- drawer scroll")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var home_squad := _squad(1, "HOME")
	var template: Dictionary = (home_squad["players"] as Array)[10]
	for extra in 10:
		var player := template.duplicate(true)
		player["id"] = 500 + extra
		player["name"] = "RESERVE %d" % (extra + 1)
		player["lastname"] = "RESERVE%d" % (extra + 1)
		(home_squad["players"] as Array).append(player)
	var home := MatchLineup.from_squad(home_squad)
	var away := MatchLineup.from_squad(_squad(2, "AWAY"))
	var plan := _make_plan()
	plan.setup_prematch(home, away, [0])
	plan.open_plan()
	await create_timer(0.3).timeout
	var panel := _panel(plan, 0)
	var last_reserve := int(home.reserve[home.reserve.size() - 1])
	panel["cursor"] = _find_entry(panel, last_reserve)
	plan.call("_refresh_panel", panel)
	plan.call("_layout")
	await create_timer(0.35).timeout
	var scroll: ScrollContainer = panel["bench_scroll"]
	_check(scroll.scroll_vertical > 0,
		"the bench drawer scrolls to a selected reserve")
	var card = (panel["bench_cards"] as Dictionary).get(int(panel["cursor"]), null)
	_check(card != null, "the selected reserve has a bench card")
	if card != null:
		var view: Rect2 = scroll.get_global_rect()
		var rect: Rect2 = card.get_global_rect()
		_check(rect.position.y >= view.position.y - 2.0 and rect.end.y <= view.end.y + 2.0,
			"the selected reserve card is visible")
	plan.queue_free()
	await _frames(1)

func _check_ready_matrix() -> void:
	print("-- ready matrix")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
		{"side": "away", "kind": "gamepad", "device": 3, "name": "Pad"},
	])
	var home := MatchLineup.from_squad(_squad(1, "HOME"))
	var away := MatchLineup.from_squad(_squad(2, "AWAY"))
	var plan := _make_plan()
	plan.setup_prematch(home, away, [0, 1], {"local_two_player": true})
	plan.open_plan()
	await _frames(2)
	var panels: Array = plan.get("_panels")
	plan.handle_key(_key(KEY_ESCAPE))
	_check(bool(panels[0]["ready"]) and not bool(panels[1]["ready"]),
		"local 2P: one ready waits for the other")
	_check(int(plan.get("_close_at_ms")) == 0, "the shared plan stays open")
	plan.handle_key(_key(KEY_ESCAPE))
	_check(not bool(panels[0]["ready"]), "B again withdraws READY")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_B
	joy.pressed = true
	joy.device = 3
	plan.handle_joy_button(joy)
	plan.handle_key(_key(KEY_ESCAPE))
	_check(bool(panels[0]["ready"]) and bool(panels[1]["ready"]),
		"local 2P closes only when both are ready")
	_check(int(plan.get("_close_at_ms")) > 0, "both ready schedules the close")
	plan.queue_free()
	await _frames(1)


func _check_network_prematch() -> void:
	print("-- network pre-match edits")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var home := MatchLineup.from_squad(_squad(1, "HOME"))
	var away := MatchLineup.from_squad(_squad(2, "AWAY"))
	var fake := FakeRuntime.new()
	var plan := _make_plan()
	plan.setup_prematch(home, away, [0], {"network": true})
	plan.open_plan()
	plan.set("runtime", fake)
	await _frames(2)
	var panel := _panel(plan, 0)
	var first := int(home.lineup[1])
	var second := int(home.bench[0])
	plan._press_entry(0, _find_entry(panel, first))
	plan._press_entry(0, _find_entry(panel, second))
	_check(fake.net_actions.size() == 1 and fake.net_actions[0]["action"] == "planswap",
		"a network lineup swap sends PlanSwap")
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.net_actions.size() == 2 and fake.net_actions[1]["action"] == "planscheme",
		"a network formation sends PlanScheme")
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = 5
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.net_actions.size() == 3 and fake.net_actions[2]["action"] == "planrole",
		"a network role pick sends PlanRole")
	plan.queue_free()
	await _frames(1)


func _check_match() -> void:
	print("-- in-match plan")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var fake := FakeRuntime.new()
	fake.squads = {0: _team_data(0, "HOME"), 1: _team_data(1, "AWAY")}
	var plan := _make_plan()
	plan.setup_match(fake, [0])
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)
	_check((panel["bench_entries"] as Array).size() == 7, "only the seven matchday subs are shown")
	_check((panel["reserve_entries"] as Array).size() == 0, "the reserve is hidden in-match")

	var gk_index := _find_entry(panel, 1)
	var centre_index := _find_entry(panel, 7)
	panel["cursor"] = gk_index
	plan.handle_key(_key(KEY_UP))
	_check(int(panel["cursor"]) != gk_index, "up moves off the keeper")
	_check(str((panel["entries"] as Array)[int(panel["cursor"])].get("role", "")) == "CB",
		"up from the keeper goes to a centre-back")
	panel["cursor"] = centre_index
	plan.handle_key(_key(KEY_LEFT))
	_check(int(panel["cursor"]) != centre_index, "left moves between outfielders")

	panel["cursor"] = gk_index
	var closed_drawer_h := (panel["drawer"] as Control).size.y
	plan.handle_key(_key(KEY_DOWN))
	var first_bench := int(panel["cursor"])
	_check(bool(panel["drawer_open"]), "down from the keeper enters the bench")
	await create_timer(0.30).timeout
	_check((panel["drawer"] as Control).size.y > closed_drawer_h + 40.0,
		"the bench drawer animates open")
	plan.handle_key(_key(KEY_RIGHT))
	_check(int(panel["cursor"]) != first_bench, "right moves across the bench")
	plan.handle_key(_key(KEY_DOWN))
	_check(int(panel["cursor"]) != first_bench, "down moves to the next bench row")
	plan.handle_key(_key(KEY_UP))
	_check(bool(panel["drawer_open"]), "one up stays inside the bench")
	plan.handle_key(_key(KEY_UP))
	await create_timer(0.30).timeout
	_check(not bool(panel["drawer_open"]) and bool((panel["entries"] as Array)[int(panel["cursor"])].get("active", false)), "up returns to the pitch")
	_check((panel["drawer"] as Control).size.y <= closed_drawer_h + 2.0,
		"the bench drawer animates closed")

	# Two starters swap (free, no substitution).
	var first := _find_entry(panel, 2)
	var second := _find_entry(panel, 3)
	panel["cursor"] = first
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = second
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.swaps.size() == 1 and int(fake.swaps[0]["first"]) == 2
		and int(fake.swaps[0]["second"]) == 3, "two starters swap positions through the bridge")

	# Two bench players swap order locally.
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 21)
	plan.handle_key(_key(KEY_ENTER))
	_check((panel["bench_order"] as Array).find(20) == 1
		and (panel["bench_order"] as Array).find(21) == 0,
		"two bench players swap their drawer order")

	# Starter + substitute queues a substitution; the same pair cancels it.
	var out_id := 6
	var in_id := 20
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.queued.size() == 1, "pitch + bench queues a substitution")
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.cancelled.size() == 1, "the same pair cancels the queued substitution")

	# Chain: a queued-in bench player can be chained out for another bench
	# player (C++ collapses A->B, B->C into A->C).
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	var queued_before_chain := fake.queued.size()
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 21)
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.queued.size() == queued_before_chain + 1
		and int(fake.queued[-1]["out"]) == in_id and int(fake.queued[-1]["in"]) == 21,
		"a queued-in bench player can be chained out")

	# Tactics and roles still drive the bridge.
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.schemes.size() == 1, "in-match FORMATIONS applies a scheme")
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = 5
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.role_sets.size() == 1 and int(fake.role_sets[0]["role"]) == 0,
		"in-match ROLES assigns a role")

	plan.queue_free()
	await _frames(1)
