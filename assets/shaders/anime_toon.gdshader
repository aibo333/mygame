shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool use_texture = false;

uniform vec4 shadow_tint : source_color = vec4(0.62, 0.58, 0.78, 1.0);
uniform float cel_threshold : hint_range(-0.5, 0.5) = 0.08;
uniform float cel_smoothness : hint_range(0.001, 0.25) = 0.045;

uniform vec4 rim_color : source_color = vec4(1.0, 0.84, 0.65, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.45;

uniform float specular_strength : hint_range(0.0, 1.0) = 0.18;
uniform float specular_shininess : hint_range(4.0, 128.0) = 28.0;

uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform bool is_face_material = false;

void fragment() {
	vec4 tex = use_texture ? texture(albedo_texture, UV) : vec4(1.0);
	ALBEDO = albedo_color.rgb * tex.rgb;
	EMISSION = emission_color.rgb * emission_energy;
	ROUGHNESS = 0.65;
	METALLIC = 0.0;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	// Softly brighten anime faces so eyes and blush stay crisp and readable from top-down camera
	float face_lift = is_face_material ? 0.38 : 0.0;
	float cel = smoothstep(cel_threshold - cel_smoothness, cel_threshold + cel_smoothness, ndotl + face_lift);
	vec3 lit_tone = mix(shadow_tint.rgb, vec3(1.0), cel);

	// Warm sunset / anime rim highlight
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim_factor = pow(1.0 - ndotv, rim_power) * smoothstep(-0.2, 0.5, ndotl);
	vec3 rim = rim_color.rgb * rim_factor * (is_face_material ? rim_strength * 0.35 : rim_strength);

	// Crisp anime specular band (for hair/armor)
	vec3 half_vec = normalize(LIGHT + VIEW);
	float spec_raw = pow(max(dot(NORMAL, half_vec), 0.0), specular_shininess);
	float spec_step = smoothstep(0.45, 0.55, spec_raw);
	vec3 spec = LIGHT_COLOR * spec_step * (is_face_material ? 0.0 : specular_strength);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * lit_tone / 3.14159265;
	SPECULAR_LIGHT += (rim + spec) * ATTENUATION;
}
