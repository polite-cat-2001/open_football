class_name Career
extends RefCounted
# Career save object. It keeps the prototype's JSON shape (server/career/core.py
# Career.to_save/from_save) as its storage, so a prototype save loads without
# conversion and unknown fields survive a save round-trip.

const SAVE_VERSION := 1
const START_DATE := "2026-07-01"
const DEFAULT_FORMATION := "4-3-3"

static var last_error := ""

var data: Dictionary = {}


func _init(raw: Dictionary = {}) -> void:
	data = raw


var version: int:
	get:
		return int(data.get("version", SAVE_VERSION))

var id: String:
	get:
		return str(data.get("id", ""))

var seed: int:
	get:
		return int(data.get("seed", 0))

var date: String:
	get:
		return str(data.get("date", START_DATE))

var season_start: String:
	get:
		return str(data.get("season_start", START_DATE))

var created_at: String:
	get:
		return str(data.get("created_at", ""))

var updated_at: String:
	get:
		return str(data.get("updated_at", ""))

var club_id: String:
	get:
		return str(data.get("club_id", ""))

var league_id: String:
	get:
		return str(data.get("league_id", ""))

var player_ids: Array:
	get:
		return data.get("player_ids", [])

var league_club_ids: Array:
	get:
		return data.get("league_club_ids", [])

var schedule: Array:
	get:
		return data.get("schedule", [])

var schedule_version: int:
	get:
		return int(data.get("schedule_version", 0))

var results: Dictionary:
	get:
		return data.get("results", {})

var lineup: Array:
	get:
		return data.get("lineup", [])
	set(value):
		data["lineup"] = value

var bench_order: Array:
	get:
		return data.get("bench", [])
	set(value):
		data["bench"] = value

var formation: String:
	get:
		return str(data.get("formation", DEFAULT_FORMATION))
	set(value):
		data["formation"] = value

var role_assignments: Dictionary:
	get:
		var value = data.get("role_assignments", {})
		return value if value is Dictionary else {}
	set(value):
		data["role_assignments"] = value


var player_contracts: Dictionary:
	get:
		var value = data.get("player_contracts", {})
		return value if value is Dictionary else {}
	set(value):
		data["player_contracts"] = value


var player_values: Dictionary:
	get:
		var value = data.get("player_values", {})
		return value if value is Dictionary else {}
	set(value):
		data["player_values"] = value


var player_ages: Dictionary:
	get:
		var value = data.get("player_ages", {})
		return value if value is Dictionary else {}
	set(value):
		data["player_ages"] = value


var shirt_numbers: Dictionary:
	get:
		var value = data.get("shirt_numbers", {})
		return value if value is Dictionary else {}
	set(value):
		data["shirt_numbers"] = value


var player_transfers: Dictionary:
	get:
		var value = data.get("player_transfers", {})
		return value if value is Dictionary else {}
	set(value):
		data["player_transfers"] = value


var negotiations: Dictionary:
	# Contract-renewal talks with own players (server/career/squad.py).
	get:
		if not (data.get("negotiations") is Dictionary):
			data["negotiations"] = {}
		return data["negotiations"]
	set(value):
		data["negotiations"] = value


var transfer_offers: Array:
	get:
		if not (data.get("transfer_offers") is Array):
			data["transfer_offers"] = []
		return data["transfer_offers"]
	set(value):
		data["transfer_offers"] = value


var transfer_contracts: Dictionary:
	get:
		if not (data.get("transfer_contracts") is Dictionary):
			data["transfer_contracts"] = {}
		return data["transfer_contracts"]
	set(value):
		data["transfer_contracts"] = value


var pending_transfers: Array:
	get:
		if not (data.get("pending_transfers") is Array):
			data["pending_transfers"] = []
		return data["pending_transfers"]
	set(value):
		data["pending_transfers"] = value


var transfer_history: Array:
	get:
		if not (data.get("transfer_history") is Array):
			data["transfer_history"] = []
		return data["transfer_history"]
	set(value):
		data["transfer_history"] = value


var shortlist: Array:
	get:
		if not (data.get("shortlist") is Array):
			data["shortlist"] = []
		return data["shortlist"]
	set(value):
		data["shortlist"] = value


