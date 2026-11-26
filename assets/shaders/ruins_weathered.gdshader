shader_type spatial;
render_mode cull_back;

uniform vec4 albedo_color : source_color = vec4(0.55, 0.58, 0.62, 1.0);
uniform vec4 grime_color : source_color = vec4(0.14, 0.16, 0.18, 1.0);
uniform vec4 moss_color : source_color = vec4(0.18, 0.24, 0.19, 1.0);
uniform float weathering_strength : hint_range(0.0, 1.0) = 0.55;
uniform float ground_damp_height : hint_range(0.1, 2.5) = 0.85;
uniform float roughness_val : hint_range(0.05, 1.0) = 0.84;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.06;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.55 * value_noise(p);
	v += 0.30 * value_noise(p * 2.13 + vec2(7.1, 3.7));
	v += 0.15 * value_noise(p * 4.41 + vec2(1.9, 9.2));
	return v;
}

void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	v_world_pos = wp.xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 sample_uv = abs(v_world_normal.y) > 0.65
		? v_world_pos.xz * 0.55
		: (abs(v_world_normal.x) > 0.5 ? v_world_pos.zy : v_world_pos.xy) * 0.65;

	float n_macro = fbm(sample_uv * 0.65);
	float n_micro = fbm(sample_uv * 2.4 + vec2(4.3, 1.7));

	// Height-based dampness & grime near floor level
	float h_factor = 1.0 - smoothstep(0.0, ground_damp_height, max(0.0, v_world_pos.y));
	float grime_mask = clamp((h_factor * 0.72 + n_macro * 0.38 - 0.25) * weathering_strength, 0.0, 0.85);
	float moss_mask = clamp((h_factor * 0.60 + n_micro * 0.45 - 0.52) * weathering_strength, 0.0, 0.55);

	vec3 base_col = albedo_color.rgb * mix(0.88, 1.06, n_micro);
	vec3 weathered = mix(base_col, grime_color.rgb, grime_mask);
	weathered = mix(weathered, moss_color.rgb, moss_mask);

	ALBEDO = weathered;
	ROUGHNESS = clamp(roughness_val + grime_mask * 0.14, 0.1, 1.0);
	METALLIC = metallic_val * (1.0 - grime_mask * 0.6);
}
