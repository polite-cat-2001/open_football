extends SceneTree
# Headless check for the ticket-10 HUD frame: the substitution stack (max 3,
# newest first, 6 s life), the right-side set-piece hints, the shootout dots
# under the scoreboard (5 per row, cleared for sudden death), Alt+X, and the
# pause/replay visibility rules.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_hud_frame.gd

const GpfHudScript := preload("res://scripts/match/gpf_hud.gd")
const ShootoutViewScript := preload("res://scripts/match/gpf_shootout_view.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _base_snapshot() -> Dictionary:
	return {
		"match_duration": 1.0,
		"match_time_ms": 60000,
		"actual_time_ms": 60000,
		"in_play": true,
		"in_set_piece": false,
		"paused": false,
	}


func _run() -> void:
	ShellState.clear()
	_check_stack()
	_check_hints()
	_check_modes()
	_check_shootout_dots()
	if failures.is_empty():
		print("CHECK PASS: hud frame")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)


func _check_stack() -> void:
	print("-- substitution stack --")
	var stack := SubstitutionStack.new()
	get_root().add_child(stack)
	var now := 100000
	stack.push_lines(["Rivera off, Koval on"], [], now)
	_check(stack.entries.size() == 1 and stack.entries[0]["out"] == "Rivera"
		and stack.entries[0]["in"] == "Koval", "a line is parsed into out/in names")
	stack.push_lines(["Rivera off, Koval on"], [], now + 100)
	_check(stack.entries.size() == 1, "the same notice from both peers is not duplicated")
	stack.push_lines(["Velasco off, Brandt on"], [], now + 200)
	_check(stack.entries.size() == 2 and stack.entries[0]["out"] == "Velasco",
		"the newest substitution sits on top")
	stack.push_lines(["A off, B on", "C off, D on"], [0, 1], now + 300)
	_check(stack.entries.size() == SubstitutionStack.MAX_CARDS
		and stack.entries[0]["out"] == "C" and stack.entries[2]["out"] == "Velasco",
		"the stack keeps at most three cards and drops the oldest")
	_check(int(stack.entries[0]["team"]) == 1,
		"a notice carries the team whose crest it shows")
	stack.tick(now + 300 + 1000)
	_check(stack.entries.size() == 3, "a card lives for three seconds")
	stack.tick(now + 300 + int(SubstitutionStack.LIFE_SEC * 1000.0) + 100)
	_check(stack.entries.size() == 3 and bool(stack.entries[0].get("leaving", false)),
		"an expired card fades out instead of vanishing")
	stack.tick(now + 300 + int(SubstitutionStack.LIFE_SEC * 1000.0) + 500)
	_check(stack.entries.is_empty() and not stack.visible,
		"the cards are removed after the fade-out")
	stack.queue_free()


func _hud_with_snapshot(snap: Dictionary) -> GpfHud:
	var hud: GpfHud = GpfHudScript.new()
	get_root().add_child(hud)
	hud.setup(null)
	hud.apply_snapshot(_base_snapshot(), 7, 22, false, "Afternoon")
	hud.apply_snapshot(snap, 7, 22, false, "Afternoon")
	return hud


func _set_piece(overrides: Dictionary) -> Dictionary:
	var snap := _base_snapshot()
	snap["in_set_piece"] = true
	snap["referee_active"] = true
	snap.merge(overrides, true)
	return snap


