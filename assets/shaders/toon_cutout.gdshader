shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform vec4 albedo_color : source_color = vec4(0.18, 0.55, 0.12, 1.0);
uniform sampler2D mask_texture : filter_linear_mipmap;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

// Toon shading parameters
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.2;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 shadow_tint : source_color = vec3(0.75, 0.65, 0.5);

// Rim lighting
uniform float rim_power : hint_range(1.0, 10.0) = 2.5;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = albedo_color.rgb;
	float mask = texture(mask_texture, UV).r;
	if (mask < alpha_cutoff) {
		discard;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float light_band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, NdotL);

	vec3 shadow_color = mix(shadow_tint, vec3(1.0), light_band);
	vec3 diffuse = ALBEDO * shadow_color * ATTENUATION;
	diffuse = mix(ALBEDO * shadow_tint * shadow_strength, diffuse, light_band);

	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	rim *= light_band * rim_intensity;
	vec3 rim_color = LIGHT_COLOR * rim;

	vec3 ambient = ALBEDO * 0.12;
	DIFFUSE_LIGHT += diffuse * LIGHT_COLOR + rim_color + ambient;
}
