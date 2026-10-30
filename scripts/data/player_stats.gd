class_name PlayerStats
extends RefCounted
# Final player stats, ported from GameplayFootball's CalculateStat
# (src/utils.cpp) with the same development curve helpers (bluntmath).
# A player's profile_xml only describes the *shape* of the skill distribution;
# base_stat and age decide how good the player is right now.

const STAT_NAMES := [
	"physical_balance",
	"physical_reaction",
	"physical_acceleration",
	"physical_velocity",
	"physical_stamina",
	"physical_agility",
	"physical_shotpower",
	"technical_standingtackle",
	"technical_slidingtackle",
	"technical_ballcontrol",
	"technical_dribble",
	"technical_shortpass",
	"technical_highpass",
	"technical_header",
	"technical_shot",
	"technical_volley",
	"mental_calmness",
	"mental_workrate",
	"mental_resilience",
	"mental_defensivepositioning",
	"mental_offensivepositioning",
	"mental_vision",
]

const IDEAL_AGE := 27.0
const MAX_AGE_DISTANCE := 13.0
const MIN_STAT := 0.01
const MAX_STAT := 1.0
const AGE_BASE_GAIN := 1.2
const PROFILE_SPREAD := 2.0


static func calculate(base_stat: float, profile_stat: float, age: float) -> float:
	var distance := clampf(absf(age - IDEAL_AGE), 0.0, MAX_AGE_DISTANCE)
	var normalized := distance / MAX_AGE_DISTANCE
	var source := 1.0 - normalized * 0.5
	var age_factor := curve(source) * 2.0 - 1.0
	var aged_base_stat := base_stat * (age_factor * 0.5 + 0.5) * AGE_BASE_GAIN
	return clampf(profile_stat * PROFILE_SPREAD * aged_base_stat, MIN_STAT, MAX_STAT)


static func curve(source: float) -> float:
	return sin((source - 0.5) * PI) * 0.5 + 0.5


static func parse_profile(profile_xml: String) -> Dictionary:
	var profile := {}
	var cursor := 0
	while true:
		var tag_open := profile_xml.find("<", cursor)
		if tag_open < 0:
			break
		var tag_close := profile_xml.find(">", tag_open)
		if tag_close < 0:
			break
		var name := profile_xml.substr(tag_open + 1, tag_close - tag_open - 1).strip_edges()
		var value_end := profile_xml.find("<", tag_close + 1)
		if value_end < 0:
			break
		if not name.is_empty() and not name.begins_with("/"):
			profile[name] = profile_xml.substr(tag_close + 1, value_end - tag_close - 1).strip_edges().to_float()
		cursor = value_end
	return profile


static func calculate_profile(profile_xml: String, base_stat: float, age: float) -> Dictionary:
	var profile := parse_profile(profile_xml)
	var stats := {}
	for name in STAT_NAMES:
		if profile.has(name):
			stats[name] = calculate(base_stat, float(profile[name]), age)
	return stats


static func average(stats: Dictionary) -> float:
	if stats.is_empty():
		return 0.0
	var total := 0.0
	for name in STAT_NAMES:
		total += float(stats.get(name, 0.0))
	return total / float(STAT_NAMES.size())
