// 冰雪島的天空：頭頂→地平線漸層，地平線一條亮亮的霧帶（海面遠處也是這個顏色，海天相接看不到縫）；少量柔和的雲、太陽的光暈、傍晚的星星。
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.30, 0.62, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.92, 1.0);
uniform vec3 mist_color : source_color = vec3(0.88, 0.94, 1.0);
uniform vec3 abyss_color : source_color = vec3(0.62, 0.76, 0.95);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.80, 0.88, 0.98);
uniform vec3 sun_glow : source_color = vec3(1.0, 0.9, 0.7);
uniform float stars = 0.0;
uniform float aurora = 0.0;                                      // 極光的強度（夜空才有）
uniform vec3 aurora_a : source_color = vec3(0.20, 1.0, 0.70);    // 極光下緣（青綠）
uniform vec3 aurora_b : source_color = vec3(0.45, 0.40, 1.0);    // 極光上緣（紫）
uniform float aurora_elev = 0.28;                                // 極光下緣多高（收尾鏡頭會把它壓低一點，整條才進得了畫面）
uniform float aurora_speed = 1.0;                                // 極光流動的速度（收尾時加快）
uniform float cloud_cover = 0.0;                                 // 雲量：0 = 零星幾朵，1 = 整片陰天
uniform float glow_band = 0.85;                                  // 地平線那條亮帶多明顯
uniform float band_thin = 11.0;                                  // 亮帶多窄（越大越貼著地平線）

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm2(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * n2(p); p = p * 2.1 + 3.7; a *= 0.5; } return s; }

void sky() {
	vec3 d = EYEDIR;
	vec3 col;
	if (d.y >= 0.0) {
		col = mix(horizon_color, top_color, pow(d.y, 0.55));
		vec2 uv = d.xz / (d.y + 0.22) * 1.2 + vec2(TIME * 0.004, 0.0);
		float c = fbm2(uv * vec2(0.7, 1.5));
		float cl = smoothstep(0.57 - cloud_cover * 0.42, 0.68 - cloud_cover * 0.36, c);
		cl = max(cl, cloud_cover * 0.75);
		vec3 cc = mix(cloud_shade, cloud_color, smoothstep(0.63, 0.80, c));
		col = mix(col, cc, cl * smoothstep(0.03, 0.22, d.y) * mix(0.7, 0.95, cloud_cover));
		if (stars > 0.0) {
			// 星星：把視線方向切成小方格，每格最多一顆（不會因為靠近天頂或地平線被拉長），三種大小
			vec3 q = d * 64.0;
			vec3 cell = floor(q);
			float h = fract(sin(dot(cell, vec3(127.1, 311.7, 74.7))) * 43758.5453);
			float hs = fract(h * 57.31);
			float r = hs < 0.60 ? 0.11 : (hs < 0.90 ? 0.18 : 0.27);
			float st = step(0.90, h) * smoothstep(r, r * 0.35, length(q - cell - 0.5));
			col += vec3(st) * stars * smoothstep(0.03, 0.3, d.y) * (1.0 - cl) * (0.65 + 0.35 * hs);
		}
		if (aurora > 0.0) {
			// 極光：一條彎彎的光帶橫過北邊的天空。三層粗細不同的垂直光束（雜訊只沿水平方向變、垂直方向拉長），
			// 每一束高矮不一；下緣柔柔地淡出，下面青綠、往上變紫，最上面帶一點洋紅。
			float az = atan(d.x, -d.z);                                  // 0 = 正北
			float at = TIME * aurora_speed;
			float e0 = aurora_elev + 0.07 * sin(az * 1.7 + 0.6) + 0.035 * sin(az * 4.3 + at * 0.05);
			float t = (d.y - e0) / 0.26;                                 // 0 = 下緣，1 = 上緣
			float r1 = n2(vec2(az * 17.0 + at * 0.05, 0.5));
			float r2 = n2(vec2(az * 43.0 - at * 0.08, 3.1));
			float r3 = n2(vec2(az * 6.0 + at * 0.02, 7.7));
			float rays = 0.30 + 0.70 * (r1 * 0.45 + r2 * 0.25 + r3 * 0.40);
			float top = 1.0 - smoothstep(0.20 + 0.55 * r1, 0.75 + 0.55 * r1, t);
			float bottom = smoothstep(-0.16, 0.12, t);
			float span = smoothstep(2.6, 1.2, abs(az));                  // 只在北半邊
			vec3 ac = mix(aurora_a, aurora_b, smoothstep(0.15, 0.80, t));
			ac = mix(ac, vec3(0.95, 0.30, 0.80), smoothstep(0.55, 1.10, t) * 0.55);
			ac = mix(vec3(dot(ac, vec3(0.3, 0.59, 0.11))), ac, 0.85);    // 彩度降一成半
			col += ac * bottom * top * rays * span * aurora * (1.0 - cl * 0.7);
		}
	} else {
		col = mix(mist_color, abyss_color, smoothstep(0.0, 0.75, -d.y));
	}
	col = mix(col, mist_color, exp(-abs(d.y) * band_thin) * glow_band);
	if (LIGHT0_ENABLED) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += sun_glow * (pow(sd, 18.0) * 0.35 + pow(sd, 600.0) * 1.6);
	}
	COLOR = col;
}
