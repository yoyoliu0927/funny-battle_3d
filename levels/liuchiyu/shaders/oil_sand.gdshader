shader_type spatial;
render_mode cull_disabled;
// 沙地：一道一道被風吹出來的沙紋（兩階顏色，像顏料刷出來的），邊緣顏色深一點，跟橘色的地面分得開。
// hl > 0：現在用風吹它會有反應 —— 整塊沙蓋上一層白（跟其他可以互動的東西一樣，不會閃）。
// 全部都是算出來的，沒有貼圖；一塊沙只有幾百個三角形。

uniform float hl = 0.0;          // 0 = 平常、1 = 準心正指著它而且可以吹
uniform float seed = 0.0;        // 每塊沙的沙紋長得不一樣

varying vec3 lp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 p = lp.xz;
	float d = COLOR.r;        // 0 = 沙地中心、1 = 最外圈（頂點顏色帶進來的）
	// 沙紋：彎彎的平行線
	float bend = vnoise(p * 0.55 + seed) * 5.0;
	float rip = sin((p.x * 0.85 + p.y * 0.4) * 4.2 + bend);
	float band = smoothstep(-0.15, 0.15, rip);
	vec3 col = mix(vec3(0.70, 0.52, 0.27), vec3(0.90, 0.74, 0.43), band);
	// 沙紋的亮面上再加一條更亮的細線（稜線）
	col = mix(col, vec3(0.98, 0.86, 0.56), smoothstep(0.82, 0.95, rip));
	// 一小塊一小塊的深淺，像筆觸
	col *= 0.93 + 0.14 * hash(floor(p * 5.0) + seed);
	// 邊緣顏色深、帶一點濕沙的感覺
	col = mix(col, vec3(0.50, 0.35, 0.18), smoothstep(0.70, 1.0, d));
	// 可以吹的時候：蓋一層白
	col = mix(col, vec3(1.0), hl * 0.42);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
