extends SceneTree
# Windowed screenshot book for the career hub, the shared game plan and the
# squad centre.
#
# Run:  godot --path . -s res://tests/capture_career_shots.gd
# Out:  .scratch/ui_shots/career_<state>_<WxH>.png

const HUB_SCENE := "res://scenes/career_hub.tscn"
const OUT_DIR := "C:/Users/Egor/Desktop/projects/open_football_career/.scratch/ui_shots"
const SIZES := [Vector2i(1920, 1080)]
const STATES := [
	"centre", "squad_overview", "plan_squad", "plan_formations",
	"plan_roles", "plan_details", "squad_centre", "squad_centre_stats",
	"squad_centre_attrs", "squad_centre_finance",
	"transfers_hub", "transfers_filters", "transfers_results", "transfers_centre",
	"transfers_centre_sent", "transfers_offer", "transfers_contract", "transfers_history",
	"scouting_scouts", "scouting_reports",
	"squad_actions", "negotiation", "shirt_number", "release",
]

var saved := 0


func _init() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root():
		push_error("capture_career_shots: " + catalog.error)
		quit(1)
		return
	var career := CareerFactory.create(catalog, 131, "Golden Manager", 189, 42)
	if career == null:
		push_error("capture_career_shots: " + CareerFactory.last_error)
		quit(1)
		return
	CareerSession.career = career
	CareerSession.catalog = catalog
	CareerSaveStore.root_override = "user://career_capture_%d" % Time.get_ticks_usec()
	_seed_transfers(catalog, career)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	await _frames(2)
	for size in SIZES:
		for state in STATES:
			await _capture(state, size)
	print("captured ", saved, " career screenshots into ", OUT_DIR)
	CareerSaveStore.root_override = ""
	CareerSession.clear()
	quit(0)


