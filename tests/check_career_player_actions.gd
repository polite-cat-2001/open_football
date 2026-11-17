extends SceneTree
# Headless check for CareerPlayerActions (prototype PlayerActionsModal.svelte):
# the header / metrics fog, the status lines, the exact row set for a club
# player / a scouted player / a free agent, the disabled reasons, the shortlist
# toggle, the scout picker hand-off and the offer / contract routes.
#
# Run:  godot --headless --path . -s res://tests/check_career_player_actions.gd

const FIXTURE := "res://tests/fixtures/career_save_prototype.json"
const SCOUTS := [
	{"id": "s1", "name": "Ivan Petrov", "experience": 3, "judgement": 4},
]

var failures: Array[String] = []
var _routes: Array[Dictionary] = []
var _changed := 0
var _closed := 0
var _scouts_assigned: Array[String] = []
var _assign_scouts := false


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


# A real left click at `position` (viewport coordinates), the way a mouse does.
func _click(viewport: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	viewport.push_input(event)


func _finish() -> void:
	print("== check_career_player_actions: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check(raw is Dictionary, "the prototype save fixture parses")
	if not (raw is Dictionary):
		_finish()
		return
	var career := Career.from_save(raw)
	_check(career != null, "the prototype career loads")
	if career == null:
		_finish()
		return

	var page := CareerSearch.search(catalog, career,
		{"league": "ES1", "sort": "overall", "direction": "desc"}, 200, 0)
	var items: Array = page.get("items", [])
	_check(items.size() == 200, "the search returns a pool of players")
	var player: Dictionary = {}
	for candidate in items:
		if not bool(candidate.get("scouted", false)) \
				and not str(candidate.get("club_id", "")).is_empty():
			player = candidate
			break
	_check(not player.is_empty(), "an unscouted club player is available")
	if player.is_empty():
		_finish()
		return
	var club_player := player.duplicate(true)
	var scouted := player.duplicate(true)
	scouted["scouted"] = true
	scouted["overall"] = 84.0
	scouted["pot"] = 89.0
	scouted["foot"] = "right"
	scouted["market_value"] = 42000000
	scouted["weekly_wage"] = 95000
	var free_agent := player.duplicate(true)
	free_agent["status"] = "free"
	free_agent["club_id"] = ""
	free_agent["club_name"] = ""
	free_agent["club_logo"] = ""
	free_agent["contract_expires"] = ""
	var expiring: Dictionary = {}
	var steady: Dictionary = {}
	for candidate in items:
		if str(candidate.get("club_id", "")).is_empty():
			continue
		if CareerTransferContracts.can_discuss(catalog, career, candidate):
			if expiring.is_empty():
				expiring = candidate.duplicate(true)
		elif steady.is_empty():
			steady = candidate.duplicate(true)
	_check(not expiring.is_empty(), "a player with an expiring contract is available")
	_check(not steady.is_empty(), "a player with a running contract is available")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var nav := root.get_node("UiNav")

	var modal := CareerPlayerActions.new()
	modal.size = Vector2(1920.0, 1080.0)
	host.add_child(modal)
	modal.navigate.connect(func(view: String, payload: Dictionary) -> void:
		_routes.append({"view": view, "payload": payload}))
	modal.changed.connect(func() -> void: _changed += 1)
	modal.closed.connect(func() -> void: _closed += 1)
	modal.scout_requested.connect(func(scout_id: String) -> void:
		_scouts_assigned.append(scout_id)
		# The real hosts (transfer results / centre) assign synchronously here.
		if _assign_scouts:
			CareerScouting.assign(career, catalog, scout_id, modal.player_id()))
	await _frames(2)

	# Unscouted club player, no free scouts ---------------------------------
	modal.setup(career, catalog, club_player, {"scouts": [], "date": career.date})
	modal.open()
	await _frames(2)
	_check(modal.is_open(), "the modal opens")
	_check(nav.is_modal() and nav.modal_owner() == modal, "the modal owns input")
	_check(modal.row_ids() == ["scout", "shortlist", "offer_transfer", "offer_loan",
		"discuss"], "a club player lists all five actions")
	_check(modal.row_label("scout") == "HIRE A SCOUT", "no scouts: the row asks to hire one")
	_check(not modal.row_enabled("scout"), "the hire row is not an action")
	_check(modal.row_ticket("scout") == "NETWORK", "the hire row sends you to the network")
	_check(modal.row_label("shortlist") == "ADD TO SHORTLIST", "the shortlist offers to add")
	_check(modal.row_enabled("offer_transfer") and modal.row_enabled("offer_loan"),
		"club offers are available")
	_check(not modal.row_enabled("discuss"), "an unscouted running contract cannot be discussed")
	_check(modal.row_ticket("discuss") == "NOT EXPIRING", "the discuss row explains why")
	var foot: Label = ((modal.get("_pane") as CareerPlayerPane).get("_fact_values") as Array)[3]
	_check(foot.text == "?", "an unscouted foot stays hidden")
	var metrics: Array = (modal.get("_pane") as CareerPlayerPane).get("_metric_values")
	_check((metrics[0] as Label).text == "?" and (metrics[1] as Label).text == "?"
		and (metrics[2] as Label).text == "?", "fog hides overall, price and wage")
	_check((metrics[3] as Label).text == CareerPlayerPane.money(
		int(club_player.get("release_clause", 0))), "the release clause stays visible")
	var status_box: VBoxContainer = (modal.get("_pane") as CareerPlayerPane).get("_status_box")
	_check(status_box.get_child_count() >= 2, "the status and the contract line are shown")

	# Focus walks the rows, Back closes -------------------------------------
	var first_row: CareerPlayerPane.ActionRow = modal.get("_rows")[0]
	_check(first_row.has_focus(), "the first row takes focus, disabled or not")
	# The pane must own a real height: a collapsed ScrollContainer showed only
	# the first action row of the card.
	var pane_box: Control = modal.get("_pane")
	_check(pane_box.size.y > 300.0, "the player pane gets its full height")
	var rows: Array = modal.get("_rows")
	var last_row: Control = rows[rows.size() - 1]
	_check(last_row.position.y + last_row.size.y <= modal.get_node("Card").size.y + 0.5,
		"every action row fits inside the card")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check((modal.get("_rows") as Array)[1].has_focus(), "down walks the rows")
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check((modal.get("_rows") as Array)[2].has_focus(), "down reaches the offer row")
	nav.cancelled.emit()
	await _frames(2)
	_check(not modal.is_open(), "Back closes the modal")
	_check(_closed == 1, "the modal reports its close")
	_check(not nav.is_modal(), "input returns to the host")

	# Backdrop click ---------------------------------------------------------
	modal.open()
	await _frames(2)
	_check(modal.get_node("Scrim").size == modal.size, "the scrim covers the whole screen")
	_click(viewport, Vector2(6.0, 6.0))
	await _frames(2)
	_check(not modal.is_open(), "a click on the backdrop closes the modal")
	_check(not nav.is_modal(), "the click also frees the modal stack")

	# Shortlist toggle ------------------------------------------------------
	var player_id := str(club_player["player_id"])
	_check(not career.shortlist.has(player_id), "the player starts off the shortlist")
	modal.setup(career, catalog, club_player, {"scouts": []})
	modal.open()
	await _frames(2)
	(modal.get("_by_id")["shortlist"] as CareerPlayerPane.ActionRow).grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(career.shortlist.has(player_id), "the toggle writes the shortlist")
	_check(_changed == 1, "the modal reports the change")
	_check(modal.row_label("shortlist") == "REMOVE FROM SHORTLIST", "the row flips in place")
	_check(modal.is_open(), "toggling keeps the modal open")

	# Offer routes ----------------------------------------------------------
	(modal.get("_by_id")["offer_transfer"] as CareerPlayerPane.ActionRow).grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(_routes.size() == 1 and _routes[0]["view"] == "offer",
		"the transfer offer leaves for the offer screen")
	_check(str(_routes[0]["payload"].get("kind", "")) == "transfer", "the kind is a transfer")
	_check(str(_routes[0]["payload"].get("player_id", "")) == player_id,
		"the route carries the player")
	var preset: Dictionary = _routes[0]["payload"].get("preset", {})
	_check(preset.has("fee") and preset.has("can_submit"),
		"the route carries the proposal preset")
	_check(not modal.is_open() and not nav.is_modal(),
		"the route hands the card over to the offer screen")
	_check(modal.resume(), "the card comes back after the offer screen")
	_check(modal.is_open() and nav.modal_owner() == modal,
		"the returned card owns input again")

	modal.setup(career, catalog, club_player, {"scouts": []})
	modal.open()
	await _frames(2)
	(modal.get("_by_id")["offer_loan"] as CareerPlayerPane.ActionRow).grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(_routes.size() == 2 and str(_routes[1]["payload"].get("kind", "")) == "loan",
		"the loan offer routes with the loan kind")

	# Free scouts, picker and reports ---------------------------------------
	modal.setup(career, catalog, club_player, {"scouts": SCOUTS})
	modal.open()
	await _frames(2)
	_check(modal.row_label("scout") == "ASSIGN SCOUT", "free scouts offer an assignment")
	_check(modal.row_enabled("scout"), "the assignment row is an action")
	(modal.get("_by_id")["scout"] as CareerPlayerPane.ActionRow).grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	var picker: CareerScoutPicker = modal.get("_picker")
	_check(picker != null and picker.is_open(), "the scout picker opens over the modal")
	_check(picker.scout_ids() == ["s1"], "the picker lists the free scouts")
	_check(nav.modal_owner() == picker, "the picker owns input while it is open")
	nav.confirmed.emit()
	await _frames(2)
	_check(not picker.is_open(), "assigning closes the picker")
	_check(_scouts_assigned.size() == 1 and _scouts_assigned[0] == "s1",
		"the assignment reports the scout")
	_check(modal.is_open(), "the actions stay open behind the picker")

	modal.setup(career, catalog, club_player, {
		"scouts": SCOUTS,
		"report": {"player_id": player_id, "kind": "studying",
			"scout_name": "Nils Berg", "days_left": 3},
	})
	_check(modal.row_label("scout") == "NILS BERG IS WATCHING", "a running report names the scout")
	_check(modal.row_enabled("scout"), "a running report offers a recall")
	_check(modal.row_ticket("scout") == "3 DAYS LEFT", "the report row counts the days")
	modal.call("_open_picker")
	_check(not (modal.get("_picker") as CareerScoutPicker).is_open(),
		"a player who is already watched offers no scout picker")

	# A live assignment lands on the card without a reopen -------------------
	_assign_scouts = true
	var free_scout: Dictionary = CareerScouting.assignable_scouts(career)[0]
	modal.setup(career, catalog, club_player, {"scouts": [free_scout], "date": career.date})
	_check(modal.row_label("scout") == "ASSIGN SCOUT", "a free scout is offered again")
	(modal.get("_by_id")["scout"] as CareerPlayerPane.ActionRow).grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check((modal.get("_picker") as CareerScoutPicker).is_open(),
		"re-opened, the picker waits for its own confirm")
	nav.confirmed.emit()
	await _frames(2)
	_check(modal.row_label("scout")
		== "%s IS WATCHING" % str(free_scout.get("name", "")).to_upper(),
		"the card switches to the scout who is now watching")
	_check(modal.row_enabled("scout"), "the watching row is an action")
	_assign_scouts = false

	# Confirming it offers the recall card ----------------------------------
	var before_recall := _changed
	nav.confirmed.emit()
	await _frames(2)
	var recall := modal.get("_recall_modal") as CareerScoutingModal
	_check(recall != null and recall.is_open(), "the watching row opens the recall card")
	_check(recall.row_ids() == ["recall", "cancel"], "the recall card offers recall and cancel")
	_check(nav.modal_owner() == recall, "the recall card owns input")
	nav.confirmed.emit()
	await _frames(2)
	_check(not recall.is_open(), "recalling closes the card")
	_check(modal.row_label("scout") == "ASSIGN SCOUT", "the recall frees the row again")
	_check(CareerScouting.report_for(career, club_player["player_id"]).is_empty(),
		"the recalled scout dropped the player")
	_check(_changed == before_recall + 1, "the recall reports the change")

	# A scouted player hides the scout row and reveals the numbers -----------
	modal.setup(career, catalog, scouted, {"scouts": SCOUTS})
	modal.open()
	await _frames(2)
	_check(not modal.row_ids().has("scout"), "a scouted player needs no scout row")
	var revealed_metrics: Array = (modal.get("_pane") as CareerPlayerPane).get("_metric_values")
	_check((revealed_metrics[0] as Label).text == "84", "a scouted overall is shown")
	_check((revealed_metrics[1] as Label).text == CareerPlayerPane.money(42000000),
		"a scouted price is shown")
	_check(((modal.get("_pane") as CareerPlayerPane).get("_fact_values") as Array)[3].text == "Right", "a scouted foot is shown")

	# Free agent ------------------------------------------------------------
	modal.setup(career, catalog, free_agent, {"scouts": []})
	await _frames(1)
	_check(modal.row_ids() == ["scout", "shortlist", "discuss"],
		"a free agent has no club offers")
	_check(modal.row_enabled("discuss"), "a free agent can discuss a move")
	_check(modal.row_ticket("discuss") == "A", "the discuss row is an action")
	modal.open()
	await _frames(2)
	(modal.get("_by_id")["discuss"] as CareerPlayerPane.ActionRow).grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(_routes.size() == 3 and _routes[2]["view"] == "contract",
		"discussing opens the contract screen")
	_check(str(_routes[2]["payload"].get("player_id", ""))
		== str(free_agent["player_id"]), "the contract route carries the player")

	# Expiring / running contracts -----------------------------------------
	if not expiring.is_empty():
		modal.setup(career, catalog, expiring, {"scouts": []})
		_check(modal.row_enabled("discuss"), "an expiring contract can be discussed")
	if not steady.is_empty():
		modal.setup(career, catalog, steady, {"scouts": []})
		_check(not modal.row_enabled("discuss"), "a running contract cannot be discussed")

	# A pending offer removes the send rows ---------------------------------
	var today := str(career.date)
	var offer := {
		"id": "test-offer", "player_id": player_id, "kind": "transfer",
		"amount": 1, "status": "pending", "signed": false,
	}
	career.transfer_offers.append(offer)
	modal.setup(career, catalog, club_player, {"scouts": []})
	_check(modal.row_ids() == ["scout", "shortlist", "offer_blocked", "discuss"],
		"a pending offer removes the transfer and loan rows")
	_check(modal.row_label("offer_blocked") == "OFFER IS WITH THE CLUB",
		"the pending row names the state")
	_check(modal.row_ticket("offer_blocked") == "TRANSFER CENTRE",
		"the pending row points at the centre")
	_check(not modal.row_enabled("offer_blocked"), "the pending row is not an action")

	# Refused: no offers until the retry date -------------------------------
	offer["status"] = "refused"
	offer["retry_after"] = CareerSearch.add_days(today, 3)
	career.data["date"] = today
	modal.setup(career, catalog, club_player, {"scouts": []})
	_check(modal.row_ids() == ["scout", "shortlist", "offer_blocked", "discuss"],
		"a refusal inside its cooldown removes the send rows")
	_check(modal.row_label("offer_blocked") == "OFFER REFUSED", "the refusal is named")
	_check(modal.row_ticket("offer_blocked")
		== "RETRY " + CareerSearch.add_days(today, 3), "the refusal carries the retry date")
	career.data["date"] = CareerSearch.add_days(today, 4)
	modal.setup(career, catalog, club_player, {"scouts": []})
	_check(modal.row_ids() == ["scout", "shortlist", "offer_transfer", "offer_loan",
		"discuss"], "the retry date brings the offer rows back")
	career.data["date"] = today

	# An accepted offer turns the offer rows into contract talks ------------
	offer["status"] = "accepted"
	offer["retry_after"] = null
	modal.setup(career, catalog, club_player, {"scouts": []})
	_check(modal.row_ids() == ["scout", "shortlist", "discuss"],
		"an accepted offer hides the transfer and loan rows")
	_check(modal.row_label("discuss") == "CONTRACT TALKS",
		"an accepted offer offers contract talks")
	_check(modal.row_enabled("discuss"), "contract talks are an action")
	modal.open()
	await _frames(2)
	(modal.get("_by_id")["discuss"] as CareerPlayerPane.ActionRow).grab_focus()
	nav.confirmed.emit()
	await _frames(2)
	_check(_routes.size() == 4 and _routes[3]["view"] == "contract",
		"contract talks route to the contract screen")
	_check(str(_routes[3]["payload"].get("offer_id", "")) == "test-offer",
		"contract talks carry the accepted offer")
	_check(str(_routes[3]["payload"].get("kind", "")) == "transfer",
		"contract talks carry the offer kind")
	offer["signed"] = true
	offer["execute_on"] = "2026-08-01"
	modal.setup(career, catalog, club_player, {"scouts": []})
	_check(modal.row_ids() == ["scout", "shortlist", "transfer_agreed"],
		"a signed transfer leaves only the note")
	_check(modal.row_label("transfer_agreed") == "TRANSFER AGREED",
		"the note says the transfer is agreed")
	_check(modal.row_ticket("transfer_agreed") == "JOINS 2026-08-01",
		"the note carries the joining date")

	# A counter is still a running negotiation: no new offer of either kind ---
	offer["signed"] = false
	offer["status"] = "counter"
	offer["counter"] = {"amount": 1}
	modal.setup(career, catalog, club_player, {"scouts": []})
	_check(modal.row_ids() == ["scout", "shortlist", "offer_blocked", "discuss"],
		"a counter hides both send rows")

	# Your own squad has nothing to send ------------------------------------
	var own := club_player.duplicate(true)
	own["player_id"] = str(career.player_ids[0])
	own["club_id"] = str(career.club_id)
	modal.setup(career, catalog, own, {"scouts": []})
	_check(not modal.row_ids().has("offer_transfer") and not modal.row_ids().has("offer_loan"),
		"your own player offers nothing to send")
	_check(modal.row_ids().has("shortlist"), "your own player can still be shortlisted")

	# Busy scouts are listed but cannot be picked ---------------------------
	var busy_picker := CareerScoutPicker.new()
	busy_picker.size = Vector2(1920.0, 1080.0)
	host.add_child(busy_picker)
	var busy := {"id": "s2", "name": "Nils Berg", "experience": 2, "judgement": 3,
		"report": {"player_id": "1", "player_name": "Kylian Mbappe"}}
	var free := {"id": "s3", "name": "Tom Reed", "experience": 4, "judgement": 5}
	var spanish := {"id": "s4", "name": "Diego Sol", "experience": 4, "judgement": 5,
		"nationality": "Spain", "nationality_id": "157"}
	busy_picker.setup([busy, free, spanish], "Kylian Mbappe")
	busy_picker.open()
	await _frames(2)
	var busy_row = (busy_picker.get("_rows") as Array)[0]
	_check(not bool(busy_row.enabled), "a busy scout cannot be picked")
	_check((busy_row.get("_note") as Label).text == "BUSY · WATCHING Kylian Mbappe",
		"a busy scout names the player he watches")
	var free_row = (busy_picker.get("_rows") as Array)[1]
	_check(free_row.has_focus(), "focus starts on the first free scout")
	_check((free_row.get("_stars") as Control).position.x
		+ (free_row.get("_stars") as Control).size.x <= free_row.size.x - 13.0,
		"the stars end at the row padding")
	var spanish_row = (busy_picker.get("_rows") as Array)[2]
	_check((spanish_row.get("_note") as Label).text.begins_with("SPAIN · "),
		"a scout row shows his nationality")
	_check((spanish_row.get("_flag") as TextureRect).texture != null
		and (spanish_row.get("_flag") as TextureRect).visible,
		"a scout row shows his flag")
	busy_picker.queue_free()
	await _frames(2)
	_check(not nav.is_modal() or nav.modal_owner() != busy_picker,
		"a freed picker leaves the modal stack")

	modal.queue_free()
	await _frames(2)
	_finish()
