shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edges = smoothstep(0.48, 1.45, length(p));
	float scan = step(0.56, fract(FRAGCOORD.y * 0.5));
	float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.004, 0.012, 0.016, 0.27 * edges + 0.085 * scan + grain * 0.047);
}
