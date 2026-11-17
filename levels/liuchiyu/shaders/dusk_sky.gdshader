// 劉起佑版：黃昏童話天空——頭頂深藍綠、中段灰紫、地平線橘粉，加上被夕陽從下面打亮的長條雲
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.04, 0.15, 0.28);
uniform vec3 mid_color : source_color = vec3(0.22, 0.44, 0.60);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.50, 0.42);
uniform vec3 glow_color : source_color = vec3(1.0, 0.52, 0.24);
uniform vec3 cloud_dark : source_color = vec3(0.17, 0.15, 0.30);
uniform vec3 cloud_lit : source_color = vec3(0.95, 0.56, 0.46);
uniform vec3 below_color : source_color = vec3(0.26, 0.25, 0.42);

float h1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h1(i), h1(i + vec2(1, 0)), f.x), mix(h1(i + vec2(0, 1)), h1(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * n2(p); p = p * 2.07 + 3.7; a *= 0.5; } return s; }

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(-0.02, 0.26, y));
	col = mix(col, top_color, smoothstep(0.18, 0.85, y));
	// 太陽那一側的地平線特別暖
	vec2 flat_d = normalize(d.xz + vec2(0.0001));
	vec2 sun_d = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001));
	float side = max(dot(flat_d, sun_d), 0.0);
	float low = exp(-max(y, 0.0) * 5.5);
	col += glow_color * pow(side, 2.5) * low * 0.55;
	// 背對太陽那一側偏冷
	col = mix(col, col * vec3(0.78, 0.92, 1.08), (1.0 - side) * low * 0.6);
	if (y > 0.0) {
		vec2 uv = d.xz / (y + 0.22);
		// 長條雲：橫向拉很長，慢慢飄
		float c = fbm(uv * vec2(0.35, 1.5) + vec2(TIME * 0.006, 0.0));
		float cl = smoothstep(0.50, 0.66, c) * smoothstep(0.02, 0.22, y) * (1.0 - smoothstep(0.55, 0.95, y));
		// 雲的下緣被夕陽照亮
		float under = smoothstep(0.50, 0.58, c) * (1.0 - smoothstep(0.58, 0.72, c));
		vec3 cc = mix(cloud_dark, cloud_lit, under * (0.35 + 0.65 * side) * (1.0 - smoothstep(0.1, 0.6, y)));
		col = mix(col, cc, cl * 0.85);
		// 高處幾顆小星星
		vec2 su = d.xz / (1.0 + y) * 40.0;
		vec2 id = floor(su);
		vec2 f = fract(su) - 0.5;
		float pick = h1(id + 5.0);
		if (pick > 0.90) {
			vec2 off = vec2(h1(id + 1.3), h1(id + 7.7)) * 0.5 - 0.25;
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + pick * 3.0) + pick * 40.0);
			float st = smoothstep(0.09, 0.0, length(f - off)) * tw;
			col += vec3(1.0, 0.92, 0.75) * st * smoothstep(0.3, 0.7, y) * (1.0 - cl) * 1.4;
		}
	} else {
		col = mix(col, below_color, smoothstep(0.0, -0.08, y));
	}
	COLOR = col;
}
