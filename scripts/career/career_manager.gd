class_name CareerManager
extends RefCounted
# Manager identity for a career save. Mirrors server/career/core.py's Manager.

var name := ""
var nationality_id := ""
var nationality := ""


func _init(manager_name := "", manager_nationality_id := "", manager_nationality := "") -> void:
	name = manager_name
	nationality_id = manager_nationality_id
	nationality = manager_nationality


func to_save() -> Dictionary:
	return {
		"name": name,
		"nationality_id": nationality_id,
		"nationality": nationality,
	}


static func from_save(raw: Dictionary) -> CareerManager:
	return CareerManager.new(
		str(raw.get("name", "")),
		str(raw.get("nationality_id", "")),
		str(raw.get("nationality", "")),
	)
