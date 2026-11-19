// 月亮：一個朝著鏡頭的圓，外面一圈淡淡的月暈。不吃光、不吃霧。
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, blend_mix, depth_draw_never;

uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.86);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.38, 0.40, d);
	float halo = (1.0 - smoothstep(0.38, 1.0, d)) * 0.35;
	ALBEDO = tint;
	ALPHA = clamp(core + halo, 0.0, 1.0);
}
