class_name KitTexture
extends RefCounted
# The model ships one neutral atlas (gpf_fullbody_gpf_kit.png): blue =
# shirt/sleeves/socks, white = shorts, black = unused. The runtime path applies
# kit_uv.gdshader to the gpf_kit surfaces: the shader recolours that mask and
# paints the pattern in UV space, so opening the menu does not run a per-pixel
# GDScript loop. texture_for() is the CPU fallback used by tests/tools.

const BASE_PATH := "res://assets/models/gpf_fullbody_gpf_kit.png"
const SHADER_PATH := "res://shaders/kit_uv.gdshader"
const PATTERNS := ["plain", "stripes", "halves", "hoops", "sash"]
const PATTERN_IDS := {
	"plain": 0,
	"stripes": 1,
	"halves": 2,
	"hoops": 3,
	"sash": 4,
}

static var _cache := {}
static var _materials := {}
static var _base_image: Image = null
static var _base_loaded := false
static var _base_texture: Texture2D = null
static var _shader: Shader = null
static var _shader_loaded := false


static func texture_for(kit: Dictionary) -> Texture2D:
	if kit.is_empty():
		return null
	var key := _key(kit)
	if _cache.has(key):
		return _cache[key]
	var base := _load_base()
	if base == null:
		_cache[key] = null
		return null
	var image := _generate(base, kit)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func material_for(kit: Dictionary) -> ShaderMaterial:
	if kit.is_empty():
		return null
	var key := _key(kit)
	if _materials.has(key):
		return _materials[key]
	var shader := _load_shader()
	var base := _load_base_texture()
	if shader == null or base == null:
		_materials[key] = null
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_mask", base)
	material.set_shader_parameter("shirt_color",
		_color(kit.get("shirt"), Color.WHITE))
	material.set_shader_parameter("shorts_color",
		_color(kit.get("shorts"), Color(0.96, 0.97, 0.98)))
	var pattern := str(kit.get("pattern", "plain"))
	material.set_shader_parameter("pattern", int(PATTERN_IDS.get(pattern, 0)))
	material.set_shader_parameter("pattern_color",
		_color(kit.get("pattern_color"), _color(kit.get("shirt"), Color.WHITE)))
	_materials[key] = material
	return material


static func apply_to_body(body: Node3D, kit: Dictionary) -> bool:
	var material := material_for(kit)
	if material == null:
		return apply_color_to_body(body, _color(kit.get("shirt"), Color.WHITE))
	var applied := false
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source == null or source.resource_name != "gpf_kit":
				continue
			mesh_instance.set_surface_override_material(surface, material)
			applied = true
	return applied


static func apply_color_to_body(body: Node3D, color: Color) -> bool:
	var applied := false
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface)
			if material == null or material.resource_name != "gpf_kit":
				continue
			var tinted := material.duplicate() as StandardMaterial3D
			if tinted == null:
				continue
			tinted.albedo_texture = null
			tinted.albedo_color = color
			mesh_instance.set_surface_override_material(surface, tinted)
			applied = true
	return applied


static func clear_cache() -> void:
	_cache.clear()
	_materials.clear()


static func _load_shader() -> Shader:
	if _shader_loaded:
		return _shader
	_shader_loaded = true
	_shader = load(SHADER_PATH) as Shader
	if _shader == null:
		push_warning("KitTexture: could not load " + SHADER_PATH)
	return _shader


static func _load_base_texture() -> Texture2D:
	if _base_texture != null:
		return _base_texture
	_base_texture = load(BASE_PATH) as Texture2D
	if _base_texture == null:
		push_warning("KitTexture: could not load " + BASE_PATH)
	return _base_texture


static func _load_base() -> Image:
	if _base_loaded:
		return _base_image
	_base_loaded = true
	var texture := load(BASE_PATH) as Texture2D
	if texture == null:
		push_warning("KitTexture: could not load " + BASE_PATH)
		return null
	var image := texture.get_image()
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	_base_image = image
	return _base_image


static func _generate(base: Image, kit: Dictionary) -> Image:
	var width := base.get_width()
	var height := base.get_height()
	var shirt := _color(kit.get("shirt"), Color.WHITE)
	var shorts := _color(kit.get("shorts"), Color(0.96, 0.97, 0.98))
	var pattern := str(kit.get("pattern", "plain"))
	if not PATTERNS.has(pattern):
		pattern = "plain"
	var pattern_color := _color(kit.get("pattern_color"), shirt)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var source := base.get_pixel(x, y)
			if _is_shirt(source):
				var color := shirt
				if pattern != "plain" and _pattern_on(x, y, width, height, pattern):
					color = pattern_color
				image.set_pixel(x, y, color)
			elif _is_shorts(source):
				image.set_pixel(x, y, shorts)
			else:
				image.set_pixel(x, y, Color(0.02, 0.02, 0.03, 1.0))
	image.generate_mipmaps()
	return image


static func _is_shirt(color: Color) -> bool:
	return color.b > 0.35 and color.b > color.r * 1.3 and color.b > color.g * 1.15


static func _is_shorts(color: Color) -> bool:
	return color.r > 0.7 and color.g > 0.7 and color.b > 0.7


static func _pattern_on(x: int, y: int, width: int, height: int, pattern: String) -> bool:
	match pattern:
		"stripes":
			return int(float(x) / maxf(1.0, float(width) / 10.0)) % 2 == 0
		"halves":
			return float(x % int(width / 2)) < float(width) / 4.0
		"hoops":
			return int(float(y) / maxf(1.0, float(height) / 14.0)) % 2 == 0
		"sash":
			return absf(float(x) + float(y) * 0.65 - float(width) * 0.62) < float(width) * 0.07
	return false


static func _color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	if not text.begins_with("#"):
		text = "#" + text
	return Color.from_string(text, fallback)


static func _key(kit: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		str(kit.get("shirt", "")),
		str(kit.get("shorts", "")),
		str(kit.get("pattern", "plain")),
		str(kit.get("pattern_color", "")),
	]
