shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform sampler2D texture_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_stone : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_pavement : hint_range(0.05, 5.0) = 0.12;
uniform float uv_scale_dirt  : hint_range(0.05, 5.0) = 0.25;
uniform float uv_scale_stone : hint_range(0.05, 5.0) = 0.2;
uniform float uv_scale_cobble: hint_range(0.05, 5.0) = 0.15;
uniform float uv_scale_earth : hint_range(0.05, 5.0) = 0.3;
uniform float blend_sharpness : hint_range(0.0, 10.0) = 3.0;

// Toon shading parameters (matched to toon.gdshader)
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.2;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 shadow_tint : source_color = vec3(0.75, 0.65, 0.5);

uniform sampler2D texture_cobble : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_packed_earth : source_color, filter_linear_mipmap, repeat_enable;

varying vec4 vertex_color_full;

void vertex() {
	vertex_color_full = COLOR;
}

void fragment() {
	float inv_sharp = 1.0 / max(blend_sharpness, 0.01);
	float dirt_w = vertex_color_full.r > 0.01 ? smoothstep(0.0, inv_sharp, vertex_color_full.r) : 0.0;
	float stone_w = vertex_color_full.g > 0.01 ? smoothstep(0.0, inv_sharp, vertex_color_full.g) : 0.0;
	float cobble_w = vertex_color_full.b > 0.01 ? smoothstep(0.0, inv_sharp, vertex_color_full.b) : 0.0;
	float earth_raw = 1.0 - vertex_color_full.a;
	float earth_w = earth_raw > 0.01 ? smoothstep(0.0, inv_sharp, earth_raw) : 0.0;

	float overlay_sum = dirt_w + stone_w + cobble_w + earth_w;
	if (overlay_sum > 1.0) {
		float inv = 1.0 / overlay_sum;
		dirt_w *= inv; stone_w *= inv; cobble_w *= inv; earth_w *= inv;
		overlay_sum = 1.0;
	}
	float grass_w = max(1.0 - overlay_sum, 0.0);

	vec3 col = texture(texture_grass, UV * uv_scale_pavement).rgb * grass_w;
	if (dirt_w > 0.0) col += texture(texture_dirt, UV * uv_scale_dirt).rgb * dirt_w;
	if (stone_w > 0.0) col += texture(texture_stone, UV * uv_scale_stone).rgb * stone_w;
	if (cobble_w > 0.0) col += texture(texture_cobble, UV * uv_scale_cobble).rgb * cobble_w;
	if (earth_w > 0.0) col += texture(texture_packed_earth, UV * uv_scale_earth).rgb * earth_w;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float light_band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, NdotL);

	vec3 shadow_color = mix(shadow_tint, vec3(1.0), light_band);
	vec3 diffuse = ALBEDO * shadow_color * ATTENUATION;
	diffuse = mix(ALBEDO * shadow_tint * shadow_strength, diffuse, light_band);

	vec3 ambient = ALBEDO * 0.15;
	DIFFUSE_LIGHT += diffuse * LIGHT_COLOR + ambient;
}
