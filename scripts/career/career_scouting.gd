class_name CareerScouting
extends RefCounted
# Scouting: the scout pool, hiring, player reports, region networks and the
# dated progress tick, ported from server/career/scouting.py plus the app's
# scouting snapshot and `scout_*` actions (server/app.py).
#
# The save holds exactly the prototype's keys (scouts, scout_assignments,
# scout_tasks, scout_reports, scout_found, scout_networks) as plain data, so a
# prototype career loads as-is and an old career without them lazily grows the
# two starting scouts on the first call.

const MAX_SCOUTS := 6
const INITIAL_SCOUTS := 2
const CANDIDATES_SHOWN := 5
const POOL_SIZE := 12
const FOUND_CAP := 20
const ROLE_GROUPS := ["", "GK", "DEF", "MID", "FWD"]
const AGE_MIN := 16
const AGE_MAX := 35
const CONTRACT_MIN := 0
const CONTRACT_MAX := 5

const REGION_SPECS := [
	{
		"id": "british-isles", "name": "British Isles", "x": 45, "y": 25,
		"countries": ["England", "Scotland", "Wales", "Northern Ireland", "Ireland"],
	},
	{
		"id": "north-europe", "name": "Northern Europe", "x": 53, "y": 18,
		"countries": ["Norway", "Sweden", "Denmark", "Finland", "Iceland",
			"Faroe Islands"],
	},
	{
		"id": "west-europe", "name": "Western Europe", "x": 48, "y": 34,
		"countries": ["France", "Germany", "Netherlands", "Belgium", "Austria",
			"Switzerland", "Luxembourg"],
	},
	{
		"id": "south-europe", "name": "Southern Europe", "x": 53, "y": 42,
		"countries": ["Spain", "Italy", "Portugal", "Türkiye", "Greece", "Croatia",
			"Serbia", "Albania", "North Macedonia", "Montenegro", "Kosovo",
			"Slovenia", "Malta", "Cyprus", "San Marino", "Andorra", "Gibraltar"],
	},
	{
		"id": "east-europe", "name": "Eastern Europe", "x": 62, "y": 29,
		"countries": ["Russia", "Ukraine", "Belarus", "Poland", "Czech Republic",
			"Slovakia", "Hungary", "Romania", "Bulgaria", "Moldova", "Estonia",
			"Latvia", "Lithuania", "Armenia", "Azerbaijan", "Georgia", "Kazakhstan"],
	},
	{
		"id": "north-america", "name": "North America", "x": 19, "y": 33,
		"countries": ["United States", "Canada", "Costa Rica", "Panama", "Nicaragua",
			"Puerto Rico", "Jamaica"],
	},
	{
		"id": "latin-america", "name": "Latin America", "x": 27, "y": 66,
		"countries": ["Brazil", "Argentina", "Uruguay", "Chile", "Colombia", "Peru",
			"Ecuador", "Paraguay", "Bolivia", "Venezuela", "Mexico"],
	},
	{
		"id": "africa", "name": "Africa", "x": 52, "y": 62,
		"countries": ["Egypt", "Algeria", "Morocco", "Tunisia", "Senegal", "Nigeria",
			"Ghana", "South Africa", "Ethiopia", "Libya", "Uganda"],
	},
	{
		"id": "asia-pacific", "name": "Asia and Oceania", "x": 78, "y": 47,
		"countries": ["Japan", "China", "Chinese Taipei", "Hongkong", "India",
			"Indonesia", "Iran", "Iraq", "Israel", "Jordan", "Lebanon", "Malaysia",
			"Myanmar", "Oman", "Philippines", "Qatar", "Saudi Arabia", "Singapore",
			"Thailand", "United Arab Emirates", "Uzbekistan", "Vietnam", "Australia",
			"New Zealand", "Cambodia"],
	},
]

