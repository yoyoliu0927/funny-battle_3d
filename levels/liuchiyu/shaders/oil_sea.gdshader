shader_type spatial;
render_mode unshaded, fog_disabled;
// 油畫風的海：深藍的底色上一筆一筆的筆觸，繞著島排成一圈一圈的同心圓。每一筆沿著自己那一圈慢慢滑動，
// 明暗也會隨時間變化，所以整片海看起來在流動。朝太陽／月亮的方向亮的筆觸比較多（反光），
// 靠近岸邊有白色的浪花筆觸。越遠筆觸越大，遠處才不會閃爍。
uniform float night = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 day_deep : source_color = vec3(0.10, 0.27, 0.40);
uniform vec3 day_mid : source_color = vec3(0.19, 0.42, 0.54);
uniform vec3 day_light : source_color = vec3(0.31, 0.55, 0.63);
uniform vec3 day_glint : source_color = vec3(1.0, 0.92, 0.70);
uniform vec3 day_foam : source_color = vec3(0.93, 0.96, 0.93);
uniform vec3 night_deep : source_color = vec3(0.03, 0.09, 0.16);
uniform vec3 night_mid : source_color = vec3(0.06, 0.17, 0.27);
uniform vec3 night_light : source_color = vec3(0.14, 0.32, 0.44);
uniform vec3 night_glint : source_color = vec3(0.55, 0.74, 0.86);
uniform vec3 night_foam : source_color = vec3(0.50, 0.74, 0.80);
uniform vec3 day_haze : source_color = vec3(0.80, 0.84, 0.82);
uniform vec3 night_haze : source_color = vec3(0.04, 0.12, 0.17);
uniform float flow = 1.0;
uniform vec2 center = vec2(0.0);    // 島的中心（世界座標 x, z）            // 流動的速度
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// 一層橫向的筆觸：回傳 (這一筆現在的明暗 0～1 上下, 筆觸的遮罩)
vec2 strokes(vec2 p, float size, float seed) {
	// 用「離島中心多遠」和「繞島的角度」來排筆觸：一圈一圈的同心圓，每一筆都順著圓周
	vec2 rel = p - center;
	float rad = length(rel) + (vnoise(rel * 0.03 + seed) - 0.5) * 6.0;      // 圓圈稍微歪一點，不要太規則
	float rowf = rad / size * 6.0;               // 又長又扁的筆觸：一圈的寬度是筆長的六分之一
	float row = floor(rowf);
	float rr = hash(vec2(row, seed));
	// 這一圈可以排幾筆（取整數，繞一圈回來才接得起來）
	float n = max(floor(6.2832 * (row + 0.5) / 6.0), 4.0);
	float u = atan(rel.y, rel.x) / 6.2832 + 0.5;
	// 每一圈用自己的速度順時針或逆時針繞著島滑
	u += rr + TIME * flow * (0.10 + 0.22 * rr) * (mod(row, 2.0) < 1.0 ? 1.0 : -0.7) / n;
	vec2 q = vec2(fract(u) * n, rowf);
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float len = 0.34 + 0.14 * hash(id + 5.0);
	float d = max(abs(f.x) - len, abs(f.y) - 0.33);
	d += (vnoise(q * vec2(7.0, 2.5) + seed) - 0.5) * 0.22;
	float m = smoothstep(0.05, -0.02, d);
	float tone = hash(id + seed * 13.0) + 0.30 * sin(TIME * flow * (0.5 + hash(id + 9.0)) + hash(id + 3.0) * 6.283);
	return vec2(tone, m);
}

vec3 sea(vec2 p, float sc, float glint, float shore, vec3 deep, vec3 mid, vec3 light, vec3 gl, vec3 foam) {
	vec3 col = deep * (0.88 + 0.24 * vnoise(p * 0.04 / sc));
	vec2 s = strokes(p, 2.6 * sc, 1.0);
	col = mix(col, s.x > 0.55 ? mid : deep * 0.78, s.y * 0.9);
	s = strokes(p, 1.6 * sc, 2.0);
	float t = s.x + glint * 0.45 + shore * 0.25;
	col = mix(col, t > 1.15 ? light : mid, s.y * step(0.62, t));
	s = strokes(p, 0.95 * sc, 3.0);
	t = s.x + glint * 0.95 + shore * 0.45;
	vec3 c = t > 1.45 ? gl : light;
	c = mix(c, foam, step(0.55, shore) * step(0.45, s.x));
	col = mix(col, c, s.y * step(1.06, t));
	return col;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_cam = CAMERA_POSITION_WORLD - wp;
	float dist = length(to_cam);
	vec3 v = to_cam / dist;
	// 水面把視線往上反射，越對準太陽／月亮越亮：一條反光的路
	vec3 r = reflect(-v, vec3(0.0, 1.0, 0.0));
	float glint = pow(max(dot(r, normalize(sun_dir)), 0.0), 14.0);
	float shore = 1.0 - COLOR.r;          // 1 = 貼著岸邊，0 = 外海
	vec3 deep = mix(day_deep, night_deep, night);
	vec3 mid = mix(day_mid, night_mid, night);
	vec3 light = mix(day_light, night_light, night);
	vec3 gl = mix(day_glint, night_glint, night);
	vec3 foam = mix(day_foam, night_foam, night);
	// 越遠筆觸越大（每遠一倍放大一倍），兩級之間慢慢換
	float lod = log2(max(dist, 14.0) / 14.0);
	float l0 = floor(lod);
	float sc = exp2(l0);
	vec3 col = sea(wp.xz, sc, glint, shore, deep, mid, light, gl, foam);
	float k = smoothstep(0.55, 1.0, lod - l0);
	if (k > 0.0) {
		col = mix(col, sea(wp.xz, sc * 2.0, glint, shore, deep, mid, light, gl, foam), k);
	}
	// 自己算遠處的霧（場景的霧會把低處的海整片蓋掉）：越遠越接近地平線的顏色
	col = mix(col, mix(day_haze, night_haze, night), (1.0 - exp(-dist * 0.0035)) * 0.9);
	ALBEDO = col;
}
