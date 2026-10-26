extends SceneTree
# Headless regression for the original phase-break signal: at half-time the
# bridge must expose a pending break, begin_phase_break() must pause, and
# continue_after_phase_break() must resume. AI vs AI with the accelerated clock.
#
# Run:  godot --headless --path . -s res://tests/check_gpf_phase_break.gd

const DATA_ROOT := "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data"
const MAX_TICKS := 60000

var failures: Array[String] = []
var runtime: Node

func _init() -> void:
	runtime = ClassDB.instantiate("GpfRuntimeNode")
	if runtime == null:
		print("CHECK FAIL: GpfRuntimeNode is not registered")
		quit(1)
		return
	runtime.set("manual_step", true)
	runtime.set("human_control", false)
	runtime.set("match_duration", 0.0)
	runtime.set("data_root", DATA_ROOT)
	get_root().add_child(runtime)
	runtime.start_runtime_now()
	if not runtime.is_runtime_ready():
		print("CHECK FAIL: runtime did not start: ", runtime.get_last_error())
		quit(1)
		return

	_run()
	if failures.is_empty():
		print("CHECK PASS: phase break")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)

func _run() -> void:
	var snap: Dictionary = runtime.get_snapshot()
	var guard := 0
	while guard < MAX_TICKS and not bool(snap.get("phase_break_pending", false)):
		runtime.step_fixed(100)
		guard += 100
		snap = runtime.get_snapshot()

	_check(guard < MAX_TICKS, "half-time phase break arrived")
	_check(int(snap.get("phase_break_next_phase", 0)) == 2, "next phase is the second half")
	_check(int(snap.get("match_phase", 0)) == 2, "phase is already the second half")
	_check(not bool(snap.get("phase_break", false)), "bridge has not paused before the UI opens")
	_check(not bool(snap.get("paused", false)), "headless run is not paused by the signal")

	_check(runtime.begin_phase_break(), "begin_phase_break() pauses")
	snap = runtime.get_snapshot()
	_check(bool(snap.get("paused", false)), "match is paused after begin_phase_break")
	_check(bool(snap.get("phase_break", false)), "phase_break state is exposed")

	runtime.continue_after_phase_break()
	snap = runtime.get_snapshot()
	_check(not bool(snap.get("paused", false)), "continue_after_phase_break unpauses")
	_check(not bool(snap.get("phase_break", false)), "phase_break clears on continue")
	_check(not bool(snap.get("phase_break_pending", false)), "pending break clears on continue")