const SCOUT_POOL := [
	["Brian Smith", "Canada"],
	["Daniel Perez", "Spain"],
	["Donald Wood", "United States"],
	["Frank Cooper", "Canada"],
	["Yago Acuña", "Mexico"],
	["Juan Guerra", "Spain"],
	["Telmo Jurado", "Spain"],
	["Antonio Rizzo", "Italy"],
	["Andre Domingues", "Portugal"],
	["Celik Asker", "Türkiye"],
	["Marek Nowak", "Poland"],
	["Lukas Berg", "Sweden"],
	["Nils Hansen", "Norway"],
	["Marco Bianchi", "Italy"],
	["Hugo Laurent", "France"],
	["Kai Fischer", "Germany"],
	["Owen Price", "England"],
	["Callum Reid", "Scotland"],
	["Diego Salas", "Argentina"],
	["Rafael Costa", "Brazil"],
]


# --- pool and hiring -------------------------------------------------------

static func scout_pool(career: Career) -> Array:
	var rng := _rng(career, "scout-pool")
	var pool: Array = []
	for index in range(POOL_SIZE):
		var identity: Array = SCOUT_POOL[index % SCOUT_POOL.size()]
		var experience := 1 + rng.randint(0, 4)
		var judgement := 1 + rng.randint(0, 4)
		var price := maxi(10_000,
			int(CareerRng.python_round(
				(float(experience * experience + judgement * judgement) * 30_000.0
					+ float(rng.randint(0, 24)) * 5_000.0) / 1_000.0)) * 1_000)
		pool.append({
			"id": "scout-%d" % (index + 1),
			"name": str(identity[0]),
			"nationality": str(identity[1]),
			"experience": experience,
			"judgement": judgement,
			"price": price,
		})
	return pool


static func ensure_scouts(career: Career) -> void:
	var scouts := _scouts(career)
	if not scouts.is_empty():
		return
	var pool := scout_pool(career)
	for index in range(INITIAL_SCOUTS):
		var scout: Dictionary = (pool[index] as Dictionary).duplicate(true)
		scout["hired_at"] = career.date
		scouts.append(scout)


static func hire(career: Career, scout_id) -> Dictionary:
	ensure_scouts(career)
	var key := str(scout_id)
	var scouts := _scouts(career)
	if scouts.size() >= MAX_SCOUTS:
		return _error("all scout slots are occupied")
	var candidate := {}
	for item in scout_pool(career):
		if str(item.get("id", "")) == key:
			candidate = item
			break
	if candidate.is_empty():
		return _error("scout is not available")
	for scout in scouts:
		if str(scout.get("id", "")) == key:
			return _error("scout is already hired")
	var price := int(candidate.get("price", 0))
	var balance = career.balance
	if balance != null and int(balance) < price:
		return _error("not enough money to hire this scout")
	if balance != null:
		career.balance = int(balance) - price
	var hired := candidate.duplicate(true)
	hired["hired_at"] = career.date
	scouts.append(hired)
	_journal(career, "scouting.hired", {"scout_id": key, "price": price})
	return {"ok": true, "error": "", "scout": hired}


static func dismiss(career: Career, scout_id) -> Dictionary:
	ensure_scouts(career)
	var key := str(scout_id)
	if _scout(career, key).is_empty():
		return _error("scout not found")
	var kept: Array = []
	for scout in _scouts(career):
		if str(scout.get("id", "")) != key:
			kept.append(scout)
	career.data["scouts"] = kept
	_map(career, "scout_assignments").erase(key)
	_map(career, "scout_tasks").erase(key)
	_journal(career, "scouting.dismissed", {"scout_id": key})
	return {"ok": true, "error": ""}


static func recall(career: Career, scout_id) -> Dictionary:
	ensure_scouts(career)
	var key := str(scout_id)
	if _scout(career, key).is_empty():
		return _error("scout not found")
	var released := _map(career, "scout_assignments").erase(key)
	if _map(career, "scout_tasks").erase(key):
		released = true
	if not released:
		return _error("this scout has no active task")
	_journal(career, "scouting.recalled", {"scout_id": key})
	return {"ok": true, "error": ""}


static func assignable_scouts(career: Career) -> Array:
	ensure_scouts(career)
	var assignments := _map(career, "scout_assignments")
	var tasks := _map(career, "scout_tasks")
	var free_scouts: Array = []
	for scout in _scouts(career):
		var key := str(scout.get("id", ""))
		if assignments.has(key) or tasks.has(key):
			continue
		free_scouts.append(scout)
	return free_scouts


