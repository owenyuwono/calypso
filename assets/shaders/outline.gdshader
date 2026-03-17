shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;
uniform float depth_threshold : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.12, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 texel = outline_thickness / VIEWPORT_SIZE;
	vec3 screen_col = texture(screen_texture, SCREEN_UV).rgb;

	// Cross-pattern depth edge detection (4 samples instead of 9)
	float d_top = texture(depth_texture, SCREEN_UV + vec2(0.0, texel.y)).r;
	float d_bottom = texture(depth_texture, SCREEN_UV + vec2(0.0, -texel.y)).r;
	float d_left = texture(depth_texture, SCREEN_UV + vec2(-texel.x, 0.0)).r;
	float d_right = texture(depth_texture, SCREEN_UV + vec2(texel.x, 0.0)).r;
	float depth_edge = abs(d_top - d_bottom) + abs(d_left - d_right);
	depth_edge = step(depth_threshold * 0.0001, depth_edge);

	float edge = depth_edge;
	ALBEDO = mix(screen_col, outline_color.rgb, edge * outline_color.a);
}
