class_name MatchResultScreen
extends MatchOverScreen
# Match result: ADVANCE (main menu) and RESTART MATCH are live; highlights and
# performance are SOON placeholders, as is the right-hand info panel.

signal advance_requested
signal restart_requested


func _tile_specs() -> Array:
	return [
		{"name": "AdvanceTile", "id": "advance", "title": "ADVANCE",
			"glyph": "exit"},
		{"name": "RestartTile", "id": "restart", "title": "RESTART MATCH",
			"glyph": "resume"},
		{"name": "HighlightsTile", "id": "highlights",
			"title": "MATCH HIGHLIGHTS", "glyph": "replay", "chip": "SOON",
			"disabled": true},
		{"name": "PerformanceTile", "id": "performance", "title": "PERFORMANCE",
			"glyph": "skills", "chip": "SOON", "disabled": true},
	]


func _info_spec() -> Dictionary:
	return {"title": "PLAYER PERFORMANCE", "glyph": "ratings", "chip": "SOON"}


func _on_tile_pressed(id: String) -> void:
	if id == "advance":
		advance_requested.emit()
	elif id == "restart":
		restart_requested.emit()


# A LAN rematch must go back through the network lobby, so the local restart is
# shown but dead instead of desyncing the peers.
func _apply_online() -> void:
	if _tiles.size() < 2:
		return
	var restart := _tiles[1]
	restart.set_page("RESTART MATCH", "resume",
		"ONLINE LOBBY" if _online else "")
	restart.set_tile_disabled(_online)