# --- player reports --------------------------------------------------------

static func report_days(experience: int) -> int:
	return clampi(6 - int(experience), 1, 5)


static func assign(career: Career, catalog: TeamCatalog, scout_id, player_id) -> Dictionary:
	var key := str(player_id)
	if career.player_ids.has(key):
		return _error("you cannot scout your own player")
	if catalog == null or not key.is_valid_int() \
			or catalog.career_player(int(key), false).is_empty():
		return _error("player not found")
	ensure_scouts(career)
	var scout := _scout(career, str(scout_id))
	if scout.is_empty():
		return _error("scout not found")
	var assignments := _map(career, "scout_assignments")
	if assignments.has(str(scout_id)):
		return _error("this scout is already studying a player")
	for report in assignments.values():
		if str((report as Dictionary).get("player_id", "")) == key:
			return _error("this player is already being studied")
	if _map(career, "scout_reports").has(key) or _map(career, "scout_found").has(key):
		return _error("this player has already been studied")
	var total := report_days(int(scout.get("experience", 1)))
	var report := {
		"player_id": key,
		"scout_id": str(scout_id),
		"started_at": career.date,
		"due_at": CareerSearch.add_days(career.date, total),
		"days_total": total,
		"acknowledged": false,
	}
	assignments[str(scout_id)] = report
	_journal(career, "scouting.report_started",
		{"scout_id": str(scout_id), "player_id": key, "days": total})
	return {"ok": true, "error": "", "report": report}


# --- region networks -------------------------------------------------------

static func default_criteria() -> Dictionary:
	return {
		"role": "", "age_min": null, "age_max": null,
		"contract_min": null, "contract_max": null,
	}


static func normalize_criteria(raw) -> Dictionary:
	var criteria := default_criteria()
	var source: Dictionary = raw if raw is Dictionary else {}
	var role := str(source.get("role", "")).to_upper()
	criteria["role"] = role if ROLE_GROUPS.has(role) else ""
	for spec in [["age", AGE_MIN, AGE_MAX], ["contract", CONTRACT_MIN, CONTRACT_MAX]]:
		var name := str(spec[0])
		var low := int(spec[1])
		var high := int(spec[2])
		var minimum = _int_or_null(source.get(name + "_min"))
		var maximum = _int_or_null(source.get(name + "_max"))
		if minimum != null:
			minimum = maxi(low, mini(high, int(minimum)))
		if maximum != null:
			maximum = maxi(low, mini(high, int(maximum)))
		if minimum != null and maximum != null and int(minimum) > int(maximum):
			var swap = minimum
			minimum = maximum
			maximum = swap
		criteria[name + "_min"] = minimum
		criteria[name + "_max"] = maximum
	return criteria


static func network(career: Career, catalog: TeamCatalog, scout_id, region_id,
		country_id, criteria = {}) -> Dictionary:
	ensure_scouts(career)
	var key := str(scout_id)
	if _scout(career, key).is_empty():
		return _error("scout not found")
	var region := {}
	for spec in REGION_SPECS:
		if str(spec["id"]) == str(region_id):
			region = spec
			break
	if region.is_empty():
		return _error("region not found")
	var country := {}
	var countries := _country_index(catalog)
	for name in region["countries"]:
		var entry: Dictionary = countries.get(str(name), {})
		if not entry.is_empty() and str(entry["id"]) == str(country_id):
			country = entry
			break
	if country.is_empty():
		return _error("country is not in this region")
	var task := {
		"kind": "network",
		"region_id": str(region["id"]),
		"region_name": str(region["name"]),
		"country_id": str(country["id"]),
		"country_name": str(country["name"]),
		"criteria": normalize_criteria(criteria),
		"started_at": career.date,
		"last_tick": career.date,
		"found": [],
	}
	_map(career, "scout_tasks")[key] = task
	var networks := _networks(career)
	var known := false
	for entry in networks:
		if str(entry.get("country_id", "")) == str(country["id"]):
			known = true
			break
	if not known:
		networks.append({
			"region_id": str(region["id"]),
			"region_name": str(region["name"]),
			"country_id": str(country["id"]),
			"country_name": str(country["name"]),
			"created_at": career.date,
			"scout_id": key,
		})
	_journal(career, "scouting.network_started",
		{"scout_id": key, "region_id": str(region["id"]), "country_id": str(country["id"])})
	return {"ok": true, "error": "", "task": task}


