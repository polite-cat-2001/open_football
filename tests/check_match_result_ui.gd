extends SceneTree
# Headless check for the end-of-match RESULT screen: a pause-style scoreboard
# header, a 2x2 bento block with two live tiles and two SOON placeholders, and
# the SOON information panel on the right.
#
# Run:  godot --headless --path . -s res://tests/check_match_result_ui.gd

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var screen := preload("res://scenes/match/match_result.tscn").instantiate() as MatchResultScreen
	get_root().add_child(screen)
	await process_frame

	screen.set_match_data(_data("International Cup"))
	screen.open()

	_check(screen.is_open(), "the result screen opens")
	var tiles := screen.tiles()
	_check(tiles.size() == 4, "the result screen has four tiles")
	_check(_titles(tiles) == ["ADVANCE", "RESTART MATCH", "MATCH HIGHLIGHTS",
		"PERFORMANCE"], "tiles are ADVANCE, RESTART, HIGHLIGHTS, PERFORMANCE")
	_check(not tiles[0].disabled and not tiles[1].disabled,
		"advance and restart are live")
	_check(tiles[2].disabled and tiles[3].disabled,
		"highlights and performance are SOON and disabled")
	_check(tiles[2].chip == "SOON" and tiles[3].chip == "SOON",
		"the placeholders carry the SOON chip")
	_check(screen.info_tile.title == "PLAYER PERFORMANCE",
		"the right panel is PLAYER PERFORMANCE")
	_check(screen.info_tile.disabled, "the right panel is a non-focusable placeholder")
	_check(is_equal_approx(screen.scoreboard.size.x, MatchOverScreen.PANEL_W),
		"the header uses the wide panel width")
	_check(str(screen.scoreboard.get("_clock")) == "FULL TIME",
		"the header clock reads FULL TIME")
	_check(screen.meta.text == "INTERNATIONAL CUP", "the competition meta line is shown")

	_check(tiles[0].has_focus(), "ADVANCE owns focus on entry")

	var advanced := [false]
	var restarted := [false]
	screen.advance_requested.connect(func(): advanced[0] = true)
	screen.restart_requested.connect(func(): restarted[0] = true)

	screen.handle_key(_key(KEY_RIGHT))
	_check(tiles[1].has_focus(), "Right moves to RESTART MATCH")
	screen.handle_key(_key(KEY_DOWN))
	_check(tiles[1].has_focus(), "Down skips the disabled SOON tiles")

	screen.handle_key(_key(KEY_ENTER))
	_check(restarted[0], "Enter on RESTART MATCH requests a restart")
	screen.handle_key(_key(KEY_LEFT))
	screen.handle_key(_key(KEY_ENTER))
	_check(advanced[0], "Enter on ADVANCE requests the main menu")

	# A LAN rematch goes through the lobby, so the local restart is shown dead.
	screen.set_online(true)
	_check(tiles[1].disabled, "RESTART MATCH is disabled in a network match")
	_check(tiles[1].chip == "ONLINE LOBBY", "the network restart explains itself")
	_check(tiles[0].has_focus() or not tiles[1].has_focus(),
		"the disabled restart never owns focus")

	_finish()


func _data(meta: String) -> Dictionary:
	return {
		"home": {"name": "BAYERN", "database_id": 4, "color1": Vector3(0.2, 0.3, 0.8)},
		"away": {"name": "SPURS", "database_id": 5, "color1": Vector3(0.9, 0.2, 0.2)},
		"score0": 5,
		"score1": 0,
		"caption": "",
		"meta": meta,
	}


func _titles(tiles: Array) -> Array:
	var names: Array = []
	for tile in tiles:
		names.append(String((tile as BentoTile).title))
	return names


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: match result screen")
		quit(0)
	else:
		print("CHECK FAIL: ", failures[0])
		quit(1)
