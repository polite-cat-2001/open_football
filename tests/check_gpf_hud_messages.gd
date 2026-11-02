extends SceneTree
# Headless check for the match message HUD (ticket 13): synthetic snapshots
# drive GpfHud directly (text, counter dedupe, expiry on actual_time_ms, reset,
# substitution banner regression), then a real match forces a goal and proves
# the bridge fills the same fields. In-match fatigue/card indicators are
# deliberately absent (the original HUD has none; Game Plan owns fatigue).
#
# Run:  godot --headless --path . -s res://tests/check_gpf_hud_messages.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MatchPackageFixture := preload("res://tests/match_package_fixture.gd")
const GpfHudScript := preload("res://scripts/match/gpf_hud.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	await _check_synthetic_hud()
	_check_bridge_messages()
	if failures.is_empty():
		print("== check_gpf_hud_messages: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_gpf_hud_messages: FAIL ==")
	quit(0 if failures.is_empty() else 1)


func _synthetic_snapshot() -> Dictionary:
	return {
		"actual_time_ms": 1000,
		"match_duration": 1.0,
		"spam_message": "GOAL for Old Team! Smith scores!",
		"spam_message_time_ms": 4000,
		"spam_message_counter": 3,
	}


func _check_synthetic_hud() -> void:
	print("-- synthetic snapshots --")
	var hud: GpfHud = GpfHudScript.new()
	get_root().add_child(hud)
	hud.setup(null)
	_check(hud.get("condition_panel") == null,
		"the in-match HUD has no fatigue/card block (Game Plan owns fatigue)")

	var base := _synthetic_snapshot()
	hud.apply_snapshot(base, 7, 22, false, "Afternoon")
	await process_frame
	var message := hud.get("message_label") as Label
	_check(message != null and not message.visible,
		"the first snapshot is a baseline: an old message is not replayed")
	_check(message != null and is_equal_approx(message.anchor_top, 0.085)
		and is_equal_approx(message.anchor_left, 0.05),
		"the message sits top-centre under the score line")

	var counter_snap := base.duplicate(true)
	counter_snap["spam_message_counter"] = 4
	counter_snap["spam_message"] = "FOUL! YELLOW CARD"
	counter_snap["actual_time_ms"] = 2000
	counter_snap["spam_message_time_ms"] = 3000
	hud.apply_snapshot(counter_snap, 7, 22, false, "Afternoon")
	_check(message.visible and message.text == "FOUL! YELLOW CARD",
		"a new counter shows the message text")
	var legend := hud.get("hud") as Label
	_check(legend != null and legend.position.y >= 130.0,
		"the dev legend moves below an active message")

	var same_counter := counter_snap.duplicate(true)
	same_counter["spam_message"] = "SHOULD NOT REPLACE"
	same_counter["actual_time_ms"] = 3000
	hud.apply_snapshot(same_counter, 7, 22, false, "Afternoon")
	_check(message.visible and message.text == "FOUL! YELLOW CARD",
		"the same counter never duplicates or replaces the message")

	var shootout := same_counter.duplicate(true)
	shootout["shootout_active"] = true
	hud.apply_snapshot(shootout, 7, 22, false, "Afternoon")
	_check(not message.visible, "the shootout circle rows suppress the message")
	shootout["shootout_active"] = false
	hud.apply_snapshot(shootout, 7, 22, false, "Afternoon")
	_check(message.visible, "the message returns after the shootout")

	var expired := same_counter.duplicate(true)
	expired["actual_time_ms"] = 5001
	hud.apply_snapshot(expired, 7, 22, false, "Afternoon")
	_check(not message.visible, "the message hides on actual_time_ms + duration")
	_check(legend != null and legend.position.y == 64.0,
		"the dev legend returns once the message is gone")

	counter_snap["actual_time_ms"] = 6000
	counter_snap["spam_message_counter"] = 5
	counter_snap["spam_message"] = ""
	hud.apply_snapshot(counter_snap, 7, 22, false, "Afternoon")
	_check(not message.visible, "an empty relayed message does not show a caption")

	var updated := base.duplicate(true)
	updated["spam_message_counter"] = 6
	updated["spam_message"] = "RED CARD!"
	updated["actual_time_ms"] = 7000
	updated["substitution_notice_counter"] = 1
	updated["substitution_notices"] = ["Jones off, Brown on"]
	hud.apply_snapshot(updated, 7, 22, false, "Afternoon")
	var sub_notice := hud.get("substitution_notice") as Label
	_check(sub_notice != null and sub_notice.visible
		and sub_notice.text == "Jones off, Brown on",
		"the substitution banner still works next to the message")

	hud.reset()
	_check(not message.visible and message.text == "",
		"reset hides and clears the message")
	_check(not sub_notice.visible, "reset hides the substitution banner")
	hud.apply_snapshot(updated, 7, 22, false, "Afternoon")
	_check(not message.visible,
		"after reset the next snapshot is a new baseline (F4/new match)")
	hud.queue_free()


func _check_bridge_messages() -> void:
	print("-- real match --")
	var package := MatchPackageFixture.build(DATA_ROOT, 3, 8, {"duration": 0.0})
	if package.is_empty():
		_check(false, "match package could not be built")
		return
	var runtime: Node = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		_check(false, "GpfRuntimeNode is not registered")
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("data_root", DATA_ROOT)
	if not runtime.set_match_package(package):
		_check(false, "runtime rejected the package")
		return
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		_check(false, "runtime did not start: " + String(runtime.get_last_error()))
		return

	var snap: Dictionary = {}
	for attempt in 6000:
		runtime.step_fixed(1)
		snap = runtime.get_snapshot()
		if bool(snap.get("in_play", false)) and not bool(snap.get("in_set_piece", false)):
			break
	_check(bool(snap.get("in_play", false)), "the match reached open play")
	if not bool(snap.get("in_play", false)):
		runtime.stop_match()
		return

	# Game Plan keeps its own fatigue source: get_squad(), as in the original.
	var squad_fatigue_found := false
	for player in runtime.get_squad(0).get("players", []):
		if bool(player.get("active", false)) and int(player.get("fatigue", -1)) >= 0 \
				and int(player.get("fatigue", -1)) <= 100:
			squad_fatigue_found = true
			break
	_check(squad_fatigue_found, "Game Plan still gets fatigue from get_squad")

	var controlled := -1
	for entry in runtime.get_player_ids():
		if int(entry.get("team", -1)) == 0 and String(entry.get("role", "")) == "player":
			controlled = int(entry.get("id", -1))
			break
	_check(controlled > 0, "the home side has an active outfield player")

	var hud: GpfHud = GpfHudScript.new()
	get_root().add_child(hud)
	hud.setup(runtime)
	hud.apply_snapshot(snap, controlled, 22, false, "Afternoon")
	var baseline_counter := int(snap.get("spam_message_counter", -1))
	_check(baseline_counter == 0, "the fresh match starts with no message")
	_check(snap.has("referee_cards")
		and not bool((snap.get("referee_cards", {}).get("yellow", {})).get("visible", true))
		and not bool((snap.get("referee_cards", {}).get("red", {})).get("visible", true)),
		"the fresh match has no referee card")
	_check(snap.has("referee_cards")
		and (snap.get("referee_cards", {}).get("yellow", {}) as Dictionary).has("pos")
		and (snap.get("referee_cards", {}).get("yellow", {}) as Dictionary).has("raised")
		and (snap.get("referee_cards", {}).get("red", {}) as Dictionary).has("rot"),
		"the bridge relays both referee card transforms")
	var message := hud.get("message_label") as Label

	runtime.debug_set_ball(
		Vector3(-54.6 * int(snap.get("team0_side", 1)), 3.4, 1.2),
		Vector3(-40.0 * int(snap.get("team0_side", 1)), 0.0, 0.0))
	runtime.debug_set_last_touch_team(0)
	var goal_snap: Dictionary = {}
	for attempt in 400:
		runtime.step_fixed(5)
		goal_snap = runtime.get_snapshot()
		if String(goal_snap.get("spam_message", "")) != "":
			break
	var goal_text := String(goal_snap.get("spam_message", ""))
	var goal_counter := int(goal_snap.get("spam_message_counter", 0))
	_check(goal_text.begins_with("GOAL for"), "a real goal fills spam_message: " + goal_text)
	_check(goal_counter > baseline_counter, "the goal increments spam_message_counter")
	_check(int(goal_snap.get("spam_message_time_ms", 0)) == 4000,
		"the bridge relays the message duration")
	_check(not goal_snap.has("player_condition"),
		"the bridge sends no in-match fatigue/card block")

	hud.apply_snapshot(goal_snap, controlled, 22, false, "Afternoon")
	_check(message.visible and message.text == goal_text,
		"the HUD shows the real goal message")
	_check(hud.get("condition_panel") == null,
		"the HUD never grew a fatigue/card block")

	runtime.step_fixed(600)
	var later: Dictionary = runtime.get_snapshot()
	hud.apply_snapshot(later, controlled, 22, false, "Afternoon")
	_check(not message.visible, "the real message expires on match time")
	hud.reset()
	_check(not message.visible, "reset hides the real message")
	hud.queue_free()
	runtime.stop_match()
