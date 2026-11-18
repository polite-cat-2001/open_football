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
	_check((card.get_node("Age") as Label).text == "34 y.o.", "the age line reads like the prototype")
	_check((card.get_node("Position") as Label).text == "RW",
		"the position shows the prototype code")
	_check((card.get_node("Position") as Label).get_theme_color(&"font_color") == UiTokens.INK,
		"the position is plain ink text, not a plate")
	_check((card.get_node("PositionDot") as Panel).get_theme_stylebox(&"panel").bg_color
		== UiTokens.position_color("FWD"), "the position dot carries the position colour")
	var tile := CareerPlayerCard.shows_overall_tile(PLAYER)
	_check((card.get_node("OvrTile") as Control).visible == tile,
		"a scouted OVR sits on the meta line")
	_check((card.get_node("Photo") as Control).visible,
		"the rating tile never replaces the portrait")
	if tile:
		_check((card.get_node("OvrTile/Value") as Label).text == "88",
			"the tile shows the revealed OVR")
		_check((card.get_node("OvrTile") as Panel).get_theme_stylebox(&"panel").bg_color
			== UiTokens.rating_color(88), "the chip uses the shared rating ramp")
		_check((card.get_node("OvrTile") as Control).size.x <= 30.0,
			"the rating chip stays as narrow as its number")
	_check(not (card.get_node("Chips/Chip0") as Control).visible,
		"a transfer-listed player no longer takes a chip")
	_check(card.custom_minimum_size.y >= 107.0, "the card keeps the result card height")

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
	var scouted := {"player_id": "0", "photo": "", "overall": 80, "scouted": true}
	_check(CareerPlayerCard.shows_overall_tile(scouted),
		"a scouted player's OVR gets the rating chip")
	_check(not CareerPlayerCard.shows_overall_tile({"player_id": "0", "overall": 80}),
		"an unscouted player hides the rating chip")
	_check(not CareerPlayerCard.shows_overall_tile({"player_id": "0", "scouted": true}),
		"no revealed OVR means no chip")
	_check(CareerPlayerCard.age_text({"age": 0}) == "—",
		"a player without a birth date has no age")
	_check(CareerPlayerCard.age_text({"age": 25}) == "25 y.o.", "the age reads y.o.")
	_check(CareerPlayerCard.age_value({"age": 25}) == "25", "the shared age value is bare")
	_check(UiTokens.rating_color(92) == UiTokens.INK, "rating ramp: 90+ ink")
	_check(UiTokens.rating_color(84) == UiTokens.MARK_WIN, "rating ramp: 80+ win")
	_check(UiTokens.rating_color(72) == UiTokens.MARK_WARN, "rating ramp: 70+ warn")
	_check(UiTokens.rating_color(62) == UiTokens.MARK_WARN, "rating ramp: 60+ warn")
	_check(UiTokens.rating_color(45) == UiTokens.MARK_LOSS, "rating ramp: below loss")
	var loan := PLAYER.duplicate(true)
	loan["status"] = "loan"
	card.setup(loan)
	await _frames(2)
	_check((card.get_node("Chips/Chip0/ChipLabel0") as Label).text == "ON LOAN",
		"an on-loan player still takes a chip")
	var placeholder := UiAssets.player_placeholder()
	_check(placeholder != null, "the prototype portrait mask ships and imports")
	if placeholder != null:
		_check(placeholder.get_size() == Vector2(598.0, 600.0),
			"the portrait mask is the prototype asset")
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
	_check(_row_value(content.get_node("Metrics/Column0/RELEASE CLAUSE")) == "€90M",
		"the release clause band shows the money")
	var column := content.get_node("Metrics/Column0")
	_check(_row_value(column.get_node("OVERALL")) == "84", "metrics: overall")
	_check(_row_value(column.get_node("PRICE")) == "€42M", "metrics: price")
	_check(_row_value(column.get_node("WAGE")) == "€120K / WEEK", "metrics: wage")
	_check(_row_value(column.get_node("RELEASE CLAUSE")) == "€90M",
		"metrics: release clause")
	var stat_column := content.get_node("Metrics/Column1")
	var pager := content.get_node("Head/Club/Pager")
	_check(stat_column.get_node("mental").is_visible_in_tree(),
		"attributes start on the first group page")
	_check(pager.get_node("Dots").get_child_count() == 3, "a dot per attribute page")
	_check(pager.get_child_count() == 3 and _cap_text(pager.get_child(0)) == "Q" \
		and _cap_text(pager.get_child(2)) == "E",
		"the pager hints sit either side of the dots")
	_check((pane.get("_stat_values") as Array).size() == 22, "every attribute has a row")
	var stat_value := _row_value(stat_column.get_node("mental/mental_calmness"))
	_check(stat_value == "71", "attributes: revealed stat value")
	pane.call("_step_page", 1)
	_check(stat_column.get_node("physical").is_visible_in_tree(),
		"a page step moves to the next group")
	_check(stat_column.get_node("technical/technical_volley").is_visible_in_tree() == false,
		"only the current page is shown")
	pane.call("_step_page", -1)
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 1.0
	pane.call("_unhandled_input", motion)
	_check(stat_column.get_node("physical").is_visible_in_tree(),
		"the right stick pages forward")
	pane.call("_unhandled_input", motion)
	_check(stat_column.get_node("physical").is_visible_in_tree(),
		"a held stick does not repeat the step")
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_RIGHT_X
	release.axis_value = 0.0
	pane.call("_unhandled_input", release)
	var back := InputEventJoypadMotion.new()
	back.axis = JOY_AXIS_RIGHT_X
	back.axis_value = -1.0
	pane.call("_unhandled_input", back)
	_check(stat_column.get_node("mental").is_visible_in_tree(),
		"the right stick pages back once released")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	pane.call("_unhandled_input", key)
	_check(stat_column.get_node("physical").is_visible_in_tree(), "E pages forward")
	key = InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	pane.call("_unhandled_input", key)
	_check(stat_column.get_node("mental").is_visible_in_tree(), "Q pages back")
	var nav := root.get_node_or_null("UiNav")
	if nav != null:
		nav.set("_last_device", 1)  # UiNav.Device.GAMEPAD
		pane.call("_build_pager")
		_check(pager.get_child_count() == 2 and _cap_text(pager.get_child(0)) == "R",
			"a gamepad shows one circled R left of the dots")
		nav.set("_last_device", 0)
		pane.call("_build_pager")
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
	_check(_row_value(pane.get_node("Card/Content/Metrics/Column1/mental/mental_calmness")) == "?",
		"unscouted attributes are hidden")
	_check(_row_value(pane.get_node("Card/Content/Metrics/Column0/RELEASE CLAUSE")) == "€90M",
		"an unscouted release clause stays public")
	var chip_texts: Array[String] = []
	for chip in pane.get_node("Card/Content/Metrics/Column0/ChipWrap/Chips").get_children():
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


func _cap_text(cap: Node) -> String:
	var label := cap.get_child(0) as Label if cap.get_child_count() > 0 else null
	return "" if label == null else label.text


func _status_text(row: Node) -> String:
	for child in row.get_children():
		if child is HBoxContainer:
			for label in child.get_children():
				if label is Label:
					return (label as Label).text
	return ""
