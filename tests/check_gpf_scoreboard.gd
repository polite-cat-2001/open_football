extends SceneTree
# Headless check for the in-match scoreboard (ticket 07): score/clock/phase come
# from the snapshot, crests from the match package, and the broadcast chrome
# stays up in replay and the shootout but hides on pause and the half-time break.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_scoreboard.gd

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


func _snapshot() -> Dictionary:
	return {
		"match_duration": 1.0,
		"score0": 2,
		"score1": 1,
		"match_time_ms": 2723000,
		"match_phase": 2,
	}


func _run() -> void:
	var hud: GpfHud = GpfHudScript.new()
	get_root().add_child(hud)
	hud.setup(null)
	hud.set_match_package({
		"home": {
			"database_id": 3,
			"logo_url": "databases/default/images_teams/3.png",
			"color1": Vector3(0.2, 0.3, 0.9),
		},
		"away": {
			"database_id": 8,
			"logo_url": "databases/default/images_teams/8.png",
			"color1": Vector3(0.9, 0.2, 0.2),
		},
	})
	hud.apply_snapshot(_snapshot(), 7, 22, false, "Afternoon")
	await process_frame

	var board := hud.get("scoreboard") as MatchScoreboard
	_check(board != null, "the HUD builds a scoreboard control")
	_check(board.score0 == 2 and board.score1 == 1, "the score comes from the snapshot")
	_check(board.clock_text == "45:23", "the clock comes from the snapshot")
	_check(board.home_crest != null and board.away_crest != null,
		"both crests come from the match package")
	_check(board.home_crest != null and board.home_crest.get_image().has_mipmaps(),
		"crests are mipmapped so the 180 px originals stay clean at 30 px")
	_check(board.visible, "the scoreboard is up in open play")

	var paused := _snapshot()
	paused["paused"] = true
	hud.apply_snapshot(paused, 7, 22, false, "Afternoon")
	_check(not board.visible, "the scoreboard hides on pause")

	var on_break := _snapshot()
	on_break["phase_break"] = true
	hud.apply_snapshot(on_break, 7, 22, false, "Afternoon")
	_check(not board.visible, "the scoreboard hides on the half-time break")

	hud.apply_snapshot(_snapshot(), 7, 22, false, "Afternoon")
	hud.set_replay_mode(true)
	hud.apply_snapshot(_snapshot(), 7, 22, false, "Afternoon")
	_check(board.visible, "the scoreboard stays up in replay")
	hud.set_replay_mode(false)

	var shootout := _snapshot()
	shootout["shootout_active"] = true
	hud.apply_snapshot(shootout, 7, 22, false, "Afternoon")
	_check(board.visible, "the scoreboard stays up in the shootout")

	var tv := hud.get("tv_logo") as TextureRect
	_check(tv != null and tv.texture != null and tv.anchor_left == 1.0
		and tv.anchor_right == 1.0 and tv.offset_right < 0.0,
		"the PDTV logo sits in the top-right corner")

	if failures.is_empty():
		print("CHECK PASS: match scoreboard")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
