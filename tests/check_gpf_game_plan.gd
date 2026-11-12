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
	var committed: Array = []

	func net_action(action_type, side: int = 0, value: int = 0, value2: int = 0) -> bool:
		net_actions.append({"action": str(action_type), "side": side,
			"value": value, "value2": value2})
		return true

	func net_commit_plan(team_id: int, ops: PackedInt32Array) -> bool:
		committed.append({"team": team_id, "ops": ops.duplicate()})
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


class ClientFake extends FakeRuntime:
	func is_net_client() -> bool:
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
	await _check_network_match()
	await _check_network_chain()
	await _check_bench_place()
	await _check_second_scheme_place()
	await _check_client_sync()
	await _check_swap_then_sub()
	await _check_network_limit()
	await _check_mouse_click()
	await _check_retired_player_visible()
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
	_check(GpfGamePlan._full_player_name({"first_name": "Karim", "last_name": "Adeyemi"})
		== "Karim Adeyemi", "the header keeps the first name before the surname")
	_check(GpfGamePlan._full_player_name({"name": "Adeyemi"}) == "Adeyemi",
		"the header falls back to the stored name")
	_check(GpfGamePlan._full_player_name({"first_name": "Rodri", "name": "Rodri"}) == "Rodri",
		"a one-word name is not duplicated")
	_check(int(home_panel["tab"]) == GpfGamePlan.TAB_SQUAD, "SQUAD is the default tab")
	_check((home_panel["entries"] as Array).size() == 20, "all squad players are listed")
	_check((home_panel["bench_entries"] as Array).size() == 7, "the drawer lists seven bench players")
	_check((home_panel["reserve_entries"] as Array).size() == 2, "the drawer lists the reserve")

	# Starter -> bench, starter -> reserve.
	var starter_id := int(home.lineup[1])
	var bench_id := int(home.bench[0])
	plan._on_entry_pressed(0, _find_entry(home_panel, starter_id))
	plan._on_entry_pressed(0, _find_entry(home_panel, bench_id))
	_check(home.lineup.has(bench_id) and home.bench.has(starter_id),
		"a starter and a bench player exchange places")
	var cursor_index := int(home_panel["cursor"])
	_check(cursor_index >= 0
		and int((home_panel["entries"] as Array)[cursor_index].get("id", -1)) == starter_id,
		"the cursor stays on the player that was pressed first")
	var reserve_id := int(home.reserve[0])
	var current_starter := int(home.lineup[2])
	plan._press_entry(0, _find_entry(home_panel, current_starter))
	plan._press_entry(0, _find_entry(home_panel, reserve_id))
	_check(home.lineup.has(reserve_id) and home.reserve.has(current_starter),
		"a starter and a reserve player exchange places")

	# Formations tab.
	plan.handle_key(_key(KEY_E))
	_check(int(home_panel["tab"]) == GpfGamePlan.TAB_FORMATIONS, "E switches to FORMATIONS")
	_check((home_panel["tabs"] as UiTabBar).get_active_tab() == GpfGamePlan.TAB_FORMATIONS,
		"the shared tab bar follows the active tab")
	_check(not (home_panel["header"] as Control).visible,
		"FORMATIONS hides the player comparison header")
	var formation_drawer_h := (home_panel["drawer"] as Control).size.y
	var formation_pitch_h := (home_panel["pitch"] as Control).size.y
	plan.handle_key(_key(KEY_RIGHT))
	plan.handle_key(_key(KEY_ENTER))
	_check(home.current_scheme() >= 0, "a formation can be applied")

	# Roles tab.
	plan.handle_key(_key(KEY_E))
	_check(int(home_panel["tab"]) == GpfGamePlan.TAB_ROLES, "E switches to ROLES")
	_check(not (home_panel["header"] as Control).visible,
		"ROLES hides the player comparison header")
	_check(is_equal_approx((home_panel["drawer"] as Control).size.y, formation_drawer_h),
		"FORMATIONS and ROLES share the same drawer height")
	_check(is_equal_approx((home_panel["pitch"] as Control).size.y, formation_pitch_h),
		"the pitch keeps the same height across FORMATIONS and ROLES")
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
	_check((home_panel["header"] as Control).visible,
		"SQUAD restores the player comparison header")
	_check(is_equal_approx(float(home_panel["drawer_t"]), 0.0),
		"returning to SQUAD keeps the bench drawer collapsed")

	# Returning from a tab collapses a drawer that was open in SQUAD.
	home_panel["cursor"] = _find_entry(home_panel, int(home.bench[0]))
	plan.call("_refresh_panel", home_panel)
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_E))
	_check(not bool(home_panel["drawer_open"])
		and is_equal_approx(float(home_panel["drawer_t"]), 0.0),
		"returning to SQUAD resets an open bench drawer to collapsed")

	# The bench drawer expands when focus moves into it and collapses back.
	home_panel["cursor"] = _find_entry(home_panel, int(home.lineup[0]))
	plan.handle_key(_key(KEY_DOWN))
	_check(bool(home_panel["drawer_open"]), "moving down opens the bench drawer")
	plan.handle_key(_key(KEY_UP))
	_check(not bool(home_panel["drawer_open"]), "moving back to the pitch closes it")

	# Mouse hover mirrors arrow selection (web prototype behaviour).
	var hover_bench := _find_entry(home_panel, int(home.bench[0]))
	plan.call("_on_entry_hovered", 0, hover_bench)
	_check(int(home_panel["cursor"]) == hover_bench and bool(home_panel["drawer_open"]),
		"hovering a bench card selects it and opens the drawer")
	plan.call("_on_entry_hovered", 0, _find_entry(home_panel, int(home.lineup[0])))
	_check(not bool(home_panel["drawer_open"]),
		"hovering a pitch card closes the drawer")
	plan.handle_key(_key(KEY_E))
	plan.call("_on_scheme_hovered", 0, 2)
	_check(int(home_panel["scheme_cursor"]) == 2,
		"hovering a formation moves the scheme cursor")
	plan.handle_key(_key(KEY_E))
	plan.call("_on_role_hovered", 0, 3)
	_check(int(home_panel["role_cursor"]) == 3,
		"hovering a role tile moves the role cursor")
	plan.handle_key(_key(KEY_E))

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

	# The RESERVE label belongs between the bench and the reserve rows.
	var box: VBoxContainer = panel["bench_box"]
	_check(box.get_child(1) == panel["bench_grid"]
		and box.get_child(2) == panel["reserve_rule"]
		and box.get_child(3) == panel["reserve_header"],
		"the RESERVE label sits between the bench and the reserve")
	_check((panel["reserve_rule"] as Control).visible,
		"a rule separates the bench from the reserve")

	# Scrolling back up to the first bench row must reveal the BENCH header.
	panel["cursor"] = int((panel["bench_entries"] as Array)[0])
	plan.call("_refresh_panel", panel)
	plan.call("_layout")
	await create_timer(0.35).timeout
	var bench_header: Control = panel["bench_header"]
	_check(bench_header.visible and bench_header.get_global_rect().position.y
		>= scroll.get_global_rect().position.y - 2.0,
		"the first bench row keeps the BENCH header visible")
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

	# Two starters swap their positions locally; nothing reaches the bridge
	# before READY.
	var first_pos: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 2)] \
		.get("position", Vector2.ZERO)
	var second_pos: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 3)] \
		.get("position", Vector2.ZERO)
	panel["cursor"] = _find_entry(panel, 2)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 3)
	plan.handle_key(_key(KEY_ENTER))
	_check((panel["entries"] as Array)[_find_entry(panel, 2)].get("position", Vector2.ZERO)
		== second_pos
		and (panel["entries"] as Array)[_find_entry(panel, 3)].get("position", Vector2.ZERO)
		== first_pos, "two starters swap positions in the plan")
	_check(fake.committed.is_empty(), "nothing is committed before READY")

	# Two bench players swap order locally.
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 21)
	plan.handle_key(_key(KEY_ENTER))
	_check((panel["bench_order"] as Array).find(20) == 1
		and (panel["bench_order"] as Array).find(21) == 0,
		"two bench players swap their drawer order")

	# Starter + substitute: the bench player takes the pitch at once; the same
	# pair (now an off player + an on player) puts the starter back.
	var out_id := 6
	var in_id := 20
	var out_position: Vector2 = (panel["entries"] as Array)[_find_entry(panel, out_id)] \
		.get("position", Vector2.ZERO)
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, out_id) == "bench" and _group(panel, in_id) == "pitch",
		"pitch + bench shows the substitution immediately")
	var sub_entry: Dictionary = (panel["entries"] as Array)[_find_entry(panel, in_id)]
	_check(sub_entry.get("position", Vector2.ZERO) == out_position,
		"the substitute keeps the outgoing player's position")
	_check(int((panel["entries"] as Array)[int(panel["cursor"])].get("id", -1)) == out_id,
		"the cursor stays on the player that was pressed first")
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, out_id) == "pitch" and _group(panel, in_id) == "bench",
		"the reverse pair restores the starting eleven")

	# A shown substitute can be chained out for another bench player.
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 21)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, out_id) == "bench" and _group(panel, in_id) == "bench"
		and _group(panel, 21) == "pitch",
		"a shown substitute can be chained out for another bench player")

	# Scheme and roles are buffered too.
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_ENTER))
	var scheme_index := int(panel["scheme_cursor"])
	_check(fake.committed.is_empty(), "the scheme waits for READY")
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 2)
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.committed.is_empty(), "the role waits for READY")

	# READY commits the net plan once.
	plan.handle_key(_key(KEY_ESCAPE))
	_check(fake.committed.size() == 1, "READY sends one plan commit")
	if fake.committed.size() == 1:
		var ops: PackedInt32Array = fake.committed[0]["ops"]
		var has_scheme := false
		var has_role := false
		var has_sub := false
		var has_swap := false
		var out_slot := int((panel["entries"] as Array)[_find_entry(panel, out_id)] \
			.get("slot", -1))
		var chain_slot := int((panel["entries"] as Array)[_find_entry(panel, 21)] \
			.get("slot", -1))
		for index in range(0, ops.size(), 3):
			var op_type := int(ops[index])
			if op_type == 1 and int(ops[index + 1]) == scheme_index:
				has_scheme = true
			elif op_type == 2 and int(ops[index + 1]) == 0:
				has_role = true
			elif op_type == 3 and int(ops[index + 1]) == out_slot \
					and int(ops[index + 2]) == chain_slot:
				has_sub = true
			elif op_type == 0 and ((int(ops[index + 1]) == 2 and int(ops[index + 2]) == 3) \
					or (int(ops[index + 1]) == 3 and int(ops[index + 2]) == 2)):
				has_swap = true
		_check(has_scheme, "the commit carries the scheme")
		_check(has_role, "the commit carries the role")
		_check(has_sub, "the commit carries the net substitution")
		_check(has_swap, "the commit carries the position swap")

	plan.queue_free()
	await _frames(1)


