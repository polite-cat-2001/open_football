class_name CareerJob
extends RefCounted
# One callable run off the main thread, for work that is too slow for a frame
# (the 120k-row player walk). The caller starts it, keeps drawing, and collects
# the result with `take()` once `done()`.
#
# The worker must only touch plain data: no scene tree, no shared SQLite
# reader, no writes into the career the UI is reading. It runs on the engine's
# worker pool, which is also joined on shutdown, so a job still running when
# the game quits cannot outlive the scripts it calls.

var _task := -1
var _result = null
var _finished := false


func start(work: Callable) -> void:
	if _task >= 0:
		return
	_task = WorkerThreadPool.add_task(func() -> void:
		_result = work.call()
		_finished = true, false, "CareerJob")


func done() -> bool:
	if _finished:
		return true
	return _task >= 0 and WorkerThreadPool.is_task_completed(_task)


func running() -> bool:
	return _task >= 0


# Waits for the worker and returns its result. Safe to call once.
func take():
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return _result


func _notification(what: int) -> void:
	# A task still queued at destruction must be joined, and on a dying object
	# a method call is not safe any more, so the wait is inlined.
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
