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
			"CLI": {"champion": "111"},
			"CS": {"champion": "222"},
		}},
		"AFC": {"competitions": {
			"ACLE": {"champion": "333"},
			"ACL2": {"champion": "444"},
			"AFCP": {"champion": "555"},
		}},
		"CONCACAF": {"competitions": {
			"CCL": {"champion": "666"},
		}},
	}}
	var fields := CareerSeason._confederation_fields(berths, old)
	_check(str(fields["CONMEBOL"]["CLI"].get("111", "")) == "group_stage",
		"the Libertadores champion enters the next group stage")
	_check(str(fields["CONMEBOL"]["CLI"].get("222", "")) == "group_stage",
		"the Sudamericana champion enters the next Libertadores group stage")
	_check(str(fields["AFC"]["ACLE"].get("333", "")) == "league_stage",
		"the Elite champion enters the next league stage")
	_check(str(fields["AFC"]["ACLE"].get("444", "")) == "playoff",
		"the ACL Two champion enters the next Elite play-off")
	_check(str(fields["AFC"]["ACL2"].get("555", "")) == "group_stage",
		"the Challenge champion enters the next ACL Two group stage")
	_check(str(fields["CONCACAF"]["CCL"].get("666", "")) == "round_of_16",
		"the CONCACAF champion enters the next round of 16")
	var recopa: Dictionary = fields["CONMEBOL"].get("RECO", {})
	_check(str(recopa.get("111", "")) == "final"
		and str(recopa.get("222", "")) == "final",
		"the two CONMEBOL champions play the Recopa Sudamericana")
	_finish()
