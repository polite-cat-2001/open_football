class_name CareerTransfersView
extends Control
# Transfers tab host. The prototype's TransfersTab switches between the hub,
# filters, results, centre, offer, contract, history and the scouting network;
# each of those is a self-contained Control that reads UiNav itself. This node
# only owns the view switch, the payloads and the fade+scale transition.

signal changed
signal view_changed
# Emitted when a view swap starts (before its fade), for the shell's row swap.
signal view_opening(view: String)
signal exit_requested
signal tab_requested(delta: int)
# The transfer hub's card grid was pushed at its edge: the career hub switches
# section or hands focus back to the main tab strip.
signal edge_requested(direction: Vector2i)

const SCREENS := {
	"hub": "res://scripts/ui/career_transfer_hub.gd",
	"filters": "res://scripts/ui/career_transfer_filters.gd",
	"results": "res://scripts/ui/career_transfer_results.gd",
	"centre": "res://scripts/ui/career_transfer_centre.gd",
	"offer": "res://scripts/ui/career_transfer_offer.gd",
	"contract": "res://scripts/ui/career_transfer_contract.gd",
	"history": "res://scripts/ui/career_transfer_history.gd",
	"network": "res://scripts/ui/career_scouting_view.gd",
}
const PARENT := {
	"filters": "hub", "results": "filters", "centre": "hub",
	"history": "hub", "network": "hub",
	"offer": "results", "contract": "centre",
}
const CRUMBS := {
	"filters": "SEARCH",
	"results": "SEARCH RESULTS",
	"centre": "TRANSFER CENTRE",
	"offer": "TRANSFER OFFER",
	"contract": "CONTRACT TALKS",
	"history": "TRANSFER HISTORY",
	"network": "WORLD NETWORK",
}

var _career: Career
var _catalog: TeamCatalog
var _filters: Dictionary = {}
var _screens: Dictionary = {}
var _current := "hub"
var _back_view := ""
var _busy := false
var _open := false
var _shell_focused := false
# Result of the last scout assignment; the host shows it in its hints bar.
var _notice := ""
var _notice_error := false


func open(career: Career, catalog: TeamCatalog, start := "hub") -> void:
	_career = career
	_catalog = catalog
	if _filters.is_empty():
		_filters = CareerSearch.filters_default()
	_open = true
	visible = true
	_show(start, {})


func close() -> void:
	_open = false
	visible = false
	var screen := _screens.get(_current) as Control
	if screen != null and screen.has_method("close"):
		screen.close()


func current_view() -> String:
	return _current


func is_overlay() -> bool:
	return _current != "hub"


func focus_initial() -> void:
	var screen := _current_screen()
	if screen != null and screen.has_method("focus_initial"):
		screen.focus_initial()


# The shell's tab strip owns input: the landing screens must ignore moves
# (they read UiNav themselves) until Down hands the focus to the page.
func set_shell_focused(value: bool) -> void:
	_shell_focused = value
	var screen := _current_screen()
	if screen != null and screen.has_method("set_shell_focused"):
		screen.set_shell_focused(value)


# Drop the move/tab event that enters the landing; the hub calls it only for
# wiring-driven entries, never for a click or a Q/E that the landing won't see.
func suppress_event() -> void:
	var screen := _current_screen()
	if screen != null and screen.has_method("suppress_event"):
		screen.suppress_event()


func hints() -> Array:
	var screen := _current_screen()
	if screen != null and screen.has_method("hints"):
		return screen.hints()
	return []


func breadcrumb(view := _current) -> Array[String]:
	if view == "hub":
		return []
	return ["CAREER", "TRANSFERS", str(CRUMBS.get(view, str(view).to_upper()))]


func status() -> String:
	if not _notice.is_empty():
		return _notice
	var screen := _current_screen()
	if screen != null and screen.has_method("status"):
		return str(screen.status())
	return ""


func status_error() -> bool:
	if not _notice.is_empty():
		return _notice_error
	var screen := _current_screen()
	if screen != null and screen.has_method("status_error"):
		return bool(screen.status_error())
	return false


func refresh() -> void:
	var screen := _current_screen()
	if screen != null and screen.has_method("open"):
		_configure(screen, _current, {})


func _current_screen() -> Control:
	return _screens.get(_current) as Control


# Autoloads are looked up by path: the screen is also instantiated by headless
# tests directly, where bare UiTransition identifiers do not resolve.
func _instant() -> bool:
	var transition := get_node_or_null("/root/UiTransition")
	return transition != null and bool(transition.get("instant"))


