extends SceneTree
# Headless check for the TRANSFERS landing screen (TransferHub.svelte): the
# scouting reports card (feed page of six, pager, counts), the four hub cards,
# grid navigation, the navigate payloads, tab requests and Back.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_hub_screen.gd

const HUB_SCRIPT := "res://scripts/ui/career_transfer_hub.gd"
const CLUB_ID := 131
const SCREEN_SIZE := Vector2(1480.0, 626.4)

var failures: Array[String] = []
var catalog: TeamCatalog


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _finish() -> void:
	print("== check_career_transfer_hub_screen: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	if not _load_catalog():
		_finish()
		return
	var career := CareerFactory.create(catalog, CLUB_ID, "Golden Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var feed_size := _seed_reports(career)
	_check(feed_size == 8, "eight completed reports fill the feed (got %d)" % feed_size)
	var snapshot := CareerScouting.snapshot(career, catalog)
	_check((career.data.get("scouts", []) as Array).size() == 2,
		"the two starting scouts are hired")

	var nav := root.get_node("UiNav")
	var hub = load(HUB_SCRIPT).new()
	hub.name = "TransferHub"
	root.add_child(hub)
	hub.size = SCREEN_SIZE
	await _frames(2)
	hub.open(career, catalog, {})
	await _frames(2)

	_check(hub.card_count() == 4, "the hub shows four cards")
	_check(hub.is_overlay() == false, "the landing is not an overlay")
	_check(hub.page_count() == 2, "eight reports make two pages")
	_check(hub.feed_page().size() == 6, "a page shows six report slots")
	var feed: Array = snapshot.get("feed", [])
	_check(hub.feed_page()[0] == feed[0], "the first page starts at the newest report")
	_check(int(hub._counts.get("new", -1)) == int(snapshot["counts"].get("new", -2)),
		"the NEW counter matches the snapshot")
	_check(int(hub._counts.get("updates", -1)) == int(snapshot["counts"].get("updates", -2)),
		"the UPDATES counter matches the snapshot")

	var hints: Array = hub.hints()
	_check(hints.size() == 4, "the hub advertises four hints")
	_check(str(hints[0]["label"]) == "navigate" and hints[0]["keys"] == ["↑", "↓", "←", "→"],
		"arrows move between the tiles, they do not page the feed")
	_check(hints[1]["keys"] == ["ENTER"] and hints[2]["keys"] == ["Q", "E"]
		and hints[3]["keys"] == ["ESC"], "keyboard hints list select/tabs/back")

	hub.focus_initial()
	await _frames(1)
	_check(hub.focused_index() == 0, "the reports card owns the first focus")

	# The feed pages from the widget's own arrows, never from the keyboard.
	hub.call("_shift_page", 1)
	await _frames(1)
	_check(hub.page() == 1, "the pager moves the report feed forward")
	_check(hub.feed_page()[0] == feed[6], "the second page starts at the seventh report")
	hub.call("_shift_page", -1)
	await _frames(1)
	_check(hub.page() == 0, "the pager turns the page back")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(hub.page() == 0 and hub.focused_index() == 1,
		"Right leaves the reports card for the next tile instead of paging")
	hub.focus_index(0)
	await _frames(1)

	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(hub.focused_index() == 3, "Down from the reports card reaches WORLD NETWORK")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(hub.focused_index() == 4, "Right reaches HISTORY")
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(hub.focused_index() == 2, "Up reaches TRANSFER CENTRE")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(hub.focused_index() == 1, "Left reaches SEARCH PLAYERS")
	var edges: Array = []
	hub.edge_requested.connect(func(direction: Vector2i) -> void: edges.append(direction))
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(hub.focused_index() == 1 and edges == [Vector2i.UP],
		"Up from the top row asks the hub for the tab strip")

	var opened: Array = []
	hub.navigate.connect(func(view: String, payload: Dictionary) -> void:
		opened.append({"view": view, "payload": payload}))
	hub.focus_index(1)
	nav.confirmed.emit()
	_check(opened.size() == 1 and opened[0]["view"] == "filters"
		and (opened[0]["payload"] as Dictionary).is_empty(),
		"SEARCH PLAYERS opens the filters")
	hub.focus_index(2)
	nav.confirmed.emit()
	_check(opened.size() == 2 and opened[1]["view"] == "centre",
		"TRANSFER CENTRE opens the centre")
	hub.focus_index(3)
	nav.confirmed.emit()
	_check(opened.size() == 3 and opened[2]["view"] == "network"
		and str((opened[2]["payload"] as Dictionary).get("mode", "")) == "scouts",
		"WORLD NETWORK opens the scouts")
	hub.focus_index(4)
	nav.confirmed.emit()
	_check(opened.size() == 4 and opened[3]["view"] == "history",
		"HISTORY opens the history")

	hub.focus_index(0)
	nav.confirmed.emit()
	var first_player := str((feed[0].get("player", {}) as Dictionary).get("player_id", ""))
	_check(opened.size() == 5 and opened[4]["view"] == "network"
		and str((opened[4]["payload"] as Dictionary).get("mode", "")) == "reports"
		and str((opened[4]["payload"] as Dictionary).get("player_id", "")) == first_player,
		"the reports card opens the reports centre on its first entry")

	var tabs: Array = []
	hub.tab_requested.connect(func(delta: int) -> void: tabs.append(delta))
	nav.tab_next.emit()
	nav.tab_previous.emit()
	_check(tabs == [1, -1], "LB/RB ask the host for the next/previous tab")
	hub._input(_key(KEY_E))
	hub._input(_key(KEY_Q))
	_check(tabs == [1, -1, 1, -1], "E/Q ask the host for the next/previous tab")

	var closes := [0]
	hub.closed.connect(func() -> void: closes[0] += 1)
	nav.cancelled.emit()
	_check(closes[0] == 1, "Back leaves the transfers section")

	# The shell's tab strip owns focus when the section opens; the hub's late
	# (windowed) visibility hook must not steal it back. With no owner at all
	# (a return from a subview) it restores the last card.
	var strip := Button.new()
	root.add_child(strip)
	strip.grab_focus()
	await _frames(1)
	hub.visible = false
	hub.visible = true
	await _frames(2)
	_check(strip.has_focus(), "showing the hub leaves the shell focus alone")
	hub.visible = false
	strip.release_focus()
	await _frames(1)
	hub.visible = true
	await _frames(2)
	_check((hub.get_node("Reports") as Control).has_focus(),
		"showing the hub with no focus owner restores the card")
	strip.queue_free()
	hub.queue_free()

	# A brand-new career has no reports: one empty page, no pager.
	var fresh := CareerFactory.create(catalog, CLUB_ID, "Golden Manager", 189, 43)
	var empty_hub = load(HUB_SCRIPT).new()
	root.add_child(empty_hub)
	empty_hub.size = SCREEN_SIZE
	await _frames(2)
	empty_hub.open(fresh, catalog, {})
	await _frames(1)
	_check(empty_hub.page_count() == 1, "an empty feed has a single page")
	_check(empty_hub.feed_page().is_empty(), "an empty feed has no entries")
	var empty_hints: Array = empty_hub.hints()
	_check(str(empty_hints[0]["label"]) == "navigate"
		and empty_hints[0]["keys"] == ["↑", "↓", "←", "→"],
		"the hints always advertise navigation now that paging is mouse-only")
	var empty_opened: Array = []
	empty_hub.navigate.connect(func(view: String, payload: Dictionary) -> void:
		empty_opened.append({"view": view, "payload": payload}))
	empty_hub.focus_index(0)
	nav.confirmed.emit()
	_check(empty_opened.size() == 1
		and str((empty_opened[0]["payload"] as Dictionary).get("player_id", "x")).is_empty(),
		"the empty reports card still opens with no entry")
	empty_hub.queue_free()

	_finish()


func _load_catalog() -> bool:
	catalog = TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	return catalog.is_loaded()


# Two scouts, four rounds: each completed report lands in the feed.
func _seed_reports(career: Career) -> int:
	CareerScouting.ensure_scouts(career)
	var opponent_id := _opponent_club()
	_check(opponent_id > 0, "the league has a second club to scout")
	if opponent_id <= 0:
		return 0
	var targets: Array = []
	for player in catalog.career_squad(opponent_id):
		if targets.size() >= 8:
			break
		targets.append(str(player.get("id", "")))
	var next := 0
	for round_index in 4:
		for scout in CareerScouting.assignable_scouts(career):
			if next >= targets.size():
				break
			var started := CareerScouting.assign(career, catalog,
				str(scout.get("id", "")), targets[next])
			_check(bool(started.get("ok", false)),
				"report %d starts: %s" % [next, str(started.get("error"))])
			next += 1
		var due := ""
		for scout in CareerScouting.snapshot(career, catalog).get("scouts", []):
			var report = scout.get("report")
			if not (report is Dictionary):
				continue
			var due_at := str(report.get("due_at", ""))
			if due.is_empty() or due_at > due:
				due = due_at
		if due.is_empty():
			break
		CareerScouting.process_days(career, catalog, career.date, due)
		career.data["date"] = due
	return (CareerScouting.snapshot(career, catalog).get("feed", []) as Array).size()


func _opponent_club() -> int:
	for club in catalog.all_teams_for_league(str(career_league())):
		var club_id := int(club.get("id", 0))
		if club_id != CLUB_ID and catalog.career_squad(club_id).size() >= 8:
			return club_id
	return 0


func career_league() -> String:
	return str(catalog.career_club(CLUB_ID).get("league_id", ""))
