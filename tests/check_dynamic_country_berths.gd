extends SceneTree
# Headless check for a dynamic country rank in the UEFA access list: England at
# rank 1 gets four Champions League places plus the EPS place; at rank 6 it gets
# three, and the EPS flag adds the fourth. The override must not need a new access
# asset, only the rank from the rolling country table.
#
# Run:  godot --headless --path . -s res://tests/check_dynamic_country_berths.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _rows() -> Array:
	var rows: Array = []
	for index in range(20):
		rows.append({"club_id": "c%d" % (index + 1), "position": index + 1})
	return rows


func _ucl_count(block: Dictionary) -> int:
	var count := 0
	for berth in block.get("berths", []):
		if str((berth as Dictionary).get("competition", "")) == "CL":
			count += 1
	return count


func _run() -> void:
	var rows := _rows()
	var cups := {"FA Cup": {"winner": "cup_winner_club"}}
	var top := CareerBerths.for_country("England", rows, cups)
	_check(int(top.get("rank", 0)) == 1, "England starts at rank 1")
	_check(_ucl_count(top) == 5, "rank 1 gets four places and the EPS place")
	var low := CareerBerths.for_country("England", rows, cups, 6, false)
	_check(int(low.get("rank", 0)) == 6, "the rank override is used")
	_check(_ucl_count(low) == 3, "rank 6 gets three Champions League places")
	_check(not bool(low.get("eps", true)), "the EPS override removes the extra place")
	var low_eps := CareerBerths.for_country("England", rows, cups, 6, true)
	_check(_ucl_count(low_eps) == 4, "the EPS override adds the fourth place")
	var top_no_eps := CareerBerths.for_country("England", rows, cups, 1, false)
	_check(_ucl_count(top_no_eps) == 4, "rank 1 without EPS gets four places")
	print("== check_dynamic_country_berths: ",
		"PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
