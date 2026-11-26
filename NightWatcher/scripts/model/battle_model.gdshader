shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, fog_disabled;

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
	float light_band = mix(0.77, 0.99, smoothstep(0.18, 0.57, light));
	vec4 ground_pigment = COLOR;
	vec3 paper_point = world_point;
	if (has_pigment_atlas) {
		ground_pigment = vec4(texture(pigment_atlas, UV).rgb * pigment_tint.rgb, 1.0);
		paper_point = model_point;
	}
	// A continuous projection keeps soft pigment across rounded edges and folds.
	vec2 paper = vec2(paper_point.x + paper_point.z * 0.31, paper_point.y + paper_point.z * 0.58);
	float pigment_scale = ground_pigment.a < 0.40 ? 0.39 : 0.82;
	float cloud = wash(paper * pigment_scale);
	float pools = smoothstep(0.28, 0.72, cloud);
	vec3 paint = ground_pigment.rgb * light_band * mix(0.89, 1.075, pools);
	float cut = wash(paper * 1.60 + vec2(2.53, 8.86));
	if (ground_pigment.a < 0.29) {
		float dots = smoothstep(0.73, 0.92, cut) * smoothstep(0.53, 0.77, cloud);
		paint *= 1.0 - 0.26 * dots;
	} else if (ground_pigment.a > 0.92) {
		float point = floor(seconds * 8.0);
		float movement = (seed(vec2(point, floor(paper.x * 2.4))) - 0.5) * 0.012;
		float fracture = 1.0 - smoothstep(0.005, 0.019, abs(cut - 0.549 + movement));
		paint *= 1.0 - fracture * smoothstep(0.62, 0.81, cloud) * 0.40;
		vec2 pen = vec2(paper.x * 3.8 - paper.y * 1.2, paper.y * 15.5 + paper.x * 6.9);
		float strokes = abs(fract(pen.y + cut * 0.52) - 0.5);
		float hatch = 1.0 - smoothstep(0.035, 0.16 + min(fwidth(pen.y) * 0.4, 0.13), strokes);
		hatch *= smoothstep(0.62, 0.81, wash(vec2(pen.x, pen.y * 0.086)));
		paint *= 1.0 - hatch * (1.0 - smoothstep(-0.12, 0.32, light)) * 0.23;
	}
	ALBEDO = paint;
	ROUGHNESS = 1.0;
}
