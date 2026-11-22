class_name CareerBerths
extends RefCounted
# UEFA berths from the association access list. The league table supplies the
# position slots; the domestic cups supply the cup slots. EPS adds a Champions
# League place and slides the lower slots down. A cup winner who is already
# qualified does not lose the berth: the next league club takes it, as UEFA's
# cascade does. England's second cup is an alternative route to the Conference
# League place, not an extra berth.

const ACCESS_PATH := "res://assets/data/uefa_access.json"

static var _access: Dictionary = {}


static func access() -> Dictionary:
	if _access.is_empty():
		if not FileAccess.file_exists(ACCESS_PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(ACCESS_PATH))
		if raw is Dictionary:
			_access = raw
	return _access


static func for_country(country: String, rows: Array,
		cups_by_label: Dictionary = {}) -> Dictionary:
	var data := access()
	if data.is_empty():
		return {}
	var rank := _rank_of(data, country)
	if rank <= 0:
		return {}
	var band := _band_for(data, rank)
	if band.is_empty():
		return {}
	var eps := (data.get("eps", []) as Array).has(country)
	var cup_slot := _cup_slot(data, country)
	var main_cup := str(cup_slot.get("main_cup", ""))
	if main_cup.is_empty():
		for label in cups_by_label:
			main_cup = str(label)
			break
	var positions: Array = []
	for row in rows:
		positions.append(str((row as Dictionary).get("club_id", row.get("id", ""))))
	var assigned := {}
	var berths: Array = []
	for slot in band.get("ucl", []):
		var index := _slot_index(str(slot.get("slot", "")))
		if index > 0:
			_add_position(berths, "ucl", slot, index, positions, assigned)
	if eps:
		var extra := 0
		for slot in band.get("ucl", []):
			extra = maxi(extra, _slot_index(str(slot.get("slot", ""))))
		_add_position(berths, "ucl",
			{"entry": "league_phase", "path": null}, extra + 1, positions, assigned)
	var shift := 1 if eps else 0
	for slot in band.get("uel", []):
		var index := _slot_index(str(slot.get("slot", "")))
		if index > 0:
			_add_position(berths, "uel", slot, index + shift, positions, assigned)
	for slot in band.get("uel", []):
		if str(slot.get("slot", "")) != "cup_winner":
			continue
		var winner := str(cups_by_label.get(main_cup, ""))
		_add_club_or_next(berths, "uel", slot, winner, positions, assigned, "cup")
	var uecl_cup: Dictionary = {}
	for slot in band.get("uecl", []):
		if str(slot.get("slot", "")) == "cup_winner":
			uecl_cup = slot
	if not uecl_cup.is_empty():
		var winner := str(cups_by_label.get(main_cup, ""))
		_add_club_or_next(berths, "uecl", uecl_cup, winner, positions, assigned,
			"cup")
	var uecl_slots: Array = []
	for slot in band.get("uecl", []):
		if _slot_index(str(slot.get("slot", ""))) > 0:
			uecl_slots.append(slot)
	if not uecl_slots.is_empty():
		var second := str(cups_by_label.get(str(cup_slot.get("second_cup", "")), ""))
		var used_second := false
		if not second.is_empty() and not assigned.has(second) and uecl_cup.is_empty():
			assigned[second] = true
			used_second = true
			berths.append({
				"competition": "uecl",
				"entry": _round_of(str(cup_slot.get("second_entry", "uecl_playoff_round")), "uecl"),
				"path": str(cup_slot.get("second_path", "league")),
				"club_id": second, "source": "second_cup",
			})
		for slot_index in range(uecl_slots.size()):
			if slot_index == 0 and used_second:
				continue
			var slot: Dictionary = uecl_slots[slot_index]
			var slot_position := _slot_index(str(slot.get("slot", ""))) + shift
			_add_position(berths, "uecl", slot, slot_position, positions, assigned)
	return {
		"association": country, "rank": rank, "eps": eps,
		"berths": berths,
	}


static func _add_position(berths: Array, competition: String, slot: Dictionary,
		index: int, positions: Array, assigned: Dictionary) -> void:
	var club_id := ""
	if index >= 1 and index <= positions.size():
		club_id = str(positions[index - 1])
	if club_id.is_empty() or assigned.has(club_id):
		club_id = _next_unassigned(positions, assigned)
	if club_id.is_empty():
		return
	assigned[club_id] = true
	berths.append({
		"competition": competition,
		"entry": str(slot.get("entry", "league_phase")),
		"path": str(slot.get("path", "")) if slot.get("path") != null else "",
		"club_id": club_id, "source": "league",
	})


static func _add_club_or_next(berths: Array, competition: String,
		slot: Dictionary, club_id: String, positions: Array,
		assigned: Dictionary, source: String) -> void:
	if club_id.is_empty() or assigned.has(club_id):
		club_id = _next_unassigned(positions, assigned)
	if club_id.is_empty():
		return
	assigned[club_id] = true
	berths.append({
		"competition": competition,
		"entry": _round_of(str(slot.get("entry", competition + "_league_phase")),
			competition),
		"path": str(slot.get("path", "")),
		"club_id": club_id, "source": source,
	})


static func _next_unassigned(positions: Array, assigned: Dictionary) -> String:
	for club_id in positions:
		if not assigned.has(str(club_id)):
			return str(club_id)
	return ""


static func _round_of(entry: String, competition: String) -> String:
	var prefix := competition + "_"
	if entry.begins_with(prefix):
		return entry.substr(prefix.length())
	return entry


static func _slot_index(slot: String) -> int:
	if slot == "champion":
		return 1
	var digits := ""
	for index in range(slot.length()):
		var ch := slot[index]
		if not ch.is_valid_int():
			break
		digits += ch
	return digits.to_int()


static func _rank_of(data: Dictionary, country: String) -> int:
	for row in data.get("coefficients", []):
		if str((row as Dictionary).get("association", "")) == country:
			return int(row.get("rank", 0))
	return 0


static func _band_for(data: Dictionary, rank: int) -> Dictionary:
	for band in data.get("bands", []):
		if rank >= int(band.get("rank_from", 0)) \
				and rank <= int(band.get("rank_to", 0)):
			return band
	return {}


static func _cup_slot(data: Dictionary, country: String) -> Dictionary:
	for row in data.get("cup_slots", []):
		if str((row as Dictionary).get("association", "")) == country:
			return row
	return {}