static func set_task(career: Career, scout_id, criteria) -> Dictionary:
	var key := str(scout_id)
	var tasks := _map(career, "scout_tasks")
	var task = tasks.get(key)
	if not (task is Dictionary) or str((task as Dictionary).get("kind", "")) != "network":
		return _error("this scout has no network task")
	task["criteria"] = normalize_criteria(criteria)
	_journal(career, "scouting.task_updated",
		{"scout_id": key, "criteria": (task["criteria"] as Dictionary).duplicate(true)})
	return {"ok": true, "error": "", "task": task}


# --- reports feed ----------------------------------------------------------

static func ack(career: Career) -> Dictionary:
	for entry in _map(career, "scout_reports").values():
		(entry as Dictionary)["acknowledged"] = true
	for entry in _map(career, "scout_found").values():
		(entry as Dictionary)["acknowledged"] = true
	return {"ok": true, "error": ""}


static func remove(career: Career, player_id) -> Dictionary:
	var key := str(player_id)
	for report in _map(career, "scout_assignments").values():
		if str((report as Dictionary).get("player_id", "")) == key:
			return _error("report is still in progress")
	var removed := _map(career, "scout_reports").erase(key)
	if _map(career, "scout_found").erase(key):
		removed = true
	if not removed:
		return _error("player is not in any report")
	for task in _map(career, "scout_tasks").values():
		(task as Dictionary)["found"] = _without((task as Dictionary).get("found"), key)
	_journal(career, "scouting.removed", {"player_id": key})
	return {"ok": true, "error": ""}


static func forget_player(career: Career, player_id) -> void:
	var key := str(player_id)
	var assignments := _map(career, "scout_assignments")
	for scout_id in assignments.keys():
		var report = assignments[scout_id]
		if report is Dictionary and str((report as Dictionary).get("player_id", "")) == key:
			assignments.erase(scout_id)
	_map(career, "scout_reports").erase(key)
	_map(career, "scout_found").erase(key)
	for task in _map(career, "scout_tasks").values():
		(task as Dictionary)["found"] = _without((task as Dictionary).get("found"), key)


static func forget_own_players(career: Career) -> void:
	for player_id in career.player_ids:
		forget_player(career, str(player_id))


static func counts(career: Career) -> Dictionary:
	ensure_scouts(career)
	var reports := _map(career, "scout_reports")
	var found := _map(career, "scout_found")
	var total := reports.size() + found.size()
	var new_count := 0
	for entry in reports.values() + found.values():
		if not bool((entry as Dictionary).get("acknowledged", false)):
			new_count += 1
	return {
		"new": new_count,
		"updates": maxi(0, total - new_count),
		"total": total,
		"found": found.size(),
		"scouts": _scouts(career).size(),
	}


# --- the dated tick --------------------------------------------------------

