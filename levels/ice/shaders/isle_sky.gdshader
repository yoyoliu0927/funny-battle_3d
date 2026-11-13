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
			col += vec3(st) * stars * smoothstep(0.1, 0.5, d.y) * (1.0 - cl);
		}
	} else {
		col = mix(mist_color, abyss_color, smoothstep(0.0, 0.75, -d.y));
	}
	col = mix(col, mist_color, exp(-abs(d.y) * 11.0) * 0.85);
	if (LIGHT0_ENABLED) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += sun_glow * (pow(sd, 18.0) * 0.35 + pow(sd, 600.0) * 1.6);
	}
	COLOR = col;
}
