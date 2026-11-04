shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Recolours the neutral gpf_kit UV atlas (blue = shirt/sleeves/socks,
// white = shorts, black = unused) and paints the kit pattern in UV space.
// This replaces per-kit generated PNGs/textures, so opening the kit screen
// never has to run a 512x512 per-pixel GDScript loop.

uniform sampler2D base_mask : source_color, filter_linear_mipmap;
uniform vec4 shirt_color : source_color = vec4(1.0);
uniform vec4 shorts_color : source_color = vec4(1.0);
uniform vec4 pattern_color : source_color = vec4(1.0);
uniform int pattern = 0; // 0 plain, 1 stripes, 2 halves, 3 hoops, 4 sash

void fragment() {
	vec4 base = texture(base_mask, UV);
	// source_color textures arrive in linear space; the mask thresholds were
	// authored against the sRGB pixel values.
	vec3 srgb = pow(base.rgb, vec3(1.0 / 2.2));
	bool is_shirt = srgb.b > 0.35 && srgb.b > srgb.r * 1.3 && srgb.b > srgb.g * 1.15;
	bool is_shorts = srgb.r > 0.7 && srgb.g > 0.7 && srgb.b > 0.7;
	vec3 color = base.rgb;
	if (is_shirt) {
		color = shirt_color.rgb;
		bool on = false;
		if (pattern == 1) {
			on = mod(floor(UV.x * 10.0), 2.0) < 1.0;
		} else if (pattern == 2) {
			on = mod(UV.x, 0.5) < 0.25;
		} else if (pattern == 3) {
			on = mod(floor(UV.y * 14.0), 2.0) < 1.0;
		} else if (pattern == 4) {
			on = abs(UV.x + UV.y * 0.65 - 0.62) < 0.07;
		}
		if (on) {
			color = pattern_color.rgb;
		}
	} else if (is_shorts) {
		color = shorts_color.rgb;
	}
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
