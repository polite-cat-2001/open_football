class_name UiIcon
extends RefCounted

# White-stroke SVG icons ported from the prototype's Glyph.svelte. Imported at
# 512px and tinted with modulate, so one texture serves every state and size.

const ICON_DIR := "res://assets/ui/icons/"

static var _textures: Dictionary = {}


static func texture(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	var path := ICON_DIR + icon_name + ".svg"
	if _textures.has(path):
		return _textures[path]
	var result := load(path) as Texture2D
	if result == null:
		push_warning("UiIcon: missing icon " + path)
	_textures[path] = result
	return result
