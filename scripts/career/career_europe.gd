class_name CareerEurope
extends RefCounted
# The real 2026-27 UEFA fields and the first-season Europe switch. Real mode
# plays the published league phase as it is; simulated mode starts from the same
# field and, when the career club is absent, puts it into the competition whose
# average club coefficient is closest and drops the weakest club there. Clubs are
# compared by coefficient everywhere; it is the same number that seeds the pots.

const PATH := "res://assets/data/europe_2026_27.json"
const MODES := ["real", "simulated", "none"]
const COMPETITIONS := ["ucl", "uel", "uecl"]
const ROUNDS := {"ucl": 8, "uel": 8, "uecl": 6}

static var last_error := ""
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if not FileAccess.file_exists(PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data


static func season() -> String:
	return str(data().get("season", ""))


static func fields() -> Dictionary:
	var result := {}
	var competitions = data().get("competitions", {})
	if not (competitions is Dictionary):
		return result
	for comp in competitions:
		var field = competitions[comp]
		if field is Array:
			result[str(comp).to_lower()] = _ids(field)
	return result


static func replacements() -> Dictionary:
	var result := {}
	var rows = data().get("replacements", {})
	if not (rows is Dictionary):
		return result
	for comp in rows:
		result[str(comp).to_lower()] = rows[comp]
	return result


static func uefa_association(country: String) -> bool:
	if country.is_empty():
		return false
	var uefa = CareerBerths.access().get("uefa", {})
	for row in uefa.get("coefficients", []):
		if str((row as Dictionary).get("association", "")) == country:
			return true
	return false


static func block() -> Dictionary:
	var fields := fields()
	if fields.is_empty():
		return {}
	var competitions := {}
	for comp in COMPETITIONS:
		competitions[comp] = {
			"league_phase": fields.get(comp, []),
			"rounds": {},
			"draw": draw(comp),
			"round_count": int(ROUNDS.get(comp, 8)),
			"substitutions": {},
		}
	return {"competitions": competitions, "rebalanced": {},
		"source": "uefa_2026_27"}


static func draw(comp: String) -> Array:
	var result: Array = []
	var rows = data().get("draw", {})
	if not (rows is Dictionary):
		return result
	for row in rows.get(comp.to_upper(), []):
		if row is Array and row.size() == 2:
			result.append({"home": str(int(row[0])), "away": str(int(row[1]))})
	return result


static func first_season(mode: String, focus_club: String) -> Dictionary:
	last_error = ""
	if not MODES.has(mode):
		last_error = "unknown Europe mode: " + mode
		return {}
	if mode == "none":
		return {}
	var built := block()
	if built.is_empty():
		last_error = "the 2026-27 UEFA field is missing"
		return {}
	if mode == "real" or focus_club.is_empty():
		return built
	if _competition_of(built, focus_club).is_empty():
		_place_club(built, focus_club)
	return built


static func swap(block_data: Dictionary, from_comp: String, from_club: String,
		to_comp: String, to_club: String) -> bool:
	last_error = ""
	var competitions: Dictionary = block_data.get("competitions", {})
	if from_comp == to_comp:
		last_error = "pick clubs from two different competitions"
		return false
	if not competitions.has(from_comp) or not competitions.has(to_comp):
		last_error = "unknown competition"
		return false
	var from_field: Array = competitions[from_comp].get("league_phase", [])
	var to_field: Array = competitions[to_comp].get("league_phase", [])
	var from_index := from_field.find(from_club)
	var to_index := to_field.find(to_club)
	if from_index < 0:
		last_error = "the club is not in the first competition"
		return false
	if to_index < 0:
		last_error = "the club is not in the second competition"
		return false
	from_field[from_index] = to_club
	to_field[to_index] = from_club
	if from_field.size() != 36 or to_field.size() != 36 \
			or _duplicates(from_field) or _duplicates(to_field):
		from_field[from_index] = from_club
		to_field[to_index] = to_club
		last_error = "the swap would break the 36-club field"
		return false
	return true


static func _place_club(block_data: Dictionary, club_id: String) -> String:
	var competitions: Dictionary = block_data.get("competitions", {})
	var target := ""
	var target_diff := INF
	var coefficient := CareerCoefficients.coefficient(club_id)
	for comp in COMPETITIONS:
		var field: Array = competitions.get(comp, {}).get("league_phase", [])
		if field.is_empty():
			continue
		var diff := absf(_average(field) - coefficient)
		if diff < target_diff:
			target_diff = diff
			target = comp
	if target.is_empty():
		last_error = "no league phase to place the club into"
		return ""
	var field: Array = competitions[target]["league_phase"]
	var weakest := _weakest(field)
	field[field.find(weakest)] = club_id
	var substitutions: Dictionary = competitions[target].get("substitutions", {})
	substitutions[weakest] = club_id
	competitions[target]["substitutions"] = substitutions
	return target


static func _competition_of(block_data: Dictionary, club_id: String) -> String:
	var competitions: Dictionary = block_data.get("competitions", {})
	for comp in COMPETITIONS:
		var field: Array = competitions.get(comp, {}).get("league_phase", [])
		if field.has(club_id):
			return comp
	return ""


static func _weakest(field: Array) -> String:
	var sorted := CareerCoefficients.sorted_clubs(field)
	return sorted[sorted.size() - 1] if not sorted.is_empty() else ""


static func _average(field: Array) -> float:
	if field.is_empty():
		return 0.0
	var total := 0.0
	for club_id in field:
		total += CareerCoefficients.coefficient(str(club_id))
	return total / field.size()


static func _duplicates(field: Array) -> bool:
	var seen := {}
	for club_id in field:
		if seen.has(str(club_id)):
			return true
		seen[str(club_id)] = true
	return false


static func _ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(str(int(value)))
	return result