func _check_hints() -> void:
	print("-- set-piece hints --")
	var hud := _hud_with_snapshot(_set_piece({
		"referee_set_piece": 3, "set_piece_type": 3, "set_piece_role": 1,
		"set_piece_local_taker": true, "referee_team": 0,
	}))
	var hints := hud.get("set_piece_hints") as SetPieceHints
	_check(hints != null and hints.visible and hints.key_for("change taker") == "Tab"
		and hints.key_for("pass") == "S" and hints.key_for("shot") == "D"
		and hints.key_for("cross") == "A",
		"a keyboard taker sees change taker, pass, shot and cross")
	var view := hud.get_viewport().get_visible_rect().size
	_check(hints.position.x == roundf(view.x - hints.size.x - 24.0)
		and hints.position.y == roundf((view.y - hints.size.y) * 0.5),
		"the hints sit on the right, vertically centred")
	_check(hints != null and hud.get("taker_hint") == null,
		"the old bottom-left taker hint is gone")

	var taker_menu: GpfSetPieceTakerMenu = hud.get("taker_menu")
	hud.show_taker_menu_demo([{"id": 7, "team": 0, "name": "A", "role": "player"}], 0)
	var menu_snap := _set_piece({
		"referee_set_piece": 3, "set_piece_type": 3, "set_piece_role": 1,
		"set_piece_local_taker": true, "referee_team": 0,
		"set_piece_taker_menu_open": true,
	})
	hud.apply_snapshot(menu_snap, 7, 22, false, "Afternoon")
	_check(not hints.has_hint("change taker"),
		"the taker row disappears while the taker menu is open")
	taker_menu.close(false)

	var defender_snap := _set_piece({
		"referee_set_piece": 6, "set_piece_type": 6, "set_piece_role": 0,
		"set_piece_local_taker": false, "referee_team": 1, "human_team": 0,
	})
	hud.apply_snapshot(defender_snap, 7, 22, false, "Afternoon")
	_check(hints.key_for("dive") == "Arrows",
		"the human defending a penalty gets the dive hint")
	defender_snap["referee_team"] = 0
	defender_snap["set_piece_role"] = 1
	hud.apply_snapshot(defender_snap, 7, 22, false, "Afternoon")
	_check(hints.key_for("shot") == "D" and not hints.has_hint("dive"),
		"the penalty taker gets the shot hint, not the dive")
	defender_snap["set_piece_role"] = 2
	defender_snap["set_piece_local_taker"] = false
	hud.apply_snapshot(defender_snap, 7, 22, false, "Afternoon")
	_check(hints.key_for("dive") == "Arrows", "a human keeper gets the dive hint")

	# A gamepad taker sees pad buttons instead of letters.
	ShellState.set_controllers([{"side": "home", "kind": "gamepad", "device": 0}])
	var pad_snap := _set_piece({
		"referee_set_piece": 4, "set_piece_type": 4, "set_piece_role": 1,
		"set_piece_local_taker": true, "referee_team": 0,
	})
	hud.apply_snapshot(pad_snap, 7, 22, false, "Afternoon")
	_check(hints.key_for("change taker") == "Select" and hints.key_for("shot") == "X"
		and hints.key_for("pass") == "A" and hints.key_for("cross") == "B",
		"a gamepad taker sees Select and the pad buttons")
	ShellState.clear()

	hud.apply_snapshot(_base_snapshot(), 7, 22, false, "Afternoon")
	_check(not hints.visible, "the hints hide when the set piece ends")
	hud.queue_free()


