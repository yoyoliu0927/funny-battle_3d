shader_type spatial;
render_mode cull_disabled, unshaded;
// 一片葉子 = 一筆顏料：兩頭尖的葉形（純數學算形狀，不讀雜訊），顏色用每個實例自己的顏色
// （oil_world.gd 已經依照朝不朝太陽把亮面、暗面的顏色算好，所以不用打光）。
uniform float night = 0.0;           // 1 = 晚上：不管原本什麼顏色，都換成同一組由深到淺的藍綠色
uniform vec3 night_dark : source_color = vec3(0.04, 0.12, 0.20);
uniform vec3 night_mid : source_color = vec3(0.14, 0.36, 0.46);
uniform vec3 night_light : source_color = vec3(0.56, 0.84, 0.86);
vec3 night_ramp(vec3 c) {
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 r = mix(night_dark, night_mid, smoothstep(0.12, 0.42, l));
	return mix(r, night_light, smoothstep(0.42, 0.80, l));
}
varying vec3 inst;
varying float rnd;

void vertex() {
	inst = pow(COLOR.rgb, vec3(2.2));
	rnd = fract(MODEL_MATRIX[3].x * 3.7 + MODEL_MATRIX[3].z * 1.3);
}

void fragment() {
	vec2 f = UV - 0.5;
	// 葉形：中間寬、兩頭收尖
	float x = f.x / 0.46;
	if (abs(f.y) > 0.30 * (1.0 - x * x) + 0.01 * rnd) {
		discard;
	}
	// 一點點從葉柄到葉尖的深淺，每片的亮度稍微不同
	float v = 0.9 + 0.12 * f.x + 0.12 * (rnd - 0.5);
	ALBEDO = mix(inst, night_ramp(pow(inst, vec3(1.0 / 2.2))), night) * v;
}
