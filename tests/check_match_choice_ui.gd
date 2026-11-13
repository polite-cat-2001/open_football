extends SceneTree
# Headless check for the 90:00 draw choice screen: classic extra time, the SOON
# golden goal, the shootout straight away or accepting the draw.
#
# Run:  godot --headless --path . -s res://tests/check_match_choice_ui.gd

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var screen := preload("res://scenes/match/match_choice.tscn").instantiate() as MatchChoiceScreen
	get_root().add_child(screen)
	await process_frame

	screen.set_match_data(_data())
	screen.open()

	_check(screen.is_open(), "the choice screen opens")
	var tiles := screen.tiles()
	_check(tiles.size() == 4, "the choice screen has four tiles")
	_check(_titles(tiles) == ["CLASSIC", "GOLDEN GOAL", "PENALTIES", "DRAW"],
		"tiles are CLASSIC, GOLDEN GOAL, PENALTIES, DRAW")
	_check(tiles[1].disabled and tiles[1].chip == "SOON",
		"golden goal is a disabled SOON placeholder")
	_check(not tiles[0].disabled and not tiles[2].disabled and not tiles[3].disabled,
		"classic, penalties and draw are live")
	_check(screen.info_tile.title == "MATCH INFO", "the right panel is MATCH INFO")
	_check(tiles[0].has_focus(), "CLASSIC owns focus on entry")

	var chosen := [""]
	screen.option_chosen.connect(func(id: String): chosen[0] = id)

	screen.handle_key(_key(KEY_RIGHT))
	_check(tiles[0].has_focus(), "Right cannot land on the disabled golden goal")
	screen.handle_key(_key(KEY_DOWN))
	_check(tiles[2].has_focus(), "Down moves to PENALTIES")
	screen.handle_key(_key(KEY_ENTER))
	_check(chosen[0] == "penalties", "Enter on PENALTIES reports the choice")

	screen.handle_key(_key(KEY_RIGHT))
	_check(tiles[3].has_focus(), "Right moves to DRAW")
	screen.handle_key(_key(KEY_ENTER))
	_check(chosen[0] == "draw", "Enter on DRAW accepts the draw")

	screen.handle_key(_key(KEY_LEFT))
	screen.handle_key(_key(KEY_UP))
	_check(tiles[0].has_focus(), "Up returns to CLASSIC")
	screen.handle_key(_key(KEY_ENTER))
	_check(chosen[0] == "classic", "Enter on CLASSIC reports the choice")

	# Network: the host decides, so every choice is dead locally; the hint sits on
	# the tiles instead of the status line.
	chosen[0] = ""
	screen.set_online(true)
	_check(tiles[0].disabled and tiles[2].disabled and tiles[3].disabled,
		"every choice is disabled for the network client")
	_check(tiles[0].chip == "HOST CHOOSING" and tiles[1].chip == "HOST CHOOSING"
		and tiles[2].chip == "HOST CHOOSING" and tiles[3].chip == "HOST CHOOSING",
		"the client writes the host-choosing text on each tile")
	_check(screen.hints.status_text() == "",
		"the host-choosing text does not use the status line")
	screen.handle_key(_key(KEY_ENTER))
	_check(chosen[0] == "", "a network client never reports a choice")

	_finish()


func _data() -> Dictionary:
	return {
		"home": {"name": "BAYERN", "database_id": 4, "color1": Vector3(0.2, 0.3, 0.8)},
		"away": {"name": "SPURS", "database_id": 5, "color1": Vector3(0.9, 0.2, 0.2)},
		"score0": 1,
		"score1": 1,
		"caption": "",
		"meta": "International Cup",
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
		print("CHECK PASS: match choice screen")
		quit(0)
	else:
		print("CHECK FAIL: ", failures[0])
		quit(1)
