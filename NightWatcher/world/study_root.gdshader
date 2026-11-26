shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://world/study_pencil.gdshaderinc"

uniform vec2 map_origin = vec2(303.1, 369.0);
uniform vec2 map_scale = vec2(50.0, 33.45);
uniform vec2 hearth = vec2(354.0, 402.0);
uniform vec2 trunk = vec2(168.0, 407.0);
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

varying vec3 world_point;
varying vec3 world_normal;

float lantern_light(vec2 offset, vec2 direction, bool reflected) {
	float travel = length(offset);
	vec2 ray = normalize(offset + vec2(0.0001));
	float facing = dot(ray, direction);
	float angle = atan(direction.x * ray.y - direction.y * ray.x, facing + 0.00001);
	float index = clamp((angle / acos(cone_dot) * 0.5 + 0.5) * 48.0, 0.0, 48.0);
	int a = int(index);
	int b = min(a + 1, 48);
	float reach = reflected ? mix(mirror_distances[a], mirror_distances[b], fract(index))
		: mix(beam_distances[a], beam_distances[b], fract(index));
	return smoothstep(cone_dot, cone_dot + 0.067, facing)
		* (1.0 - smoothstep(reach * 0.75, max(1.0, reach), travel))
		* smoothstep(0.0, 12.0, travel);
}

float brush_edge(float crosswise, float width) {
	float softness = max(fwidth(crosswise) * 0.75, 0.008);
	return 1.0 - smoothstep(width, width + softness, abs(crosswise));
}

float brush_length(float along, float from, float to) {
	return smoothstep(from, from + 0.11, along) * (1.0 - smoothstep(to - 0.12, to, along));
}

float stroke_random(float frame, float seed) {
	return fract(sin(frame * 72.79 + seed * 48.91) * 13562.43);
}

float stroke_frame(float time, float seed) {
	float draw_time = time * 8.3;
	float frame = floor(draw_time);
	float next_drawing = 0.69 + 0.27 * stroke_random(frame, seed);
	return frame + step(next_drawing, fract(draw_time));
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 ground = world_point.xz * map_scale + map_origin;
	vec2 relative = (ground - trunk) / map_scale;
	vec3 root_point = vec3(relative.x, world_point.y, relative.y);
	float hi = dot(root_point, INV_VIEW_MATRIX[1].xyz);
	float lower_bark = 1.0 - smoothstep(0.76, 1.88, world_point.y);
	float pen = 1.0 - smoothstep(0.80, 0.85, COLOR.a);
	float dark_stroke = 1.0 - pen;

	float shade = max(0.0, dot(n, normalize(vec3(-0.67, 0.73, 0.35))));
	float original_shade = 0.78 + 0.08 * smoothstep(0.22, 0.37, shade)
		+ 0.165 * smoothstep(0.58, 0.72, shade);
	vec3 base = COLOR.rgb * original_shade;
	float broad_shade = smoothstep(-0.43, 0.39, n.y + n.x * 0.45);
	vec3 wash = mix(vec3(0.096, 0.143, 0.168), vec3(0.151, 0.215, 0.224), broad_shade);
	base = mix(base, wash * mix(1.0, 0.88, dark_stroke), lower_bark * 0.90);
	base = mix(base, base * vec3(0.42, 0.60, 0.80), night * 0.94);

	vec3 fire_point = vec3((hearth.x - map_origin.x) / map_scale.x, 0.48,
		(hearth.y - map_origin.y) / map_scale.y);
	vec3 fire_dir = normalize(fire_point - world_point);
	float turned_toward_fire = smoothstep(-0.15, 0.72, dot(n, fire_dir));
	float flicker = 0.93 + 0.043 * sin(time_elapsed * 10.1) + 0.026 * sin(time_elapsed * 17.7);
	float intensity = fuel * (fire_energy / 1.3) * flicker;
	float spread = 1.0 - smoothstep(1.45, 4.05, distance(fire_point, world_point));
	float wash_strength = lower_bark * spread * intensity * turned_toward_fire * pen;
	base = mix(base, vec3(0.50, 0.235, 0.092), wash_strength * 0.52);

	// The bright ridges follow the two exposed roots in the fixed play view.
	float along_root = root_point.x;
	float frame = stroke_frame(time_elapsed, 3.2);
	float left_shift = stroke_random(frame, 5.6) - 0.5;
	float right_shift = stroke_random(frame, 7.9) - 0.5;
	float drift = mix(left_shift, right_shift, smoothstep(0.58, 1.63, along_root)) * 0.027;
	float raised_root = hi - (0.36 + 0.054 * sin(along_root * 2.65) - 0.042 * along_root + drift);
	float falling_root = hi - (0.065 - along_root * 0.56 + 0.028 * sin(along_root * 15.0) - drift * 0.60);
	float breaks = max(brush_length(along_root, 0.53, 0.99), brush_length(along_root, 1.10, 1.70));
	float warm_pen = max(
		brush_edge(raised_root, 0.025) * breaks,
		brush_edge(falling_root, 0.016) * brush_length(along_root, 0.77, 1.58)
	) * (0.93 + stroke_random(frame, 12.6) * 0.07);
	vec3 view_dir = normalize(INV_VIEW_MATRIX[2].xyz);
	float edge = 1.0 - smoothstep(0.10, 0.40, abs(dot(n, view_dir)));
	float sidelight = smoothstep(0.16, 0.75, dot(n, fire_dir)) * edge;
	float gold = warm_pen * (0.47 + 0.53 * turned_toward_fire) + sidelight * breaks * 0.28;
	base = mix(base, vec3(0.94, 0.43, 0.12),
		clamp(gold * intensity * lower_bark * pen * smoothstep(0.13, 0.37, spread), 0.0, 0.86));

	// A small intermittent fire reflection stays on the drawn ridge.
	float spark_time = time_elapsed * 0.59 + 0.32;
	float spark_frame = floor(spark_time);
	float spark_phase = fract(spark_time);
	float spark_x = 0.66 + stroke_random(spark_frame, 9.5) * 0.20;
	float glint = brush_edge(along_root - spark_x, 0.009) * brush_edge(raised_root, 0.010);
	glint *= step(0.48, stroke_random(spark_frame, 16.3)) * smoothstep(0.16, 0.21, spark_phase)
		* (1.0 - smoothstep(0.23, 0.29, spark_phase));
	base = mix(base, vec3(1.0, 0.73, 0.36), glint * intensity * lower_bark * pen * spread * 0.76);
	vec2 paper = SCREEN_UV * vec2(1280.0, 800.0);
	float graphite = pencil_sample(paper, pencil_group(paper), pencil_frame(time_elapsed)).r;
	base = mix(base, vec3(0.029, 0.055, 0.061), graphite * 0.87);

	vec2 offset = ground - watcher;
	float lantern = lantern_light(offset, aim, false);
	if (mirror) {
		lantern = max(lantern, lantern_light(offset, -aim, true) * 0.70);
	}
	base += lantern * beam_power * vec3(0.29, 0.20, 0.093) * (0.45 + 0.55 * max(n.y, 0.0));
	base += dawn * vec3(0.10, 0.064, 0.029) * (0.58 + 0.42 * shade);
	ALBEDO = base;
}
