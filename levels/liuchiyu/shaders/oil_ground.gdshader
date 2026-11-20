shader_type spatial;
// 油畫風的地面：幾層大筆觸疊出滿地落葉——底色是深紅棕，上面疊棕、鏽橘，
// 只有陽光照到的光斑才有幾筆土黃。顏色故意只用相近的幾個，角色站在上面才看得清楚。

// 陰影裡的顏色：色相很多（紅棕、紫、深綠、鏽橘、棕），但明暗差不多，所以看起來豐富卻不花
uniform vec3 sh1 : source_color = vec3(0.40, 0.17, 0.15);
uniform vec3 sh2 : source_color = vec3(0.31, 0.21, 0.38);
uniform vec3 sh3 : source_color = vec3(0.20, 0.31, 0.17);
uniform vec3 sh4 : source_color = vec3(0.47, 0.25, 0.11);
uniform vec3 sh5 : source_color = vec3(0.35, 0.21, 0.14);
// 陽光光斑裡的顏色：橘、黃、金、紅橘、黃綠，同樣明暗接近
uniform vec3 su1 : source_color = vec3(0.86, 0.50, 0.14);
uniform vec3 su2 : source_color = vec3(0.90, 0.70, 0.22);
uniform vec3 su3 : source_color = vec3(0.84, 0.60, 0.18);
uniform vec3 su4 : source_color = vec3(0.80, 0.38, 0.14);
uniform vec3 su5 : source_color = vec3(0.62, 0.64, 0.24);
uniform vec3 rock : source_color = vec3(0.24, 0.13, 0.14);

uniform float night = 0.0;           // 1 = 晚上：不管原本什麼顏色，都換成同一組由深到淺的藍綠色
uniform vec3 night_dark : source_color = vec3(0.40, 0.56, 0.66);
uniform vec3 night_mid : source_color = vec3(0.66, 0.81, 0.87);
uniform vec3 night_light : source_color = vec3(0.94, 0.99, 0.99);
vec3 night_ramp(vec3 c) {
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 r = mix(night_dark, night_mid, smoothstep(0.12, 0.42, l));
	return mix(r, night_light, smoothstep(0.42, 0.80, l));
}
uniform vec2 origin = vec2(0.0);    // 島的原點在這一小關座標裡的位置（x, z）
// 筆觸的方向每一塊區域轉多少。轉得越多越有「漩渦」的筆觸感，但離原點越遠筆觸會被拉得越細；
// 小關裡隔著油畫濾鏡看剛好，世界地圖沒有濾鏡、看得又遠，會變成一圈一圈的摩爾紋，所以地圖上設成 0
uniform float swirl = 2.2;
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec3 pick5(float r, vec3 a, vec3 b, vec3 c, vec3 d, vec3 e) {
	return r < 0.2 ? a : (r < 0.4 ? b : (r < 0.6 ? c : (r < 0.8 ? d : e)));
}

// 一層筆觸：回傳 (這一筆的亂數, 筆觸的遮罩)
vec2 strokes(vec2 p, float size, float ang, float cover, float seed) {
	// 每一塊區域筆的方向不太一樣
	float a = ang + (vnoise(p * 0.18 + seed) - 0.5) * swirl;
	vec2 q = vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y) / size;
	q.y *= 3.2;                               // 筆觸是長條形
	q.x += floor(q.y) * 0.37 + seed;          // 每一排錯開
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float r = hash(id + seed * 13.0);
	float len = 0.30 + 0.18 * hash(id + 5.0);
	float d = max(abs(f.x) - len, abs(f.y) - 0.30);
	d += (vnoise(q * vec2(9.0, 3.0)) - 0.5) * 0.22;      // 邊緣毛毛的
	float m = smoothstep(0.06, -0.02, d) * step(r, cover);
	return vec2(hash(id + 31.0 + seed), m);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp.xz -= origin;        // 筆觸跟著島走：同一塊地不管從哪一小關看，畫出來都一樣
}

void fragment() {
	vec2 p = wp.xz;
	// 光斑：大範圍的亮區和暗區
	float sun_patch = smoothstep(0.46, 0.64, vnoise(p * 0.13 + 3.0) * 0.75 + vnoise(p * 0.4) * 0.25);
	vec3 col = sh5;
	// 陰影的筆觸：兩層大筆觸，只用相近的紅棕色（原本三層、五種色相，地面太花）
	vec2 s = strokes(p, 1.25, 0.3, 0.8, 1.0);
	col = mix(col, pick5(s.x, sh1, sh5, sh4, sh1, sh5), s.y * 0.85);
	s = strokes(p, 0.8, 1.1, 0.5, 2.0);
	col = mix(col, pick5(s.x, sh1, sh4, sh5, sh4, sh2), s.y * 0.7);
	// 光斑的筆觸：只出現在亮區，一層大筆觸
	s = strokes(p, 0.95, 0.8, sun_patch * 0.8, 4.0);
	col = mix(col, pick5(s.x, su1, su3, su4, su1, su3), s.y * 0.9);

	// 陡坡畫成深色的岩石筆觸
	float steep = smoothstep(0.3, 0.7, COLOR.b);
	s = strokes(p * vec2(1.0, 0.6), 0.9, 1.5, 0.8, 6.0);
	col = mix(col, mix(rock, rock * 1.9 + vec3(0.1, 0.05, 0.0), s.x * s.y), steep * 0.85);

	// 整體壓暗、降一點彩度，站在上面的角色才看得清楚
	float luma = dot(col, vec3(0.3, 0.55, 0.15));
	ALBEDO = mix(mix(col, vec3(luma), 0.08) * 0.72, night_ramp(col * 2.6), night);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
