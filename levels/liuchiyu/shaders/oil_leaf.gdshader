shader_type spatial;
render_mode cull_disabled, unshaded;
// 一片葉子 = 一筆顏料：形狀是邊緣毛毛的長條，顏色用每個實例自己的顏色。
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

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	inst = pow(COLOR.rgb, vec3(2.2));
	rnd = fract(MODEL_MATRIX[3].x * 3.7 + MODEL_MATRIX[3].z * 1.3);
}

void fragment() {
	vec2 f = UV - 0.5;
	float d = max(abs(f.x) - 0.40, abs(f.y) - 0.28) + (vnoise(UV * vec2(6.0, 14.0) + rnd * 30.0) - 0.5) * 0.3;
	if (d > 0.0) {
		discard;
	}
	// 一筆裡面顏料厚薄不一
	float v = 0.85 + 0.3 * vnoise(vec2(UV.x * 3.0, UV.y * 16.0) + rnd * 11.0);
	ALBEDO = mix(inst, night_ramp(pow(inst, vec3(1.0 / 2.2))), night) * v;
}
