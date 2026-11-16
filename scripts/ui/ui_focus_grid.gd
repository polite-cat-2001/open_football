extends RefCounted

# Directional focus over real rects, for screens whose layout is not a plain
# row/column list (bento tiles, uneven cards). Callers collect the visible,
# focusable rects and map the returned index back to their own item. Keeping
# it geometric means a moved/resized tile keeps its neighbours without a
# hand-written map drifting out of date.

const FORWARD_MIN := 8.0
const SIDEWAYS_WEIGHT := {Vector2i.LEFT: 4.0, Vector2i.RIGHT: 4.0}


# Index of the best rect in `direction`, or -1 when nothing lies that way.
# `top_px >= 0` treats anything whose top is within `top_px` of the topmost
# rect as the top row: Up from there returns -1 so the host can give focus to
# the tab strip (a tall top tile must not hop over its own centre).
static func neighbour(rects: Array[Rect2], current: Rect2, direction: Vector2i,
		top_px := -1.0) -> int:
	if rects.is_empty():
		return -1
	if direction == Vector2i.UP and top_px >= 0.0:
		var top := INF
		for rect in rects:
			top = minf(top, rect.position.y)
		if current.position.y <= top + top_px:
			return -1

	var centre := current.get_center()
	var weight: float = SIDEWAYS_WEIGHT.get(direction, 1.8)
	var best := -1
	var best_score := INF
	for index in rects.size():
		var rect := rects[index]
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var delta := rect.get_center() - centre
		var forward := 0.0
		var sideways := 0.0
		match direction:
			Vector2i.LEFT:
				forward = -delta.x
				sideways = absf(delta.y)
			Vector2i.RIGHT:
				forward = delta.x
				sideways = absf(delta.y)
			Vector2i.UP:
				forward = -delta.y
				sideways = absf(delta.x)
			_:
				forward = delta.y
				sideways = absf(delta.x)
		if forward <= FORWARD_MIN:
			continue
		var score := forward + sideways * weight
		if score < best_score:
			best_score = score
			best = index
	return best