var pending_departures: Array:
	get:
		if not (data.get("pending_departures") is Array):
			data["pending_departures"] = []
		return data["pending_departures"]
	set(value):
		data["pending_departures"] = value


var incoming_offers: Array:
	get:
		if not (data.get("incoming_offers") is Array):
			data["incoming_offers"] = []
		return data["incoming_offers"]
	set(value):
		data["incoming_offers"] = value


var world_transfers: Array:
	get:
		if not (data.get("world_transfers") is Array):
			data["world_transfers"] = []
		return data["world_transfers"]
	set(value):
		data["world_transfers"] = value


var club_deltas: Dictionary:
	get:
		if not (data.get("club_deltas") is Dictionary):
			data["club_deltas"] = {}
		return data["club_deltas"]
	set(value):
		data["club_deltas"] = value


var incoming_market_date: String:
	get:
		return str(data.get("incoming_market_date", ""))
	set(value):
		data["incoming_market_date"] = value


var world_market_date: String:
	get:
		return str(data.get("world_market_date", ""))
	set(value):
		data["world_market_date"] = value


var balance:
	get:
		return data.get("balance")
	set(value):
		data["balance"] = value


var player_state: Dictionary:
	get:
		return data.get("player_state", {})
	set(value):
		data["player_state"] = value

var condition_date:
	get:
		return data.get("condition_date")
	set(value):
		data["condition_date"] = value

var journal: Array:
	get:
		return data.get("journal", [])

var manager: CareerManager:
	get:
		return CareerManager.from_save(data.get("manager", {}))
	set(value):
		data["manager"] = value.to_save()

var hub_tab: String:
	get:
		return str(data.get("hub_tab", "centre"))
	set(value):
		data["hub_tab"] = value


func touch() -> void:
	data["updated_at"] = utc_now()


func to_save() -> Dictionary:
	var payload := data.duplicate(true)
	payload["version"] = version
	payload["updated_at"] = updated_at
	if payload.has("manager"):
		payload["manager"] = manager.to_save()
	return payload


