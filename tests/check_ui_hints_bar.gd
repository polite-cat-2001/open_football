extends SceneTree
# Rule check: every shell screen uses the shared UiHintsBar instead of a local
# status/legend pair, and the widget exposes the same height/status seam.
#
# Run:  godot --headless --path . -s res://tests/check_ui_hints_bar.gd

const SCENES := [
	"res://scenes/main_menu.tscn",
	"res://scenes/network_menu.tscn",
	"res://scenes/network_host.tscn",
	"res://scenes/network_join.tscn",
	"res://scenes/ui/side_select_view.tscn",
	"res://scenes/ui/team_select_view.tscn",
	"res://scenes/ui/kit_select_view.tscn",
	"res://scenes/ui/match_hub_view.tscn",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)
	return condition



func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	for path in SCENES:
		await _check_scene(path)
	await _check_widget()
	if failures.is_empty():
		print("== check_ui_hints_bar: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_ui_hints_bar: FAIL ==")
	quit(0 if failures.is_empty() else 1)


func _check_scene(path: String) -> void:
	var packed: PackedScene = load(path)
	if not _check(packed != null, path.get_file() + " loads"):
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Node = packed.instantiate()
	host.add_child(screen)
	await _frames(3)
	var hints := screen.find_child("Hints", true, false)
	_check(hints is UiHintsBar, path.get_file() + " uses UiHintsBar")
	if hints is UiHintsBar:
		_check(hints.legend != null and hints.status_label != null,
			path.get_file() + " exposes status + legend")
		_check(absf(hints.height() - (UiTokens.HINTS_STATUS_H
			+ UiTokens.HINTS_STATUS_GAP + UiTokens.HINTS_LEGEND_H)) <= 1.0,
			path.get_file() + " hints height is uniform")
	viewport.queue_free()
	await _frames(1)


func _check_widget() -> void:
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	root.add_child(host)
	host.size = Vector2(1480, 200)
	var hints: UiHintsBar = load("res://scenes/ui/ui_hints_bar.tscn").instantiate()
	host.add_child(hints)

	hints.size = Vector2(1480, hints.height())
	await _frames(2)
	hints.setup([{"keys": ["ENTER"], "label": "ready"}])
	_check(hints.legend.get_child_count() == 1, "setup fills the legend")
	hints.set_status("Choose a side first.", true)
	_check(hints.status_text() == "Choose a side first.", "status text is mirrored")
	_check(hints.status_label.theme_type_variation == &"SideStatusError",
		"status error style is applied")
	hints.set_status("")
	_check(hints.status_text().is_empty(), "status can be cleared")
	host.queue_free()
	await _frames(1)


