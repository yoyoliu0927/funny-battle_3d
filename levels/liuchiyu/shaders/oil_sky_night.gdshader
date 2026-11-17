shader_type sky;
// 有極光的夜空：深藍綠色的底、星星，加上兩道慢慢飄動的極光光幕。
// 光幕是柔和連續的一整片（下緣亮、往上淡掉，裡面有細細的直向光絲），顏色由下往上是白綠 → 綠 → 青 → 一點藍紫。
// 白天的天空是另一個 shader（oil_sky.gdshader），oil_world.gd 依白天／晚上切換兩個 Sky。
uniform vec3 zenith : source_color = vec3(0.002, 0.014, 0.028);
uniform vec3 horizon : source_color = vec3(0.010, 0.060, 0.070);
uniform float aurora_strength = 1.0;

float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
// 沿著一圈角度的一維平滑雜訊（period 格繞一圈，接得起來）
float ring_noise(float a, float cells, float seed) {
	float x = a / 6.2832 * cells;
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(mod(i, cells) + seed), hash1(mod(i + 1.0, cells) + seed), f);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = max(dir.y, 0.0);
	vec3 col = mix(horizon, zenith, smoothstep(0.0, 0.9, h));
	if (AT_CUBEMAP_PASS) {
		// 反射用的小圖只要底色和一點極光的綠
		COLOR = col + vec3(0.0, 0.05, 0.03) * smoothstep(0.1, 0.4, h) * aurora_strength;
	} else {
		// 星星
		vec3 sc = floor(dir * 160.0);
		float star = step(0.9978, hash3(sc));
		col += vec3(0.85, 0.92, 1.0) * star * smoothstep(0.05, 0.3, h) * (0.5 + 0.5 * hash3(sc + 7.0));
		float a = atan(dir.x, -dir.z);
		float e = asin(clamp(dir.y, -1.0, 1.0));
		vec3 glow = vec3(0.0);
		for (int i = 0; i < 2; i++) {
			float ph = float(i) * 2.1;
			float fi = float(i);
			// 光幕的下緣：一條平滑起伏的弧線，慢慢左右飄
			float e0 = 0.32 + 0.20 * fi + 0.12 * sin(a * 2.0 + TIME * 0.10 + ph) + 0.05 * sin(a * 5.0 - TIME * 0.16 + ph * 2.0);
			// 哪幾段有光幕（大段大段出現），每段有多高
			float presence = smoothstep(0.35, 0.65, ring_noise(a + TIME * 0.02, 7.0, 3.0 + ph));
			float height = 0.14 + 0.22 * ring_noise(a - TIME * 0.03, 11.0, 9.0 + ph);
			// 很細的直向光絲：讓上緣參差、裡面有一絲一絲的紋路
			float rays = ring_noise(a + TIME * 0.015 * (fi + 1.0), 220.0, 17.0 + ph) * 0.6 + ring_noise(a, 90.0, 23.0 + ph) * 0.4;
			float d = e - e0;
			float t = d / (height * (0.55 + 0.9 * rays));
			float body = step(0.0, d) * pow(clamp(1.0 - t, 0.0, 1.0), 1.6);
			float halo = (d > 0.0 ? exp(-d / (height * 0.6)) : exp(d * 40.0)) * 0.18;
			float inten = (body * (0.65 + 0.35 * rays) + halo) * presence * smoothstep(1.25, 0.9, e);
			// 顏色：下緣偏白綠，往上變綠、青，最頂端帶一點藍紫
			float tt = clamp(d / (height * 1.2), 0.0, 1.0);
			vec3 ac = mix(vec3(0.55, 1.0, 0.60), vec3(0.18, 1.0, 0.30), smoothstep(0.0, 0.15, tt));
			ac = mix(ac, vec3(0.05, 0.85, 0.65), smoothstep(0.30, 0.65, tt));
			ac = mix(ac, vec3(0.30, 0.30, 0.90), smoothstep(0.75, 1.0, tt) * 0.6);
			glow += ac * inten * (1.6 - 0.3 * fi);
		}
		col += glow * smoothstep(-0.02, 0.08, dir.y) * aurora_strength;
		COLOR = col;
	}
}
