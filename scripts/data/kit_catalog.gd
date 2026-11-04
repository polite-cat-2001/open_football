class_name KitCatalog
extends RefCounted
# Reads the kit specs imported from gf-ui-prototype (databases/default/kits.json,
# tools/import_prototype_kits.py). The file is optional: without it every team
# falls back to a plain kit built from its database colours, so the kit screen
# still works in a minimal data tree.

const FILE := "databases/default/kits.json"
const VERSION := 1
const KIT_IDS := ["main", "white", "black", "reserve"]
const KIT_LABELS := {
	"main": "HOME",
	"white": "AWAY",
	"black": "THIRD",
	"reserve": "FOURTH",
}
const FALLBACK_PALETTE := [
	Color(0.960784, 0.968627, 0.980392, 1.0),
	Color(0.090196, 0.105882, 0.247059, 1.0),
	Color(0.352941, 0.372549, 0.470588, 1.0),
	Color(0.113725, 0.129412, 0.219608, 1.0),
]

var error := ""
var available := false
var data_root := ""

var _teams := {}
var _loaded := false

# The kit file is ~1.9 MB; parsing it on every kit-screen open caused a visible
# hitch. The parsed teams object is immutable, so share it between instances.
static var _file_cache := {}


func load_data_root(root: String = "") -> bool:
	error = ""
	available = false
	_teams.clear()
	_loaded = true
	data_root = root if not root.is_empty() else TeamCatalog.new().resolve_data_root()
	var path := data_root.path_join(FILE)
	if _file_cache.has(path):
		_teams = _file_cache[path]
		available = not _teams.is_empty()
		return true
	if not FileAccess.file_exists(path):
		return true
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		error = "Kit specs are empty: " + path
		return false
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		error = "Kit specs are not a JSON object: " + path
		return false
	var teams = parsed.get("teams", {})
	if not (teams is Dictionary):
		error = "Kit specs have no teams object: " + path
		return false
	_teams = teams
	_file_cache[path] = _teams
	available = not _teams.is_empty()
	return true


func is_loaded() -> bool:
	return _loaded


func teams_count() -> int:
	return _teams.size()


func kits_for(team: Dictionary) -> Array:
	var tm_id := str(team.get("tm_id", "")).strip_edges()
	if not tm_id.is_empty() and _teams.has(tm_id):
		var entry = _teams[tm_id]
		if entry is Dictionary:
			var kits = entry.get("kits", [])
			if kits is Array and not kits.is_empty():
				var result: Array = []
				for kit in kits:
					if kit is Dictionary:
						result.append(_normalize_kit(kit))
				if not result.is_empty():
					return result
	return default_kits(team)


func default_kit(team: Dictionary, index: int) -> Dictionary:
	var kits := kits_for(team)
	return kits[clampi(index, 0, kits.size() - 1)]


func default_away_kit(team: Dictionary, opponent_kit: Dictionary) -> Dictionary:
	var kits := kits_for(team)
	return kits[default_away_index(kits, opponent_kit)]


func default_away_index(kits: Array, opponent_kit: Dictionary) -> int:
	if kits.is_empty():
		return 0
	if opponent_kit.is_empty():
		return kit_index(kits, "white") if kit_index(kits, "white") >= 0 else 0
	var scores: Array[float] = []
	var best := -1.0
	var best_index := 0
	for index in kits.size():
		var score := _contrast(kits[index], opponent_kit)
		scores.append(score)
		if score > best:
			best = score
			best_index = index
	# Prefer the away/main shirt when it is close to the maximum contrast; only
	# fall through to a third/fourth strip when it is clearly more distinct.
	for id in ["white", "main"]:
		var index := kit_index(kits, id)
		if index >= 0 and scores[index] >= best * 0.72:
			return index
	return best_index


func _contrast(first: Dictionary, second: Dictionary) -> float:
	var first_shirt := _parse_color(str(first.get("shirt", "")), Color.WHITE)
	var second_shirt := _parse_color(str(second.get("shirt", "")), Color.WHITE)
	var first_shorts := _parse_color(str(first.get("shorts", "")), Color.WHITE)
	var second_shorts := _parse_color(str(second.get("shorts", "")), Color.WHITE)
	var shirt_distance := Vector3(
		first_shirt.r - second_shirt.r,
		first_shirt.g - second_shirt.g,
		first_shirt.b - second_shirt.b
	).length() / sqrt(3.0)
	var shorts_distance := Vector3(
		first_shorts.r - second_shorts.r,
		first_shorts.g - second_shorts.g,
		first_shorts.b - second_shorts.b
	).length() / sqrt(3.0)
	var luminance := absf(first_shirt.get_luminance() - second_shirt.get_luminance())
	return shirt_distance * 0.7 + shorts_distance * 0.15 + luminance * 0.15


func kit_index(kits: Array, kit_id: String) -> int:
	for index in kits.size():
		if str((kits[index] as Dictionary).get("id", "")) == kit_id:
			return index
	return -1


func default_index(side: int) -> int:
	return 0 if side == 0 else 1


func default_kits(team: Dictionary) -> Array:
	var first := _parse_color(str(team.get("color1", "")), FALLBACK_PALETTE[0])
	var second := _parse_color(str(team.get("color2", "")), FALLBACK_PALETTE[1])
	return [
		_kit("main", first, second, "plain", null),
		_kit("white", FALLBACK_PALETTE[0], first, "plain", null),
		_kit("black", FALLBACK_PALETTE[1], first, "plain", null),
		_kit("reserve", second, first, "plain", null),
	]


func _normalize_kit(kit: Dictionary) -> Dictionary:
	var id := str(kit.get("id", "main"))
	if not KIT_IDS.has(id):
		id = "main"
	var shirt := _color_string(kit.get("shirt"), FALLBACK_PALETTE[0])
	var shorts := _color_string(kit.get("shorts"), FALLBACK_PALETTE[1])
	var pattern := str(kit.get("pattern", "plain"))
	if not ["plain", "stripes", "halves", "hoops", "sash"].has(pattern):
		pattern = "plain"
	var pattern_color = kit.get("pattern_color", null)
	if pattern == "plain" or pattern_color == null:
		pattern_color = null
	else:
		pattern_color = _color_string(pattern_color, FALLBACK_PALETTE[3])
	return {
		"id": id,
		"label": str(KIT_LABELS.get(id, id.to_upper())),
		"shirt": shirt,
		"shorts": shorts,
		"pattern": pattern,
		"pattern_color": pattern_color,
	}


func _kit(id: String, shirt: Color, shorts: Color, pattern: String,
		pattern_color) -> Dictionary:
	return {
		"id": id,
		"label": str(KIT_LABELS.get(id, id.to_upper())),
		"shirt": shirt.to_html(false),
		"shorts": shorts.to_html(false),
		"pattern": pattern,
		"pattern_color": pattern_color,
	}


func _color_string(value, fallback: Color) -> String:
	if value is Color:
		return (value as Color).to_html(false)
	var text := str(value).strip_edges()
	if text.begins_with("#") and (text.length() == 7 or text.length() == 9):
		return text.trim_prefix("#").substr(0, 6).to_upper()
	return _parse_color(text, fallback).to_html(false)


func _parse_color(value: String, fallback: Color) -> Color:
	var text := value.strip_edges()
	if text.is_empty():
		return fallback
	if not text.begins_with("#"):
		text = "#" + text
	return Color.from_string(text, fallback)
