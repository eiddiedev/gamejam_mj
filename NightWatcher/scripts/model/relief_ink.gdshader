shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D surface_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D relief_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float seconds = 0.0;

float depth_at(vec2 pixel) { return texture(relief_depth, pixel).r; }

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 page = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float pose = floor(seconds * 8.0);
	float sway = sin(pose * 8.38 + page.x * 41.0 + page.y * 73.47) * 0.21;
	float pressure = 1.36 + sin(page.y * 278.0 + page.x * 19.0) * 0.25 + sway;
	vec2 width = px * pressure;
	float depth = depth_at(page);
	float east = depth_at(page + vec2(width.x, 0.0));
	float west = depth_at(page - vec2(width.x, 0.0));
	float south = depth_at(page + vec2(0.0, width.y));
	float north = depth_at(page - vec2(0.0, width.y));
	float fold = max(abs(east + west - 2.0 * depth), abs(south + north - 2.0 * depth));
	float ridge = max(max(east, west), max(south, north)) - depth;
	float line = max(smoothstep(0.00058, 0.0022, fold) * 0.37,
		smoothstep(0.00175, 0.0066, ridge) * 0.78);
	vec3 wash = texture(surface_texture, page).rgb;
	float border = smoothstep(0.48, 0.79, length((page - vec2(0.49, 0.45)) * vec2(1.0, 0.84)));
	vec3 bleed = (texture(surface_texture, page + px * vec2(1.4, -0.5)).rgb +
		texture(surface_texture, page + px * vec2(-1.0, 1.3)).rgb) * 0.5;
	wash = mix(wash, bleed, smoothstep(0.04, 0.41, abs(page.y - 0.46)) * 0.27);
	float pencil = fract(sin(dot(floor(FRAGCOORD.xy), vec2(126.32, 28.17))) * 38674.21);
	float broken = smoothstep(0.32, 0.90, pencil + sin(pose * 19.1 + FRAGCOORD.y * 0.77) * 0.14);
	vec3 ink = mix(vec3(0.037, 0.057, 0.064), wash, 0.34);
	ALBEDO = mix(wash, ink, line * (0.80 + 0.20 * broken)) * (1.0 - border * 0.12 + (pencil - 0.5) * 0.028);
}
