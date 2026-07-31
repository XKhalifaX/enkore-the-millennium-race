shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Balatro Paint Mix - 3D Triplanar Version

uniform bool polar_coordinates = false;
uniform vec2 polar_center = vec2(0.5);
uniform float polar_zoom = 1.;
uniform float polar_repeat = 1.;

uniform float spin_rotation = 0.0; 
uniform float spin_speed = 1.0;
uniform vec2 offset = vec2(0., 0.); 
uniform vec4 colour_1 : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 colour_3 : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform float contrast = 2.;
uniform float spin_amount = 0.36;
uniform float pixel_filter = 700.;
#define SPIN_EASE 1.0

// Triplanar Scale Control
uniform float triplanar_scale = 1.0;

varying vec3 triplanar_power;
varying vec3 triplanar_pos;

void vertex() {
	// Calculate the blend weights based on which way the 3D surface faces
	triplanar_power = pow(abs(NORMAL), vec3(4.0));
	triplanar_power /= (triplanar_power.x + triplanar_power.y + triplanar_power.z);
	
	// Track the actual 3D world/local space positions instead of mesh UVs
	triplanar_pos = VERTEX * triplanar_scale;
}

vec4 effect(vec2 screenSize, vec2 screen_coords){
	float pixel_size = length(screenSize.xy) / pixel_filter;
	vec2 uv = (floor(screen_coords.xy*(1./pixel_size))*pixel_size - 0.5*screenSize.xy)/length(screenSize.xy) - offset;
	float uv_len = length(uv);
	
	float speed = (spin_rotation*SPIN_EASE*0.2) + 302.2;
	float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
	vec2 mid = (screenSize.xy/length(screenSize.xy))/2.;
	uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);
	
	uv *= 30.;
	speed = TIME*(spin_speed);
	vec2 uv2 = vec2(uv.x+uv.y);
	
	for(int i=0; i < 5; i++) {
		uv2 += sin(max(uv.x, uv.y)) + uv;
		uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
		uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
	}
	
	float contrast_mod = (0.25*contrast + 0.5*spin_amount + 1.2);
	float paint_res = min(2., max(0.,length(uv)*(0.035)*contrast_mod));
	float c1p = max(0.,1. - contrast_mod*abs(1.-paint_res));
	float c2p = max(0.,1. - contrast_mod*abs(paint_res));
	float c3p = 1. - min(1., c1p + c2p);
	
	vec4 ret_col = (0.3/contrast)*colour_1 + (1. - 0.3/contrast)*(colour_1*c1p + colour_2*c2p + vec4(c3p*colour_3.rgb, c3p*colour_1.a));
	return ret_col;
}

vec2 polar_coords(vec2 uv, vec2 center, float zoom, float repeat){
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y , dir.x) * 1.0 / (PI * 2.0);
	return mod(vec2(radius * zoom, angle * repeat), 1.0);
}

void fragment() {
	// Generate 3 separate paint coordinates based on side, top, and front projection planes
	vec2 uv_x = triplanar_pos.zy;
	vec2 uv_y = triplanar_pos.xz;
	vec2 uv_z = triplanar_pos.xy;
	
	if (polar_coordinates){
		uv_x = polar_coords(uv_x, polar_center, polar_zoom, polar_repeat);
		uv_y = polar_coords(uv_y, polar_center, polar_zoom, polar_repeat);
		uv_z = polar_coords(uv_z, polar_center, polar_zoom, polar_repeat);
	}
	
	// Calculate the paint color for all three planes independently
	vec4 col_x = effect(vec2(1.0), uv_x);
	vec4 col_y = effect(vec2(1.0), uv_y);
	vec4 col_z = effect(vec2(1.0), uv_z);
	
	// Blend them smoothly across the mesh surface using our triplanar weights
	vec4 final_color = col_x * triplanar_power.x + col_y * triplanar_power.y + col_z * triplanar_power.z;
	
	ALBEDO = final_color.rgb;
	ROUGHNESS = 0.2;
}