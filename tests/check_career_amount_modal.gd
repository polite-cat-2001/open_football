extends SceneTree
# Headless check for CareerAmountModal (prototype shared/AmountModal.svelte):
# nine digit places, place stepping, digit rolling, value preview, apply/clamp/
# step rules, UiNav modal ownership and open/close animation flags.
#
# Run:  godot --headless --path . -s res://tests/check_career_amount_modal.gd

var failures: Array[String] = []
var _applied: Array[int] = []
var _closed := 0


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
	print("== check_career_amount_modal: ", "PASS" if failures.is_empty() else "FAIL",
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
	var modal := CareerAmountModal.new()
	host.add_child(modal)
	modal.applied.connect(func(value: int) -> void: _applied.append(value))
	modal.closed.connect(func() -> void: _closed += 1)
	await _frames(3)
	var nav := root.get_node("UiNav")

	_check(not modal.is_open(), "the modal starts closed")
	_check(not modal.visible, "the modal starts hidden")

	modal.open(1250000)
	await _frames(2)
	_check(modal.is_open() and modal.visible, "open shows the modal")
	_check(nav.modal_owner() == modal, "the modal takes UiNav ownership")
	_check(modal.value() == 1250000, "the value round-trips")
	_check(modal.index() == 2, "the first non-zero place owns the cursor")
	_check(modal.digit(2) == 1 and modal.digit(3) == 2 and modal.digit(4) == 5,
		"the digits are laid out by place")
	_check(modal.place_text() == "PLACE: MILLIONS", "the place line names the place")
	_check((modal.get_node("Card/Column/Preview") as Label).text
		== CareerPlayerPane.money(1250000), 
		"the preview prints the amount in career money units")
	_check((modal.get_node("Card/Column/Title") as Label).text == "AMOUNT",
		"the default title is AMOUNT")

	nav.moved.emit(Vector2i.RIGHT)
	await _frames(1)
	_check(modal.index() == 3, "right walks to the next place")
	nav.moved.emit(Vector2i.UP)
	await _frames(1)
	_check(modal.digit(3) == 3, "up rolls the digit")
	_check(modal.value() == 1350000, "the value follows the digits")
	nav.moved.emit(Vector2i.DOWN)
	nav.moved.emit(Vector2i.DOWN)
	await _frames(1)
	_check(modal.digit(3) == 1, "down rolls the digit and wraps")
	nav.moved.emit(Vector2i.LEFT)
	await _frames(1)
	_check(modal.index() == 2, "left walks back")

	nav.confirmed.emit()
	await _frames(2)
	_check(_applied == [1150000], "confirm applies the edited value")
	_check(_closed == 1, "confirm closes the modal")
	_check(not modal.is_open(), "the modal reports closed")
	_check(nav.modal_owner() != modal, "closing releases UiNav")
	await _frames(3)
	_check(not modal.visible, "the modal hides after the close animation")

	# Clamp and step rules used by the offer / contract screens.
	modal.open(500, {"min": 1000, "title": "Weekly wage", "hint": "€/week"})
	await _frames(2)
	_check((modal.get_node("Card/Column/Title") as Label).text == "WEEKLY WAGE",
		"the title is upper-cased")
	_check((modal.get_node("Card/Column/Hint") as Label).visible,
		"the optional hint line shows")
	nav.confirmed.emit()
	await _frames(2)
	_check(_applied == [1150000, 1000], "min clamps the applied value")

	modal.open(1250000, {"step": 100000})
	await _frames(2)
	nav.confirmed.emit()
	await _frames(2)
	_check(_applied == [1150000, 1000, 1300000], "step snaps the applied value")

	modal.open(25000, {"place_multiplier": 1000})
	await _frames(2)
	_check(modal.value() == 25000, "place_multiplier scales the committed value")
	_check(modal.index() == 7, "the cursor follows the scaled digits")
	nav.cancelled.emit()
	await _frames(3)
	_check(_applied.size() == 3, "Back closes without applying")
	_check(_closed == 4, "Back reports the close")
	_check(not modal.is_open(), "Back leaves the modal closed")

	modal.queue_free()
	_finish()
