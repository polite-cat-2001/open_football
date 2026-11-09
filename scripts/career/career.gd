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

var journal: Array:
	get:
		return data.get("journal", [])

var manager: CareerManager:
	get:
		return CareerManager.from_save(data.get("manager", {}))
	set(value):
		data["manager"] = value.to_save()


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

	if payload.has("league_id") and payload["league_id"] != null:
		payload["league_id"] = str(payload["league_id"])
	if payload.has("league_club_ids") and payload["league_club_ids"] is Array:
		payload["league_club_ids"] = _string_array(payload["league_club_ids"])
	if payload.has("lineup") and payload["lineup"] is Array:
		payload["lineup"] = _string_array(payload["lineup"])
	if payload.has("bench") and payload["bench"] is Array:
		payload["bench"] = _string_array(payload["bench"])
	payload["formation"] = str(payload.get("formation", DEFAULT_FORMATION))

	if payload.has("schedule") and payload["schedule"] is Array:
		var fixtures: Array = []
		for item in payload["schedule"]:
			if not (item is Dictionary):
				continue
			fixtures.append({
				"id": str(item.get("id", "")),
				"round": _as_int(item.get("round"), 0),
				"date": str(item.get("date", "")),
				"home": str(item.get("home", "")),
				"away": str(item.get("away", "")),
			})
		payload["schedule"] = fixtures
		payload["schedule_version"] = _as_int(payload.get("schedule_version"), 0)

	if payload.has("results") and payload["results"] is Dictionary:
		var normalized := {}
		for fixture_id in payload["results"]:
			var score = payload["results"][fixture_id]
			if score is Dictionary:
				normalized[str(fixture_id)] = {
					"home": _as_int(score.get("home"), 0),
					"away": _as_int(score.get("away"), 0),
				}
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


static func _as_int(value, fallback: int) -> int:
	if value == null:
		return fallback
	if value is int or value is float or value is bool:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)
	return fallback