static func from_save(raw: Dictionary) -> Career:
	last_error = ""
	if not raw.has("version"):
		last_error = "Save version is missing; this build requires version %d." % SAVE_VERSION
		return null
	if _as_int(raw.get("version"), -1) != SAVE_VERSION:
		last_error = "Save version %s is not supported; this build requires version %d." % [
			str(raw.get("version")), SAVE_VERSION,
		]
		return null
	for key in ["id", "seed", "date", "created_at", "updated_at", "club_id", "player_ids"]:
		if not raw.has(key):
			last_error = "Save is malformed: missing %s." % key
			return null
	if not (raw.get("manager") is Dictionary):
		last_error = "Save is malformed: missing manager."
		return null

	var payload := raw.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["id"] = str(payload["id"])
	payload["seed"] = _as_int(payload["seed"], 0)
	payload["date"] = str(payload["date"])
	if not payload.has("season_start"):
		payload["season_start"] = START_DATE
	payload["season_start"] = str(payload["season_start"])
	payload["created_at"] = str(payload["created_at"])
	payload["updated_at"] = str(payload["updated_at"])
	payload["club_id"] = str(payload["club_id"])
	payload["player_ids"] = _string_array(payload["player_ids"])
	payload["journal"] = payload.get("journal", []) if payload.get("journal") is Array else []
	for entry in payload["journal"]:
		if entry is Dictionary and entry.get("seq") != null:
			entry["seq"] = _as_int(entry["seq"], 0)

	if payload.has("league_id") and payload["league_id"] != null:
		payload["league_id"] = str(payload["league_id"])
	if payload.has("league_club_ids") and payload["league_club_ids"] is Array:
		payload["league_club_ids"] = _string_array(payload["league_club_ids"])
	if payload.has("lineup") and payload["lineup"] is Array:
		payload["lineup"] = _string_array(payload["lineup"])
	if payload.has("bench") and payload["bench"] is Array:
		payload["bench"] = _string_array(payload["bench"])
	payload["formation"] = str(payload.get("formation", DEFAULT_FORMATION))
	payload["hub_tab"] = str(payload.get("hub_tab", "centre"))
	if payload.has("role_assignments") and payload["role_assignments"] is Dictionary:
		var roles := {}
		for role in payload["role_assignments"]:
			roles[str(role)] = str(payload["role_assignments"][role])
		payload["role_assignments"] = roles
	if payload.has("player_contracts") and payload["player_contracts"] is Dictionary:
		var contracts := {}
		for player_id in payload["player_contracts"]:
			var contract_raw = payload["player_contracts"][player_id]
			if not (contract_raw is Dictionary):
				continue
			contracts[str(player_id)] = {
				"years": _as_int(contract_raw.get("years"), 1),
				"weekly_wage": _as_int(contract_raw.get("weekly_wage"), 0),
				"squad_role": str(contract_raw.get("squad_role", "rotation")),
				"release_clause": _as_int(contract_raw.get("release_clause"), 0),
			}
		payload["player_contracts"] = contracts
	for field in ["player_values", "player_ages", "shirt_numbers"]:
		if payload.has(field) and payload[field] is Dictionary:
			var values := {}
			for player_id in payload[field]:
				values[str(player_id)] = _as_int(payload[field][player_id], 0)
			payload[field] = values
	if payload.has("player_transfers") and payload["player_transfers"] is Dictionary:
		var transfers := {}
		for player_id in payload["player_transfers"]:
			transfers[str(player_id)] = str(payload["player_transfers"][player_id])
		payload["player_transfers"] = transfers
	# Transfer state: the prototype's from_save drops every offer but the last
	# one per player and keeps the nested term dictionaries as dictionaries.
	# Keys an old save does not carry stay absent: the getters create them on
	# first write, so loading and re-saving such a career does not change it.
	for key in ["transfer_offers", "incoming_offers"]:
		if payload.has(key):
			payload[key] = _offer_list(payload[key])
	if payload.has("pending_departures"):
		payload["pending_departures"] = _dict_list(payload["pending_departures"])
	if payload.has("world_transfers"):
		payload["world_transfers"] = _dict_list(payload["world_transfers"])
	if payload.has("transfer_history"):
		payload["transfer_history"] = _history_list(payload["transfer_history"])
	if payload.has("pending_transfers"):
		payload["pending_transfers"] = _pending_list(payload["pending_transfers"])
	if payload.has("transfer_contracts"):
		payload["transfer_contracts"] = _contract_map(payload["transfer_contracts"])
	if payload.has("negotiations"):
		payload["negotiations"] = _negotiation_map(payload["negotiations"])
	if payload.has("shortlist"):
		payload["shortlist"] = _string_array(payload["shortlist"])
	if payload.has("club_deltas"):
		payload["club_deltas"] = _delta_map(payload["club_deltas"])
	for key in ["incoming_market_date", "world_market_date"]:
		if payload.has(key):
			payload[key] = "" if payload[key] == null else str(payload[key])
	if payload.has("balance") and payload["balance"] != null:
		payload["balance"] = _as_int(payload["balance"], 0)

	if payload.has("schedule") and payload["schedule"] is Array:
		var fixtures: Array = []
		for item in payload["schedule"]:
			if not (item is Dictionary):
				continue
			var fixture := {
				"id": str(item.get("id", "")),
				"round": _as_int(item.get("round"), 0),
				"date": str(item.get("date", "")),
				"home": str(item.get("home", "")),
				"away": str(item.get("away", "")),
			}
			if item.has("stage_round"):
				fixture["stage_round"] = _as_int(item.get("stage_round"), 0)
			if item.has("stage"):
				fixture["stage"] = str(item.get("stage", ""))
			if item.has("competition"):
				fixture["competition"] = str(item.get("competition", ""))
			if item.has("group"):
				fixture["group"] = _as_int(item.get("group"), -1)
			if item.has("tie"):
				fixture["tie"] = str(item.get("tie", ""))
			if item.has("leg"):
				fixture["leg"] = _as_int(item.get("leg"), 0)
			fixtures.append(fixture)
		payload["schedule"] = fixtures
		payload["schedule_version"] = _as_int(payload.get("schedule_version"), 0)

	if payload.has("seasons_completed"):
		payload["seasons_completed"] = _as_int(payload["seasons_completed"], 0)

	if payload.has("competitions") and payload["competitions"] is Array:
		var competitions: Array = []
		for item in payload["competitions"]:
			if not (item is Dictionary):
				continue
			var entry: Dictionary = item.duplicate(true)
			entry["id"] = str(entry.get("id", ""))
			entry["kind"] = str(entry.get("kind", ""))
			entry["label"] = str(entry.get("label", ""))
			if entry.has("country"):
				entry["country"] = str(entry.get("country", ""))
			if entry.has("entrants"):
				entry["entrants"] = _string_array(entry.get("entrants"))
			if entry.has("dates"):
				entry["dates"] = _string_array(entry.get("dates"))
			if entry.get("rounds") is Array:
				for spec in entry["rounds"]:
					if spec is Dictionary:
						spec["name"] = str(spec.get("name", ""))
						spec["legs"] = _as_int(spec.get("legs"), 1)
			if entry.get("winner") != null:
				entry["winner"] = str(entry["winner"])
			competitions.append(entry)
		payload["competitions"] = competitions

	if payload.has("world_seasons") and payload["world_seasons"] is Dictionary:
		var worlds := {}
		for season in payload["world_seasons"]:
			var tables = payload["world_seasons"][season]
			if not (tables is Dictionary):
				continue
			var league_tables := {}
			for league_id in tables:
				var rows: Array = []
				for row in tables[league_id]:
					if not (row is Dictionary):
						continue
					rows.append({
						"club_id": str(row.get("club_id", "")),
						"position": _as_int(row.get("position"), 0),
						"points": _as_int(row.get("points"), 0),
						"played": _as_int(row.get("played"), 0),
					})
				league_tables[str(league_id)] = rows
			worlds[str(season)] = league_tables
		payload["world_seasons"] = worlds

	if payload.has("berths") and payload["berths"] is Dictionary:
		var berths := {}
		for season in payload["berths"]:
			var block = payload["berths"][season]
			if not (block is Dictionary):
				continue
			var by_country := {}
			if block.has("association"):
				by_country[str(block.get("association", ""))] = _berth_block(block)
			else:
				for name in block:
					by_country[str(name)] = _berth_block(block[name])
			berths[str(season)] = by_country
		payload["berths"] = berths

	if payload.has("results") and payload["results"] is Dictionary:
		var normalized := {}
		for fixture_id in payload["results"]:
			var score = payload["results"][fixture_id]
			if score is Dictionary:
				var result := {
					"home": _as_int(score.get("home"), 0),
					"away": _as_int(score.get("away"), 0),
				}
				if score.get("pens") is Dictionary:
					result["pens"] = {
						"home": _as_int(score["pens"].get("home"), 0),
						"away": _as_int(score["pens"].get("away"), 0),
					}
				if score.get("et") is Dictionary:
					result["et"] = {
						"home": _as_int(score["et"].get("home"), 0),
						"away": _as_int(score["et"].get("away"), 0),
					}
				if score.has("decided_by"):
					result["decided_by"] = str(score.get("decided_by", ""))
				normalized[str(fixture_id)] = result
		payload["results"] = normalized

	return Career.new(payload)


