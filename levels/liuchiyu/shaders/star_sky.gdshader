// 劉起佑版：舞台布景感的夜空——深藍底＋手繪金色星星
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.012, 0.025, 0.11);
uniform vec3 mid_color : source_color = vec3(0.03, 0.06, 0.24);
uniform vec3 horizon_color : source_color = vec3(0.06, 0.10, 0.32);
uniform vec3 star_color : source_color = vec3(0.95, 0.70, 0.26);
uniform vec3 star_edge : source_color = vec3(0.78, 0.50, 0.14);
uniform float star_brightness = 1.15;
uniform float small_density = 0.55;   // 小五角星出現機率
uniform float big_density = 0.45;     // 大十字閃光出現機率

float h1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h1(i), h1(i + vec2(1, 0)), f.x), mix(h1(i + vec2(0, 1)), h1(i + vec2(1, 1)), f.x), f.y);
}

// n 角星的距離場（負的在裡面）。m 越接近 2 星芒越細長
float sd_star(vec2 p, float r, float n, float m) {
	float an = 3.141593 / n;
	float en = 3.141593 / m;
	vec2 acs = vec2(cos(an), sin(an));
	vec2 ecs = vec2(cos(en), sin(en));
	float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
	p = length(p) * vec2(cos(bn), abs(sin(bn)));
	p -= r * acs;
	p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
	return length(p) * sign(p.x);
}

// n 道細長星芒（閃光那種）：每道是從中心往外收尖、邊緣微微內凹的錐形
float sd_sparkle(vec2 p, float len, float w, float n) {
	float an = 3.141593 / n;
	float b = mod(atan(p.y, p.x) + an, 2.0 * an) - an;
	vec2 q = length(p) * vec2(cos(b), abs(sin(b)));
	float t = clamp(q.x / len, 0.0, 1.0);
	return q.y - w * pow(1.0 - t, 1.4) + max(q.x - len, 0.0);
}

vec2 rot(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }

// 回傳 (覆蓋量, 中心亮度)
vec2 star_layer(vec2 uv, float cell, float density, bool big, float seed) {
	vec2 g = uv / cell;
	vec2 id0 = floor(g);
	float cover = 0.0;
	float shade = 0.0;
	float aa = 0.0016;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = id0 + vec2(float(i), float(j));
			float pick = h1(id + seed);
			if (pick > density) continue;
			vec2 rnd = h22(id + seed * 1.7);
			vec2 c = (id + 0.2 + rnd * 0.6) * cell;
			vec2 p = uv - c;
			float size = mix(0.6, 1.0, h1(id + seed + 9.1));
			float d;
			float r;
			if (big) {
				// 大的：四道長星芒＋四道短的斜星芒
				r = cell * 0.30 * size;
				vec2 pr = rot(p, (rnd.x - 0.5) * 0.15);
				float d1 = sd_sparkle(pr, r, r * 0.20, 4.0);
				float d2 = sd_sparkle(rot(pr, 0.785398), r * 0.45, r * 0.13, 4.0);
				d = min(d1, d2);
			} else if (pick < density * 0.2) {
				// 偶爾一顆小十字閃光
				r = cell * 0.30 * size;
				d = sd_sparkle(rot(p, (rnd.x - 0.5) * 0.3), r, r * 0.26, 4.0);
			} else {
				// 小五角星，隨機歪一點
				r = cell * 0.16 * size;
				d = sd_star(rot(p, (rnd.y - 0.5) * 1.2), r, 5.0, 2.8);
			}
			float a = 1.0 - smoothstep(-aa, aa, d);
			cover = max(cover, a);
			// 中心比較亮、邊緣比較暗，像金箔紙
			shade = max(shade, a * (1.0 - clamp(length(p) / r, 0.0, 1.0)));
		}
	}
	return vec2(cover, shade);
}

void sky() {
	vec3 d = EYEDIR;
	float y = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.35, y));
	col = mix(col, top_color, smoothstep(0.3, 1.0, y));
	if (d.y > -0.02) {
		// 立體投影：整個上半球都連續、不會在頭頂擠在一起
		vec2 uv = d.xz / (1.0 + max(d.y, 0.0));
		// 布景上不均勻的刷痕
		float brush = n2(uv * vec2(9.0, 3.0)) * 0.6 + n2(uv * 23.0) * 0.4;
		col *= mix(0.85, 1.12, brush);
		vec2 s1 = star_layer(uv, 0.085, small_density, false, 3.0);
		vec2 s2 = star_layer(uv, 0.30, big_density, true, 17.0);
		float cover = max(s1.x, s2.x);
		float shade = max(s1.y, s2.y);
		vec3 sc = mix(star_edge, star_color, smoothstep(0.0, 0.6, shade)) * star_brightness;
		float fade = smoothstep(-0.02, 0.06, d.y);
		col = mix(col, sc, cover * fade);
	}
	COLOR = col;
}
