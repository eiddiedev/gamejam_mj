shader_type canvas_item;
render_mode unshaded;

varying vec4 tint;

void cubic_axis(float f, out vec3 weights, out vec3 positions) {
	float f2 = f * f;
	float outer_left = -0.5 * f + f2 * (1.0 - 0.5 * f);
	float inner_left = 1.0 + f2 * (1.5 * f - 2.5);
	float inner_right = 0.5 * f + f2 * (2.0 - 1.5 * f);
	float outer_right = f2 * (0.5 * f - 0.5);
	weights = vec3(outer_left, inner_left + inner_right, outer_right);
	positions = vec3(-1.0, inner_right / weights.y, 2.0);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 footprint = fwidth(UV) / texel;
	float focus = 1.0 - smoothstep(0.65, 1.0, max(footprint.x, footprint.y));
	if (focus > 0.001) {
		vec2 grid = UV / texel - vec2(0.5);
		vec2 center = floor(grid) + vec2(0.5);
		vec3 wx, wy, xs, ys;
		cubic_axis(fract(grid.x), wx, xs);
		cubic_axis(fract(grid.y), wy, ys);
		vec3 ink = vec3(0.0);
		for (int row = 0; row < 3; row++) {
			for (int column = 0; column < 3; column++) {
				vec2 address = (center + vec2(xs[column], ys[row])) * texel;
				ink += textureLod(TEXTURE, address, 0.0).rgb * wx[column] * wy[row];
			}
		}
		paper.rgb += clamp(ink - paper.rgb, vec3(-0.045), vec3(0.036)) * focus;
	}
	COLOR = paper * tint;
}
