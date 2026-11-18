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
static var _placeholder: Texture2D = null
static var _placeholder_loaded := false

# The silhouette sits 6% inside its portrait slot, like a real cut-out whose
# head does not touch the top of the frame.
const PLACEHOLDER_INSET := 0.06


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
	# Legacy media names stay keyed by the old numeric league id; the league's
	# public id is its transfermarkt code.
	var legacy_id := int(league.get("legacy_id", 0))
	if legacy_id > 0:
		var outlined := load_texture_mipmapped(
			"databases/default/images_leagues_outline/%d.png" % legacy_id)
		if outlined != null:
			return outlined
	var url := str(league.get("logo_url", ""))
	if not url.is_empty():
		var texture := load_texture("databases/default/%s" % url)
		if texture != null:
			return texture
	if legacy_id > 0:
		var imported := load_texture_mipmapped(
			"databases/default/images_leagues/%d.png" % legacy_id)
		if imported != null:
			return imported
	return orange_fallback()


static func team_logo(team: Dictionary) -> Texture2D:
	# National teams have no club emblem. Use the country flag when the row
	# carries one, otherwise their own logo file from `logo_url`
	# (databases/default/images_teams/national/<name>_logo.png).
	if str(team.get("league_id", "")) == "NAT" and int(team.get("country_id", 0)) > 0:
		var flag := country_flag({"tm_id": str(team.get("country_id", ""))})
		if usable_texture(flag) != null:
			return flag
	# Career clubs use the prototype's emblems (career_logo); the game's
	# logo_url files are not shipped in the unified data tree.
	var career_url := str(team.get("career_logo", ""))
	if not career_url.is_empty():
		var career_texture := load_texture(career_url.trim_prefix("/"))
		if career_texture != null:
			return career_texture
	var url := str(team.get("logo_url", ""))
	if not url.is_empty():
		var texture := load_texture("databases/default/%s" % url)
		if texture != null:
			return texture
	# No id-keyed fallback on purpose: those copies were made in several runs and
	# can hold another club's emblem (id 131 = Barcelona had Tacoma's). A missing
	# emblem shows the card's designed glyph instead of a wrong club.
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


static func player_placeholder() -> Texture2D:
	# Portrait fallback, ported from the prototype's PlayerPhoto.svelte: a white
	# bust mask (assets/faces is gitignored, so a missing face is normal).
	if not _placeholder_loaded:
		_placeholder_loaded = true
		_placeholder = load("res://assets/ui/portraits/player_placeholder.png")
	return _placeholder


static func draw_player_placeholder(target: CanvasItem, rect: Rect2, ink: Color) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var texture := player_placeholder()
	if texture == null:
		return
	# Cover the portrait box (real cut-outs are ~0.77 wide, the mask is square),
	# but keep a little headroom: portraits sit a touch lower than the slot top.
	var shrink := rect.size * PLACEHOLDER_INSET
	var inner := Rect2(rect.position + Vector2(shrink.x * 0.5, shrink.y), rect.size - shrink)
	var texture_size := Vector2(texture.get_size())
	var scale := maxf(inner.size.x / texture_size.x, inner.size.y / texture_size.y)
	var region := inner.size / scale
	var source := Rect2(
		Vector2((texture_size.x - region.x) * 0.5, texture_size.y - region.y),
		region)
	target.draw_texture_rect_region(texture, inner, source, ink.lerp(Color.WHITE, 0.7))


static func kit_texture(team: Dictionary, kit: int) -> Texture2D:
	var url := str(team.get("kit_url", ""))
	if url.is_empty():
		return null
	var suffix := "%02d" % kit
	var texture := load_texture("databases/default/%s_kit_%s.png" % [url, suffix])
	return texture
