shader_type canvas_item;

// Repeating diagonal hatch used by the hero tile (115 degrees, 1.5px line
// every 17px, 9% opacity, fading in from the left).
uniform vec4 line_color : source_color = vec4(0.1137, 0.1294, 0.2196, 1.0);
uniform vec2 area = vec2(735.0, 626.0);

void fragment() {
	vec2 px = UV * area;
	float coord = px.x * 0.9063 + px.y * 0.4226;
	float line = step(mod(coord, 17.0), 1.5);
	float mask = smoothstep(0.0, 0.55, UV.x);
	COLOR = vec4(line_color.rgb, line * 0.09 * mask);
}
