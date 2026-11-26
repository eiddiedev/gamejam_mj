shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://world/study_pencil.gdshaderinc"

uniform vec2 map_origin = vec2(303.1, 369.0);
uniform vec2 map_scale = vec2(50.0, 33.45);
uniform vec2 hearth = vec2(354.0, 402.0);
uniform vec2 watcher = vec2(354.0, 402.0);
uniform vec2 aim = vec2(1.0, 0.0);
uniform float night = 0.0;
uniform float dawn = 0.0;
uniform float fuel = 1.0;
uniform float fire_energy = 1.3;
uniform float time_elapsed = 0.0;
uniform float cone_dot = 0.8988;
uniform float beam_power = 0.0;
uniform bool mirror = false;
uniform float beam_distances[49];
uniform float mirror_distances[49];
uniform bool study_stone = false;
uniform bool study_arch = false;
varying vec3 ink_position;
varying vec3 ink_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.1))) * 43758.5453);
}

float grain(vec2 p) {
	vec2 c = floor(p);
	vec2 w = fract(p);
	w = w * w * (3.0 - 2.0 * w);
	return mix(mix(hash(c), hash(c + vec2(1, 0)), w.x),
		mix(hash(c + vec2(0, 1)), hash(c + vec2(1, 1)), w.x), w.y);
}

float torch(vec2 offset, vec2 direction, bool reflected) {
	float distance = length(offset);
	vec2 ray = normalize(offset + vec2(0.0001));
	float facing = dot(ray, direction);
	float angle = atan(direction.x * ray.y - direction.y * ray.x, facing + 0.00001);
	float index = clamp((angle / acos(cone_dot) * 0.5 + 0.5) * 48.0, 0.0, 48.0);
	int a = int(index);
	int b = min(a + 1, 48);
	float radius = reflected ? mix(mirror_distances[a], mirror_distances[b], fract(index))
		: mix(beam_distances[a], beam_distances[b], fract(index));
	return smoothstep(cone_dot, cone_dot + 0.067, facing) *
		(1.0 - smoothstep(radius * 0.75, max(1.0, radius), distance)) * smoothstep(0.0, 12.0, distance);
}

vec3 stone_wash(vec3 n, float kind, vec2 paper) {
	float pigment = grain(paper * 0.021) - 0.5;
	float cap = smoothstep(0.40, 0.86, n.y);
	vec3 face = vec3(0.263, 0.379, 0.373);
	vec3 top = vec3(0.360, 0.482, 0.451);
	if (study_arch) {
		face = mix(vec3(0.192, 0.273, 0.292), vec3(0.295, 0.386, 0.384),
			smoothstep(0.18, 0.76, abs(n.z)));
		top = vec3(0.334, 0.420, 0.403);
	}
	vec3 mass = mix(face, top, cap);
	mass += pigment * vec3(0.036, 0.057, 0.046);
	return mass * (kind < 0.94 ? 0.83 : 1.0);
}

vec3 drawn_marks(vec3 base, vec2 paper, vec2 to_fire, float flicker) {
	float frame = pencil_frame(time_elapsed);
	float group = pencil_group(paper);
	vec3 marks_here = pencil_sample(paper, group, frame);
	vec3 graphite = vec3(0.044, 0.085, 0.087);
	base = mix(base, graphite, marks_here.r * (study_arch ? 0.74 : 0.94));

	float moss = marks_here.b * smoothstep(0.22, 0.70, grain(paper * 0.38));
	base = mix(base, base * vec3(0.71, 0.98, 0.72) + vec3(0.0, 0.035, 0.0), moss * 0.80);

	float reach = 1.0 - smoothstep(100.0, 228.0, length(to_fire));
	float catch_light = marks_here.g * reach * fuel * (fire_energy / 1.3) * flicker;
	float offset_wash = texture(marks, (paper - marks_bounds.xy - vec2(0.0, 2.5)) / marks_bounds.zw).g;
	base = mix(base, vec3(0.62, 0.35, 0.17), offset_wash * reach * fuel * flicker * 0.28);
	float glint_phase = fract(time_elapsed * 0.49 + group * 0.17);
	float glint = smoothstep(0.84, 0.88, glint_phase) * (1.0 - smoothstep(0.89, 0.93, glint_phase));
	float split = step(0.65, hash(vec2(group, floor(paper.x / 5.0))));
	vec3 copper = mix(vec3(0.98, 0.49, 0.19), vec3(1.0, 0.72, 0.37), glint * split * 0.65);
	return mix(base, copper, catch_light);
}

