// 地圖外面的海：深色的海面上，又大又疏的波浪筆觸（兩個色階，sea_waves.png）慢慢漂；靠近地圖的海比較亮、遠處深；
// 沿著地圖的輪廓有一圈會動的白色浪花（一道一道往外推）；浮冰旁邊也有一點浪花。越遠越接近地平線的顏色。
// 不吃光：每個時段的顏色由 ice_world.gd 給。
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_back;

uniform sampler2D wave_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform vec3 deep : source_color = vec3(0.05, 0.30, 0.56);
uniform vec3 near_c : source_color = vec3(0.12, 0.52, 0.74);       // 靠近地圖的海
uniform vec3 stroke_c : source_color = vec3(0.62, 0.90, 0.98);     // 筆觸最亮的那一撇
uniform vec3 stroke2_c : source_color = vec3(0.24, 0.66, 0.84);    // 筆觸外圈的中間色
uniform vec3 horizon_c : source_color = vec3(0.72, 0.89, 1.0);
uniform vec3 foam_c : source_color = vec3(1.0, 1.0, 1.0);
uniform vec2 center = vec2(0.0);
uniform float rim[96];                // 每個方向（96 等分）地圖吃水線離中心多遠
uniform float fade_near = 90.0;
uniform float fade_far = 420.0;

varying vec3 wpos;

float shore_r(float ang) {
	float f = fract(ang / TAU + 1.0) * 96.0;
	int i = int(floor(f));
	return mix(rim[i % 96], rim[(i + 1) % 96], f - float(i));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 dv = p - center;
	float sd = length(dv) - shore_r(atan(dv.y, dv.x));          // 離岸多遠（公尺）
	float nearf = 1.0 - smoothstep(0.0, 38.0, sd);
	vec3 c = mix(deep, near_c, nearf * nearf);
	// 波浪筆觸：兩層大小不同、漂的方向不同
	vec2 s1 = texture(wave_tex, p / 27.0 + vec2(TIME * 0.006, sin(TIME * 0.35) * 0.006)).rg;
	vec2 s2 = texture(wave_tex, p / 43.0 + vec2(-TIME * 0.004, cos(TIME * 0.3) * 0.005) + 0.37).rg;
	float halo = max(s1.g, s2.g * 0.85);
	float core = max(s1.r, s2.r * 0.85);
	// 筆觸不要鋪滿：東一撇西一撇，越遠越淡（遠處不會變成一排一排的魚鱗）
	float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	float keep = smoothstep(0.34, 0.52, texture(wave_tex, p / 120.0 + 0.19).b) * (1.0 - smoothstep(70.0, 260.0, dist) * 0.75);
	c = mix(c, stroke2_c, halo * 0.60 * keep);
	c = mix(c, stroke_c, core * 0.80 * keep);
	// 岸邊的浪花：貼著冰崖的一圈＋兩道往外推、越遠越淡的浪
	float n = texture(wave_tex, p / 9.0 + vec2(TIME * 0.02, -TIME * 0.015)).b;
	float n2 = texture(wave_tex, p / 23.0 + 0.61).b;
	float foam = 1.0 - smoothstep(0.15 + n * 0.5, 0.75 + n * 1.0, sd);
	for (int k = 0; k < 2; k++) {
		float ph = fract(TIME * 0.10 + float(k) * 0.5 + n2 * 0.6);
		float at = 0.9 + ph * 3.4;
		float band = 1.0 - smoothstep(0.0, 0.22 + 0.25 * n, abs(sd - at));
		foam = max(foam, band * (1.0 - ph) * smoothstep(0.30, 0.55, n + 0.15) * step(0.0, sd));
	}
	// 浮冰旁邊：海面碰到東西的地方（跟後面場景的深度差很小）
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float gap = -up.z / up.w + VERTEX.z;
	foam = max(foam, (1.0 - smoothstep(0.04, 0.14 + n * 0.3, gap)) * step(6.0, sd));
	c = mix(c, foam_c, clamp(foam, 0.0, 1.0) * 0.92);
	c = mix(c, horizon_c, smoothstep(fade_near, fade_far, dist) * 0.92);
	ALBEDO = c;
}
