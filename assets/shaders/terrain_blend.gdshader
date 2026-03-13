shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform sampler2D texture_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_stone : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale : hint_range(0.1, 5.0) = 0.5;
uniform float blend_sharpness : hint_range(0.0, 10.0) = 3.0;

// Toon shading parameters (matched to toon.gdshader)
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.15;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec3 shadow_tint : source_color = vec3(0.6, 0.55, 0.7);

// Rim lighting
uniform float rim_power : hint_range(1.0, 10.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.4;

// Fallback colors when no textures assigned
uniform vec4 color_grass : source_color = vec4(0.28, 0.48, 0.18, 1.0);
uniform vec4 color_dirt : source_color = vec4(0.45, 0.35, 0.22, 1.0);
uniform vec4 color_stone : source_color = vec4(0.22, 0.18, 0.15, 1.0);
uniform sampler2D texture_cobble : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_packed_earth : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 color_cobble : source_color = vec4(0.48, 0.44, 0.40, 1.0);
uniform vec4 color_packed_earth : source_color = vec4(0.35, 0.30, 0.22, 1.0);

varying vec4 vertex_color_full;

void vertex() {
	vertex_color_full = COLOR;
}

void fragment() {
	vec2 tiled_uv = UV * uv_scale;

	// Sample textures (fall back to uniform color if texture is default white)
	vec3 grass_col = texture(texture_grass, tiled_uv).rgb;
	vec3 dirt_col = texture(texture_dirt, tiled_uv).rgb;
	vec3 stone_col = texture(texture_stone, tiled_uv).rgb;
	vec3 cobble_col = texture(texture_cobble, tiled_uv).rgb;
	vec3 earth_col = texture(texture_packed_earth, tiled_uv).rgb;

	// If textures are all white (not assigned), use fallback colors
	if (grass_col.r > 0.99 && grass_col.g > 0.99 && grass_col.b > 0.99) {
		grass_col = color_grass.rgb;
	}
	if (dirt_col.r > 0.99 && dirt_col.g > 0.99 && dirt_col.b > 0.99) {
		dirt_col = color_dirt.rgb;
	}
	if (stone_col.r > 0.99 && stone_col.g > 0.99 && stone_col.b > 0.99) {
		stone_col = color_stone.rgb;
	}
	if (cobble_col.r > 0.99 && cobble_col.g > 0.99 && cobble_col.b > 0.99) {
		cobble_col = color_cobble.rgb;
	}
	if (earth_col.r > 0.99 && earth_col.g > 0.99 && earth_col.b > 0.99) {
		earth_col = color_packed_earth.rgb;
	}

	// Vertex color channels: R=dirt, G=stone, B=cobblestone, A=packed_earth(inverted)
	float dirt_weight = smoothstep(0.0, 1.0 / max(blend_sharpness, 0.01), vertex_color_full.r);
	float stone_weight = smoothstep(0.0, 1.0 / max(blend_sharpness, 0.01), vertex_color_full.g);
	float cobble_weight = smoothstep(0.0, 1.0 / max(blend_sharpness, 0.01), vertex_color_full.b);
	float earth_weight = smoothstep(0.0, 1.0 / max(blend_sharpness, 0.01), 1.0 - vertex_color_full.a);
	float grass_weight = max(1.0 - dirt_weight - stone_weight - cobble_weight - earth_weight, 0.0);

	ALBEDO = grass_col * grass_weight + dirt_col * dirt_weight + stone_col * stone_weight + cobble_col * cobble_weight + earth_col * earth_weight;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// 2-band stepped diffuse (copied from toon.gdshader)
	float NdotL = dot(NORMAL, LIGHT);
	float light_band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, NdotL);

	// Mix shadow tint into dark areas
	vec3 shadow_color = mix(shadow_tint, vec3(1.0), light_band);
	vec3 diffuse = ALBEDO * shadow_color * ATTENUATION;
	diffuse = mix(ALBEDO * shadow_tint * shadow_strength, diffuse, light_band);

	// Rim lighting — only on lit side
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	rim *= light_band * rim_intensity;
	vec3 rim_color = LIGHT_COLOR * rim;

	vec3 ambient = ALBEDO * 0.08;
	DIFFUSE_LIGHT += diffuse * LIGHT_COLOR + rim_color + ambient;
}
