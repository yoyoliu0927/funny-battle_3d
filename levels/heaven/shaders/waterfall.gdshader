// 仙山的瀑布：半透明的水，一絲一絲往下流，越往下越散成霧（模型是一片上窄下寬的面，用模型自己的座標畫）。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.90, 0.97, 1.0);
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float streak = 0.5 + 0.5 * sin(lp.x * 26.0 + sin(lp.y * 2.4) * 2.0) * sin(lp.y * 6.0 + TIME * 6.0);
	float fade = smoothstep(-5.6, -2.2, lp.y);
	ALBEDO = tint;
	ALPHA = clamp((0.28 + 0.6 * streak) * (0.25 + 0.75 * fade), 0.0, 1.0) * 0.9;
}
