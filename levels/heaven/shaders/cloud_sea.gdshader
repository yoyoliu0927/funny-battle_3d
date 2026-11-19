// 地圖底下的雲海：一大片慢慢流動的雲，亮的雲頭、暗的雲縫；靠近台座的地方比較亮，越遠越融進地平線的顏色。
// 不吃光：每個時段的顏色由 heaven_world.gd 給。
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_back;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 deep : source_color = vec3(0.24, 0.48, 0.52);
uniform vec3 mid_c : source_color = vec3(0.56, 0.78, 0.78);
uniform vec3 light_c : source_color = vec3(0.74, 0.90, 0.88);
uniform vec3 crest_c : source_color = vec3(0.94, 1.0, 0.98);
uniform vec3 horizon_c : source_color = vec3(0.70, 0.88, 0.86);
uniform vec2 center = vec2(0.0);
uniform float fade_near = 60.0;
uniform float fade_far = 300.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 drift = vec2(TIME * 0.35, TIME * 0.12);
	float big = texture(noise_tex, (p + drift) / 95.0).r;
	float mid = texture(noise_tex, (p + drift * 1.7) / 41.0 + 0.37).r;
	float fine = texture(noise_tex, (p + drift * 2.6) / 17.0 + 0.11).g;
	float h = big * 0.55 + mid * 0.33 + fine * 0.12;
	// 三個色階：雲縫 → 雲身 → 雲頭，邊界柔一點（像一筆一筆暈開）
	vec3 c = mix(deep, mid_c, smoothstep(0.30, 0.44, h));
	c = mix(c, light_c, smoothstep(0.46, 0.58, h));
	c = mix(c, crest_c, smoothstep(0.62, 0.72, h));
	float near = 1.0 - smoothstep(18.0, 70.0, length(p - center));
	c = mix(c, light_c, near * 0.35);
	float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	c = mix(c, horizon_c, smoothstep(fade_near, fade_far, dist) * 0.94);
	ALBEDO = c;
}
