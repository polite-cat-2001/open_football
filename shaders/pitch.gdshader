shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// C++ generated macro pitch maps + a world-space grass detail layer. The detail
// fades out once its texels shrink below a pixel, so the repeated tile can
// never turn into a moire grid at the broadcast or stadium camera.

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 pitch_tint : source_color = vec4(1.0);
uniform float pitch_roughness : hint_range(0.0, 1.0) = 0.95;
uniform float detail_meters = 2.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.7;
uniform float pitch_normal_strength : hint_range(0.0, 1.5) = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = texture(albedo_map, UV).rgb;
	vec3 macro_normal = texture(normal_map, UV).rgb * 2.0 - 1.0;
	macro_normal.xy *= pitch_normal_strength;
	NORMAL_MAP = normalize(macro_normal) * 0.5 + 0.5;
	// Grass is matte; the raw maps alone leave a glossy sun highlight.
	ROUGHNESS = clamp(texture(roughness_map, UV).r + 0.1, 0.0, 1.0) * pitch_roughness;
	SPECULAR = 0.25;

	// Same axes as UV1, world locked so the tile does not swim.
	vec2 detail_uv = vec2(world_pos.x, -world_pos.z) / detail_meters;
	vec2 texels_per_pixel = max(abs(dFdx(detail_uv)), abs(dFdy(detail_uv)))
		* float(textureSize(detail_albedo, 0).x);
	float amount = detail_strength
		* (1.0 - smoothstep(1.2, 3.2, max(texels_per_pixel.x, texels_per_pixel.y)));
	if (amount > 0.001) {
		vec3 detail_color = texture(detail_albedo, detail_uv).rgb;
		vec3 detail_n = texture(detail_normal, detail_uv).rgb * 2.0 - 1.0;
		ALBEDO = mix(ALBEDO, detail_color, amount);
		NORMAL_MAP = normalize(mix(NORMAL_MAP * 2.0 - 1.0, detail_n, amount)) * 0.5 + 0.5;
	}
	ALBEDO *= pitch_tint.rgb;
}
