shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 silhouette_color : source_color = vec4(0.18, 0.78, 0.98, 0.52);
uniform vec4 rim_color : source_color = vec4(0.62, 0.95, 1.0, 0.94);
uniform float min_occluder_gap : hint_range(0.05, 3.0) = 0.55;

void fragment() {
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 ndc_scene = vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	vec4 view_scene = INV_PROJECTION_MATRIX * ndc_scene;
	view_scene.xyz /= view_scene.w;
	float scene_dist = -view_scene.z;
	float frag_dist = -VERTEX.z;

	// Only render silhouette when an opaque occluder sits meaningfully in front of the character
	if (frag_dist - scene_dist < min_occluder_gap) {
		discard;
	}

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.6);
	ALBEDO = mix(silhouette_color.rgb, rim_color.rgb, fresnel);
	ALPHA = clamp(mix(silhouette_color.a, rim_color.a, fresnel), 0.0, 1.0);
}
