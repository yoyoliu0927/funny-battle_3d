shader_type sky;
// 秋天樹林的天空：藍天上一大團一大團的積雲，用方塊狀的平塗筆觸畫出來
// （亮面是暖白、中間是淡藍灰、背光面是藍綠），地平線和太陽那一側帶金黃色的陽光。
uniform vec3 top : source_color = vec3(0.38, 0.55, 0.74);
uniform vec3 mid : source_color = vec3(0.62, 0.75, 0.86);
uniform vec3 low : source_color = vec3(1.0, 0.92, 0.68);
uniform vec3 gold : source_color = vec3(1.0, 0.78, 0.36);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.93);
uniform vec3 cloud_mid : source_color = vec3(0.80, 0.88, 0.94);
uniform vec3 cloud_shade : source_color = vec3(0.64, 0.76, 0.82);
uniform float night = 0.0;          // 0 = 白天，1 = 有極光的夜晚
uniform float coverage = 0.50;      // 雲量，越大雲越多
uniform float dab = 105.0;          // 雲邊緣的筆觸大小，越大筆觸越小
uniform float shade_dab = 48.0;     // 雲裡面明暗色塊的大小

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
// 一顆一顆圓球鼓起來的雜訊（離最近的點越近越大）
float puff(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	float d = 1.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + hash3(i + o) - f;
		d = min(d, dot(r, r));
	}
	return 1.0 - sqrt(d);
}
// 雲的厚度：大塊的形狀 + 兩層圓鼓鼓的小球
float density(vec3 d) {
	vec3 p = d * vec3(1.0, 1.3, 1.0);
	float shape = vnoise(p * 1.3 + 4.0) * 0.7 + vnoise(p * 2.9 + 9.0) * 0.3;
	float v = (shape - (1.06 - coverage)) * 2.2;
	v += (puff(p * 3.6) - 0.6) * 0.36;
	v += (puff(p * 8.5 + 3.0) - 0.6) * 0.15;
	return v;
}