func _ensure(view: String) -> Control:
	if _screens.has(view):
		return _screens[view] as Control
	var path := str(SCREENS.get(view, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var script := load(path) as Script
	if script == null:
		return null
	var screen := script.new() as Control
	if screen == null:
		return null
	screen.name = view.capitalize()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	_screens[view] = screen
	if screen.has_signal("navigate"):
		screen.connect("navigate", _on_navigate)
	if screen.has_signal("closed"):
		screen.connect("closed", _on_closed)
	if screen.has_signal("changed"):
		screen.connect("changed", _on_changed)
	if screen.has_signal("tab_requested"):
		screen.connect("tab_requested", func(delta: int) -> void: tab_requested.emit(delta))
	if screen.has_signal("edge_requested"):
		screen.connect("edge_requested", func(direction: Vector2i) -> void:
			edge_requested.emit(direction))
	if screen.has_signal("scout_requested"):
		screen.connect("scout_requested", _on_scout_requested)
	if screen.has_signal("applied"):
		screen.connect("applied", _on_filters_applied)
	if screen.has_signal("state_changed"):
		screen.connect("state_changed", func() -> void: view_changed.emit())
	if screen.has_signal("sort_applied"):
		screen.connect("sort_applied", func(sort: String, direction: String) -> void:
			_filters["sort"] = sort
			_filters["direction"] = direction
			view_changed.emit())
	return screen


func _show(view: String, payload: Dictionary) -> void:
	if not _open:
		return
	var screen := _ensure(view)
	if screen == null:
		return
	_notice = ""
	if _busy:
		return
	if _current == view and screen.visible:
		_configure(screen, view, payload)
		view_changed.emit()
		return
	var previous := _current_screen()
	_busy = true
	# Announced before the fade: the shell starts the tab strip/path swap with
	# the view, not after it.
	view_opening.emit(view)
	var swap := func() -> void:
		if previous != null:
			previous.visible = false
			if previous.has_method("close"):
				previous.close()
		_current = view
		_configure(screen, view, payload)
		if screen.has_method("set_shell_focused"):
			screen.set_shell_focused(_shell_focused)
		screen.visible = true
		screen.modulate.a = 1.0
		screen.scale = Vector2.ONE
	if _instant() or previous == null or not is_inside_tree():
		swap.call()
		_busy = false
		view_changed.emit()
		return
	pivot_offset = size * 0.5
	screen.pivot_offset = size * 0.5
	var out := create_tween().set_parallel(true)
	out.tween_property(previous, "modulate:a", 0.0, UiTransition.OUT_TIME)
	out.tween_property(previous, "scale", Vector2(0.96, 0.96), UiTransition.OUT_TIME)
	out.finished.connect(func() -> void:
		swap.call()
		screen.modulate.a = 0.0
		screen.scale = Vector2(0.96, 0.96)
		var enter := create_tween().set_parallel(true)
		enter.tween_property(screen, "modulate:a", 1.0, UiTransition.IN_TIME)
		enter.tween_property(screen, "scale", Vector2.ONE, UiTransition.IN_TIME)
		enter.finished.connect(func() -> void:
			_busy = false
			view_changed.emit()))


func _configure(screen: Control, view: String, payload: Dictionary) -> void:
	if _career == null or _catalog == null:
		return
	match view:
		"filters":
			screen.setup(_filters, _reference())
		"results":
			var next := {"filters": _filters}
			if bool(payload.get("resume", false)):
				next["resume"] = true
			screen.setup(_career, _catalog, next)
		_:
			if screen.has_method("open"):
				screen.open(_career, _catalog, payload)
			elif screen.has_method("setup"):
				screen.setup(_career, _catalog, payload)


func _reference() -> Dictionary:
	var reference := CareerSearch.filter_reference(_catalog)
	reference["clubs"] = _catalog.career_clubs() \
		if _catalog.has_method("career_clubs") else []
	return reference


func _on_navigate(view: String, payload: Dictionary) -> void:
	if _busy:
		return
	match view:
		"filters":
			_show("filters", {})
		"results":
			_show("results", payload)
		"centre":
			_show("centre", payload)
		"history":
			_show("history", {})
		"network":
			_show("network", payload)
		"offer":
			_back_view = _current
			_show("offer", payload)
		"contract":
			_back_view = _current
			_show("contract", payload)
		"exit":
			exit_requested.emit()
		_:
			_show(view, payload)


func _on_closed() -> void:
	if _busy:
		return
	if _current == "hub":
		exit_requested.emit()
		return
	# The offer / contract screens return where they were opened from (the
	# search results or the Transfer Centre); the rest keep their fixed parent.
	var back := str(PARENT.get(_current, "hub"))
	var resume := false
	if _current in ["offer", "contract"] and not _back_view.is_empty():
		back = _back_view
		resume = true
	_back_view = ""
	_show(back, {"resume": true} if resume else {})


func _on_changed() -> void:
	if _career == null:
		return
	_career.touch()
	var store := CareerSession.store if CareerSession.store != null else CareerSaveStore.new()
	if store.save(_career):
		CareerSession.store = store
	changed.emit()


func _on_scout_requested(player_id: String, scout_id: String) -> void:
	if _career == null or _catalog == null:
		return
	var result := CareerScouting.assign(_career, _catalog, scout_id, player_id)
	if not bool(result.get("ok", false)):
		_notice = str(result.get("error", "the scout could not be assigned"))
		_notice_error = true
		view_changed.emit()
		return
	_notice = ""
	_notice_error = false
	_on_changed()


func _on_filters_applied(filters: Dictionary) -> void:
	_filters = filters
	if _current == "filters":
		_show("results", {"filters": _filters})
