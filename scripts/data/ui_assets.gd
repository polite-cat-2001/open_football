class_name UiAssets
extends RefCounted
# Data-driven images for the ported menu UI (team crests, league logos, country
# flags, kits). The original loads these straight from the GameplayFootball data
# tree; Godot is not asked to import thousands of tiny PNGs, so they are read at
# runtime and cached.

static var _textures := {}
static var _mipmapped_textures := {}
static var _faces := {}
static var _face_root := ""
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


static func load_texture_mipmapped(relative_path: String) -> Texture2D:
	if relative_path.is_empty():
		return null
	var path := data_root().path_join(relative_path)
	if _mipmapped_textures.has(path):
		return _mipmapped_textures[path]
	if not FileAccess.file_exists(path):
		_mipmapped_textures[path] = null
		return null
	var image := Image.new()
	if image.load(path) != OK:
		_mipmapped_textures[path] = null
		return null
	image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_mipmapped_textures[path] = texture
	return texture


static func orange_fallback() -> Texture2D:
	if _fallback_loaded:
		return _fallback
	_fallback_loaded = true
	_fallback = load_texture("media/textures/orange.jpg")
	return _fallback


static func national_icon() -> Texture2D:
	return load_texture("media/textures/nationalteams.png")


static func usable_texture(texture: Texture2D) -> Texture2D:
	# When a specific image is missing the data tree returns the original orange
	# placeholder; the design-system cards prefer their glyph fallback
	# (globe/shirt), so treat that placeholder as "no image".
	if texture == null:
		return null
	var fallback := orange_fallback()
	if fallback != null and texture == fallback:
		return null
	return texture


static func country_flag(country: Dictionary) -> Texture2D:
	var tm_id := str(country.get("tm_id", ""))
	if not tm_id.is_empty():
		var texture := load_texture("databases/default/images_countries/%s.png" % tm_id)
		if texture != null:
			return texture
	return orange_fallback()


static func league_logo(league: Dictionary) -> Texture2D:
	var league_id := int(league.get("id", 0))
	if league_id > 0:
		var outlined := load_texture_mipmapped(
			"databases/default/images_leagues_outline/%d.png" % league_id)
		if outlined != null:
			return outlined
	var url := str(league.get("logo_url", ""))
	if not url.is_empty():
		var texture := load_texture("databases/default/%s" % url)
		if texture != null:
			return texture
	if league_id > 0:
		var imported := load_texture_mipmapped(
			"databases/default/images_leagues/%d.png" % league_id)
		if imported != null:
			return imported
	return orange_fallback()


static func team_logo(team: Dictionary) -> Texture2D:
	var url := str(team.get("logo_url", ""))
	if not url.is_empty():
		var texture := load_texture("databases/default/%s" % url)
		if texture != null:
			return texture
	var team_id := int(team.get("id", 0))
	if team_id > 0:
		var imported := load_texture("databases/default/images_teams/%d.png" % team_id)
		if imported != null:
			return imported
	return orange_fallback()


static func player_face(tm_id: int) -> Texture2D:
	# Player portraits live under res://assets/faces, which is gitignored and
	# marked .gdignore so Godot never imports the 60k source PNGs. Read them as
	# raw images and cache the resulting textures.
	if tm_id <= 0:
		return null
	if _face_root.is_empty():
		_face_root = ProjectSettings.globalize_path("res://assets/faces")
	var path := _face_root.path_join("%d.png" % tm_id)
	if _faces.has(path):
		return _faces[path]
	if not FileAccess.file_exists(path):
		_faces[path] = null
		return null
	var image := Image.new()
	if image.load(path) != OK:
		_faces[path] = null
		return null
	var texture := ImageTexture.create_from_image(image)
	_faces[path] = texture
	return texture


static func kit_texture(team: Dictionary, kit: int) -> Texture2D:
	var url := str(team.get("kit_url", ""))
	if url.is_empty():
		return null
	var suffix := "%02d" % kit
	var texture := load_texture("databases/default/%s_kit_%s.png" % [url, suffix])
	return texture
