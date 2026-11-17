shader_type spatial;
// 墨色描邊（跟介面 ui_style.gd 的深咖啡色外框同一個顏色）
// 用法：GeometryInstance3D.material_overlay = 這個材質。只畫背面、沿法線往外推固定幾個像素，
// 所以不管離鏡頭多遠，線都一樣粗（跟 2D 介面的外框一致）。
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque, fog_disabled;

uniform vec4 ink : source_color = vec4(0.231, 0.165, 0.125, 1.0);
uniform float width_px = 2.6;     // 線的粗細（像素）
uniform float far_fade = 60.0;    // 太遠的東西線變細，免得糊成一團

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy;
	float len = length(dir);
	if (len > 0.0001) {
		dir /= len;
		float w = width_px * clamp(1.0 - clip.w / far_fade, 0.35, 1.0);
		clip.xy += dir * w * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
