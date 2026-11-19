// 結局的大鳳凰：不透明的金色剪影（一般混色，不會被背後的光環洗成一片白）。
// 由下往上從橘紅到亮金，一道一道的羽毛紋，邊上一圈亮；整隻自己發光。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;   // 不透明

uniform vec3 tone : source_color = vec3(1.0);    // 這一層的顏色（grad = 0 的時候用）
uniform float grad = 1.0;                         // 1＝由下往上朱紅到金的漸層；0＝整層用 tone
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float h = clamp((lp.y + 2.6) / 4.7, 0.0, 1.0);
	vec3 c = mix(vec3(0.96, 0.22, 0.04), vec3(1.0, 0.70, 0.12), smoothstep(0.15, 0.80, h));
	c = mix(c, vec3(1.0, 0.95, 0.62), smoothstep(0.8, 1.0, h) * 0.7);
	float stripe = 0.5 + 0.5 * sin(abs(lp.x) * 11.0 - lp.y * 5.0 + TIME * 1.5);
	c *= 0.86 + 0.20 * smoothstep(0.3, 0.7, stripe);
	float pulse = 0.5 + 0.5 * sin(lp.y * 3.0 - TIME * 3.0);
	vec3 flat_c = tone * (0.90 + 0.14 * smoothstep(0.3, 0.7, stripe));
	ALBEDO = mix(flat_c, c + vec3(0.22, 0.14, 0.03) * pulse, grad);
}