static func utc_now() -> String:
	var unix := Time.get_unix_time_from_system()
	var seconds := int(unix)
	var micros := int(round((unix - float(seconds)) * 1000000.0))
	if micros >= 1000000:
		seconds += 1
		micros -= 1000000
	return Time.get_datetime_string_from_unix_time(seconds, false) + ".%06dZ" % micros


static func random_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	var hex := ""
	for byte in bytes:
		hex += "%02x" % int(byte)
	return hex


static func random_seed() -> int:
	var bytes := Crypto.new().generate_random_bytes(4)
	return int(bytes.decode_u32(0))


static func _string_array(value) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


static func _dict_list(value) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				out.append(item.duplicate(true))
	return out


static func _offer_list(value) -> Array:
	# Python's from_save walks the offers backwards and keeps the first offer it
	# meets per player, so a save with several offers for one player keeps the
	# newest one and the original order of the rest.
	var kept: Array = []
	var seen := {}
	if value is Array:
		for index in range((value as Array).size() - 1, -1, -1):
			var item = value[index]
			if not (item is Dictionary):
				continue
			var player_id := str(item.get("player_id", ""))
			if seen.has(player_id):
				continue
			seen[player_id] = true
			var offer: Dictionary = item.duplicate(true)
			offer["counter"] = _term_dict(offer.get("counter"))
			offer["demand"] = _term_dict(offer.get("demand"))
			_int_fields(offer, ["amount", "loan_fee", "wage_share", "counter_offers"])
			kept.push_front(offer)
	return kept


