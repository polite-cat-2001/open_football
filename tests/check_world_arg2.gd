extends SceneTree
# Headless check for the ARG2 world season: the two promoted clubs are distinct
# ARG2 clubs and the same seed gives the same pair.
#
# Run:  godot --headless --path . -s res://tests/check_world_arg2.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	var catalog := TeamCatalog.new()
	_check(catalog.load_data_root(), "catalog opens the database: " + catalog.error)
	if not catalog.is_loaded():
		_finish()
		return
	var league_ids := {}
	for team in catalog.all_teams_for_league("ARG2"):
		league_ids[str(team.get("id", ""))] = true
	var promoted := CareerWorld.arg2_promoted(catalog, 42)
	_check(promoted.size() == 2, "ARG2 promotes two clubs")
	_check(str(promoted[0]) != str(promoted[1]), "the two clubs are distinct")
	_check(league_ids.has(str(promoted[0])) and league_ids.has(str(promoted[1])),
		"both clubs belong to ARG2")
	var again := CareerWorld.arg2_promoted(catalog, 42)
	_check(again == promoted, "the same seed gives the same pair")
	_finish()


func _finish() -> void:
	print("== check_world_arg2: ", "PASS" if failures.is_empty() else "FAIL",
		" (", failures.size(), " failures) ==")
	quit(0 if failures.is_empty() else 1)
