shader_type canvas_item;
render_mode unshaded;
uniform bool contact = false;

void fragment() {
	vec2 surface = UV * vec2(1.1, 0.82);
	float beam = pow(max(0.0, 1.0 - length(surface - vec2(0.42, 0.26))), 2.0);
	float grid = max(step(0.97, fract(UV.x * 26.0)), step(0.97, fract(UV.y * 12.0)));
	float foil = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 low = vec3(0.031, 0.052, 0.060);
	vec3 tone = contact ? vec3(0.029, 0.051, 0.066) : vec3(0.058, 0.085, 0.099);
	COLOR = vec4(low + tone * beam + grid * 0.007 + foil * 0.011, 1.0);
}
