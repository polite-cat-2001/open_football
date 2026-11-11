extends SceneTree
# Headless check: the network game plan targets the peer's lobby side, not a
# hard-coded HOME. The hub used to build its plan before the first lobby poll,
# so both peers fell back to team 0.
#
# Run:  godot --headless --path . -s res://tests/check_net_plan_team.gd

const HUB_SCRIPT := "res://scripts/ui/network_match_hub.gd"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hub = load(HUB_SCRIPT).new()
	hub._lobby = {"players": [{"id": 7, "side": 0}, {"id": 9, "side": 1}]}
	hub._local_id = 9
	_check(hub._local_team() == 1, "an away peer edits the away team")
	hub._local_id = 7
	_check(hub._local_team() == 0, "a home peer edits the home team")
	hub.free()

	_check(NetShell.local_team_id({
		"local_id": 9,
		"lobby": {"players": [{"id": 7, "side": 0}, {"id": 9, "side": 1}]},
	}) == 1, "the lobby lookup used by the match plan resolves the away side")
	_check(NetShell.local_team_id({"local_id": 9, "lobby": {"players": []}}) == -1,
		"an unknown peer resolves to no team")

	for failure in failures:
		print("CHECK FAIL: ", failure)
	print("CHECK PASS: network plan team" if failures.is_empty() else "CHECK FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("  FAIL: ", message)
	else:
		print("  ok: ", message)
