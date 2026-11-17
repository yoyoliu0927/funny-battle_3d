shader_type spatial;
// 油畫風的樹幹：直向的筆觸，深紫黑為主，受光面有幾筆土黃；頂點顏色的紅色通道 > 0.5 是白樺。
uniform float burnt = 0.0;          // 1 = 被雷劈過：燒得焦黑，裂縫裡還有一點火光
varying vec3 wp;
varying vec3 inst;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inst = COLOR.rgb;
}

void fragment() {
	vec2 q = vec2(UV.x * 26.0 + inst.g * 40.0, wp.y * 0.55);
	float streak = vnoise(q);
	float streak2 = vnoise(q * vec2(2.0, 1.7) + 9.0);
	vec3 dark = mix(vec3(0.07, 0.05, 0.09), vec3(0.30, 0.25, 0.30), streak);
	vec3 col = mix(dark, vec3(0.58, 0.48, 0.36), smoothstep(0.70, 0.78, streak2));
	col = mix(col, vec3(0.34, 0.28, 0.40), smoothstep(0.25, 0.2, streak2) * 0.6);
	// 白樺：灰白的樹皮，加上黑色的橫紋
	vec3 birch = mix(vec3(0.74, 0.76, 0.84), vec3(0.95, 0.93, 0.88), streak);
	float mark = step(0.86, vnoise(vec2(UV.x * 9.0, wp.y * 3.0 + inst.g * 20.0)));
	birch = mix(birch, vec3(0.05, 0.04, 0.06), mark);
	vec3 wood = mix(col * 0.42, birch, step(0.5, inst.r));
	float ember = smoothstep(0.80, 0.86, vnoise(q * vec2(1.3, 2.1) + 4.0)) * burnt;
	ALBEDO = mix(wood * mix(1.0, 0.3, burnt), vec3(2.2, 0.7, 0.15), ember);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
