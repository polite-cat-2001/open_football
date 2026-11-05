extends SceneTree
# Headless checks for the shared Back-vote component: local request, mirrored
# echo, both-sides agreement, the incoming two-option dialog and Stay dismissal.
#
# Run:  godot --headless --path . -s res://tests/check_network_back_vote.gd

var failures: Array[String] = []
var host: Control
var vote: NetworkBackVote
var ui_nav: Node
var state: Dictionary
var sent: Array[int] = []
var agreed: Array[int] = []


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


func _fresh_state() -> Dictionary:
	return {
		"active": true,
		"local_id": 0,
		"lobby": {
			"hub_vote": 0,
			"players": [
				{"id": 0, "name": "Host", "hub_vote": 0},
				{"id": 1, "name": "Guest", "hub_vote": 0},
			],
		},
	}


func _set_vote(player_index: int, value: int) -> void:
	var players: Array = state["lobby"]["players"]
	players[player_index]["hub_vote"] = value


func _set_agreed(value: int) -> void:
	state["lobby"]["hub_vote"] = value


func _poll() -> void:
	vote.call("_poll")


func _dialog_visible() -> bool:
	var dialog := vote.get_node_or_null("Dialog")
	return dialog != null and dialog.visible


func _make_vote(action: int) -> void:
	state = _fresh_state()
	sent.clear()
	agreed.clear()
	vote.setup(action, {
		"provider": func() -> Dictionary: return state,
		"sender": func(value: int) -> void: sent.append(value),
	})


func _run() -> void:
	host = Control.new()
	host.name = "BackVoteHost"
	host.add_to_group(&"ui_shell")
	host.size = Vector2(1920, 1080)
	host.theme = UiTheme.load_or_build()
	root.add_child(host)
	ui_nav = root.get_node_or_null("UiNav")
	_check(ui_nav != null, "the UiNav autoload is present")
	vote = NetworkBackVote.new()
	host.add_child(vote)
	vote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vote.action_agreed.connect(func(action: int): agreed.append(action))
	await _frames(3)

	_make_vote(NetworkBackVote.VOTE_BACK_TO_SIDES)
	vote.request()
	_check(sent.size() == 1 and sent[0] == NetworkBackVote.VOTE_BACK_TO_SIDES,
		"request sends the shared vote")
	_check(vote.is_pending(), "the requester waits for the other player")
	_set_vote(0, NetworkBackVote.VOTE_BACK_TO_SIDES)
	_poll()
	_check(vote.is_pending(), "the echoed vote keeps the requester pending")
	_set_vote(1, NetworkBackVote.VOTE_BACK_TO_SIDES)
	_set_agreed(NetworkBackVote.VOTE_BACK_TO_SIDES)
	_poll()
	await _frames(1)
	_check(agreed.has(NetworkBackVote.VOTE_BACK_TO_SIDES), "both votes emit agreement")

	_make_vote(NetworkBackVote.VOTE_BACK_TO_SIDES)
	_check(not vote.is_pending(), "setup resets the local vote")
	_set_vote(1, NetworkBackVote.VOTE_BACK_TO_SIDES)
	_poll()
	_check(_dialog_visible(), "the other player's request opens the dialog")
	_check(ui_nav.is_modal() and ui_nav.modal_owner() == vote,
		"the dialog owns the modal")
	_check(not vote.is_pending(), "the invited player is not pending before accepting")
	vote.call("_accept_incoming")
	_check(sent.size() == 1 and sent[0] == NetworkBackVote.VOTE_BACK_TO_SIDES,
		"accept sends the same vote")
	_check(vote.is_pending(), "accept starts waiting for the peer")
	_check(not _dialog_visible(), "accept closes the dialog")
	_set_vote(0, NetworkBackVote.VOTE_BACK_TO_SIDES)
	_set_agreed(NetworkBackVote.VOTE_BACK_TO_SIDES)
	_poll()
	await _frames(1)
	_check(agreed.has(NetworkBackVote.VOTE_BACK_TO_SIDES), "accept reaches agreement")

	_make_vote(NetworkBackVote.VOTE_BACK_TO_SIDES)
	_set_vote(1, NetworkBackVote.VOTE_BACK_TO_SIDES)
	_poll()
	_check(_dialog_visible(), "a fresh request opens the dialog again")
	vote.call("_stay")
	_check(not _dialog_visible() and not ui_nav.is_modal(), "Stay closes the dialog")
	_poll()
	_check(not _dialog_visible(), "Stay is not re-opened by the same request")
	_set_vote(1, 0)
	_poll()
	_set_vote(1, NetworkBackVote.VOTE_BACK_TO_SIDES)
	_poll()
	_check(_dialog_visible(), "a new request after withdrawal opens the dialog")

	_make_vote(NetworkBackVote.VOTE_LEAVE_SESSION)
	vote.request()
	_set_vote(0, NetworkBackVote.VOTE_LEAVE_SESSION)
	_set_vote(1, NetworkBackVote.VOTE_LEAVE_SESSION)
	_set_agreed(NetworkBackVote.VOTE_LEAVE_SESSION)
	_poll()
	await _frames(1)
	_check(agreed.has(NetworkBackVote.VOTE_LEAVE_SESSION),
		"leave-session agreement is reported")

	_make_vote(NetworkBackVote.VOTE_BACK_TO_TEAMS)
	vote.clear_server_vote()
	_check(sent.size() == 1 and sent[0] == NetworkBackVote.VOTE_NONE,
		"clear_server_vote sends a zero vote")

	host.queue_free()
	await _frames(1)
	if failures.is_empty():
		print("== check_network_back_vote: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_network_back_vote: FAIL ==")
	quit(0 if failures.is_empty() else 1)
