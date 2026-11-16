extends SceneTree
# Headless check for CareerTransferFilters (prototype TransferFilters.svelte):
# the 4x2 tile grid, focus walking, editing tiles (position/role, age, status,
# country/league/club cascade), the name tile's shared OSK, SEARCH/RESET and the
# hints contract the transfers host consumes.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_filters.gd

var failures: Array[String] = []
var _applied: Array[Dictionary] = []
var _closed := 0
var _viewport: SubViewport

const REFERENCE := {
	"countries": [
		{"id": "1", "name": "England"},
		{"id": "2", "name": "Spain"},
	],
	"leagues": [
		{"id": "EPL", "name": "Premier League", "country_id": "1"},
		{"id": "LIGA", "name": "LaLiga", "country_id": "2"},
	],
	"clubs": [
		{"id": "57", "name": "Arsenal", "league_id": "EPL"},
		{"id": "131", "name": "Barcelona", "league_id": "LIGA"},
	],
}


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


# Back the way UiNav delivers it: the event's modal state is latched before the
# signal goes out, so a modal that closes on it does not also reach the screen
# underneath (the widget lives in a SubViewport, so UiNav's own _input never sees
# the pushed keys).
func _ui_cancel(nav: Node) -> void:
	nav.set("_event_modal", nav.is_modal())
	nav.cancelled.emit()
	# UiNav relatches the flag on the next event; direct emits in this test must
	# not leave the screen deaf.
	nav.set("_event_modal", false)


