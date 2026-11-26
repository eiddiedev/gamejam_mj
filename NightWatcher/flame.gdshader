shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float t = 0.0;
uniform float fuel = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

float tongue(vec2 p, float seed, float spread, float start, float end) {
	float h = clamp(p.y / end, 0.0, 1.0);
	float center = start * (1.0 - h * 0.62);
	center += (noise(vec2(seed + p.y * 7.2, t * 4.1)) - 0.5) * h * 0.23;
	float envelope = pow(1.0 - h, 0.74) * spread;
	float x = abs(p.x - center);
	float sides = 1.0 - smoothstep(envelope - 0.036, envelope + 0.024, x);
	return sides * (1.0 - smoothstep(0.89, 1.0, h)) * smoothstep(-0.025, 0.075, p.y);
}

void vertex() {
	// Offset the view-facing sheet so its lowest flame lands on the glowing wood.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.y += 0.35;
}

void fragment() {
	float y = (0.91 - UV.y) / mix(0.56, 1.0, fuel);
	vec2 p = vec2(UV.x - 0.5, y);

	float middle = tongue(p, 1.2, 0.19, -0.030, 0.68 + noise(vec2(t * 5.0, 2.0)) * 0.17);
	float right = tongue(p, 2.0, 0.15, 0.12, 0.54 + noise(vec2(t * 6.3, 9.0)) * 0.11);
	float left = tongue(p, 3.0, 0.14, -0.15, 0.45 + noise(vec2(t * 6.2, 13.0)) * 0.17);
	float intensity = max(middle, max(right, left));
	float core = tongue(p, 1.2, 0.095, -0.026, 0.43);
	vec3 perimeter = vec3(0.85, 0.27, 0.08);
	vec3 bright = vec3(1.0, 0.57, 0.22);
	vec3 color = mix(perimeter, bright, smoothstep(0.16, 0.84, intensity));
	color = mix(color, vec3(1.0, 0.78, 0.43), core * 0.84);
	ALBEDO = color;
	ALPHA = intensity * smoothstep(0.0, 0.21, fuel);
}
