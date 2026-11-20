// 風格化天空：青綠漸層 + 手繪感雲朵
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.42, 0.74, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.90, 0.90);
uniform vec3 cloud_color : source_color = vec3(0.97, 0.98, 0.94);
uniform vec3 cloud_shade : source_color = vec3(0.76, 0.86, 0.85);
// 選關畫面的農莊天色用（預設全部關掉，別的場景看不到）：星星、太陽、月亮
uniform float night = 0.0;
uniform float sun_vis = 0.0;
uniform float moon_vis = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm2(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * n2(p); p = p * 2.1 + 3.7; a *= 0.5; } return s; }

void sky() {
	vec3 d = EYEDIR;
	float y = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(y, 0.6));
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.25) * 1.3 + vec2(TIME * 0.004, 0.0);
		float c = fbm2(uv * vec2(0.8, 1.6));
		float cl = smoothstep(0.5, 0.58, c);
		float inner = smoothstep(0.58, 0.75, c);
		vec3 cc = mix(cloud_shade, cloud_color, inner);
		col = mix(col, cc, cl * smoothstep(0.0, 0.15, d.y) * 0.9);
	} else {
		col = horizon_color;
	}
	// 星星：小格子裡一顆一顆的亮點，會閃；雲蓋住的地方看不到
	if (night > 0.01 && d.y > 0.0) {
		vec3 sp = d * 70.0;
		vec3 g = floor(sp);
		float r = fract(sin(dot(g, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		vec3 ctr = vec3(fract(r * 7.13), fract(r * 3.77), fract(r * 5.31)) * 0.6 + 0.2;
		float dd = length(fract(sp) - ctr);
		float tw = 0.7 + 0.3 * sin(TIME * (1.5 + r * 3.0) + r * 40.0);
		float star = step(0.93, r) * smoothstep(0.16, 0.02, dd) * tw;
		col += vec3(1.0, 0.97, 0.88) * star * night * smoothstep(0.02, 0.2, d.y);
	}
	// 太陽和月亮：一個圓盤＋一圈光暈
	float sd = dot(d, normalize(sun_dir));
	col += (vec3(1.0, 0.86, 0.55) * smoothstep(0.9988, 0.9994, sd) + vec3(1.0, 0.7, 0.4) * pow(max(sd, 0.0), 48.0) * 0.28) * sun_vis;
	float md = dot(d, normalize(moon_dir));
	col += (vec3(0.95, 0.97, 1.0) * smoothstep(0.9984, 0.9990, md) + vec3(0.55, 0.65, 1.0) * pow(max(md, 0.0), 60.0) * 0.30) * moon_vis;
	COLOR = col;
}
