extends SceneTree
# Headless check for host-authoritative game-plan edits: pre-match PlanSwap
# reaches the shared MatchData (so Start uses the edited lineup) and in-match
# PlanSwap edits the live runtime formation.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const PORT := 28293

var failures: Array[String] = []
var runtime: Node


func _init() -> void:
	var package := MatchPackageFixture.build(DATA_ROOT, 4, 5, {"duration": 0.0})
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
	runtime.set("auto_start_match", false)
	runtime.set("data_root", DATA_ROOT)
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime")
		quit(1)
		return
	_check(bool(runtime.net_host(PORT, "Plan Host")), "the host binds a LAN session")
	_check(bool(runtime.set_match_package(package)), "the package creates the pre-match MatchData")
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	runtime.net_leave()
	if failures.is_empty():
		print("== check_gpf_net_plan_sync: PASS ==")
		quit(0)
	else:
		print("== check_gpf_net_plan_sync: FAIL ==")
		quit(1)


func _run() -> void:
	var before: PackedInt32Array = runtime.debug_get_plan_order(0)
	_check(before.size() > 4, "the pre-match squad order is available")
	if before.size() < 4:
		_finish()
		return

	# Pre-match swap: PlanSwap edits the shared MatchData, and net_lobby drains
	# the queued request even though the shell runtime runs in manual-step mode.
	_check(bool(runtime.net_action("planswap", 0, before[1], before[2])),
		"the host sends a pre-match plan swap")
	runtime.net_lobby()
	var after: PackedInt32Array = runtime.debug_get_plan_order(0)
	_check(after[1] == before[2] and after[2] == before[1],
		"the pre-match swap reaches the shared MatchData")

	# The shell builds the network package from this plan, so it must expose the
	# applied order, formation and roles.
	var plan: Dictionary = runtime.debug_get_plan(0)
	var plan_order: PackedInt32Array = plan.get("order", PackedInt32Array())
	_check(plan_order.size() == after.size() and plan_order[1] == after[1],
		"debug_get_plan follows the applied lineup")
	_check((plan.get("formation", []) as Array).size() == 11,
		"debug_get_plan carries the formation")
	_check((plan.get("roles", PackedInt32Array()) as PackedInt32Array).size() == 6,
		"debug_get_plan carries the designated roles")

	# The network hub mirrors this plan into the local MatchLineup before it
	# builds the package; that split is what the peers actually field.
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(DATA_ROOT), "the catalog loads for the hub mirror")
	var lineup := MatchLineup.from_squad(catalog.load_squad(4))
	lineup.apply_plan(plan)
	var plan_roles: PackedInt32Array = plan.get("roles", PackedInt32Array())
	_check(lineup.lineup.size() == MatchLineup.SLOT_COUNT,
		"the hub mirror keeps eleven starters")
	_check(lineup.lineup[1] == plan_order[1] and lineup.lineup[2] == plan_order[2],
		"the hub mirror follows the applied order")
	_check(lineup.bench.size() == mini(MatchLineup.BENCH_SIZE,
		plan_order.size() - MatchLineup.SLOT_COUNT),
		"the hub mirror splits the bench at seven")
	_check(lineup.formation.size() == MatchLineup.SLOT_COUNT,
		"the hub mirror carries the formation")
	_check(int(lineup.roles.get(0, -1)) == int(plan_roles[0]),
		"the hub mirror carries the designated roles")
	_check(lineup.error == "", "the hub mirror leaves the lineup valid")

	# Starting the match must reuse that MatchData, not rebuild from the package.
	_check(bool(runtime.start_match()), "the match starts from the edited MatchData")
	var squad: Dictionary = runtime.get_squad(0)
	var active := []
	for player in squad.get("players", []):
		if bool(player.get("active", false)):
			active.append(player)
	_check(active.size() == 11, "eleven players start")
	var swapped_pair: Array = []
	for player in active:
		if int(player.get("database_id", -1)) == before[1] \
				or int(player.get("database_id", -1)) == before[2]:
			swapped_pair.append(player)
	_check(swapped_pair.size() == 2, "the swapped starters are on the pitch")

	# In-match PlanSwap edits the live runtime formation (its roles exchange).
	var first: Dictionary = active[6]
	var second: Dictionary = active[7]
	var first_role := str(first.get("role", ""))
	var second_role := str(second.get("role", ""))
	_check(bool(runtime.net_action("planswap", 0,
		int(first.get("database_id", -1)), int(second.get("database_id", -1)))),
		"the host sends an in-match plan swap")
	runtime.net_lobby()
	var live: Dictionary = runtime.get_squad(0)
	var by_id := {}
	for player in live.get("players", []):
		by_id[int(player.get("id", -1))] = player
	_check(str(by_id[int(first["id"])].get("role", "")) == second_role
		and str(by_id[int(second["id"])].get("role", "")) == first_role,
		"the in-match swap exchanges the live formation roles")

	runtime.stop_match()
	_finish()
