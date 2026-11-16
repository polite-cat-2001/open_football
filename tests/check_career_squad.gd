extends SceneTree
# Headless check for the career squad (ticket 05): the snapshot/golden lineup,
# formation changes, bench swaps, role assignments, blocked players, save/load
# and the Squad tab plan flow in the hub.
#
# Run:  godot --headless --path . -s res://tests/check_career_squad.gd

const HUB := "res://scenes/career_hub.tscn"
const GOLDEN := "res://tests/fixtures/career_squad_golden.json"

var failures: Array[String] = []
var _directory := ""


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _finish() -> void:
	_cleanup()
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	print("== check_career_squad: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_directory = "user://career_squad_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	CareerSession.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var store := CareerSaveStore.new(_directory)
	CareerSession.career = career
	CareerSession.catalog = catalog
	CareerSession.store = store

	var squad := CareerSquad.snapshot(catalog, career)
	_check(not squad.is_empty(), "the squad snapshot builds")
	var formations: Array = squad.get("formations", [])
	_check(formations.size() == 20, "the formation catalog has twenty schemes")
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	_check(golden is Dictionary, "the golden fixture loads")
	if golden is Dictionary:
		_check(formations.size() == (golden.get("formations", []) as Array).size(),
			"the formation count matches the golden")
		var formation_ids: Array = []
		for formation in formations:
			formation_ids.append(formation.get("id"))
		_check(formation_ids == golden.get("formations", []),
			"the formation order matches the golden")
		var lineup: Dictionary = squad.get("lineup", {})
		_check(str(lineup.get("formation", "")) == str(golden["formation"]),
			"the default formation is 4-3-3")
		_check((lineup.get("slots", []) as Array).size() == 11,
			"the lineup has eleven starters")
		_check((lineup.get("bench", []) as Array).size() == 7,
			"the matchday bench has seven players")
		_check((lineup.get("reserve", []) as Array).size() == 12,
			"the remaining squad sits in reserve")
		_check(_lineup_golden(lineup) == golden["slots"],
			"the starters match the golden snapshot")
		_check(_ids(lineup.get("bench", [])) == golden["bench"],
			"the bench order matches the golden")
		_check(_ids(lineup.get("reserve", [])) == golden["reserve"],
			"the reserve order matches the golden")
		_check(_roles_match(squad.get("roles", {}), golden["roles"]),
			"the default role assignments match the golden")

	var players: Array = squad.get("players", [])
	var starter_ids := _ids((squad.get("lineup", {}).get("slots", [])))
	var bench_ids := _ids(squad.get("lineup", {}).get("bench", []))
	_check(starter_ids.size() == 11 and _unique(starter_ids),
		"the starting eleven are unique")
	_check(not benchmark_overlap(starter_ids, bench_ids),
		"the bench and starters do not overlap")

	# Starter <-> starter swap.
	var a := str(starter_ids[0])
	var b := str(starter_ids[1])
	_check(CareerSquad.swap_players(career, players, a, b),
		"two starters swap: " + CareerSquad.last_error)
	_check(career.lineup.size() >= 2 and str(career.lineup[0]) == b
		and str(career.lineup[1]) == a, "the starter order is swapped")
	var after := CareerSquad.snapshot(catalog, career)
	_check(_ids(after.get("lineup", {}).get("slots", []))[0] == b,
		"the snapshot reflects the starter swap")

	# Starter -> bench swap.
	var starter := str(_ids(after.get("lineup", {}).get("slots", []))[2])
	var bench := str(_ids(after.get("lineup", {}).get("bench", []))[0])
	_check(CareerSquad.swap_players(career, players, starter, bench),
		"a starter and a bench player swap: " + CareerSquad.last_error)
	var swapped := CareerSquad.snapshot(catalog, career)
	_check(not _ids(swapped.get("lineup", {}).get("slots", [])).has(starter),
		"the outgoing starter leaves the eleven")
	_check(_ids(swapped.get("lineup", {}).get("slots", [])).has(bench),
		"the bench player enters the eleven")
	_check(career.bench_order.has(starter), "the outgoing starter joins the bench order")

	# Bench <-> bench swap.
	var bench_now := _ids(swapped.get("lineup", {}).get("bench", []))
	var first := str(bench_now[0])
	var second := str(bench_now[1])
	_check(CareerSquad.swap_players(career, players, first, second),
		"two bench players swap: " + CareerSquad.last_error)
	_check(str(career.bench_order[0]) == second and str(career.bench_order[1]) == first,
		"the bench order is swapped")

	_check(not CareerSquad.swap_players(career, players, first, first),
		"swapping a player with himself is refused")
	_check(CareerSquad.last_error == "choose two different players",
		"the refusal has the prototype message")

	# Formation change and preview.
	var before_formation := career.formation
	_check(CareerSquad.set_formation(career, players, "3-5-2"),
		"the formation changes: " + CareerSquad.last_error)
	_check(career.formation == "3-5-2", "the active formation is stored")
	var changed := CareerSquad.snapshot(catalog, career)
	var positions: Array = []
	for slot in changed.get("lineup", {}).get("slots", []):
		positions.append(str(slot.get("position", "")))
	_check(positions.count("CB") == 3, "3-5-2 gives three centre-backs")
	_check(positions.count("CM") == 3, "3-5-2 gives three central midfielders")
	_check(positions.count("ST") == 2, "3-5-2 gives two strikers")
	_check(changed.get("lineup", {}).get("formation_label") == "3-5-2",
		"the formation label follows the scheme")
	var preview := CareerSquad.preview_lineup(changed.get("lineup", {}), "4-4-2")
	_check((preview.get("slots", []) as Array).size() == 11,
		"a formation preview keeps eleven slots")
	_check(str(preview.get("formation", "")) == "4-4-2",
		"the preview reports the previewed formation")
	_check(str(preview.get("slots", [])[0].get("player", {}).get("id", ""))
		== str(changed.get("lineup", {}).get("slots", [])[0].get("player", {}).get("id", "")),
		"the goalkeeper stays in goal in the preview")

	# Roles.
	var captain := str(changed.get("lineup", {}).get("slots", [])[5].get("player", {}).get("id", ""))
	_check(CareerSquad.set_role(career, players, "captain", captain),
		"the captain is assigned: " + CareerSquad.last_error)
	var role_snapshot := CareerSquad.snapshot(catalog, career)
	_check(str(role_snapshot.get("roles", {}).get("captain", "")) == captain,
		"the snapshot reports the new captain")
	var bench_id := str(_ids(role_snapshot.get("lineup", {}).get("bench", []))[0])
	_check(not CareerSquad.set_role(career, players, "captain", bench_id),
		"a bench player cannot be captain")
	_check(CareerSquad.last_error == "player is not in the starting lineup",
		"the role refusal matches the prototype")

	# Blocked players.
	CareerCondition.ensure_player_states(career, _ids(players))
	var injured := str(_ids(role_snapshot.get("lineup", {}).get("slots", []))[4])
	var state: Dictionary = career.player_state[injured]
	state["injury"] = {"type": "Muscle", "until": "2026-09-01"}
	var blocked := CareerSquad.snapshot(catalog, career)
	_check(not _ids(blocked.get("lineup", {}).get("slots", [])).has(injured),
		"an injured player is dropped from the eleven")
	_check(_ids(blocked.get("lineup", {}).get("reserve", [])).has(injured),
		"an injured player sits in reserve")
	_check(not CareerSquad.swap_players(career, players, injured,
		str(_ids(blocked.get("lineup", {}).get("slots", []))[0])),
		"an injured player cannot be swapped in")
	_check(CareerSquad.last_error == "player is unavailable",
		"the unavailable refusal matches the prototype")

	# Save/load round-trip.
	var saved_lineup := career.lineup.duplicate()
	var saved_bench := career.bench_order.duplicate()
	var saved_formation := career.formation
	var saved_roles := career.role_assignments.duplicate()
	_check(store.save(career), "the squad career saves")
	var reloaded := store.load_career(career.id)
	_check(reloaded != null, "the squad career reloads")
	if reloaded != null:
		_check(reloaded.lineup == saved_lineup, "the lineup survives save/load")
		_check(reloaded.bench_order == saved_bench, "the bench order survives save/load")
		_check(reloaded.formation == saved_formation, "the formation survives save/load")
		_check(_roles_match(reloaded.role_assignments, saved_roles),
			"the role assignments survive save/load")

	# Hub flow: Squad tab -> overview -> plan -> schemes -> roles -> details.
	var ui_career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	CareerSession.career = ui_career
	change_scene_to_file(HUB)
	await _frames(14)
	var hub := current_scene
	_check(hub != null and hub.name == "CareerHub", "the career hub opens")
	if hub == null or hub.name != "CareerHub":
		_finish()
		return
	var nav := root.get_node("UiNav")
	var view = hub.get_node("Design/PanelWrap/Body/SquadView")
	var tab_bar = hub.get_node("Design/PanelWrap/Body/TabBar")
	nav.tab_next.emit()
	await _frames(4)
	_check(view.visible, "the Squad tab shows the squad view")
	_check(view.current_view() == "overview", "the Squad tab opens on the overview")
	_check(tab_bar.visible, "the overview keeps the main tabs")
	_check(view.focused_id() == "", "the page has no focus while the strip owns it")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(3)
	_check(view.focused_id() == "team", "Down gives the club tile the first focus")
	view.handle_moved(Vector2i.RIGHT)
	await _frames(2)
	_check(view.focused_id() == "tile:centre", "Right reaches the Squad Centre tile")
	view.handle_confirmed()
	await _frames(2)
	_check(view.current_view() == "centre", "the Squad Centre opens")
	_check(not tab_bar.visible, "the Squad Centre hides the main tabs")
	view.handle_tab(1)
	await _frames(2)
	_check(int(view.get("centre_tab")) == 1, "tabs switch the Squad Centre pane")
	view.handle_cancelled()
	await _frames(2)
	_check(view.current_view() == "overview", "Back returns to the squad overview")
	_check(tab_bar.visible, "the main tabs return with the overview")
	view.handle_confirmed()
	await _frames(10)
	var plan = hub.get_node("Design/PlanHost/GamePlan")
	_check(plan != null and plan.is_open(), "confirm opens the shared game plan")
	_check(not tab_bar.visible, "the game plan hides the main tabs")
	_check((plan.formation_source as Array).size() == 20,
		"the plan edits the career's twenty formations")
	var panel: Dictionary = plan._panels[0]
	var entries: Array = panel["entries"]
	var first_index := -1
	var second_index := -1
	for index in entries.size():
		if str(entries[index].get("entry_group", "")) != "pitch":
			continue
		if first_index < 0:
			first_index = index
		elif second_index < 0:
			second_index = index
	_check(first_index >= 0 and second_index >= 0, "the plan lists the starting eleven")
	var bench_index := -1
	for index in entries.size():
		if str(entries[index].get("entry_group", "")) == "bench":
			bench_index = index
			break
	plan._on_entry_pressed(0, bench_index)
	await _frames(1)
	_check(int(panel["held"]) == bench_index, "a bench card press selects the player")
	plan.handle_ui_action("cancel", -1)
	await _frames(1)
	_check(int(panel["held"]) == -1, "Back clears the bench selection")
	var first_id := int(entries[first_index].get("id", -1))
	var second_slot := int(entries[second_index].get("slot", -1))
	panel["cursor"] = first_index
	plan.handle_key(_key(KEY_ENTER))
	panel["cursor"] = second_index
	plan.handle_key(_key(KEY_ENTER))
	await _frames(2)
	_check(plan.lineup_model(0).slot_for_player(first_id) == second_slot,
		"two starters swap inside the plan")

	plan.handle_ui_action("tab_next", -1)
	await _frames(3)
	_check(int(panel["tab"]) == 1, "the plan switches to FORMATIONS")
	var preview_before: Dictionary = plan._scheme_preview(panel)
	plan.handle_ui_action("right", -1)
	await _frames(1)
	var preview_after: Dictionary = plan._scheme_preview(panel)
	_check(preview_before.size() == 11 and preview_after != preview_before,
		"moving the formation cursor previews the new layout")
	plan.handle_ui_action("confirm", -1)
	await _frames(2)
	var applied: String = plan.formation_id
	_check(not applied.is_empty() and applied != ui_career.formation,
		"the plan applies a career formation")
	plan.handle_ui_action("tab_prev", -1)
	await _frames(3)
	plan.handle_ui_action("details", -1)
	await _frames(2)
	_check(bool(panel["details_open"]), "R opens the player details")
	var page_before := int(panel.get("details_page", 0))
	plan.handle_ui_action("tab_next", -1)
	await _frames(1)
	_check(int(panel.get("details_page", 0)) == posmod(page_before + 1, 4),
		"details page with Q/E")
	plan.handle_ui_action("cancel", -1)
	await _frames(2)
	_check(not bool(panel["details_open"]), "Back closes the details")
	plan.handle_ui_action("tab_next", -1)
	plan.handle_ui_action("tab_next", -1)
	await _frames(3)
	_check(int(panel["tab"]) == 2, "the plan reaches ROLES")
	var captain_slot: int = int(plan.lineup_model(0).role_slot(0))
	var captain_id := int(plan.lineup_model(0).lineup[captain_slot])
	plan._on_role_hovered(0, 0)
	await _frames(2)
	_check(int(entries[int(panel["cursor"])].get("id", -1)) == captain_id,
		"hovering a role shows its player on the pitch")

	nav.cancelled.emit()
	await _frames(14)
	_check(not hub.get_node("Design/PlanHost").visible, "Back closes the game plan")
	_check(tab_bar.visible, "the main tabs return after the plan")
	_check(ui_career.formation == applied, "the formation is written into the career")
	_check(ui_career.lineup.find(str(first_id)) == second_slot,
		"the swap is written into the career")
	var saved_plan := store.load_career(ui_career.id)
	_check(saved_plan != null and saved_plan.formation == applied,
		"the plan changes are saved")
	_check(view.current_view() == "overview", "the hub returns to the squad overview")
	_finish()


func _lineup_golden(lineup: Dictionary) -> Array:
	var slots: Array = []
	for slot in lineup.get("slots", []):
		var player: Dictionary = slot.get("player", {})
		slots.append({
			"position": slot.get("position"),
			"role": slot.get("role"),
			"player_id": player.get("id"),
			"name": player.get("name"),
			"overall": player.get("overall"),
			"effective_overall": player.get("effective_overall"),
		})
	return slots


func _ids(items: Array) -> Array:
	var ids: Array = []
	for item in items:
		if item is Dictionary:
			if item.has("player"):
				ids.append(str(item.get("player", {}).get("id", "")))
			else:
				ids.append(str(item.get("id", "")))
		else:
			ids.append(str(item))
	return ids


func _unique(values: Array) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true


func benchmark_overlap(first: Array, second: Array) -> bool:
	for value in first:
		if second.has(value):
			return true
	return false


func _roles_match(actual, expected) -> bool:
	if not (actual is Dictionary) or not (expected is Dictionary):
		return false
	if actual.size() != expected.size():
		return false
	for key in expected:
		if str(actual.get(key, "")) != str(expected[key]):
			return false
	return true


func _cleanup() -> void:
	if _directory.is_empty():
		return
	var dir := DirAccess.open(_directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_directory))
