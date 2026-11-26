shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D surface_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D relief_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 air_pigment : source_color = vec4(0.32, 0.39, 0.42, 1.0);
uniform float seconds = 0.0;

float depth_at(vec2 pixel) { return texture(relief_depth, pixel).r; }

float paper_grain(vec2 address) {
	return fract(sin(dot(address, vec2(37.84, 87.19))) * 13021.32);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 page = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float pose = floor(seconds * 7.0);
	float offset_angle = pose * 4.217 + page.x * 49.0 + page.y * 62.0;
	vec2 ink_center = page + px * vec2(cos(offset_angle), sin(offset_angle * 1.31)) * 0.44;
	float pressure = 1.46 + sin(page.y * 220.0 + page.x * 41.0) * 0.22;
	vec2 width = px * pressure;
	float depth = depth_at(ink_center);
	float east = depth_at(ink_center + vec2(width.x, 0.0));
	float west = depth_at(ink_center - vec2(width.x, 0.0));
	float south = depth_at(ink_center + vec2(0.0, width.y));
	float north = depth_at(ink_center - vec2(0.0, width.y));
	float fold = max(abs(east + west - 2.0 * depth), abs(south + north - 2.0 * depth));
	float ridge = max(max(east, west), max(south, north)) - depth;
	float crease = smoothstep(0.0010, 0.0031, fold) * 0.44;
	float silhouette = smoothstep(0.0015, 0.0052, ridge) * 0.92;
	float line = max(crease, silhouette);
	vec3 wash = texture(surface_texture, page).rgb;

	vec4 clip = vec4(page * 2.0 - 1.0, depth_at(page) * 2.0 - 1.0, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * clip;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	float distance = 1.0 - smoothstep(-15.0, -1.9, world.z);
	float low_mist = (1.0 - smoothstep(0.10, 2.7, world.y)) * distance;
	float drift = sin(world.x * 0.58 + world.z * 1.24 + seconds * 0.29) * 0.5 + 0.5;
	float haze = distance * 0.34 + low_mist * (0.11 + drift * 0.075);
	float tooth = paper_grain(floor(FRAGCOORD.xy));
	float skip = paper_grain(floor(FRAGCOORD.xy * 0.45) + vec2(pose * 17.0, pose * 2.0));
	float graphite = line * (0.86 + tooth * 0.14 - 0.22 * step(0.89, skip));
	vec3 ink = mix(vec3(0.031, 0.042, 0.048), wash, 0.19);
	vec3 painted = mix(wash, ink, graphite);
	ALBEDO = mix(painted, air_pigment.rgb, haze) * (0.988 + tooth * 0.024);
}