func _group(panel: Dictionary, player_id: int) -> String:
	var index := _find_entry(panel, player_id)
	if index < 0:
		return ""
	return str((panel["entries"] as Array)[index].get("entry_group", ""))


func _check_network_match() -> void:
	print("-- network in-match plan commit")
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
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)
	var out_id := 6
	var in_id := 20

	# A substitution applies locally; nothing is sent until READY.
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.net_actions.is_empty() and fake.committed.is_empty(),
		"the network plan sends nothing before READY")
	_check(_group(panel, out_id) == "bench" and _group(panel, in_id) == "pitch",
		"the network plan swaps the pair immediately")

	# Cancelling the local pair restores the XI and logs a cancel op.
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, out_id) == "pitch" and _group(panel, in_id) == "bench",
		"cancelling the local pair restores the XI immediately")

	# Queue it again, then swap two starters: both stay local.
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	var first_position: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 2)] \
		.get("position", Vector2.ZERO)
	var second_position: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 3)] \
		.get("position", Vector2.ZERO)
	panel["cursor"] = _find_entry(panel, 2)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 3)
	plan.handle_key(_key(KEY_ENTER))
	_check((panel["entries"] as Array)[_find_entry(panel, 2)].get("position", Vector2.ZERO)
		== second_position
		and (panel["entries"] as Array)[_find_entry(panel, 3)].get("position", Vector2.ZERO)
		== first_position, "the network plan swaps positions immediately")

	# A scheme is applied to the local view as well.
	plan.handle_key(_key(KEY_E))
	plan.handle_key(_key(KEY_ENTER))
	var scheme_index := int(panel["scheme_cursor"])
	_check(fake.net_actions.is_empty() and fake.committed.is_empty(),
		"the scheme is buffered locally too")

	# READY sends the net result: scheme, the sub, and the position swap.
	plan.handle_key(_key(KEY_ESCAPE))
	_check(fake.committed.size() == 1, "READY sends one plan commit")
	if fake.committed.size() == 1:
		var ops: PackedInt32Array = fake.committed[0]["ops"]
		_check(int(fake.committed[0]["team"]) == 0, "the commit names the team")
		var out_slot := int((panel["entries"] as Array)[_find_entry(panel, out_id)] \
			.get("slot", -1))
		var in_slot := int((panel["entries"] as Array)[_find_entry(panel, in_id)] \
			.get("slot", -1))
		var has_scheme := false
		var has_sub := false
		var has_swap := false
		for index in range(0, ops.size(), 3):
			var op_type := int(ops[index])
			if op_type == 1 and int(ops[index + 1]) == scheme_index:
				has_scheme = true
			elif op_type == 3 and int(ops[index + 1]) == out_slot \
					and int(ops[index + 2]) == in_slot:
				has_sub = true
			elif op_type == 0:
				has_swap = (int(ops[index + 1]) == 2 and int(ops[index + 2]) == 3) \
					or (int(ops[index + 1]) == 3 and int(ops[index + 2]) == 2)
		_check(has_scheme, "the commit carries the scheme")
		_check(has_sub, "the commit carries the net substitution")
		_check(has_swap, "the commit carries the position swap")
		_check(ops.size() == 9, "the cancelled pair leaves no ops behind")

	# The pause preview reads this committed XI without waiting for the host.
	var planned: Array = plan.planned_lineup(0)
	var incoming_name := str((panel["entries"] as Array)[_find_entry(panel, in_id)] \
		.get("name", ""))
	var planned_has_incoming := false
	for entry in planned:
		if str(entry.get("name", "")) == incoming_name:
			planned_has_incoming = true
	_check(planned.size() == Formation.SLOT_COUNT and planned_has_incoming,
		"the plan exposes the committed XI for the pause preview")

	plan.queue_free()
	await _frames(1)


