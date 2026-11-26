uniform sampler2D marks : repeat_disable, filter_linear;
uniform vec4 marks_bounds;

float pencil_random(vec2 at) {
	return fract(sin(dot(at, vec2(41.7, 289.1))) * 43758.5453);
}

float pencil_group(vec2 paper) {
	return floor((paper.x + paper.y * 0.53) / 56.0);
}

float pencil_frame(float time) {
	float clock = time * 8.0;
	float frame = floor(clock);
	return frame + step(0.70 + pencil_random(vec2(frame, 8.74)) * 0.25, fract(clock));
}

vec3 pencil_sample(vec2 paper, float group, float frame) {
	vec2 drift = vec2(pencil_random(vec2(group + 2.1, frame)),
		pencil_random(vec2(group + 9.3, frame))) - 0.5;
	vec2 page = (paper - marks_bounds.xy + drift * 1.56) / marks_bounds.zw;
	vec3 marks_here = texture(marks, page).rgb;
	float grain = pencil_random(floor(paper * 1.3));
	marks_here.r *= (0.66 + 0.34 * grain) * (0.90 + pencil_random(vec2(group, frame + 3.6)) * 0.10);
	return marks_here;
}
