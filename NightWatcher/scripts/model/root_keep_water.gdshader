shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, fog_disabled;

uniform vec4 still_water : source_color = vec4(0.25, 0.39, 0.40, 1.0);
uniform vec4 reflected_sky : source_color = vec4(0.48, 0.60, 0.59, 1.0);
uniform float seconds = 0.0;
varying vec2 water_point;

float ink_seed(vec2 coordinate) {
	return fract(sin(dot(coordinate, vec2(58.81, 31.72))) * 15237.43);
}

float pigment(vec2 coordinate) {
	vec2 corner = floor(coordinate);
	vec2 t = fract(coordinate);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(ink_seed(corner), ink_seed(corner + vec2(1.0, 0.0)), t.x),
		mix(ink_seed(corner + vec2(0.0, 1.0)), ink_seed(corner + vec2(1.0)), t.x), t.y);
}

void vertex() {
	water_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 flow = water_point + vec2(-seconds * 0.11, seconds * 0.037);
	float wash = smoothstep(0.18, 0.80, pigment(flow * vec2(0.57, 0.96)));
	vec3 water = mix(still_water.rgb * 0.86, reflected_sky.rgb, 0.28 * wash);
	float bend = pigment(flow * vec2(0.75, 1.10)) * 0.96;
	bend += sin(flow.x * 2.51 - flow.y * 0.31) * 0.29;
	vec2 strokes = vec2(flow.x * 0.81 + flow.y * 0.30, flow.y * 3.6 + bend);
	float pressure = abs(fract(strokes.y) - 0.52);
	float line = 1.0 - smoothstep(0.016, 0.042 + fwidth(strokes.y) * 0.55, pressure);
	float gaps = smoothstep(0.51, 0.83, pigment(vec2(strokes.x, floor(strokes.y) * 0.47)));
	ALBEDO = mix(water, reflected_sky.rgb, line * gaps * 0.51);
	ROUGHNESS = 1.0;
}