func _check_network_chain() -> void:
	print("-- network in-match chained substitution")
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
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)
	var out_id := 6
	var in_id := 20
	var chain_id := 21

	# A (field) for B (bench), then B (now shown on the pitch) for C (bench):
	# the local view must end up as A off, C on, B back on the bench.
	panel["cursor"] = _find_entry(panel, out_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, out_id) == "bench" and _group(panel, in_id) == "pitch",
		"the first substitution swaps the pair")
	panel["cursor"] = _find_entry(panel, in_id)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, chain_id)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, out_id) == "bench"
		and _group(panel, in_id) == "bench"
		and _group(panel, chain_id) == "pitch",
		"a chained substitution is normalized to A->C locally")

	# Retargeting: the incoming shown on the pitch goes off for another sub;
	# the outgoing player stays off, so the net sub keeps the same outgoing.
	var retarget_out := 7
	var retarget_first := 22
	var retarget_second := 23
	panel["cursor"] = _find_entry(panel, retarget_out)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, retarget_first)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, retarget_out) == "bench"
		and _group(panel, retarget_first) == "pitch",
		"the retarget starts with A->B")
	panel["cursor"] = _find_entry(panel, retarget_first)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, retarget_second)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, retarget_out) == "bench"
		and _group(panel, retarget_first) == "bench"
		and _group(panel, retarget_second) == "pitch",
		"replacing the incoming keeps the outgoing off")

	plan.handle_key(_key(KEY_ESCAPE))
	_check(fake.committed.size() == 1, "the plan commits once")
	if fake.committed.size() == 1:
		var ops: PackedInt32Array = fake.committed[0]["ops"]
		var out_slot := int((panel["entries"] as Array)[_find_entry(panel, out_id)] \
			.get("slot", -1))
		var chain_slot := int((panel["entries"] as Array)[_find_entry(panel, chain_id)] \
			.get("slot", -1))
		var retarget_slot := int((panel["entries"] as Array)[_find_entry(panel, retarget_out)] \
			.get("slot", -1))
		var second_slot := int((panel["entries"] as Array)[_find_entry(panel, retarget_second)] \
			.get("slot", -1))
		_check(ops.size() == 6 and int(ops[0]) == 3 and int(ops[1]) == out_slot
			and int(ops[2]) == chain_slot and int(ops[3]) == 3
			and int(ops[4]) == retarget_slot and int(ops[5]) == second_slot,
			"the commit carries one sub per outgoing, with the last incoming")

	plan.queue_free()
	await _frames(1)


