extends SceneTree
# LAN two-process probe: run as a child process by check_gpf_net_two_process.gd.
# Joins the host, plays through the lobby, receives MatchSetup, builds the same
# match from the ids and reports the remote-presentation snapshot as JSON.
#
# Usage (the host test builds this command):
#   godot --headless --path . -s res://tests/gpf_net_client_probe.gd -- \
#       ADDRESS PORT RESULT_PATH [RUNNING_MARKER PAUSE_MARKER HOST_VOTE_MARKER
#       SIDE_DONE_MARKER RESUME_DONE_MARKER MODE]
#
# MODE "rejoin" means the host already runs a match: wait for the streamed
# MatchSetup, build the paused match, join the mirrored side selection and
# report the resumed match instead of playing through the lobby.

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const GpfHudScript := preload("res://scripts/match/gpf_hud.gd")

var failures: Array[String] = []
var runtime: Node
var probe_result: Dictionary = {}
var match_setup: Dictionary = {}
var last_snapshot: Dictionary = {}
var hud: GpfHud
var probe_human_id := -1
var pending_seen := false
var pending_out_slot := -1
var pending_in_slot := -1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		print("PROBE FAIL: expected ADDRESS PORT RESULT_PATH")
		quit(1)
		return

	probe_result = {
		"status": "fail",
		"stage": "init",
		"address": args[0],
		"port": int(args[1]),
	}
	# "-" marks an unused positional marker: empty arguments are dropped by the
	# OS/engine argument parser and would shift the later positions.
	var running_marker := _arg(args, 3)
	var pause_marker := _arg(args, 4)
	var host_vote_marker := _arg(args, 5)
	var side_done_marker := _arg(args, 6)
	var resume_done_marker := _arg(args, 7)
	var mode := _arg(args, 8)
	var message_marker := _arg(args, 9)
	var message_seen_marker := _arg(args, 10)
	var ok := _run(args[0], int(args[1]), running_marker, pause_marker, host_vote_marker,
		side_done_marker, resume_done_marker, mode, message_marker, message_seen_marker)
	probe_result["status"] = "ok" if ok and failures.is_empty() else "fail"
	probe_result["failures"] = failures
	_write_result(args[2], probe_result)
	print("PROBE: ", probe_result["status"], " stage=", probe_result.get("stage", ""))
	for failure in failures:
		print("PROBE FAIL: ", failure)
	quit(0 if probe_result["status"] == "ok" else 1)


func _arg(args: PackedStringArray, index: int) -> String:
	if index >= args.size():
		return ""
	var value := args[index]
	return "" if value == "-" else value


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("PROBE FAIL: ", message)
	return condition


