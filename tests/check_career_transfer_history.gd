extends SceneTree
# Headless check for the TRANSFER HISTORY screen (TransferHistory.svelte): the
# three filter tabs (all / my league / my club), the fee/OVR columns, the
# date/status cells, focus movement, the empty state and Back.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfer_history.gd

const HISTORY_SCRIPT := "res://scripts/ui/career_transfer_history.gd"
const CLUB_ID := 131
const SCREEN_SIZE := Vector2(1480.0, 688.4)

var failures: Array[String] = []
var catalog: TeamCatalog
var career: Career


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
	print("== check_career_transfer_history: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	catalog = TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	career = CareerFactory.create(catalog, CLUB_ID, "Golden Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return

	var own_league := str(catalog.career_club(CLUB_ID).get("league_id", ""))
	_check(not own_league.is_empty(), "the club has a league")
	var league_club := _league_club(own_league)
	_check(league_club > 0, "the league has a second club")
	var foreign := _foreign_clubs(own_league)
	_check(foreign.size() == 2, "the database has clubs outside the league")
	if league_club <= 0 or foreign.size() < 2:
		_finish()
		return

	var own_squad := catalog.career_squad(CLUB_ID)
	_check(own_squad.size() >= 3, "the club squad has players to move")
	if own_squad.size() < 3:
		_finish()
		return
	var first_id := str(own_squad[0].get("id", ""))
	var second_id := str(own_squad[1].get("id", ""))
	var third_id := str(own_squad[2].get("id", ""))
	career.transfer_history = [
		{"player_id": first_id, "from_club_id": str(league_club),
			"to_club_id": str(CLUB_ID), "fee": 50000000, "kind": "transfer",
			"status": "completed", "date": "2026-08-01", "overall": 84.0},
		{"player_id": second_id, "from_club_id": str(CLUB_ID),
			"to_club_id": str(league_club), "fee": 0, "kind": "loan",
			"status": "signed", "date": "2026-07-20", "overall": 78.0},
		{"player_id": third_id, "from_club_id": str(foreign[0]),
			"to_club_id": str(foreign[1]), "fee": 12000000, "kind": "transfer",
			"status": "completed", "date": "2026-06-10", "overall": 72.0},
	]
	var seeded := CareerTransfers.history_rows(career, catalog)
	_check(seeded.size() == 3, "the history rows build from the career")

	var nav := root.get_node("UiNav")
	var screen = load(HISTORY_SCRIPT).new()
	screen.name = "TransferHistory"
	root.add_child(screen)
	screen.size = SCREEN_SIZE
	await _frames(2)
	screen.open(career, catalog, {})
	await _frames(2)

	_check(screen.is_overlay(), "the history is an overlay of the transfers tab")
	_check(screen.row_count() == 3, "the list shows every deal")
	_check(screen.filter_id() == "all", "the history opens on ALL LEAGUES")
	_check(not screen.is_empty_state(), "a filled history hides the empty state")

	var rows: Array = screen.visible_rows()
	_check(str(rows[0].get("player_name", "")).to_upper()
		== str(catalog.career_player(int(first_id), false).get("name", "")).to_upper(),
		"the newest deal is the first row")
	_check(str(rows[0].get("status", "")) == "completed"
		and str(rows[1].get("status", "")) == "signed",
		"completed and signed deals keep their status")
	_check(int(rows[0].get("fee", 0)) == 50000000, "the fee survives the row")
	_check(str(rows[0].get("from_club_name", ""))
		== str(catalog.career_club(league_club).get("name", "")),
		"the from club name resolves from the catalog")

	var hints: Array = screen.hints()
	_check(hints.size() == 3 and str(hints[1]["label"]) == "filter"
		and hints[1]["keys"] == ["Q", "E"] and hints[2]["keys"] == ["ESC"],
		"the history advertises navigation/filter/back")

	screen.focus_initial()
	await _frames(1)
	_check(screen.focused_row() == -1, "the history opens on the filter tabs")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.focused_row() == 0, "Down reaches the first deal")
	nav.moved.emit(Vector2i.DOWN)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(screen.focused_row() == 2, "Down walks the list")
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(screen.focused_row() == 1, "Up walks back")
	nav.moved.emit(Vector2i.UP)
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(screen.focused_row() == -1, "Up from the first row returns to the tabs")

	nav.tab_next.emit()
	await _frames(1)
	_check(screen.filter_id() == "league", "Q/E turns to MY LEAGUE")
	_check(screen.row_count() == 2, "MY LEAGUE keeps the two domestic deals")
	_check(screen.focused_row() == -1, "the filter change returns focus to the tabs")
	nav.tab_next.emit()
	await _frames(1)
	_check(screen.filter_id() == "club" and screen.row_count() == 2,
		"MY CLUB keeps the two deals of the own club")
	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(screen.filter_id() == "all" and screen.row_count() == 3,
		"Right on the tabs cycles the filter")
	screen._input(_key(KEY_Q))
	await _frames(1)
	_check(screen.filter_id() == "club", "Q cycles the filter backwards")
	screen._input(_key(KEY_E))
	await _frames(1)
	_check(screen.filter_id() == "all", "E cycles the filter forwards")

	# The strip's marker travels between tabs: the filter rebuild must not
	# re-fit the strip and snap the marker into place.
	var bar: UiTabBar = screen.get("_tab_bar")
	_check(bar != null and bar.tab_count() == 3, "the history has a tab strip")
	bar.get_tab_button(2).pressed.emit()
	await _frames(1)
	var marker: Control = bar.get("_marker")
	_check(marker.position.x > 1.0, "the history marker starts travelling")
	await create_timer(0.35).timeout
	_check(absf(marker.position.x - bar.get_tab_button(2).position.x) < 0.5,
		"the history marker reaches the tab")
	bar.get_tab_button(0).pressed.emit()
	await _frames(1)
	_check(screen.filter_id() == "all", "the click switches back for the rest of the pass")

	# Rows are mostly informational; confirm must not leave the screen.
	var closes := [0]
	screen.closed.connect(func() -> void: closes[0] += 1)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	nav.confirmed.emit()
	_check(closes[0] == 0, "confirm on a deal is a no-op")
	nav.cancelled.emit()
	_check(closes[0] == 1, "Back closes the transfer history")

	# Fee, date and status cells.
	var row = screen._row_nodes[0] if not screen._row_nodes.is_empty() else null
	if row != null:
		_check(row._fee.text == CareerPlayerPane.money(50000000),
			"the fee cell uses the shared money format")
		_check(row._date.text == CareerHubModel.short_date("2026-08-01"),
			"the date cell uses the short date")
		_check(row._status.text == "COMPLETED", "the status cell is spelled out")
	screen.queue_free()

	# The AI market ledger feeds the same history: AI deals never involve the own
	# club, carry no status of their own and may have no seller at all.
	career.world_transfers = [
		{"id": "wt-1", "player_id": first_id, "player_name": "AI DEAL",
			"overall": 81.0, "from_club_id": foreign[0], "to_club_id": foreign[1],
			"fee": 9000000, "kind": "transfer", "date": "2026-07-25"},
		{"id": "wt-2", "player_id": second_id, "player_name": "FREE DEAL",
			"overall": 70.0, "from_club_id": null, "to_club_id": foreign[1],
			"fee": 0, "kind": "free_agent", "date": "2026-07-26"},
	]
	var merged := CareerTransfers.history_rows(career, catalog)
	_check(merged.size() == 5, "the history merges the own deals and the AI market")
	_check(str(merged[1].get("player_name", "")) == "FREE DEAL",
		"an AI deal slots in by date behind the newer own deal")
	_check(str(merged[1].get("kind_label", "")) == "Free agent"
		and str(merged[1].get("status", "")) == "completed",
		"an AI deal is completed and its free-agent kind is named")
	_check(str(merged[2].get("from_club_name", ""))
		== str(catalog.career_club(int(foreign[0])).get("name", "")),
		"an AI deal resolves both clubs")
	_check(str(merged[2].get("role", "")) == str(
			catalog.career_player(int(first_id), false).get("role", ""))
		and not str(merged[2].get("role", "")).is_empty(),
		"an AI deal gets its role from the batch read")

	var merged_screen = load(HISTORY_SCRIPT).new()
	root.add_child(merged_screen)
	merged_screen.size = SCREEN_SIZE
	await _frames(2)
	merged_screen.open(career, catalog, {})
	await _frames(1)
	_check(merged_screen.row_count() == 5, "the screen lists the AI deals too")
	merged_screen._set_filter(2)
	await _frames(1)
	_check(merged_screen.row_count() == 2, "MY CLUB keeps only the own deals")
	merged_screen.queue_free()

	# A long career must not hand the screen one node per deal ever recorded, and
	# the cap may not eat the club's own history.
	var many: Array = []
	for index in range(CareerTransfers.HISTORY_LIMIT + 50):
		many.append({"id": "cap-%d" % index, "player_id": first_id,
			"player_name": "CAP", "overall": 60.0, "from_club_id": foreign[0],
			"to_club_id": foreign[1], "fee": 0, "kind": "transfer",
			"date": "2026-09-01"})
	career.world_transfers = many
	var capped := CareerTransfers.history_rows(career, catalog)
	var own_rows := 0
	for deal in capped:
		if str(deal.get("from_club_id", "")) == str(CLUB_ID) \
				or str(deal.get("to_club_id", "")) == str(CLUB_ID):
			own_rows += 1
	_check(capped.size() == CareerTransfers.HISTORY_LIMIT,
		"the feed stops at the newest HISTORY_LIMIT deals")
	_check(own_rows == 2, "the cap trims the AI market, not the club's own history")

	# A long feed must not be built in one go: the screen paints the first chunk
	# and fills the rest over the following frames.
	var big_screen = load(HISTORY_SCRIPT).new()
	root.add_child(big_screen)
	big_screen.size = SCREEN_SIZE
	await _frames(2)
	big_screen.open(career, catalog, {})
	_check(big_screen.row_count() == CareerTransfers.HISTORY_LIMIT
		and big_screen._row_nodes.size() < big_screen.row_count(),
		"the screen builds only the first rows when it opens")
	_check(big_screen.is_visible_in_tree() and big_screen.is_processing(),
		"the rest of the feed keeps building")
	big_screen._focus_row_at(big_screen.row_count() - 1)
	_check(big_screen._row_nodes.size() == big_screen.row_count()
		and big_screen.focused_row() == big_screen.row_count() - 1,
		"focusing a row past the first chunk builds it on demand")
	big_screen.queue_free()

	# The background pump, not the focus path, must fill the rest of the feed.
	var fill_screen = load(HISTORY_SCRIPT).new()
	root.add_child(fill_screen)
	fill_screen.size = SCREEN_SIZE
	await _frames(2)
	fill_screen.open(career, catalog, {})
	await _frames(30)
	_check(fill_screen._row_nodes.size() == fill_screen.row_count(),
		"the remaining rows arrive over the following frames")
	fill_screen.queue_free()

	var empty_career := CareerFactory.create(catalog, CLUB_ID, "Golden Manager", 189, 44)
	var empty_screen = load(HISTORY_SCRIPT).new()
	root.add_child(empty_screen)
	empty_screen.size = SCREEN_SIZE
	await _frames(2)
	empty_screen.open(empty_career, catalog, {})
	await _frames(1)
	_check(empty_screen.row_count() == 0, "a new career has no deals")
	_check(empty_screen.is_empty_state(), "the empty history shows its empty state")
	empty_screen.queue_free()

	_finish()


func _league_club(league_id: String) -> int:
	for club in catalog.all_teams_for_league(league_id):
		var club_id := int(club.get("id", 0))
		if club_id != CLUB_ID and club_id > 0:
			return club_id
	return 0


func _foreign_clubs(league_id: String) -> Array:
	var clubs: Array = []
	for club in catalog.career_clubs():
		var club_league := str(club.get("league_id", ""))
		if club_league.is_empty() or club_league == league_id:
			continue
		var club_id := int(club.get("id", 0))
		if club_id <= 0 or clubs.has(str(club_id)):
			continue
		clubs.append(str(club_id))
		if clubs.size() == 2:
			break
	return clubs
