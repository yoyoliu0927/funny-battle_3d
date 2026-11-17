shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// 油畫風的河和瀑布：一筆一筆順著水流方向的長筆觸，整片往下游流。
// UV.x = 橫跨河面（0～1），UV.y = 沿著河走了幾公尺；COLOR.r = 1 的地方是瀑布（比較白、流得比較快）。
uniform float night = 0.0;
uniform vec3 day_deep : source_color = vec3(0.12, 0.32, 0.44);
uniform vec3 day_mid : source_color = vec3(0.22, 0.47, 0.58);
uniform vec3 day_light : source_color = vec3(0.50, 0.72, 0.76);
uniform vec3 day_foam : source_color = vec3(0.94, 0.97, 0.94);
uniform vec3 night_deep : source_color = vec3(0.03, 0.10, 0.18);
uniform vec3 night_mid : source_color = vec3(0.07, 0.20, 0.31);
uniform vec3 night_light : source_color = vec3(0.20, 0.42, 0.54);
uniform vec3 night_foam : source_color = vec3(0.62, 0.84, 0.90);
uniform float flow = 1.0;            // 流速
uniform float width = 3.6;           // 河多寬（公尺），算筆觸粗細用

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// 一層順著水流的筆觸：回傳 (這一筆的明暗, 遮罩)
vec2 strokes(vec2 p, float lanes, float len, float speed, float seed) {
	// p.x = 橫向 0～1，p.y = 沿河的公尺數
	float lane = floor(p.x * lanes);
	float rl = hash(vec2(lane, seed));
	float y = (p.y - TIME * flow * speed * (0.75 + 0.5 * rl)) / len + rl * 9.0;
	vec2 id = vec2(lane, floor(y));
	vec2 f = vec2(fract(p.x * lanes), fract(y)) - 0.5;
	float l = 0.34 + 0.14 * hash(id + 5.0);
	float d = max(abs(f.y) - l, abs(f.x) - 0.36);
	d += (vnoise(vec2(p.x * lanes * 3.0, y * 5.0) + seed) - 0.5) * 0.22;
	return vec2(hash(id + seed * 13.0), smoothstep(0.05, -0.02, d));
}

void fragment() {
	float fall = COLOR.r;
	vec3 deep = mix(day_deep, night_deep, night);
	vec3 mid = mix(day_mid, night_mid, night);
	vec3 light = mix(day_light, night_light, night);
	vec3 foam = mix(day_foam, night_foam, night);
	vec2 p = UV;
	float lanes = max(floor(width / 0.55), 3.0);
	float speed = mix(1.4, 6.5, fall);
	float len = mix(1.5, 2.6, fall);
	// 靠兩岸的地方、還有瀑布，白色的水花比較多
	float edge = smoothstep(0.30, 0.48, abs(p.x - 0.5));
	float white = max(fall * 0.75, edge * 0.5);
	vec3 col = mix(deep, mid, fall * 0.7);
	vec2 s = strokes(p, lanes * 0.6, len * 1.6, speed, 1.0);
	col = mix(col, s.x > 0.5 ? mid : deep * 0.8, s.y * (1.0 - fall * 0.6));
	s = strokes(p + vec2(0.13, 0.0), lanes, len, speed * 1.15, 2.0);
	col = mix(col, s.x + white * 0.4 > 0.8 ? light : mid, s.y * step(0.35, s.x + white));
	s = strokes(p + vec2(0.31, 0.0), lanes * 1.5, len * 0.7, speed * 1.3, 3.0);
	col = mix(col, s.x + white > 1.15 ? foam : light, s.y * step(0.85, s.x + white));
	ALBEDO = col;
}
