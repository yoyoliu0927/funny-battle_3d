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
		float cl = smoothstep(0.57, 0.68, c);
		vec3 cc = mix(cloud_shade, cloud_color, smoothstep(0.63, 0.80, c));
		col = mix(col, cc, cl * smoothstep(0.03, 0.22, d.y) * 0.7);
		if (stars > 0.0) {
			vec2 su = d.xz / (d.y + 0.4) * 60.0;
			float st = step(0.985, h2(floor(su))) * smoothstep(0.75, 0.2, length(fract(su) - 0.5) * 2.0);
			col += vec3(st) * stars * smoothstep(0.06, 0.4, d.y) * (1.0 - cl);
		}
		if (aurora > 0.0) {
			// 一條彎彎的光帶橫過北邊的天空：下緣青綠、往上變紫，裡面有一絲一絲直的光
			float az = atan(d.x, -d.z);                                  // 0 = 正北
			float e0 = 0.30 + 0.07 * sin(az * 1.7 + 0.6) + 0.035 * sin(az * 4.3 + TIME * 0.05);
			float t = (d.y - e0) / 0.20;                                 // 0 = 下緣，1 = 上緣
			float ray = 0.55 + 0.45 * n2(vec2(az * 22.0 + TIME * 0.06, 1.3));
			float body = smoothstep(-0.10, 0.04, t) * (1.0 - smoothstep(0.15, 1.0, t)) * ray;
			float span = smoothstep(2.6, 1.2, abs(az));                  // 只在北半邊
			vec3 ac = mix(aurora_a, aurora_b, smoothstep(0.1, 0.9, t));
			col += ac * body * span * aurora * (1.0 - cl * 0.7);
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