static func process_days(career: Career, catalog: TeamCatalog, from_date: String,
		to_date: String) -> Array:
	# CareerAdvance moves the clock, then ticks. The dates are explicit so the
	# tick never depends on when the caller writes career.date; the per-task
	# `last_tick` and the assignment removal keep repeated calls idempotent.
	var events: Array = []
	if career == null or catalog == null:
		return events
	var today := to_date.substr(0, 10) if not to_date.is_empty() else career.date
	if not from_date.is_empty() and today <= from_date.substr(0, 10):
		return events
	ensure_scouts(career)
	var assignments := _map(career, "scout_assignments")
	var reports := _map(career, "scout_reports")
	var found := _map(career, "scout_found")
	for scout_id in assignments.keys():
		var report: Dictionary = assignments[scout_id]
		var due_at := str(report.get("due_at", today))
		if today < due_at:
			continue
		var player_id := str(report.get("player_id", ""))
		reports[player_id] = {
			"scout_id": str(scout_id),
			"completed_at": due_at,
			"acknowledged": false,
		}
		assignments.erase(scout_id)
		var player_name := _player_name(catalog, player_id)
		events.append({
			"type": "scouting.report.ready",
			"message": "%s completed the scouting report on %s." % [
				_scout_name(career, scout_id), player_name],
			"player_id": player_id,
			"player_name": player_name,
			"scout_id": str(scout_id),
		})
		_journal(career, "scouting.report_ready",
			{"scout_id": str(scout_id), "player_id": player_id})

	for scout_id in _map(career, "scout_tasks").keys():
		var task: Dictionary = _map(career, "scout_tasks")[scout_id]
		if str(task.get("kind", "")) != "network":
			continue
		var last_tick := str(task.get("last_tick", task.get("started_at", today)))
		if last_tick.is_empty():
			last_tick = today
		if today <= last_tick:
			continue
		var scout := _scout(career, scout_id)
		var rate := 1
		if not scout.is_empty():
			rate += int(scout.get("judgement", 1)) / 2
		var day := CareerSearch.add_days(last_tick, 1)
		var candidates: Array = []
		var loaded := false
		while day <= today:
			var task_found: Array = task["found"] if task.get("found") is Array else []
			task["found"] = task_found
			var current := task_found.size()
			var target := mini(FOUND_CAP, current + rate)
			if current < target:
				if not loaded:
					candidates = _task_candidates(career, catalog, task)
					loaded = true
				var rng := _rng(career, "found:%s:%s" % [str(scout_id), day])
				_shuffle(rng, candidates)
				for candidate in candidates:
					if current >= target:
						break
					var player_id := str(candidate)
					if task_found.has(player_id):
						continue
					if found.has(player_id) or reports.has(player_id):
						continue
					if career.player_ids.has(player_id):
						continue
					task_found.append(player_id)
					found[player_id] = {
						"scout_id": str(scout_id),
						"found_at": day,
						"acknowledged": false,
					}
					var player_name := _player_name(catalog, player_id)
					events.append({
						"type": "scouting.found",
						"message": "%s found %s in %s." % [
							_scout_name(career, scout_id), player_name,
							str(task.get("country_name", ""))],
						"player_id": player_id,
						"player_name": player_name,
						"scout_id": str(scout_id),
					})
					_journal(career, "scouting.player_found",
						{"scout_id": str(scout_id), "player_id": player_id})
					current += 1
			day = CareerSearch.add_days(day, 1)
		task["last_tick"] = today
	return events


# --- snapshot for the screens ---------------------------------------------

static func snapshot(career: Career, catalog: TeamCatalog) -> Dictionary:
	ensure_scouts(career)
	var countries := _country_index(catalog)
	var scouts: Array = []
	var tasks: Array = []
	var scout_names := {}
	for scout in _scouts(career):
		var key := str(scout.get("id", ""))
		scout_names[key] = str(scout.get("name", ""))
		var view := _scout_view(career, catalog, scout, countries)
		scouts.append(view)
		if view["task"] != null:
			var task: Dictionary = (view["task"] as Dictionary).duplicate(true)
			task["scout_id"] = key
			task["scout_name"] = view["name"]
			tasks.append(task)
	var candidates: Array = []
	for item in scout_candidates(career):
		var candidate: Dictionary = item.duplicate(true)
		var country: Dictionary = countries.get(str(candidate.get("nationality", "")), {})
		candidate["nationality_id"] = str(country.get("id", ""))
		candidate["flag"] = str(country.get("name", ""))
		candidate["affordable"] = career.balance == null \
			or int(career.balance) >= int(candidate.get("price", 0))
		candidates.append(candidate)
	var reports: Array = []
	var report_store := _map(career, "scout_reports")
	for player_id in report_store:
		var data: Dictionary = report_store[player_id]
		var entry := _entry(career, catalog, player_id, data, "report",
			str(data.get("completed_at", career.date)), scout_names)
		if not entry.is_empty():
			reports.append(entry)
	var recommendations: Array = []
	var found_store := _map(career, "scout_found")
	for player_id in found_store:
		var data: Dictionary = found_store[player_id]
		var entry := _entry(career, catalog, player_id, data, "recommendation",
			str(data.get("found_at", career.date)), scout_names)
		if not entry.is_empty():
			recommendations.append(entry)
	_sort_entries(reports)
	_sort_entries(recommendations)
	var feed := reports + recommendations
	_sort_feed(feed)
	var found_ids: Array = []
	for player_id in found_store:
		found_ids.append(str(player_id))
	return {
		"scouts": scouts,
		"candidates": candidates,
		"tasks": tasks,
		"reports": reports,
		"recommendations": recommendations,
		"feed": feed,
		"found": found_ids,
		"networks": _networks(career).duplicate(true),
		"regions": regions(catalog),
		"counts": counts(career),
		"max_scouts": MAX_SCOUTS,
		"age_min": AGE_MIN,
		"age_max": AGE_MAX,
		"contract_min": CONTRACT_MIN,
		"contract_max": CONTRACT_MAX,
	}


