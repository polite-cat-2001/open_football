class_name ShellState
extends RefCounted
# Shell-wide selection state that outlives a single screen. The team selection
# screen writes here; the prematch and match-package steps read it.
#
# Kept as static state instead of an autoload so headless `-s` tests (which do
# not create autoloads) can exercise the same code path as the running game.

static var home_team: Dictionary = {}
static var away_team: Dictionary = {}
static var preview_team: Dictionary = {}


static func set_teams(home: Dictionary, away: Dictionary) -> void:
	home_team = home.duplicate(true)
	away_team = away.duplicate(true)


static func set_preview_team(team: Dictionary) -> void:
	preview_team = team.duplicate(true)


static func has_selection() -> bool:
	return not home_team.is_empty() and not away_team.is_empty()


static func clear() -> void:
	home_team.clear()
	away_team.clear()
	preview_team.clear()
