extends SceneTree
# Manual audit: how dense is the career club's calendar in every playable league?
# Slow on purpose (one career per league, ~15 min); run it after a calendar change.
#
# Run:  godot --headless --path . -s res://tests/audit_calendars.gd [league_id ...]
# The optional ids print every tight pair with the competitions involved.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root():
		print("no catalog")
		quit(1)
		return
	var checked := 0
	var tight_leagues: Array = []
	var same_day_leagues: Array = []
	var only: Array = OS.get_cmdline_user_args()
	for league in catalog.career_leagues():
		var league_id := str(league.get("id", ""))
		if not only.is_empty() and not only.has(league_id):
			continue
		var teams: Array = catalog.all_teams_for_league(league_id)
		if teams.is_empty():
			continue
		var club_id := int(str((teams[0] as Dictionary).get("id", "0")))
		var career := CareerFactory.create(catalog, club_id, "Audit", 189, 31)
		if career == null:
			print("CREATE FAIL ", league_id, " ", CareerFactory.last_error)
			continue
		var rows: Array = []
		for fixture in career.schedule:
			if str(fixture.get("home", "")) != career.club_id \
					and str(fixture.get("away", "")) != career.club_id:
				continue
			rows.append({"date": str(fixture.get("date", "")),
				"competition": str(fixture.get("competition", league_id))})
		rows.sort_custom(func(a, b): return str(a["date"]) < str(b["date"]))
		var tight := 0
		var same_day := 0
		for index in range(1, rows.size()):
			var gap := absi(CareerSeason.days_between(str(rows[index]["date"]),
				str(rows[index - 1]["date"])))
			if gap == 0:
				same_day += 1
			elif gap < 3:
				tight += 1
			if gap < 3 and OS.get_cmdline_user_args().has(league_id):
				print("   ", league_id, " ", rows[index - 1]["date"], " ",
					rows[index - 1]["competition"], " -> ",
					rows[index]["date"], " ", rows[index]["competition"])
		checked += 1
		if same_day > 0:
			same_day_leagues.append([league_id, same_day])
		if tight > 0:
			tight_leagues.append([league_id, tight, rows.size()])
	print("checked ", checked, " leagues")
	print("same day twice: ", same_day_leagues.size(), same_day_leagues)
	print("inside three days: ", tight_leagues.size())
	for row in tight_leagues:
		print("  TIGHT ", row[0], " pairs ", row[1], " of ", row[2])
	quit(0)