func _check_modes() -> void:
	print("-- Alt+X, pause, replay --")
	var hud := _hud_with_snapshot(_set_piece({
		"referee_set_piece": 3, "set_piece_type": 3, "set_piece_role": 1,
		"set_piece_local_taker": true, "referee_team": 0,
	}))
	var hints := hud.get("set_piece_hints") as SetPieceHints
	var stack := hud.get("substitution_stack") as SubstitutionStack
	stack.push_lines(["Rivera off, Koval on"])
	hud.apply_snapshot(_set_piece({
		"referee_set_piece": 3, "set_piece_type": 3, "set_piece_role": 1,
		"set_piece_local_taker": true, "referee_team": 0,
	}), 7, 22, false, "Afternoon")
	_check(stack.visible and stack.position.y == 14.0,
		"the substitution stack shares the scoreboard's top line")
	var legend := hud.get("hud") as Label
	var board := hud.get("scoreboard") as MatchScoreboard
	hud.toggle_legacy_hud()
	_check(hud.is_legacy_hidden() and not legend.visible,
		"Alt+X hides the old text HUD")
	_check(board.visible and hints.visible and stack.visible,
		"Alt+X keeps the design-system HUD (score, hints, substitutions)")
	hud.toggle_legacy_hud()
	_check(legend.visible, "Alt+X brings the text HUD back")

	var paused := _base_snapshot()
	paused["paused"] = true
	hud.apply_snapshot(paused, 7, 22, false, "Afternoon")
	var root_layer := hud.get("root_layer") as CanvasLayer
	_check(not root_layer.visible, "a paused match hides the whole HUD")
	hud.apply_snapshot(_base_snapshot(), 7, 22, false, "Afternoon")
	_check(root_layer.visible, "resuming restores the HUD")

	hud.apply_snapshot(_set_piece({
		"referee_set_piece": 3, "set_piece_type": 3, "set_piece_role": 1,
		"set_piece_local_taker": true, "referee_team": 0,
	}), 7, 22, false, "Afternoon")
	stack.push_lines(["Smith off, Jones on"])
	hud.set_replay_mode(true)
	_check(board.visible, "the scoreboard stays up during the replay")
	_check(not hints.visible and not stack.visible,
		"the replay hides the set-piece hints and the substitution stack")
	hud.set_replay_mode(false)
	hud.apply_snapshot(_set_piece({
		"referee_set_piece": 3, "set_piece_type": 3, "set_piece_role": 1,
		"set_piece_local_taker": true, "referee_team": 0,
	}), 7, 22, false, "Afternoon")
	_check(legend.visible, "the text HUD returns after the replay")
	hud.queue_free()


func _check_shootout_dots() -> void:
	print("-- shootout dots --")
	var view: GpfShootoutView = ShootoutViewScript.new()
	get_root().add_child(view)
	view.setup()
	var dots := view.get("shootout_dots") as ShootoutDots
	_check(dots != null and dots.position.y > MatchScoreboard.PLATE_H,
		"the dots sit under the scoreboard")
	_check(dots != null and dots.size.y == ShootoutDots.CIRCLE,
		"both team rows share one height")
	var board := MatchScoreboard.new()
	get_root().add_child(board)
	board.set_teams({"short_name": "UNAM Pumas"}, {"short_name": "Atlas"})
	board.position = Vector2(24, 14)
	view.set_scoreboard(board)
	var updated := _base_snapshot()
	updated["shootout_active"] = true
	updated["shootout_kicks0"] = [1, 1, 1, 1, 1]
	updated["shootout_kicks1"] = [2, 2, 2, 2, 2]
	view.update(updated, 0.0)
	_check(is_equal_approx(dots.position.y, board.position.y + board.size.y + 8.0),
		"the dots hang directly under the scoreboard plate")
	_check(dots.row_lefts[0] == 0.0
		and dots.row_lefts[1] == board.team_outer_edge_x(1) - ShootoutDots.WIDTH,
		"the left group starts at the plate edge and the right group ends at the clock divider")
	dots.set_results([1, 2, 1, 1, 0], [1, 1, 2, 0, 0])
	_check(dots.home == [1, 2, 1, 1, 0] and dots.away == [1, 1, 2, 0, 0],
		"five kicks fill the two rows of five")
	dots.set_results([1, 2, 1, 1, 0, 2], [1, 1, 2, 0, 0, 1])
	_check(dots.home == [2, 0, 0, 0, 0] and dots.away == [1, 0, 0, 0, 0],
		"the sixth kick clears the rows for sudden death")
	dots.set_results([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	_check(dots.home == [2, 0, 0, 0, 0] and dots.away == [1, 0, 0, 0, 0],
		"the eleventh kick clears the rows again")
	updated = _base_snapshot()
	updated["shootout_active"] = true
	updated["shootout_kicks0"] = [1, 1, 1, 1, 1]
	updated["shootout_kicks1"] = [2, 2, 2, 2, 2]
	view.update(updated, 0.0)
	_check(view.get("shootout_layer").visible, "the dots layer follows the series")
	updated["paused"] = true
	view.update(updated, 0.0)
	_check(not view.get("shootout_layer").visible, "a paused series hides the dots")
	view.queue_free()