static func regions(catalog: TeamCatalog) -> Array:
	var countries := _country_index(catalog)
	var result: Array = []
	for spec in REGION_SPECS:
		var members: Array = []
		for name in spec["countries"]:
			var country: Dictionary = countries.get(str(name), {})
			if country.is_empty():
				continue
			members.append({
				"id": str(country["id"]),
				"name": str(country["name"]),
				"flag": str(country["name"]),
			})
		if members.is_empty():
			continue
		result.append({
			"id": str(spec["id"]),
			"name": str(spec["name"]),
			"x": int(spec["x"]),
			"y": int(spec["y"]),
			"countries": members,
		})
	return result


static func scout_candidates(career: Career) -> Array:
	ensure_scouts(career)
	var hired := {}
	for scout in _scouts(career):
		hired[str(scout.get("id", ""))] = true
	var result: Array = []
	for scout in scout_pool(career):
		if hired.has(str(scout.get("id", ""))):
			continue
		result.append(scout)
		if result.size() >= CANDIDATES_SHOWN:
			break
	return result


static func report_for(career: Career, player_id) -> Dictionary:
	# What the transfer screens need: is this player being studied, reported or
	# already found, and by whom.
	var key := str(player_id)
	for scout_id in _map(career, "scout_assignments"):
		var report: Dictionary = _map(career, "scout_assignments")[scout_id]
		if str(report.get("player_id", "")) != key:
			continue
		var progress := _report_progress(career, report)
		return {
			"player_id": key,
			"kind": "studying",
			"scout_id": str(scout_id),
			"scout_name": _scout_name(career, str(scout_id)),
			"date": str(report.get("started_at", career.date)),
			"acknowledged": false,
			"duration": progress["days_total"],
			"days_left": progress["days_left"],
		}
	for kind in ["report", "recommendation"]:
		var store := _map(career, "scout_reports" if kind == "report" else "scout_found")
		if not store.has(key):
			continue
		var data: Dictionary = store[key]
		var stamp := str(data.get("completed_at", data.get("found_at", career.date)))
		return {
			"player_id": key,
			"kind": kind,
			"scout_id": str(data.get("scout_id", "")),
			"scout_name": _scout_name(career, str(data.get("scout_id", ""))),
			"date": stamp,
			"acknowledged": bool(data.get("acknowledged", false)),
			"duration": _duration(career, kind, str(data.get("scout_id", "")), key),
			"days_left": 0,
		}
	return {}


# --- internals -------------------------------------------------------------

