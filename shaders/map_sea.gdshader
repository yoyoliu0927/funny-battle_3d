// 選關地圖的海：卡通色塊的海面＋零星的波浪筆觸；海面碰到任何東西（小島、浮橋、站點）的地方自動有一圈白色浪花。
// 不吃光：顏色由 level_select.gd 依目前小關的時段給。
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform vec3 deep : source_color = vec3(0.10, 0.42, 0.66);
uniform vec3 near_c : source_color = vec3(0.20, 0.62, 0.78);
uniform vec3 stroke_c : source_color = vec3(0.72, 0.93, 0.97);
uniform vec3 foam_c : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 horizon_c : source_color = vec3(0.78, 0.90, 0.92);
uniform float fade_near = 60.0;
uniform float fade_far = 260.0;
uniform float zoom = 0.0;   // 0 = 島上、1 = 拉遠看世界地圖：花紋放大，從高空看才不會糊成雜點
// 南北兩區（世界地圖才看得出來，region_k 跟著拉遠變 1）：北邊冷、淡、有浮冰；南邊暖、亮的藍綠色
uniform float region_z = 0.0;     // 分界線在世界座標的 z（北邊是 z 比較小的那一側）
uniform float region_w = 24.0;    // 分界線附近慢慢過渡的寬度
uniform float region_k = 0.0;
uniform vec3 north_deep : source_color = vec3(0.07, 0.34, 0.58);
uniform vec3 north_near : source_color = vec3(0.24, 0.58, 0.80);
uniform vec4 isles[8];            // 每座島：中心 x、z 和半徑 rx、rz（浮冰在島四周讓出一圈水道）
uniform int isle_count = 0;
uniform vec3 south_deep : source_color = vec3(0.02, 0.50, 0.58);
uniform vec3 south_near : source_color = vec3(0.28, 0.80, 0.64);
uniform vec3 sand_c : source_color = vec3(1.0, 0.85, 0.52);
uniform float calm_z = -100000.0;  // 比這更北（z 更小）的海不長浮冰：地圖最上面留一條平靜的海

// 海浪（開船的時候才有，wave_amp = 0 就是原本平平的海）：三道疊起來的長浪；level_select.gd 用一模一樣的公式算船的高度
uniform float wave_amp = 0.0;
uniform float wave_t = 0.0;
varying vec3 wpos;
varying float wave_h;

float sea_wave(vec2 p, float t) {
	return 0.55 * sin(dot(p, vec2(0.071, 0.052)) + t * 0.9)
		+ 0.30 * sin(dot(p, vec2(-0.043, 0.093)) + t * 1.25 + 1.7)
		+ 0.16 * sin(dot(p, vec2(0.13, -0.08)) + t * 1.8 + 4.0);
}

