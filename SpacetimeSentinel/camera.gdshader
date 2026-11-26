shader_type canvas_item;
render_mode unshaded;

uniform bool preserved = false;
uniform bool contact = false;
uniform float signal_clock = 0.0;
uniform sampler2D clean_view : filter_nearest, repeat_disable;
uniform float cut_progress = 0.0;

void fragment() {
	float field = floor(UV.y * 97.0);
	float salt = fract(sin(field * 175.5 + floor(signal_clock * 18.0) * 5.96) * 43758.54);
	float disturbance = contact ? 0.94 : 0.985;
	float jitter = step(disturbance, salt) * (salt - 0.96) * 0.15;
	vec2 point = vec2(clamp(UV.x + jitter, 0.001, 0.999), UV.y);
	vec3 sample_color = texture(TEXTURE, point).rgb;
	if (cut_progress > 0.0) {
		vec3 restored = texture(clean_view, point).rgb;
		vec2 cell = floor(point * vec2(171.0, 118.0));
		float spark = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.54);
		float reveal = smoothstep(spark - 0.15, spark + 0.05, cut_progress);
		float cut_edge = max(0.0, 1.0 - abs(spark - cut_progress) / 0.09);
		float changed = smoothstep(0.06, 0.38, length(sample_color - restored));
		sample_color = mix(sample_color, restored, reveal) + vec3(0.25, 0.17, 0.12) * cut_edge * changed;
	}
	float stripe = 1.0 - smoothstep(0.007, 0.080, abs(UV.y - fract(signal_clock * 0.18)));
	float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) * 0.026;
	vec3 tone = preserved ? vec3(0.82, 1.0, 0.94) : vec3(0.89, 0.96, 1.05);
	COLOR = vec4(sample_color * tone * (0.94 + 0.07 * stripe) + grain, 1.0);
}