func _check_swap_then_sub() -> void:
	print("-- cyclic plan A->B, B<->C, C->A")
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
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)
	var first_pos: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 2)] \
		.get("position", Vector2.ZERO)
	var second_pos: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 3)] \
		.get("position", Vector2.ZERO)

	# A -> B: the bench player takes A's spot.
	panel["cursor"] = _find_entry(panel, 2)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	# B <-> C: both on, positions swap.
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 3)
	plan.handle_key(_key(KEY_ENTER))
	# C -> A: the benched A comes back on for C.
	panel["cursor"] = _find_entry(panel, 3)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 2)
	plan.handle_key(_key(KEY_ENTER))

	_check(_group(panel, 2) == "pitch" and _group(panel, 20) == "pitch"
		and _group(panel, 3) == "bench",
		"the cycle ends with A and B on, C off")
	var final_first: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 2)] \
		.get("position", Vector2.ZERO)
	var final_second: Vector2 = (panel["entries"] as Array)[_find_entry(panel, 20)] \
		.get("position", Vector2.ZERO)
	_check(final_first == first_pos and final_second == second_pos,
		"the cycle keeps A and B in their intended spots")
	var positions := {}
	for index in panel["pitch_entries"]:
		positions[str((panel["entries"] as Array)[int(index)].get("position", Vector2.ZERO))] = true
	_check(positions.size() == 11, "all eleven pitch positions stay distinct")

	# The whole cycle collapses to one net sub: C -> B.
	plan.handle_key(_key(KEY_ESCAPE))
	_check(fake.committed.size() == 1, "READY sends one plan commit")
	if fake.committed.size() == 1:
		var ops: PackedInt32Array = fake.committed[0]["ops"]
		var out_slot := int((panel["entries"] as Array)[_find_entry(panel, 3)] \
			.get("slot", -1))
		var in_slot := int((panel["entries"] as Array)[_find_entry(panel, 20)] \
			.get("slot", -1))
		_check(ops.size() == 3 and int(ops[0]) == 3 and int(ops[1]) == out_slot
			and int(ops[2]) == in_slot,
			"the commit is the single net substitution C -> B")

	plan.queue_free()
	await _frames(1)


