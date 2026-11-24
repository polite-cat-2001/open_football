class_name CareerCalendar
extends RefCounted
# One date allocator for every stage. The stage window comes from the data;
# this module chooses the match days inside it, skipping international blackouts
# and dates already taken by another competition of the same club.

static func round_dates(start_date: String, end_date: String, rounds: int,
		rules: Array = [], scope := "world", busy: Dictionary = {}) -> Array:
	if rounds <= 0 or start_date.is_empty():
		return []
	if end_date.is_empty():
		var weekly: Array = []
		for index in range(rounds):
			weekly.append(CareerSeason.add_days(start_date, 7 * (index + 1)))
		return weekly
	var span := CareerSeason.days_between(start_date, end_date)
	if span < 0:
		return []
	var free: Array = []
	for offset in range(span + 1):
		var date := CareerSeason.add_days(start_date, offset)
		if busy.has(date):
			continue
		if not rules.is_empty() and IntlCalendar.is_blocked(rules, date, scope):
			continue
		free.append(date)
	var dates: Array = []
	if free.size() >= rounds:
		for index in range(rounds):
			var position := 0
			if rounds > 1:
				position = int(round(float(index) * float(free.size() - 1)
					/ float(rounds - 1)))
			dates.append(free[position])
		return dates
	# Not enough free days: keep the old even spread rather than dropping rounds.
	for index in range(rounds):
		var offset := 0
		if rounds > 1:
			offset = int(round(float(index) * float(span) / float(rounds - 1)))
		dates.append(CareerSeason.add_days(start_date, offset))
	return dates


static var last_compressed: Array = []


static func joint_plan(requests: Array, rules: Array = [], scope := "world",
		rest := 3) -> Dictionary:
	# Every competition of the club is planned together. Higher priority picks
	# its ideal days first; the rest shift to the nearest free day inside their
	# window, keeping `rest` days from every match already placed. The league is
	# the backbone; a cup therefore lands in the midweek gaps.
	var ordered := requests.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		return str(a.get("id", "")) < str(b.get("id", "")))
	last_compressed = []
	var reserved: Array = []
	var used := {}
	var plan := {}
	for request in ordered:
		var ideal := round_dates(str(request.get("start", "")),
			str(request.get("end", "")), int(request.get("days", 0)), rules, scope)
		var dates: Array = []
		for date in ideal:
			var slot := _free_slot(str(date), request, used, reserved, rest)
			dates.append(slot)
			used[slot] = true
			reserved.append(slot)
		plan[str(request.get("id", ""))] = dates
	return plan


static func _free_slot(ideal: String, request: Dictionary, used: Dictionary,
		reserved: Array, rest: int) -> String:
	for step in range(0, 29):
		for offset in ([0] if step == 0 else [step, -step]):
			var candidate := CareerSeason.add_days(ideal, offset)
			if candidate < str(request.get("start", "")) \
					or candidate > str(request.get("end", "")):
				continue
			if used.has(candidate):
				continue
			var ok := true
			for other in reserved:
				if absi(CareerSeason.days_between(candidate, str(other))) < rest:
					ok = false
					break
			if ok:
				return candidate
	# The window has no free day left: priority wins, so the fixture keeps its
	# ideal day and the clash is reported instead of hidden.
	last_compressed.append({
		"id": str(request.get("id", "")),
		"date": ideal,
		"priority": int(request.get("priority", 0)),
	})
	return ideal


static func stage_date(year: int, md: String, reference_md: String) -> String:
	if md.length() != 5:
		return ""
	var stage_year := year
	if not reference_md.is_empty() and md < reference_md:
		stage_year += 1
	return "%04d-%s" % [stage_year, md]
