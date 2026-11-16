class_name CareerWarmup
extends Node
# GDScript compiles a screen the first time it is loaded, and the career screens
# depend on each other, so the first entry used to compile ~1-2 s of code on the
# click that opened the hub (debug builds are slowest). This node loads the list
# one script per frame while the player reads the screen he is already on, so the
# compile cost is paid out of sight. `load()` is idempotent, so screens may start
# their own warm-up without coordinating.

const ENTRY: Array[String] = [
	"res://scripts/ui/career_hub.gd",
	"res://scripts/ui/career_new.gd",
	"res://scripts/ui/career_load.gd",
	"res://scripts/ui/career_squad_view.gd",
	"res://scripts/ui/career_transfers_view.gd",
]
const TRANSFERS: Array[String] = [
	"res://scripts/ui/career_transfer_hub.gd",
	"res://scripts/ui/career_transfer_filters.gd",
	"res://scripts/ui/career_transfer_results.gd",
	"res://scripts/ui/career_transfer_centre.gd",
	"res://scripts/ui/career_transfer_offer.gd",
	"res://scripts/ui/career_transfer_contract.gd",
	"res://scripts/ui/career_transfer_history.gd",
	"res://scripts/ui/career_scouting_view.gd",
	"res://scripts/ui/career_player_actions.gd",
	"res://scripts/ui/career_scout_picker.gd",
	"res://scripts/ui/career_amount_modal.gd",
	"res://scripts/ui/career_match_overlay.gd",
	"res://scripts/ui/career_negotiation.gd",
	"res://scripts/ui/career_shirt_number.gd",
	"res://scripts/ui/career_release.gd",
]

var _queue: Array[String] = []


static func start(host: Node, paths: Array[String]) -> void:
	if host == null or not host.is_inside_tree():
		return
	var warmup := CareerWarmup.new()
	warmup.name = "CareerWarmup"
	warmup._queue = paths.duplicate()
	host.add_child(warmup)


func _ready() -> void:
	set_process(not _queue.is_empty())


func _process(_delta: float) -> void:
	if _queue.is_empty():
		set_process(false)
		queue_free()
		return
	load(_queue.pop_front())
