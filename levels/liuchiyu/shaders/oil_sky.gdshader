shader_type sky;
// 秋天的白天天空：藍天上一大團一大團柔軟的積雲，雲只分三階明暗（暖白、淡藍灰、藍綠的背光面），
// 地平線和太陽那一側帶金黃色的陽光。
// 這個 shader 不用 TIME：反射用的 cubemap 只算一次；雲的雜訊也只剩兩層平滑雜訊＋一層 2×2×2 的圓球雜訊。
// 晚上的極光是另一個 shader（oil_sky_night.gdshader），oil_world.gd 依白天／晚上切換兩個 Sky。
uniform vec3 top : source_color = vec3(0.38, 0.55, 0.74);
uniform vec3 mid : source_color = vec3(0.62, 0.75, 0.86);
uniform vec3 low : source_color = vec3(1.0, 0.92, 0.68);
uniform vec3 gold : source_color = vec3(1.0, 0.78, 0.36);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.93);
uniform vec3 cloud_mid : source_color = vec3(0.84, 0.90, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.66, 0.77, 0.84);
uniform float coverage = 0.50;      // 雲量，越大雲越多

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash3(i).x, hash3(i + vec3(1, 0, 0)).x, f.x);
	float b = mix(hash3(i + vec3(0, 1, 0)).x, hash3(i + vec3(1, 1, 0)).x, f.x);
	float c = mix(hash3(i + vec3(0, 0, 1)).x, hash3(i + vec3(1, 0, 1)).x, f.x);
	float d = mix(hash3(i + vec3(0, 1, 1)).x, hash3(i + vec3(1, 1, 1)).x, f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}
// 一顆一顆圓球鼓起來的雜訊（離最近的點越近越大）。只找最近的 2×2×2 格（原本 3×3×3），省一大半
float puff(vec3 p) {
	vec3 i = floor(p - 0.5); vec3 f = p - i;
	float d = 1.0;
	for (int x = 0; x <= 1; x++) for (int y = 0; y <= 1; y++) for (int z = 0; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + 0.25 + 0.5 * hash3(i + o) - f;      // 點只在格子中間一半的範圍晃，最近的點才一定在這 2×2×2 格裡（不會有接縫）
		d = min(d, dot(r, r));
	}
	return 1.0 - sqrt(d);
}
float shape(vec3 p) {
	return vnoise(p * 1.3 + 4.0) * 0.7 + vnoise(p * 2.9 + 9.0) * 0.3;
}

vec3 sky_base(vec3 dir, float s) {
	float h = clamp(dir.y, -0.2, 1.0);
	vec3 col = mix(mid, top, smoothstep(0.05, 0.85, h));
	col = mix(col, low, smoothstep(0.40 + s * 0.25, 0.0, h));
	col = mix(col, vec3(1.0, 0.86, 0.50), pow(s, 9.0) * 0.75);
	col += vec3(1.0, 0.90, 0.60) * pow(s, 80.0) * 0.9;
	return col;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float s = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	vec3 col = sky_base(dir, s);
	float h = dir.y;
	if (!AT_CUBEMAP_PASS && h > 0.0) {
		// 雲（反射用的小圖不畫雲）
		vec3 p = dir * vec3(1.0, 1.3, 1.0);
		float sh = shape(p);
		float bump = puff(p * 3.6);
		float dn = (sh - (1.06 - coverage)) * 2.2 + (bump - 0.6) * 0.40;
		// 往太陽那邊雲比較薄 = 受光面；雲球的頂是亮的，球和球之間的凹縫是暗的
		float toward = shape(p + LIGHT0_DIRECTION * vec3(1.0, 1.3, 1.0) * 0.14);
		float lit = clamp(0.62 + (sh - toward) * 2.6 + (bump - 0.55) * 1.5, 0.0, 1.0);
		// 三階明暗，交界稍微柔和
		vec3 c = mix(cloud_shade, cloud_mid, smoothstep(0.30, 0.36, lit));
		c = mix(c, cloud_lit, smoothstep(0.64, 0.70, lit));
		// 靠近太陽和地平線的雲帶一點金色
		c = mix(c, c * vec3(1.0, 0.90, 0.70) + gold * 0.12, clamp(pow(s, 2.0) * 0.7 + smoothstep(0.25, 0.0, h) * 0.5, 0.0, 0.8) * lit);
		col = mix(col, c, smoothstep(0.0, 0.03, dn) * smoothstep(0.02, 0.30, h));
	}
	COLOR = col;
}