static func _pending_list(value) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			if not (item is Dictionary):
				continue
			var copy: Dictionary = item.duplicate(true)
			copy["terms"] = _term_dict(copy.get("terms"))
			_int_fields(copy, ["fee", "loan_fee", "wage_share", "market_value", "age"])
			out.append(copy)
	return out


static func _contract_map(value) -> Dictionary:
	var out := {}
	if value is Dictionary:
		for player_id in value:
			var state = value[player_id]
			if not (state is Dictionary):
				continue
			var copy: Dictionary = state.duplicate(true)
			for key in ["demand", "offer", "counter", "agreed"]:
				copy[key] = _term_dict(copy.get(key))
			_int_fields(copy, ["fee", "loan_fee", "wage_share", "counter_offers",
				"rounds", "value"])
			out[str(player_id)] = copy
	return out


static func _negotiation_map(value) -> Dictionary:
	# Renewal talks keep only the keys the prototype writes; terms come back
	# from JSON as floats and are cast back to the prototype's integers.
	var out := {}
	if value is Dictionary:
		for player_id in value:
			var state = value[player_id]
			if not (state is Dictionary):
				continue
			var copy: Dictionary = state.duplicate(true)
			for key in ["demand", "offer", "counter"]:
				if copy.has(key):
					copy[key] = _term_dict(copy.get(key))
			_int_fields(copy, ["counter_offers", "rounds"])
			out[str(player_id)] = copy
	return out


static func _berth_block(value) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var copy: Dictionary = (value as Dictionary).duplicate(true)
	copy["association"] = str(copy.get("association", ""))
	copy["rank"] = _as_int(copy.get("rank"), 0)
	copy["eps"] = bool(copy.get("eps", false))
	var entries: Array = []
	for entry in copy.get("berths", []):
		if not (entry is Dictionary):
			continue
		entries.append({
			"competition": str(entry.get("competition", "")),
			"entry": str(entry.get("entry", "")),
			"path": str(entry.get("path", "")),
			"club_id": str(entry.get("club_id", "")),
			"source": str(entry.get("source", "")),
		})
	copy["berths"] = entries
	return copy


static func _delta_map(value) -> Dictionary:
	var out := {}
	if value is Dictionary:
		for club_id in value:
			var delta = value[club_id]
			if not (delta is Dictionary):
				continue
			out[str(club_id)] = {
				"in": _string_array(delta.get("in")),
				"out": _string_array(delta.get("out")),
			}
	return out


static func _history_list(value) -> Array:
	var out := _dict_list(value)
	for record in out:
		_int_fields(record, ["fee"])
		if record.get("overall") != null:
			record["overall"] = float(record["overall"])
	return out


static func _int_fields(target: Dictionary, keys: Array) -> void:
	for key in keys:
		var value = target.get(key)
		if value == null:
			continue
		target[key] = _as_int(value, 0)


static func _term_dict(value):
	# Contract/offer terms are integers in the prototype; JSON hands them back
	# as floats, so a re-save would otherwise change every amount's type.
	if not (value is Dictionary):
		return null
	var copy: Dictionary = value.duplicate(true)
	for key in copy:
		if copy[key] is float and is_equal_approx(float(copy[key]),
				roundf(float(copy[key]))):
			copy[key] = int(copy[key])
	return copy


static func _dict_or_null(value):
	return value.duplicate(true) if value is Dictionary else null


static func _as_int(value, fallback: int) -> int:
	if value == null:
		return fallback
	if value is int or value is float or value is bool:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)
	return fallback
