shader_type spatial;
render_mode cull_disabled;
// 油畫風的岩壁：灰紫色的石頭，直向的筆觸，受光的地方幾筆暖色，一層一層橫向的岩層，
// 平的地方（平台、石頭頂）積了一點落葉的顏色。
uniform vec3 shade : source_color = vec3(0.17, 0.14, 0.22);
uniform vec3 half_tone : source_color = vec3(0.38, 0.36, 0.45);
uniform vec3 light : source_color = vec3(0.72, 0.68, 0.64);
uniform vec3 leaf_a : source_color = vec3(0.86, 0.50, 0.12);
uniform vec3 leaf_b : source_color = vec3(0.98, 0.80, 0.28);
uniform float night = 0.0;           // 1 = 晚上：岩石上的落葉跟地面一樣換成淺藍綠色
uniform vec3 night_leaf_a : source_color = vec3(0.40, 0.58, 0.68);
uniform vec3 night_leaf_b : source_color = vec3(0.68, 0.84, 0.88);
uniform vec2 origin = vec2(0.0);    // 島的原點在這一小關座標裡的位置（x, z）
varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp.xz -= origin;        // 筆觸跟著島走：同一塊地不管從哪一小關看，畫出來都一樣
	wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// 沿著岩壁橫向的座標：看這一面比較朝哪個方向
	float u = abs(wn.x) > abs(wn.z) ? wp.z : wp.x;
	float s1 = vnoise(vec2(u * 1.6, wp.y * 0.35));
	float s2 = vnoise(vec2(u * 4.0 + 7.0, wp.y * 0.8));
	float strata = vnoise(vec2(u * 0.25 + 3.0, wp.y * 2.4));
	vec3 col = mix(shade, half_tone, smoothstep(0.28, 0.62, s1));
	col = mix(col, light, smoothstep(0.66, 0.74, s2));
	// 一層一層橫向的岩層：寬的色帶深淺交替，再加幾道細的深色裂縫
	float band = vnoise(vec2(u * 0.06, wp.y * 0.55 + 5.0));
	col = mix(col, col * 0.62 + shade * 0.2, smoothstep(0.45, 0.55, band) * 0.7);
	col = mix(col, light * 0.95, smoothstep(0.80, 0.86, band) * 0.5);
	col = mix(col, shade * 0.55, smoothstep(0.70, 0.76, strata) * 0.8);
	// 平的地方：落葉的筆觸
	float flat_amt = smoothstep(0.80, 0.93, wn.y);
	float l1 = vnoise(wp.xz * vec2(3.0, 7.0));
	float l2 = vnoise(wp.xz * vec2(8.0, 3.5) + 11.0);
	vec3 leaf = mix(mix(leaf_a, night_leaf_a, night), mix(leaf_b, night_leaf_b, night), step(0.5, l2));
	col = mix(col, leaf, flat_amt * step(0.60, l1));
	ALBEDO = col * 0.88;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
