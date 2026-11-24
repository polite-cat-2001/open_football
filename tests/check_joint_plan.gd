extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("_run")
func _check(ok: bool, msg: String) -> void:
	if ok: print("  ok: ", msg)
	else: failures.append(msg); print("  FAIL: ", msg)
func _run() -> void:
	var requests := [
		{"id": "league", "priority": 3, "start": "2026-08-20", "end": "2027-05-20", "days": 38},
		{"id": "conf", "priority": 4, "start": "2026-09-14", "end": "2027-05-02", "days": 13},
	]
	var plan := CareerCalendar.joint_plan(requests, [], "world", 3)
	var league: Array = plan.get("league", [])
	var conf: Array = plan.get("conf", [])
	_check(league.size() == 38, "the league keeps its 38 dates")
	_check(conf.size() == 13, "the international window keeps its 13 dates")
	var silent := 0
	for c in conf:
		for l in league:
			if absi(CareerSeason.days_between(str(c), str(l))) < 3 \
					and not _reported(str(c)):
				silent += 1
	_check(silent == 0, "no silent clash between the league and the international window")
	var tight := [
		{"id": "league", "priority": 3, "start": "2026-10-01", "end": "2026-10-31", "days": 10},
		{"id": "conf", "priority": 4, "start": "2026-10-01", "end": "2026-10-31", "days": 10},
	]
	CareerCalendar.joint_plan(tight, [], "world", 3)
	_check(not CareerCalendar.last_compressed.is_empty(),
		"a tight window reports the compressed days")
	print("== check_joint_plan: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), ") ==")
	quit(0 if failures.is_empty() else 1)
func _reported(date: String) -> bool:
	for item in CareerCalendar.last_compressed:
		if str(item.get("date", "")) == date:
			return true
	return false
