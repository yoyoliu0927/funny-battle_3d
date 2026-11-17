shader_type spatial;
render_mode cull_disabled;
// 跟 oil_leaf 一樣是一片葉形的顏料，但是會吃陽光和影子（三階 ramp；給貼在地上的落葉用，樹影才會蓋在上面）。
#include "res://levels/liuchiyu/shaders/toon_light.gdshaderinc"
uniform float night = 0.0;           // 1 = 晚上：不管原本什麼顏色，都換成同一組由深到淺的藍綠色
uniform vec3 night_dark : source_color = vec3(0.40, 0.56, 0.66);
uniform vec3 night_mid : source_color = vec3(0.66, 0.81, 0.87);
uniform vec3 night_light : source_color = vec3(0.94, 0.99, 0.99);
vec3 night_ramp(vec3 c) {
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 r = mix(night_dark, night_mid, smoothstep(0.12, 0.42, l));
	return mix(r, night_light, smoothstep(0.42, 0.80, l));
}
varying vec3 inst;
varying float rnd;

void vertex() {
	inst = COLOR.rgb;
	rnd = fract(MODEL_MATRIX[3].x * 3.7 + MODEL_MATRIX[3].z * 1.3);
}

void fragment() {
	vec2 f = UV - 0.5;
	float x = f.x / 0.46;
	if (abs(f.y) > 0.30 * (1.0 - x * x) + 0.01 * rnd) {
		discard;
	}
	float v = 0.9 + 0.12 * f.x + 0.12 * (rnd - 0.5);
	ALBEDO = mix(inst * v * 0.46, night_ramp(inst) * v, night);
	// 貼在地上的葉子一律當成朝上，光影才會跟地面一致
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
