// 風格化天空：青綠漸層 + 手繪感雲朵
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.42, 0.74, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.90, 0.90);
uniform vec3 cloud_color : source_color = vec3(0.97, 0.98, 0.94);
uniform vec3 cloud_shade : source_color = vec3(0.76, 0.86, 0.85);

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
	COLOR = col;
}
