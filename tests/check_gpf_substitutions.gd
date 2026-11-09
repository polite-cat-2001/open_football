extends SceneTree
# Headless check for the substitution bridge: queue/cancel/limit, the applied
# roster after a restart, and the notice counter/texts the shell renders.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_substitutions.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/open_football_career/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 7633, 8590, {"duration": 0.0})
	if package.is_empty():
		print("CHECK FAIL: package")
		quit(1)
		return
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	runtime.set_match_package(package)
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime: ", runtime.get_last_error())
		quit(1)
		return
	_run()
	print("== check_gpf_substitutions: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _squad(team: int) -> Dictionary:
	return runtime.get_squad(team)


func _active(squad: Dictionary) -> Array:
	var result: Array = []
	for player in squad.get("players", []):
		if bool(player.get("active", false)):
			result.append(player)
	return result


func _bench(squad: Dictionary) -> Array:
	var result: Array = []
	for player in squad.get("players", []):
		if not bool(player.get("active", false)) and not bool(player.get("left_pitch", false)):
			result.append(player)
	return result


func _by_id(squad: Dictionary, player_id: int) -> Dictionary:
	for player in squad.get("players", []):
		if int(player.get("id", -1)) == player_id:
			return player
	return {}


func _run() -> void:
	for attempt in 6000:
		runtime.step_fixed(1)
		var snap: Dictionary = runtime.get_snapshot()
		if bool(snap.get("in_play", false)) and not bool(snap.get("in_set_piece", false)):
			break
	var snap: Dictionary = runtime.get_snapshot()
	_check(bool(snap.get("in_play", false)), "the match is in play")

	var home := _squad(0)
	_check(int(home.get("name", "").length()) > 0, "get_squad reports the team name")
	_check(_active(home).size() == 11, "the squad lists eleven active players")
	_check(_bench(home).size() >= 5, "the squad lists a bench")
	_check((home.get("roles", []) as Array).size() == 6, "get_squad lists the six team roles")

	var starters := _active(home)
	var bench := _bench(home)
	var out_a: Dictionary = starters[5]
	var in_a: Dictionary = bench[0]
	_check(bool(runtime.queue_substitution(0, int(out_a["id"]), int(in_a["id"]))),
		"a valid substitution is queued")
	var pending: Array = runtime.get_pending_substitutions()
	_check(pending.size() == 1 and int(pending[0]["team"]) == 0
		and int(pending[0]["out_id"]) == int(out_a["id"])
		and int(pending[0]["in_id"]) == int(in_a["id"]),
		"get_pending_substitutions returns the pair")
	var home_with_pending := _squad(0)
	_check(bool(_by_id(home_with_pending, int(out_a["id"])).get("pending_out", false)),
		"the outgoing player is marked pending")
	_check(bool(_by_id(home_with_pending, int(in_a["id"])).get("pending_in", false)),
		"the incoming player is marked pending")
	_check(not bool(runtime.queue_substitution(0, int(out_a["id"]), int(in_a["id"]))),
		"a duplicate incoming player is refused")

	_check(bool(runtime.cancel_substitution(0, int(out_a["slot"]))), "the queued pair can be cancelled")
	_check((runtime.get_pending_substitutions() as Array).is_empty(), "the queue is empty after cancel")
	_check(not bool(runtime.cancel_substitution(0, int(out_a["slot"]))), "cancelling twice is refused")

	# Five per team: queue five distinct pairs, the sixth must be refused.
	var queued_pairs: Array = []
	for i in 5:
		var out_player: Dictionary = starters[2 + i]
		var in_player: Dictionary = bench[i]
		var ok := bool(runtime.queue_substitution(0, int(out_player["id"]), int(in_player["id"])))
		_check(ok, "pair %d is queued" % (i + 1))
		queued_pairs.append([out_player, in_player])
	_check((runtime.get_pending_substitutions() as Array).size() == 5, "five substitutions queue")
	var sixth_out: Dictionary = starters[9]
	var sixth_in: Dictionary = bench[5]
	_check(not bool(runtime.queue_substitution(0, int(sixth_out["id"]), int(sixth_in["id"]))),
		"the sixth substitution is refused (five-match limit)")
	for pair in queued_pairs:
		runtime.cancel_substitution(0, int(pair[0]["slot"]))
	_check((runtime.get_pending_substitutions() as Array).is_empty(), "all queued pairs can be cancelled")

	# One real substitution, then force the next restart (the referee applies the
	# queue when play resumes).
	var out_player: Dictionary = starters[6]
	var in_player: Dictionary = bench[2]
	_check(bool(runtime.queue_substitution(0, int(out_player["id"]), int(in_player["id"]))),
		"the applied pair is queued")
	var before_notices := int(runtime.get_substitution_notice_counter())
	runtime.debug_force_set_piece(3, 0)
	var applied := false
	for attempt in 8000:
		runtime.step_fixed(1)
		if int(runtime.get_substitution_notice_counter()) > before_notices:
			applied = true
			break
	_check(applied, "the substitution applies at the restart")

	var after := _squad(0)
	var out_after := _by_id(after, int(out_player["id"]))
	var in_after := _by_id(after, int(in_player["id"]))
	_check(not bool(out_after.get("active", true)), "the outgoing player is off the pitch")
	_check(bool(out_after.get("left_pitch", false)), "the outgoing player is marked as left")
	_check(bool(in_after.get("active", false)), "the substitute is on the pitch")
	_check(int(runtime.get_snapshot().get("substitutions0", 0)) == 1,
		"the substitution counter is reported in the snapshot")

	var notices: Array = runtime.get_substitution_notices()
	_check(not notices.is_empty(), "get_substitution_notices returns the applied pair")
	if not notices.is_empty():
		var notice: Dictionary = notices[notices.size() - 1]
		_check(int(notice["team"]) == 0 and int(notice["out_id"]) == int(out_player["id"])
			and int(notice["in_id"]) == int(in_player["id"]), "the notice carries the ids")
		_check(str(notice.get("text", "")).contains(" off, "), "the notice text names both players")
	var snapshot_notices: Array = runtime.get_snapshot().get("substitution_notices", [])
	_check(not snapshot_notices.is_empty(), "the snapshot carries the notice texts")

	var active_ids: Array = []
	for entry in runtime.get_player_ids():
		if int(entry.get("team", -1)) == 0:
			active_ids.append(int(entry.get("id", -1)))
	_check(active_ids.has(int(in_player["id"])), "the match roster lists the substitute")
	_check(not active_ids.has(int(out_player["id"])), "the match roster drops the outgoing player")

	# Roles and tactics from the Game Plan bridge.
	var roles_before: Array = _squad(0).get("roles", [])
	var captain := {}
	for role_entry in roles_before:
		if int(role_entry.get("role", -1)) == 0:
			captain = role_entry
			break
	var captain_slot := int(captain.get("slot", -1))
	_check(bool(runtime.set_team_role(0, 0, captain_slot)), "set_team_role accepts the captain slot")
	var roles_after: Array = _squad(0).get("roles", [])
	var captain_after := {}
	for role_entry in roles_after:
		if int(role_entry.get("role", -1)) == 0:
			captain_after = role_entry
			break
	_check(int(captain_after.get("designated", -1)) == captain_slot,
		"the captain designation is reported by get_squad")

	var starters_now := _active(_squad(0))
	var first_player: Dictionary = starters_now[6]
	var second_player: Dictionary = starters_now[7]
	var first_role := str(first_player.get("role", ""))
	var second_role := str(second_player.get("role", ""))
	var substitutions_before := int(runtime.get_snapshot().get("substitutions0", 0))
	_check(bool(runtime.swap_squad_players(0, int(first_player["id"]), int(second_player["id"]))),
		"two starters can swap positions in-match")
	var swapped := _squad(0)
	_check(str(_by_id(swapped, int(first_player["id"])).get("role", "")) == second_role,
		"the first starter took the second role")
	_check(str(_by_id(swapped, int(second_player["id"])).get("role", "")) == first_role,
		"the second starter took the first role")
	_check(int(runtime.get_snapshot().get("substitutions0", 0)) == substitutions_before,
		"a position swap is not a substitution")

	runtime.apply_tactical_scheme(0, 1)
	var tactic_squad := _squad(0)
	var role_counts := {}
	for player in _active(tactic_squad):
		var role := str(player.get("role", ""))
		role_counts[role] = int(role_counts.get(role, 0)) + 1
	_check(int(role_counts.get("CM", 0)) == 3, "4-3-3 applies three central midfielders in-match")
	_check(int(role_counts.get("CF", 0)) == 1, "4-3-3 applies one centre forward in-match")
