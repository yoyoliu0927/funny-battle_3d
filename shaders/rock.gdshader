// 風格化岩石：淺灰塊狀、平切面、低對比斑駁；朝上的面帶一點砂土色
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 base_color : source_color = vec3(0.76, 0.75, 0.72);
uniform vec3 dark_color : source_color = vec3(0.63, 0.63, 0.62);
uniform vec3 top_color : source_color = vec3(0.86, 0.78, 0.60);
uniform float top_amount = 0.45;
uniform float detail_amount = 0.12;
uniform float tex_scale = 0.15;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 N = normalize(wnrm);
	float m1 = fbm(wpos * 0.09);
	float m2 = fbm(wpos * 0.45 + 4.0);
	vec3 col = mix(dark_color, base_color, smoothstep(0.3, 0.7, m1));
	col *= 0.96 + 0.06 * m2;
	// 極淡的照片細節，只當作斑駁
	vec3 w = pow(abs(N), vec3(4.0)); w /= (w.x + w.y + w.z);
	vec3 p = wpos * tex_scale;
	float d = dot(texture(detail_tex, p.zy).rgb * w.x + texture(detail_tex, p.xz).rgb * w.y + texture(detail_tex, p.xy).rgb * w.z, vec3(0.333));
	col *= 1.0 + (d - 0.45) * detail_amount * 2.0;
	col *= COLOR.rgb;
	float top = smoothstep(0.6, 0.9, N.y + (m2 - 0.5) * 0.4) * top_amount;
	col = mix(col, top_color, top);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

// 風格化光照：柔和的兩階明暗、無高光
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
