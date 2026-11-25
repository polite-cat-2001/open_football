extends SceneTree
# Regenerates the advance-tick golden from the current database.
#
# The offer part of the golden depends on the whole club pool, so it goes stale
# with every league import; this script rebuilds it from the same inputs.
#
# Run:  godot --headless --path . -s res://tests/_regen_advance_tick.gd

const GOLDEN := "res://tests/fixtures/career_advance_tick_golden.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root():
		push_error("no catalog")
		quit(1)
		return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	if not (golden is Dictionary):
		push_error("golden is unreadable")
		quit(1)
		return
	var header: Dictionary = golden["career"]
	var career := CareerFactory.create(catalog, int(header["club_id"]),
		str(header["manager_name"]), int(header["manager_nationality_id"]),
		int(header["seed"]))
	if career == null:
		push_error("career: " + CareerFactory.last_error)
		quit(1)
		return
	career.data["created_at"] = str(header["created_at"])
	career.data["date"] = "2026-07-02"
	career.incoming_market_date = "2026-07-02"
	career.world_market_date = "2026-07-02"

	var tick_date := str(golden["tick_date"])
	var ticked := CareerAdvance.tick(career, catalog, tick_date)
	var offers: Array = []
	for offer in career.incoming_offers:
		offers.append({
			"offer_id": str((offer as Dictionary).get("id", "")),
			"player_id": str((offer as Dictionary).get("player_id", "")),
			"club_id": str((offer as Dictionary).get("club_id", "")),
			"amount": int((offer as Dictionary).get("amount", 0)),
			"created_at": str((offer as Dictionary).get("created_at", "")),
		})
	var event_types: Array = []
	for event in ticked.get("events", []):
		event_types.append(str((event as Dictionary).get("type", "")))
	var first := {
		"career": header,
		"tick_date": tick_date,
		"events": event_types,
		"incoming_market_date": str(career.incoming_market_date),
		"world_market_date": str(career.world_market_date),
		"offers": offers,
		"world_transfers": career.world_transfers.size(),
	}
	CareerAdvance.tick(career, catalog, tick_date)
	first["repeat"] = {
		"offers": career.incoming_offers.size(),
		"world_transfers": career.world_transfers.size(),
	}
	CareerAdvance.tick(career, catalog, "2026-08-01")
	first["next_window"] = {
		"offers": career.incoming_offers.size(),
		"world_transfers": career.world_transfers.size(),
		"world_market_date": str(career.world_market_date),
	}
	var file := FileAccess.open(GOLDEN, FileAccess.WRITE)
	file.store_string(JSON.stringify(first, "  ", false) + "\n")
	file.close()
	print("golden regenerated: ", offers.size(), " offers, ",
		first["world_transfers"], " world transfers")
	quit(0)