func _write_result(path: String, result: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("PROBE FAIL: cannot write result to ", path)
		return
	file.store_string(JSON.stringify(result))
	file.close()


func _wait_until(predicate: Callable, timeout_ms: int, poll_ms: int = 50) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		OS.delay_msec(poll_ms)
	return false


func _lobby_state() -> Dictionary:
	return Dictionary(runtime.net_lobby().get("lobby", {}))


func _active_ids(team_id: int) -> Array:
	var ids: Array = []
	var squad: Dictionary = runtime.get_squad(team_id)
	for player in squad.get("players", []):
		if bool(player.get("active", false)):
			ids.append(int(player.get("id", -1)))
	ids.sort()
	return ids


func _poll_connected() -> bool:
	var info: Dictionary = runtime.net_lobby()
	probe_result["local_id"] = info.get("local_id", -1)
	probe_result["connection"] = info.get("connection", -1)
	probe_result["reject_text"] = info.get("reject_text", "")
	return int(info.get("connection", 0)) == 3


func _poll_teams_phase() -> bool:
	var lobby := _lobby_state()
	probe_result["phase_after_ready"] = lobby.get("phase", -1)
	return int(lobby.get("phase", -1)) == 1


func _poll_setup() -> bool:
	match_setup = runtime.net_take_match_setup()
	return not match_setup.is_empty()


func _poll_remote() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	_apply_probe_hud(last_snapshot)
	return int(last_snapshot.get("match_time_ms", 0)) > 0


func _apply_probe_hud(snap: Dictionary) -> void:
	if hud == null:
		return
	hud.apply_snapshot(snap, probe_human_id, 0, false, "Afternoon")


func _poll_spam_message(baseline: int) -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	_apply_probe_hud(last_snapshot)
	return int(last_snapshot.get("spam_message_counter", 0)) > baseline \
		and String(last_snapshot.get("spam_message", "")) != ""


func _poll_paused() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return bool(last_snapshot.get("paused", false))


func _poll_resumed() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return not bool(last_snapshot.get("paused", true))


func _poll_penalty() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	# The host queues its substitution right before forcing this penalty; the
	# snapshot must relay that pending pair to the client's game plan.
	var pending: Array = runtime.get_pending_substitutions()
	for pair in pending:
		if int(pair.get("team", -1)) != 1:
			continue
		pending_seen = true
		pending_out_slot = int(pair.get("out_slot", -1))
		pending_in_slot = int(pair.get("in_slot", -1))
		break
	return int(last_snapshot.get("presentation_type", 0)) == 6


func _poll_side_select_open() -> bool:
	runtime.step_fixed(10)
	return bool(_lobby_state().get("side_select", false))


func _poll_side_select_closed() -> bool:
	runtime.step_fixed(10)
	last_snapshot = runtime.get_snapshot()
	return not bool(_lobby_state().get("side_select", true)) \
		and not bool(last_snapshot.get("paused", true))


func _file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


func _write_marker(path: String, text: String) -> void:
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _run(address: String, port: int, running_marker: String = "",
		pause_marker: String = "", host_vote_marker: String = "",
		side_done_marker: String = "", resume_done_marker: String = "",
		mode: String = "", message_marker: String = "",
		message_seen_marker: String = "") -> bool:
	probe_result["stage"] = "runtime"
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8)
	if package.is_empty():
		return _check(false, "client could not build the bootstrap package")

	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		return _check(false, "GpfRuntimeNode is not registered")
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	if not runtime.set_match_package(package):
		return _check(false, "client bootstrap package rejected")
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		return _check(false, "client runtime did not start: " + String(runtime.get_last_error()))
	runtime.stop_match()

	probe_result["stage"] = "join"
	if not _check(runtime.net_join(address, port, "Client"), "net_join failed: " + String(runtime.get_last_error())):
		return false

	if not _wait_until(_poll_connected, 15000):
		probe_result["stage"] = "connect"
		return _check(false, "client did not connect (connection=%s, reject=%s)" % [
			probe_result.get("connection"), probe_result.get("reject_text")])

	var info: Dictionary = runtime.net_lobby()
	probe_result["accepted"] = info.get("accepted", false)
	if not _check(bool(info.get("accepted", false)), "the host rejected the client: " + String(info.get("reject_text", ""))):
		probe_result["stage"] = "rejected"
		return false

	if mode == "rejoin":
		return _run_rejoin()

	# Pick the away side and vote ready; the host votes from its own process.
	probe_result["stage"] = "sides"
	_check(runtime.net_action("set_side", 1, 1, 0), "client SetSide failed")
	_check(runtime.net_action("set_ready", 0, 1, 0), "client SetReady failed")

	if not _wait_until(_poll_teams_phase, 10000):
		probe_result["stage"] = "teams-phase"
		return _check(false, "the lobby did not reach the Teams phase")

	probe_result["stage"] = "team-select"
	_check(runtime.net_action("set_selection", 1, 0, 0), "client country selection failed")
	_check(runtime.net_action("set_selection", 1, 2, 8), "client team selection failed")
	_check(runtime.net_action("set_team_ready", 1, 1, 0), "client team confirmation failed")

	probe_result["stage"] = "match-setup"
	if not _wait_until(_poll_setup, 20000):
		return _check(false, "client did not receive NetMatchSetup")
	probe_result["team_ids"] = match_setup.get("team_ids", [])
	var ids: Array = match_setup.get("team_ids", [])
	if not _check(ids.size() == 2 and int(ids[0]) == 3 and int(ids[1]) == 8,
			"unexpected MatchSetup team ids: " + str(ids)):
		return false

	probe_result["stage"] = "build-match"
	var match_package := MatchPackageFixture.build(DATA_ROOT, int(ids[0]), int(ids[1]))
	if not _check(not match_package.is_empty(), "client could not build the match package"):
		return false
	if not _check(runtime.set_match_package(match_package), "client match package rejected"):
		return false
	if not _check(runtime.start_match(), "client could not start the remote match: " + String(runtime.get_last_error())):
		return false

	# The HUD is driven only through apply_snapshot, exactly like the slice. It
	# establishes the message/condition baseline before the host sends anything.
	hud = GpfHudScript.new()
	hud.name = "ProbeHud"
	get_root().add_child(hud)
	hud.setup(runtime)

	probe_result["stage"] = "remote-match"
	var saw_remote := _wait_until(_poll_remote, 20000)
	var snap := last_snapshot
	probe_result["net_active"] = snap.get("net_active", false)
	probe_result["net_is_client"] = snap.get("net_is_client", false)
	probe_result["net_is_host"] = snap.get("net_is_host", true)
	probe_result["net_connection"] = snap.get("net_connection", -1)
	probe_result["tick"] = snap.get("tick", -1)
	probe_result["match_time_ms"] = snap.get("match_time_ms", -1)
	probe_result["score0"] = snap.get("score0", -1)
	probe_result["score1"] = snap.get("score1", -1)
	probe_result["team0_name"] = snap.get("team0_name", "")
	probe_result["team1_name"] = snap.get("team1_name", "")

	_check(saw_remote, "client did not receive a remote snapshot")
	_check(bool(snap.get("net_active", false)), "client snapshot has no net session")
	_check(bool(snap.get("net_is_client", false)), "client snapshot is not marked as client")
	_check(not bool(snap.get("net_is_host", true)), "client snapshot is marked as host")
	_check(int(snap.get("tick", 0)) > 0, "client match did not advance")
	_check(String(snap.get("team0_name", "")) != "" and String(snap.get("team1_name", "")) != "",
		"client match has no team names")

	# The client must follow the host's selected player (snapshot ownerId), not
	# the first player on its side.
	var local_id := int(probe_result.get("local_id", -1))
	var human_id := int(runtime.get_human_player_id())
	var owner_id := -1
	var roster_ids: Array = runtime.get_player_ids()
	for entry in roster_ids:
		if int(entry.get("owner_id", -1)) == local_id:
			owner_id = int(entry.get("id", -1))
			break
	probe_result["human_player_id"] = human_id
	probe_result["owner_player_id"] = owner_id
	var human_ids: Array = runtime.get_human_player_ids()
	_check(human_id > 0, "client has a local human player")
	_check(human_id == owner_id, "client human player matches the snapshot owner")
	_check(human_ids.size() == 1 and int(human_ids[0]) == human_id,
		"client highlights only its own selected player")

	# Keep the HUD fed with the local human id before the message stage.
	probe_human_id = human_id
	_apply_probe_hud(last_snapshot)

	# The card props are driven by the original geometry the client's own
	# Officials::Put() positioned from the relayed card state.
	var cards: Dictionary = last_snapshot.get("referee_cards", {})
	var cards_present: bool = cards.get("yellow", {}).has("pos") \
		and cards.get("yellow", {}).has("raised") \
		and cards.get("red", {}).has("rot") \
		and cards.get("red", {}).has("raised")
	var cards_visible := 0
	for key in ["yellow", "red"]:
		if bool((cards.get(key, {}) as Dictionary).get("visible", false)):
			cards_visible += 1
	probe_result["referee_cards_present"] = cards_present
	probe_result["referee_cards_visible"] = cards_visible
	_check(cards_present, "client snapshot carries the referee card props")
	_check(cards_visible <= 1, "at most one referee card is visible")

	if not pause_marker.is_empty():
		probe_result["stage"] = "pause"
		_write_marker(running_marker, "running")

		# The host relays an on-screen match message through Match::SpamMessage
		# after it sees this marker. The HUD must show it, exactly once, from the
		# snapshot counter (not from the raw text).
		if not message_marker.is_empty():
			probe_result["stage"] = "message"
			_check(_wait_until(_file_exists.bind(message_marker), 15000),
				"client did not see the host message marker")
			var baseline := int(last_snapshot.get("spam_message_counter", 0))
			var saw_message := _wait_until(_poll_spam_message.bind(baseline), 15000)
			var message_snap := last_snapshot
			var message_text := String(message_snap.get("spam_message", ""))
			probe_result["spam_seen"] = saw_message
			probe_result["spam_message"] = message_text
			probe_result["spam_message_counter"] = int(message_snap.get("spam_message_counter", 0))
			probe_result["spam_message_time_ms"] = int(message_snap.get("spam_message_time_ms", 0))
			_check(saw_message, "client received the relayed match message")
			_check(message_text.begins_with("GOAL"),
				"the relayed message is the goal announcement: " + message_text)
			_check(int(message_snap.get("spam_message_time_ms", 0)) > 0,
				"the relayed message carries its display duration")
			var message_label := hud.get("message_label") as Label
			probe_result["hud_message_visible"] = message_label != null and message_label.visible
			probe_result["hud_message_text"] = message_label.text if message_label != null else ""
			_check(message_label != null and message_label.visible
				and message_label.text == message_text,
				"the client HUD shows the relayed message")
			# In-match fatigue is not drawn (original fidelity); the Game Plan
			# reads it from get_squad() and must have valid values on the client.
			var plan_fatigue := -1
			for player in runtime.get_squad(1).get("players", []):
				if bool(player.get("active", false)) \
						and int(player.get("fatigue", -1)) >= 0 \
						and int(player.get("fatigue", -1)) <= 100:
					plan_fatigue = int(player.get("fatigue", -1))
					break
			probe_result["game_plan_fatigue"] = plan_fatigue
			_check(plan_fatigue >= 0,
				"the client Game Plan sees player fatigue (%d)" % plan_fatigue)
			if not message_seen_marker.is_empty():
				_write_marker(message_seen_marker, "seen")

		var saw_pause := _wait_until(_poll_paused, 15000)
		probe_result["pause_seen"] = saw_pause
		if not _check(saw_pause, "client did not see the host pause"):
			return false
		_write_marker(pause_marker, "paused")
		# Wait for the host vote: one vote alone must not resume the match.
		if not _check(_wait_until(_file_exists.bind(host_vote_marker), 15000),
				"client did not see the host resume vote"):
			return false
		if not _check(runtime.net_action("set_resume_ready", 0, 1, 0),
				"client resume vote failed"):
			return false
		var resumed := _wait_until(_poll_resumed, 15000)
		probe_result["resumed"] = resumed
		_check(resumed, "client did not resume after both votes")
		# The next host phase pauses again; let it know this peer really saw
		# the resume first, or the two pause broadcasts can collapse.
		_write_marker(resume_done_marker, "resumed")

		# In-match side selection: the host opened it while paused; mirror it,
		# ready up and wait for the host commit (a client never commits).
		probe_result["stage"] = "side-select"
		if not _wait_until(_poll_side_select_open, 15000):
			return _check(false, "client did not see the mirrored side selection")
		probe_result["side_select_seen"] = true
		_check(runtime.net_action("set_ready", 0, 1, 0), "client side-select ready failed")
		if not _wait_until(_poll_side_select_closed, 15000):
			return _check(false, "client never saw the host commit the side selection")
		var side_resumed := _wait_until(_poll_resumed, 15000)
		probe_result["side_select_resumed"] = side_resumed
		if not _check(side_resumed, "client did not resume after the side-select commit"):
			return false
		# Snapshot the away XI before the host reacts to the marker below: it
		# queues the substitution and forces the restart.
		var before_sub_ids := _active_ids(1)

		# In-match game-plan commit from the client: swap two away starters and
		# report the expected formation so the host can verify the relay.
		var plan_squad: Dictionary = runtime.get_squad(1)
		var commit_a := -1
		var commit_b := -1
		var commit_pos_a := Vector2.ZERO
		var commit_pos_b := Vector2.ZERO
		for player in plan_squad.get("players", []):
			if not bool(player.get("active", false)):
				continue
			if str(player.get("role", "")) == "GK":
				continue
			if commit_a < 0:
				commit_a = int(player.get("database_id", -1))
				commit_pos_a = player.get("position", Vector2.ZERO)
			elif commit_b < 0:
				commit_b = int(player.get("database_id", -1))
				commit_pos_b = player.get("position", Vector2.ZERO)
				break
		probe_result["commit_a"] = commit_a
		probe_result["commit_b"] = commit_b
		probe_result["commit_pos_a"] = [commit_pos_a.x, commit_pos_a.y]
		probe_result["commit_pos_b"] = [commit_pos_b.x, commit_pos_b.y]
		probe_result["commit_ok"] = runtime.net_commit_plan(1,
			PackedInt32Array([0, commit_a, commit_b]))

		_write_marker(side_done_marker, JSON.stringify({
			"a": commit_a, "b": commit_b,
			"ax": commit_pos_a.x, "ay": commit_pos_a.y,
			"bx": commit_pos_b.x, "by": commit_pos_b.y,
		}))

		# The host forces a penalty for this client's team; the client must get
		# the kicker role and the yellow aim reticle from the same snapshot data.
		probe_result["stage"] = "penalty"
		var penalty_seen := _wait_until(_poll_penalty, 20000)
		var penalty_snap := last_snapshot
		probe_result["pending_seen"] = pending_seen
		probe_result["pending_out_slot"] = pending_out_slot
		probe_result["pending_in_slot"] = pending_in_slot
		var after_sub_ids := _active_ids(1)
		var new_sub_ids: Array = []
		for id in after_sub_ids:
			if not before_sub_ids.has(id):
				new_sub_ids.append(id)
		probe_result["substitution_new_ids"] = new_sub_ids
		probe_result["substitution_roster_changed"] = after_sub_ids != before_sub_ids
		probe_result["substitution_roster_synced"] = not new_sub_ids.is_empty()
		_check(bool(probe_result["substitution_roster_changed"]),
			"client did not apply the substitution roster")
		_check(bool(probe_result["substitution_roster_synced"]),
			"client roster is missing the substituted-in player")
		var aim: Vector3 = penalty_snap.get("set_piece_aim_point", Vector3.ZERO)
		probe_result["penalty_seen"] = penalty_seen
		probe_result["penalty_role"] = penalty_snap.get("set_piece_role", -1)
		probe_result["penalty_local_taker"] = penalty_snap.get("set_piece_local_taker", false)
		probe_result["penalty_hud_player"] = penalty_snap.get("set_piece_hud_player", -1)
		probe_result["penalty_human_id"] = int(runtime.get_human_player_id())
		probe_result["penalty_aim_length"] = aim.length()
		_check(penalty_seen, "client did not see the forced penalty")
		_check(int(penalty_snap.get("set_piece_role", 0)) == 1,
			"client is not the penalty kicker")
		_check(aim.length() > 0.01, "client penalty aim point is empty")
		_check(bool(penalty_snap.get("set_piece_local_taker", false)),
			"client penalty taker is not local")
	return failures.is_empty()


