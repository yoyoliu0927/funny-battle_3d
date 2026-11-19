// 結局：家豪身上展開的鳳凰形狀的金光（模型是一片展翅的剪影）。加亮、不吃光，由下往上流動的光。
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float flow = 0.6 + 0.4 * sin(lp.y * 5.0 - TIME * 4.0 + lp.x * 2.0);
	vec3 c = mix(vec3(1.0, 0.62, 0.18), vec3(1.0, 0.96, 0.70), flow);
	ALBEDO = c * 1.6;
	ALPHA = 0.75;
}
