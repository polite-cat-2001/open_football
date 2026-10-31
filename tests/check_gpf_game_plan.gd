extends SceneTree
# Headless behaviour check for the ported Game Plan screen: prematch swaps,
# in-match substitution queue/cancel, 2P ownership and section navigation.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_game_plan.gd

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
	for index in 18:
		players.append({
			"id": team_id * 100 + index + 1,
			"firstname": "First%d" % index,
			"lastname": "%s%d" % [team_name.substr(0, 3), index + 1],
			"name": "%s %d" % [team_name, index + 1],
			"role": roles[index] if index < roles.size() else "CM",
			"base_stat": 0.5 + 0.01 * index,
			"average": 0.5,
			"stats": {},
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
	return {
		"team": {"id": team_id, "name": team_name},
		"players": players,
		"formation": formation,
	}


func _team_data(team_id: int, team_name: String, pending: bool = false) -> Dictionary:
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
			"slot": index,
			"name": "%s%d" % [team_name.substr(0, 3), index + 1],
			"role": roles[index],
			"position": positions[index],
			"active": true,
			"left_pitch": false,
			"pending_out": pending and index == 6,
			"pending_in": false,
			"rating": 70,
			"fatigue": 100,
		})
	for index in 7:
		players.append({
			"id": team_id * 100 + 20 + index,
			"slot": roles.size() + index,
			"name": "%sSUB%d" % [team_name.substr(0, 3), index + 1],
			"role": "CM" if index < 4 else "ST",
			"position": Vector2.ZERO,
			"active": false,
			"left_pitch": false,
			"pending_out": false,
			"pending_in": pending and index == 3,
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
	await _check_match()
	await _check_2p()
	print("== check_gpf_game_plan: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _make_plan() -> GpfGamePlan:
	var plan := GpfGamePlan.new()
	if plan == null:
		_check(false, "GpfGamePlan instantiates")
		return null
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
	print("-- prematch lineups")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])
	var home := MatchLineup.from_squad(_squad(1, "HOME"))
	var away := MatchLineup.from_squad(_squad(2, "AWAY"))
	var plan := _make_plan()
	plan.setup_prematch(home, away, [0])
	plan.open_plan()
	await _frames(2)

	_check(plan.is_open(), "the game plan opens")
	_check((plan.get("_panels") as Array).size() == 2, "single player sees his team and the opponent")
	var home_panel := _panel(plan, 0)
	_check(bool(home_panel["bar_focused"]), "the section bar starts focused")
	_check(int(home_panel["bar_cursor"]) == 1, "Positions is the default section")

	# Tactics: open the section, move to 4-3-3 and apply it.
	plan.handle_key(_key(KEY_LEFT))
	plan.handle_key(_key(KEY_ENTER))
	_check(int(home_panel["active_section"]) == 0, "Tactics opens")
	var scheme_scroll := home_panel["scheme_scroll"] as ScrollContainer
	_check(scheme_scroll.visible, "the scheme list replaces the bench")
	plan.handle_key(_key(KEY_DOWN))
	plan.handle_key(_key(KEY_ENTER))
	_check(home.current_scheme() == 1, "the chosen scheme is written into the lineup")
	plan.handle_key(_key(KEY_ESCAPE))

	# Roles: pick the captain from the pitch.
	plan.handle_key(_key(KEY_RIGHT))
	plan.handle_key(_key(KEY_RIGHT))
	plan.handle_key(_key(KEY_ENTER))
	_check(int(home_panel["active_section"]) == 2, "Roles opens")
	var role_scroll := home_panel["role_scroll"] as ScrollContainer
	_check(role_scroll.visible, "the role list replaces the bench")
	plan.handle_key(_key(KEY_ENTER))
	_check(bool(home_panel["role_picking"]), "Enter starts picking a role player")
	home_panel["cursor"] = 5
	plan.handle_key(_key(KEY_ENTER))
	_check(not bool(home_panel["role_picking"]), "assigning a player closes picking")
	_check(int(home.roles.get(0, -1)) == 5, "the captain is stored by starting slot")
	plan.handle_key(_key(KEY_ESCAPE))
	plan.handle_key(_key(KEY_LEFT))
	plan.handle_key(_key(KEY_ENTER))
	_check(int(home_panel["active_section"]) == 1, "Positions is active again")

	# Any two players of the same team can be exchanged: starters between
	# themselves and bench players between themselves.
	var starter_a := int(home.lineup[1])
	var starter_b := int(home.lineup[2])
	home_panel["cursor"] = _find_entry(home_panel, starter_a)
	plan.handle_key(_key(KEY_ENTER))
	home_panel["cursor"] = _find_entry(home_panel, starter_b)
	plan.handle_key(_key(KEY_ENTER))
	_check(int(home.lineup[1]) == starter_b and int(home.lineup[2]) == starter_a,
		"two starters swap slots in prematch")

	var bench_a := int(home.bench[0])
	var bench_b := int(home.bench[1])
	home_panel["cursor"] = _find_entry(home_panel, bench_a)
	plan.handle_key(_key(KEY_ENTER))
	home_panel["cursor"] = _find_entry(home_panel, bench_b)
	plan.handle_key(_key(KEY_ENTER))
	_check(int(home.bench[0]) == bench_b and int(home.bench[1]) == bench_a,
		"two bench players swap positions in prematch")

	# Y/Tab moves between the pitch and the bench.
	var first_pitch := int(home_panel["pitch_entries"][0])
	home_panel["cursor"] = first_pitch
	plan.handle_key(_key(KEY_TAB))
	var bench_cursor := int(home_panel["cursor"])
	_check(not bool((home_panel["entries"] as Array)[bench_cursor].get("active", true)),
		"Tab jumps from the pitch to the bench")
	plan.handle_key(_key(KEY_TAB))
	_check(bool((home_panel["entries"] as Array)[int(home_panel["cursor"])].get("active", false)),
		"Tab jumps back to the pitch")

	var starter_id := int(home.lineup[5])
	var bench_id := int(home.bench[0])
	var starter_index := _find_entry(home_panel, starter_id)
	var bench_index := _find_entry(home_panel, bench_id)
	_check(starter_index >= 0 and bench_index >= 0, "both players are on the screen")

	home_panel["cursor"] = starter_index
	plan.handle_key(_key(KEY_ENTER))
	_check(int(home_panel["held"]) == starter_index, "the first pick is held")
	var changed := [false]
	plan.lineup_changed.connect(func(): changed[0] = true)
	home_panel["cursor"] = bench_index
	plan.handle_key(_key(KEY_ENTER))
	_check(changed[0], "a prematch swap emits lineup_changed")
	_check(home.lineup.has(bench_id), "the substitute joined the starting eleven")
	_check(home.bench.has(starter_id), "the replaced starter moved to the bench")
	_check(home.is_valid(), "the edited lineup is still valid")

	var closed := [false]
	plan.close_requested.connect(func(): closed[0] = true)
	plan.handle_key(_key(KEY_ESCAPE))
	plan.handle_key(_key(KEY_ESCAPE))
	_check(closed[0], "Back on the section bar asks to leave")
	plan.queue_free()
	await _frames(1)


func _check_match() -> void:
	print("-- in-match substitutions")
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
	plan.handle_key(_key(KEY_ENTER))

	# Any pair is exchangeable: two starters swap positions via C++, two bench
	# players swap their bench order locally.
	panel["cursor"] = _find_entry(panel, 2)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 3)
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.swaps.size() == 1
		and int(fake.swaps[0]["first"]) == 2 and int(fake.swaps[0]["second"]) == 3,
		"two starters swap positions in-match")
	panel["cursor"] = _find_entry(panel, 20)
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = _find_entry(panel, 21)
	plan.handle_key(_key(KEY_ENTER))
	_check((panel["bench_order"] as Array).find(20) == 1
		and (panel["bench_order"] as Array).find(21) == 0,
		"two bench players swap their bench order")

	var out_id := int((panel["entries"] as Array)[_find_entry(panel, 6)].get("id"))
	var in_id := int((panel["entries"] as Array)[_find_entry(panel, 20)].get("id"))
	var out_index := _find_entry(panel, out_id)
	var in_index := _find_entry(panel, in_id)
	panel["cursor"] = out_index
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = in_index
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.queued.size() == 1, "starter + substitute queues a substitution")
	if fake.queued.size() == 1:
		_check(int(fake.queued[0]["team"]) == 0 and int(fake.queued[0]["out"]) == out_id
			and int(fake.queued[0]["in"]) == in_id, "the queued pair carries the C++ ids")
	_check(str(plan.get("_status").text).to_lower().contains("queued"), "the screen confirms the queue")

	panel["cursor"] = out_index
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = in_index
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.cancelled.size() == 1, "picking the same pair again cancels the queue")

	# Bench is reachable with the arrows: from the right-back, Right lands on a
	# substitute row and Enter queues that pair.
	panel["cursor"] = 3
	plan.handle_key(_key(KEY_ENTER))
	var queued_before := fake.queued.size()
	plan.handle_key(_key(KEY_RIGHT))
	var landed := int(panel["cursor"])
	var landed_active := bool((panel["entries"] as Array)[landed].get("active", true))
	_check(not landed_active, "Right from the right-back reaches the bench")
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.queued.size() == queued_before + 1, "the bench pick queues a substitution")

	# X cancels the queued pair under the cursor.
	var pending_out := int(fake.queued[queued_before]["out"])
	var pending_index := _find_entry(panel, pending_out)
	panel["cursor"] = pending_index
	var cancelled_before := fake.cancelled.size()
	plan.handle_key(_key(KEY_X))
	_check(fake.cancelled.size() == cancelled_before + 1, "X cancels the queued substitution")

	# Tactics and Roles drive the runtime bridge in-match.
	panel["cursor"] = 0
	plan.handle_key(_key(KEY_ESCAPE))
	_check(bool(panel["bar_focused"]), "Back returns to the section bar")
	plan.handle_key(_key(KEY_LEFT))
	plan.handle_key(_key(KEY_ENTER))
	_check(int(panel["active_section"]) == 0, "in-match Tactics opens")
	plan.handle_key(_key(KEY_DOWN))
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.schemes.size() == 1 and int(fake.schemes[0]["scheme"]) == 1,
		"in-match tactics call the C++ scheme bridge")
	plan.handle_key(_key(KEY_ESCAPE))
	plan.handle_key(_key(KEY_RIGHT))
	plan.handle_key(_key(KEY_RIGHT))
	plan.handle_key(_key(KEY_ENTER))
	_check(int(panel["active_section"]) == 2, "in-match Roles opens")
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = 5
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.role_sets.size() == 1 and int(fake.role_sets[0]["role"]) == 0,
		"in-match role assignment calls the C++ bridge")
	plan.handle_key(_key(KEY_ESCAPE))
	plan.handle_key(_key(KEY_ESCAPE))

	plan.queue_free()
	await _frames(1)


