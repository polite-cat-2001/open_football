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


static func stage_date(year: int, md: String, reference_md: String) -> String:
	if md.length() != 5:
		return ""
	var stage_year := year
	if not reference_md.is_empty() and md < reference_md:
		stage_year += 1
	return "%04d-%s" % [stage_year, md]
