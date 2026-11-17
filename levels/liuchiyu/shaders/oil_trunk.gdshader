shader_type spatial;
// 油畫風的樹幹：直向的筆觸（讀預先畫好的雜訊貼圖，不再每個像素算雜訊），深紫黑為主，受光面有幾筆土黃；
// 頂點顏色的紅色通道 > 0.5 是白樺。光影用三階 ramp。
#include "res://levels/liuchiyu/shaders/toon_light.gdshaderinc"
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float burnt = 0.0;          // 1 = 被雷劈過：燒得焦黑，裂縫裡還有一點火光
varying vec3 wp;
varying vec3 inst;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inst = COLOR.rgb;
}

void fragment() {
	// 繞樹幹一圈 = 貼圖橫向的幾格，沿著高度拉得很長 = 直條紋
	vec4 nz = texture(noise_tex, vec2(UV.x * 0.8 + inst.g * 5.0, wp.y * 0.018));
	float streak = nz.b;
	vec3 col = mix(vec3(0.07, 0.05, 0.09), vec3(0.30, 0.25, 0.30), streak);
	col = mix(col, vec3(0.58, 0.48, 0.36), smoothstep(0.70, 0.76, nz.a));
	// 白樺：灰白的樹皮，加上黑色的橫紋
	vec3 birch = mix(vec3(0.74, 0.76, 0.84), vec3(0.95, 0.93, 0.88), streak);
	float mark = step(0.80, texture(noise_tex, vec2(UV.x * 0.3, wp.y * 0.1 + inst.g)).a);
	birch = mix(birch, vec3(0.05, 0.04, 0.06), mark);
	vec3 wood = mix(col * 0.42, birch, step(0.5, inst.r));
	float ember = smoothstep(0.78, 0.84, nz.g) * burnt;
	ALBEDO = mix(wood * mix(1.0, 0.3, burnt), vec3(2.2, 0.7, 0.15), ember);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
