class_name CareerCountryCoefficients
extends RefCounted
# UEFA association coefficients. The first career season uses the published
# five-year country ranking (2021-22 to 2025-26). In the dynamic mode the career
# rolls the table after each European season: the oldest season drops and the new
# country points (sum of its clubs' points divided by the clubs that took part)
# are appended.

const PATH := "res://assets/data/country_coefficients.json"

static var _data: Dictionary = {}

# The country ranking page and the access list spell four associations differently.
const NORMALIZE := {
	"Czechia": "Czech Republic",
	"Türkiye": "Turkey",
	"Ireland": "Republic of Ireland",
	"Bosnia-Herzegovina": "Bosnia and Herzegovina",
}

# Club country codes used by the club snapshot -> association names.
const CODES := {
	"Eng": "England", "Esp": "Spain", "Ita": "Italy", "Ger": "Germany",
	"Fra": "France", "Por": "Portugal", "Ned": "Netherlands", "Bel": "Belgium",
	"Tur": "Türkiye", "Cze": "Czechia", "Gre": "Greece", "Pol": "Poland",
	"Den": "Denmark", "Nor": "Norway", "Cyp": "Cyprus", "Sui": "Switzerland",
	"Aut": "Austria", "Sco": "Scotland", "Swe": "Sweden", "Cro": "Croatia",
	"Isr": "Israel", "Hun": "Hungary", "Ukr": "Ukraine", "Srb": "Serbia",
	"Rom": "Romania", "Slo": "Slovenia", "Azb": "Azerbaijan", "Rus": "Russia",
	"Svk": "Slovakia", "Bul": "Bulgaria", "Irl": "Ireland", "Isl": "Iceland",
	"Arm": "Armenia", "Mol": "Moldova", "Fin": "Finland", "Kos": "Kosovo",
	"Kaz": "Kazakhstan", "Bos": "Bosnia-Herzegovina", "Lat": "Latvia",
	"Far": "Faroe Islands", "Mlt": "Malta", "Lie": "Liechtenstein",
	"Est": "Estonia", "Alb": "Albania", "Mac": "North Macedonia",
	"Lit": "Lithuania", "Nir": "Northern Ireland", "Gib": "Gibraltar",
	"And": "Andorra", "Bls": "Belarus", "Lux": "Luxembourg",
	"Mon": "Montenegro", "Geo": "Georgia", "Wal": "Wales", "Sma": "San Marino",
}


static func data() -> Dictionary:
	if _data.is_empty():
		if not FileAccess.file_exists(PATH):
			return {}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			_data = raw
	return _data


static func seasons() -> Array:
	var value = data().get("seasons", [])
	return value if value is Array else []


static func table() -> Dictionary:
	var result := {}
	var associations = data().get("associations", {})
	if not (associations is Dictionary):
		return result
	for name in associations:
		var entry = associations[name]
		if entry is Dictionary and entry.get("points") is Array:
			result[str(name)] = (entry["points"] as Array).duplicate()
	return result


static func coefficient(table_data: Dictionary, association: String) -> float:
	var row = table_data.get(association, [])
	var total := 0.0
	for value in row:
		total += float(value)
	return total


static func ranking(table_data: Dictionary) -> Array:
	var names := table_data.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		var left := coefficient(table_data, a)
		var right := coefficient(table_data, b)
		if not is_equal_approx(left, right):
			return left > right
		return a < b)
	return names


static func roll(table_data: Dictionary,
		season_points: Dictionary) -> Dictionary:
	var result := {}
	for name in table_data:
		var row = table_data[name]
		var next: Array = []
		if row is Array:
			for index in range(1, 5):
				next.append(float(row[index]) if index < (row as Array).size() else 0.0)
		else:
			next = [0.0, 0.0, 0.0, 0.0]
		next.append(float(season_points.get(str(name), 0.0)))
		result[str(name)] = next
	for name in season_points:
		if not result.has(str(name)):
			result[str(name)] = [0.0, 0.0, 0.0, 0.0,
				float(season_points[name])]
	return result


static func association_for_code(code: String) -> String:
	return str(CODES.get(code, ""))


static func access_name(association: String) -> String:
	return str(NORMALIZE.get(association, association))
