extends SceneTree
# Headless UI layout/focus lint. Every screen is instantiated inside a
# SubViewport at the two target resolutions; interactive controls must stay
# inside the viewport, have a positive size, and not overlap. Focusable
# controls must form a traversable chain.
#
# Run:  godot --headless --path . -s res://tests/check_ui_layout.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const SCREENS := [
	"res://scenes/main_menu.tscn",
	"res://scenes/controller_select.tscn",
	"res://scenes/ui/side_select_view.tscn",
	"res://scenes/team_select.tscn",
	"res://scenes/kit_select.tscn",
	"res://scenes/ui/kit_select_view.tscn",
	"res://scenes/prematch.tscn",
	"res://scenes/ui_lab.tscn",
]
const SIDE_FIXTURE := preload("res://tests/side_select_fixture.gd")
const KIT_FIXTURE := preload("res://tests/kit_select_fixture.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	failures.append(message)
	print("  FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _seed() -> void:
	ShellState.clear()
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(DATA_ROOT):
		_fail("catalog loads: " + str(catalog.error))
		return
	var home := catalog.team_by_id(3)
	var away := catalog.team_by_id(8)
	ShellState.set_teams(home, away)
	ShellState.set_controllers([
		{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
	])


func _run() -> void:
	_seed()
	for size in SIZES:
		for path in SCREENS:
			await _check_screen(path, size)
	print("== check_ui_layout: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _check_screen(path: String, size: Vector2i) -> void:
	var label := "%s @ %dx%d" % [path.get_file(), size.x, size.y]
	print("-- ", label)
	var packed: PackedScene = load(path)
	if packed == null:
		_fail(label + ": scene loads")
		return
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var screen: Node = packed.instantiate()
	viewport.add_child(screen)
	await _frames(3)
	if path.ends_with("side_select_view.tscn"):
		screen.call("setup", SIDE_FIXTURE.rows_2p(), {
			"input_mode": "devices",
			"show_names": true,
			"back_label": "leave",
		})
		await _frames(3)
	if path.ends_with("kit_select_view.tscn"):
		screen.call("setup", KIT_FIXTURE.state_1p(), {"back_label": "back"})
		await _frames(3)
	if path.ends_with("kit_select.tscn"):
		await _frames(6)

	var states: Array = [""]
	if screen.has_method("set_state") and path.ends_with("ui_lab.tscn"):
		states = []
		for i in 16:
			states.append(str(i))
	for state in states:
		if state != "":
			screen.call("set_state", int(state))
			await _frames(2)
		_check_layout(screen, Vector2(size), label + " state " + str(state))
		_check_focus(screen, label + " state " + str(state))
	if path.ends_with("prematch.tscn") and screen.has_method("_select_tab"):
		screen.call("_select_tab", 3)
		await _frames(3)
		_check_layout(screen, Vector2(size), label + " gameplan")
		_check_focus(screen, label + " gameplan")

	viewport.queue_free()
	await _frames(1)


func _check_layout(root_node: Node, view: Vector2, label: String) -> void:
	var rects: Array = []
	for control in _interactive_controls(root_node):
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		var name := String(control.name)
		if rect.size.x <= 0.5 or rect.size.y <= 0.5:
			_fail("%s: %s has zero size" % [label, name])
		if rect.position.x < -1.0 or rect.position.y < -1.0 \
				or rect.end.x > view.x + 1.0 or rect.end.y > view.y + 1.0:
			_fail("%s: %s out of viewport %s" % [label, name, str(rect)])
		rects.append({"name": name, "rect": rect, "node": control})
	print("   controls=", rects.size())
	_check_label_bounds(root_node, view, label)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Dictionary = rects[i]
			var b: Dictionary = rects[j]
			if a["node"].is_ancestor_of(b["node"]) or b["node"].is_ancestor_of(a["node"]):
				continue
			if (a["rect"] as Rect2).intersects(b["rect"] as Rect2):
				_fail("%s: %s overlaps %s" % [label, a["name"], b["name"]])


func _check_label_bounds(root_node: Node, view: Vector2, label: String) -> void:
	for control in _all_labels(root_node):
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if rect.size.x <= 0.5 or rect.size.y <= 0.5:
			continue
		if rect.position.x < -1.0 or rect.position.y < -1.0 \
				or rect.end.x > view.x + 1.0 or rect.end.y > view.y + 1.0:
			_fail("%s: label %s out of viewport %s" % [label, String(control.name), str(rect)])


func _all_labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	if node is Label:
		result.append(node as Label)
	for child in node.get_children():
		result.append_array(_all_labels(child))
	return result


func _check_focus(root_node: Node, label: String) -> void:
	var focusables: Array[Control] = []
	for control in _interactive_controls(root_node):
		if control is BaseButton or control is Range:
			if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE \
					and not (control is BaseButton and (control as BaseButton).disabled):
				focusables.append(control)
	if focusables.is_empty():
		return
	var reached := {}
	var current: Control = focusables[0]
	for guard in 64:
		if current == null or reached.has(current):
			break
		reached[current] = true
		current = current.find_next_valid_focus()
	for control in focusables:
		if not reached.has(control):
			_fail("%s: focus cannot reach %s" % [label, String(control.name)])


func _interactive_controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is BaseButton or node is Range or node is ItemList:
		result.append(node as Control)
	for child in node.get_children():
		result.append_array(_interactive_controls(child))
	return result