vec2 cell_pt(vec2 g) {
	vec2 q = vec2(dot(g, vec2(127.1, 311.7)), dot(g, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453) * 0.8 + 0.1;
}

// Voronoi：回傳 (到格子邊的距離, 這一格的亂數)。格子是凸多邊形，拿來當一塊一塊有稜角的浮冰
vec2 voro(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + cell_pt(n + g) - f;
			float d = dot(r, r);
			if (d < md) { md = d; mr = r; mg = g; }
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + cell_pt(n + g) - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	vec2 id = n + mg;
	return vec2(md, fract(sin(dot(id, vec2(41.3, 289.1))) * 15731.743));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_h = sea_wave(wpos.xz, wave_t);
	VERTEX.y += wave_h * wave_amp;
	wpos.y += wave_h * wave_amp;
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(p - CAMERA_POSITION_WORLD.xz);
	// 大塊的深淺
	float ks = mix(1.0, 0.36, zoom);
	float swell = fbm(vec3(p * 0.06 * ks + vec2(TIME * 0.02, 0.0), TIME * 0.03));
	float north = smoothstep(region_z + region_w, region_z - region_w, p.y);
	vec3 d0 = mix(deep, mix(south_deep, north_deep, north), region_k);
	vec3 n0 = mix(near_c, mix(south_near, north_near, north), region_k);
	vec3 c = mix(d0, n0, smoothstep(0.32, 0.62, swell));
	// 北方的浮冰：有稜角的平頂冰塊，越北越多。偏藍的白（跟冰雪島的雪白分開），南邊（畫面下方）一道深色的厚度
	float far_n = smoothstep(region_z - region_w * 1.5, region_z - region_w * 4.0, p.y) * region_k;
	float has_n = step(0.01, far_n) * smoothstep(calm_z - 8.0, calm_z + 6.0, p.y);
	// 離島太近的不要（留一圈水道）
	float clear = 1.0;
	for (int i = 0; i < isle_count; i++) {
		vec2 q = (p - isles[i].xy) / (isles[i].zw + vec2(14.0));
		clear = min(clear, smoothstep(1.0, 1.25, length(q)));
	}
	// 一格約 13 公尺；只有一部分的格子是浮冰（越北越多），格子往內縮一圈當水道
	float dens = 0.16 + 0.14 * far_n;
	vec2 v0 = voro(p / 13.0);
	vec2 v1 = voro((p - vec2(0.0, 1.3)) / 13.0);
	float on0 = step(v0.y, dens) * has_n * clear;
	float on1 = step(v1.y, dens) * has_n * clear;
	float floe = smoothstep(0.13, 0.145, v0.x) * on0;
	float side = clamp(smoothstep(0.13, 0.145, v1.x) * on1 - floe, 0.0, 1.0);
	float edge_f = clamp(smoothstep(0.075, 0.09, v0.x) * on0 - floe - side, 0.0, 1.0);
	c = mix(c, vec3(0.52, 0.86, 0.95), edge_f * 0.7);
	c = mix(c, vec3(0.03, 0.24, 0.32), side * 0.6);
	c = mix(c, vec3(0.84, 0.93, 0.99), floe);
	c = mix(c, vec3(0.97, 0.99, 1.0), floe * smoothstep(0.17, 0.30, v0.x) * 0.8);
	// 波浪筆觸：橫向拉長的亮線，東一撇西一撇
	float kw = mix(1.0, 0.62, zoom);     // 筆觸放大得比色塊少：拉遠時還是一撇一撇的小浪，不會變成一大片白
	float w = vnoise(vec3(p.x * 0.22 * kw + TIME * 0.08, p.y * 0.95 * kw, TIME * 0.12));
	float keep = smoothstep(0.45, 0.6, vnoise(vec3(p * 0.045 * ks, 7.0))) * (1.0 - smoothstep(50.0, 160.0, dist) * 0.8 * (1.0 - zoom));
	float calm = 1.0 - 0.75 * smoothstep(0.0, 0.4, zoom) * (1.0 - north);    // 世界地圖上南方的筆觸淡一點：拉遠才不會像一片一片的冰
	c = mix(c, stroke_c, smoothstep(0.70 + 0.05 * zoom, 0.76 + 0.05 * zoom, w) * keep * mix(0.75, 0.6, zoom) * calm * (1.0 - floe));
	// 浪花：海面後面的東西離海面很近的地方
	float zd = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// 網頁版（Compatibility）的深度值是 0～1、要換成 -1～1 才對；沒換的話整片海都算成「離岸很近」，全部變成浪花的顏色（灰白）
	vec3 ndc = vec3(SCREEN_UV, zd) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, zd);
#endif
	vec4 up = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float gap = -up.z / up.w + VERTEX.z;
	float n = vnoise(vec3(p * 1.4, TIME * 0.7));
	float foam = 1.0 - smoothstep(0.10, 0.35 + n * 0.55, gap);
	float ph = fract(TIME * 0.22 + vnoise(vec3(p * 0.3, 2.0)));
	float band = 1.0 - smoothstep(0.0, 0.16 + 0.12 * n, abs(gap - (0.7 + ph * 1.3)));
	foam = max(foam, band * (1.0 - ph) * 0.7);
	// 南方的沙灘：照真正的海岸線（海面離島身近的地方）一圈米黃，只在主題島旁邊（不包括主島、浮球）
	float near_i = 0.0;
	for (int i = 1; i < isle_count; i++) {
		vec2 q = (p - isles[i].xy) / (isles[i].zw + vec2(4.0));
		near_i = max(near_i, 1.0 - smoothstep(1.0, 1.08, length(q)));
	}
	float sandb = (1.0 - smoothstep(1.7, 3.0, gap)) * (1.0 - north) * region_k * near_i;
	c = mix(c, sand_c, sandb * 0.95);
	c = mix(c, foam_c, clamp(foam, 0.0, 1.0) * 0.92 * (1.0 - sandb * 0.6));
	// 浪頭：開船時浪尖一圈亮亮的線、浪谷深一點，一道一道往前推
	float crest = smoothstep(0.55, 0.95, wave_h) * clamp(wave_amp * 3.0, 0.0, 1.0);
	float trough = smoothstep(-0.35, -0.95, wave_h) * clamp(wave_amp * 3.0, 0.0, 1.0);
	c = mix(c, stroke_c, crest * 0.65);
	c = mix(c, d0 * 0.9, trough * 0.35);
	c = mix(c, horizon_c, smoothstep(fade_near, fade_far, dist) * 0.95);
	ALBEDO = c;
}
