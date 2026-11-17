shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;
// 岩漿：暗紅色的硬殼上，一筆一筆橘色、亮黃色的筆觸慢慢流動、一明一暗，亮的地方會發光。
uniform float heat = 1.0;            // 0 = 快冷掉了（暗），1 = 正熱
uniform float scale = 1.6;
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (wp.xz + wp.y * 0.6) * scale;
	vec2 q = vec2(p.x + vnoise(p * 0.5 + TIME * 0.2) * 1.5, p.y * 2.6 + TIME * 0.35);
	vec2 id = floor(q);
	float r = hash(id);
	float glow = 0.5 + 0.5 * sin(TIME * (1.0 + r * 2.0) + r * 6.283);
	float tone = r * 0.6 + glow * 0.4 + (vnoise(p * 1.7) - 0.5) * 0.3;
	vec3 crust = vec3(0.30, 0.04, 0.02);
	vec3 orange = vec3(1.0, 0.36, 0.04) * 1.8;
	vec3 yellow = vec3(1.0, 0.82, 0.28) * 2.6;
	vec3 c = mix(crust, orange, step(0.38, tone));
	c = mix(c, yellow, step(0.72, tone));
	ALBEDO = mix(crust * 0.6, c, clamp(heat, 0.0, 1.0));
}
