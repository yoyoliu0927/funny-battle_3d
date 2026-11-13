// 地圖外面的海：深藍綠的海面，兩層慢慢流動的卡通波光線（sea_waves.png），碰到岩壁和浮冰的地方有一圈白色浪花，越遠越接近地平線的顏色。
// 不吃光：每個時段的顏色由 ice_world.gd 給。
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_back;

uniform sampler2D wave_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform vec3 deep : source_color = vec3(0.07, 0.36, 0.60);
uniform vec3 light_c : source_color = vec3(0.16, 0.56, 0.76);
uniform vec3 line_c : source_color = vec3(0.80, 0.96, 1.0);
uniform vec3 horizon_c : source_color = vec3(0.72, 0.89, 1.0);
uniform vec3 foam_c : source_color = vec3(1.0, 1.0, 1.0);
uniform float fade_near = 70.0;
uniform float fade_far = 380.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float big = texture(wave_tex, p / 70.0 + vec2(TIME * 0.002, TIME * 0.001)).g;
	float l1 = texture(wave_tex, p / 17.0 + vec2(TIME * 0.012, sin(TIME * 0.5) * 0.004)).r;
	float l2 = texture(wave_tex, p / 29.0 + vec2(-TIME * 0.008, cos(TIME * 0.4) * 0.004) + 0.43).r;
	float sp = texture(wave_tex, p / 9.0 + vec2(TIME * 0.02, 0.0)).b;
	vec3 c = mix(deep, light_c, smoothstep(0.25, 0.80, big) * 0.8);
	c = mix(c, line_c, clamp(l1 * 0.8 + l2 * 0.6, 0.0, 1.0) * 0.50);
	c = mix(c, line_c, sp * 0.35);
	// 浪花：海面碰到東西的地方（跟後面場景的深度差很小）
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float gap = -up.z / up.w + VERTEX.z;
	float wob = texture(wave_tex, p / 6.0 + vec2(TIME * 0.03, -TIME * 0.02)).g;
	float foam = 1.0 - smoothstep(0.05, 0.16 + wob * 0.38, gap);
	c = mix(c, foam_c, foam * 0.85);
	float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	c = mix(c, horizon_c, smoothstep(fade_near, fade_far, dist) * 0.92);
	ALBEDO = c;
}
