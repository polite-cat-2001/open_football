class_name CareerDraw
extends RefCounted
# UEFA league-phase draw. The slot pattern is fixed: eight rounds, every slot
# meets two slots from each pot, four at home and four away, and no pair repeats.
# The clubs are sorted into four pots of nine by coefficient and then assigned to
# the slots inside their pot so that no pair meets its own association and no club
# meets more than two from any other association. The club assignment is the only
# random part, seeded by the career, so the same seed repeats the draw.

const SIZE := 36
const POTS := 4
const ATTEMPTS := 60
const PATTERN := [
	[[24, 14], [11, 10], [5, 30], [20, 22], [9, 19], [29, 18], [1, 13], [17, 16], [26, 27], [21, 31], [28, 25], [34, 3], [6, 4], [12, 0], [32, 8], [15, 7], [33, 35], [2, 23]],
	[[14, 26], [13, 20], [27, 28], [25, 21], [8, 33], [7, 17], [10, 34], [22, 29], [19, 6], [30, 32], [0, 2], [4, 9], [23, 15], [35, 11], [31, 1], [16, 5], [18, 24], [3, 12]],
	[[32, 29], [3, 14], [8, 0], [31, 7], [10, 12], [35, 26], [1, 5], [4, 23], [19, 11], [9, 25], [24, 20], [27, 6], [16, 2], [21, 28], [33, 13], [22, 17], [15, 30], [34, 18]],
	[[23, 32], [5, 19], [13, 21], [18, 8], [26, 16], [6, 3], [7, 4], [30, 10], [0, 22], [20, 34], [25, 15], [11, 24], [29, 31], [12, 35], [17, 27], [14, 33], [2, 9], [28, 1]],
	[[10, 6], [19, 27], [17, 23], [31, 9], [26, 25], [18, 4], [21, 3], [11, 1], [8, 13], [29, 12], [5, 14], [16, 15], [32, 20], [33, 22], [30, 0], [24, 2], [34, 7], [28, 35]],
	[[22, 10], [23, 18], [35, 19], [27, 30], [4, 28], [20, 16], [12, 17], [9, 34], [14, 29], [13, 11], [25, 31], [15, 8], [6, 24], [2, 33], [0, 32], [1, 26], [7, 21], [3, 5]],
	[[12, 18], [34, 31], [24, 33], [23, 30], [10, 0], [9, 14], [26, 19], [22, 21], [16, 32], [27, 15], [13, 28], [17, 4], [11, 6], [35, 2], [29, 3], [25, 5], [8, 1], [7, 20]],
	[[19, 23], [21, 12], [18, 10], [2, 7], [30, 24], [33, 34], [32, 17], [28, 11], [31, 16], [15, 9], [14, 13], [6, 35], [4, 29], [5, 27], [0, 26], [3, 25], [20, 8], [1, 22]],
]

static var last_error := ""
static var _neighbors: Array = []
static var _budget := 0


static func league_phase(catalog: TeamCatalog, club_ids: Array, seed: int) -> Array:
	last_error = ""
	var clubs: Array = []
	for club_id in club_ids:
		var key := str(club_id)
		if not clubs.has(key):
			clubs.append(key)
	if clubs.size() != SIZE:
		last_error = "the league phase needs 36 clubs, got %d" % clubs.size()
		return []
	if _neighbors.is_empty():
		_build_neighbors()
	var pots := _split_pots(clubs)
	var countries := {}
	for club_id in clubs:
		countries[club_id] = str(
			catalog.career_club(int(club_id)).get("country_name", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for attempt in range(ATTEMPTS):
		var slots := _assign(pots, countries, rng)
		if slots.is_empty():
			continue
		var fixtures: Array = []
		for pairs in PATTERN:
			for pair in pairs:
				fixtures.append({
					"home": str(slots[int(pair[0])]),
					"away": str(slots[int(pair[1])]),
				})
		return fixtures
	last_error = "no club assignment avoids the same association"
	return []


static func _split_pots(clubs: Array) -> Array:
	var ranked := CareerCoefficients.sorted_clubs(clubs)
	var pots: Array = []
	for pot in range(POTS):
		var group: Array = []
		for index in range(pot * 9, pot * 9 + 9):
			group.append(str(ranked[index]))
		pots.append(group)
	return pots


static func _assign(pots: Array, countries: Dictionary,
		rng: RandomNumberGenerator) -> Array:
	var slots: Array = []
	slots.resize(SIZE)
	slots.fill("")
	var remaining: Array = []
	for pot in range(POTS):
		var group: Array = (pots[pot] as Array).duplicate()
		_shuffle(group, rng)
		remaining.append(group)
	_budget = 200000
	if not _search(slots, remaining, countries, rng):
		return []
	var exceptions := _cap_exceptions(slots, countries)
	if exceptions > 0:
		last_error = "%d country-cap exceptions in the draw" % exceptions
	return slots


static func _search(slots: Array, remaining: Array, countries: Dictionary,
		rng: RandomNumberGenerator) -> bool:
	if _budget <= 0:
		return false
	_budget -= 1
	var chosen := -1
	var chosen_candidates: Array = []
	var best := 1000
	for slot in range(SIZE):
		if not str(slots[slot]).is_empty():
			continue
		var pot := slot / 9
		var candidates: Array = []
		for club_id in remaining[pot]:
			if _valid(str(club_id), slot, slots, countries):
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
	var pot_chosen := chosen / 9
	_shuffle(chosen_candidates, rng)
	for club_id in chosen_candidates:
		slots[chosen] = str(club_id)
		(remaining[pot_chosen] as Array).erase(str(club_id))
		if _search(slots, remaining, countries, rng):
			return true
		(remaining[pot_chosen] as Array).append(str(club_id))
		slots[chosen] = ""
	return false


static func _valid(club_id: String, slot: int, slots: Array,
		countries: Dictionary) -> bool:
	var country := str(countries.get(club_id, ""))
	if country.is_empty():
		return true
	for other in _neighbors[slot]:
		var index := int(other)
		if not str(slots[index]).is_empty() \
				and country == str(countries.get(str(slots[index]), "")):
			return false
	return true


static func _cap_exceptions(slots: Array, countries: Dictionary) -> int:
	var total := 0
	for slot in range(SIZE):
		var counts := {}
		for other in _neighbors[slot]:
			var country := str(countries.get(str(slots[int(other)]), ""))
			counts[country] = int(counts.get(country, 0)) + 1
		for value in counts.values():
			if int(value) > 2:
				total += int(value) - 2
	return total


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[other]
		values[other] = value


static func _build_neighbors() -> void:
	_neighbors = []
	for slot in range(SIZE):
		_neighbors.append([])
	for pairs in PATTERN:
		for pair in pairs:
			var first := int(pair[0])
			var second := int(pair[1])
			(_neighbors[first] as Array).append(second)
			(_neighbors[second] as Array).append(first)
