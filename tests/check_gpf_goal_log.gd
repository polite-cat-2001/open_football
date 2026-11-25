extends SceneTree
# Headless check for the goal log and the two banners it feeds (ticket 09):
# the GOAL banner (name only) during the celebration, the pre-kickoff scoreboard
# (crests, names, score and per-team scorers) once the kickoff is set up, and a
# fresh match clearing the log.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_goal_log.gd

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


func _snapshot(score0: int, score1: int, time_ms: int, goal := false,
		team := -1, scorer := -1) -> Dictionary:
	return {
		"match_duration": 1.0,
		"score0": score0,
		"score1": score1,
		"match_time_ms": time_ms,
		"goal_scored": goal,
		"last_goal_team": team,
		"last_goal_scorer": scorer,
	}


func _kickoff(snap: Dictionary) -> Dictionary:
	var out := snap.duplicate(true)
	out["goal_scored"] = false
	out["in_set_piece"] = true
	out["set_piece_type"] = 1
	out["referee_set_piece"] = 1
	return out


func _prepare(snap: Dictionary) -> Dictionary:
	var out := snap.duplicate(true)
	out["goal_scored"] = false
	out["referee_active"] = true
	out["referee_set_piece"] = 1
	out["referee_prepare_time"] = int(snap.get("match_time_ms", 0))
	out["actual_time_ms"] = int(snap.get("match_time_ms", 0))
	return out


