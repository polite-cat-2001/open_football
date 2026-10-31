extends SceneTree
# Headless check for the presentation roster sync used after a substitution:
# the outgoing player's body/nameplate is dropped, the substitute gets a new
# body with his own nameplate.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_actor_roster.gd

var failures: Array[String] = []


class FakeRuntime:
	extends Node

	func get_player_pose(_player_id: int) -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	var actors := GpfActors.new()
	get_root().add_child(actors)
	actors.setup(FakeRuntime.new())
	var roster: Array = [
		{"id": 58, "team": 0, "role": "player", "name": "Moreno"},
		{"id": 59, "team": 0, "role": "player", "name": "Echeverría"},
	]
	actors.spawn(roster)
	await process_frame
	_check(actors.actor_bodies.has(58) and actors.actor_bodies.has(59), "starter bodies spawn")
	_check((actors.player_labels[58] as Label3D).text == "Moreno", "the starter nameplate is built")

	var substituted: Array = [
		{"id": 59, "team": 0, "role": "player", "name": "Echeverría"},
		{"id": 78, "team": 0, "role": "player", "name": "Fierro"},
	]
	actors.sync_roster(substituted)
	await process_frame
	_check(not actors.actor_bodies.has(58), "the outgoing player's body is dropped")
	_check(not actors.player_labels.has(58), "the outgoing player's nameplate is dropped")
	_check(actors.actor_bodies.has(78), "the substitute gets a body")
	_check((actors.player_labels[78] as Label3D).text == "Fierro", "the substitute nameplate is built")
	_check(actors.actors.size() == 2, "the presented roster stays in sync")

	actors.queue_free()
	print("== check_gpf_actor_roster: ", "PASS" if failures.is_empty() else "FAIL", " ==")
	quit(0 if failures.is_empty() else 1)
