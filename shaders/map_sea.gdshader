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
uniform vec3 north_deep : source_color = vec3(0.25, 0.42, 0.60);
uniform vec3 north_near : source_color = vec3(0.50, 0.67, 0.80);
uniform vec4 isles[8];            // 每座島：中心 x、z 和半徑 rx、rz（浮冰在島四周讓出一圈水道）
uniform int isle_count = 0;
uniform vec3 south_deep : source_color = vec3(0.00, 0.50, 0.70);
uniform vec3 south_near : source_color = vec3(0.08, 0.80, 0.80);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	// 北方的浮冰：少少幾塊、大一點，越北越多。偏藍的白（跟冰雪島的雪白分開），南邊（畫面下方）一道深色的厚度
	float far_n = smoothstep(region_z - region_w * 1.5, region_z - region_w * 4.0, p.y) * region_k;
	float has_n = step(0.01, far_n);
	float cut = 0.80 - 0.03 * far_n + 0.05 * smoothstep(region_z - region_w * 4.0, region_z - region_w * 6.0, p.y);   // 最北邊再稀一點
	// 離島太近的不要（留一圈水道），再用細一點的雜訊切出裂縫，把大塊打碎
	float clear = 1.0;
	for (int i = 0; i < isle_count; i++) {
		vec2 q = (p - isles[i].xy) / (isles[i].zw + vec2(14.0));
		clear = min(clear, smoothstep(1.0, 1.25, length(q)));
	}
	float fn = vnoise(vec3(p * 0.075, 11.0)) + vnoise(vec3(p * 0.22, 5.0)) * 0.12;
	vec2 ps = p - vec2(0.0, 1.4);
	float fs = vnoise(vec3(ps * 0.075, 11.0)) + vnoise(vec3(ps * 0.22, 5.0)) * 0.12;
	float crack = smoothstep(0.035, 0.06, abs(vnoise(vec3(p * 0.16, 23.0)) - 0.5));
	float crack_s = smoothstep(0.035, 0.06, abs(vnoise(vec3(ps * 0.16, 23.0)) - 0.5));
	float floe = smoothstep(cut, cut + 0.008, fn) * has_n * clear * crack;
	float side = clamp(smoothstep(cut, cut + 0.008, fs) * has_n * clear * crack_s - floe, 0.0, 1.0);
	c = mix(c, north_deep * 0.66, side * 0.6);
	c = mix(c, vec3(0.84, 0.93, 0.99), floe);
	c = mix(c, vec3(0.97, 0.99, 1.0), floe * smoothstep(cut + 0.03, cut + 0.10, fn) * 0.8);
	// 波浪筆觸：橫向拉長的亮線，東一撇西一撇
	float kw = mix(1.0, 0.62, zoom);     // 筆觸放大得比色塊少：拉遠時還是一撇一撇的小浪，不會變成一大片白
	float w = vnoise(vec3(p.x * 0.22 * kw + TIME * 0.08, p.y * 0.95 * kw, TIME * 0.12));
	float keep = smoothstep(0.45, 0.6, vnoise(vec3(p * 0.045 * ks, 7.0))) * (1.0 - smoothstep(50.0, 160.0, dist) * 0.8 * (1.0 - zoom));
	float calm = 1.0 - 0.75 * smoothstep(0.0, 0.4, zoom) * (1.0 - north);    // 世界地圖上南方的筆觸淡一點：拉遠才不會像一片一片的冰
	c = mix(c, stroke_c, smoothstep(0.70 + 0.05 * zoom, 0.76 + 0.05 * zoom, w) * keep * mix(0.75, 0.6, zoom) * calm * (1.0 - floe));
	// 浪花：海面後面的東西離海面很近的地方
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float gap = -up.z / up.w + VERTEX.z;
	float n = vnoise(vec3(p * 1.4, TIME * 0.7));
	float foam = 1.0 - smoothstep(0.10, 0.35 + n * 0.55, gap);
	float ph = fract(TIME * 0.22 + vnoise(vec3(p * 0.3, 2.0)));
	float band = 1.0 - smoothstep(0.0, 0.16 + 0.12 * n, abs(gap - (0.7 + ph * 1.3)));
	foam = max(foam, band * (1.0 - ph) * 0.7);
	c = mix(c, foam_c, clamp(foam, 0.0, 1.0) * 0.92);
	c = mix(c, horizon_c, smoothstep(fade_near, fade_far, dist) * 0.95);
	ALBEDO = c;
}
