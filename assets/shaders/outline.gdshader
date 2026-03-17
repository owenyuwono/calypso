shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_linear_mipmap;

uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;
uniform float depth_threshold : hint_range(0.0, 10.0) = 2.0;
uniform float normal_threshold : hint_range(0.0, 3.0) = 1.0;
uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.12, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 texel = outline_thickness / VIEWPORT_SIZE;
	vec3 screen_col = texture(screen_texture, SCREEN_UV).rgb;

	// Sobel depth edge detection
	float d_center = texture(depth_texture, SCREEN_UV).r;
	float d_top = texture(depth_texture, SCREEN_UV + vec2(0.0, texel.y)).r;
	float d_bottom = texture(depth_texture, SCREEN_UV + vec2(0.0, -texel.y)).r;
	float d_left = texture(depth_texture, SCREEN_UV + vec2(-texel.x, 0.0)).r;
	float d_right = texture(depth_texture, SCREEN_UV + vec2(texel.x, 0.0)).r;
	float d_tl = texture(depth_texture, SCREEN_UV + vec2(-texel.x, texel.y)).r;
	float d_tr = texture(depth_texture, SCREEN_UV + vec2(texel.x, texel.y)).r;
	float d_bl = texture(depth_texture, SCREEN_UV + vec2(-texel.x, -texel.y)).r;
	float d_br = texture(depth_texture, SCREEN_UV + vec2(texel.x, -texel.y)).r;

	float sobel_x = d_tl + 2.0 * d_left + d_bl - d_tr - 2.0 * d_right - d_br;
	float sobel_y = d_tl + 2.0 * d_top + d_tr - d_bl - 2.0 * d_bottom - d_br;
	float depth_edge = sqrt(sobel_x * sobel_x + sobel_y * sobel_y);
	depth_edge = step(depth_threshold * 0.001, depth_edge);

	// Normal discontinuity detection
	vec3 n_center = texture(normal_texture, SCREEN_UV).rgb * 2.0 - 1.0;
	vec3 n_top = texture(normal_texture, SCREEN_UV + vec2(0.0, texel.y)).rgb * 2.0 - 1.0;
	vec3 n_bottom = texture(normal_texture, SCREEN_UV + vec2(0.0, -texel.y)).rgb * 2.0 - 1.0;
	vec3 n_left = texture(normal_texture, SCREEN_UV + vec2(-texel.x, 0.0)).rgb * 2.0 - 1.0;
	vec3 n_right = texture(normal_texture, SCREEN_UV + vec2(texel.x, 0.0)).rgb * 2.0 - 1.0;

	float normal_diff = 0.0;
	normal_diff += 1.0 - dot(n_center, n_top);
	normal_diff += 1.0 - dot(n_center, n_bottom);
	normal_diff += 1.0 - dot(n_center, n_left);
	normal_diff += 1.0 - dot(n_center, n_right);
	float normal_edge = step(normal_threshold, normal_diff);

	float edge = max(depth_edge, normal_edge);
	ALBEDO = mix(screen_col, outline_color.rgb, edge * outline_color.a);
}