func _check_mouse_click() -> void:
	print("-- bench card click wiring")
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
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)
	var index := _find_entry(panel, 20)
	var card: Control = (panel["bench_cards"] as Dictionary).get(index, null)
	_check(card != null, "the bench card exists")
	if card != null:
		card.activated.emit()
		await _frames(1)
		_check(int(panel["held"]) == index, "the bench card click selects the player")
		card = (panel["bench_cards"] as Dictionary).get(index, null)
		if card != null:
			card.activated.emit()
			await _frames(1)
			_check(int(panel["held"]) == -1, "a second click clears the selection")

	plan.queue_free()
	await _frames(1)


func _check_retired_player_visible() -> void:
	print("-- substituted-out player stays in the plan")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var fake := FakeRuntime.new()
	var home := _team_data(0, "HOME")
	(home["players"] as Array)[5]["left_pitch"] = true
	fake.squads = {0: home, 1: _team_data(1, "AWAY")}
	var plan := _make_plan()
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)
	var index := _find_entry(panel, 6)
	_check(index >= 0 and _group(panel, 6) == "bench",
		"the substituted-out player is still listed on the bench")
	_check(index >= 0
		and not bool((panel["entries"] as Array)[index].get("selectable", true)),
		"the substituted-out player is not selectable")
	# Open the drawer (any selectable bench card) so the disabled card is built.
	panel["cursor"] = _find_entry(panel, 20)
	plan.call("_refresh_panel", panel)
	await _frames(1)
	var card: Control = (panel["bench_cards"] as Dictionary).get(index, null)
	_check(card != null and not bool(card.get("editable"))
		and card.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the substituted-out card ignores the mouse and is not editable")
	plan.call("_press_entry", 0, index)
	await _frames(1)
	_check(int(panel["held"]) == -1 && _group(panel, 6) == "bench",
		"the substituted-out player cannot be selected")

	plan.queue_free()
	await _frames(1)

func _check_bench_place() -> void:
	print("-- substituted player keeps the incoming bench row")
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
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)

	# 6 -> 20 puts the outgoing on 20's row (the first one).
	panel["cursor"] = _find_entry(panel, 6)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	var row := (panel["bench_order"] as Array).find(22)
	_check(row > 0, "the next incoming has a non-first bench row")
	# 7 -> 22 must reuse 22's row instead of jumping to the top.
	panel["cursor"] = _find_entry(panel, 7)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 22)
	plan.handle_key(_key(KEY_ENTER))
	_check((panel["bench_order"] as Array).find(7) == row,
		"the outgoing takes the incoming player's bench row")
	var shown: Array = []
	for index in panel["bench_entries"]:
		shown.append(int((panel["entries"] as Array)[int(index)].get("id", -1)))
	_check(shown.find(7) == row, "the bench list shows it in that row")

	plan.queue_free()
	await _frames(1)


