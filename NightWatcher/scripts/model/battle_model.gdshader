shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, fog_disabled;

uniform vec4 mist : source_color = vec4(0.29, 0.36, 0.36, 1.0);
uniform bool has_pigment_atlas = false;
uniform sampler2D pigment_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 pigment_tint : source_color = vec4(1.0);
uniform float seconds = 0.0;
varying vec3 world_point;
varying vec3 world_normal;
varying vec3 model_point;

float seed(vec2 coordinate) {
	return fract(sin(dot(coordinate, vec2(49.33, 91.77))) * 11389.73);
}

float wash(vec2 coordinate) {
	vec2 i = floor(coordinate);
	vec2 f = fract(coordinate);
	vec2 t = f * f * (3.0 - 2.0 * f);
	return mix(mix(seed(i), seed(i + vec2(1,0)), t.x),
		mix(seed(i + vec2(0,1)), seed(i + vec2(1,1)), t.x), t.y);
}

void vertex() {
	model_point = VERTEX;
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	float light = dot(normal, normalize(vec3(-0.53, 0.81, 0.37)));
	float light_band = 0.67 + 0.15 * smoothstep(0.04, 0.48, light) + 0.16 * smoothstep(0.54, 0.90, light);
	vec4 ground_pigment = COLOR;
	vec3 paper_point = world_point;
	if (has_pigment_atlas) {
		ground_pigment = vec4(texture(pigment_atlas, UV).rgb * pigment_tint.rgb, 1.0);
		paper_point = model_point;
	}
	vec2 paper = abs(normal.y) > 0.63 ? paper_point.xz : vec2(paper_point.x - paper_point.z, paper_point.y);
	float cloud = wash(paper * (ground_pigment.a < 0.40 ? 0.35 : 1.32));
	float paper_tooth = wash(paper * 24.0);
	float pigment = smoothstep(0.13, 0.85, cloud);
	vec3 paint = ground_pigment.rgb * light_band * (0.89 + 0.17 * pigment + 0.06 * paper_tooth);
	float cut = wash(paper * 1.7 + vec2(2.53, 8.86));
	if (ground_pigment.a < 0.29) {
		float dots = smoothstep(0.73, 0.92, cut) * smoothstep(0.53, 0.77, cloud);
		paint *= 1.0 - 0.26 * dots;
	} else if (ground_pigment.a > 0.92) {
		float point = floor(seconds * 8.0);
		float movement = (seed(vec2(point, floor(paper.x * 4.0))) - 0.5) * 0.019;
		float fracture = 1.0 - smoothstep(0.009, 0.022, abs(cut - 0.549 + movement));
		paint *= 1.0 - fracture * smoothstep(0.64, 0.85, cloud) * 0.37;
		vec2 pen = vec2(paper.x * 6.9 - paper.y * 2.0, paper.y * 22.0 + paper.x * 9.0);
		float hatch = 1.0 - smoothstep(0.06, 0.24, abs(fract(pen.y + cut * 0.6) - 0.5));
		hatch *= smoothstep(0.60, 0.86, wash(vec2(pen.x, pen.y * 0.065)));
		paint *= 1.0 - hatch * (1.0 - smoothstep(-0.28, 0.39, light)) * 0.23;
	}
	float haze = (1.0 - smoothstep(-14.2, -2.0, world_point.z)) * 0.41;
	ALBEDO = mix(paint, mist.rgb, haze);
	ROUGHNESS = 1.0;
}