func _check_2p() -> void:
	print("-- two players, own team only")
	ShellState.clear()
	ShellState.set_teams(
		{"id": 1, "name": "Home FC", "color1": "0.2,0.3,0.9"},
		{"id": 2, "name": "Away FC", "color1": "0.9,0.2,0.2"})
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
		{"side": "away", "kind": "gamepad", "device": 3, "name": "Pad"},
	])
	var fake := FakeRuntime.new()
	fake.squads = {0: _team_data(0, "HOME"), 1: _team_data(1, "AWAY")}
	var plan := _make_plan()
	plan.setup_match(fake, [0, 1])
	plan.open_plan()
	await _frames(2)
	var panels: Array = plan.get("_panels")
	_check(panels.size() == 2, "both teams are shown")
	_check(bool(panels[0]["editable"]) and bool(panels[1]["editable"]),
		"both sides are editable")

	# Keyboard drives home only.
	plan.handle_key(_key(KEY_ENTER))
	_check(int(panels[0]["active_section"]) == 1, "keyboard opens the home section")
	_check(int(panels[1]["active_section"]) != 1, "the keyboard cannot open the away section")

	# Gamepad 3 drives away only.
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	joy.device = 3
	plan.handle_joy_button(joy)
	_check(int(panels[1]["active_section"]) == 1, "the away pad opens the away section")

	var home_out := _find_entry(panels[0], 6)
	var home_in := _find_entry(panels[0], 20)
	panels[0]["cursor"] = home_out
	plan.handle_key(_key(KEY_ENTER))
	panels[0]["cursor"] = home_in
	plan.handle_key(_key(KEY_ENTER))
	_check(fake.queued.size() == 1 and int(fake.queued[0]["team"]) == 0,
		"the keyboard queues for home")

	var away_out := _find_entry(panels[1], 106)
	var away_in := _find_entry(panels[1], 120)
	panels[1]["cursor"] = away_out
	plan.handle_joy_button(joy)
	panels[1]["cursor"] = away_in
	plan.handle_joy_button(joy)
	_check(fake.queued.size() == 2 and int(fake.queued[1]["team"]) == 1,
		"the away pad queues for away")

	# Gamepad Y jumps to the bench, X cancels the queued pair.
	var joy_y := InputEventJoypadButton.new()
	joy_y.button_index = JOY_BUTTON_Y
	joy_y.pressed = true
	joy_y.device = 3
	panels[1]["cursor"] = _find_entry(panels[1], 106)
	plan.handle_joy_button(joy_y)
	var pad_cursor := int(panels[1]["cursor"])
	_check(not bool((panels[1]["entries"] as Array)[pad_cursor].get("active", true)),
		"gamepad Y jumps to the bench")
	var joy_x := InputEventJoypadButton.new()
	joy_x.button_index = JOY_BUTTON_X
	joy_x.pressed = true
	joy_x.device = 3
	panels[1]["cursor"] = _find_entry(panels[1], 106)
	var cancelled_before := fake.cancelled.size()
	plan.handle_joy_button(joy_x)
	_check(fake.cancelled.size() == cancelled_before + 1,
		"gamepad X cancels the queued substitution")

	# Read-only opponents in 1P cannot be changed.
	plan.setup_match(fake, [0])
	plan.open_plan()
	await _frames(1)
	var solo: Array = plan.get("_panels")
	_check(not bool(solo[1]["editable"]), "the opponent panel is read-only")
	var before := fake.queued.size()
	solo[1]["cursor"] = _find_entry(solo[1], 106)
	solo[1]["active_section"] = 1
	solo[1]["held"] = -1
	plan._press_entry(1, _find_entry(solo[1], 106))
	_check(fake.queued.size() == before, "a read-only panel cannot queue substitutions")
	plan.queue_free()
	await _frames(1)
