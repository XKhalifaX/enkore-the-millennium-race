shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Base_Paint;
uniform vec3 facing_color : source_color = vec3(0.15, 0.5, 0.9);
uniform vec3 glancing_color : source_color = vec3(0.0, 0.05, 0.2);
uniform float fresnel_exponent : hint_range(0.1, 10.0) = 2.0;
uniform float paint_metallic : hint_range(0.0, 1.0) = 0.8;
uniform float paint_specular : hint_range(0.0, 1.0) = 0.5;

group_uniforms Metallic_Flakes;
uniform sampler2D flake_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float flake_scale : hint_range(1.0, 500.0) = 150.0;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.4;
uniform float flake_roughness : hint_range(0.0, 1.0) = 0.1;

group_uniforms Clear_Coat;
uniform float clearcoat_amount : hint_range(0.0, 1.0) = 1.0;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.02;

void fragment() {
	// Fresnel
	float fresnel = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	fresnel = pow(fresnel, fresnel_exponent);
	
	ALBEDO = mix(facing_color, glancing_color, fresnel);
	METALLIC = paint_metallic;
	SPECULAR = paint_specular;
	
	// Flakes
	float flakes = texture(flake_texture, UV * flake_scale).r;
	ROUGHNESS = mix(base_roughness, flake_roughness, flakes);
	
	// Clear coat
	CLEARCOAT = clearcoat_amount;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
}