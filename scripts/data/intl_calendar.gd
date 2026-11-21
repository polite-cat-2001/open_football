class_name IntlCalendar
extends RefCounted
# Pure rules for the international calendar: annual FIFA windows and
# multi-year tournaments, expanded on the fly. The rules are passed in, so the
# recurrence math is testable without the shipped asset.
#
# A rule: {kind, label, start_md, end_md, every_years, anchor_year, applies_to}
# `start_md > end_md` means the edition crosses New Year. An explicit edition
# uses `start`/`end` ISO dates instead of the recurring fields. `applies_to` is
# "world", a confederation code, or an array of them.

const PATH := "res://assets/data/intl_calendar.json"

static var _data: Dictionary = {}
static var _error := ""

static func load_all() -> Dictionary:
	if not _data.is_empty():
		return _data
	_error = ""
	if not FileAccess.file_exists(PATH):
		_error = "international calendar missing: " + PATH
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_error = "cannot open " + PATH
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_error = "international calendar is not a JSON object"
		return {}
	_data = parsed
	return _data


static func last_error() -> String:
	return _error


static func rules() -> Array:
	var value = load_all().get("rules", [])
	return value if value is Array else []


static func is_blocked(rules: Array, date: String, scope := "world") -> bool:
	if date.length() < 10:
		return false
	var year := int(date.substr(0, 4))
	var md := date.substr(5, 5)
	for rule in rules:
		if not (rule is Dictionary):
			continue
		if not _applies(rule, scope):
			continue
		if rule.get("pauses_club_football", true) == false:
			continue
		if rule.has("start") and rule.has("end"):
			if str(rule["start"]) <= date and date <= str(rule["end"]):
				return true
			continue
		if _matches(rule, year, md):
			return true
	return false


static func _applies(rule: Dictionary, scope: String) -> bool:
	var applies = rule.get("applies_to", "world")
	if applies is Array:
		return applies.has("world") or applies.has(scope)
	return str(applies) == "world" or str(applies) == scope


static func _matches(rule: Dictionary, year: int, md: String) -> bool:
	var start := str(rule.get("start_md", ""))
	var end := str(rule.get("end_md", ""))
	if start.length() != 5 or end.length() != 5:
		return false
	if start <= end:
		return _recurs(rule, year) and md >= start and md <= end
	# The edition starts late in `year` and ends in `year + 1`.
	return (_recurs(rule, year) and md >= start) \
		or (_recurs(rule, year - 1) and md <= end)


static func _recurs(rule: Dictionary, edition_year: int) -> bool:
	var every := int(rule.get("every_years", 1))
	if every <= 0:
		return false
	var anchor := int(rule.get("anchor_year", edition_year))
	var diff := edition_year - anchor
	return diff >= 0 and diff % every == 0
