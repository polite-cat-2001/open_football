shader_type canvas_item;

// Three stacked scrim layers from the prototype's .stage::after:
// vertical gradient, radial vignette, flat blue tint.

vec4 over(vec4 top, vec4 bottom) {
	float a = top.a + bottom.a * (1.0 - top.a);
	vec3 c = top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a);
	return vec4(c / max(a, 0.0001), a);
}

void fragment() {
	vec2 uv = UV;

	vec3 top_color = vec3(9.0, 16.0, 38.0) / 255.0;
	vec3 bottom_color = vec3(6.0, 12.0, 26.0) / 255.0;
	vec3 vertical_color;
	float vertical_alpha;
	if (uv.y < 0.4) {
		float t = uv.y / 0.4;
		vertical_color = top_color;
		vertical_alpha = mix(0.5, 0.0, t);
	} else {
		float t = (uv.y - 0.4) / 0.6;
		vertical_color = mix(top_color, bottom_color, t);
		vertical_alpha = mix(0.0, 0.46, t);
	}
	vec4 vertical = vec4(vertical_color, vertical_alpha);

	vec2 radial_uv = (uv - vec2(0.5, 0.45)) / vec2(1.2, 0.9);
	float radial_distance = length(radial_uv);
	vec4 radial = vec4(bottom_color, smoothstep(0.36, 1.0, radial_distance) * 0.5);

	vec4 flat_tint = vec4(vec3(24.0, 34.0, 80.0) / 255.0, 0.16);

	COLOR = over(vertical, over(radial, flat_tint));
}
