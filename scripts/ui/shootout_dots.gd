class_name ShootoutDots
extends Control
# Series circles under the match scoreboard (ticket 10): two groups of five on
# one line, home under the home block and away under the away block. After five
# kicks a group clears for the sudden-death round (and again every five).

const CIRCLE := 16.0
const GAP := 6.0
const WIDTH := 5 * CIRCLE + 4 * GAP
const HEIGHT := CIRCLE

const COLOR_EMPTY := Color(0.964706, 0.972549, 0.984314, 0.18)
const COLOR_GOAL := Color(0.058824, 0.615686, 0.462745)
const COLOR_MISS := UiTokens.RAIL
const COLOR_BORDER := Color(0.964706, 0.972549, 0.984314, 0.35)

var home: Array[int] = [0, 0, 0, 0, 0]
var away: Array[int] = [0, 0, 0, 0, 0]
var row_lefts: Array[float] = [0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, HEIGHT)


# Each group is aligned to its own team block: the left team's group to its left
# edge, the right team's group to its right edge.
func set_row_lefts(home_x: float, away_x: float) -> void:
	row_lefts.clear()
	row_lefts.append(home_x)
	row_lefts.append(away_x)
	size.x = maxf(home_x, away_x) + WIDTH
	queue_redraw()


# Display values are 0 = not taken, 1 = goal, 2 = save/miss.
func set_results(kicks0: Array, kicks1: Array) -> void:
	home = _round(kicks0)
	away = _round(kicks1)
	queue_redraw()


func _round(kicks: Array) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0, 0]
	var base := 0
	if not kicks.is_empty():
		base = ((kicks.size() - 1) / 5) * 5
	for i in 5:
		if base + i < kicks.size():
			out[i] = int(kicks[base + i])
	return out


func _draw() -> void:
	for row in 2:
		var values: Array[int] = home if row == 0 else away
		var left := row_lefts[row]
		for i in 5:
			var colour := COLOR_EMPTY
			if values[i] == 1:
				colour = COLOR_GOAL
			elif values[i] == 2:
				colour = COLOR_MISS
			var centre := Vector2(left + i * (CIRCLE + GAP) + CIRCLE * 0.5, CIRCLE * 0.5)
			draw_circle(centre, CIRCLE * 0.5, colour)
			draw_arc(centre, CIRCLE * 0.5, 0.0, TAU, 24, COLOR_BORDER, 1.5, true)
