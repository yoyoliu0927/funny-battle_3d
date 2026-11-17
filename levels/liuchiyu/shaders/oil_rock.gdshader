shader_type spatial;
render_mode cull_disabled;
// 油畫風的岩壁：灰紫色的石頭，一層一層橫向的岩層，平的地方積了一點落葉的顏色。
// 明暗分三階（亮、中、暗）直接用 ramp 光影，紋理只讀一張預先畫好的雜訊貼圖（不再每個像素算六層雜訊）。
#include "res://levels/liuchiyu/shaders/toon_light.gdshaderinc"
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
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

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp.xz -= origin;        // 筆觸跟著島走：同一塊地不管從哪一小關看，畫出來都一樣
	wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// 沿著岩壁橫向的座標：看這一面比較朝哪個方向
	float u = abs(wn.x) > abs(wn.z) ? wp.z : wp.x;
	// 一次讀四個頻率：G = 直向的大筆觸明暗，B = 受光的幾筆，A = 細的裂縫
	vec4 nz = texture(noise_tex, vec2(u * 0.12, wp.y * 0.03));
	vec3 col = mix(shade, half_tone, smoothstep(0.30, 0.60, nz.g));
	col = mix(col, light, smoothstep(0.70, 0.76, nz.b) * 0.8);
	col = mix(col, shade * 0.55, smoothstep(0.76, 0.80, nz.a) * 0.6);
	// 一層一層橫向的岩層：寬的色帶深淺交替
	float band = texture(noise_tex, vec2(u * 0.004, wp.y * 0.07)).r;
	col = mix(col, col * 0.62 + shade * 0.2, smoothstep(0.45, 0.55, band) * 0.6);
	// 平的地方：落葉的顏色（一塊一塊，不是細碎的點）
	float flat_amt = smoothstep(0.80, 0.93, wn.y);
	vec4 ln = texture(noise_tex, wp.xz * 0.06);
	vec3 leaf = mix(mix(leaf_a, night_leaf_a, night), mix(leaf_b, night_leaf_b, night), step(0.5, ln.b));
	col = mix(col, leaf, flat_amt * smoothstep(0.52, 0.56, ln.a));
	ALBEDO = col * 0.88;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
