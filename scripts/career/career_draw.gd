class_name CareerDraw
extends RefCounted
# UEFA league-phase draw for both formats. UCL and UEL use four pots of nine and
# eight rounds, two opponents from each pot. UECL uses six pots of six and six
# rounds, one opponent from each pot. The slot pattern fixes the pots, the rounds
# and the home split; clubs are sorted into pots by coefficient and assigned to
# the slots so that no pair meets its own association. The country cap (at most
# two from one association) is checked and reported in last_error, but it does
# not reject the draw.

const PATTERNS := {
	"4x9": [
		[[24, 14], [11, 10], [5, 30], [20, 22], [9, 19], [29, 18], [1, 13], [17, 16], [26, 27], [21, 31], [28, 25], [34, 3], [6, 4], [12, 0], [32, 8], [15, 7], [33, 35], [2, 23]],
		[[14, 26], [13, 20], [27, 28], [25, 21], [8, 33], [7, 17], [10, 34], [22, 29], [19, 6], [30, 32], [0, 2], [4, 9], [23, 15], [35, 11], [31, 1], [16, 5], [18, 24], [3, 12]],
		[[32, 29], [3, 14], [8, 0], [31, 7], [10, 12], [35, 26], [1, 5], [4, 23], [19, 11], [9, 25], [24, 20], [27, 6], [16, 2], [21, 28], [33, 13], [22, 17], [15, 30], [34, 18]],
		[[23, 32], [5, 19], [13, 21], [18, 8], [26, 16], [6, 3], [7, 4], [30, 10], [0, 22], [20, 34], [25, 15], [11, 24], [29, 31], [12, 35], [17, 27], [14, 33], [2, 9], [28, 1]],
		[[10, 6], [19, 27], [17, 23], [31, 9], [26, 25], [18, 4], [21, 3], [11, 1], [8, 13], [29, 12], [5, 14], [16, 15], [32, 20], [33, 22], [30, 0], [24, 2], [34, 7], [28, 35]],
		[[22, 10], [23, 18], [35, 19], [27, 30], [4, 28], [20, 16], [12, 17], [9, 34], [14, 29], [13, 11], [25, 31], [15, 8], [6, 24], [2, 33], [0, 32], [1, 26], [7, 21], [3, 5]],
		[[12, 18], [34, 31], [24, 33], [23, 30], [10, 0], [9, 14], [26, 19], [22, 21], [16, 32], [27, 15], [13, 28], [17, 4], [11, 6], [35, 2], [29, 3], [25, 5], [8, 1], [7, 20]],
		[[19, 23], [21, 12], [18, 10], [2, 7], [30, 24], [33, 34], [32, 17], [28, 11], [31, 16], [15, 9], [14, 13], [6, 35], [4, 29], [5, 27], [0, 26], [3, 25], [20, 8], [1, 22]],
	],
	"6x6": [
		[[2, 0], [19, 15], [8, 14], [26, 21], [35, 22], [17, 16], [33, 10], [23, 30], [18, 7], [6, 5], [11, 13], [1, 32], [28, 34], [3, 31], [20, 29], [27, 9], [4, 24], [12, 25]],
		[[7, 6], [25, 2], [10, 8], [29, 28], [14, 26], [24, 27], [15, 1], [5, 3], [22, 23], [21, 11], [9, 19], [0, 17], [16, 20], [32, 18], [31, 12], [13, 4], [30, 33], [34, 35]],
		[[25, 31], [26, 35], [11, 0], [1, 9], [32, 16], [6, 34], [20, 19], [8, 4], [13, 21], [33, 29], [15, 12], [7, 30], [2, 18], [14, 3], [23, 5], [27, 17], [28, 10], [22, 24]],
		[[9, 32], [31, 11], [21, 33], [18, 28], [30, 14], [35, 13], [34, 2], [4, 1], [19, 25], [5, 27], [0, 26], [3, 20], [24, 8], [12, 23], [17, 22], [10, 15], [29, 6], [16, 7]],
		[[18, 14], [25, 26], [9, 11], [7, 2], [12, 6], [34, 17], [3, 29], [13, 24], [28, 16], [15, 33], [5, 35], [32, 27], [23, 10], [8, 20], [19, 31], [22, 1], [4, 21], [30, 0]],
		[[6, 22], [17, 9], [0, 19], [35, 8], [33, 4], [20, 34], [29, 15], [24, 30], [10, 3], [27, 23], [1, 28], [21, 18], [31, 32], [14, 13], [16, 5], [2, 12], [26, 7], [11, 25]],
	],
}
const FORMATS := {
	"CL": {"pattern": "4x9", "pots": 4, "size": 9},
	"EL": {"pattern": "4x9", "pots": 4, "size": 9},
	"UCOL": {"pattern": "6x6", "pots": 6, "size": 6},
}
const SIZE := 36
const ATTEMPTS := 60

static var last_error := ""
static var _neighbors: Dictionary = {}
static var _slot_pot: Dictionary = {}
static var _budget := 0


