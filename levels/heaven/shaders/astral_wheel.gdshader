// 山海轉盤：一圈半透明的金色光環（平放在地上或立在終點後面），分成十二格，每格中間嵌一塊紋章盤（另外的模型）。
// UV.x 繞一圈 0～1、UV.y 由內到外 0～1。
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 gold : source_color = vec3(1.0, 0.76, 0.32);
uniform float strength = 1.0;
uniform float segs = 12.0;
uniform float spin = 0.0;         // 轉了多少（弧度）：花紋跟著紋章盤一起轉
uniform float lit = 0.0;          // 結局：整圈亮起來
uniform float fade_near = 0.0;    // 離鏡頭這麼近以內淡掉（立著的大轉盤不要糊在鏡頭前）

void fragment() {
	float r = UV.y;
	float a = UV.x - spin / 6.2831853;
	float lw = fwidth(r) * 1.5 + 0.008;
	float lines = 0.0;
	lines += 1.0 - smoothstep(0.0, lw * 1.6, abs(r - 0.035));
	lines += 1.0 - smoothstep(0.0, lw * 1.6, abs(r - 0.965));
	lines += (1.0 - smoothstep(0.0, lw, abs(r - 0.17))) * 0.7;
	lines += (1.0 - smoothstep(0.0, lw, abs(r - 0.83))) * 0.7;
	// 內外緣各一圈刻度
	float tick = step(0.5, fract(a * segs * 12.0));
	float tick_band = step(0.06, r) * step(r, 0.145) + step(0.855, r) * step(r, 0.94);
	// 十二格之間的分隔線（細的兩條）
	float cell = abs(fract(a * segs + 0.5) - 0.5);
	float aw = fwidth(a * segs) * 1.2 + 0.006;
	float sep = (1.0 - smoothstep(0.0, aw, abs(cell - 0.035))) * step(0.17, r) * step(r, 0.83);
	// 一道繞著轉的光
	float sweep = pow(0.5 + 0.5 * sin(a * 6.2831853 - TIME * 0.7), 10.0);
	float body = 0.10 + 0.10 * sweep + 0.10 * lit;
	float v = body + lines * 0.9 + tick * tick_band * 0.28 + sep * 0.6;
	float cam_d = length(VERTEX);
	float nearfade = fade_near > 0.0 ? smoothstep(fade_near * 0.5, fade_near, cam_d) : 1.0;
	ALBEDO = gold * v * strength * (1.0 + 0.3 * lit) * nearfade;
}
