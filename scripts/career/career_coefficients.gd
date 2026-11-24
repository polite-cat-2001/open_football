class_name CareerCoefficients
extends RefCounted
# UEFA club coefficients. The first career season uses a published snapshot of
# the end-of-2025-26 five-year ranking; clubs outside it start at zero. The
# career's own European results can be rolled into the same table later.

const PATH := "res://assets/data/club_coefficients.json"

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


static func seasons() -> Array:
	var value = data().get("seasons", [])
	return value if value is Array else []


static func points(club_id: String) -> Array:
	var clubs = data().get("clubs", {})
	if not (clubs is Dictionary):
		return []
	var entry = clubs.get(str(club_id), {})
	if entry is Dictionary and entry.get("points") is Array:
		return entry["points"]
	return []


static func country_part(club_id: String) -> float:
	var clubs = data().get("clubs", {})
	if not (clubs is Dictionary):
		return 0.0
	var entry = clubs.get(str(club_id), {})
	if entry is Dictionary:
		return float(entry.get("country_part", 0.0))
	return 0.0


static func table() -> Dictionary:
	var result := {}
	var clubs = data().get("clubs", {})
	if not (clubs is Dictionary):
		return result
	for club_id in clubs:
		var entry = clubs[club_id]
		if entry is Dictionary and entry.get("points") is Array:
			result[str(club_id)] = (entry["points"] as Array).duplicate()
	return result


static func roll(table_data: Dictionary, season_points: Dictionary) -> Dictionary:
	# Add one season and drop the oldest, so the ranking always covers five.
	var result := {}
	for club_id in table_data:
		var row = table_data[club_id]
		var next: Array = []
		if row is Array:
			for index in range(1, 5):
				next.append(float(row[index]) if index < (row as Array).size() else 0.0)
		else:
			next = [0.0, 0.0, 0.0, 0.0]
		next.append(float(season_points.get(str(club_id), 0.0)))
		result[str(club_id)] = next
	for club_id in season_points:
		if not result.has(str(club_id)):
			result[str(club_id)] = [0.0, 0.0, 0.0, 0.0,
				float(season_points[club_id])]
	return result


static func total(table_data: Dictionary, club_id: String) -> float:
	var row = table_data.get(str(club_id), [])
	var total_points := 0.0
	for value in row:
		total_points += float(value)
	return maxf(total_points, country_part(club_id))


static func season_points(competition: String, league_rank: int, wins: int,
		draws: int, reached: Dictionary) -> float:
	# UEFA 2024-27 club points: 2 per win and 1 per draw from the league phase
	# onwards (the knockout play-off is excluded), a league-phase ranking bonus,
	# and a participation bonus for each knockout round reached. UEL and UECL
	# league phases also have a minimum.
	var match_points := 2.0 * float(wins) + float(draws)
	var bonus := _rank_bonus(competition, league_rank)
	var per_round := 0.5
	if competition == "CL":
		per_round = 1.5
	elif competition == "EL":
		per_round = 1.0
	var knockout := 0.0
	for round in ["r16", "qf", "semi", "final"]:
		if bool(reached.get(round, false)):
			knockout += per_round
	var total_points := match_points + bonus + knockout
	var minimum := 0.0
	if competition == "EL":
		minimum = 3.0
	elif competition == "UCOL":
		minimum = 2.5
	return maxf(total_points, minimum)


static func _rank_bonus(competition: String, rank: int) -> float:
	var position := clampi(rank, 1, 36)
	if competition == "CL":
		if position < 9:
			return 12.0 - 0.25 * float(position - 1)
		if position < 17:
			return 10.0 - 0.25 * float(position - 9)
		if position < 25:
			return 8.0 - 0.25 * float(position - 17)
		return 6.0
	if competition == "EL":
		if position < 9:
			return 6.0 - 0.25 * float(position - 1)
		if position < 17:
			return 4.0 - 0.25 * float(position - 9)
		if position < 25:
			return 2.0 - 0.25 * float(position - 17)
		return 0.0
	if position < 9:
		return 4.0 - 0.25 * float(position - 1)
	if position < 17:
		return 2.0 - 0.125 * float(position - 9)
	if position < 25:
		return 1.0 - 0.125 * float(position - 17)
	return 0.0


static func coefficient(club_id: String) -> float:
	var clubs = data().get("clubs", {})
	if not (clubs is Dictionary):
		return 0.0
	var entry = clubs.get(str(club_id), {})
	if entry is Dictionary:
		return float(entry.get("coefficient", 0.0))
	return 0.0


static func sorted_clubs(club_ids: Array) -> Array:
	var ids: Array = []
	for club_id in club_ids:
		ids.append(str(club_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var left := coefficient(a)
		var right := coefficient(b)
		if not is_equal_approx(left, right):
			return left > right
		return a < b)
	return ids