static func _scout_view(career: Career, catalog: TeamCatalog, scout: Dictionary,
		countries: Dictionary) -> Dictionary:
	var key := str(scout.get("id", ""))
	var country: Dictionary = countries.get(str(scout.get("nationality", "")), {})
	var task_view = null
	var task = _map(career, "scout_tasks").get(key)
	if task is Dictionary:
		task_view = {
			"kind": str((task as Dictionary).get("kind", "network")),
			"region_id": str((task as Dictionary).get("region_id", "")),
			"region_name": str((task as Dictionary).get("region_name", "")),
			"country_id": str((task as Dictionary).get("country_id", "")),
			"country_name": str((task as Dictionary).get("country_name", "")),
			"criteria": normalize_criteria((task as Dictionary).get("criteria")),
			"started_at": str((task as Dictionary).get("started_at", career.date)),
			"days_worked": maxi(0, CareerSearch.date_diff_days(
				str((task as Dictionary).get("started_at", career.date)), career.date)),
			"found_count": ((task as Dictionary).get("found") as Array).size() \
				if (task as Dictionary).get("found") is Array else 0,
		}
	var report_view = null
	var report = _map(career, "scout_assignments").get(key)
	if report is Dictionary:
		var progress := _report_progress(career, report)
		var player_id := str((report as Dictionary).get("player_id", ""))
		report_view = {
			"player_id": player_id,
			"player_name": _player_name(catalog, player_id),
			"player_photo": int(player_id) if player_id.is_valid_int() else 0,
			"started_at": str((report as Dictionary).get("started_at", career.date)),
			"due_at": str((report as Dictionary).get("due_at", career.date)),
			"days_total": progress["days_total"],
			"days_left": progress["days_left"],
			"days_worked": progress["days_worked"],
			"progress": snappedf(float(progress["days_worked"])
				/ float(maxi(1, progress["days_total"])), 0.001),
		}
	return {
		"id": key,
		"name": str(scout.get("name", "")),
		"nationality": str(scout.get("nationality", "")),
		"nationality_id": str(country.get("id", "")),
		"flag": str(country.get("name", "")),
		"experience": int(scout.get("experience", 1)),
		"judgement": int(scout.get("judgement", 1)),
		"price": int(scout.get("price", 0)),
		"hired_at": str(scout.get("hired_at", "")),
		"hired": true,
		"free": task_view == null and report_view == null,
		"busy": task_view != null or report_view != null,
		"current_task": "report" if report_view != null \
			else ("network" if task_view != null else ""),
		"task": task_view,
		"report": report_view,
	}


static func _entry(career: Career, catalog: TeamCatalog, player_id, data, kind: String,
		stamp: String, scout_names: Dictionary) -> Dictionary:
	var player := CareerSearch.profile(catalog, career, player_id)
	if player.is_empty():
		return {}
	var scout_id := str((data as Dictionary).get("scout_id", ""))
	var scout_name := str(scout_names.get(scout_id, ""))
	if scout_name.is_empty():
		scout_name = _scout_name(career, scout_id)
	return {
		"player": player,
		"kind": kind,
		"scout_id": scout_id,
		"scout_name": scout_name,
		"date": stamp,
		"acknowledged": bool((data as Dictionary).get("acknowledged", false)),
		"duration": _duration(career, kind, scout_id, str(player_id)),
	}


static func _duration(career: Career, kind: String, scout_id: String,
		player_id: String) -> int:
	if kind != "report":
		return 0
	for scout in _scouts(career) + scout_pool(career):
		if str(scout.get("id", "")) == scout_id:
			return report_days(int(scout.get("experience", 1)))
	return 0


static func _sort_entries(entries: Array) -> void:
	# Prototype: sorted by (date, player name) descending.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["date"]) != str(b["date"]):
			return str(a["date"]) > str(b["date"])
		return str(a["player"]["name"]) > str(b["player"]["name"]))


static func _sort_feed(entries: Array) -> void:
	# The client's final order: newest first, then player name ascending.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["date"]) != str(b["date"]):
			return str(a["date"]) > str(b["date"])
		return str(a["player"]["name"]).to_lower() \
			< str(b["player"]["name"]).to_lower())


static func _task_candidates(career: Career, catalog: TeamCatalog, task: Dictionary) -> Array:
	var criteria := normalize_criteria(task.get("criteria"))
	var filters := CareerSearch.filters_default()
	filters["country"] = str(task.get("country_id", ""))
	filters["group"] = str(criteria["role"])
	filters["age_min"] = criteria["age_min"]
	filters["age_max"] = criteria["age_max"]
	filters["sort"] = "overall"
	filters["direction"] = "desc"
	var page := CareerSearch.search(catalog, career, filters, 200, 0)
	var result: Array = []
	var seen := {}
	for item in page.get("items", []):
		var player_id := str((item as Dictionary).get("player_id", ""))
		if seen.has(player_id):
			continue
		seen[player_id] = true
		if not _matches(item, criteria, career):
			continue
		result.append(player_id)
	return result


