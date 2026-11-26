shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float fuel : hint_range(0.0, 1.0) = 1.0;
uniform float clock = 0.0;
uniform float thickness = 1.0;

float cell_noise(vec2 p) {
	return fract(sin(dot(p, vec2(65.37, 19.28))) * 14127.9);
}

float ripple(vec2 p) {
	vec2 cell = floor(p);
	vec2 w = fract(p);
	w = w * w * (3.0 - 2.0 * w);
	return mix(mix(cell_noise(cell), cell_noise(cell + vec2(1.0, 0.0)), w.x),
		mix(cell_noise(cell + vec2(0.0, 1.0)), cell_noise(cell + vec2(1.0)), w.x), w.y);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float boundary = length(p * vec2(1.0, 1.08));
	float haze = pow(1.0 - smoothstep(0.0, 1.0, boundary), 2.0);
	float density = ripple(p * 3.7 + vec2(clock * 0.12, -clock * 0.15));
	float pulse = 0.96 + sin(clock * 7.3) * 0.06 + cos(clock * 17.0) * 0.025;
	ALBEDO = mix(vec3(0.54, 0.19, 0.108), vec3(0.91, 0.38, 0.11), haze * 0.8);
	ALPHA = haze * thickness * fuel * pulse * (0.60 + 0.40 * density);
}
