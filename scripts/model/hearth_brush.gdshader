shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform bool accent = false;
uniform float fuel : hint_range(0.0, 1.0) = 1.0;
uniform float intensity = 1.0;
uniform vec4 amber : source_color = vec4(0.88, 0.47, 0.23, 1.0);
uniform vec4 ember : source_color = vec4(0.98, 0.64, 0.32, 1.0);

float tooth(vec2 uv) {
	return fract(sin(dot(uv, vec2(29.11, 71.77))) * 4096.12);
}

void fragment() {
	if (accent) {
		ALBEDO = ember.rgb;
		ALPHA = COLOR.a * fuel * intensity;
	} else {
		vec2 paper = (UV - vec2(0.5)) * 2.0;
		float grain = tooth(floor(UV * vec2(544.0, 346.0)));
		float edge = sin(10.0 * paper.x + 6.0 * paper.y) * 0.059;
		edge += cos(17.0 * paper.y - 5.4 * paper.x) * 0.036;
		float reach = mix(0.44, 1.0, sqrt(fuel));
		float distance = length(paper * vec2(0.95, 1.08) + vec2(-0.03, 0.02)) / reach;
		distance += edge * smoothstep(0.15, 0.62, distance);
		float center = pow(clamp(1.0 - distance, 0.0, 1.0), 1.72);
		float halo = 1.0 - smoothstep(0.34, 0.94, distance);
		ALBEDO = mix(amber.rgb, ember.rgb, center * 0.70);
		ALPHA = (0.53 * center + 0.098 * halo) * (0.88 + grain * 0.22) * fuel * intensity;
	}
}
