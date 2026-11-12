class_name MatchChoiceScreen
extends MatchOverScreen
# 90:00 draw: what happens next. The host (or P1 locally) picks classic extra
# time + penalties, the series straight away, or accepts the draw.

signal option_chosen(id: String)


func _tile_specs() -> Array:
	return [
		{"name": "ClassicTile", "id": "classic", "title": "CLASSIC",
			"glyph": "resume"},
		{"name": "GoldenGoalTile", "id": "golden_goal",
			"title": "GOLDEN GOAL", "glyph": "trophy", "chip": "SOON",
			"disabled": true},
		{"name": "PenaltiesTile", "id": "penalties", "title": "PENALTIES",
			"glyph": "pitch"},
		{"name": "DrawTile", "id": "draw", "title": "DRAW", "glyph": "sides"},
	]


func _info_spec() -> Dictionary:
	return {"title": "MATCH INFO", "glyph": "tactics", "chip": "SOON"}


func _on_tile_pressed(id: String) -> void:
	if _online:
		return
	option_chosen.emit(id)


# Thin client: the host decides; the client only watches.
func _apply_online() -> void:
	for index in _tiles.size():
		_tiles[index].set_tile_disabled(_online or index == 1)
	hints.set_status("WAITING FOR HOST" if _online else "")
