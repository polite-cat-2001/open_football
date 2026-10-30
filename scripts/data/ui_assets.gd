class_name UiAssets
extends RefCounted
# Data-driven images for the ported menu UI (team crests, league logos, country
# flags, kits). The original loads these straight from the GameplayFootball data
# tree; Godot is not asked to import thousands of tiny PNGs, so they are read at
# runtime and cached.

static var _textures := {}
static var _data_root := ""
static var _fallback: Texture2D = null
static var _fallback_loaded := false


static func data_root() -> String:
	if _data_root.is_empty():
		_data_root = TeamCatalog.new().resolve_data_root()
	return _data_root


static func load_texture(relative_path: String) -> Texture2D:
	if relative_path.is_empty():
		return null
	var path := data_root().path_join(relative_path)
	if _textures.has(path):
		return _textures[path]
	if not FileAccess.file_exists(path):
		_textures[path] = null
		return null
	var image := Image.new()
	if image.load(path) != OK:
		_textures[path] = null
		return null
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture


static func orange_fallback() -> Texture2D:
	if _fallback_loaded:
		return _fallback
	_fallback_loaded = true
	_fallback = load_texture("media/textures/orange.jpg")
	return _fallback


static func national_icon() -> Texture2D:
	return load_texture("media/textures/nationalteams.png")


static func country_flag(country: Dictionary) -> Texture2D:
	var tm_id := str(country.get("tm_id", ""))
	if not tm_id.is_empty():
		var texture := load_texture("databases/default/images_countries/%s.png" % tm_id)
		if texture != null:
			return texture
	return orange_fallback()


static func league_logo(league: Dictionary) -> Texture2D:
	var url := str(league.get("logo_url", ""))
	if not url.is_empty():
		var texture := load_texture("databases/default/%s" % url)
		if texture != null:
			return texture
	return orange_fallback()


static func team_logo(team: Dictionary) -> Texture2D:
	var url := str(team.get("logo_url", ""))
	if not url.is_empty():
		var texture := load_texture("databases/default/%s" % url)
		if texture != null:
			return texture
	return orange_fallback()


static func kit_texture(team: Dictionary, kit: int) -> Texture2D:
	var url := str(team.get("kit_url", ""))
	if url.is_empty():
		return null
	var suffix := "%02d" % kit
	var texture := load_texture("databases/default/%s_kit_%s.png" % [url, suffix])
	return texture
