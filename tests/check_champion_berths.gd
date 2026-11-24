extends SceneTree
# Headless check for the automatic champion berths: the next season's field
# takes the previous champions at the stage the rules give them.
#
# Run:  godot --headless --path . -s res://tests/check_champion_berths.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _finish() -> void:
	print("== check_champion_berths: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var berths := {
		"Brazil": {"confederation": "CONMEBOL", "berths": []},
		"Korea, South": {"confederation": "AFC", "berths": []},
		"Mexico": {"confederation": "CONCACAF", "berths": []},
	}
	var old := {"confederations": {
		"CONMEBOL": {"competitions": {
			"libertadores": {"champion": "111"},
			"sudamericana": {"champion": "222"},
		}},
		"AFC": {"competitions": {
			"acl_elite": {"champion": "333"},
			"acl_two": {"champion": "444"},
			"afc_challenge_league": {"champion": "555"},
		}},
		"CONCACAF": {"competitions": {
			"champions_cup": {"champion": "666"},
		}},
	}}
	var fields := CareerSeason._confederation_fields(berths, old)
	_check(str(fields["CONMEBOL"]["libertadores"].get("111", "")) == "group_stage",
		"the Libertadores champion enters the next group stage")
	_check(str(fields["CONMEBOL"]["libertadores"].get("222", "")) == "group_stage",
		"the Sudamericana champion enters the next Libertadores group stage")
	_check(str(fields["AFC"]["acl_elite"].get("333", "")) == "league_stage",
		"the Elite champion enters the next league stage")
	_check(str(fields["AFC"]["acl_elite"].get("444", "")) == "playoff",
		"the ACL Two champion enters the next Elite play-off")
	_check(str(fields["AFC"]["acl_two"].get("555", "")) == "group_stage",
		"the Challenge champion enters the next ACL Two group stage")
	_check(str(fields["CONCACAF"]["champions_cup"].get("666", "")) == "round_of_16",
		"the CONCACAF champion enters the next round of 16")
	var recopa: Dictionary = fields["CONMEBOL"].get("recopa", {})
	_check(str(recopa.get("111", "")) == "final"
		and str(recopa.get("222", "")) == "final",
		"the two CONMEBOL champions play the Recopa Sudamericana")
	_finish()
