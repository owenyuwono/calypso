shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

// Cel shading parameters
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.02;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec3 shadow_tint : source_color = vec3(0.75, 0.65, 0.5);

// Specular (toonified Blinn-Phong)
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float specular_glossiness : hint_range(0.0, 1.0) = 0.5;
uniform float specular_smoothness : hint_range(0.0, 0.5) = 0.05;

// Rim lighting
uniform float rim_power : hint_range(1.0, 10.0) = 2.5;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 base_color = albedo_color;
	if (use_texture) {
		base_color *= texture(albedo_texture, UV);
	}
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	if (base_color.a < 0.01) {
		discard;
	}
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float self_lit = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, NdotL);

	vec3 lit = ALBEDO * LIGHT_COLOR;
	vec3 shaded = ALBEDO * shadow_tint * shadow_strength;

	// Toon banding for surface normals
	vec3 result = mix(shaded, lit, self_lit);

	// Cast shadow from light's shadow map — applied independently
	result *= ATTENUATION;
	DIFFUSE_LIGHT += result;

	// Toonified Blinn-Phong specular — suppress in shadow
	vec3 half_dir = normalize(VIEW + LIGHT);
	float gloss = pow(2.0, 8.0 * (1.0 - specular_glossiness));
	float spec_intensity = pow(max(dot(NORMAL, half_dir), 0.0), gloss * gloss);
	spec_intensity = smoothstep(0.05, 0.05 + specular_smoothness, spec_intensity);
	SPECULAR_LIGHT += LIGHT_COLOR * specular_color.rgb * specular_color.a * spec_intensity * self_lit * ATTENUATION;

	// Rim lighting — only on lit side
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	rim *= self_lit * ATTENUATION * rim_intensity;
	DIFFUSE_LIGHT += LIGHT_COLOR * rim;
}
