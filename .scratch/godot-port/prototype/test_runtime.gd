extends SceneTree

func _init() -> void:
	print("GpfRuntimeNode exists: ", ClassDB.class_exists("GpfRuntimeNode"))
	var node = ClassDB.instantiate("GpfRuntimeNode")
	if node == null:
		quit(1)
		return
	node.set("manual_step", true)
	node.set("data_root", "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data")
	get_root().add_child(node)
	node.start_runtime_now()
	print("ready=", node.is_runtime_ready(), " err=", node.get_last_error())
	if not node.is_runtime_ready():
		quit(2)
		return
	print("player ids=", node.get_player_ids())
	print("human=", node.get_human_player_id())
	node.select_player(1)
	node.start_open_play(1)
	print("after open play human=", node.get_human_player_id())
	node.set_button(1, true)
	node.set_button(14, true)
	node.step_fixed(80)
	node.set_button(14, false)
	node.set_button(1, false)
	node.set_button(6, true)
	node.step_fixed(3)
	node.set_button(6, false)
	node.step_fixed(77)
	var snap: Dictionary = node.get_snapshot()
	print("tick=", snap.get("tick"), " in_play=", snap.get("in_play"), " score=", snap.get("score0"), ":", snap.get("score1"))
	print("ball=", snap.get("ball_pos"), " player_id=", snap.get("player_id"))
	var p: Dictionary = snap.get("player", {})
	print("player=", p.get("id"), " pos=", p.get("pos"), " anim=", p.get("anim"), " frame=", p.get("frame"))
	print("bones=", (p.get("bones", []) as Array).size())
	quit(0)




