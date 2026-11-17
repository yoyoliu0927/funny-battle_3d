shader_type spatial;
// 星星外面的光：一團金黃色的光暈，加上慢慢轉的幾道光芒，一明一暗。永遠正對鏡頭。
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float a = atan(p.y, p.x);
	float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
	float halo = exp(-d * d * 4.5) * 0.85 + exp(-d * d * 30.0) * 0.6;
	// 四道長光芒 + 四道短的，慢慢轉
	float r1 = pow(abs(cos(a * 2.0 + TIME * 0.5)), 60.0) * smoothstep(1.0, 0.1, d);
	float r2 = pow(abs(cos(a * 2.0 - TIME * 0.35 + 0.8)), 90.0) * smoothstep(0.7, 0.1, d) * 0.6;
	float v = (halo + (r1 + r2) * 0.9) * pulse * smoothstep(0.95, 0.45, d);
	// 沒有光的地方完全不畫（不然整塊方形面片會被霧染亮，看得到一個方框）
	if (v < 0.004) {
		discard;
	}
	ALBEDO = mix(vec3(1.0, 0.70, 0.18), vec3(1.0, 0.96, 0.72), clamp(v, 0.0, 1.0)) * v;
	ALPHA = clamp(v * 1.5, 0.0, 1.0);
}