func _capture(state: String, size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.theme = UiTheme.load_or_build()
	viewport.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hub: Control = (load(HUB_SCENE) as PackedScene).instantiate()
	host.add_child(hub)
	await _frames(6)
	var body := hub.get_node("Design/PanelWrap/Body")
	var view = body.get_node("SquadView")
	var plan = hub.get_node("Design/PlanHost/GamePlan")
	match state:
		"centre":
			pass
		"squad_overview":
			hub.call("_set_section", 1, 1)
		"plan_squad":
			hub.call("_set_section", 1, 1)
			await _frames(45)
			view.focus_initial()
			view.handle_confirmed()
		"plan_formations":
			hub.call("_set_section", 1, 1)
			await _frames(45)
			view.focus_initial()
			view.handle_confirmed()
			await _frames(8)
			plan.handle_ui_action("tab_next", -1)
		"plan_roles":
			hub.call("_set_section", 1, 1)
			await _frames(45)
			view.focus_initial()
			view.handle_confirmed()
			await _frames(8)
			plan.handle_ui_action("tab_next", -1)
			plan.handle_ui_action("tab_next", -1)
		"plan_details":
			hub.call("_set_section", 1, 1)
			await _frames(45)
			view.focus_initial()
			view.handle_confirmed()
			await _frames(8)
			plan.handle_ui_action("details", -1)
		"squad_centre":
			hub.call("_set_section", 1, 1)
			await _frames(45)
			view.focus_initial()
			view.handle_moved(Vector2i.RIGHT)
			view.handle_confirmed()
		"squad_centre_stats", "squad_centre_attrs", "squad_centre_finance":
			hub.call("_set_section", 1, 1)
			await _frames(45)
			view.focus_initial()
			view.handle_moved(Vector2i.RIGHT)
			view.handle_confirmed()
			view.call("_set_centre_tab", {"squad_centre_stats": 1, "squad_centre_attrs": 2,
				"squad_centre_finance": 3}[state])
		"transfers_hub":
			hub.call("_set_section", 2, 1)
		"transfers_filters":
			hub.call("_set_section", 2, 1)
			await _frames(45)
			_transfers(body).get_node("Hub").emit_signal("navigate", "filters", {})
		"transfers_results":
			await _open_results(hub, body)
		"transfers_centre":
			hub.call("_set_section", 2, 1)
			await _frames(45)
			_transfers(body).get_node("Hub").emit_signal("navigate", "centre", {})
		"transfers_centre_sent":
			hub.call("_set_section", 2, 1)
			await _frames(45)
			_transfers(body).get_node("Hub").emit_signal("navigate", "centre",
				{"tab": "sent"})
		"transfers_offer":
			await _open_results(hub, body)
			var results = _transfers(body).get_node("Results")
			results.emit_signal("navigate", "offer",
				{"player_id": str(results.selected_id()), "kind": "transfer"})
		"transfers_contract":
			hub.call("_set_section", 2, 1)
			await _frames(45)
			var free := CareerSearch.search(CareerSession.catalog, CareerSession.career,
				{"status": "free"}, 1, 0)
			var items: Array = free.get("items", [])
			if not items.is_empty():
				_transfers(body).get_node("Hub").emit_signal("navigate", "contract",
					{"player_id": str(items[0].get("player_id", ""))})
		"transfers_history":
			hub.call("_set_section", 2, 1)
			await _frames(45)
			_transfers(body).get_node("Hub").emit_signal("navigate", "history", {})
		"scouting_scouts", "scouting_reports":
			hub.call("_set_section", 2, 1)
			await _frames(45)
			_transfers(body).get_node("Hub").emit_signal("navigate", "network",
				{"mode": "reports" if state == "scouting_reports" else "scouts"})
		"squad_actions", "negotiation", "shirt_number", "release":
			hub.call("_set_section", 1, 1)
			await _frames(45)
			view.focus_initial()
			view.handle_moved(Vector2i.RIGHT)
			view.handle_confirmed()
			await _frames(45)
			view.handle_confirmed()
			await _frames(45)
			var row = view.get("_actions_row")
			if row != null:
				var pid: String = str(view.focused_id()).replace("centre-row:", "")
				if state != "squad_actions":
					row.action_requested.emit(
						{"negotiation": "renew", "shirt_number": "number",
							"release": "release"}[state], pid)
	await _frames(40)
	await RenderingServer.frame_post_draw
	var path := "%s/career_%s_%dx%d.png" % [OUT_DIR, state, size.x, size.y]
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("capture_career_shots: no image for " + path)
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("capture_career_shots: save failed %s (%d)" % [path, error])
		else:
			saved += 1
			print("  ", path)
	viewport.queue_free()
	await _frames(1)


func _transfers(body: Control) -> Control:
	return body.get_node("TransfersView")


# A shortlist entry, one listed player and one pending offer make the transfer
# centre screenshots show real rows instead of empty states.
func _seed_transfers(catalog: TeamCatalog, career: Career) -> void:
	var found := CareerSearch.search(catalog, career, {}, 40, 0)
	var items: Array = found.get("items", [])
	if items.is_empty():
		return
	CareerTransfers.toggle_shortlist(career, catalog, str(items[0].get("player_id", "")))
	if not career.player_ids.is_empty():
		CareerTransfers.set_status(career, catalog, str(career.player_ids[0]), "transfer")
	for item in items:
		if str(item.get("club_id", "")).is_empty() \
				or str(item.get("club_id", "")) == career.club_id:
			continue
		CareerTransferOffers.submit(career, catalog, str(item.get("player_id", "")),
			"transfer", 1_000_000, null, null, false)
		break


func _open_results(hub: Control, body: Control) -> void:
	hub.call("_set_section", 2, 1)
	await _frames(45)
	var host := _transfers(body)
	host.get_node("Hub").emit_signal("navigate", "filters", {})
	await _frames(40)
	host.get_node("Filters").emit_signal("applied", CareerSearch.filters_default())
	await _frames(45)
