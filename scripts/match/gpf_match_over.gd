class_name GpfMatchOver
extends Node
# End-of-match overlay carrier: one CanvasLayer over the frozen match holding the
# two design-system screens (result and the 90:00 draw choice). The orchestrator
# decides which one is current from the snapshot; this node only routes input and
# re-emits the chosen action.

signal advance_requested
signal restart_requested
signal choice_made(id: String)

const RESULT_SCENE := preload("res://scenes/match/match_result.tscn")
const CHOICE_SCENE := preload("res://scenes/match/match_choice.tscn")

var layer: CanvasLayer
var result: MatchResultScreen
var choice: MatchChoiceScreen

var _runtime: Node = null
var _package: Dictionary = {}


func setup() -> void:
	layer = CanvasLayer.new()
	layer.name = "MatchOver"
	layer.layer = 7
	add_child(layer)

	result = RESULT_SCENE.instantiate() as MatchResultScreen
	result.name = "Result"
	layer.add_child(result)
	result.advance_requested.connect(func(): advance_requested.emit())
	result.restart_requested.connect(func(): restart_requested.emit())

	choice = CHOICE_SCENE.instantiate() as MatchChoiceScreen
	choice.name = "Choice"
	layer.add_child(choice)
	choice.option_chosen.connect(func(id: String): choice_made.emit(id))


func set_match(runtime_node: Node, package: Dictionary) -> void:
	_runtime = runtime_node
	_package = package
	# The result screen disables its local restart for any network match; the
	# draw choice stays host-only, so the client flag differs.
	result.set_online(_is_network())
	choice.set_online(_is_client())


func open_result(series_caption := "") -> void:
	if choice.is_open():
		choice.hide_now()
	result.set_match_data(_data(series_caption))
	result.open()


func open_choice() -> void:
	if result.is_open():
		result.hide_now()
	choice.set_match_data(_data(""))
	choice.open()


func is_open() -> bool:
	return result.is_open() or choice.is_open()


func is_choice() -> bool:
	return choice.is_open()


func dismiss() -> void:
	if result.is_open():
		result.close()
	if choice.is_open():
		choice.close()


func hide_now() -> void:
	result.hide_now()
	choice.hide_now()


func handle_key(event: InputEventKey) -> bool:
	if choice.is_open():
		return choice.handle_key(event)
	if result.is_open():
		return result.handle_key(event)
	return false


func handle_joy(event: InputEventJoypadButton) -> bool:
	if choice.is_open():
		return choice.handle_joy(event)
	if result.is_open():
		return result.handle_joy(event)
	return false


func _is_network() -> bool:
	return _runtime != null and is_instance_valid(_runtime) \
		and _runtime.has_method("is_net_active") and bool(_runtime.is_net_active())


func _is_client() -> bool:
	return _runtime != null and is_instance_valid(_runtime) \
		and _runtime.has_method("is_net_client") and bool(_runtime.is_net_client())


func _data(caption: String) -> Dictionary:
	var home: Dictionary = _package.get("home", {})
	var away: Dictionary = _package.get("away", {})
	var snap: Dictionary = {}
	if _runtime != null and is_instance_valid(_runtime):
		snap = _runtime.get_snapshot()
	return {
		"home": home,
		"away": away,
		"score0": int(snap.get("score0", 0)),
		"score1": int(snap.get("score1", 0)),
		"caption": caption,
		"meta": str(home.get("league", "")),
	}
