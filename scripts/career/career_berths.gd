class_name CareerBerths
extends RefCounted
# Continental berths from the confederation access lists. UEFA uses its
# coefficient bands and EPS; the other confederations use their fixed or ranked
# slot lists. A slot names a league position or a domestic cup; a club that is
# already qualified does not lose the berth, the next league club takes it.
# Unsupported split-specific slots (Apertura/Clausura champions) fall back to
# the season table, which is the aggregate the background season stores.

const ACCESS_PATH := "res://assets/data/confederations.json"

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
		cups_by_label: Dictionary = {}, rank_override := -1,
		eps_override = null) -> Dictionary:
	var data := access()
	if data.is_empty():
		return {}
	var uefa = data.get("uefa", {})
	if uefa is Dictionary and (rank_override > 0 or _rank_of(uefa, country) > 0):
		return _uefa_for_country(uefa, country, rows, cups_by_label,
			rank_override, eps_override)
	return _slots_for_country(data, country, rows, cups_by_label)


static func _uefa_for_country(data: Dictionary, country: String, rows: Array,
		cups_by_label: Dictionary, rank_override := -1,
		eps_override = null) -> Dictionary:
	var rank := rank_override if rank_override > 0 else _rank_of(data, country)
	var band := _band_for(data, rank)
	if band.is_empty():
		return {}
	var eps := bool(eps_override) if eps_override != null \
		else (data.get("eps", []) as Array).has(country)
	var cup_slot := _cup_slot(data, country)
	var main_cup := str(cup_slot.get("main_cup", ""))
	if main_cup.is_empty():
		main_cup = _main_cup_label(cups_by_label)
	var positions := _positions(rows)
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
		_add_club_or_next(berths, "uel", slot, _cup_winner(cups_by_label, main_cup),
			positions, assigned, "cup")
	var uecl_cup: Dictionary = {}
	for slot in band.get("uecl", []):
		if str(slot.get("slot", "")) == "cup_winner":
			uecl_cup = slot
	if not uecl_cup.is_empty():
		_add_club_or_next(berths, "uecl", uecl_cup,
			_cup_winner(cups_by_label, main_cup), positions, assigned, "cup")
	var uecl_slots: Array = []
	for slot in band.get("uecl", []):
		if _slot_index(str(slot.get("slot", ""))) > 0:
			uecl_slots.append(slot)
	if not uecl_slots.is_empty():
		var second := _cup_winner(cups_by_label,
			str(cup_slot.get("second_cup", "")))
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


static func _slots_for_country(data: Dictionary, country: String, rows: Array,
		cups_by_label: Dictionary) -> Dictionary:
	var confederation: Dictionary = {}
	var slot_entry: Dictionary = {}
	for key in data:
		if str(key) == "uefa":
			continue
		var conf = data[key]
		if not (conf is Dictionary):
			continue
		for slot in conf.get("slots", []):
			if str((slot as Dictionary).get("country", "")) == country:
				confederation = conf
				slot_entry = slot
				break
		if not slot_entry.is_empty():
			break
	if slot_entry.is_empty():
		return {}
	var positions := _positions(rows)
	var assigned := {}
	var berths: Array = []
	var main_cup := _main_cup_label(cups_by_label)
	for competition in slot_entry:
		if str(competition) in ["country", "note"]:
			continue
		var slots = slot_entry[competition]
		if not (slots is Array):
			continue
		for slot in slots:
			var resolved := _resolve_slot(str((slot as Dictionary).get("slot", "")),
				positions, assigned, cups_by_label, main_cup)
			var club_id := str(resolved.get("club", ""))
			if club_id.is_empty() or assigned.has(club_id):
				continue
			assigned[club_id] = true
			berths.append({
				"competition": str(competition),
				"entry": str((slot as Dictionary).get("entry", "group_stage")),
				"path": str((slot as Dictionary).get("path", "")),
				"club_id": club_id,
				"source": str(resolved.get("source", "league")),
			})
	return {
		"association": country, "rank": 0, "eps": false,
		"confederation": str(confederation.get("id", "")),
		"berths": berths,
	}


static func _resolve_slot(slot: String, positions: Array, assigned: Dictionary,
		cups_by_label: Dictionary, main_cup: String) -> Dictionary:
	if slot == "cup_winner":
		return {"club": _cup_winner(cups_by_label, main_cup), "source": "cup"}
	if slot == "cup_runner_up":
		return {"club": _cup_runner(cups_by_label, main_cup), "source": "cup"}
	var index := 0
	if slot == "national_league_champion" or slot == "champion" \
			or slot.begins_with("apertura_"):
		index = 1
	elif slot.begins_with("clausura_"):
		index = 2
	elif slot.begins_with("liga_mx_"):
		index = _mx_index(slot)
	elif slot.begins_with("league_") or slot.begins_with("aggregate_"):
		index = _slot_index(slot)
	if index <= 0:
		return {}
	var start := index - 1
	if slot.contains("not_qualified"):
		return {"club": _next_from(positions, assigned, start), "source": "league"}
	var club_id := ""
	if start < positions.size():
		club_id = str(positions[start])
	if club_id.is_empty() or assigned.has(club_id):
		club_id = _next_from(positions, assigned, index)
	return {"club": club_id, "source": "league"}


static func _mx_index(slot: String) -> int:
	match slot:
		"liga_mx_champion_higher_aggregate":
			return 1
		"liga_mx_other_champion", "liga_mx_runner_up":
			return 2
		"liga_mx_runner_up_other_tournament":
			return 3
		"liga_mx_aggregate_next_1":
			return 4
		"liga_mx_aggregate_next_2":
			return 5
	return 0


static func _add_position(berths: Array, competition: String, slot: Dictionary,
		index: int, positions: Array, assigned: Dictionary) -> void:
	var club_id := ""
	if index >= 1 and index <= positions.size():
		club_id = str(positions[index - 1])
	if club_id.is_empty() or assigned.has(club_id):
		club_id = _next_from(positions, assigned, index - 1)
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
		club_id = _next_from(positions, assigned, 0)
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


static func _next_from(positions: Array, assigned: Dictionary, start: int) -> String:
	for index in range(maxi(0, start), positions.size()):
		var club_id := str(positions[index])
		if not assigned.has(club_id):
			return club_id
	for index in range(0, mini(maxi(0, start), positions.size())):
		var club_id := str(positions[index])
		if not assigned.has(club_id):
			return club_id
	return ""


static func _positions(rows: Array) -> Array:
	var positions: Array = []
	for row in rows:
		positions.append(str((row as Dictionary).get("club_id", row.get("id", ""))))
	return positions


static func _cup_winner(cups_by_label: Dictionary, label: String) -> String:
	if label.is_empty():
		return ""
	var value = cups_by_label.get(label, "")
	if value is Dictionary:
		return str(value.get("winner", ""))
	return str(value)


static func _cup_runner(cups_by_label: Dictionary, label: String) -> String:
	if label.is_empty():
		return ""
	var value = cups_by_label.get(label, {})
	if value is Dictionary:
		return str(value.get("runner_up", ""))
	return ""


static func _main_cup_label(cups_by_label: Dictionary) -> String:
	for label in cups_by_label:
		return str(label)
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
	var started := false
	for index in range(slot.length()):
		var ch := slot[index]
		if ch.is_valid_int():
			digits += ch
			started = true
		elif started:
			break
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