// 夜空：深藍綠色的底、橫向的筆觸、星星，加上會飄動的極光
// 晚上的天空也用筆觸畫：深藍綠的底色上有一條一條斜斜的長筆觸，
// 極光是一排一排直的筆觸——每一筆有自己的長度、亮度和顏色，下緣是一格一格的，上面是參差的尖頭。
vec3 night_sky(vec3 dir) {
	float h = max(dir.y, 0.0);
	float a = atan(dir.x, -dir.z);
	float e = asin(clamp(dir.y, -1.0, 1.0));
	vec3 col = mix(vec3(0.008, 0.050, 0.058), vec3(0.002, 0.014, 0.028), smoothstep(0.0, 0.9, h));
	// 底色：一大塊一大塊平塗，明暗稍微不同
	// 把天空攤平成一張圓頂的圖來排筆觸，頭頂正上方才不會擠成一個漩渦
	vec2 dome = dir.xz / (max(dir.y, 0.0) + 0.45);
	vec2 bq = vec2(dome.x * 2.2 + dome.y * 0.5, dome.y * 7.0 - dome.x * 0.8);
	bq.x += floor(bq.y) * 0.37;
	col *= 0.78 + 0.40 * hash3(vec3(floor(bq), 3.0)).x;
	// 星星
	vec3 sc = floor(dir * 130.0);
	col += vec3(0.9, 0.95, 1.0) * step(0.9975, hash3(sc).x) * smoothstep(0.05, 0.3, h);

	// 極光：每一道是連續的一整片光幕（下緣是一條平滑起伏的弧線，整片連在一起），
	// 再用很細的直筆觸決定每個地方往上拉多長，所以上緣是參差的尖頭，裡面有一絲一絲的直紋。
	vec3 glow = vec3(0.0);
	float cover = 0.0;
	vec2 cc = vec2(cos(a), sin(a));
	for (int i = 0; i < 3; i++) {
		float ph = float(i) * 2.1;
		float e0 = 0.30 + 0.17 * float(i) + 0.13 * sin(a * 2.0 + TIME * 0.12 + ph) + 0.06 * sin(a * 5.0 - TIME * 0.19 + ph * 2.0);
		float presence = smoothstep(0.50, 0.66, vnoise(vec3(cc * 1.5 + ph * 3.0, TIME * 0.05)));
		float base_len = 0.10 + 0.30 * vnoise(vec3(cc * 5.0 + ph, TIME * 0.15));
		float tone = vnoise(vec3(cc * 1.3 + ph * 5.0, TIME * 0.04));
		// 兩層細筆觸（粗的、細的）：每一筆只改變「長度」和一點點亮度，不留空隙
		float streak_len = 0.0;
		float streak_b = 0.0;
		float edge = 0.0;
		for (int k = 0; k < 2; k++) {
			float w = k == 0 ? 0.014 : 0.0045;
			float id = floor(a / w + ph * 7.0);
			vec3 r = hash3(vec3(id, float(i) * 17.0 + float(k) * 5.0, 1.0));
			float flick = 0.85 + 0.15 * sin(TIME * (0.5 + r.z) + id);
			streak_len += (k == 0 ? 0.65 : 0.35) * (0.20 + 1.6 * r.y * r.y) * flick;
			streak_b += (k == 0 ? 0.6 : 0.4) * (0.40 + 0.60 * r.x);
			edge += (r.z - 0.5) * (k == 0 ? 0.012 : 0.006);
		}
		float d = e - e0 - edge;
		float len = base_len * streak_len;
		float t = d / len;
		// 亮度：下緣最亮，平滑地往上淡掉（沒有分階，光幕才是連續的）
		float body = step(0.0, d) * pow(clamp(1.0 - t, 0.0, 1.0), 1.7) * streak_b;
		// 整片光幕外面一層柔柔的光暈，把筆觸連在一起
		float d0 = e - e0;
		float halo = (d0 > 0.0 ? exp(-d0 / (base_len * 0.55)) : exp(d0 * 45.0)) * 0.12;
		float inten = (body + halo) * presence * smoothstep(1.2, 0.9, e);
		// 顏色：整片以綠色為主，有些段落是青色；最下緣偏白，最頂端只帶一點點藍紫
		float tt = clamp(d0 / (base_len * 1.2), 0.0, 1.0);
		vec3 ac = mix(vec3(0.22, 1.0, 0.14), vec3(0.03, 0.95, 0.70), smoothstep(0.46, 0.64, tone));
		ac = mix(ac, vec3(0.03, 0.85, 0.36), smoothstep(0.20, 0.50, tt) * 0.6);
		ac = mix(ac, vec3(0.04, 0.62, 0.80), smoothstep(0.55, 0.95, tt) * 0.5);
		ac = mix(ac, vec3(0.22, 0.26, 0.85), smoothstep(0.85, 1.0, tt) * 0.35);
		ac = mix(ac, vec3(0.80, 1.0, 0.88), smoothstep(0.14, 0.0, tt) * step(0.0, d) * 0.30);
		// 頂端外面一圈很淡的藍紫
		float tu = d0 / (base_len * 1.2);
		float fringe = step(0.0, d0) * smoothstep(0.55, 0.9, tu) * smoothstep(1.5, 1.0, tu) * 0.015 * presence * smoothstep(1.2, 0.9, e);
		glow += ac * (inten * (1.7 - 0.2 * float(i)) + fringe);
		cover = max(cover, clamp(inten * 1.6, 0.0, 1.0));
	}
	float up = smoothstep(-0.02, 0.08, dir.y);
	col = col * (1.0 - cover * up * 0.7) + glow * up;
	// 最上面再刷幾筆細細斜斜的淺色長筆觸，蓋過天空和極光
	vec2 sq = vec2(dome.x * 2.6 + dome.y * 0.9, (dome.y - dome.x * 0.22) * 34.0);
	sq.x += floor(sq.y) * 0.43;
	vec3 sr = hash3(vec3(floor(sq), 9.0));
	float line = step(sr.x, 0.13) * smoothstep(0.5, 0.42, abs(fract(sq.x) - 0.5) + 0.05) * smoothstep(0.5, 0.2, abs(fract(sq.y) - 0.5));
	col += vec3(0.05, 0.14, 0.14) * line * (0.3 + 0.7 * sr.y);
	return col;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = clamp(dir.y, -0.2, 1.0);
	float s = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	// 藍天：越高越深；地平線被陽光染成金黃，太陽那一側染得更高
	vec3 col = mix(mid, top, smoothstep(0.05, 0.85, h));
	col = mix(col, low, smoothstep(0.40 + s * 0.25, 0.0, h));
	col = mix(col, vec3(1.0, 0.86, 0.50), pow(s, 9.0) * 0.75);
	col += vec3(1.0, 0.90, 0.60) * pow(s, 80.0) * 0.9;

	// 把方向切成一小塊一小塊（每塊稍微錯開），每塊只有一個顏色 = 一筆平塗
	vec3 cell = floor(dir * dab);
	vec3 q = normalize((cell + 0.5 + (hash3(cell) - 0.5) * 0.9) / dab);
	float dn = density(q);
	if (dn > 0.0 && h > -0.02) {
		// 明暗用比較大的色塊：往太陽那邊雲比較薄 = 受光面；雲球的頂是亮的，球和球之間的凹縫是暗的
		vec3 cell2 = floor(dir * shade_dab + 7.0);
		vec3 q2 = normalize((cell2 - 7.0 + 0.5 + (hash3(cell2) - 0.5) * 0.9) / shade_dab);
		float jitter = hash3(cell2).y;
		float d2 = density(q2);
		float toward = density(normalize(q2 + LIGHT0_DIRECTION * 0.14));
		float bump = puff(q2 * vec3(1.0, 1.3, 1.0) * 3.6);
		float lit = clamp(0.60 + (d2 - toward) * 1.3 + (bump - 0.55) * 1.7 + (jitter - 0.5) * 0.08, 0.0, 1.0);
		lit = floor(lit * 4.0 + 0.5) / 4.0;        // 分成幾階平塗的顏色
		vec3 c = mix(cloud_shade, cloud_mid, smoothstep(0.0, 0.5, lit));
		c = mix(c, cloud_lit, smoothstep(0.45, 0.95, lit));
		// 靠近太陽和地平線的雲帶一點金色
		c = mix(c, c * vec3(1.0, 0.90, 0.70) + gold * 0.12, clamp(pow(s, 2.0) * 0.7 + smoothstep(0.25, 0.0, h) * 0.5, 0.0, 0.8) * lit);
		col = mix(col, c, smoothstep(0.02, 0.30, h));
	}
	if (night > 0.001) {
		col = mix(col, night_sky(dir), night);
	}
	COLOR = col;
}
