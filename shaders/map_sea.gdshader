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
	vec3 c = mix(deep, near_c, smoothstep(0.32, 0.62, swell));
	// 波浪筆觸：橫向拉長的亮線，東一撇西一撇
	float kw = mix(1.0, 0.62, zoom);     // 筆觸放大得比色塊少：拉遠時還是一撇一撇的小浪，不會變成一大片白
	float w = vnoise(vec3(p.x * 0.22 * kw + TIME * 0.08, p.y * 0.95 * kw, TIME * 0.12));
	float keep = smoothstep(0.45, 0.6, vnoise(vec3(p * 0.045 * ks, 7.0))) * (1.0 - smoothstep(50.0, 160.0, dist) * 0.8 * (1.0 - zoom));
	c = mix(c, stroke_c, smoothstep(0.70 + 0.05 * zoom, 0.76 + 0.05 * zoom, w) * keep * mix(0.75, 0.6, zoom));
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