func _check_second_scheme_place() -> void:
	print("-- second scheme keeps the substitute on its place")
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
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)

	panel["cursor"] = _find_entry(panel, 6)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	plan.call("_plan_apply_scheme", panel, 0)
	plan.call("_plan_apply_scheme", panel, 1)

	var places: Dictionary = (plan.get("_plan_place") as Dictionary).get(0, {})
	_check(int(places.get(20, -1)) == 6, "the substitute keeps the outgoing place")
	var by_base: Dictionary = plan.call("_plan_scheme_entries", 0, 1)
	var expected: Dictionary = by_base.get(6, {})
	var actual: Dictionary = ((plan.get("_plan_positions") as Dictionary).get(0, {}) as Dictionary) \
		.get(20, {})
	_check(not expected.is_empty()
		and actual.get("position", Vector2.ZERO) == expected.get("position", Vector2.ONE)
		and str(actual.get("role", "")) == str(expected.get("role", "")),
		"the substitute gets the second scheme's entry")

	plan.handle_key(_key(KEY_ESCAPE))
	_check(fake.committed.size() == 1, "READY commits the last scheme")
	if fake.committed.size() == 1:
		var ops: PackedInt32Array = fake.committed[0]["ops"]
		var second_scheme := false
		for index in range(0, ops.size(), 3):
			if int(ops[index]) == 1 and int(ops[index + 1]) == 1:
				second_scheme = true
		_check(second_scheme, "the commit carries the second scheme")

	plan.queue_free()
	await _frames(1)