func _finish() -> void:
	print("== check_career_transfer_filters: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = viewport
	var filters := CareerTransferFilters.new()
	filters.position = Vector2(128.0, 210.0)
	filters.size = Vector2(1664.0, 596.0)
	host.add_child(filters)
	filters.applied.connect(func(next: Dictionary) -> void: _applied.append(next))
	filters.closed.connect(func() -> void: _closed += 1)
	filters.setup({}, REFERENCE)
	await _frames(4)
	var nav := root.get_node("UiNav")

	# Geometry: eight tiles in 4x2 plus a right-aligned SEARCH / RESET pair.
	var tiles: Array = filters.get("_tiles")
	_check(tiles.size() == 8, "eight filter tiles are built")
	var cell := (1664.0 - 10.0 * 3.0) / 4.0
	_check(absf((tiles[0] as Control).size.x - cell) < 0.5, "a tile is a quarter of the width")
	_check((tiles[1] as Control).position.x > (tiles[0] as Control).position.x,
		"tiles run left to right")
	_check((tiles[4] as Control).position.y > (tiles[0] as Control).position.y,
		"the fifth tile starts the second row")
	_check((tiles[0] as Control).size.y > 0.0, "tiles fill the two rows")

	_check(filters.filters()["sort"] == "overall", "the filter schema carries every key")
	_check(filters.filters()["foot"] == "", "unset filters stay empty")
	_check(_value(tiles[0], 0) == "ANY", "the name tile starts at ANY")
	_check(_value(tiles[1], 0) == "ALL", "the position group starts at ALL")
	_check(_value(tiles[2], 0) == "ANY", "the citizenship tile starts at ANY")
	_check(_value(tiles[3], 0) == "ANY", "the league tile starts at ANY")
	_check(_value(tiles[4], 0) == "ANY" and _value(tiles[4], 1) == "ANY",
		"both age rows start at ANY")
	_check(_value(tiles[5], 0) == "ANY", "the status tile starts at ANY")
	_check(_value(tiles[6], 0) == "ANY", "the country tile starts at ANY")
	_check(_value(tiles[7], 0) == "PICK A LEAGUE",
		"the club tile asks for a league first")
	_check((tiles[4] as Control).get_node("Label").text == "AGE",
		"the age tile keeps the prototype label")

	# Focus walking: grid then actions, without wrapping.
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.get("_focus") == 1, "right walks to the next tile")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(filters.get("_focus") == 5, "down keeps the column on the second row")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(filters.get("_focus") == CareerTransferFilters.SEARCH_ACTION,
		"down from the last row reaches the actions")
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(filters.get("_focus") == 5, "up returns to the last tile")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(filters.get("_focus") == 4, "left walks the row")

	# Position & role: group and role rows step independently.
	filters.get("_tiles")[1].grab_focus() if false else null
	filters.set("_focus", 1)
	nav.confirmed.emit()
	await _frames(1)
	_check(filters.editing() == "role", "confirm opens the position tile")
	_check(filters.hints().size() == 3, "editing shows the short hint set")
	_check(_arrows(tiles[1], 0) and _arrows(tiles[1], 1),
		"both role rows show arrows while editing")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["group"] == "FWD", "right steps the group")
	_check(_value(tiles[1], 0) == "FWD", "the tile shows the new group")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(filters.get("_role_row") == "position", "down moves to the role row")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["position"] == "Goalkeeper", "right steps the role")
	_check(_badge(tiles[1], 1) == "GK", "the role row shows the position badge")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(filters.filters()["position"] == "", "left wraps back to any role")
	nav.confirmed.emit()
	await _frames(1)
	_check(filters.editing() == "", "confirm closes the tile")
	_check(not _arrows(tiles[1], 0), "arrows hide outside editing")

	# Age range: min/max rows, ANY cycling and the min<=max guard.
	filters.set("_focus", 4)
	nav.confirmed.emit()
	await _frames(1)
	_check(filters.editing() == "age", "confirm opens the age tile")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["age_min"] == 15, "right starts the minimum at 15")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["age_min"] == 16, "right steps the minimum")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["age_max"] == 15, "the maximum starts at 15")
	_check(filters.filters()["age_min"] == 15, "the guard keeps min below max")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(filters.filters()["age_max"] == 0, "stepping past the range clears to any")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(filters.filters()["age_max"] == 50, "stepping down from any jumps to the top")
	nav.confirmed.emit()
	await _frames(1)

	# Status cycles through the prototype option list.
	filters.set("_focus", 5)
	nav.confirmed.emit()
	await _frames(1)
	_check(_arrows(tiles[5], 0), "a single-value tile shows arrows while editing")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["status"] == "free", "the status starts at free agent")
	_check(_value(tiles[5], 0) == "FREE AGENT", "the status tile spells the state")
	nav.confirmed.emit()
	await _frames(1)

	# Country -> league -> club cascade.
	filters.set("_focus", 6)
	nav.confirmed.emit()
	await _frames(1)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["country_id"] == "1", "right picks the country")
	_check(_value(tiles[6], 0) == "England", "the country tile shows the name")
	nav.confirmed.emit()
	await _frames(1)
	filters.set("_focus", 3)
	nav.confirmed.emit()
	await _frames(1)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["league_id"] == "EPL",
		"the league list is narrowed by the country")
	nav.confirmed.emit()
	await _frames(1)
	filters.set("_focus", 7)
	nav.confirmed.emit()
	await _frames(1)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["club_id"] == "57", "the club list follows the league")
	_check(_value(tiles[7], 0) == "Arsenal", "the club tile shows the name")
	nav.confirmed.emit()
	await _frames(1)
	filters.set("_focus", 6)
	nav.confirmed.emit()
	await _frames(1)
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(filters.filters()["country_id"] == "2", "right steps the country")
	_check(filters.filters()["league_id"] == "" and filters.filters()["club_id"] == "",
		"changing the country clears the league and club")
	nav.confirmed.emit()
	await _frames(1)

	# The name tile opens the shared on-screen keyboard.
	filters.set("_focus", 0)
	nav.confirmed.emit()
	await _frames(2)
	var osk: UiOnScreenKeyboard = filters.get("_osk")
	_check(osk.is_open(), "the name tile opens the shared OSK")
	_check(nav.is_modal(), "the OSK owns input while it is open")
	nav.moved.emit(Vector2i.RIGHT)
	_check(filters.editing() == "", "the filter grid ignores input under the OSK")
	# Back closes only the keyboard: the filter screen must not also leave.
	_ui_cancel(nav)
	await _frames(2)
	_check(not osk.is_open(), "Back closes the on-screen keyboard")
	_check(not nav.is_modal(), "the modal stack is empty after the keyboard closes")
	_check(_closed == 0, "the keyboard's Back does not leave the filter screen")
	filters.set("_focus", 0)
	nav.confirmed.emit()
	await _frames(2)
	_check(osk.is_open(), "the name tile reopens the OSK")
	osk.press_character("R")
	osk.press_character("a")
	osk.press_apply()
	await _frames(3)
	_check(filters.filters()["name"] == "RA", "the applied name is upper-cased")
	_check(_value(tiles[0], 0) == "RA", "the name tile shows the search text")

	# X resets and Y searches (the prototype's hints).
	await _press(KEY_X)
	var reset_values := filters.filters()
	_check(reset_values["name"] == "" and reset_values["group"] == ""
		and reset_values["age_min"] == 0 and reset_values["country_id"] == "",
		"X clears every filter")
	await _press(KEY_Y)
	_check(_applied.size() == 1, "Y starts the search")
	_check(_applied[0] == filters.filters(), "search reports the current filters")

	filters.set("_focus", CareerTransferFilters.SEARCH_ACTION)
	nav.confirmed.emit()
	await _frames(1)
	_check(_applied.size() == 2, "the SEARCH action also reports")

	nav.cancelled.emit()
	await _frames(1)
	_check(_closed == 1, "Back leaves the screen")

	_check(filters.hints().size() == 5, "the idle hint set lists five controls")
	filters.set("_focus", 2)
	await _frames(1)
	filters.queue_free()
	_finish()


func _press(code: Key) -> void:
	# The widget lives in a SubViewport, so the event is pushed into that
	# viewport rather than the root window Input singleton.
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	_viewport.push_input(event)
	await _frames(2)
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	_viewport.push_input(release)
	await _frames(1)


func _value(tile, row: int) -> String:
	var rows: Array = tile.get("_rows")
	return (rows[row]["value"] as Label).text


func _arrows(tile, row: int) -> bool:
	var rows: Array = tile.get("_rows")
	return (rows[row]["left"] as Control).visible


func _badge(tile, row: int) -> String:
	var rows: Array = tile.get("_rows")
	return (rows[row]["badge"] as Label).text