static func league_phase(catalog: TeamCatalog, club_ids: Array, seed: int,
		competition := "CL", rankings: Dictionary = {}) -> Array:
	last_error = ""
	var clubs: Array = []
	for club_id in club_ids:
		var key := str(club_id)
		if not clubs.has(key):
			clubs.append(key)
	if clubs.size() != SIZE:
		last_error = "the league phase needs 36 clubs, got %d" % clubs.size()
		return []
	var format: Dictionary = FORMATS.get(competition, FORMATS["CL"])
	var pattern_key := str(format.get("pattern", "4x9"))
	_prepare(pattern_key, int(format.get("size", 9)))
	var pots := _split_pots(clubs, int(format.get("pots", 4)),
		int(format.get("size", 9)), rankings)
	var countries := {}
	for club_id in clubs:
		countries[club_id] = str(
			catalog.career_club(int(club_id)).get("country_name", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for attempt in range(ATTEMPTS):
		var slots := _assign(pots, countries, rng, pattern_key)
		if slots.is_empty():
			continue
		var fixtures: Array = []
		for pairs in PATTERNS[pattern_key]:
			for pair in pairs:
				fixtures.append({
					"home": str(slots[int(pair[0])]),
					"away": str(slots[int(pair[1])]),
				})
		return fixtures
	last_error = "no club assignment avoids the same association"
	return []


static func _split_pots(clubs: Array, pots: int, size: int,
		rankings: Dictionary = {}) -> Array:
	var ranked: Array
	if rankings.is_empty():
		ranked = CareerCoefficients.sorted_clubs(clubs)
	else:
		ranked = clubs.duplicate()
		ranked.sort_custom(func(a: String, b: String) -> bool:
			var left := CareerCoefficients.total(rankings, a)
			var right := CareerCoefficients.total(rankings, b)
			if not is_equal_approx(left, right):
				return left > right
			return a < b)
	var result: Array = []
	for pot in range(pots):
		var group: Array = []
		for index in range(pot * size, pot * size + size):
			group.append(str(ranked[index]))
		result.append(group)
	return result


static func _assign(pots: Array, countries: Dictionary,
		rng: RandomNumberGenerator, pattern_key: String) -> Array:
	var slots: Array = []
	slots.resize(SIZE)
	slots.fill("")
	var remaining: Array = []
	for pot in range(pots.size()):
		var group: Array = (pots[pot] as Array).duplicate()
		_shuffle(group, rng)
		remaining.append(group)
	_budget = 200000
	if not _search(slots, remaining, countries, rng, pattern_key):
		return []
	var exceptions := _cap_exceptions(slots, countries, pattern_key)
	if exceptions > 0:
		last_error = "%d country-cap exceptions in the draw" % exceptions
	return slots


static func _search(slots: Array, remaining: Array, countries: Dictionary,
		rng: RandomNumberGenerator, pattern_key: String) -> bool:
	if _budget <= 0:
		return false
	_budget -= 1
	var chosen := -1
	var chosen_candidates: Array = []
	var best := 1000
	for slot in range(SIZE):
		if not str(slots[slot]).is_empty():
			continue
		var pot := int((_slot_pot[pattern_key] as Array)[slot])
		var candidates: Array = []
		for club_id in remaining[pot]:
			if _valid(str(club_id), slot, slots, countries, pattern_key):
				candidates.append(str(club_id))
		if candidates.is_empty():
			return false
		if candidates.size() < best:
			best = candidates.size()
			chosen = slot
			chosen_candidates = candidates
			if best == 1:
				break
	if chosen < 0:
		return true
	var pot_chosen := int((_slot_pot[pattern_key] as Array)[chosen])
	_shuffle(chosen_candidates, rng)
	for club_id in chosen_candidates:
		slots[chosen] = str(club_id)
		(remaining[pot_chosen] as Array).erase(str(club_id))
		if _search(slots, remaining, countries, rng, pattern_key):
			return true
		(remaining[pot_chosen] as Array).append(str(club_id))
		slots[chosen] = ""
	return false


static func _valid(club_id: String, slot: int, slots: Array,
		countries: Dictionary, pattern_key: String) -> bool:
	var country := str(countries.get(club_id, ""))
	if country.is_empty():
		return true
	for other in _neighbors[pattern_key][slot]:
		var index := int(other)
		if not str(slots[index]).is_empty() \
				and country == str(countries.get(str(slots[index]), "")):
			return false
	return true


static func _cap_exceptions(slots: Array, countries: Dictionary,
		pattern_key: String) -> int:
	var total := 0
	for slot in range(SIZE):
		var counts := {}
		for other in _neighbors[pattern_key][slot]:
			var country := str(countries.get(str(slots[int(other)]), ""))
			counts[country] = int(counts.get(country, 0)) + 1
		for value in counts.values():
			if int(value) > 2:
				total += int(value) - 2
	return total


static func _prepare(pattern_key: String, size: int) -> void:
	if _neighbors.has(pattern_key):
		return
	var neighbors: Array = []
	var pot_of: Array = []
	for slot in range(SIZE):
		neighbors.append([])
		pot_of.append(slot / size)
	for pairs in PATTERNS[pattern_key]:
		for pair in pairs:
			var first := int(pair[0])
			var second := int(pair[1])
			(neighbors[first] as Array).append(second)
			(neighbors[second] as Array).append(first)
	_neighbors[pattern_key] = neighbors
	_slot_pot[pattern_key] = pot_of


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[other]
		values[other] = value
