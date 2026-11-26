shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool study_enabled = false;
uniform vec2 study_wall[6];
uniform vec3 study_arch;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float depth_at(vec2 pixel) {
	return texture(scene_depth, pixel).r;
}

float study_area(vec3 point) {
	float wall_distance = 20.0;
	for (int index = 0; index < 5; index++) {
		vec2 a = study_wall[index];
		vec2 side = study_wall[index + 1] - a;
		float along = clamp(dot(point.xz - a, side) / dot(side, side), 0.0, 1.0);
		wall_distance = min(wall_distance, length(point.xz - (a + along * side)));
	}
	float wall = (1.0 - smoothstep(0.52, 0.64, wall_distance)) * smoothstep(0.13, 0.31, point.y);
	vec3 arch = abs(point - study_arch);
	float gate = (1.0 - smoothstep(0.95, 1.05, arch.x)) *
		(1.0 - smoothstep(0.29, 0.39, arch.z)) * (1.0 - smoothstep(2.18, 2.31, arch.y));
	return max(wall, gate);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = vec2(1.0) / VIEWPORT_SIZE;
	float pressure = 1.25 + sin(uv.y * 276.0 + uv.x * 13.0) * 0.19
		+ sin(uv.x * 161.0 - uv.y * 71.0) * 0.14;
	vec2 offset = pixel * pressure;
	float here = depth_at(uv);
	float right = depth_at(uv + vec2(offset.x, 0.0));
	float left = depth_at(uv - vec2(offset.x, 0.0));
	float up = depth_at(uv + vec2(0.0, offset.y));
	float down = depth_at(uv - vec2(0.0, offset.y));
	float fold = max(abs(right + left - 2.0 * here), abs(up + down - 2.0 * here));
	float ridge = max(max(right, left), max(up, down)) - here;
	float crease = smoothstep(0.00056, 0.0022, fold) * 0.45;
	float silhouette = smoothstep(0.00175, 0.0068, ridge) * 0.86;
	if (study_enabled) {
		vec4 clip = vec4(uv * 2.0 - 1.0, here * 2.0 - 1.0, 1.0);
		vec4 at = INV_PROJECTION_MATRIX * clip;
		vec3 world = (INV_VIEW_MATRIX * vec4(at.xyz / at.w, 1.0)).xyz;
		float painted = study_area(world);
		crease *= 1.0 - 0.88 * painted;
		silhouette = mix(silhouette, smoothstep(0.008, 0.016, ridge) * 0.86, painted);
	}
	float distance_softening = mix(0.62, 1.0, smoothstep(0.15, 0.65, uv.y));
	vec3 color = texture(scene_texture, uv).rgb;
	vec3 ink = mix(vec3(0.045, 0.065, 0.077), color, 0.14);
	ALBEDO = mix(color, ink, max(crease, silhouette) * distance_softening);
}
