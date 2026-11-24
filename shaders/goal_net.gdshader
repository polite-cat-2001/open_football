shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Goal net: the NetSim cloth is a deforming triangle grid whose vertices arrive
// without normals. Derive one normal per triangle from screen derivatives (flat
// shading, like the original C++ net) and face it to the camera, so a pocket and
// both sides of the net take the light instead of a per-preset tint.
//
// The original netting texture is a 1-px thread on a 32-px tile; minified that
// breaks into dashes, so the thread is a procedural grid whose width grows with
// the on-screen cell size. The net stays continuous at any distance and turns
// denser at grazing angles, like real netting.

uniform vec4 net_tint : source_color = vec4(1.0);
uniform float net_thread : hint_range(0.0, 0.1) = 0.03125;

void fragment() {
	vec3 view_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(view_normal, VERTEX) > 0.0) {
		view_normal = -view_normal;
	}
	NORMAL = normalize((INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz);

	vec2 fw = fwidth(UV);
	vec2 half_thread = max(vec2(net_thread * 0.5), 0.35 * fw);
	vec2 cell = abs(fract(UV) - 0.5);
	vec2 cover = 1.0 - smoothstep(half_thread - 0.5 * fw, half_thread + 0.5 * fw, cell);
	ALBEDO = net_tint.rgb;
	ALPHA = max(cover.x, cover.y) * net_tint.a;
	ROUGHNESS = 0.9;
}
