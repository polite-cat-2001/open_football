class_name IntlCalendar
extends RefCounted
# Pure rules for the international calendar: annual FIFA windows and
# multi-year tournaments, expanded on the fly. The rules are passed in, so the
# recurrence math is testable without the shipped asset.
#
# A rule: {kind, label, start_md, end_md, every_years, anchor_year, applies_to}
# `start_md > end_md` means the edition crosses New Year. `applies_to` is
# "world", a confederation code, or an array of them.

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