void vertex() {
	ink_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ink_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(ink_normal);
	vec2 ground = ink_position.xz * map_scale + map_origin;
	vec2 surface = abs(n.y) > 0.58 ? ink_position.xz : vec2(ink_position.x - ink_position.z, ink_position.y);
	float paper = grain(surface * 2.4);
	float d = max(0.0, dot(n, normalize(vec3(-0.67, 0.73, 0.35))));
	float steps = 0.78 + 0.08 * smoothstep(0.22, 0.37, d) + 0.165 * smoothstep(0.58, 0.72, d);
	vec3 base = COLOR.rgb * (steps + (paper - 0.45) * 0.054);
	float kind = COLOR.a;
	vec2 drawing_point = SCREEN_UV * vec2(1280.0, 800.0);
	if (study_stone) {
		base = stone_wash(n, kind, drawing_point);
	}
	if (kind < 0.26) {
		float weeds = smoothstep(0.45, 0.67, grain(surface * 0.83 + 9.2));
		float clearing = length((ground - hearth) * vec2(0.92, 1.25));
		float moss = weeds * smoothstep(28.0, 150.0, clearing);
		base = mix(base, vec3(0.225, 0.340, 0.30), moss * 0.66);
	}
	base = mix(base, base * vec3(0.42, 0.60, 0.80), night * 0.94);

	vec2 to_fire = (ground - hearth) * vec2(0.95, 1.14);
	float radius = mix(14.0, 119.0, fuel);
	float heat = exp(-pow(length(to_fire) / radius, 2.0) - max(ink_position.y, 0.0) * 0.31) * fuel * fire_energy / 1.3;
	float flicker = 0.93 + 0.043 * sin(time_elapsed * 10.1) + 0.026 * sin(time_elapsed * 17.7);
	vec3 fire_direction = normalize(vec3(-to_fire.x / 50.0, 0.48 - ink_position.y, -to_fire.y / 33.45));
	float lit_face = 0.42 + 0.58 * max(0.0, dot(n, fire_direction));
	vec3 warmth = vec3(0.91, 0.35, 0.073);
	// The painted strokes take on the warm light while retaining their ink density.
	float scatter = (kind > 0.84 && kind < 0.87) ? 0.65 : 1.0;
	base = mix(base, base * vec3(1.32, 0.95, 0.58) + warmth * (0.29 + night * 0.24) * scatter,
		heat * lit_face * flicker);
	float rim = pow(heat, 1.16) * smoothstep(0.74, 0.98, lit_face) * (1.0 - abs(n.y));
	base += warmth * rim * flicker * 0.56 * scatter;
	if (study_stone) {
		base = drawn_marks(base, drawing_point, to_fire, flicker);
	}

	vec2 search_ray = ground - watcher;
	float lantern = torch(search_ray, aim, false);
	if (mirror) {
		lantern = max(lantern, torch(search_ray, -aim, true) * 0.70);
	}
	base += lantern * beam_power * vec3(0.29, 0.20, 0.093) * (0.45 + 0.55 * max(n.y, 0.0));
	base += dawn * vec3(0.10, 0.064, 0.029) * (0.58 + 0.42 * d);
	float distance_fog = 1.0 - smoothstep(-13.2, -4.30, ink_position.z);
	vec3 mist = mix(vec3(0.206, 0.281, 0.31), vec3(0.083, 0.14, 0.20), night);
	base = mix(base, mist, distance_fog * 0.83);
	ALBEDO = base;
}
