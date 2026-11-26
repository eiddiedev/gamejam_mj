shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float left_side = 1.0 - smoothstep(0.185, 0.338, UV.x);
	float right_side = smoothstep(0.72, 0.99, UV.x);
	float border = max(left_side, right_side);
	float lower = smoothstep(0.76, 1.07, UV.y) * 0.55;
	float upper = (1.0 - smoothstep(0.0, 0.20, UV.y)) * 0.43;
	float alpha = max(border * 0.68, max(lower, upper));
	COLOR = vec4(0.025, 0.040, 0.044, alpha);
}
