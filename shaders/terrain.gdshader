// 風格化地形：暖黃砂土為主，平塗色塊 + 柔和雜訊
// COLOR.r = 坡道砂土, COLOR.g = 深色土/乾草地, COLOR.b = 陡坡岩面
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 ground_a : source_color = vec3(0.78, 0.62, 0.36);
uniform vec3 ground_b : source_color = vec3(0.70, 0.60, 0.34);
uniform vec3 grassy : source_color = vec3(0.60, 0.60, 0.32);
uniform vec3 sand_c : source_color = vec3(0.93, 0.76, 0.48);
uniform vec3 dirt_c : source_color = vec3(0.74, 0.56, 0.34);
uniform vec3 rock_c : source_color = vec3(0.74, 0.61, 0.40);
uniform float detail_amount = 0.10;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 N = normalize(wnrm);
	float n1 = fbm(wpos * 0.05);
	float n2 = fbm(wpos * 0.25 + 7.0);
	float d = dot(texture(detail_tex, wpos.xz * 0.3).rgb, vec3(0.333));

	vec3 ground = mix(ground_a, ground_b, smoothstep(0.35, 0.65, n1));
	ground = mix(ground, grassy, smoothstep(0.55, 0.7, n2) * 0.6);
	float ws = smoothstep(0.4, 0.6, COLOR.r + (n2 - 0.5) * 0.3);
	float wd = smoothstep(0.35, 0.65, COLOR.g + (n2 - 0.5) * 0.4);
	float wr = smoothstep(0.4, 0.6, COLOR.b + (n1 - 0.5) * 0.3);

	vec3 col = ground;
	col = mix(col, dirt_c, wd * 0.7);
	col = mix(col, sand_c * (0.97 + 0.06 * n2), ws);
	col = mix(col, rock_c, wr);
	col *= 1.0 + (d - 0.45) * detail_amount;
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

// 風格化光照：柔和的兩階明暗、無高光
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