# Mid-match rejoin: the host streams MatchSetup, the animation table and a
# snapshot to every peer that joins a running match. Build the same match from
# the setup, then take part in the mirrored side selection; after the host
# commits, the snapshots continue the match on this peer.
func _run_rejoin() -> bool:
	probe_result["rejoin"] = true
	probe_result["stage"] = "rejoin-setup"
	if not _check(_wait_until(_poll_setup, 20000),
			"rejoining client did not receive MatchSetup"):
		return false
	probe_result["team_ids"] = match_setup.get("team_ids", [])
	var ids: Array = match_setup.get("team_ids", [])
	if not _check(ids.size() == 2 and int(ids[0]) > 0 and int(ids[1]) > 0,
			"rejoining client got no team ids: " + str(ids)):
		return false

	probe_result["stage"] = "rejoin-build"
	var match_package := MatchPackageFixture.build(DATA_ROOT, int(ids[0]), int(ids[1]))
	if not _check(not match_package.is_empty(),
			"rejoining client could not build the match package"):
		return false
	if not _check(runtime.set_match_package(match_package),
			"rejoining client match package rejected"):
		return false
	if not _check(runtime.start_match(),
			"rejoining client could not start the remote match: " + String(runtime.get_last_error())):
		return false

	probe_result["stage"] = "rejoin-snapshot"
	if not _check(_wait_until(_poll_remote, 20000),
			"rejoining client received no remote snapshot"):
		return false
	if not _check(_wait_until(_poll_side_select_open, 15000),
			"rejoining client missed the mirrored side selection"):
		return false
	probe_result["side_select_seen"] = true
	_check(runtime.net_action("set_ready", 0, 1, 0), "rejoining client ready failed")
	if not _check(_wait_until(_poll_side_select_closed, 20000),
			"rejoining client never left the side selection"):
		return false
	if not _check(_wait_until(_poll_resumed, 15000),
			"rejoining client did not resume"):
		return false

	last_snapshot = runtime.get_snapshot()
	probe_result["net_active"] = last_snapshot.get("net_active", false)
	probe_result["net_is_client"] = last_snapshot.get("net_is_client", false)
	probe_result["net_is_host"] = last_snapshot.get("net_is_host", true)
	probe_result["tick"] = last_snapshot.get("tick", -1)
	probe_result["match_time_ms"] = last_snapshot.get("match_time_ms", -1)
	probe_result["score0"] = last_snapshot.get("score0", -1)
	probe_result["score1"] = last_snapshot.get("score1", -1)
	probe_result["team0_name"] = last_snapshot.get("team0_name", "")
	probe_result["team1_name"] = last_snapshot.get("team1_name", "")
	probe_result["resumed"] = true
	_check(int(probe_result["match_time_ms"]) > 0, "rejoining client has no match time")
	_check(int(probe_result["tick"]) > 0, "rejoining client did not advance")
	_check(String(probe_result["team0_name"]) != "" and String(probe_result["team1_name"]) != "",
		"rejoining client has no team names")
	var cards: Dictionary = last_snapshot.get("referee_cards", {})
	probe_result["referee_cards_present"] = cards.get("yellow", {}).has("pos") \
		and cards.get("yellow", {}).has("raised") \
		and cards.get("red", {}).has("rot")
	_check(bool(probe_result["referee_cards_present"]),
		"rejoining client snapshot carries the referee card props")
	# The Game Plan (original: fatigue on the player cards) reads get_squad();
	# a mid-match rejoin must have valid values there.
	var plan_fatigue := -1
	for player in runtime.get_squad(1).get("players", []):
		if bool(player.get("active", false)) \
				and int(player.get("fatigue", -1)) >= 0 \
				and int(player.get("fatigue", -1)) <= 100:
			plan_fatigue = int(player.get("fatigue", -1))
			break
	probe_result["game_plan_fatigue"] = plan_fatigue
	_check(plan_fatigue >= 0,
		"the rejoining client Game Plan sees player fatigue (%d)" % plan_fatigue)
	return failures.is_empty()
