class_name ShellState
extends RefCounted
# Shell-wide selection state that outlives a single screen. The team selection
# screen writes here; the prematch screen turns the selection into a match
# package and the match scene hands it to the C++ runtime.
#
# Kept as static state instead of an autoload so headless `-s` tests (which do
# not create autoloads) can exercise the same code path as the running game.

const DEFAULT_MATCH_OPTIONS := {
	"duration": 1.0,
	"difficulty": 0.8,
	"kit_home": 1.0,
	"kit_away": 2.0,
}
const DEFAULT_CONTROLLERS := [
	{"side": "home", "kind": "keyboard", "device": 0, "name": "Keyboard"},
]

static var home_team: Dictionary = {}
static var away_team: Dictionary = {}
static var preview_team: Dictionary = {}
static var match_options: Dictionary = DEFAULT_MATCH_OPTIONS.duplicate(true)
static var match_package: Dictionary = {}
# One entry per local human: which side they play and which device they use.
# 1P today; the array shape is what the local-2P ticket extends. The default is
# a fallback for flows that skip the controller select screen; it is not a
# confirmed user choice (the screen restores only configured sides).
static var controllers: Array = DEFAULT_CONTROLLERS.duplicate(true)
static var controllers_configured := false


static func set_teams(home: Dictionary, away: Dictionary) -> void:
	home_team = home.duplicate(true)
	away_team = away.duplicate(true)
	match_package.clear()


static func set_preview_team(team: Dictionary) -> void:
	preview_team = team.duplicate(true)


static func set_match_options(options: Dictionary) -> void:
	match_options = DEFAULT_MATCH_OPTIONS.duplicate(true)
	for key in DEFAULT_MATCH_OPTIONS:
		if options.has(key):
			match_options[key] = float(options[key])


static func set_match_package(package: Dictionary) -> void:
	match_package = package.duplicate(true)


static func set_controllers(setup: Array) -> void:
	controllers.clear()
	for entry in setup:
		if entry is Dictionary:
			controllers.append((entry as Dictionary).duplicate(true))
	controllers_configured = true
	if controllers.is_empty():
		controllers = DEFAULT_CONTROLLERS.duplicate(true)


static func set_controller(index: int, entry: Dictionary) -> void:
	if index < 0:
		return
	while controllers.size() <= index:
		controllers.append(DEFAULT_CONTROLLERS[0].duplicate(true))
	controllers[index] = entry.duplicate(true)
	controllers_configured = true


static func has_package() -> bool:
	return not match_package.is_empty()


static func has_selection() -> bool:
	return not home_team.is_empty() and not away_team.is_empty()


static func clear() -> void:
	home_team.clear()
	away_team.clear()
	preview_team.clear()
	match_options = DEFAULT_MATCH_OPTIONS.duplicate(true)
	match_package.clear()
	controllers = DEFAULT_CONTROLLERS.duplicate(true)
	controllers_configured = false