func _run() -> void:
	var hud: GpfHud = GpfHudScript.new()
	get_root().add_child(hud)
	hud.setup(null)
	hud.set_match_package({
		"home": {"short_name": "Home", "players": [
			{"database_id": 10, "first_name": "Alpha", "last_name": "Alpha"},
			{"database_id": 12, "first_name": "Gamma", "last_name": "Gamma"},
		]},
		"away": {"short_name": "Away", "players": [
			{"database_id": 20, "first_name": "Beta", "last_name": "Beta"},
		]},
	})
	var banner := hud.get("event_banner") as EventBanner
	var kickoff := hud.get("kickoff_banner") as KickoffBanner
	hud.apply_snapshot(_snapshot(0, 0, 0), 7, 22, false, "Afternoon")
	hud.apply_snapshot(_kickoff(_snapshot(0, 0, 0)), 7, 22, false, "Afternoon")
	_check(kickoff.is_presented() and kickoff.size.y == KickoffBanner.BASE_H,
		"an empty kickoff banner has no scorer strip")

	hud.apply_snapshot(_snapshot(1, 0, 1380000, true, 0, 10), 7, 22, false, "Afternoon")
	_check(banner.is_presented() and banner.goal and banner.title == "GOAL",
		"the goal shows the GOAL banner")
	_check(banner.text == "Alpha", "the goal banner shows the scorer name")
	_check(banner.minute == "24'", "the goal banner shows the goal minute on the right")

	# The score + scorers appear only once the roll is on the centre spot: the
	# referee prepare phase starts a couple of seconds before the whistle.
	hud.apply_snapshot(_prepare(_snapshot(1, 0, 1390000)), 7, 22, false, "Afternoon")
	_check(kickoff.is_presented() and not banner.is_presented(),
		"the kickoff banner appears in the referee prepare phase")
	hud.apply_snapshot(_kickoff(_snapshot(1, 0, 1395000)), 7, 22, false, "Afternoon")
	_check(kickoff.is_presented() and not banner.is_presented(),
		"the pre-kickoff banner replaces the goal banner")
	_check(kickoff.score0 == 1 and kickoff.score1 == 0, "the kickoff banner shows the score")
	_check(kickoff.home_events.size() == 1 and kickoff.away_events.is_empty()
		and kickoff.home_events[0]["name"] == "Alpha"
		and not bool(kickoff.home_events[0]["card"]),
		"the home scorers sit above the home team")
	_check(kickoff.size.y == KickoffBanner.BASE_H + KickoffBanner.SCORER_LINE
		+ KickoffBanner.SCORER_GAP,
		"the kickoff banner grows for the scorer strip")

	hud.apply_snapshot(_snapshot(1, 0, 1400000), 7, 22, false, "Afternoon")
	_check(not kickoff.is_presented(), "the kickoff banner ends when play restarts")

	hud.apply_snapshot(_snapshot(2, 1, 4050000, true, 1, 20), 7, 22, false, "Afternoon")
	_check(banner.text == "Beta", "the next goal banner shows its scorer")
	hud.apply_snapshot(_kickoff(_snapshot(2, 1, 4060000)), 7, 22, false, "Afternoon")
	_check(kickoff.home_events.size() == 1 and kickoff.away_events.size() == 1
		and kickoff.away_events[0]["name"] == "Beta",
		"both teams' scorers are listed on their sides")
	_check(kickoff.score0 == 2 and kickoff.score1 == 1, "the kickoff banner updates the score")

	# An own goal is credited to the scoring team while the player belongs to the
	# other side: the banner and the kickoff line must say so.
	var own_goal := _snapshot(3, 2, 4070000, true, 0, 20)
	own_goal["spam_message"] = "OWN GOAL! Beta is so unlucky!"
	own_goal["spam_message_counter"] = 2
	own_goal["spam_message_time_ms"] = 4000
	own_goal["actual_time_ms"] = 1000
	hud.apply_snapshot(own_goal, 7, 22, false, "Afternoon")
	_check(banner.is_presented() and banner.goal and banner.title == "OWN GOAL"
		and banner.text == "Beta", "an own goal shows the OWN GOAL title")
	hud.apply_snapshot(_kickoff(_snapshot(3, 2, 4080000)), 7, 22, false, "Afternoon")
	var home_og := ""
	for event in kickoff.home_events:
		if String(event["name"]).ends_with("(OG)"):
			home_og = String(event["name"])
	_check(home_og == "Beta (OG)", "the kickoff list marks an own goal")

	# Red cards are drawn next to each team on both the kickoff banner and the
	# in-match scoreboard.
	var reds := _kickoff(_snapshot(2, 1, 4090000))
	reds["red_cards0"] = 1
	reds["red_cards1"] = 2
	reds["red_card_ids0"] = [12]
	reds["red_card_ids1"] = [20, 21]
	hud.apply_snapshot(reds, 7, 22, false, "Afternoon")
	var home_cards := 0
	for event in kickoff.home_events:
		if bool(event["card"]):
			home_cards += 1
	var away_cards := 0
	for event in kickoff.away_events:
		if bool(event["card"]):
			away_cards += 1
	_check(home_cards == 1 and away_cards == 2,
		"red cards are event lines, not a count, on the kickoff banner")
	var board := hud.get("scoreboard") as MatchScoreboard
	_check(board.red_cards0 == 1 and board.red_cards1 == 2,
		"the scoreboard shows red cards for both teams")

	# A live caption must not survive into the restarted match.
	var stale := _snapshot(2, 1, 4085000)
	stale["spam_message"] = "foul! yellow card"
	stale["spam_message_counter"] = 3
	stale["spam_message_time_ms"] = 4000
	stale["actual_time_ms"] = 1000
	hud.apply_snapshot(stale, 7, 22, false, "Afternoon")
	_check(banner.is_presented() and not banner.goal,
		"a live caption is up before the rematch")

	# A restarted match rewinds the clock; the old log must not leak into it.
	hud.apply_snapshot(_snapshot(0, 0, 0), 7, 22, false, "Afternoon")
	_check(not banner.is_presented(), "the rematch clears the stale caption")
	hud.apply_snapshot(_snapshot(0, 0, 1000), 7, 22, false, "Afternoon")
	hud.apply_snapshot(_snapshot(1, 0, 600000, true, 0, 12), 7, 22, false, "Afternoon")
	hud.apply_snapshot(_kickoff(_snapshot(1, 0, 610000)), 7, 22, false, "Afternoon")
	_check(kickoff.home_events.size() == 1 and kickoff.away_events.is_empty()
		and kickoff.home_events[0]["name"] == "Gamma",
		"a new match starts its own goal log")

	# The GOAL banner outranks a referee caption while the goal is being shown.
	var card := _snapshot(1, 0, 620000, true, 0, 12)
	card["spam_message"] = "foul! yellow card"
	card["spam_message_counter"] = 1
	card["spam_message_time_ms"] = 4000
	card["actual_time_ms"] = 1000
	hud.apply_snapshot(card, 7, 22, false, "Afternoon")
	_check(banner.is_presented() and banner.goal,
		"the goal banner wins over a referee caption")
	_check(not kickoff.is_presented(), "the kickoff banner is hidden during the goal")

	# A thin client has no scorer id; it parses the surname from the relayed goal
	# caption instead.
	var client: GpfHud = GpfHudScript.new()
	get_root().add_child(client)
	client.setup(null)
	client.apply_snapshot(_snapshot(0, 0, 0), 7, 22, false, "Afternoon")
	var client_goal := _snapshot(1, 0, 1380000, true, 0, -1)
	client_goal["spam_message"] = "GOAL for UNAM Pumas! Vite scores!"
	client_goal["spam_message_counter"] = 1
	client_goal["spam_message_time_ms"] = 4000
	client_goal["actual_time_ms"] = 1000
	client.apply_snapshot(client_goal, 7, 22, false, "Afternoon")
	var client_banner := client.get("event_banner") as EventBanner
	_check(client_banner.text == "Vite",
		"a thin client parses the scorer from the relayed goal caption")
	_check(client_banner.minute == "24'", "the client goal banner shows the minute")
	client.queue_free()

	# A thin client has no local referee buffer: the kickoff banner must follow
	# the relayed live set-piece type instead of the host's prepare window.
	var client_hud: GpfHud = GpfHudScript.new()
	get_root().add_child(client_hud)
	client_hud.setup(null)
	client_hud.set_net_client(true)
	var client_snap := _snapshot(0, 0, 10000)
	client_snap["referee_active"] = true
	client_snap["referee_set_piece"] = 1
	client_snap["referee_prepare_time"] = 0
	client_snap["actual_time_ms"] = 10000
	client_hud.apply_snapshot(client_snap, 7, 22, false, "Afternoon")
	var client_kickoff := client_hud.get("kickoff_banner") as KickoffBanner
	_check(client_kickoff.is_presented(),
		"a thin client shows the kickoff banner in the relayed prepare phase")
	client_snap["in_set_piece"] = true
	client_snap["set_piece_type"] = 4
	client_hud.apply_snapshot(client_snap, 7, 22, false, "Afternoon")
	_check(not client_kickoff.is_presented(),
		"a thin client does not show the kickoff banner on a corner")
	client_snap["set_piece_type"] = 1
	client_hud.apply_snapshot(client_snap, 7, 22, false, "Afternoon")
	_check(client_kickoff.is_presented(),
		"a thin client shows the kickoff banner on the relayed kickoff")

	# The status line must use the relayed referee state, not the client's stale
	# local buffer (which keeps the constructor's kickoff values).
	var status_snap := _snapshot(0, 0, 30000)
	status_snap["in_play"] = true
	status_snap["referee_active"] = false
	status_snap["referee_set_piece"] = 4
	status_snap["referee_prepare_time"] = 0
	status_snap["actual_time_ms"] = 30000
	client_hud.apply_snapshot(status_snap, 7, 22, false, "Afternoon")
	var legend := client_hud.get("hud") as Label
	_check(legend != null and legend.text.begins_with("LIVE"),
		"a thin client status line says LIVE in open play")
	var corner_snap := status_snap.duplicate(true)
	corner_snap["in_set_piece"] = true
	corner_snap["set_piece_type"] = 4
	corner_snap["referee_set_piece"] = 4
	corner_snap["referee_active"] = true
	client_hud.apply_snapshot(corner_snap, 7, 22, false, "Afternoon")
	_check(legend != null and legend.text.begins_with("CORNER"),
		"a thin client status line names the relayed corner")
	client_hud.queue_free()

	# The defending human's stick is the dive input (the game never hands the
	# selected outfielder the keeper role), so the dive hint belongs to the
	# defending human; the taker gets the aim hint instead.
	var defender_hud: GpfHud = GpfHudScript.new()
	get_root().add_child(defender_hud)
	defender_hud.setup(null)
	var penalty_snap := _snapshot(0, 0, 40000)
	penalty_snap["in_set_piece"] = true
	penalty_snap["set_piece_type"] = 6
	penalty_snap["referee_set_piece"] = 6
	penalty_snap["referee_active"] = true
	penalty_snap["set_piece_role"] = 0
	penalty_snap["human_team"] = 0
	penalty_snap["referee_team"] = 1
	penalty_snap["set_piece_taker"] = 3
	defender_hud.apply_snapshot(penalty_snap, 7, 22, false, "Afternoon")
	var defender_legend := defender_hud.get("hud") as Label
	_check(defender_legend != null and defender_legend.text.contains("keeper"),
		"a defending human gets the penalty dive hint")
	var taker_snap := penalty_snap.duplicate(true)
	taker_snap["human_team"] = 1
	taker_snap["referee_team"] = 1
	taker_snap["set_piece_role"] = 1
	taker_snap["set_piece_taker"] = 7
	defender_hud.apply_snapshot(taker_snap, 7, 22, false, "Afternoon")
	_check(defender_legend != null and not defender_legend.text.contains("keeper"),
		"the penalty taker is not told to dive")
	var keeper_snap := penalty_snap.duplicate(true)
	keeper_snap["set_piece_role"] = 2
	keeper_snap["set_piece_taker"] = 7
	defender_hud.apply_snapshot(keeper_snap, 7, 22, false, "Afternoon")
	_check(defender_legend != null and defender_legend.text.contains("keeper"),
		"a human keeper still gets the dive hint")
	# A free kick has no dive branch: the host must not be told to take the
	# client's kick unless it really is the local taker.
	var free_kick := _snapshot(0, 0, 41000)
	free_kick["in_set_piece"] = true
	free_kick["set_piece_type"] = 3
	free_kick["referee_set_piece"] = 3
	free_kick["referee_active"] = true
	free_kick["set_piece_role"] = 0
	free_kick["human_team"] = 0
	free_kick["referee_team"] = 1
	free_kick["set_piece_taker"] = 3
	free_kick["set_piece_human_taker"] = false
	defender_hud.apply_snapshot(free_kick, 7, 22, false, "Afternoon")
	_check(defender_legend != null and defender_legend.text.begins_with("FREE KICK")
		and not defender_legend.text.contains("S pass / D shot"),
		"the host is not told to take the client's free kick")
	free_kick["set_piece_human_taker"] = true
	defender_hud.apply_snapshot(free_kick, 7, 22, false, "Afternoon")
	_check(defender_legend != null and defender_legend.text.contains("S pass / D shot"),
		"the local taker is told to take the free kick")
	defender_hud.queue_free()

	# The bridge relayed on a thin client keeps last_goal_team at 0 even when the
	# away side scored; the HUD must use the score change instead.
	var net_hud: GpfHud = GpfHudScript.new()
	get_root().add_child(net_hud)
	net_hud.setup(null)
	net_hud.set_net_client(true)
	net_hud.apply_snapshot(_snapshot(0, 0, 10000), 7, 22, false, "Afternoon")
	net_hud.apply_snapshot(_snapshot(0, 1, 20000, true, 0, -1), 7, 22, false, "Afternoon")
	net_hud.apply_snapshot(_kickoff(_snapshot(0, 1, 21000)), 7, 22, false, "Afternoon")
	var net_kickoff := net_hud.get("kickoff_banner") as KickoffBanner
	_check(net_kickoff.away_events.size() == 1 and net_kickoff.home_events.is_empty(),
		"a thin client puts an away goal on the away side despite the stale goal team")
	net_hud.queue_free()

	# The banner is up for only a couple of seconds, so long lists grow it
	# instead of scrolling (the whole history must be readable at a glance).
	var tall_banner := KickoffBanner.new()
	get_root().add_child(tall_banner)
	tall_banner.set_teams({"short_name": "Home"}, {"short_name": "Away"})
	var many: Array[Dictionary] = []
	for i in 6:
		many.append({"minute": 10 + i, "name": "P%d" % i, "card": i == 2})
	tall_banner.set_match(3, 0, many, [])
	tall_banner.present(true)
	_check(tall_banner.size.y == KickoffBanner.BASE_H
		+ 6 * KickoffBanner.SCORER_LINE + KickoffBanner.SCORER_GAP,
		"six events grow the kickoff banner to six lines")
	var overflow: Array[Dictionary] = []
	for i in KickoffBanner.MAX_LINES + 2:
		overflow.append({"minute": i + 1, "name": "P%d" % i, "card": false})
	tall_banner.set_match(3, 0, overflow, [])
	_check(tall_banner.size.y == KickoffBanner.BASE_H
		+ (KickoffBanner.MAX_LINES + 1) * KickoffBanner.TIGHT_LINE
		+ KickoffBanner.SCORER_GAP,
		"an overlong list caps at MAX_LINES plus one ellipsis line")
	_check((tall_banner.get("_home_lines") as Array).size() == KickoffBanner.MAX_LINES + 1,
		"the visible list keeps the latest events and a marker")
	tall_banner.present(false)
	tall_banner.queue_free()

	# A rematch clears the card log as well as the goal log.
	var reset_hud: GpfHud = GpfHudScript.new()
	get_root().add_child(reset_hud)
	reset_hud.setup(null)
	reset_hud.apply_snapshot(_snapshot(0, 0, 0), 7, 22, false, "Afternoon")
	var cards := _snapshot(1, 0, 2700000)
	cards["red_cards0"] = 1
	cards["red_card_ids0"] = [10]
	reset_hud.apply_snapshot(cards, 7, 22, false, "Afternoon")
	reset_hud.reset()
	reset_hud.apply_snapshot(_kickoff(_snapshot(0, 0, 0)), 7, 22, false, "Afternoon")
	var reset_kickoff := reset_hud.get("kickoff_banner") as KickoffBanner
	_check(reset_kickoff.home_events.is_empty() and reset_kickoff.away_events.is_empty(),
		"a rematch starts with no cards from the previous match")
	reset_hud.queue_free()

	# A rejoin's first snapshot already carries the host's cards; they must not
	# be logged with the rejoin minute. Cards shown after it still are.
	var rejoin_hud: GpfHud = GpfHudScript.new()
	get_root().add_child(rejoin_hud)
	rejoin_hud.setup(null)
	var joined := _snapshot(1, 0, 2700000)
	joined["red_cards0"] = 1
	joined["red_card_ids0"] = [10]
	rejoin_hud.apply_snapshot(joined, 7, 22, false, "Afternoon")
	rejoin_hud.apply_snapshot(_kickoff(_snapshot(1, 0, 2760000)), 7, 22, false, "Afternoon")
	var rejoin_kickoff := rejoin_hud.get("kickoff_banner") as KickoffBanner
	_check(rejoin_kickoff.home_events.is_empty(),
		"a rejoin baseline does not invent red-card minutes")
	var late := _snapshot(1, 0, 2800000)
	late["red_cards0"] = 2
	late["red_card_ids0"] = [10, 12]
	rejoin_hud.apply_snapshot(late, 7, 22, false, "Afternoon")
	rejoin_hud.apply_snapshot(_kickoff(_snapshot(1, 0, 2810000)), 7, 22, false, "Afternoon")
	_check(rejoin_kickoff.home_events.size() == 1
		and bool(rejoin_kickoff.home_events[0].get("card", false)),
		"a card shown after a rejoin is still logged")
	rejoin_hud.queue_free()

	# A rejoin during the goal celebration must not guess the scoring side.
	var goal_rejoin_hud: GpfHud = GpfHudScript.new()
	get_root().add_child(goal_rejoin_hud)
	goal_rejoin_hud.setup(null)
	goal_rejoin_hud.set_net_client(true)
	goal_rejoin_hud.apply_snapshot(_snapshot(1, 1, 2700000, true, 0, -1),
		7, 22, false, "Afternoon")
	goal_rejoin_hud.apply_snapshot(_kickoff(_snapshot(1, 1, 2760000)),
		7, 22, false, "Afternoon")
	var goal_rejoin_kickoff := goal_rejoin_hud.get("kickoff_banner") as KickoffBanner
	_check(goal_rejoin_kickoff.home_events.is_empty()
		and goal_rejoin_kickoff.away_events.is_empty(),
		"a rejoin during the goal does not guess the scoring side")
	goal_rejoin_hud.queue_free()

	if failures.is_empty():
		print("CHECK PASS: goal log")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
