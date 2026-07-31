shader_type spatial;
render_mode specular_schlick_ggx;

uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
uniform float iridescence_scale : hint_range(0.0, 10.0) = 3.0;
uniform float iridescence_intensity : hint_range(0.0, 1.0) = 0.5;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 iridescent_color(float angle) {
    float hue = fract(angle * iridescence_scale);
    return hsv2rgb(vec3(hue, 1.0, 1.0));
}

void fragment() {
    vec3 view_dir = normalize(-NORMAL);
    float angle = dot(NORMAL, VIEW);

    vec3 rainbow = iridescent_color(angle);
    vec3 base_color = mix(vec3(1.0), rainbow, iridescence_intensity);

    ALBEDO = base_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;

    EMISSION = base_color * 0.2;
}