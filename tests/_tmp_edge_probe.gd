extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _run() -> void:
	var dir := "user://career_edge_probe_%d" % Time.get_ticks_usec()
	CareerSaveStore.root_override = dir
	CareerSession.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root():
		print("no db"); quit(1); return
	var career := CareerFactory.create(catalog, 131, "Probe Manager", 189, 42)
	var store := CareerSaveStore.new(dir)
	store.save(career)
	CareerSession.career = career
	CareerSession.store = store
	CareerSession.catalog = catalog
	root.get_node("UiTransition").set("instant", false)
	change_scene_to_file("res://scenes/career_hub.tscn")
	await _wait(0.9)
	var hub = current_scene
	var nav := root.get_node("UiNav")
	var tab_bar: UiTabBar = hub.get_node("Design/PanelWrap/Body/TabBar")
	var transfers = hub.get_node("Design/PanelWrap/Body/TransfersView")
	var squad = hub.get_node("Design/PanelWrap/Body/SquadView")
	nav.tab_next.emit()
	await _wait(0.9)
	print("A squad: tab=", tab_bar.get_active_tab(), " focus=", _n(root.gui_get_focus_owner()),
		" squad_focus=", squad.focused_id())
	nav.moved.emit(Vector2i.DOWN)
	await _wait(0.4)
	print("B down: focus=", _n(root.gui_get_focus_owner()), " squad_focus=", squad.focused_id())
	squad.handle_moved(Vector2i.RIGHT)
	await _wait(0.2)
	print("C right: squad_focus=", squad.focused_id())
	nav.moved.emit(Vector2i.RIGHT)
	await _wait(1.2)
	var th = transfers.get_node_or_null("Hub")
	print("D edge->transfers: tab=", tab_bar.get_active_tab(),
		" view=", transfers.current_view(), " focus=", _n(root.gui_get_focus_owner()),
		" t_focus=", th.focused_index() if th != null else -1,
		" visible=", th.visible if th != null else false)
	# Leave back to squad and repeat (second visit).
	nav.tab_previous.emit()
	await _wait(0.9)
	print("E back: tab=", tab_bar.get_active_tab(), " squad_focus=", squad.focused_id())
	if squad.focused_id() == "":
		squad.focus_initial()
	nav.moved.emit(Vector2i.RIGHT)
	await _wait(1.2)
	th = transfers.get_node_or_null("Hub")
	print("F edge again: tab=", tab_bar.get_active_tab(),
		" focus=", _n(root.gui_get_focus_owner()),
		" t_focus=", th.focused_index() if th != null else -1)
	quit(0)

func _n(node: Node) -> String:
	return "null" if node == null else str(node.name)
