extends SceneTree
# Headless check for the referee card presentation: the bridge relays the two
# card props exactly as the original Officials::Put() positioned them (host:
# GetCurrentCardState; thin client: relayed SetRemoteCardState), so GpfActors
# only has to show the matching yellow/red box. A real card event needs a foul
# and is not forceable without touching of_port; the bridge fields are checked in
# check_gpf_hud_messages and the LAN probe, this test pins the renderer.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_referee_card.gd

const GpfActorsScript := preload("res://scripts/match/gpf_actors.gd")
const CARD_SIZE := Vector3(0.1104, 0.02, 0.1539)

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	var actors: GpfActors = GpfActorsScript.new()
	get_root().add_child(actors)
	actors.setup(null)
	var yellow := actors.get("yellow_card") as MeshInstance3D
	var red := actors.get("red_card") as MeshInstance3D
	_check(yellow != null and red != null, "both card meshes are built")
	_check(yellow.visible == false and red.visible == false,
		"cards are hidden before any card event")
	var box := yellow.mesh as BoxMesh
	_check(box != null and box.size.is_equal_approx(CARD_SIZE),
		"the card box matches the original yellowcard.ase dimensions")

	actors.update_referee_card({})
	_check(not yellow.visible and not red.visible,
		"a snapshot without card props hides both cards")

	var card_pos := Vector3(1.5, 2.0, 0.8)
	var card_rot := Quaternion(Vector3.RIGHT, 0.35)
	actors.update_referee_card({"referee_cards": {
		"yellow": {"visible": true, "raised": false,
			"pos": Vector3(1.2, 1.0, 0.6), "rot": Quaternion.IDENTITY},
		"red": {"visible": false},
	}})
	_check(not yellow.visible and not red.visible,
		"the showcard clip's arm-down frame keeps the card hidden")

	actors.update_referee_card({"referee_cards": {
		"yellow": {"visible": true, "raised": true, "pos": card_pos, "rot": card_rot},
		"red": {"visible": false},
	}})
	_check(yellow.visible and not red.visible, "the raised yellow prop is shown")
	var expected_yellow := Transform3D(Basis(card_rot),
		card_pos + Basis(card_rot) * Vector3(0.0, 0.0, -CARD_SIZE.z))
	_check(yellow.transform.is_equal_approx(expected_yellow),
		"the yellow card is shifted to the hand's lower edge")

	actors.update_referee_card({"referee_cards": {
		"yellow": {"visible": false},
		"red": {"visible": true, "raised": true, "pos": Vector3(2.0, 1.0, 0.5),
			"rot": Quaternion.IDENTITY},
	}})
	_check(red.visible and not yellow.visible, "the raised red prop is shown")
	_check(red.transform.is_equal_approx(
		Transform3D(Basis.IDENTITY, Vector3(2.0, 1.0, 0.5 - CARD_SIZE.z))),
		"the red card is shifted to the hand's lower edge")

	actors.update_referee_card({"referee_cards": {
		"yellow": {"visible": false},
		"red": {"visible": false},
	}})
	_check(not yellow.visible and not red.visible,
		"hidden props hide both cards again")

	actors.reset()
	_check(not yellow.visible and not red.visible, "reset hides the cards")
	actors.queue_free()

	if failures.is_empty():
		print("== check_gpf_referee_card: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_gpf_referee_card: FAIL ==")
	quit(0 if failures.is_empty() else 1)
