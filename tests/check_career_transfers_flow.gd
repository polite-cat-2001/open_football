extends SceneTree
# Headless check for the transfers tab host: tab switching, breadcrumbs, the
# hub landing -> filters -> results -> offer route, history, and the Centre tile
# shortcut. Screens come from the prototype's TransfersTab view switch.
#
# Run:  godot --headless --path . -s res://tests/check_career_transfers_flow.gd

const HUB := "res://scenes/career_hub.tscn"

var failures: Array[String] = []
var _directory := ""


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
	_cleanup()
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	print("== check_career_transfers_flow: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _cleanup() -> void:
	if _directory.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(_directory)
	DirAccess.remove_absolute(absolute)


func _run() -> void:
	_directory = "user://career_transfers_flow_test_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = _directory
	CareerSession.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	var nav := root.get_node("UiNav")

	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	_check(career != null, "the career is created: " + CareerFactory.last_error)
	if career == null:
		_finish()
		return
	var store := CareerSaveStore.new(_directory)
	_check(store.save(career), "the career saves")
	CareerSession.career = career
	CareerSession.catalog = catalog
	CareerSession.store = store

	CareerSession.career.hub_tab = "centre"
	var hub := (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	await _frames(3)

	var tab_bar: UiTabBar = hub.get_node("Design/PanelWrap/Body/TabBar")
	var breadcrumb: UiBreadcrumb = hub.get_node("Design/PanelWrap/Body/Breadcrumb")
	var transfers = hub.get_node("Design/PanelWrap/Body/TransfersView")
	var health := hub.get_node("Design/PanelWrap/Body/Grid/TrainingTile")

	_check(CareerHubModel.TABS.size() == 5 and CareerHubModel.PLACEHOLDER_TABS.size() == 2,
		"scouting lives inside transfers; academy and office are placeholders")
	_check(tab_bar.get_active_tab() == 0, "the Centre tab is active")
	nav.tab_next.emit()
	await _frames(2)
	nav.tab_next.emit()
	await _frames(3)
	_check(tab_bar.get_active_tab() == 2, "R1 twice reaches the Transfers tab")
	_check(transfers.visible, "the transfers host is visible")
	_check(transfers.current_view() == "hub", "the transfers landing is the first view")
	_check(not breadcrumb.visible, "the landing keeps the top tabs")
	var landing := transfers.get_node_or_null("Hub")
	_check(landing != null, "the landing screen is built")

	landing.navigate.emit("filters", {})
	await _frames(3)
	_check(transfers.current_view() == "filters", "SEARCH PLAYERS opens the filters")
	_check(breadcrumb.visible, "a subview shows the breadcrumb")
	_check(not tab_bar.visible, "a subview hides the top tabs")
	_check(breadcrumb.get_child_count() == 3
		and (breadcrumb.get_child(2) as Label).text == "SEARCH",
		"the breadcrumb reads CAREER / TRANSFERS / SEARCH")

	var filters := transfers.get_node_or_null("Filters")
	_check(filters != null, "the filters screen is built")
	filters.applied.emit(CareerSearch.filters_default())
	await _frames(3)
	_check(transfers.current_view() == "results", "the filter search opens the results")
	var results := transfers.get_node_or_null("Results")
	_check(results != null, "the results screen is built")
	_check(results.item_count() > 0, "the results list has players")
	var first := str(results.selected_id())
	_check(not first.is_empty(), "the first player is selected")

	results.navigate.emit("offer", {"player_id": first, "kind": "transfer"})
	await _frames(3)
	_check(transfers.current_view() == "offer", "a result opens the offer screen")
	var offer := transfers.get_node_or_null("Offer")
	_check(offer != null, "the offer screen holds the player")
	offer.closed.emit()
	await _frames(3)
	_check(transfers.current_view() == "results", "Back from the offer returns to results")

	results.closed.emit()
	await _frames(3)
	_check(transfers.current_view() == "filters",
		"Back from results returns to the search board")
	_check(breadcrumb.visible, "the search board keeps its breadcrumb")
	filters = transfers.get_node_or_null("Filters")
	filters.closed.emit()
	await _frames(3)
	_check(transfers.current_view() == "hub", "Back from the search board returns to the landing")
	_check(not breadcrumb.visible, "the landing restores the top tabs")
	landing.navigate.emit("history", {})
	await _frames(3)
	_check(transfers.current_view() == "history", "HISTORY opens the history screen")
	_check((breadcrumb.get_child(2) as Label).text == "TRANSFER HISTORY",
		"the history breadcrumb is labelled")
	var history := transfers.get_node_or_null("History")
	_check(history != null, "the history screen is built")
	history.closed.emit()
	await _frames(3)
	_check(transfers.current_view() == "hub", "Back from history returns to the landing")
	landing.navigate.emit("network", {"mode": "scouts"})
	await _frames(3)
	_check(transfers.current_view() == "network", "WORLD NETWORK opens the scouting screen")
	var network := transfers.get_node_or_null("Network")
	_check(network != null, "the scouting screen is built")
	network.closed.emit()
	await _frames(3)
	_check(transfers.current_view() == "hub", "Back from scouting returns to the landing")
	landing.navigate.emit("centre", {})
	await _frames(4)
	_check(transfers.current_view() == "centre", "TRANSFER CENTRE opens the four-tab centre")
	var centre = transfers.get_node_or_null("Centre")
	_check(centre != null, "the transfer centre screen is built")
	_check(centre.tab() == "shortlist", "the centre opens on the shortlist")
	_check(centre.tab_ids().size() == 4, "the centre has four tabs")
	_check((breadcrumb.get_child(2) as Label).text == "TRANSFER CENTRE",
		"the centre breadcrumb is labelled")
	centre.closed.emit()
	await _frames(3)
	_check(transfers.current_view() == "hub", "Back from the centre returns to the landing")

	transfers.exit_requested.emit()
	await _frames(3)
	_check(tab_bar.get_active_tab() == 0, "Back from the landing returns to Centre")
	var tile: BentoTile = hub.get_node("Design/PanelWrap/Body/Grid/TransferTile")
	_check(tile.focus_mode == Control.FOCUS_ALL, "the Centre transfer tile is live")
	tile.pressed.emit()
	await _frames(3)
	_check(tab_bar.get_active_tab() == 2, "the Centre tile opens the Transfers tab")
	_check(health.focus_mode == Control.FOCUS_NONE, "the unused tiles stay inert")
	_check(career.hub_tab == "transfers", "the transfers tab is stored on the career")
	_finish()
