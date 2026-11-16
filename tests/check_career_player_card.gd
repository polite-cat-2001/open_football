extends SceneTree
# Headless check for the shared transfer primitives: CareerPlayerCard (the
# .tf-result result card: content, chips, focus inversion, pressed signal) and
# CareerPlayerPane (the .tf-detail pane: facts, metrics, fog of scouting,
# contract months, action rows).
#
# Run:  godot --headless --path . -s res://tests/check_career_player_card.gd

var failures: Array[String] = []
var _pressed_ids: Array[String] = []
var _action_ids: Array[String] = []

const PLAYER := {
	"player_id": "12345",
	"name": "Lionel Messi",
	"photo": "",
	"club_name": "Inter Miami",
	"club_logo": "",
	"position": "Right Winger",
	"position_group": "FWD",
	"overall": 88,
	"age": 34,
	"status": "transfer",
	"shortlisted": true,
	"listed_for_transfer": false,
	"scouted": true,
}

const DETAIL := {
	"player_id": "999",
	"name": "Ruben Dias",
	"club_name": "Manchester City",
	"club_logo": "",
	"position": "Centre-Back",
	"position_group": "DEF",
	"age": 27,
	"height": 190,
	"foot": "right",
	"overall": 84,
	"market_value": 42000000,
	"wage": 120000,
	"release_clause": 90000000,
	"status": "",
	"available": true,
	"shortlisted": true,
	"listed_for_transfer": false,
	"scouted": true,
	"contract_expires": "2027-06-30",
	"stats": {"mental_calmness": 71, "physical_velocity": 88},
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


func _finish() -> void:
	print("== check_career_player_card: ", "PASS" if failures.is_empty() else "FAIL",
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
	await _frames(2)

	await _check_card(host)
	await _check_pane(host)
	_finish()


func _check_card(host: Control) -> void:
	var card := CareerPlayerCard.new()
	card.position = Vector2(40.0, 40.0)
	card.size = Vector2(420.0, 112.0)
	host.add_child(card)
	card.pressed.connect(func(id: String) -> void: _pressed_ids.append(id))
	card.setup(PLAYER)
	await _frames(3)

	_check(card.player_id() == "12345", "the card keeps the player id")
	_check(card.player().get("name") == "Lionel Messi", "the card keeps the player data")
	_check((card.get_node("Name") as Label).text == "LIONEL MESSI",
		"the name is upper-case like the prototype")
	_check((card.get_node("Club") as Label).text == "Inter Miami", "the club name is shown")
	_check((card.get_node("Age") as Label).text == "34", "the age slot is filled")
	_check((card.get_node("Position/PositionLabel") as Label).text == "RW",
		"the position badge uses the prototype code")
	var tone := CareerPlayerCard.position_tone("FWD")
	_check((card.get_node("Position/PositionLabel") as Label)
		.get_theme_color(&"font_color") == tone, "the badge carries the position tone")
	_check((card.get_node("Ovr") as Label).text == "88", "the card shows the OVR")
	_check((card.get_node("Chips/Chip0") as Control).visible, "the status chip is shown")
	_check((card.get_node("Chips/Chip0/ChipLabel0") as Label).text == "TRANSFER LISTED",
		"the status chip reads the transfer status")
	_check((card.get_node("Chips/Chip1/ChipLabel1") as Label).text == "SHORTLIST",
		"the shortlist marker is shown")
	_check(card.custom_minimum_size.y >= 100.0, "the card keeps the result card height")

	# Focus inverts the card and hides the rail; selected shows it without focus.
	card.grab_focus()
	await _frames(2)
	_check(card.has_focus(), "the card can take focus")
	_check((card.get_node("Name") as Label).get_theme_color(&"font_color")
		== UiTokens.FOCUS_MARK, "focus turns the name lime")
	_check(not (card.get_node("Rail") as Control).visible, "the rail hides on focus")
	card.release_focus()
	await _frames(2)
	card.set_selected(true)
	await _frames(2)
	_check((card.get_node("Rail") as Control).visible, "the rail marks a selected card")
	_check(card.is_selected(), "set_selected is remembered")
	card.set_selected(false)

	card.activate()
	await _frames(1)
	_check(_pressed_ids == ["12345"], "activate emits pressed(player_id)")

	# Static helpers shared by the transfer screens.
	_check(CareerPlayerCard.position_code("Centre-Forward", "") == "CF",
		"position_code maps the full position")
	_check(CareerPlayerCard.position_code("", "MID") == "MID",
		"position_code falls back to the group")
	_check(CareerPlayerCard.status_label("free") == "FREE AGENT", "status_label: free")
	_check(CareerPlayerCard.status_label("") == "AT CLUB", "status_label: at club")
	_check(CareerPlayerCard.face_texture(PLAYER) == null or
		CareerPlayerCard.face_texture(PLAYER) is Texture2D, "face lookup is safe")
	card.queue_free()
	await _frames(2)


func _check_pane(host: Control) -> void:
	var pane := CareerPlayerPane.new()
	pane.position = Vector2(520.0, 40.0)
	host.add_child(pane)
	pane.action_chosen.connect(func(id: String) -> void: _action_ids.append(id))
	pane.setup(DETAIL, {
		"date": "2026-11-14",
		"show_actions": true,
		"width": 520.0,
		"action_rows": [
			{"id": "shortlist", "label": "Shortlist", "key": "X"},
			{"id": "offer", "label": "Send offer", "key": "A"},
		],
	})
	pane.size = Vector2(520.0, 760.0)
	await _frames(4)

	_check(pane.player_id() == "999", "the pane keeps the player id")
	_check(is_equal_approx(pane.custom_minimum_size.x, 520.0), "the width option is applied")
	var content := pane.get_node("Card/Content")
	var head := content.get_node("Head")
	_check((head.get_node("Info/Name") as Label).text == "RUBEN DIAS",
		"the pane shows the upper-case name")
	var facts := head.get_node("Info/Facts")
	_check((facts.get_node("AGE").get_child(1) as Label).text == "27", "facts: age")
	_check((facts.get_node("HEIGHT").get_child(1) as Label).text == "190 CM", "facts: height")
	_check((facts.get_node("POSITION").get_child(1) as Label).text == "CB",
		"facts: position code")
	_check((facts.get_node("FOOT").get_child(1) as Label).text == "Right", "facts: foot")
	_check((head.get_node("Club/ClubName") as Label).text == "Manchester City",
		"the club name is shown")
	_check((content.get_node("Clause/Line/ReleaseClause") as Label).text == "€90M",
		"the release clause band shows the money")
	var column := content.get_node("Metrics/Column0")
	_check(_row_value(column.get_node("OVERALL")) == "84", "metrics: overall")
	_check(_row_value(column.get_node("PRICE")) == "€42M", "metrics: price")
	_check(_row_value(column.get_node("WAGE")) == "€120K / WEEK", "metrics: wage")
	_check(_row_value(column.get_node("RELEASE CLAUSE")) == "€90M",
		"metrics: release clause")
	var stat_column := content.get_node("Metrics/Column1")
	var stat_value := _row_value(stat_column.get_child(0))
	_check(stat_value == "71", "attributes: revealed stat value")
	var status_lines := content.get_node("Status").get_child_count()
	_check(status_lines == 3, "three status lines (club, availability, contract)")
	var last_status := content.get_node("Status").get_child(2)
	_check(_status_text(last_status) == "Contract expires in 8 months",
		"the contract status line counts the months to expiry")

	_check(pane.action_buttons().size() == 2, "two action rows are built")
	(pane.action_buttons()[0] as Button).pressed.emit()
	await _frames(1)
	_check(_action_ids == ["shortlist"], "an action row emits action_chosen(id)")

	# Fog of scouting hides every number.
	var hidden := DETAIL.duplicate(true)
	hidden["scouted"] = false
	pane.setup(hidden, {"date": "2026-11-14", "show_actions": false})
	await _frames(3)
	_check(_row_value(pane.get_node("Card/Content/Metrics/Column0").get_node("OVERALL")) == "?",
		"an unscouted overall is hidden")
	_check(_row_value(pane.get_node("Card/Content/Metrics/Column1").get_child(0)) == "???",
		"unscouted attributes are hidden")
	_check((pane.get_node("Card/Content/Clause/Line/ReleaseClause") as Label).text == "?",
		"an unscouted release clause is hidden")
	var chip_texts: Array[String] = []
	for chip in pane.get_node("Card/Content/Chips").get_children():
		chip_texts.append((chip.get_child(0) as Label).text)
	_check("NOT SCOUTED" in chip_texts, "the pane tags an unscouted player")

	_check(CareerPlayerPane.money(850000) == "€850K", "money: thousands")
	_check(CareerPlayerPane.money(1500000) == "€1.5M", "money: millions")
	_check(CareerPlayerPane.money(1000000000) == "€1.0B", "money: billions")
	_check(CareerPlayerPane.months_until("2027-06-30", "2026-11-14") == 8,
		"months_until counts whole months")
	_check(CareerPlayerPane.months_until("2026-01-01", "2026-11-14") == 0,
		"months_until clamps a past date to zero")
	_check(CareerPlayerPane.months_until("", "2026-11-14") == -1,
		"months_until reports an unusable date")
	pane.queue_free()
	await _frames(2)


func _row_value(row: Node) -> String:
	for child in row.get_children():
		if child is HBoxContainer:
			for label in child.get_children():
				if label is Label and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
					return (label as Label).text
	return ""


func _status_text(row: Node) -> String:
	for child in row.get_children():
		if child is HBoxContainer:
			for label in child.get_children():
				if label is Label:
					return (label as Label).text
	return ""