static func _matches(item: Dictionary, criteria: Dictionary, career: Career) -> bool:
	var role := str(criteria.get("role", ""))
	if not role.is_empty() and str(item.get("position_group", "")) != role:
		return false
	var age := int(item.get("age", 0))
	if age > 0 and criteria.get("age_min") != null and age < int(criteria["age_min"]):
		return false
	if age > 0 and criteria.get("age_max") != null and age > int(criteria["age_max"]):
		return false
	var minimum = criteria.get("contract_min")
	var maximum = criteria.get("contract_max")
	if minimum == null and maximum == null:
		return true
	var months := _contract_months(career, item)
	if minimum != null and months < int(minimum) * 12:
		return false
	if maximum != null and months > int(maximum) * 12:
		return false
	return true


static func _contract_months(career: Career, item: Dictionary) -> int:
	# CareerSearch.contract_months needs the club membership to tell a free
	# agent (0 months) from a contracted player; the search item keeps only the
	# resolved status.
	var player := {"club_id": "" if str(item.get("status", "")) == "free" else "club"}
	return CareerSearch.contract_months(career, player, str(item.get("player_id", "")))


static func _report_progress(career: Career, report: Dictionary) -> Dictionary:
	var total := maxi(1, int(report.get("days_total", 1)))
	var started := str(report.get("started_at", career.date))
	var worked := mini(total, maxi(0, CareerSearch.date_diff_days(started, career.date)))
	return {"days_total": total, "days_left": maxi(0, total - worked), "days_worked": worked}


static func _scout(career: Career, scout_id) -> Dictionary:
	var key := str(scout_id)
	for scout in _scouts(career):
		if str(scout.get("id", "")) == key:
			return scout
	return {}


static func _scout_name(career: Career, scout_id: String) -> String:
	var scout := _scout(career, scout_id)
	if not scout.is_empty():
		return str(scout.get("name", ""))
	for item in scout_pool(career):
		if str(item.get("id", "")) == scout_id:
			return str(item.get("name", ""))
	return ""


static func _player_name(catalog: TeamCatalog, player_id: String) -> String:
	if catalog == null or not player_id.is_valid_int():
		return player_id
	var player := catalog.career_player(int(player_id), false)
	if player.is_empty():
		return player_id
	return str(player.get("name", player_id))


static func _country_index(catalog: TeamCatalog) -> Dictionary:
	var result := {}
	if catalog == null:
		return result
	for country in catalog.countries():
		var name := str(country.get("name", ""))
		if not name.is_empty():
			result[name] = country
	return result


static func _scouts(career: Career) -> Array:
	if not (career.data.get("scouts") is Array):
		career.data["scouts"] = []
	return career.data["scouts"]


static func _map(career: Career, key: String) -> Dictionary:
	if not (career.data.get(key) is Dictionary):
		career.data[key] = {}
	return career.data[key]


static func _networks(career: Career) -> Array:
	if not (career.data.get("scout_networks") is Array):
		career.data["scout_networks"] = []
	return career.data["scout_networks"]


static func _rng(career: Career, key: String) -> CareerRng:
	return CareerRng.seeded("%d:%s" % [career.seed, key])


static func _shuffle(rng: CareerRng, values: Array) -> void:
	# CPython's random.shuffle: one randbelow(i + 1) draw per position, from
	# the end, so the RNG stream matches the prototype bit for bit.
	for index in range(values.size() - 1, 0, -1):
		var swap := rng.randbelow(index + 1)
		var value = values[index]
		values[index] = values[swap]
		values[swap] = value


static func _int_or_null(value):
	if value == null:
		return null
	if value is int or value is float or value is bool:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)
	return null


static func _without(values, key: String) -> Array:
	var result: Array = []
	if values is Array:
		for item in values:
			if str(item) != key:
				result.append(item)
	return result


static func _journal(career: Career, kind: String, payload: Dictionary) -> void:
	var journal: Array = career.journal
	journal.append({"seq": journal.size() + 1, "type": kind, "payload": payload})


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