func _check_client_sync() -> void:
	print("-- client plan waits for a stable host state")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var fake := ClientFake.new()
	fake.squads = {0: _team_data(0, "HOME"), 1: _team_data(1, "AWAY")}
	var plan := _make_plan()
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	_check(not bool(plan.get("_plan_synced")), "the client plan starts unsynced")
	var panel := _panel(plan, 0)
	plan.handle_key(_key(KEY_ENTER))
	_check(int(panel["held"]) == -1, "the plan ignores input while syncing")
	await create_timer(0.35).timeout
	_check(bool(plan.get("_plan_synced")), "the plan syncs after two stable polls")
	_check(not (plan.get("_plan_on") as Dictionary).is_empty(),
		"the plan builds the desired lineup after the sync")

	plan.queue_free()
	await _frames(1)


func _check_network_limit() -> void:
	print("-- network plan substitution limit")
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
	plan.setup_match(fake, [0], {"network": true})
	plan.open_plan()
	await _frames(2)
	var panel := _panel(plan, 0)

	# Five subs exhaust the limit; the sixth is blocked as it is clicked.
	for index in 5:
		panel["cursor"] = _find_entry(panel, index + 1)
		plan.handle_key(_key(KEY_ENTER))
		panel["cursor"] = _find_entry(panel, 20 + index)
		plan.handle_key(_key(KEY_ENTER))
	_check((panel["pending"] as Array).size() == 5, "five departures are planned")
	panel["cursor"] = _find_entry(panel, 6)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 25)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, 6) == "pitch" and _group(panel, 25) == "bench",
		"the sixth substitution is blocked when clicked")
	_check(str((plan.get("_status") as Label).text).find("limit") >= 0,
		"the plan reports the substitution limit")
	_check(fake.committed.is_empty(), "nothing is committed before READY")

	# A chain (bench for a shown substitute) changes no departure count.
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 25)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, 20) == "bench" and _group(panel, 25) == "pitch"
		and (panel["pending"] as Array).size() == 5,
		"a chain is allowed at the limit and keeps five departures")

	# Bringing a starter back frees a slot for another new departure.
	panel["cursor"] = _find_entry(panel, 25)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 1)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, 1) == "pitch" and _group(panel, 25) == "bench"
		and (panel["pending"] as Array).size() == 4,
		"a returning starter lowers the planned departures")
	panel["cursor"] = _find_entry(panel, 6)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 25)
	plan.handle_key(_key(KEY_ENTER))
	_check(_group(panel, 6) == "bench" and _group(panel, 25) == "pitch"
		and (panel["pending"] as Array).size() == 5,
		"the freed slot allows one more departure")

	plan.handle_key(_key(KEY_ESCAPE))
	_check(fake.committed.size() == 1, "five substitutions commit")
	if fake.committed.size() == 1:
		var ops: PackedInt32Array = fake.committed[0]["ops"]
		var subs := 0
		for index in range(0, ops.size(), 3):
			if int(ops[index]) == 3:
				subs += 1
		_check(subs == 5, "the commit carries five substitutions")

	plan.queue_free()
	await _frames(1)
